import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'gestures.dart';

/// How close to the screen edge a gesture may begin before it is left to the system back gesture.
const double _edgeGuard = 24;

/// `uiSwipe`: reports a sideways swipe across [child] (to move between tabs or screens) and stays
/// out of the way of everything else the finger might have meant.
///
/// It listens to raw pointers rather than joining the gesture arena, so it never takes a drag from
/// anything: the page still scrolls under the same finger. It fires while the finger is still
/// moving, as soon as the drag qualifies ([UiGestures.isSwipe]), and declines:
/// mostly vertical drags; a second finger; gestures starting within 24px of the screen edge (the
/// system back gesture); anything under the finger that scrolls sideways (a tab strip, a carousel);
/// any subtree wrapped in [UiNoSwipe]; and the mouse unless [mouse] is set.
class UiSwipe extends StatefulWidget {
  const UiSwipe({super.key, required this.child, this.onSwipeLeft, this.onSwipeRight, this.enabled = true, this.mouse = false});

  final Widget child;

  /// The finger travelled leftwards: the next thing.
  final VoidCallback? onSwipeLeft;

  /// The finger travelled rightwards: the previous thing.
  final VoidCallback? onSwipeRight;
  final bool enabled;

  /// Whether a mouse drag counts too.
  final bool mouse;

  @override
  State<UiSwipe> createState() => _UiSwipeState();
}

class _UiSwipeState extends State<UiSwipe> {
  final Set<int> _down = {};
  int? _id;
  Offset _from = Offset.zero;
  Duration _at = Duration.zero;

  void _clear() => _id = null;

  void _onDown(PointerDownEvent e) {
    _down.add(e.pointer);
    // A second finger means this was never a swipe.
    if (_down.length > 1) {
      _clear();
      return;
    }
    if (!widget.enabled) return;
    if (e.kind == PointerDeviceKind.mouse && !widget.mouse) return;
    if (UiNoSwipe._claimed.contains(e.pointer)) return;
    final width = MediaQuery.sizeOf(context).width;
    if (e.position.dx <= _edgeGuard || e.position.dx >= width - _edgeGuard) return;
    _id = e.pointer;
    _from = e.position;
    _at = e.timeStamp;
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _id) return;
    final d = e.position - _from;
    final width = context.size?.width ?? 0;
    if (!UiGestures.isSwipe(d.dx, d.dy, (e.timeStamp - _at).inMicroseconds / 1000, width)) return;
    // Spent: the rest of this drag is following through on a gesture already answered.
    _clear();
    if (d.dx < 0) {
      widget.onSwipeLeft?.call();
    } else {
      widget.onSwipeRight?.call();
    }
  }

  void _onUp(PointerEvent e) {
    _down.remove(e.pointer);
    if (e.pointer == _id) _clear();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollStartNotification>(
      // Something under the finger scrolls sideways: the drag is its own.
      onNotification: (n) {
        if (n.metrics.axis == Axis.horizontal && n.dragDetails != null) _clear();
        return false;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        onPointerCancel: _onUp,
        child: widget.child,
      ),
    );
  }
}

/// Marks a subtree whose drags must never be read as a swipe by an enclosing [UiSwipe] (the web
/// `data-no-swipe`): sliders, signature pads, maps.
class UiNoSwipe extends StatelessWidget {
  const UiNoSwipe({super.key, required this.child});

  final Widget child;

  /// Pointers that went down inside a [UiNoSwipe]. The inner listener sees the down event before
  /// the enclosing [UiSwipe] does, so the swipe can decline it.
  static final Set<int> _claimed = {};

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => _claimed.add(e.pointer),
        onPointerUp: (e) => _claimed.remove(e.pointer),
        onPointerCancel: (e) => _claimed.remove(e.pointer),
        child: child,
      );
}
