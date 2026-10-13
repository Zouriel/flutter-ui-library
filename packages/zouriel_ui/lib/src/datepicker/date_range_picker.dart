import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../theme/theme.dart';
import 'calendar_view.dart';
import 'date_names.dart';

/// A range of ISO `YYYY-MM-DD` days; either end may be unset while choosing.
@immutable
class UiDateRange {
  const UiDateRange({this.start, this.end});

  final String? start;
  final String? end;

  static const UiDateRange empty = UiDateRange();

  @override
  bool operator ==(Object other) => other is UiDateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'UiDateRange($start, $end)';
}

/// `ui-date-range-picker`: inline range selection.
///
/// Tap a start day, then an end day (an earlier end swaps them); a third tap starts a new range.
/// While choosing the end, hovering with a mouse previews the band. It opens on the month the
/// range starts in. The footer reads the chosen range.
class UiDateRangePicker extends StatelessWidget {
  const UiDateRangePicker({super.key, this.value = UiDateRange.empty, this.onChanged, this.min, this.max, this.enabled = true, this.radius});

  final UiDateRange value;
  final ValueChanged<UiDateRange>? onChanged;
  final String? min;
  final String? max;
  final bool enabled;
  final bool? radius;

  /// The next range after picking [d] (exposed for the form engine and tests).
  static UiDateRange nextRange(UiDateRange r, String d) {
    if (r.start == null || r.end != null) return UiDateRange(start: d);
    return d.compareTo(r.start!) < 0 ? UiDateRange(start: d, end: r.start) : UiDateRange(start: r.start, end: d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final small = context.uiText.body.copyWith(fontSize: t.fontSizeSm, color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()]);
    String fmt(String? d) => d == null ? 'Not set' : uiFormatIsoDate(context, d, short: true);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        // Tighter on phones, so seven 48dp days fit a 360dp-wide screen.
        padding: EdgeInsets.all(uiTouchPlatform(context) ? t.space2 : t.space3),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular((radius ?? theme.config.radius) ? t.radius : 0),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          UiCalendarView(
            range: true,
            rangeStart: value.start,
            rangeEnd: value.end,
            min: min,
            max: max,
            enabled: enabled,
            onPick: (d) => onChanged?.call(nextRange(value, d)),
          ),
          SizedBox(height: t.space2),
          Semantics(
            liveRegion: true,
            label: 'From ${fmt(value.start)} to ${fmt(value.end)}',
            excludeSemantics: true,
            child: Row(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
              Text(value.start == null ? '—' : fmt(value.start), style: small),
              UiIcon(HugeIcons.strokeRoundedArrowRight02, size: 12, color: t.textMuted),
              Text(value.end == null ? '—' : fmt(value.end), style: small),
            ]),
          ),
        ]),
      ),
    );
  }
}
