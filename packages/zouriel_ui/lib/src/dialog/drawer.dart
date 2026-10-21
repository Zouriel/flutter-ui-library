import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../layout/pinned_edges.dart';
import '../theme/theme.dart';
import 'modal.dart';
import 'route.dart';

export '../layout/pinned_edges.dart' show UiScrollBodyBuilder;

/// The edge a drawer slides in from, the web `UiDrawerSide`. Left and right are physical sides.
enum UiDrawerSide { left, right, top, bottom }

/// Opens a [UiDrawer] on a [UiDialogRoute]; completes with what it is popped with.
///
/// It slides in from [side]. The barrier closes it when [closeOnBackdrop], Escape when
/// [closeOnEscape], and the Android back button and a swipe toward its edge always do.
///
/// The body is [builder] (wrapped in a scroll view) or [bodyBuilder] (a scroll view of your own,
/// such as a paging `ListView`, given the drawer's controller). [headerBuilder] and [footerBuilder]
/// build the fixed parts above and below it (the web `[drawer-header]` / `[drawer-footer]`).
Future<T?> showUiDrawer<T>({
  required BuildContext context,
  WidgetBuilder? builder,
  UiScrollBodyBuilder? bodyBuilder,
  WidgetBuilder? headerBuilder,
  WidgetBuilder? footerBuilder,
  UiDrawerSide side = UiDrawerSide.right,
  String? title,
  bool closeOnBackdrop = true,
  bool closeOnEscape = true,
  bool? glass,
  bool? radius,
  bool useRootNavigator = true,
  RouteSettings? settings,
}) {
  assert((builder == null) != (bodyBuilder == null), 'Give showUiDrawer either builder or bodyBuilder');
  final t = context.ui;
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    UiDialogRoute<T>.themed(
      context,
      dismissible: closeOnBackdrop,
      settings: settings,
      duration: t.motionSlow,
      reverse: t.motionBase,
      transitions: (context, animation, child) => uiSheetTransition(context, animation, child, side),
      builder: (context) => UiDrawer(
        side: side,
        title: title,
        closeOnEscape: closeOnEscape,
        glass: glass,
        radius: radius,
        header: headerBuilder == null ? null : Builder(builder: headerBuilder),
        footer: footerBuilder == null ? null : Builder(builder: footerBuilder),
        bodyBuilder: bodyBuilder,
        child: builder == null ? null : Builder(builder: builder),
      ),
    ),
  );
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
  return SlideTransition(
    position: Tween(begin: from, end: Offset.zero).animate(curved),
    child: child,
  );
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

/// `ui-drawer`: an edge-anchored panel with a title bar (title and close button), an optional fixed
/// [header], the body (the only part that scrolls) and an optional fixed [footer], which stays at
/// the bottom of the panel clear of the system's safe area (and, on a full-height drawer, the
/// keyboard). A hairline shows under [header] while the body is scrolled away from its top, and over
/// [footer] while more of the body is below it. The body is [child] in a scroll view, or
/// [bodyBuilder]'s own scroll view (a paging `ListView`) given the drawer's controller; pad it with
/// [UiDrawer.bodyPadding]. Left and right drawers are up to 360px wide (90% of a phone); top and bottom ones up to
/// 320px tall (80%). A bottom drawer rests on the on-screen keyboard while it is up (0.41.3), its
/// height taken from the space above it, so its fields and footer stay in view. Open it with [showUiDrawer]: the route gives it the backdrop, focus trap and
/// focus return, and back-button closing. On touch it follows a swipe toward its edge and closes
/// when flung or let go past half way. Escape closes it unless [closeOnEscape] is false.
class UiDrawer extends StatelessWidget {
  const UiDrawer({
    super.key,
    this.child,
    this.bodyBuilder,
    this.header,
    this.footer,
    this.side = UiDrawerSide.right,
    this.title,
    this.closeOnEscape = true,
    this.glass,
    this.radius,
    this.onClose,
    this.autofocus = true,
    this.onPointerEnter,
    this.onPointerExit,
  }) : assert((child == null) != (bodyBuilder == null), 'Give UiDrawer either child or bodyBuilder');

  /// The body, in a scroll view. Give this or [bodyBuilder].
  final Widget? child;

  /// A body that scrolls itself (a `ListView.builder` that loads more at the end), built around the
  /// drawer's [ScrollController]. Give this or [child].
  final UiScrollBodyBuilder? bodyBuilder;

  /// Fixed above the body, under the title bar (the web `[drawer-header]`): a New chat button.
  final Widget? header;

  /// Fixed at the bottom, under the body (the web `[drawer-footer]`): account, settings.
  final Widget? footer;

  /// The body's padding (the web `.bd`): space4 at the sides, space3 above and below. A
  /// [bodyBuilder]'s list uses it as its own padding so its rows scroll to the panel's edges.
  static EdgeInsets bodyPadding(BuildContext context) {
    final t = context.ui;
    return EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space3);
  }

  final UiDrawerSide side;
  final String? title;
  final bool closeOnEscape;
  final bool? glass;
  final bool? radius;
  final VoidCallback? onClose;

  /// Take keyboard focus when it opens. A peek opened by hovering ([UiDrawerPeek]) leaves it where it is.
  final bool autofocus;

  /// The pointer entered or left the panel (the web `panelEnter` / `panelLeave`), for drawers that
  /// close when it leaves.
  final VoidCallback? onPointerEnter;
  final VoidCallback? onPointerExit;

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
    // Keep content clear of the notch and the gesture bar on the edges the panel touches; a
    // full-height drawer also keeps its bottom (the footer) above the keyboard.
    final bottomInset = _horizontal ? math.max(mq.padding.bottom, mq.viewInsets.bottom) : mq.padding.bottom;
    final inset = EdgeInsets.only(
      top: side != UiDrawerSide.bottom ? mq.padding.top : 0,
      bottom: side != UiDrawerSide.top ? bottomInset : 0,
      left: side == UiDrawerSide.left || !_horizontal ? mq.padding.left : 0,
      right: side == UiDrawerSide.right || !_horizontal ? mq.padding.right : 0,
    );

    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        color: isGlass ? t.glassPanelBg : t.surface,
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
                  child: UiPinnedEdges(
                    header: header,
                    footer: footer,
                    headerPadding: UiDrawer.bodyPadding(context),
                    footerPadding: UiDrawer.bodyPadding(context),
                    body: bodyBuilder ??
                        (context, controller) => SingleChildScrollView(
                              controller: controller,
                              padding: UiDrawer.bodyPadding(context),
                              child: child,
                            ),
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
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: t.glassBlur, sigmaY: t.glassBlur),
          child: panel,
        ),
      );
    }
    panel = UiDialogScope(label: title, closeOnEscape: closeOnEscape, onClose: close, autofocus: autofocus, child: panel);
    if (onPointerEnter != null || onPointerExit != null) {
      panel = MouseRegion(onEnter: (_) => onPointerEnter?.call(), onExit: (_) => onPointerExit?.call(), child: panel);
    }

    final size = mq.size;
    // A bottom drawer rests on the on-screen keyboard (0.41.3): until then it stayed at the screen
    // edge and the keyboard covered its fields and footer. Its height comes from the space left.
    final keyboard = side == UiDrawerSide.bottom ? mq.viewInsets.bottom : 0.0;
    final extent = _horizontal ? math.min(360.0, size.width * 0.9) : math.min(320.0, math.max(0.0, size.height - keyboard - mq.padding.top) * 0.8);
    panel = SizedBox(width: _horizontal ? extent : double.infinity, height: _horizontal ? double.infinity : extent, child: panel);
    // The route slides the whole screen-sized layer, so a finger maps onto the screen's extent.
    panel = _SwipeToClose(side: side, extent: _horizontal ? size.width : size.height, child: panel);
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Align(
        alignment: switch (side) {
          UiDrawerSide.left => Alignment.centerLeft,
          UiDrawerSide.right => Alignment.centerRight,
          UiDrawerSide.top => Alignment.topCenter,
          UiDrawerSide.bottom => Alignment.bottomCenter,
        },
        child: panel,
      ),
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

/// A drawer over the page that doesn't block it: the web `ui-drawer` with `modal` false. No barrier,
/// no route and no focus grab, so the page underneath stays usable; Escape (with focus inside) and
/// the close button still call [onClose]. It slides in from [side] while [open] and out after.
///
/// [child] is laid out in place (the thing that opens it, e.g. a rail of dots); the drawer itself is
/// shown in the nearest [Overlay].
class UiDrawerPeek extends StatefulWidget {
  const UiDrawerPeek({super.key, required this.open, required this.child, required this.drawer, this.side = UiDrawerSide.right, this.title, this.onClose, this.onPointerEnter, this.onPointerExit, this.headerBuilder, this.footerBuilder});

  final bool open;
  final Widget child;

  /// The drawer's content.
  final WidgetBuilder drawer;

  /// The drawer's fixed [UiDrawer.header] and [UiDrawer.footer].
  final WidgetBuilder? headerBuilder;
  final WidgetBuilder? footerBuilder;
  final UiDrawerSide side;
  final String? title;
  final VoidCallback? onClose;
  final VoidCallback? onPointerEnter;
  final VoidCallback? onPointerExit;

  @override
  State<UiDrawerPeek> createState() => _UiDrawerPeekState();
}

class _UiDrawerPeekState extends State<UiDrawerPeek> with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController();
  late final AnimationController _anim = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    // Shown for good (show() may not be called during a rebuild); it draws nothing while closed.
    _portal.show();
    if (widget.open) _anim.value = 1;
  }

  @override
  void didUpdateWidget(UiDrawerPeek oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (widget.open == old.open) return;
    final t = context.ui;
    final animate = context.uiAnimate;
    if (widget.open) {
      _anim.animateTo(1, duration: animate ? t.motionSlow : Duration.zero, curve: t.easeDecelerate);
    } else {
      _anim.animateTo(0, duration: animate ? t.motionBase : Duration.zero, curve: t.easeAccelerate);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final from = switch (widget.side) {
      UiDrawerSide.left => const Offset(-1, 0),
      UiDrawerSide.right => const Offset(1, 0),
      UiDrawerSide.top => const Offset(0, -1),
      UiDrawerSide.bottom => const Offset(0, 1),
    };
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => AnimatedBuilder(
        animation: _anim,
        builder: (context, drawer) => !widget.open && _anim.value == 0 ? const SizedBox.shrink() : drawer!,
        child: SlideTransition(
          position: Tween(begin: from, end: Offset.zero).animate(_anim),
          child: UiDrawer(
            side: widget.side,
            title: widget.title,
            autofocus: false,
            onClose: widget.onClose ?? () {},
            onPointerEnter: widget.onPointerEnter,
            onPointerExit: widget.onPointerExit,
            header: widget.headerBuilder == null ? null : Builder(builder: widget.headerBuilder!),
            footer: widget.footerBuilder == null ? null : Builder(builder: widget.footerBuilder!),
            child: Builder(builder: widget.drawer),
          ),
        ),
      ),
      child: widget.child,
    );
  }
}
