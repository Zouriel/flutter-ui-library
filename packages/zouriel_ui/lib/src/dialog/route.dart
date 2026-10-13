import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// How a [UiDialogRoute] animates its content in and out.
typedef UiRouteTransitions = Widget Function(BuildContext context, Animation<double> animation, Widget child);

/// The route every library dialog opens on (modal, drawer, confirm, command palette).
///
/// A [PopupRoute], so Flutter does the heavy lifting the web does by hand: the page beneath stays
/// visible behind a dimmed barrier (`--ui-color-overlay`) that blocks taps and scrolling, the
/// route gets its own focus scope (Tab cycles inside it, and focus goes back to where it was when
/// it closes), screen readers can't reach what's underneath, and the Android back button closes
/// it. Tapping the barrier closes it when [dismissible]. Escape is handled by the content (see
/// [UiModal.closeOnEscape]).
///
/// It can also follow a finger: [dragUpdate] / [dragEnd] move the route's animation directly, for
/// swipe-to-close.
class UiDialogRoute<T> extends PopupRoute<T> {
  UiDialogRoute({
    required this.builder,
    required this.barrierTint,
    this.dismissible = true,
    this.label = 'Close',
    this.duration = const Duration(milliseconds: 200),
    this.reverse = const Duration(milliseconds: 200),
    this.transitions,
    super.settings,
  });

  /// A route styled from [context]'s theme: the overlay tint, and the theme's motion (none when
  /// animations are off).
  factory UiDialogRoute.themed(
    BuildContext context, {
    required WidgetBuilder builder,
    bool dismissible = true,
    Duration? duration,
    Duration? reverse,
    UiRouteTransitions? transitions,
    RouteSettings? settings,
  }) {
    final t = context.ui;
    final animate = context.uiAnimate;
    return UiDialogRoute<T>(
      builder: builder,
      barrierTint: t.overlay,
      dismissible: dismissible,
      duration: animate ? (duration ?? t.motionBase) : Duration.zero,
      reverse: animate ? (reverse ?? t.motionBase) : Duration.zero,
      transitions: transitions,
      settings: settings,
    );
  }

  final WidgetBuilder builder;
  final Color barrierTint;
  final bool dismissible;

  /// The barrier's name for screen readers.
  final String label;
  final Duration duration;
  final Duration reverse;
  final UiRouteTransitions? transitions;

  /// The [UiDialogRoute] that [context] is in, if any.
  static UiDialogRoute<dynamic>? maybeOf(BuildContext context) {
    final r = ModalRoute.of(context);
    return r is UiDialogRoute ? r : null;
  }

  @override
  Color? get barrierColor => barrierTint;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => label;

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration => reverse;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      Builder(builder: builder);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) =>
      transitions == null ? child : transitions!(context, animation, child);

  /// Whether a finger is moving the route right now.
  bool get dragging => _dragging;
  bool _dragging = false;

  /// Moves the route's animation by [fraction] of its travel (negative closes), for swipe-to-close.
  void dragUpdate(double fraction) {
    if (!isActive) return;
    _dragging = true;
    controller!.value = (controller!.value + fraction).clamp(0.0, 1.0);
  }

  /// Ends a drag: closes when flung toward closing ([velocity] in route-fractions per second,
  /// negative closes) or let go past half way; otherwise settles back open.
  void dragEnd(double velocity) {
    if (!_dragging) return;
    _dragging = false;
    if (!isActive) return;
    if (velocity < -1 || (velocity <= 1 && controller!.value < 0.5)) {
      navigator?.pop();
    } else {
      controller!.forward();
    }
  }
}
