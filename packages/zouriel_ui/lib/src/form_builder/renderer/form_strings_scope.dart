import 'package:flutter/widgets.dart';

import '../engine/form_strings.dart';

/// Sets the form renderer's wording once for everything below it (the web `provideUiFormStrings`).
/// A renderer's own `strings` parameter is laid on top, key by key.
///
/// ```dart
/// UiFormStringsScope(
///   strings: {'dv': {'submit': 'ފޮނުވާ'}, 'fr': {'submit': 'Envoyer', 'back': 'Retour'}},
///   child: MyApp(),
/// )
/// ```
class UiFormStringsScope extends InheritedWidget {
  const UiFormStringsScope({super.key, required this.strings, required super.child});

  /// Wording changes per language code, on top of the built-in English and Dhivehi.
  final UiFbStringOverrides strings;

  /// The overrides in effect here (and rebuilds when they change), or `null` outside a scope.
  static UiFbStringOverrides? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<UiFormStringsScope>()?.strings;

  /// Like [maybeOf] without depending on it (for `initState`).
  static UiFbStringOverrides? read(BuildContext context) => context.getInheritedWidgetOfExactType<UiFormStringsScope>()?.strings;

  @override
  bool updateShouldNotify(UiFormStringsScope oldWidget) => !fbStringOverridesEqual(oldWidget.strings, strings);
}
