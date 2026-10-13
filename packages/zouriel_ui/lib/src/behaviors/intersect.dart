import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// `uiIntersect`: reports whether [child] is on screen. [onChange] gets the first state once laid
/// out (false when it starts out of view), then each change as the enclosing scroll views move or
/// the window resizes.
///
/// "On screen" means at least [threshold] of its area (0: any of it) is inside the window and every
/// enclosing scroll view, with [rootMargin] growing (or, negative, shrinking) that area like the
/// web IntersectionObserver's `rootMargin`. With [once] it stops after the first true.
class UiIntersect extends StatefulWidget {
  const UiIntersect({super.key, required this.child, required this.onChange, this.once = false, this.threshold = 0, this.rootMargin = EdgeInsets.zero});

  final Widget child;
  final ValueChanged<bool> onChange;
  final bool once;

  /// Fraction of the child's area that must be visible, 0–1.
  final double threshold;
  final EdgeInsets rootMargin;

  /// The fraction of [box] visible inside the window and every scrollable above [context].
  static double visibleFraction(BuildContext context, RenderBox box, {EdgeInsets margin = EdgeInsets.zero}) {
    if (!box.attached || !box.hasSize) return 0;
    final rect = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
    var clip = margin.inflateRect(Offset.zero & MediaQuery.sizeOf(context));
    var scrollable = Scrollable.maybeOf(context);
    while (scrollable != null) {
      final r = scrollable.context.findRenderObject();
      if (r is RenderBox && r.attached && r.hasSize) {
        clip = clip.intersect(margin.inflateRect(MatrixUtils.transformRect(r.getTransformTo(null), Offset.zero & r.size)));
      }
      scrollable = Scrollable.maybeOf(scrollable.context);
    }
    // A box with no area (a zero-width marker) is visible when it touches the visible area at all.
    if (rect.width <= 0 || rect.height <= 0) return clip.overlaps(rect.inflate(0.5)) ? 1 : 0;
    final hit = rect.intersect(clip);
    if (hit.width <= 0 || hit.height <= 0) return 0;
    return (hit.width * hit.height) / (rect.width * rect.height);
  }

  @override
  State<UiIntersect> createState() => _UiIntersectState();
}

class _UiIntersectState extends State<UiIntersect> with WidgetsBindingObserver {
  final List<ScrollPosition> _positions = [];
  bool? _last;
  bool _done = false;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listen();
    _schedule();
  }

  @override
  void didUpdateWidget(UiIntersect oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  @override
  void didChangeMetrics() => _schedule();

  void _listen() {
    for (final p in _positions) {
      p.removeListener(_schedule);
    }
    _positions.clear();
    var s = Scrollable.maybeOf(context);
    while (s != null) {
      _positions.add(s.position..addListener(_schedule));
      s = Scrollable.maybeOf(s.context);
    }
  }

  void _schedule() {
    if (_done || _scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _check();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _check() {
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final f = UiIntersect.visibleFraction(context, box, margin: widget.rootMargin);
    final visible = widget.threshold <= 0 ? f > 0 : f >= widget.threshold;
    if (visible == _last) return;
    _last = visible;
    widget.onChange(visible);
    if (visible && widget.once) {
      _done = true;
      _unlisten();
    }
  }

  void _unlisten() {
    for (final p in _positions) {
      p.removeListener(_schedule);
    }
    _positions.clear();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unlisten();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
