import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Today, for the calendars' "today" mark. Tests and demos can replace it to pin the date.
DateTime Function() uiToday = DateTime.now;

/// `YYYY-MM-DD` for a day (the value type of the date controls, as on the web).
String uiIsoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The ISO day for year [y], zero-based month [m] and day [d]; overflow rolls over (day 0 is the
/// last day of the previous month), like JavaScript's `new Date(y, m, d)`.
String uiIsoOf(int y, int m, int d) => uiIsoDate(DateTime(y, m + 1, d));

/// Parses `YYYY-MM-DD`; null for null or malformed text.
DateTime? uiParseIsoDate(String? iso) {
  if (iso == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
  if (m == null) return null;
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

/// Days in zero-based month [m] of [y].
int uiDaysInMonth(int y, int m) => DateTime(y, m + 2, 0).day;

DateFormat _format(BuildContext? context, String pattern) {
  final locale = context == null ? null : Localizations.maybeLocaleOf(context)?.toLanguageTag();
  try {
    return DateFormat(pattern, locale);
  } catch (_) {
    // Locale data not loaded (call initializeDateFormatting for other locales): use English.
    return DateFormat(pattern, 'en');
  }
}

/// Locale month names, long ("October") or short ("Oct"), January first.
List<String> uiMonthNames(BuildContext? context, {bool short = false}) {
  final f = _format(context, short ? 'MMM' : 'MMMM');
  return [for (var m = 1; m <= 12; m++) f.format(DateTime(2000, m, 1))];
}

/// Short weekday names, Sunday first (the grids start on Sunday, as on the web).
List<String> uiWeekdayNames(BuildContext? context) {
  final f = _format(context, 'EEE');
  // 2 January 2000 was a Sunday.
  return [for (var d = 0; d < 7; d++) f.format(DateTime(2000, 1, 2 + d))];
}

/// "October 2026" for a view of year [y], zero-based month [m].
String uiMonthYear(BuildContext? context, int y, int m) => _format(context, 'MMMM y').format(DateTime(y, m + 1, 1));

/// An ISO day as local text: "October 13, 2026", or "Oct 13, 2026" when [short].
String uiFormatIsoDate(BuildContext? context, String iso, {bool short = false}) {
  final d = uiParseIsoDate(iso);
  if (d == null) return iso;
  return _format(context, short ? 'yMMMd' : 'yMMMMd').format(d);
}
