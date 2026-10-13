import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:video_player/video_player.dart';

import '../button/button.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../feedback/spinner.dart';
import '../theme/theme.dart';
import 'seek_bar.dart';
import 'sources.dart';

/// Owns (or borrows) a [VideoPlayerController] for [src], initialises it and rebuilds on every
/// change. Shared by the video and audio players.
mixin _PlayerHost<W extends StatefulWidget> on State<W> {
  VideoPlayerController? _owned;
  VideoPlayerController get player => _borrowed ?? _owned!;
  VideoPlayerController? get _borrowed;
  String get _src;
  Object? initError;

  void _attach() {
    if (_borrowed == null) _owned = UiFileSources.playerFor(_src);
    player.addListener(_changed);
    if (!player.value.isInitialized) {
      player.initialize().catchError((Object e) {
        if (mounted) setState(() => initError = e);
      });
    }
  }

  void _detach() {
    player.removeListener(_changed);
    _owned?.dispose();
    _owned = null;
    initError = null;
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void togglePlay() {
    final v = player.value;
    if (!v.isInitialized) return;
    if (v.isPlaying) {
      player.pause();
    } else {
      // Ended: start over.
      if (v.duration > Duration.zero && v.position >= v.duration) player.seekTo(Duration.zero);
      player.play();
    }
  }

  bool get hasError => initError != null || player.value.hasError;
  String get errorText => player.value.errorDescription ?? 'This file could not be played.';

  Duration get buffered {
    final ranges = player.value.buffered;
    return ranges.isEmpty ? Duration.zero : ranges.last.end;
  }
}

/// `ui-video-player`: a video with themed controls: play/pause, the time, a seek bar, mute, speed
/// (0.5× to 2×) and full screen. Tapping the picture plays or pauses. [src] is a URL, a file path or
/// an asset key (see [UiFileSources]); pass [controller] to manage playback yourself.
///
/// The picture keeps its aspect ratio, at most [maxHeight] tall (60% of the screen by default).
/// Full screen opens the same clip over everything; back or Escape returns. Uses the platform player
/// through `video_player` (ExoPlayer on Android).
class UiVideoPlayer extends StatefulWidget {
  const UiVideoPlayer({super.key, required this.src, this.poster, this.controller, this.maxHeight});

  final String src;

  /// Shown until the clip starts.
  final ImageProvider? poster;
  final VideoPlayerController? controller;
  final double? maxHeight;

  @override
  State<UiVideoPlayer> createState() => _UiVideoPlayerState();
}

class _UiVideoPlayerState extends State<UiVideoPlayer> with _PlayerHost<UiVideoPlayer> {
  bool _started = false;

  @override
  VideoPlayerController? get _borrowed => widget.controller;
  @override
  String get _src => widget.src;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(UiVideoPlayer old) {
    super.didUpdateWidget(old);
    if (old.src != widget.src || old.controller != widget.controller) {
      old.controller?.removeListener(_changed);
      _owned?.removeListener(_changed);
      _owned?.dispose();
      _owned = null;
      initError = null;
      _started = false;
      _attach();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  Future<void> _fullscreen() async {
    final nav = Navigator.of(context);
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    await nav.push(PageRouteBuilder<void>(
      opaque: true,
      barrierLabel: 'Full screen video',
      pageBuilder: (context, _, _) => _FullscreenVideo(player: player, host: this),
      transitionDuration: context.uiAnimate ? context.ui.motionBase : Duration.zero,
      reverseTransitionDuration: context.uiAnimate ? context.ui.motionBase : Duration.zero,
      transitionsBuilder: (context, a, _, child) => FadeTransition(opacity: a, child: child),
    ));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  }

  @override
  void togglePlay() {
    _started = true;
    super.togglePlay();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final v = player.value;
    final maxH = widget.maxHeight ?? MediaQuery.sizeOf(context).height * 0.6;
    final ratio = v.isInitialized && v.aspectRatio > 0 ? v.aspectRatio : 16 / 9;

    final stage = Semantics(
      label: 'Video',
      onTap: togglePlay,
      child: GestureDetector(
        onTap: togglePlay,
        excludeFromSemantics: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: AspectRatio(
            aspectRatio: ratio,
            child: ColoredBox(
              color: t.mediaBg,
              child: Stack(fit: StackFit.expand, children: [
                if (v.isInitialized) VideoPlayer(player),
                if (widget.poster != null && !_started && v.position == Duration.zero && !v.isPlaying)
                  Image(image: widget.poster!, fit: BoxFit.contain, excludeFromSemantics: true),
                if (hasError)
                  Center(child: Padding(padding: EdgeInsets.all(t.space4), child: Text(errorText, textAlign: TextAlign.center, style: context.uiText.caption.copyWith(color: t.mediaOnScrim))))
                else if (!v.isInitialized || v.isBuffering)
                  Center(child: UiSpinner(size: 28, strokeWidth: 2.5, color: t.mediaOnScrim)),
              ]),
            ),
          ),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(context.uiTheme.radius()),
      child: ColoredBox(
        color: t.mediaBg,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: stage),
          _Controls(host: this, onFullscreen: _fullscreen),
        ]),
      ),
    );
  }
}

/// The video controls bar, shared by the inline and full-screen views.
class _Controls extends StatelessWidget {
  const _Controls({required this.host, this.onFullscreen, this.fullscreen = false});
  final _PlayerHost host;
  final VoidCallback? onFullscreen;
  final bool fullscreen;

  static const _rates = [1.0, 1.5, 2.0, 0.5];

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final p = host.player;
    final v = p.value;
    final ready = v.isInitialized && !host.hasError;
    final time = context.uiText.code.copyWith(fontSize: t.fontSizeSm, color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()]);
    String rate(double r) => '${r == r.roundToDouble() ? r.toInt() : r}×';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: t.space1),
      decoration: BoxDecoration(color: t.surfaceRaised, border: Border(top: BorderSide(color: t.border))),
      child: Row(spacing: uiTouchPlatform(context) ? 0 : t.space1, children: [
        UiIconButton(
          icon: UiIcon(v.isPlaying ? HugeIcons.strokeRoundedPause : HugeIcons.strokeRoundedPlay),
          label: v.isPlaying ? 'Pause' : 'Play',
          size: UiSize.sm,
          onPressed: ready ? host.togglePlay : null,
        ),
        Text(uiFormatMediaTime(v.position), style: time),
        SizedBox(width: t.space2),
        Expanded(child: UiSeekBar(position: v.position, duration: v.duration, buffered: host.buffered, onSeek: p.seekTo)),
        SizedBox(width: t.space2),
        Text(uiFormatMediaTime(v.duration), style: time),
        UiIconButton(
          icon: UiIcon(v.volume == 0 ? HugeIcons.strokeRoundedVolumeMute01 : HugeIcons.strokeRoundedVolumeHigh),
          label: v.volume == 0 ? 'Unmute' : 'Mute',
          size: UiSize.sm,
          onPressed: ready ? () => p.setVolume(v.volume == 0 ? 1 : 0) : null,
        ),
        _RateButton(
          text: rate(v.playbackSpeed),
          onTap: ready ? () => p.setPlaybackSpeed(_rates[(_rates.indexOf(v.playbackSpeed) + 1) % _rates.length]) : null,
        ),
        if (onFullscreen != null || fullscreen)
          UiIconButton(
            icon: UiIcon(fullscreen ? HugeIcons.strokeRoundedMinimize01 : HugeIcons.strokeRoundedFullScreen),
            label: fullscreen ? 'Exit full screen' : 'Full screen',
            size: UiSize.sm,
            onPressed: fullscreen ? () => Navigator.of(context).maybePop() : onFullscreen,
          ),
      ]),
    );
  }
}

/// Playback speed: a compact text button that steps 1× → 1.5× → 2× → 0.5×.
class _RateButton extends StatelessWidget {
  const _RateButton({required this.text, required this.onTap});
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      enabled: onTap != null,
      semanticLabel: 'Playback speed $text',
      excludeChildSemantics: true,
      builder: (context, s) => AnimatedContainer(
        duration: context.uiAnimate ? t.motionBase : Duration.zero,
        height: t.sizeSm,
        constraints: BoxConstraints(minWidth: t.sizeSm),
        padding: EdgeInsets.symmetric(horizontal: t.space1),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: s.hovered || s.pressed ? t.elevatedHover : t.surface,
          border: Border.all(color: t.controlBorder),
          borderRadius: BorderRadius.circular(t.radiusXs),
          boxShadow: uiFocusRing(t, show: s.focused),
        ),
        child: Text(text, style: context.uiText.caption.copyWith(color: t.text, fontFeatures: const [FontFeature.tabularFigures()])),
      ),
    );
  }
}

class _FullscreenVideo extends StatefulWidget {
  const _FullscreenVideo({required this.player, required this.host});
  final VideoPlayerController player;
  final _PlayerHost host;

  @override
  State<_FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<_FullscreenVideo> {
  @override
  void initState() {
    super.initState();
    widget.player.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.player.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final v = widget.player.value;
    return Shortcuts(
      shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()},
      child: Actions(
        actions: {DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => Navigator.of(context).maybePop())},
        child: Focus(
          autofocus: true,
          child: ColoredBox(
            color: t.mediaBg,
            child: SafeArea(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(
                  child: GestureDetector(
                    onTap: widget.host.togglePlay,
                    child: Center(child: AspectRatio(aspectRatio: v.aspectRatio > 0 ? v.aspectRatio : 16 / 9, child: VideoPlayer(widget.player))),
                  ),
                ),
                _Controls(host: widget.host, fullscreen: true),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// `ui-audio-player`: themed audio controls: play/pause, an optional [title], the elapsed time, a
/// seek bar and the duration. There is no volume control; the device's volume keys apply.
///
/// Plays through `video_player` (ExoPlayer on Android handles audio-only files), so the library
/// needs one media plugin rather than two. Pass [controller] to manage playback yourself.
class UiAudioPlayer extends StatefulWidget {
  const UiAudioPlayer({super.key, required this.src, this.title, this.controller});

  final String src;
  final String? title;
  final VideoPlayerController? controller;

  @override
  State<UiAudioPlayer> createState() => _UiAudioPlayerState();
}

class _UiAudioPlayerState extends State<UiAudioPlayer> with _PlayerHost<UiAudioPlayer> {
  @override
  VideoPlayerController? get _borrowed => widget.controller;
  @override
  String get _src => widget.src;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(UiAudioPlayer old) {
    super.didUpdateWidget(old);
    if (old.src != widget.src || old.controller != widget.controller) {
      old.controller?.removeListener(_changed);
      _owned?.removeListener(_changed);
      _owned?.dispose();
      _owned = null;
      initError = null;
      _attach();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final v = player.value;
    final ready = v.isInitialized && !hasError;
    final time = context.uiText.code.copyWith(fontSize: t.fontSizeSm, color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()]);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: t.space1),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(context.uiTheme.radius())),
      child: LayoutBuilder(builder: (context, box) {
        return Row(spacing: t.space2, children: [
          UiIconButton(
            icon: UiIcon(v.isPlaying ? HugeIcons.strokeRoundedPause : HugeIcons.strokeRoundedPlay),
            label: v.isPlaying ? 'Pause' : 'Play',
            round: true,
            variant: UiButtonVariant.primary,
            onPressed: ready ? togglePlay : null,
          ),
          if (widget.title != null)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * 0.3),
              child: Text(widget.title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.caption.copyWith(color: t.text)),
            ),
          if (hasError)
            Expanded(child: Text(errorText, style: context.uiText.caption.copyWith(color: t.danger)))
          else ...[
            Text(uiFormatMediaTime(v.position), style: time),
            Expanded(child: UiSeekBar(position: v.position, duration: v.duration, buffered: buffered, onSeek: player.seekTo)),
            Text(uiFormatMediaTime(v.duration), style: time),
          ],
        ]);
      }),
    );
  }
}
