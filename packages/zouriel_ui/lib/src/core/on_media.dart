import 'package:flutter/widgets.dart';

/// Inherited on-media context used by `UiCoverHero` and reusable over other photography.
///
/// Descendant text and ghost/link controls use light ink, a soft shadow, and translucent hover
/// feedback without each app having to pass colours through every widget.
class UiOnMediaScope extends InheritedWidget {
  const UiOnMediaScope({super.key, this.enabled = true, required super.child});

  final bool enabled;

  static UiOnMediaScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<UiOnMediaScope>();

  static bool active(BuildContext context) => maybeOf(context)?.enabled ?? false;

  @override
  bool updateShouldNotify(UiOnMediaScope oldWidget) => oldWidget.enabled != enabled;
}
