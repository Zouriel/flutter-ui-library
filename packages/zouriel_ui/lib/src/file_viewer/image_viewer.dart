import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../behaviors/gestures.dart';
import '../behaviors/swipe.dart';
import '../button/button.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';

const double _minZoom = 0.25;
const double _maxZoom = 6;

/// Resolves [image] to learn its pixel size (for fitting and clamping a zoomed picture).
class _ImageSize {
  _ImageSize(this.onSize);
  final ValueChanged<Size> onSize;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener((info, _) => onSize(Size(info.image.width.toDouble(), info.image.height.toDouble())), onError: (_, _) {});

  void resolve(ImageProvider image, BuildContext context) {
    final next = image.resolve(createLocalImageConfiguration(context));
    if (next.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = next..addListener(_listener);
  }

  void dispose() => _stream?.removeListener(_listener);
}

/// The size [content] takes when fitted (contain) into [stage].
Size uiFitContain(Size content, Size stage) {
  if (content.isEmpty || stage.isEmpty) return stage;
  final s = math.min(stage.width / content.width, stage.height / content.height);
  return Size(content.width * s, content.height * s);
}

/// `ui-image-viewer`: an image you can zoom (buttons, pinch, double tap, Ctrl+wheel) and pan
/// (drag when zoomed in, the wheel, arrow keys), with Fit to reset.
///
/// With [hasPrevious]/[hasNext] it shows step buttons at the ends of the bar and reads a swipe
/// across the picture (only at fit: a zoomed picture is being read, so the drag pans it), then
/// reports the intent through [onPrevious]/[onNext]: the host owns the list and swaps [image].
/// Left/Right do the same from the keyboard. The picture's swipe is its own and never reaches an
/// enclosing [UiSwipe].
///
/// The viewer bounds itself to [maxHeight] (70% of the screen by default) so the control bar is
/// always on screen.
class UiImageViewer extends StatefulWidget {
  const UiImageViewer({
    super.key,
    required this.image,
    this.alt = '',
    this.hasPrevious = false,
    this.hasNext = false,
    this.onPrevious,
    this.onNext,
    this.maxHeight,
  });

  final ImageProvider image;
  final String alt;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final double? maxHeight;

  @override
  State<UiImageViewer> createState() => _UiImageViewerState();
}

class _Pan extends Intent {
  const _Pan(this.by);
  final Offset by;
}

class _Zoom extends Intent {
  const _Zoom(this.by);
  final double by;
}

class _Nav extends Intent {
  const _Nav(this.dir);
  final int dir;
}

class _UiImageViewerState extends State<UiImageViewer> {
  double _zoom = 1;
  Offset _offset = Offset.zero;
  double _swipe = 0;
  double _swipeDy = 0;
  bool _interacting = false;
  bool _focus = false;
  Size _natural = Size.zero;
  Size _stage = Size.zero;
  late final _ImageSize _size = _ImageSize((s) {
    if (mounted) setState(() => _natural = s);
  });

  // Gesture bookkeeping.
  double _startZoom = 1;
  Offset? _swipeFrom;
  bool _pinched = false;

  bool get _navigable => widget.hasPrevious || widget.hasNext;
  bool get _pannable => _zoom > 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _size.resolve(widget.image, context);
  }

  @override
  void didUpdateWidget(UiImageViewer old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) {
      _size.resolve(widget.image, context);
      _reset();
    }
  }

  @override
  void dispose() {
    _size.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _zoom = 1;
        _offset = Offset.zero;
        // A new image arriving mid-gesture must not inherit the last one's travel.
        _swipe = 0;
      });

  Offset _clamp(Offset o, [double? zoom]) => UiGestures.clampOffset(o, uiFitContain(_natural, _stage), _stage, zoom ?? _zoom);

  void _setZoom(double next) {
    final z = double.parse(next.clamp(_minZoom, _maxZoom).toStringAsFixed(3));
    setState(() {
      _zoom = z;
      // Zooming out can leave the picture off-centre with slack around it; pull it back.
      _offset = _clamp(_offset, z);
    });
  }

  void _toggleZoom() => _zoom > 1 ? _reset() : _setZoom(2);

  void _onScaleStart(ScaleStartDetails d) {
    _startZoom = _zoom;
    _pinched = d.pointerCount > 1;
    _swipeFrom = _pinched ? null : d.focalPoint;
    _swipeDy = 0;
    setState(() => _interacting = true);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount > 1) {
      // A pinch is not a half-finished swipe: drop the candidate.
      _pinched = true;
      _swipeFrom = null;
      _swipe = 0;
      _setZoom(_startZoom * d.scale);
      return;
    }
    if (_pinched) return;
    if (_pannable) {
      setState(() => _offset = _clamp(_offset + d.focalPointDelta));
      return;
    }
    final from = _swipeFrom;
    if (from == null || !_navigable) return;
    final dx = d.focalPoint.dx - from.dx;
    _swipeDy = d.focalPoint.dy - from.dy;
    final blocked = dx > 0 ? !widget.hasPrevious : !widget.hasNext;
    setState(() => _swipe = UiGestures.resist(dx, _stage.width, blocked: blocked));
  }

  void _onScaleEnd(ScaleEndDetails d) {
    final from = _swipeFrom;
    final dx = _swipe;
    _swipeFrom = null;
    setState(() {
      _interacting = false;
      _swipe = 0;
    });
    if (from == null || dx == 0) return;
    // The velocity stands in for the timing: a fast release counts as a flick.
    final speed = d.velocity.pixelsPerSecond.dx.abs() / 1000;
    final ms = speed > 0 ? dx.abs() / speed : 1000.0;
    if (!UiGestures.isSwipe(dx, _swipeDy, ms, _stage.width)) return;
    if (dx < 0 && widget.hasNext) {
      widget.onNext?.call();
    } else if (dx > 0 && widget.hasPrevious) {
      widget.onPrevious?.call();
    }
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final keys = HardwareKeyboard.instance;
    if (keys.isControlPressed || keys.isMetaPressed) {
      GestureBinding.instance.pointerSignalResolver.register(e, (_) => _setZoom(_zoom * (e.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1)));
      return;
    }
    // Scroll around the picture only while it has somewhere left to go, so a wheel over a fitted
    // picture still scrolls the page behind it.
    final to = _clamp(_offset - e.scrollDelta);
    if (to != _offset) GestureBinding.instance.pointerSignalResolver.register(e, (_) => setState(() => _offset = to));
  }

  void _key(Intent i) {
    if (i is _Pan) {
      if (_pannable) {
        setState(() => _offset = _clamp(_offset + i.by));
      } else if (i.by.dy == 0) {
        // Not zoomed: Left/Right ask for the neighbour.
        if (i.by.dx < 0 && widget.hasNext) widget.onNext?.call();
        if (i.by.dx > 0 && widget.hasPrevious) widget.onPrevious?.call();
      }
    } else if (i is _Zoom) {
      _setZoom(_zoom + i.by);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final screenH = MediaQuery.sizeOf(context).height;
    final maxH = widget.maxHeight ?? screenH * 0.7;
    final pct = '${(_zoom * 100).round()}%';
    final touch = uiTouchPlatform(context);

    Map<ShortcutActivator, Intent> pan(LogicalKeyboardKey k, Offset d) => {SingleActivator(k): _Pan(d), SingleActivator(k, shift: true): _Pan(d * 4)};

    final stage = LayoutBuilder(builder: (context, box) {
      _stage = box.biggest;
      final transform = Matrix4.identity()
        ..translateByDouble(_offset.dx + _swipe, _offset.dy, 0, 1)
        ..scaleByDouble(_zoom, _zoom, 1, 1);
      return Listener(
        onPointerSignal: _onSignal,
        child: UiNoSwipe(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            onDoubleTap: _toggleZoom,
            child: ClipRect(
              child: ColoredBox(
                color: t.bg,
                child: AnimatedContainer(
                  // Only eases back to rest: a transition during a pinch makes the picture lag the fingers.
                  duration: _interacting || !context.uiAnimate ? Duration.zero : t.motionFast,
                  curve: t.easeStandard,
                  transform: transform,
                  transformAlignment: Alignment.center,
                  child: Center(
                    child: Image(
                      image: widget.image,
                      fit: BoxFit.contain,
                      // Named by the stage's own semantics node.
                      excludeFromSemantics: true,
                      gaplessPlayback: true,
                      errorBuilder: (context, _, _) => Center(child: UiIcon(HugeIcons.strokeRoundedImage01, size: 32, color: t.textMuted)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });

    final focusable = FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      shortcuts: {
        ...pan(LogicalKeyboardKey.arrowLeft, const Offset(40, 0)),
        ...pan(LogicalKeyboardKey.arrowRight, const Offset(-40, 0)),
        ...pan(LogicalKeyboardKey.arrowUp, const Offset(0, 40)),
        ...pan(LogicalKeyboardKey.arrowDown, const Offset(0, -40)),
        const SingleActivator(LogicalKeyboardKey.equal): const _Zoom(0.25),
        const SingleActivator(LogicalKeyboardKey.add): const _Zoom(0.25),
        const SingleActivator(LogicalKeyboardKey.minus): const _Zoom(-0.25),
        const SingleActivator(LogicalKeyboardKey.digit0): const _Nav(0),
      },
      actions: {
        _Pan: CallbackAction<_Pan>(onInvoke: _key),
        _Zoom: CallbackAction<_Zoom>(onInvoke: _key),
        _Nav: CallbackAction<_Nav>(onInvoke: (_) => _reset()),
      },
      child: Semantics(
        image: true,
        label: widget.alt.isEmpty ? 'Image' : widget.alt,
        value: pct,
        hint: 'Double tap to zoom',
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(boxShadow: uiFocusRing(t, show: _focus)),
          child: stage,
        ),
      ),
    );

    Widget btn(UiIconData icon, String label, VoidCallback? onTap) =>
        UiIconButton(icon: UiIcon(icon), label: label, size: UiSize.sm, onPressed: onTap);

    final bar = Container(
      padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: t.space1),
      decoration: BoxDecoration(color: t.surfaceRaised, border: Border(top: BorderSide(color: t.border))),
      child: Row(spacing: touch ? 0 : t.space1, children: [
        if (_navigable) btn(HugeIcons.strokeRoundedArrowLeft01, 'Previous image', widget.hasPrevious ? widget.onPrevious : null),
        const Spacer(),
        btn(HugeIcons.strokeRoundedMinusSign, 'Zoom out', _zoom <= _minZoom ? null : () => _setZoom(_zoom - 0.25)),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 42),
          child: Text(pct, textAlign: TextAlign.center, style: context.uiText.code.copyWith(fontSize: t.fontSizeSm, fontWeight: FontWeight.w500, color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()])),
        ),
        btn(HugeIcons.strokeRoundedPlusSign, 'Zoom in', _zoom >= _maxZoom ? null : () => _setZoom(_zoom + 0.25)),
        UiButton(label: 'Fit', semanticLabel: 'Reset view', variant: UiButtonVariant.ghost, size: UiSize.sm, onPressed: _reset),
        const Spacer(),
        if (_navigable) btn(HugeIcons.strokeRoundedArrowRight01, 'Next image', widget.hasNext ? widget.onNext : null),
      ]),
    );

    return LayoutBuilder(builder: (context, box) {
      final h = box.maxHeight.isFinite ? math.min(box.maxHeight, maxH) : maxH;
      return SizedBox(
        height: math.max(200, h),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: focusable), bar]),
      );
    });
  }
}
