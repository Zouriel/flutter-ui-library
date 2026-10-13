import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'modal.dart';
import 'route.dart';

/// The edge a drawer slides in from, the web `UiDrawerSide`. Left and right are physical sides.
enum UiDrawerSide { left, right, top, bottom }

/// Opens a [UiDrawer] on a [UiDialogRoute]; completes with what it is popped with.
///
/// It slides in from [side]. The barrier closes it when [closeOnBackdrop], Escape when
/// [closeOnEscape], and the Android back button and a swipe toward its edge always do.
Future<T?> showUiDrawer<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  UiDrawerSide side = UiDrawerSide.right,
  String? title,
  bool closeOnBackdrop = true,
  bool closeOnEscape = true,
  bool? glass,
  bool? radius,
  bool useRootNavigator = true,
  RouteSettings? settings,
}) {
  final t = context.ui;
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(UiDialogRoute<T>.themed(
    context,
    dismissible: closeOnBackdrop,
    settings: settings,
    duration: t.motionSlow,
    reverse: t.motionBase,
    transitions: (context, animation, child) => uiSheetTransition(context, animation, child, side),
    builder: (context) => UiDrawer(side: side, title: title, closeOnEscape: closeOnEscape, glass: glass, radius: radius, child: Builder(builder: builder)),
  ));
}

/// The web `ui-sheet-enter` / `ui-sheet-leave`: slides fully in from [side], decelerating in and
/// accelerating out; a finger dragging it moves it one to one. A plain fade under reduced motion.
Widget uiSheetTransition(BuildContext context, Animation<double> animation, Widget child, UiDrawerSide side) {
  final t = context.ui;
  final route = UiDialogRoute.maybeOf(context);
  final from = switch (side) {
    UiDrawerSide.left => const Offset(-1, 0),
    UiDrawerSide.right => const Offset(1, 0),
    UiDrawerSide.top => const Offset(0, -1),
    UiDrawerSide.bottom => const Offset(0, 1),
  };
  final curved = _DragAwareCurve(animation, route, t.easeDecelerate, t.easeAccelerate);
  return SlideTransition(position: Tween(begin: from, end: Offset.zero).animate(curved), child: child);
}

/// Curved while the route animates on its own; linear while a finger drives it.
class _DragAwareCurve extends Animation<double> with AnimationWithParentMixin<double> {
  _DragAwareCurve(this.parent, this.route, this.curve, this.reverseCurve);

  @override
  final Animation<double> parent;
  final UiDialogRoute<dynamic>? route;
  final Curve curve, reverseCurve;

  @override
  double get value {
    final v = parent.value;
    if (route?.dragging ?? false) return v;
    return parent.status == AnimationStatus.reverse ? 1 - reverseCurve.transform(1 - v) : curve.transform(v);
  }
}

/// `ui-drawer`: an edge-anchored panel with a header (title and close button) and a scrolling
/// body. Left and right drawers are up to 360px wide (90% of a phone); top and bottom ones up to
/// 320px tall (80%). Open it with [showUiDrawer]: the route gives it the backdrop, focus trap and
/// focus return, and back-button closing. On touch it follows a swipe toward its edge and closes
/// when flung or let go past half way. Escape closes it unless [closeOnEscape] is false.
class UiDrawer extends StatelessWidget {
  const UiDrawer({
    super.key,
    required this.child,
    this.side = UiDrawerSide.right,
    this.title,
    this.closeOnEscape = true,
    this.glass,
    this.radius,
    this.onClose,
  });

  final Widget child;
  final UiDrawerSide side;
  final String? title;
  final bool closeOnEscape;
  final bool? glass;
  final bool? radius;
  final VoidCallback? onClose;

  bool get _horizontal => side == UiDrawerSide.left || side == UiDrawerSide.right;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final mq = MediaQuery.of(context);
    final isGlass = glass ?? theme.config.glass;
    final rr = (radius ?? theme.config.radius) ? Radius.circular(t.radiusLg) : Radius.zero;
    final close = onClose ?? () => Navigator.maybePop(context);
    final shape = switch (side) {
      UiDrawerSide.left => BorderRadius.only(topRight: rr, bottomRight: rr),
      UiDrawerSide.right => BorderRadius.only(topLeft: rr, bottomLeft: rr),
      UiDrawerSide.top => BorderRadius.only(bottomLeft: rr, bottomRight: rr),
      UiDrawerSide.bottom => BorderRadius.only(topLeft: rr, topRight: rr),
    };
    // Keep content clear of the notch and the gesture bar on the edges the panel touches.
    final inset = EdgeInsets.only(
      top: side != UiDrawerSide.bottom ? mq.padding.top : 0,
      bottom: side != UiDrawerSide.top ? mq.padding.bottom : 0,
      left: side == UiDrawerSide.left || !_horizontal ? mq.padding.left : 0,
      right: side == UiDrawerSide.right || !_horizontal ? mq.padding.right : 0,
    );

    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        color: isGlass ? t.glassBg : t.surface,
        borderRadius: shape,
        border: Border.all(color: isGlass ? t.glassBorder : t.border),
        boxShadow: t.shadow3,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: Padding(
          padding: inset,
          child: DefaultTextStyle.merge(
            style: const TextStyle(height: 1.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null) UiDialogHeader(title: title!, onClose: close),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space3),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (isGlass) {
      panel = ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: t.glassBlur, sigmaY: t.glassBlur), child: panel),
      );
    }
    panel = UiDialogScope(label: title, closeOnEscape: closeOnEscape, onClose: close, child: panel);

    final size = mq.size;
    final extent = _horizontal ? math.min(360.0, size.width * 0.9) : math.min(320.0, size.height * 0.8);
    panel = SizedBox(width: _horizontal ? extent : double.infinity, height: _horizontal ? double.infinity : extent, child: panel);
    // The route slides the whole screen-sized layer, so a finger maps onto the screen's extent.
    panel = _SwipeToClose(side: side, extent: _horizontal ? size.width : size.height, child: panel);
    return Align(
      alignment: switch (side) {
        UiDrawerSide.left => Alignment.centerLeft,
        UiDrawerSide.right => Alignment.centerRight,
        UiDrawerSide.top => Alignment.topCenter,
        UiDrawerSide.bottom => Alignment.bottomCenter,
      },
      child: panel,
    );
  }
}

/// Follows a drag toward [side] by moving the route's animation, then closes or settles back.
class _SwipeToClose extends StatelessWidget {
  const _SwipeToClose({required this.side, required this.extent, required this.child});

  final UiDrawerSide side;
  final double extent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = UiDialogRoute.maybeOf(context);
    if (route == null) return child;
    // Positive when the finger moves toward the edge the drawer lives on (closing it).
    final sign = side == UiDrawerSide.left || side == UiDrawerSide.top ? -1.0 : 1.0;
    void update(double delta) => route.dragUpdate(-sign * delta / extent);
    void end(double velocity) => route.dragEnd(-sign * velocity / extent);
    final horizontal = side == UiDrawerSide.left || side == UiDrawerSide.right;
    return GestureDetector(
      excludeFromSemantics: true,
      onHorizontalDragUpdate: horizontal ? (d) => update(d.delta.dx) : null,
      onHorizontalDragEnd: horizontal ? (d) => end(d.velocity.pixelsPerSecond.dx) : null,
      onHorizontalDragCancel: horizontal ? () => route.dragEnd(0) : null,
      onVerticalDragUpdate: horizontal ? null : (d) => update(d.delta.dy),
      onVerticalDragEnd: horizontal ? null : (d) => end(d.velocity.pixelsPerSecond.dy),
      onVerticalDragCancel: horizontal ? null : () => route.dragEnd(0),
      child: child,
    );
  }
}
