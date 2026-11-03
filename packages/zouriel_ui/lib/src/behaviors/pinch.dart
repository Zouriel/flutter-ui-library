import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// How far the two fingers must travel from the baseline, as a share of it, to make one step.
const double _pinchOut = 1.25;
const double _pinchIn = 0.8;

/// One step of a [UiPinch]: which way the fingers went, and where they were when it fired.
@immutable
class UiPinchStep {
  const UiPinchStep({required this.apart, required this.focal});

  /// The fingers moved apart (zoom in); false when they moved together.
  final bool apart;

  /// The midpoint of the two fingers, in global coordinates, when the step fired.
  final Offset focal;

  @override
  String toString() => 'UiPinchStep(apart: $apart, focal: $focal)';
}

/// `uiPinch`: a two-finger pinch reported as steps, not as a scale. For a photo grid that changes
/// its column count, the way a phone's gallery does.
///
/// The distance between the two fingers is taken as a baseline. Once it reaches 1.25 times that
/// ([onPinchOut]) or falls to 0.8 times it ([onPinchIn]), one step fires and the current distance
/// becomes the new baseline, so one long pinch can take several steps. [onPinch] fires just before
/// either of them with the direction and the fingers' midpoint, for a grid that zooms about it. A third finger is ignored;
/// when one of the two lifts while others remain, the next two carry on from a fresh baseline.
/// Fewer than two fingers ends it.
///
/// It listens to raw pointers rather than joining the gesture arena, so it never takes a drag from
/// anything and one finger still scrolls. The web directive also cancels `touchmove` so the browser
/// does not zoom the page; there is nothing like that to stop here.
///
/// Once one finger is down it follows pointers through the global route, not only the [Listener]. An
/// enclosing scroll view that has taken the first finger ignores pointers for everything inside it
/// (`Scrollable`'s `IgnorePointer`), so a second finger landing inside such a view is never hit-tested
/// to this widget. A global route only watches, so it takes nothing from the arena either. A finger
/// landing within this widget's bounds then counts, whatever is drawn over that spot.
class UiPinch extends StatefulWidget {
  const UiPinch({super.key, required this.child, this.onPinchIn, this.onPinchOut, this.onPinch, this.enabled = true});

  final Widget child;

  /// The fingers moved together.
  final VoidCallback? onPinchIn;

  /// The fingers moved apart.
  final VoidCallback? onPinchOut;

  /// Every step, with its direction and focal point; fires right before [onPinchIn] / [onPinchOut].
  final ValueChanged<UiPinchStep>? onPinch;

  /// Turns the gesture off without unmounting it.
  final bool enabled;

  @override
  State<UiPinch> createState() => _UiPinchState();
}

class _UiPinchState extends State<UiPinch> {
  /// Fingers on this widget, oldest first (a map literal keeps insertion order).
  final Map<int, Offset> _fingers = {};
  double _baseline = 0;

  /// The distance between the two oldest fingers; null without two.
  double? get _distance {
    if (_fingers.length < 2) return null;
    final pair = _fingers.values.take(2).toList();
    return (pair[0] - pair[1]).distance;
  }

  /// The midpoint of the two oldest fingers (only called with two).
  Offset get _focal {
    final pair = _fingers.values.take(2).toList();
    return (pair[0] + pair[1]) / 2;
  }

  bool _inPair(int pointer) => _fingers.keys.take(2).contains(pointer);

  bool _isInside(Offset global) {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize && box.size.contains(box.globalToLocal(global));
  }

  @override
  void didUpdateWidget(UiPinch old) {
    super.didUpdateWidget(old);
    if (!widget.enabled) _reset();
  }

  @override
  void dispose() {
    _reset();
    super.dispose();
  }

  void _reset() {
    if (_fingers.isNotEmpty) GestureBinding.instance.pointerRouter.removeGlobalRoute(_route);
    _fingers.clear();
    _baseline = 0;
  }

  /// Every pointer on the screen, while at least one finger is on this widget.
  void _route(PointerEvent e) {
    if (e is PointerDownEvent) {
      if (_isInside(e.position)) _onDown(e);
    } else if (e is PointerMoveEvent) {
      _onMove(e);
    } else if (e is PointerUpEvent || e is PointerCancelEvent) {
      _onEnd(e);
    }
  }

  void _onDown(PointerDownEvent e) {
    // The route sees a down the Listener has already handled.
    if (!widget.enabled || e.kind != PointerDeviceKind.touch || _fingers.containsKey(e.pointer)) return;
    if (_fingers.isEmpty) GestureBinding.instance.pointerRouter.addGlobalRoute(_route);
    _fingers[e.pointer] = e.position;
    if (_fingers.length == 2) _baseline = _distance!;
  }

  void _onMove(PointerMoveEvent e) {
    if (!_fingers.containsKey(e.pointer)) return;
    _fingers[e.pointer] = e.position;
    final distance = _distance;
    if (distance == null) return;

    // Fingers landing on the same spot: there is nothing to take a share of yet.
    if (_baseline <= 0) {
      _baseline = distance;
    } else if (distance >= _baseline * _pinchOut) {
      _baseline = distance;
      widget.onPinch?.call(UiPinchStep(apart: true, focal: _focal));
      widget.onPinchOut?.call();
    } else if (distance <= _baseline * _pinchIn) {
      _baseline = distance;
      widget.onPinch?.call(UiPinchStep(apart: false, focal: _focal));
      widget.onPinchIn?.call();
    }
  }

  void _onEnd(PointerEvent e) {
    final wasInPair = _inPair(e.pointer);
    if (_fingers.remove(e.pointer) == null) return;
    // A change of pair starts a fresh baseline, so it can't read as a step.
    if (wasInPair) _baseline = _distance ?? 0;
    if (_fingers.isEmpty) GestureBinding.instance.pointerRouter.removeGlobalRoute(_route);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      child: widget.child,
    );
  }
}
