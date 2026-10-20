import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/gestures.dart' show HorizontalDragGestureRecognizer;
import 'package:flutter/widgets.dart';

import 'theme.dart';

/// The app root for a @zouriel/ui app: theme, text, navigation, focus and scrolling defaults.
///
/// It stands in for `MaterialApp`, which the library doesn't use. Pass a [UiThemeController] to
/// switch themes at runtime (changes animate), or a fixed [theme].
class UiApp extends StatelessWidget {
  const UiApp({
    super.key,
    this.title = '',
    this.controller,
    this.theme = UiThemeName.dark,
    this.config = const UiConfig(),
    this.home,
    this.routes = const {},
    this.initialRoute,
    this.onGenerateRoute,
    this.navigatorKey,
    this.navigatorObservers = const [],
    this.builder,
    this.locale,
    this.debugShowCheckedModeBanner = false,
  });

  final String title;
  final UiThemeController? controller;
  final UiThemeName theme;
  final UiConfig config;
  final Widget? home;
  final Map<String, WidgetBuilder> routes;
  final String? initialRoute;
  final RouteFactory? onGenerateRoute;
  final GlobalKey<NavigatorState>? navigatorKey;
  final List<NavigatorObserver> navigatorObservers;
  final TransitionBuilder? builder;
  final Locale? locale;
  final bool debugShowCheckedModeBanner;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c == null) return _app(UiThemeData(name: theme, config: config));
    return UiThemeControllerScope(controller: c, child: ListenableBuilder(listenable: c, builder: (context, _) => _app(c.data)));
  }

  Widget _app(UiThemeData data) {
    return AnimatedUiTheme(
      data: data,
      child: Builder(builder: (context) {
        final t = UiTheme.of(context);
        return WidgetsApp(
          title: title,
          color: t.tokens.primary,
          navigatorKey: navigatorKey,
          navigatorObservers: navigatorObservers,
          home: home,
          routes: routes,
          initialRoute: initialRoute,
          onGenerateRoute: onGenerateRoute,
          locale: locale,
          debugShowCheckedModeBanner: debugShowCheckedModeBanner,
          textStyle: t.typography.body,
          pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
              UiPageRoute<T>(settings: settings, builder: builder),
          builder: (context, child) {
            Widget content = ColoredBox(
              color: t.tokens.bg,
              // Icons default to the theme's icon colour (maldives: Lagoon), else its text colour (black
              // would vanish on dark themes). Filled and active controls set their own.
              child: IconTheme(
                data: IconThemeData(color: t.tokens.icon ?? t.tokens.text, size: 20),
                child: DefaultTextStyle(style: t.typography.body, child: child ?? const SizedBox.shrink()),
              ),
            );
            if (builder != null) content = builder!(context, content);
            return ScrollConfiguration(behavior: const UiScrollBehavior(), child: content);
          },
        );
      }),
    );
  }
}

/// How a [UiPageRoute] enters and leaves (the web `uiSlideTransition`).
enum UiPageTransition {
  /// The default: a short fade with a slight rise.
  fade,

  /// Slides in from the start edge (the left in LTR, the right in RTL) and back out to it.
  slideFromStart,

  /// Slides in from the end edge (the right in LTR, the left in RTL) and back out to it.
  slideFromEnd,
}

/// The library's page route: [transition] picks the entrance, with the library's motion tokens.
///
/// The slides follow the text direction. Where the platform has a swipe-back gesture (iOS, macOS)
/// a slide route follows the finger from the edge it slid away from, towards the edge it came
/// from, and pops past half way or on a fling. Under reduced motion the slides become a plain fade;
/// with the library's animations off pages change at once.
class UiPageRoute<T> extends PageRoute<T> {
  UiPageRoute({required this.builder, this.transition = UiPageTransition.fade, super.settings, super.fullscreenDialog});

  final WidgetBuilder builder;
  final UiPageTransition transition;

  bool get _slides => transition != UiPageTransition.fade;

  @override
  Duration get transitionDuration => _slides ? const Duration(milliseconds: 320) : const Duration(milliseconds: 240);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      Builder(builder: builder);

  /// The side the page enters from, in screen terms: -1 the left, 1 the right.
  double _from(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final start = transition == UiPageTransition.slideFromStart;
    return start != rtl ? -1 : 1;
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final page = ColoredBox(color: context.ui.bg, child: child);
    if (!context.uiTheme.config.animations) return page;
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_slides) {
      if (reduced) return page;
      final curved = CurvedAnimation(parent: animation, curve: const Cubic(0, 0, 0, 1), reverseCurve: const Cubic(0.3, 0, 1, 1));
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(curved), child: page),
      );
    }
    // A finger drives the animation linearly (and so does its release, until it settles); a push or
    // pop eases. The route rebuilds its transitions when the navigator's gesture state changes.
    final linear = navigator?.userGestureInProgress ?? false;
    final curved = CurvedAnimation(
      parent: animation,
      curve: linear ? Curves.linear : const Cubic(0.2, 0, 0, 1),
      reverseCurve: linear ? Curves.linear : const Cubic(0.3, 0, 1, 1),
    );
    if (reduced) return FadeTransition(opacity: curved, child: page);
    final from = _from(context);
    Widget moving = SlideTransition(
      position: Tween(begin: Offset(from, 0), end: Offset.zero).animate(curved),
      // The page's own shadow edge, so it reads as a sheet over the one beneath.
      child: DecoratedBox(decoration: BoxDecoration(boxShadow: context.ui.shadow3), child: page),
    );
    if (_swipeBack(context)) moving = _UiSwipeBack(route: this, from: from, child: moving);
    return moving;
  }

  bool _swipeBack(BuildContext context) {
    final platform = defaultTargetPlatform;
    // Whether a swipe may start is asked when the finger lands (popGestureEnabled is false while a
    // gesture runs, so checking it here would tear the detector down mid-swipe).
    return (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) && !fullscreenDialog;
  }

  void _dragStart() => navigator?.didStartUserGesture();

  /// Moves the page by [fraction] of the screen width toward where it came from (positive closes).
  void _dragUpdate(double fraction) {
    controller!.value = (controller!.value - fraction).clamp(0.0, 1.0);
  }

  /// Pops when flung toward where it came from ([velocity] in widths per second, positive closes)
  /// or let go past half way; otherwise settles back.
  void _dragEnd(double velocity) {
    final c = controller!;
    final nav = navigator;
    final pop = velocity > 1 || (velocity >= -1 && c.value < 0.5);
    if (pop) {
      nav?.pop();
    } else {
      c.forward();
    }
    // The gesture ends once the release has settled, so the curve doesn't jump mid-way (as
    // CupertinoPageRoute does it).
    if (c.isAnimating) {
      void done(AnimationStatus s) {
        if (s == AnimationStatus.completed || s == AnimationStatus.dismissed) {
          c.removeStatusListener(done);
          nav?.didStopUserGesture();
        }
      }

      c.addStatusListener(done);
    } else {
      nav?.didStopUserGesture();
    }
  }
}

/// The swipe-back edge of a slide route: a strip along the side the page slid away from (the side
/// opposite its entrance), dragged toward the side it came from. It owns its recognizer (as
/// Cupertino's back gesture does), fed from a Listener, so the drag outlives the route rebuilding
/// its transitions while the finger moves.
class _UiSwipeBack extends StatefulWidget {
  const _UiSwipeBack({required this.route, required this.from, required this.child});

  final UiPageRoute<dynamic> route;

  /// -1: the page came from the left (drag left to close); 1: from the right.
  final double from;
  final Widget child;

  @override
  State<_UiSwipeBack> createState() => _UiSwipeBackState();
}

class _UiSwipeBackState extends State<_UiSwipeBack> {
  late final HorizontalDragGestureRecognizer _drag = HorizontalDragGestureRecognizer(debugOwner: this)
    ..onStart = ((_) => widget.route._dragStart())
    ..onUpdate = ((d) => widget.route._dragUpdate(widget.from * d.delta.dx / _width))
    ..onEnd = ((d) => widget.route._dragEnd(widget.from * (d.primaryVelocity ?? 0) / _width))
    ..onCancel = (() => widget.route._dragEnd(0));

  double get _width => context.size?.width ?? MediaQuery.sizeOf(context).width;

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final from = widget.from;
    final edge = 20 + (from < 0 ? mq.padding.right : mq.padding.left);
    return Stack(fit: StackFit.passthrough, children: [
      widget.child,
      Positioned(
        top: 0,
        bottom: 0,
        width: edge,
        left: from > 0 ? 0 : null,
        right: from < 0 ? 0 : null,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            if (widget.route.popGestureEnabled) _drag.addPointer(e);
          },
        ),
      ),
    ]);
  }
}

/// Platform-appropriate scrolling (bouncing on iOS, clamping with stretch on Android) without the
/// Material glow, and mouse-drag scrolling for the web build.
class UiScrollBehavior extends ScrollBehavior {
  const UiScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.mouse,
      };
}
