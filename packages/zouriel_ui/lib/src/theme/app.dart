import 'dart:ui' show PointerDeviceKind;

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
    return ListenableBuilder(listenable: c, builder: (context, _) => _app(c.data));
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
              // Icons default to the theme's text colour (black would vanish on dark themes).
              child: IconTheme(
                data: IconThemeData(color: t.tokens.text, size: 20),
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

/// Page transition: a short fade with a slight rise, using the library's motion tokens.
class UiPageRoute<T> extends PageRoute<T> {
  UiPageRoute({required this.builder, super.settings});

  final WidgetBuilder builder;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 240);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      Builder(builder: builder);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (!context.uiAnimate) return child;
    final curved = CurvedAnimation(parent: animation, curve: const Cubic(0, 0, 0, 1), reverseCurve: const Cubic(0.3, 0, 1, 1));
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(curved),
        child: ColoredBox(color: context.ui.bg, child: child),
      ),
    );
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
