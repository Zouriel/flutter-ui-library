import 'dart:async' show unawaited;

import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// One screen of a [UiSwipeScreens] (0.44.0, the web `ui-swipe-screen`).
@immutable
class UiSwipeScreen {
  const UiSwipeScreen({required this.child, required this.label, this.edgeSwipeOnly = false});

  final Widget child;

  /// Its name, announced when it becomes the shown screen ("Map").
  final String label;

  /// For a screen whose content takes horizontal drags itself (a map that pans): only a drag that
  /// starts at its leading edge swipes back; every other drag goes to the content.
  final bool edgeSwipeOnly;
}

/// A fast release (logical px per second) moves one screen that way, however short the drag.
const double uiSwipeScreensFlingVelocity = 400;

/// `ui-swipe-screens` (0.44.0): full-size screens side by side that a horizontal drag moves between,
/// like a chat with a map to its right. Screen i+1 sits at the inline end of screen i (right in
/// LTR, left in RTL).
///
/// - The screens follow the finger and snap on release: a fast release
///   ([uiSwipeScreensFlingVelocity]) moves one screen that way, otherwise past half the width moves,
///   else it springs back. No overscroll at either end. Under reduced motion the snap is instant.
/// - Only clearly horizontal drags are taken (more sideways than up or down, past the touch slop),
///   so vertical scrolling inside a screen keeps working.
/// - On the first screen a drag that starts within [leadingEdgeExclusion] of the leading edge is
///   left alone (an app drawer opens from there).
/// - On an [UiSwipeScreen.edgeSwipeOnly] screen only a drag starting in the [edgeWidth] strip at its
///   leading edge swipes, and only back; all other drags go to the content. A tap on the strip goes
///   to what is under it (0.45.1), such as the screen's own Back arrow.
/// - [index] is the shown screen: a new value animates there. A swipe calls [onIndexChanged]; the
///   widget keeps the swiped-to screen even when the parent doesn't pass it back.
/// - Every screen stays alive (state kept) when off screen. Off-screen screens are not painted,
///   hit, focusable or read out, and their tickers stop. When the shown screen changes its label is
///   announced.
class UiSwipeScreens extends StatefulWidget {
  const UiSwipeScreens({
    super.key,
    required this.screens,
    this.index = 0,
    this.onIndexChanged,
    this.leadingEdgeExclusion = 24,
    this.edgeWidth = 24,
  });

  final List<UiSwipeScreen> screens;
  final int index;
  final ValueChanged<int>? onIndexChanged;

  /// On the first screen, how far from the leading edge a drag is left to the app (a drawer).
  final double leadingEdgeExclusion;

  /// How wide the back-swipe strip of an edgeSwipeOnly screen is.
  final double edgeWidth;

  @override
  State<UiSwipeScreens> createState() => UiSwipeScreensState();
}

class UiSwipeScreensState extends State<UiSwipeScreens> with SingleTickerProviderStateMixin {
  /// Where the screens are, in screens: 1.5 is half way between the second and the third.
  late final AnimationController _pos = AnimationController.unbounded(vsync: this, value: _clampIndex(widget.index).toDouble());
  late int _index = _clampIndex(widget.index);
  final GlobalKey _box = GlobalKey();

  /// The drag in progress: where it started, and whether it may only go back.
  double _dragFrom = 0;
  bool _backOnly = false;
  bool _dragging = false;

  /// The screen shown (or being settled on).
  int get index => _index;

  /// Where the screens are while moving, in screens (for tests).
  double get position => _pos.value;

  int _clampIndex(int i) => i.clamp(0, widget.screens.isEmpty ? 0 : widget.screens.length - 1);

  @override
  void initState() {
    super.initState();
    _pos.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(UiSwipeScreens oldWidget) {
    super.didUpdateWidget(oldWidget);
    final i = _clampIndex(widget.index);
    if (i != _clampIndex(oldWidget.index) && i != _index) _settle(i, notify: false);
    if (_index > widget.screens.length - 1) _settle(_clampIndex(_index), notify: false);
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  double get _width {
    final b = _box.currentContext?.findRenderObject() as RenderBox?;
    return b != null && b.hasSize ? b.size.width : 1;
  }

  /// Moves to screen [i]: animated unless animations are off.
  void _settle(int i, {required bool notify}) {
    final changed = i != _index;
    _index = i;
    final target = i.toDouble();
    if (context.uiAnimate && _pos.value != target) {
      final t = context.ui;
      unawaited(_pos.animateTo(target, duration: t.motionBase, curve: t.easeStandard));
    } else {
      _pos.value = target;
    }
    if (!changed) return;
    if (notify) widget.onIndexChanged?.call(i);
    final view = View.maybeOf(context);
    if (view != null) unawaited(SemanticsService.sendAnnouncement(view, widget.screens[i].label, Directionality.of(context)));
  }

  /// Whether a drag may start at [global]: not on an edgeSwipeOnly screen (its strip handles that)
  /// and not in the first screen's leading-edge band.
  bool _allowMain(Offset global) {
    final b = _box.currentContext?.findRenderObject() as RenderBox?;
    if (b == null || widget.screens.length < 2) return false;
    final cur = _pos.value.round().clamp(0, widget.screens.length - 1);
    if (widget.screens[cur].edgeSwipeOnly && !_pos.isAnimating) return false;
    final x = b.globalToLocal(global).dx;
    final fromLeading = _rtl ? b.size.width - x : x;
    if (cur == 0 && _pos.value < 0.5 && fromLeading < widget.leadingEdgeExclusion) return false;
    return true;
  }

  void _start({required bool backOnly}) {
    _pos.stop();
    _dragging = true;
    _dragFrom = _pos.value;
    _backOnly = backOnly;
  }

  void _update(DragUpdateDetails d) {
    if (!_dragging) return;
    final delta = (_rtl ? d.delta.dx : -d.delta.dx) / _width;
    var next = (_pos.value + delta).clamp(0.0, (widget.screens.length - 1).toDouble());
    if (_backOnly && next > _dragFrom) next = _dragFrom;
    _pos.value = next;
  }

  void _end(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    // Forward velocity: toward the next screen.
    final v = _rtl ? d.velocity.pixelsPerSecond.dx : -d.velocity.pixelsPerSecond.dx;
    final p = _pos.value;
    var target = v > uiSwipeScreensFlingVelocity ? p.ceil() : (v < -uiSwipeScreensFlingVelocity ? p.floor() : p.round());
    // One screen per swipe, from where the drag started.
    final from = _dragFrom.round();
    target = target.clamp(from - 1, from + 1).clamp(0, widget.screens.length - 1);
    _settle(target, notify: true);
  }

  void _cancel() {
    if (!_dragging) return;
    _dragging = false;
    _settle(_pos.value.round().clamp(0, widget.screens.length - 1), notify: true);
  }

  GestureRecognizerFactory<UiSwipeDragRecognizer> _recognizer({required bool backOnly, bool Function(Offset global)? allow}) =>
      GestureRecognizerFactoryWithHandlers<UiSwipeDragRecognizer>(
        () => UiSwipeDragRecognizer(debugOwner: this),
        (r) => r
          ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context)
          ..allow = allow
          ..dragStartBehavior = DragStartBehavior.start
          ..onStart = ((_) {
            _start(backOnly: backOnly);
          })
          ..onUpdate = _update
          ..onEnd = _end
          ..onCancel = _cancel,
      );

  @override
  Widget build(BuildContext context) {
    final rtl = _rtl;
    final p = _pos.value;
    return RawGestureDetector(
      key: _box,
      behavior: HitTestBehavior.translucent,
      gestures: {UiSwipeDragRecognizer: _recognizer(backOnly: false, allow: _allowMain)},
      child: ClipRect(
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          return Stack(fit: StackFit.expand, children: [
            for (var i = 0; i < widget.screens.length; i++)
              _screen(i, w, p, rtl),
          ]);
        }),
      ),
    );
  }

  Widget _screen(int i, double w, double p, bool rtl) {
    final s = widget.screens[i];
    final shown = (i - p).abs() < 1 - 1e-9;
    // The same shape in every state, so a screen's state survives every move (keyed by position).
    return KeyedSubtree(
      key: ValueKey('ui-swipe-screen-$i'),
      child: Transform.translate(
        offset: Offset((i - p) * w * (rtl ? -1 : 1), 0),
        child: Offstage(
          offstage: !shown,
          child: TickerMode(
            enabled: shown,
            child: ExcludeFocus(
              excluding: i != _index,
              child: ExcludeSemantics(
                excluding: i != _index,
                child: Stack(fit: StackFit.expand, children: [
                  s.child,
                  // The back-swipe strip of an edgeSwipeOnly screen, over its content at the leading edge.
                  // Translucent (0.45.1): the content under it is hit too, so a tap there still presses
                  // what is under it (a header's Back arrow, the map); a horizontal drag is the strip's,
                  // since its drag accepts at the touch slop, before a map's pan (twice the slop).
                  if (s.edgeSwipeOnly && i > 0)
                    PositionedDirectional(
                      start: 0,
                      top: 0,
                      bottom: 0,
                      width: widget.edgeWidth,
                      child: RawGestureDetector(
                        key: const ValueKey('ui-swipe-screens-edge'),
                        behavior: HitTestBehavior.translucent,
                        excludeFromSemantics: true,
                        gestures: {UiSwipeDragRecognizer: _recognizer(backOnly: true)},
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The swipe screens' drag (exported for tests): a horizontal drag that gives up as soon as the
/// pointer has moved more up or down than sideways (by half the touch slop) before it has moved the
/// slop sideways, so vertical scrolling inside keeps working, and a mostly vertical drag over
/// content that takes no drags (where this would win the arena by default) moves nothing. [allow]
/// can refuse a pointer by where it lands (global position).
class UiSwipeDragRecognizer extends HorizontalDragGestureRecognizer {
  UiSwipeDragRecognizer({super.debugOwner}) {
    // Won by default (nothing else wants the pointer) still starts only past the slop.
    onlyAcceptDragOnThreshold = true;
  }

  bool Function(Offset global)? allow;
  final Map<int, Offset> _down = {};

  /// Pointers that have moved the slop sideways: the drag is theirs.
  final Set<int> _committed = {};

  @override
  bool isPointerAllowed(PointerEvent event) => super.isPointerAllowed(event) && (allow?.call(event.position) ?? true);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _down[event.pointer] = event.position;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    final from = _down[event.pointer];
    if (event is PointerMoveEvent && from != null && !_committed.contains(event.pointer)) {
      final d = event.position - from;
      final slop = gestureSettings?.touchSlop ?? kTouchSlop;
      if (d.distance > slop / 2 && d.dy.abs() >= d.dx.abs()) {
        // Gives the pointer up, whether or not the arena had already handed it over.
        rejectGesture(event.pointer);
        return;
      }
      if (d.dx.abs() > slop) _committed.add(event.pointer);
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _down.remove(event.pointer);
      _committed.remove(event.pointer);
    }
    super.handleEvent(event);
  }

  @override
  void rejectGesture(int pointer) {
    _down.remove(pointer);
    _committed.remove(pointer);
    super.rejectGesture(pointer);
  }

  @override
  String get debugDescription => 'swipe screens drag';
}
