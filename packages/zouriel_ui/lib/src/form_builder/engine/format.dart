import 'package:intl/intl.dart';

import 'conditions.dart';
import 'js.dart';
import 'option_sources.dart';
import 'schema.dart';

/// An option's label for a stored value, or the value itself (marked) when the option is gone.
String optionLabel(UiFbField field, Object? value) {
  // Sourced answers carry the label they were picked with.
  if (isChoice(value)) return jsString((value as Map)['label']);
  final s = jsString(value);
  for (final o in field.options ?? const <UiFbOption>[]) {
    if (o.value == s) return o.label;
  }
  return '$s (no longer an option)';
}

String? _locale(String? locale) => locale ?? Intl.getCurrentLocale();

/// Whether to use the built-in US English formatting, which reproduces the browser's
/// `Intl.NumberFormat('en-US')` digit for digit (intl's NumberFormat rounds differently).
bool _usEnglish(String? locale) {
  final l = (locale ?? 'en_US').replaceAll('-', '_');
  return l == 'en_US' || l == 'en';
}

/// Symbols `Intl.NumberFormat('en-US', { style: 'currency' })` uses; other codes print as `CODE `.
const Map<String, String> _usCurrencySymbols = {
  'USD': r'$', 'EUR': '€', 'GBP': '£', 'JPY': '¥', 'INR': '₹', 'CAD': r'CA$', 'AUD': r'A$', 'CNY': 'CN¥', 'ILS': '₪', //
  'KRW': '₩', 'VND': '₫', 'NZD': r'NZ$', 'HKD': r'HK$', 'MXN': r'MX$', 'BRL': r'R$', 'TWD': r'NT$', 'PHP': '₱',
  'XAF': 'FCFA ', 'XOF': 'F CFA ', 'XCD': r'EC$', 'XPF': 'CFPF ',
};

/// The decimal digits of |x| as V8 prints them (shortest round-trip), with the position of the point.
(String digits, int point) _decimalDigits(double x) {
  var s = x.abs().toString();
  var exp = 0;
  final e = s.indexOf('e');
  if (e >= 0) {
    exp = int.parse(s.substring(e + 1));
    s = s.substring(0, e);
  }
  final dot = s.indexOf('.');
  var digits = dot < 0 ? s : s.substring(0, dot) + s.substring(dot + 1);
  var point = (dot < 0 ? s.length : dot) + exp;
  // Strip leading zeros, keeping the point where it belongs.
  var lead = 0;
  while (lead < digits.length - 1 && digits[lead] == '0') {
    lead++;
  }
  digits = digits.substring(lead);
  point -= lead;
  return (digits, point);
}

/// `x` with grouping and between [minFrac] and [maxFrac] decimals, rounding half away from zero
/// on the shortest decimal form, like V8's `Intl.NumberFormat('en-US')`.
String _usDecimal(double x, int minFrac, int maxFrac) {
  if (x.isNaN) return 'NaN';
  if (x.isInfinite) return x > 0 ? '∞' : '-∞';
  var (digits, point) = _decimalDigits(x);
  // Pad so there are digits up to maxFrac places after the point, and at least one before it.
  if (point <= 0) {
    digits = '0' * (1 - point) + digits;
    point = 1;
  }
  final want = point + maxFrac;
  if (digits.length < want) digits = digits.padRight(want, '0');
  var keep = digits.substring(0, want);
  final roundUp = digits.length > want && digits.codeUnitAt(want) >= 0x35; // '5'
  if (roundUp) {
    final chars = keep.split('');
    var i = chars.length - 1;
    while (i >= 0) {
      if (chars[i] == '9') {
        chars[i] = '0';
        i--;
      } else {
        chars[i] = String.fromCharCode(chars[i].codeUnitAt(0) + 1);
        break;
      }
    }
    keep = chars.join();
    if (i < 0) {
      keep = '1$keep';
      point++;
    }
  }
  var intPart = keep.substring(0, point).replaceFirst(RegExp(r'^0+(?=\d)'), '');
  var frac = keep.substring(point);
  while (frac.length > minFrac && frac.endsWith('0')) {
    frac = frac.substring(0, frac.length - 1);
  }
  final grouped = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) grouped.write(',');
    grouped.write(intPart[i]);
  }
  intPart = grouped.toString();
  final sign = x < 0 || (x == 0 && x.isNegative) ? '-' : '';
  return '$sign$intPart${frac.isEmpty ? '' : '.$frac'}';
}

String _formatNumber(num n, UiFbField field, String? locale) {
  final p = field.props;
  final money = field.type == UiFbFieldType.currency || p?.format == 'currency';
  final decimals = p?.decimals;
  if (money) {
    final d = (decimals ?? 2).toInt();
    final raw = p?.currency;
    final code = (raw == null || raw.isEmpty ? 'USD' : raw);
    if (!RegExp(r'^[A-Za-z]{3}$').hasMatch(code) || d < 0 || d > 100) return n.toDouble().toStringAsFixed(d.clamp(0, 100));
    final upper = code.toUpperCase();
    if (_usEnglish(locale)) {
      final symbol = _usCurrencySymbols[upper] ?? '$upper ';
      final body = _usDecimal(n.toDouble().abs(), d, d);
      return '${n < 0 ? '-' : ''}$symbol$body';
    }
    return NumberFormat.simpleCurrency(locale: locale, name: upper, decimalDigits: d).format(n);
  }
  final maxFrac = (decimals ?? 10).toInt();
  final String text;
  if (_usEnglish(locale)) {
    text = _usDecimal(n.toDouble(), 0, maxFrac);
  } else {
    text = (NumberFormat.decimalPattern(locale)..maximumFractionDigits = maxFrac).format(n);
  }
  final suffix = p?.suffix;
  return '${p?.prefix ?? ''}$text${suffix != null && suffix.isNotEmpty ? ' $suffix' : ''}';
}

final RegExp _isoDay = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// `2004-03-19` as people read it (`Mar 19, 2004` in US English). Other text is returned as-is.
String formatDate(String iso, {String? locale}) {
  if (!_isoDay.hasMatch(iso)) return iso;
  final p = iso.split('-').map(int.parse).toList();
  return DateFormat.yMMMd(_locale(locale)).format(DateTime(p[0], p[1], p[2]));
}

/// An answer as people read it: option labels, dates, money, Yes/No, file names. [locale]
/// defaults to `Intl.getCurrentLocale()` (the web version uses the browser's).
String formatValue(UiFbField field, Object? value, {String? locale}) {
  if (isEmptyValue(value)) return '';
  final loc = _locale(locale);
  switch (field.type) {
    case UiFbFieldType.select || UiFbFieldType.radio:
      return optionLabel(field, value);
    case UiFbFieldType.checkboxes || UiFbFieldType.multiselect:
      return (value is List ? value : [value]).map((v) => optionLabel(field, v)).join(', ');
    case UiFbFieldType.checkbox || UiFbFieldType.toggle:
      return value == true ? 'Yes' : 'No';
    case UiFbFieldType.date:
      return formatDate(jsString(value), locale: loc);
    case UiFbFieldType.file:
      return (value as List).map((f) => jsString((f as Map)['name'])).join(', ');
    case UiFbFieldType.rating:
      return '${jsString(value)} / ${jsString(field.props?.maxRating ?? 5)}';
  }
  if (value is num) return _formatNumber(value, field, loc);
  if (value is List) return value.map((x) => x == null ? '' : jsString(x)).join(', ');
  return jsString(value);
}
