import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:video_player/video_player.dart';

import '../behaviors/gestures.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../feedback/spinner.dart';
import '../theme/theme.dart';
import 'image_viewer.dart' show uiFitContain;
import 'seek_bar.dart';
import 'sources.dart';

/// One thing in a [UiMediaLightbox]: a photograph or a clip.
@immutable
class UiMediaItem {
  /// A photograph.
  const UiMediaItem.image(ImageProvider this.image, {this.thumb, this.alt, this.caption}) : video = null;

  /// A clip: [src] is a URL, file path or asset key (see [UiFileSources]); [thumb] is its poster.
  const UiMediaItem.video(String src, {this.thumb, this.alt, this.caption})
      : video = src,
        image = null;

  final ImageProvider? image;
  final String? video;

  /// The filmstrip tile, and a clip's poster while it loads.
  final ImageProvider? thumb;

  /// Alternative text for a photograph. A clip is announced by its caption.
  final String? alt;

  /// The line the chrome shows above the counter.
  final String? caption;

  bool get isVideo => video != null;
}

/// A button in the lightbox's top bar.
@immutable
class UiMediaAction {
  const UiMediaAction({required this.id, required this.label, this.danger = false, this.when});

  final String id;
  final String label;

  /// Destructive actions are drawn in red.
  final bool danger;

  /// Offered only for the items it applies to (someone else's photo is not yours to remove).
  final bool Function(UiMediaItem item, int index)? when;
}

/// How far the sheet must be dragged down before letting go closes it.
const double _dismissDistance = 110;

/// How far a pointer may travel and still count as a tap.
const double _tapSlop = 6;

/// How long the chrome stays up over a playing clip with nothing moving.
const Duration _idle = Duration(milliseconds: 2600);

/// What a seek key is worth.
const Duration _seekStep = Duration(seconds: 10);

/// `ui-media-lightbox`: photographs and clips at full screen, the way a phone's own gallery shows
/// them: edge to edge over everything, with the chrome floating on top and getting out of the way.
///
/// Open it with [UiMediaLightbox.show], which pushes it as a modal route: focus stays inside, the
/// page behind is hidden from screen readers, and back or Escape closes it. The host owns the list:
/// [items] is what there is and [index] where you are; a swipe, the arrows, the filmstrip and the
/// keyboard all just move the index through [onIndexChanged].
///
/// Photographs zoom (pinch, double tap) and pan; clips get themed controls and start themselves.
/// Swipe sideways between items, drag down to dismiss, tap the dark around the picture to close,
/// tap a photograph to hide or show the chrome. The chrome fades away while a clip plays and comes
/// back on any touch. Keys: Left/Right step (Shift seeks a clip), Space or k plays, j/l seek 10 s,
/// m mutes, 0 resets the zoom, Escape closes.
class UiMediaLightbox extends StatefulWidget {
  const UiMediaLightbox({
    super.key,
    required this.items,
    required this.index,
    required this.onIndexChanged,
    required this.onClose,
    this.label = '',
    this.actions = const [],
    this.onAction,
    this.controllerFor,
  });

  final List<UiMediaItem> items;
  final int index;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onClose;

  /// What the set is called, shown when an item has no caption.
  final String label;
  final List<UiMediaAction> actions;

  /// One of [actions] was pressed, with the item it was pressed over.
  final void Function(String id, UiMediaItem item, int index)? onAction;

  /// Makes the player for a clip (tests and custom sources); defaults to [UiFileSources.playerFor].
  final VideoPlayerController Function(String src)? controllerFor;

  /// Opens the lightbox over everything at [initialIndex]. Completes with the index it closed on.
  static Future<int?> show(
    BuildContext context, {
    required List<UiMediaItem> items,
    int initialIndex = 0,
    String label = '',
    List<UiMediaAction> actions = const [],
    void Function(String id, UiMediaItem item, int index)? onAction,
    ValueChanged<int>? onIndexChanged,
    VideoPlayerController Function(String src)? controllerFor,
  }) {
    final animate = context.uiAnimate;
    final t = context.ui;
    var at = initialIndex;
    return Navigator.of(context).push<int>(PageRouteBuilder<int>(
      opaque: false,
      barrierLabel: label.isEmpty ? 'Media viewer' : label,
      transitionDuration: animate ? t.motionBase : Duration.zero,
      reverseTransitionDuration: animate ? t.motionBase : Duration.zero,
      pageBuilder: (context, _, _) => StatefulBuilder(
        builder: (context, set) => UiMediaLightbox(
          items: items,
          index: at,
          label: label,
          actions: actions,
          onAction: onAction,
          controllerFor: controllerFor,
          onIndexChanged: (i) {
            set(() => at = i);
            onIndexChanged?.call(i);
          },
          onClose: () => Navigator.of(context).pop(at),
        ),
      ),
      // Opacity on the sheet, a slight rise on the content: the sheet's own transform belongs to
      // the dismiss drag.
      transitionsBuilder: (context, a, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: t.easeDecelerate),
        child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: a, curve: t.easeDecelerate)), child: child),
      ),
    ));
  }

  @override
  State<UiMediaLightbox> createState() => _UiMediaLightboxState();
}

class _Key extends Intent {
  const _Key(this.name);
  final String name;
}

class _UiMediaLightboxState extends State<UiMediaLightbox> {
  // View.
  double _zoom = 1;
  Offset _offset = Offset.zero;
  double _swipe = 0;
  double _drag = 0;
  bool _interacting = false;
  Size _stage = Size.zero;
  Size _natural = Size.zero;
  bool _loading = true;

  // Gesture.
  double _startZoom = 1;
  Offset? _from;
  Offset _last = Offset.zero;
  double _moved = 0;
  bool _pinched = false;

  // Chrome.
  bool _chrome = true;
  Timer? _idleTimer;

  // Clip.
  VideoPlayerController? _clip;
  final ScrollController _strip = ScrollController();
  final FocusNode _focus = FocusNode(debugLabel: 'UiMediaLightbox');
  ImageStream? _stream;
  ImageStreamListener? _streamListener;

  UiMediaItem? get _item => widget.items.isEmpty ? null : widget.items[widget.index.clamp(0, widget.items.length - 1)];
  bool get _isVideo => _item?.isVideo ?? false;
  bool get _hasPrevious => widget.index > 0;
  bool get _hasNext => widget.index < widget.items.length - 1;
  bool get _zoomed => _zoom > 1;
  bool get _playing => _clip?.value.isPlaying ?? false;
  double get _veil => math.max(0, 1 - _drag.abs() / (_dismissDistance * 2.2));

  @override
  void initState() {
    super.initState();
    _enter();
  }

  @override
  void didUpdateWidget(UiMediaLightbox old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index || !identical(old.items, widget.items) && _item != _itemOf(old)) _enter();
  }

  UiMediaItem? _itemOf(UiMediaLightbox w) => w.items.isEmpty ? null : w.items[w.index.clamp(0, w.items.length - 1)];

  @override
  void dispose() {
    _idleTimer?.cancel();
    _disposeClip();
    _unlistenImage();
    _strip.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// A new item is a new view: the last one's zoom, pan and half-finished drag belong to it.
  void _enter() {
    _zoom = 1;
    _offset = Offset.zero;
    _swipe = 0;
    _drag = 0;
    _loading = true;
    _natural = Size.zero;
    _disposeClip();
    _unlistenImage();
    final item = _item;
    if (item == null) return;
    if (item.isVideo) {
      final c = (widget.controllerFor ?? UiFileSources.playerFor)(item.video!);
      _clip = c;
      c.addListener(_clipChanged);
      c.initialize().then((_) {
        if (!mounted || _clip != c) return;
        setState(() {
          _loading = false;
          _natural = c.value.size;
        });
        // A clip opened on purpose is a clip somebody wants to watch.
        c.play();
      }, onError: (Object _) {
        if (mounted && _clip == c) setState(() => _loading = false);
      });
    } else {
      final stream = item.image!.resolve(ImageConfiguration.empty);
      final l = ImageStreamListener((info, _) {
        if (!mounted) return;
        setState(() {
          _natural = Size(info.image.width.toDouble(), info.image.height.toDouble());
          _loading = false;
        });
      }, onError: (_, _) {
        if (mounted) setState(() => _loading = false);
      });
      _stream = stream..addListener(l);
      _streamListener = l;
    }
    _wake();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheNeighbours();
      _scrollStrip();
      _focus.requestFocus();
    });
  }

  void _unlistenImage() {
    if (_streamListener != null) _stream?.removeListener(_streamListener!);
    _stream = null;
    _streamListener = null;
  }

  void _disposeClip() {
    final c = _clip;
    _clip = null;
    if (c == null) return;
    c.removeListener(_clipChanged);
    c.pause();
    c.dispose();
  }

  bool _wasPlaying = false;
  void _clipChanged() {
    if (!mounted) return;
    final playing = _playing;
    if (playing != _wasPlaying) {
      _wasPlaying = playing;
      // A clip that starts hides the chrome after a while; one that stops (or ends) brings it back.
      _wake();
    }
    setState(() {});
  }

  /// The next photograph is fetched while this one is looked at, so a swipe lands on a picture.
  /// Clips are left alone: preloading one is megabytes spent on a guess.
  void _precacheNeighbours() {
    for (final at in [widget.index + 1, widget.index - 1]) {
      if (at < 0 || at >= widget.items.length) continue;
      final it = widget.items[at];
      if (!it.isVideo) precacheImage(it.image!, context, onError: (_, _) {});
    }
  }

  void _scrollStrip() {
    if (!_strip.hasClients) return;
    const tile = 54.0, gap = 8.0;
    final target = (widget.index * (tile + gap) + tile / 2 - _strip.position.viewportDimension / 2).clamp(0.0, _strip.position.maxScrollExtent);
    if (context.uiAnimate) {
      _strip.animateTo(target, duration: context.ui.motionBase, curve: context.ui.easeStandard);
    } else {
      _strip.jumpTo(target);
    }
  }

  /// Shows the chrome and, over a playing clip, starts the clock on hiding it again. A photograph
  /// never loses its chrome on its own: with none, nothing on screen says how to close it.
  void _wake() {
    _idleTimer?.cancel();
    if (!_chrome && mounted) setState(() => _chrome = true);
    _chrome = true;
    if (_isVideo && _playing) {
      _idleTimer = Timer(_idle, () {
        if (mounted && _playing) setState(() => _chrome = false);
      });
    }
  }

  void _close() => widget.onClose();

  void _goTo(int at) {
    if (at >= 0 && at < widget.items.length && at != widget.index) widget.onIndexChanged(at);
  }

  void _step(int by) => _goTo(widget.index + by);

  void _resetView() => setState(() {
        _zoom = 1;
        _offset = Offset.zero;
        _swipe = 0;
        _drag = 0;
      });

  Size get _shown => uiFitContain(_natural, _stage);

  Offset _clamp(Offset o, [double? z]) => UiGestures.clampOffset(o, _shown, _stage, z ?? _zoom);

  void _setZoom(double z) {
    final next = double.parse(z.clamp(1.0, 6.0).toStringAsFixed(3));
    setState(() {
      _zoom = next;
      _offset = _clamp(_offset, next);
    });
  }

  void _toggleZoom() {
    if (_isVideo) return;
    _zoomed ? _resetView() : _setZoom(2.5);
  }

  void _togglePlay() {
    final c = _clip;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      if (c.value.duration > Duration.zero && c.value.position >= c.value.duration) c.seekTo(Duration.zero);
      c.play();
    }
    _wake();
  }

  void _seekBy(Duration d) {
    final c = _clip;
    if (c == null || !c.value.isInitialized) return;
    final to = c.value.position + d;
    c.seekTo(to < Duration.zero ? Duration.zero : to > c.value.duration ? c.value.duration : to);
    _wake();
  }

  void _toggleMute() {
    final c = _clip;
    if (c == null) return;
    c.setVolume(c.value.volume == 0 ? 1 : 0);
    _wake();
  }

  void _cycleRate() {
    final c = _clip;
    if (c == null) return;
    const rates = [1.0, 1.5, 2.0, 0.5];
    c.setPlaybackSpeed(rates[(rates.indexOf(c.value.playbackSpeed) + 1) % rates.length]);
    _wake();
  }

  // ---- gestures ----

  void _onScaleStart(ScaleStartDetails d) {
    _wake();
    _startZoom = _zoom;
    _pinched = d.pointerCount > 1;
    _from = _pinched ? null : d.localFocalPoint;
    _last = d.localFocalPoint;
    _moved = 0;
    setState(() => _interacting = true);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    _last = d.localFocalPoint;
    if (d.pointerCount > 1) {
      // A pinch is not a half-finished swipe.
      _pinched = true;
      _from = null;
      _swipe = 0;
      _drag = 0;
      if (!_isVideo) _setZoom(_startZoom * d.scale);
      return;
    }
    if (_pinched) return;
    // A zoomed picture is being read: the drag pans it. Only back at fit does it browse.
    if (!_isVideo && _zoomed) {
      setState(() => _offset = _clamp(_offset + d.focalPointDelta));
      _moved = math.max(_moved, _tapSlop + 1);
      return;
    }
    final from = _from;
    if (from == null) return;
    final delta = d.localFocalPoint - from;
    _moved = math.max(_moved, delta.distance);
    // Whichever the drag is mostly doing wins, so it never does half of each.
    setState(() {
      if (delta.dx.abs() > delta.dy.abs()) {
        _drag = 0;
        final blocked = delta.dx > 0 ? !_hasPrevious : !_hasNext;
        _swipe = UiGestures.resist(delta.dx, _stage.width, blocked: blocked);
      } else {
        _swipe = 0;
        _drag = math.max(0, delta.dy);
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails d) {
    final from = _from;
    final dx = _swipe, down = _drag;
    _from = null;
    setState(() {
      _interacting = false;
      _swipe = 0;
      _drag = 0;
    });
    if (from == null || _pinched) return;
    if (_moved <= _tapSlop) {
      _onTap(_last);
      return;
    }
    if (down >= _dismissDistance) {
      _close();
      return;
    }
    if (dx == 0) return;
    final speed = d.velocity.pixelsPerSecond.dx.abs() / 1000;
    final ms = speed > 0 ? dx.abs() / speed : 1000.0;
    final dy = _last.dy - from.dy;
    if (!UiGestures.isSwipe(dx, dy, ms, _stage.width)) return;
    if (dx < 0 && _hasNext) {
      _step(1);
    } else if (dx > 0 && _hasPrevious) {
      _step(-1);
    }
  }

  /// A tap on the picture plays/pauses a clip or toggles the chrome over a photo; a tap on the dark
  /// around it closes.
  void _onTap(Offset at) {
    final shown = _shown;
    final rect = Rect.fromCenter(center: _stage.center(Offset.zero) + _offset, width: shown.width * _zoom, height: shown.height * _zoom);
    if (!_loading && _natural != Size.zero && !rect.contains(at)) {
      _close();
      return;
    }
    if (_isVideo) {
      _togglePlay();
    } else {
      setState(() => _chrome = !_chrome);
    }
  }

  bool _onKey(String k) {
    _wake();
    final shift = HardwareKeyboard.instance.isShiftPressed;
    switch (k) {
      case 'right':
        shift && _isVideo ? _seekBy(_seekStep) : _step(1);
      case 'left':
        shift && _isVideo ? _seekBy(-_seekStep) : _step(-1);
      case 'play':
        if (_isVideo) _togglePlay();
      case 'l':
        if (_isVideo) _seekBy(_seekStep);
      case 'j':
        if (_isVideo) _seekBy(-_seekStep);
      case 'm':
        if (_isVideo) _toggleMute();
      case '0':
        _resetView();
      case 'esc':
        _close();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final item = _item;
    final touch = uiTouchPlatform(context);
    final wide = MediaQuery.sizeOf(context).width > 640;
    final pad = MediaQuery.paddingOf(context);
    final onScrim = t.mediaOnScrim;

    final keys = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.arrowRight): const _Key('right'),
      const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): const _Key('right'),
      const SingleActivator(LogicalKeyboardKey.arrowLeft): const _Key('left'),
      const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): const _Key('left'),
      const SingleActivator(LogicalKeyboardKey.keyK): const _Key('play'),
      const SingleActivator(LogicalKeyboardKey.keyL): const _Key('l'),
      const SingleActivator(LogicalKeyboardKey.keyJ): const _Key('j'),
      const SingleActivator(LogicalKeyboardKey.keyM): const _Key('m'),
      const SingleActivator(LogicalKeyboardKey.digit0): const _Key('0'),
      const SingleActivator(LogicalKeyboardKey.escape): const _Key('esc'),
    };

    Widget media() {
      if (item == null) return const SizedBox();
      if (item.isVideo) {
        final c = _clip;
        return Stack(fit: StackFit.expand, children: [
          if (c != null && c.value.isInitialized)
            Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)))
          else if (item.thumb != null)
            Image(image: item.thumb!, fit: BoxFit.contain, excludeFromSemantics: true),
        ]);
      }
      return Image(
        image: item.image!,
        fit: BoxFit.contain,
        gaplessPlayback: false,
        semanticLabel: item.alt,
        excludeFromSemantics: item.alt == null,
        errorBuilder: (context, _, _) => Center(child: UiIcon(HugeIcons.strokeRoundedImage01, size: 40, color: onScrim.withValues(alpha: 0.6))),
      );
    }

    final transform = Matrix4.identity()
      ..translateByDouble(_offset.dx + _swipe, _offset.dy, 0, 1)
      ..scaleByDouble(_zoom, _zoom, 1, 1);

    final stage = LayoutBuilder(builder: (context, box) {
      _stage = box.biggest;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        onDoubleTap: _isVideo ? null : _toggleZoom,
        child: Stack(fit: StackFit.expand, alignment: Alignment.center, children: [
          AnimatedContainer(
            duration: _interacting || !context.uiAnimate ? Duration.zero : t.motionFast,
            curve: t.easeStandard,
            transform: transform,
            transformAlignment: Alignment.center,
            child: media(),
          ),
          if (_loading) Center(child: UiSpinner(size: 34, strokeWidth: 2, color: onScrim, label: 'Loading')),
          // The one control that is not chrome: a paused clip says so in the middle of itself.
          if (_isVideo && !_playing && !_loading) Center(child: _BigPlay(onTap: _togglePlay)),
        ]),
      );
    });

    final visibleActions = item == null ? const <UiMediaAction>[] : [for (final a in widget.actions) if (a.when == null || a.when!(item, widget.index)) a];
    final metaLine = (item?.caption?.isNotEmpty ?? false) ? item!.caption! : widget.label;
    final count = widget.items.length;

    final top = _Scrim(
      top: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(t.space4, math.max(t.space3, pad.top), t.space4, t.space6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, spacing: 2, children: [
                if (metaLine.isNotEmpty)
                  Text(metaLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.label.copyWith(color: onScrim, letterSpacing: 0.13)),
                if (count > 1)
                  Text('${widget.index + 1} of $count', style: context.uiText.caption.copyWith(fontSize: 12, color: onScrim.withValues(alpha: 0.66), fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
          ),
          Wrap(spacing: t.space2, runSpacing: t.space2, alignment: WrapAlignment.end, children: [
            if (_zoomed) _Glass(label: '${(_zoom * 100).round()}% · Fit', semanticLabel: 'Reset zoom', onTap: _resetView),
            for (final a in visibleActions)
              _Glass(label: a.label, danger: a.danger, onTap: () => widget.onAction?.call(a.id, item!, widget.index)),
            _Glass(icon: HugeIcons.strokeRoundedCancel01, semanticLabel: 'Close', onTap: _close),
          ]),
        ]),
      ),
    );

    final c = _clip;
    final cv = c?.value;
    final bottom = _Scrim(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(t.space4, t.space8, t.space4, math.max(t.space3, pad.bottom)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
          if (_isVideo && cv != null)
            Row(spacing: t.space2, children: [
              _Glass(icon: _playing ? HugeIcons.strokeRoundedPause : HugeIcons.strokeRoundedPlay, semanticLabel: _playing ? 'Pause' : 'Play', onTap: _togglePlay),
              _time(context, cv.position),
              Expanded(
                child: UiSeekBar(
                  position: cv.position,
                  duration: cv.duration,
                  buffered: cv.buffered.isEmpty ? Duration.zero : cv.buffered.last.end,
                  step: _seekStep,
                  trackColor: onScrim.withValues(alpha: 0.24),
                  bufferColor: onScrim.withValues(alpha: 0.38),
                  fillColor: onScrim,
                  onSeek: (d) {
                    c!.seekTo(d);
                    _wake();
                  },
                ),
              ),
              _time(context, cv.duration),
              _Glass(icon: cv.volume == 0 ? HugeIcons.strokeRoundedVolumeMute01 : HugeIcons.strokeRoundedVolumeHigh, semanticLabel: cv.volume == 0 ? 'Unmute' : 'Mute', onTap: _toggleMute),
              _Glass(label: '${cv.playbackSpeed == cv.playbackSpeed.roundToDouble() ? cv.playbackSpeed.toInt() : cv.playbackSpeed}×', semanticLabel: 'Playback speed', onTap: _cycleRate),
            ]),
          if (count > 1)
            SizedBox(
              height: 54 + t.space2 * 2,
              child: ListView.separated(
                controller: _strip,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(vertical: t.space2, horizontal: t.space1),
                itemCount: count,
                separatorBuilder: (_, _) => SizedBox(width: t.space2),
                itemBuilder: (context, i) => _StripTile(item: widget.items[i], index: i, current: i == widget.index, onTap: () => _goTo(i)),
              ),
            ),
        ]),
      ),
    );

    final veil = _veil;
    final sheet = Transform(
      alignment: const Alignment(0, -0.2),
      transform: Matrix4.identity()
        ..translateByDouble(0, _drag, 0, 1)
        ..scaleByDouble(1 - 0.06 * (1 - veil), 1 - 0.06 * (1 - veil), 1, 1),
      child: ColoredBox(
        color: t.mediaScrim.withValues(alpha: 0.92 * veil),
        child: Stack(fit: StackFit.expand, children: [
          stage,
          // Faded out, and unpressable with it: chrome you cannot see must not be chrome you can press.
          for (final (bar, isTop) in [(top, true), (bottom, false)])
            Positioned(
              left: 0,
              right: 0,
              top: isTop ? 0 : null,
              bottom: isTop ? null : 0,
              child: IgnorePointer(
                ignoring: !_chrome,
                child: ExcludeSemantics(
                  excluding: !_chrome,
                  child: AnimatedOpacity(
                    opacity: _chrome ? 1 : 0,
                    duration: context.uiAnimate ? t.motionBase : Duration.zero,
                    child: AnimatedSlide(
                      offset: _chrome ? Offset.zero : Offset(0, isTop ? -0.08 : 0.08),
                      duration: context.uiAnimate ? t.motionBase : Duration.zero,
                      child: bar,
                    ),
                  ),
                ),
              ),
            ),
          // Pointer-fine only: on a phone the same move is the swipe.
          if (count > 1 && !touch && wide && _chrome) ...[
            Positioned(left: t.space4, top: 0, bottom: 0, child: Center(child: _Glass(icon: HugeIcons.strokeRoundedArrowLeft01, semanticLabel: 'Previous', size: 48, onTap: _hasPrevious ? () => _step(-1) : null))),
            Positioned(right: t.space4, top: 0, bottom: 0, child: Center(child: _Glass(icon: HugeIcons.strokeRoundedArrowRight01, semanticLabel: 'Next', size: 48, onTap: _hasNext ? () => _step(1) : null))),
          ],
        ]),
      ),
    );

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: widget.label.isEmpty ? 'Media viewer' : widget.label,
      child: Shortcuts(
        shortcuts: keys,
        child: Actions(
          actions: {_Key: CallbackAction<_Key>(onInvoke: (k) => _onKey(k.name))},
          child: Focus(
            focusNode: _focus,
            autofocus: true,
            onKeyEvent: (node, e) {
              // Space on the stage plays a clip; on a focused button it presses the button.
              if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.space && node.hasPrimaryFocus && _isVideo) {
                _togglePlay();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Listener(
              onPointerHover: (_) {
                if (!_chrome) _wake();
              },
              child: DefaultTextStyle(style: context.uiText.body.copyWith(color: onScrim), child: sheet),
            ),
          ),
        ),
      ),
    );
  }

  Widget _time(BuildContext context, Duration d) => SizedBox(
        width: 42,
        child: Text(
          uiFormatMediaTime(d),
          textAlign: TextAlign.center,
          style: context.uiText.caption.copyWith(fontSize: 12, color: context.ui.mediaOnScrim.withValues(alpha: 0.8), fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      );
}

/// Top and bottom scrims: dark held through the band the chrome occupies, then let go.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.top, required this.child});
  final bool top;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = context.ui.mediaScrim;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [s.withValues(alpha: top ? 0.78 : 0.85), s.withValues(alpha: top ? 0.5 : 0.62), s.withValues(alpha: 0)],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: child,
    );
  }
}

/// The one glass treatment for everything floating over the picture: pills with a [label], circles
/// with an [icon].
class _Glass extends StatelessWidget {
  const _Glass({this.icon, this.label, this.semanticLabel, this.onTap, this.danger = false, this.size = 38});
  final UiIconData? icon;
  final String? label;
  final String? semanticLabel;
  final VoidCallback? onTap;
  final bool danger;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final fg = danger ? t.mediaDanger : t.mediaOnScrim;
    final circle = icon != null && label == null;
    return UiInteractive(
      onTap: onTap,
      enabled: onTap != null,
      semanticLabel: semanticLabel ?? label,
      excludeChildSemantics: true,
      builder: (context, s) {
        final fill = danger ? t.mediaDanger.withValues(alpha: s.hovered || s.pressed ? 0.26 : 0.14) : t.mediaOnScrim.withValues(alpha: s.hovered || s.pressed ? 0.22 : 0.10);
        final shape = circle ? BorderRadius.circular(size) : BorderRadius.circular(t.radiusPill);
        return AnimatedOpacity(
          opacity: s.disabled ? 0.25 : 1,
          duration: t.motionBase,
          child: ClipRRect(
            borderRadius: shape,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: AnimatedContainer(
                duration: context.uiAnimate ? t.motionBase : Duration.zero,
                height: circle ? size : t.sizeLg,
                width: circle ? size : null,
                padding: circle ? EdgeInsets.zero : EdgeInsets.symmetric(horizontal: t.space4),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: shape,
                  border: Border.all(color: danger ? t.mediaDanger.withValues(alpha: 0.35) : t.mediaOnScrim.withValues(alpha: 0.16)),
                ),
                foregroundDecoration: s.focused ? BoxDecoration(borderRadius: shape, border: Border.all(color: t.mediaOnScrim, width: 2)) : null,
                alignment: Alignment.center,
                child: label != null
                    ? Text(label!, style: context.uiText.caption.copyWith(color: fg, height: 1, fontFeatures: const [FontFeature.tabularFigures()]))
                    : UiIcon(icon!, size: size > 40 ? 22 : 19, strokeWidth: 1.9, color: fg),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BigPlay extends StatelessWidget {
  const _BigPlay({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      semanticLabel: 'Play',
      excludeChildSemantics: true,
      builder: (context, s) => ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
          child: AnimatedContainer(
            duration: context.uiAnimate ? t.motionFast : Duration.zero,
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.mediaOnScrim.withValues(alpha: s.hovered ? 0.26 : 0.16),
              border: s.focused ? Border.all(color: t.mediaOnScrim, width: 2) : null,
            ),
            child: Padding(padding: const EdgeInsets.only(left: 4), child: Center(child: UiIcon(HugeIcons.strokeRoundedPlay, size: 38, color: t.mediaOnScrim))),
          ),
        ),
      ),
    );
  }
}

class _StripTile extends StatelessWidget {
  const _StripTile({required this.item, required this.index, required this.current, required this.onTap});
  final UiMediaItem item;
  final int index;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final still = item.thumb ?? item.image;
    final animate = context.uiAnimate;
    return UiInteractive(
      onTap: onTap,
      selected: current,
      padTouchTarget: false,
      semanticLabel: item.caption ?? 'Item ${index + 1}',
      excludeChildSemantics: true,
      builder: (context, s) => AnimatedContainer(
        duration: animate ? t.motionBase : Duration.zero,
        width: 54,
        height: 54,
        transform: Matrix4.translationValues(0, current && animate ? -3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusSm),
          color: t.mediaOnScrim.withValues(alpha: 0.08),
          boxShadow: [
            if (current || s.focused) BoxShadow(color: t.mediaOnScrim, spreadRadius: 2),
            if (current) BoxShadow(color: t.mediaScrim.withValues(alpha: 0.5), blurRadius: 18, offset: const Offset(0, 6)),
          ],
        ),
        child: AnimatedOpacity(
          duration: animate ? t.motionBase : Duration.zero,
          opacity: current ? 1 : s.hovered ? 0.8 : 0.5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(t.radiusSm),
            child: Stack(fit: StackFit.expand, children: [
              if (still != null) Image(image: still, fit: BoxFit.cover, excludeFromSemantics: true),
              if (item.isVideo)
                ColoredBox(color: t.mediaScrim.withValues(alpha: 0.28), child: Center(child: UiIcon(HugeIcons.strokeRoundedPlay, size: 16, color: t.mediaOnScrim))),
            ]),
          ),
        ),
      ),
    );
  }
}
