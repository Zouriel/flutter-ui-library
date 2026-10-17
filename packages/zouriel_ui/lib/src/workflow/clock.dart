import 'package:flutter/widgets.dart';

/// The time the workflow views count from ("2 hours ago", "due in 3 days", "overdue"): the web
/// `UI_WORKFLOW_CLOCK`. Defaults to the device's clock; put one above the views to use the engine's
/// clock when they differ (a sandbox whose clock was moved forward, or a server whose time counts).
class UiWorkflowClock extends InheritedWidget {
  const UiWorkflowClock({super.key, required this.now, required super.child});

  /// The current time.
  final DateTime Function() now;

  /// The time from the nearest clock, else the device's.
  static DateTime nowOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<UiWorkflowClock>()?.now() ?? DateTime.now();

  @override
  bool updateShouldNotify(UiWorkflowClock oldWidget) => oldWidget.now != now;
}
