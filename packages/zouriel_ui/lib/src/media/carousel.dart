import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../behaviors/swipe.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../theme/theme.dart';

/// One slide of a [UiCarousel].
@immutable
class UiCarouselSlide {
  const UiCarouselSlide({required this.image, this.alt, this.caption});

  final ImageProvider image;

  /// Alternative text, read for the slide in view.
  final String? alt;

  /// A line laid over the bottom of the slide on a dark gradient.
  final String? caption;
}

/// A share of the width the finger must travel before letting go turns the slide.
const double _turnShare = 0.18;

/// A quick flick turns it too, however short. px per ms.
const double _flickSpeed = 0.45;

/// `ui-carousel`: a slideshow with a swipe that follows the finger, dots, arrows and optional
/// autoplay.
///
/// A swipe stops at the first and last slide with a little resistance; the arrows (shown only where
/// there is a mouse) wrap around. Each dot is a labelled button at least 24px wide and 48dp tall on
/// touch (48 wide when there is room). [overlay] is laid over the slides (a title, a counter) and a
/// swipe that starts on it still turns the slide. A swipe here is the carousel's own: it never
/// reaches an enclosing [UiSwipe]. For screen readers the carousel is an adjustable control whose
/// value is "Slide 2 of 5", so swiping up and down with TalkBack moves through it.
///
/// [autoplay] turns the slide on a timer, paused while hovered, while focus is inside, mid-swipe,
/// and entirely under reduced motion. Leave [index] null to keep the position here (starting at
/// [initialIndex]), or drive it with [index] + [onIndexChanged].
class UiCarousel extends StatefulWidget {
  const UiCarousel({
    super.key,
    required this.slides,
    this.index,
    this.initialIndex = 0,
    this.onIndexChanged,
    this.autoplay,
    this.dots = true,
    this.arrows = true,
    this.overlay,
    this.aspectRatio = 16 / 9,
    this.maxHeight = 360,
    this.label = 'Carousel',
  });

  final List<UiCarouselSlide> slides;
  final int? index;
  final int initialIndex;
  final ValueChanged<int>? onIndexChanged;

  /// Time between automatic turns; null disables.
  final Duration? autoplay;

  /// The built-in dots. Turn off when drawing your own position marker from [onIndexChanged].
  final bool dots;

  /// The built-in arrows, shown only on platforms with a mouse.
  final bool arrows;
  final Widget? overlay;

  /// Width:height of the slides, capped at [maxHeight].
  final double aspectRatio;
  final double maxHeight;
  final String label;

  @override
  State<UiCarousel> createState() => _UiCarouselState();
}

class _UiCarouselState extends State<UiCarousel> with SingleTickerProviderStateMixin {
  late int _own = widget.initialIndex;
  late final AnimationController _pos = AnimationController.unbounded(vsync: this, value: _index.toDouble());
  double? _drag;
  double _width = 1;
  Timer? _timer;
  bool _hovered = false, _focused = false;

  int get _count => widget.slides.length;
  int get _index => _count == 0 ? 0 : (widget.index ?? _own).clamp(0, _count - 1);

  void _go(int i, {bool animate = true}) {
    if (_count == 0) return;
    final next = i.clamp(0, _count - 1);
    final changed = next != _index;
    if (widget.index == null) setState(() => _own = next);
    if (changed) widget.onIndexChanged?.call(next);
    _animateTo(next, animate: animate);
  }

  void _animateTo(int i, {bool animate = true}) {
    final t = context.ui;
    if (!animate || !context.uiAnimate) {
      _pos.value = i.toDouble();
    } else {
      _pos.animateTo(i.toDouble(), duration: t.motionSlow, curve: t.easeStandard);
    }
  }

  void _next() => _go(_count == 0 ? 0 : (_index + 1) % _count);
  void _prev() => _go(_count == 0 ? 0 : (_index - 1 + _count) % _count);

  @override
  void didUpdateWidget(UiCarousel old) {
    super.didUpdateWidget(old);
    // The parent moved the index (or the list shrank under it): follow.
    if (_drag == null && _pos.value != _index.toDouble() && !_pos.isAnimating) _animateTo(_index);
    if (_count > 0 && _own >= _count) _own = 0;
    if (old.autoplay != widget.autoplay) _restartTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    final ms = widget.autoplay;
    // Reduced motion: nothing turns on its own; arrows, dots and swipes still work.
    if (ms == null || ms <= Duration.zero || !context.uiAnimate) return;
    _timer = Timer.periodic(ms, (_) {
      if (!_hovered && !_focused && _drag == null && mounted) _next();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pos.dispose();
    super.dispose();
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (_count < 2) return;
    final dx = (_drag ?? 0) + d.primaryDelta!;
    _drag = dx;
    // Resistance past either end, so the edge is felt rather than hit.
    final atEdge = (dx > 0 && _index == 0) || (dx < 0 && _index == _count - 1);
    _pos.value = _index - (atEdge ? dx / 3 : dx) / _width;
  }

  void _dragEnd(DragEndDetails d) {
    final dx = _drag;
    _drag = null;
    if (dx == null) return;
    final speed = (d.primaryVelocity ?? 0).abs() / 1000;
    final turn = dx.abs() > _width * _turnShare || speed > _flickSpeed;
    if (turn && dx < 0 && _index < _count - 1) {
      _go(_index + 1);
    } else if (turn && dx > 0 && _index > 0) {
      _go(_index - 1);
    } else {
      _animateTo(_index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    final radius = BorderRadius.circular(context.uiTheme.radius(t.radiusLg));

    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth.isFinite ? box.maxWidth : 390.0;
      _width = math.max(1, w);
      final h = math.min(widget.maxHeight, w / widget.aspectRatio);
      final captionStyle = context.uiText.caption.copyWith(color: t.mediaOnScrim, height: 1.35);

      final track = AnimatedBuilder(
        animation: _pos,
        builder: (context, _) => Stack(clipBehavior: Clip.none, children: [
          for (var i = 0; i < _count; i++)
            if ((i - _pos.value).abs() < 1.5)
              Positioned(
                left: (i - _pos.value) * w,
                top: 0,
                width: w,
                height: h,
                child: ExcludeSemantics(excluding: i != _index, child: _Slide(slide: widget.slides[i], style: captionStyle)),
              ),
        ]),
      );

      final dotW = _count == 0 ? 24.0 : (w / _count).clamp(24.0, touch ? uiMinTouchTarget : 24.0);
      final dotH = touch ? uiMinTouchTarget : 24.0;

      return MouseRegion(
        onEnter: (_) => _hovered = true,
        onExit: (_) => _hovered = false,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (f) => _focused = f,
          child: Semantics(
            container: true,
            label: widget.label,
            value: _count == 0 ? null : 'Slide ${_index + 1} of $_count',
            increasedValue: _index < _count - 1 ? 'Slide ${_index + 2} of $_count' : null,
            decreasedValue: _index > 0 ? 'Slide $_index of $_count' : null,
            onIncrease: _index < _count - 1 ? () => _go(_index + 1) : null,
            onDecrease: _index > 0 ? () => _go(_index - 1) : null,
            child: UiNoSwipe(
              child: ClipRRect(
                borderRadius: radius,
                child: ColoredBox(
                  color: t.bg,
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      dragStartBehavior: DragStartBehavior.down,
                      onHorizontalDragStart: _count < 2 ? null : (_) => _pos.stop(),
                      onHorizontalDragUpdate: _count < 2 ? null : _dragUpdate,
                      onHorizontalDragEnd: _count < 2 ? null : _dragEnd,
                      onHorizontalDragCancel: () {
                        _drag = null;
                        _animateTo(_index);
                      },
                      child: Stack(children: [
                        Positioned.fill(child: track),
                        if (widget.overlay != null) Positioned.fill(child: widget.overlay!),
                        if (_count > 1 && widget.arrows && !touch) ...[
                          Positioned(left: t.space2, top: 0, bottom: 0, child: Center(child: _Arrow(icon: HugeIcons.strokeRoundedArrowLeft01, label: 'Previous slide', onTap: _prev))),
                          Positioned(right: t.space2, top: 0, bottom: 0, child: Center(child: _Arrow(icon: HugeIcons.strokeRoundedArrowRight01, label: 'Next slide', onTap: _next))),
                        ],
                        if (_count > 1 && widget.dots)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              for (var i = 0; i < _count; i++) _Dot(active: i == _index, label: 'Go to slide ${i + 1}', width: dotW, height: dotH, onTap: () => _go(i)),
                            ]),
                          ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.slide, required this.style});
  final UiCarouselSlide slide;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Stack(fit: StackFit.expand, children: [
      Image(
        image: slide.image,
        fit: BoxFit.cover,
        semanticLabel: slide.alt,
        excludeFromSemantics: slide.alt == null,
        gaplessPlayback: true,
        errorBuilder: (context, _, _) => ColoredBox(color: t.surfaceSubtle),
      ),
      if (slide.caption != null)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [t.mediaScrim.withValues(alpha: 0), t.mediaScrim.withValues(alpha: 0.6)],
              ),
            ),
            // Room under the text for the dots.
            child: Padding(
              padding: EdgeInsets.fromLTRB(t.space3, t.space6, t.space3, t.space3 + 24),
              child: Text(slide.caption!, style: style, maxLines: 3, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
    ]);
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.label, required this.onTap});
  final UiIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      semanticLabel: label,
      excludeChildSemantics: true,
      builder: (context, s) => AnimatedContainer(
        duration: context.uiAnimate ? t.motionBase : Duration.zero,
        width: t.sizeTouch,
        height: t.sizeTouch,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: t.mediaScrim.withValues(alpha: s.hovered || s.pressed ? 0.65 : 0.45),
          boxShadow: uiFocusRing(t, show: s.focused),
        ),
        child: Center(child: UiIcon(icon, size: 20, color: t.mediaOnScrim)),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active, required this.label, required this.width, required this.height, required this.onTap});
  final bool active;
  final String label;
  final double width, height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      semanticLabel: label,
      selected: active,
      excludeChildSemantics: true,
      padTouchTarget: false,
      pressScale: false,
      builder: (context, s) => SizedBox(
        width: width,
        height: height,
        child: Center(
          child: AnimatedContainer(
            duration: context.uiAnimate ? t.motionBase : Duration.zero,
            width: 8,
            height: 8,
            transform: Matrix4.diagonal3Values(s.pressed ? t.scalePress : 1, s.pressed ? t.scalePress : 1, 1),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? t.mediaOnScrim : t.mediaOnScrim.withValues(alpha: s.hovered ? 0.75 : 0.5),
              boxShadow: uiFocusRing(t, show: s.focused),
            ),
          ),
        ),
      ),
    );
  }
}
