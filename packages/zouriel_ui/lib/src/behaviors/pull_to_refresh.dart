import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart';

import '../feedback/shutter_loader.dart';
import '../theme/theme.dart';

/// The ball's round chip and the shutter inside it.
const double _chip = 40;
const double _mark = 28;

/// The rubber band: how far the ball travels for a pull, `maxDrop * (1 - exp(-pull / k))`. It
/// slows as it goes and never passes [_maxDrop].
const double _maxDrop = 110;
const double _k = 70;

double _rubber(double pull) => pull <= 0 ? 0 : _maxDrop * (1 - math.exp(-pull / _k));

/// Where a refreshing ball rests: its centre 56 px in from the edge (as a drop, the chip's far side).
const double _restDrop = 56 + _chip / 2;

/// Finger travel past each end of a vertical scroll view, read from its scroll notifications (no
/// gesture recognizer, so nothing competes with the content's own taps, long presses and pinches).
///
/// Works for clamping physics (Android), where the overscroll arrives as [OverscrollNotification],
/// and bouncing physics (iOS), where the position goes past its ends; flings and their bounces
/// don't count, only a finger.
class _PullTracker {
  /// Travel past the leading end (the top of a normal list) and the trailing end.
  double leading = 0;
  double trailing = 0;

  /// Whether a finger is dragging.
  bool dragging = false;

  /// Feeds [n]: a finger's travel past an end adds to that end's pull; the drag ending clears both.
  void handle(ScrollNotification n) {
    final DragUpdateDetails? d;
    if (n is ScrollStartNotification) {
      dragging = n.dragDetails != null;
      return;
    } else if (n is OverscrollNotification) {
      d = n.dragDetails;
    } else if (n is ScrollUpdateNotification) {
      d = n.dragDetails;
    } else if (n is ScrollEndNotification) {
      _end();
      return;
    } else {
      return;
    }
    if (d == null) {
      _end();
      return;
    }
    dragging = true;
    final m = n.metrics;
    // Finger travel toward the leading end's reveal: down on a normal list, up on a reversed one.
    final f = m.axisDirection == AxisDirection.up ? -d.delta.dy : d.delta.dy;
    if (n is OverscrollNotification) {
      if (n.overscroll < 0) {
        leading = math.max(0, leading + f);
      } else if (n.overscroll > 0) {
        trailing = math.max(0, trailing - f);
      }
      return;
    }
    if (m.pixels < m.minScrollExtent) {
      leading = math.max(0, leading + f);
    } else if (m.pixels > m.maxScrollExtent) {
      trailing = math.max(0, trailing - f);
    } else {
      // Back inside the content: travel the other way takes the pull back first.
      if (leading > 0) leading = math.max(0, leading + f);
      if (trailing > 0) trailing = math.max(0, trailing - f);
    }
  }

  void _end() {
    dragging = false;
    leading = 0;
    trailing = 0;
  }
}

/// The ball: a small raised round chip holding the shutter, [drop] px in from its edge (0 hidden,
/// [_chip] fully in). Fades in over its first [_chip] px.
class _Ball extends StatelessWidget {
  const _Ball({required this.drop, required this.busy, required this.turn});

  final double drop;
  final bool busy;
  final double turn;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return IgnorePointer(
      child: Opacity(
        opacity: (drop / _chip).clamp(0.0, 1.0),
        child: Container(
          width: _chip,
          height: _chip,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: t.surfaceRaised, shape: BoxShape.circle, boxShadow: t.shadow2),
          child: busy
              ? UiShutterLoader(size: _mark, color: t.primary, decorative: true)
              : SizedBox.square(dimension: _mark, child: UiShutterMark(color: t.primary, turn: turn)),
        ),
      ),
    );
  }
}

/// Places a ball [drop] px in from the top (or the bottom when not [top]) of a stack, centred.
Widget _placed({required bool top, required double drop, required Widget ball}) => Positioned(
      left: 0,
      right: 0,
      top: top ? drop - _chip : null,
      bottom: top ? null : drop - _chip,
      child: Align(alignment: top ? Alignment.topCenter : Alignment.bottomCenter, heightFactor: 1, child: ball),
    );

/// How far the ball turns for a drop: two thirds of a turn by the time it reaches its resting spot.
double _turnFor(double drop) => drop / _restDrop * math.pi * 2 / 3;

/// The overscroll "shutter ball" `UiScrollBehavior` shows on vertical scroll views with
/// `UiConfig(overscroll: UiOverscrollStyle.shutter)` (0.72.0): pulling past the top drops it in from
/// the top edge with the finger, past the bottom it rises from the bottom; on release it springs
/// back. Like the platform indicators it asks first ([OverscrollIndicatorNotification]), so a
/// [UiPullToRefresh] around the list takes the top for itself.
class UiShutterOverscroll extends StatefulWidget {
  const UiShutterOverscroll({super.key, required this.axisDirection, required this.child});

  final AxisDirection axisDirection;
  final Widget child;

  @override
  State<UiShutterOverscroll> createState() => _UiShutterOverscrollState();
}

class _UiShutterOverscrollState extends State<UiShutterOverscroll> with TickerProviderStateMixin {
  final _pull = _PullTracker();
  late final AnimationController _lead = AnimationController.unbounded(vsync: this);
  late final AnimationController _trail = AnimationController.unbounded(vsync: this);

  /// Whether each end may show (null until asked for this drag).
  bool? _leadOk;
  bool? _trailOk;

  @override
  void dispose() {
    _lead.dispose();
    _trail.dispose();
    super.dispose();
  }

  bool _ask(bool leading) {
    final n = _Ask(leading: leading);
    n.dispatch(context);
    return !n.refused;
  }

  void _settle(AnimationController c) {
    if (c.value == 0 || c.isAnimating) return;
    if (!context.uiAnimate) {
      c.value = 0;
    } else {
      c.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    _pull.handle(n);
    if (!_pull.dragging) {
      _leadOk = _trailOk = null;
      _settle(_lead);
      _settle(_trail);
      return false;
    }
    if (_pull.leading > 0) {
      _leadOk ??= _ask(true);
      if (_leadOk!) _lead.value = _rubber(_pull.leading);
    } else {
      _leadOk = null;
      _settle(_lead);
    }
    if (_pull.trailing > 0) {
      _trailOk ??= _ask(false);
      if (_trailOk!) _trail.value = _rubber(_pull.trailing);
    } else {
      _trailOk = null;
      _settle(_trail);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // The leading end is the top of a normal list and the bottom of a reversed one.
    final leadTop = widget.axisDirection != AxisDirection.up;
    Widget ball(AnimationController c, bool top) => AnimatedBuilder(
          animation: c,
          builder: (context, _) => c.value <= 0
              ? const Positioned(top: 0, left: 0, child: SizedBox.shrink())
              : _placed(top: top, drop: c.value, ball: _Ball(drop: c.value, busy: false, turn: _turnFor(c.value) * (top ? 1 : -1))),
        );
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.hardEdge,
        children: [widget.child, ball(_lead, leadTop), ball(_trail, !leadTop)],
      ),
    );
  }
}

/// Asks the widgets above whether an end's indicator may show (a [UiPullToRefresh] says no).
class _Ask extends OverscrollIndicatorNotification {
  _Ask({required super.leading});

  bool refused = false;

  @override
  void disallowIndicator() {
    super.disallowIndicator();
    refused = true;
  }
}

/// Pull to refresh (0.72.0, Flutter only: browsers own the gesture on the web). Wrap a vertical
/// scroll view ([ListView], [GridView], [CustomScrollView]…): pulling down at its top (up at the
/// bottom of a reversed list) drops in the
/// shutter ball; past [threshold] px of finger travel the ball snaps to its resting spot with a
/// selection click and clicks its blades while [onRefresh] runs, then slides back up when the
/// future completes (or throws: the error is reported and the ball still goes).
///
/// It reads scroll notifications rather than adding a gesture recognizer, so the content's own taps,
/// long presses, double taps and pinches are untouched. Clamping (Android) and bouncing (iOS)
/// physics both work; a list shorter than the screen still needs to be scrollable
/// ([AlwaysScrollableScrollPhysics], which a vertical [ListView] gets by default). Screen readers get
/// a "Refresh" action. A pull or that action while a refresh runs does nothing.
class UiPullToRefresh extends StatefulWidget {
  const UiPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.threshold = 80,
    this.enabled = true,
    this.notificationPredicate = defaultScrollNotificationPredicate,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  /// Finger travel past the top that starts a refresh.
  final double threshold;

  /// Off: pulls show the scroll view's usual overscroll and never refresh.
  final bool enabled;

  /// Which scroll notifications to follow; the default takes the scroll view directly inside (depth
  /// 0). Inside a [NestedScrollView], follow the inner one with `(n) => n.depth == 1`.
  final ScrollNotificationPredicate notificationPredicate;

  @override
  State<UiPullToRefresh> createState() => _UiPullToRefreshState();
}

class _UiPullToRefreshState extends State<UiPullToRefresh> with SingleTickerProviderStateMixin {
  final _pull = _PullTracker();
  late final AnimationController _drop = AnimationController.unbounded(vsync: this);
  bool _busy = false;

  /// Whether the list's leading end (where the ball comes from) is its top; a reversed list's is
  /// its bottom.
  bool _top = true;
  double? _target;

  /// After a refresh starts, the same drag can't start another; the finger must lift first.
  bool _spent = false;

  @override
  void dispose() {
    _drop.dispose();
    super.dispose();
  }

  void _moveTo(double target, {required Duration duration}) {
    // Scroll notifications keep coming while it moves; restarting each time would never arrive.
    if (_drop.value == target || (_drop.isAnimating && _target == target)) return;
    _target = target;
    if (!context.uiAnimate) {
      _drop.value = target;
    } else {
      _drop.animateTo(target, duration: duration, curve: Curves.easeOutCubic);
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (!widget.enabled || !widget.notificationPredicate(n) || n.metrics.axis != Axis.vertical) return false;
    _pull.handle(n);
    final top = n.metrics.axisDirection != AxisDirection.up;
    if (top != _top) setState(() => _top = top);
    if (!_pull.dragging) {
      _spent = false;
      if (!_busy) _moveTo(0, duration: const Duration(milliseconds: 300));
      return false;
    }
    if (_busy || _spent) return false;
    if (_pull.leading >= widget.threshold) {
      _spent = true;
      _refresh();
    } else {
      _drop.value = _rubber(_pull.leading);
    }
    return false;
  }

  // Keeps the scroll view's own indicator off the top while this ball has it.
  bool _onIndicator(OverscrollIndicatorNotification n) {
    if (n.depth != 0 || !n.leading || !widget.enabled) return false;
    n.disallowIndicator();
    return true;
  }

  Future<void> _refresh() async {
    if (_busy || !widget.enabled) return;
    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    _moveTo(_restDrop, duration: const Duration(milliseconds: 200));
    try {
      await widget.onRefresh();
    } catch (e, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stack,
        library: 'zouriel_ui',
        context: ErrorDescription('while running UiPullToRefresh.onRefresh'),
      ));
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _moveTo(0, duration: const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      customSemanticsActions: widget.enabled ? {CustomSemanticsAction(label: context.uiStrings.refresh): _refresh} : null,
      child: NotificationListener<OverscrollIndicatorNotification>(
        onNotification: _onIndicator,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: _RefreshStack(drop: _drop, busy: _busy, top: _top, child: widget.child),
        ),
      ),
    );
  }
}

class _RefreshStack extends StatelessWidget {
  const _RefreshStack({required this.drop, required this.busy, required this.top, required this.child});

  final AnimationController drop;
  final bool busy;
  final bool top;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.hardEdge,
      children: [
        child,
        AnimatedBuilder(
          animation: drop,
          builder: (context, _) => drop.value <= 0
              ? const Positioned(top: 0, left: 0, child: SizedBox.shrink())
              : _placed(top: top, drop: drop.value, ball: _Ball(drop: drop.value, busy: busy, turn: _turnFor(drop.value))),
        ),
      ],
    );
  }
}
