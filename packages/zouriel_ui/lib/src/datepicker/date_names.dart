import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../theme/theme.dart';

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

UiStrings? _strings(BuildContext? context) => context == null ? null : UiTheme.of(context).config.strings;

/// The locale tag for date names: [UiStrings.locale] when set, else the app's locale.
String? _localeTag(BuildContext? context) {
  final s = _strings(context);
  if (s != null && s.locale.isNotEmpty) return s.locale;
  return context == null ? null : Localizations.maybeLocaleOf(context)?.toLanguageTag();
}

DateFormat _format(BuildContext? context, String pattern) {
  final locale = _localeTag(context);
  try {
    return DateFormat(pattern, locale);
  } catch (_) {
    // Locale data not loaded or missing (call initializeDateFormatting for other locales; `intl` has
    // no Dhivehi at all, which UiStrings.dv's names cover): use English.
    return DateFormat(pattern, 'en');
  }
}

/// Month names, long ("October") or short ("Oct"), January first: [UiStrings.months] /
/// [UiStrings.monthsShort] when set (0.46.0), else from `intl` in the locale.
List<String> uiMonthNames(BuildContext? context, {bool short = false}) {
  final s = _strings(context);
  final given = s == null ? const <String>[] : (short ? s.monthsShort : s.months);
  if (given.length == 12) return given;
  final f = _format(context, short ? 'MMM' : 'MMMM');
  return [for (var m = 1; m <= 12; m++) f.format(DateTime(2000, m, 1))];
}

/// Weekday names, Sunday first, short (the calendar columns) or long: [UiStrings.weekdaysShort] /
/// [UiStrings.weekdays] when set (0.46.0), else from `intl`. [uiWeekdayColumns] puts them in the
/// calendar's order.
List<String> uiWeekdayNames(BuildContext? context, {bool short = true}) {
  final s = _strings(context);
  final given = s == null ? const <String>[] : (short ? s.weekdaysShort : s.weekdays);
  if (given.length == 7) return given;
  final f = _format(context, short ? 'EEE' : 'EEEE');
  // 2 January 2000 was a Sunday.
  return [for (var d = 0; d < 7; d++) f.format(DateTime(2000, 1, 2 + d))];
}

/// The calendars' first column, 0 Sunday … 6 Saturday (0.46.0): [UiStrings.firstDayOfWeek] when
/// set, else the locale's (from `intl`'s date symbols), else Sunday.
int uiFirstDayOfWeek(BuildContext? context) {
  final given = _strings(context)?.firstDayOfWeek;
  if (given != null) return given % 7;
  final tag = _localeTag(context);
  if (tag == null) return 0;
  try {
    // intl counts from Monday (0 Monday … 6 Sunday).
    final symbols = DateFormat('d', tag).dateSymbols;
    return (symbols.FIRSTDAYOFWEEK + 1) % 7;
  } catch (_) {
    return 0;
  }
}

/// Short weekday names in the calendar's column order, starting on [uiFirstDayOfWeek].
List<String> uiWeekdayColumns(BuildContext? context) {
  final names = uiWeekdayNames(context);
  final first = uiFirstDayOfWeek(context);
  return [for (var i = 0; i < 7; i++) names[(first + i) % 7]];
}

/// "October 2026" for a view of year [y], zero-based month [m] ([UiStrings.monthYearFormat] with
/// [UiStrings.months] when set).
String uiMonthYear(BuildContext? context, int y, int m) {
  final s = _strings(context);
  if (s != null && s.monthYearFormat.isNotEmpty && s.months.length == 12) {
    return uiFormatString(s.monthYearFormat, {'month': s.months[m], 'y': y});
  }
  return _format(context, 'MMMM y').format(DateTime(y, m + 1, 1));
}

/// An ISO day as local text: "October 13, 2026", or "Oct 13, 2026" when [short]
/// ([UiStrings.dateFormat] / [UiStrings.dateFormatShort] with the month names when set).
String uiFormatIsoDate(BuildContext? context, String iso, {bool short = false}) {
  final d = uiParseIsoDate(iso);
  if (d == null) return iso;
  final s = _strings(context);
  if (s != null) {
    final pattern = short ? s.dateFormatShort : s.dateFormat;
    final names = short ? s.monthsShort : s.months;
    if (pattern.isNotEmpty && names.length == 12) return uiFormatString(pattern, {'d': d.day, 'month': names[d.month - 1], 'y': d.year});
  }
  return _format(context, short ? 'yMMMd' : 'yMMMMd').format(d);
}
