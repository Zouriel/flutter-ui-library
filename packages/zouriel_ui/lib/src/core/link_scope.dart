import 'package:flutter/widgets.dart';

/// How the library's links move around an app (0.87.0, the web `provideUiLinkNavigator`): [UiLink]
/// and [UiButton] / [UiIconButton] with an `href` and no tap handler of their own call [navigate]
/// with their href, and [UiLink] / [UiButton] ask [isCurrent] whether their href is the page that is
/// open. Put one above the app's pages and hand it the app's router:
///
/// ```dart
/// UiLinkScope(navigate: (href) => router.go(href), isCurrent: (href) => router.location == href, child: …)
/// ```
///
/// Rebuild the scope when the route changes so links re-ask [isCurrent]. Without a scope, a link
/// with an href but no tap handler does nothing when tapped. Unlike the web, every href is handed
/// over (external ones too): nothing else in Flutter would open it.
class UiLinkScope extends InheritedWidget {
  const UiLinkScope({super.key, required this.navigate, this.isCurrent, required super.child});

  /// Goes to [href] (e.g. `router.go(href)`, or `launchUrl` for an external address).
  final void Function(String href) navigate;

  /// Whether [href] is the page that is open; null: no link is ever current by itself.
  final bool Function(String href)? isCurrent;

  static UiLinkScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<UiLinkScope>();

  /// [isCurrent] of [href], false without one.
  bool current(String href) => isCurrent?.call(href) ?? false;

  @override
  bool updateShouldNotify(UiLinkScope old) => old.navigate != navigate || old.isCurrent != isCurrent;
}
