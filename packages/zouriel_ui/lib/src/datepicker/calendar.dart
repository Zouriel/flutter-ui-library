import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'calendar_view.dart';

/// `ui-calendar`: an inline month calendar. The value is an ISO `YYYY-MM-DD` day (or null); it
/// opens on the month of its value.
///
/// Each day is a button named with its full date; the chosen day is selected and today is
/// marked. The month and year in the heading open month and year grids. Keyboard support as in
/// [UiCalendarView]. Days outside [min]..[max] are shown but can't be picked.
class UiCalendar extends StatelessWidget {
  const UiCalendar({super.key, this.value, this.onChanged, this.min, this.max, this.enabled = true, this.radius});

  final String? value;
  final ValueChanged<String>? onChanged;

  /// Earliest selectable day, ISO `YYYY-MM-DD`.
  final String? min;

  /// Latest selectable day, ISO `YYYY-MM-DD`.
  final String? max;
  final bool enabled;
  final bool? radius;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        padding: EdgeInsets.all(t.space3),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular((radius ?? theme.config.radius) ? t.radius : 0),
        ),
        child: UiCalendarView(value: value, min: min, max: max, enabled: enabled, onPick: (v) => onChanged?.call(v)),
      ),
    );
  }
}
