import 'package:flutter/foundation.dart';

import 'phone_countries.dart';

/// A country in [UiPhoneInput]'s list, generated from libphonenumber metadata
/// (`tool/gen_phone_countries.mjs`). The web `UiPhoneCountry`.
@immutable
class UiPhoneCountry {
  const UiPhoneCountry({required this.iso2, required this.name, required this.dial, required this.trunk, required this.main, required this.leading});

  /// ISO 3166 alpha-2, e.g. 'MV'.
  final String iso2;

  /// English name (CLDR).
  final String name;

  /// Dial code without '+', e.g. '960'.
  final String dial;

  /// National trunk prefix ('0' in the UK, '1' in the US, '' in the Maldives or Italy).
  final String trunk;

  /// The main country for a dial code that several share (+1: US, +44: GB, +7: RU).
  final bool main;

  /// libphonenumber's leadingDigits: national numbers that start like this belong here (+1 268: AG).
  final String leading;

  /// The flag emoji: the ISO code's two regional indicator symbols.
  String get flag => uiPhoneFlag(iso2);

  @override
  String toString() => 'UiPhoneCountry($iso2 +$dial)';
}

/// Every country, sorted by English name.
final List<UiPhoneCountry> uiPhoneCountries = List.unmodifiable([
  for (final (iso2, name, dial, trunk, main, leading) in uiPhoneCountryRows)
    UiPhoneCountry(iso2: iso2, name: name, dial: dial, trunk: trunk, main: main, leading: leading),
]);

final Map<String, UiPhoneCountry> _byIso = {for (final c in uiPhoneCountries) c.iso2: c};
final Map<String, List<UiPhoneCountry>> _byDial = () {
  final m = <String, List<UiPhoneCountry>>{};
  for (final c in uiPhoneCountries) {
    (m[c.dial] ??= []).add(c);
  }
  return m;
}();
final Map<String, RegExp> _leadingRe = {};

/// The country for an ISO code (any case), or null.
UiPhoneCountry? uiPhoneCountry(String? iso2) => iso2 == null || iso2.isEmpty ? null : _byIso[iso2.toUpperCase()];

/// The flag emoji for an ISO code: its two regional indicator symbols, built from code points.
String uiPhoneFlag(String iso2) => String.fromCharCodes([for (final u in iso2.toUpperCase().codeUnits) 0x1F1E6 + u - 0x41]);

/// Digits only (drops spaces, dashes, dots, brackets, slashes and anything else).
String uiPhoneDigits(String text) => text.replaceAll(RegExp(r'\D'), '');

/// The country for international digits (after the '+'): the longest dial code (1 to 3 digits) that
/// exists, then among the countries sharing it: the one whose leading digits match the national
/// number, else [defaultCountry] if it shares the code, else the code's main country.
({UiPhoneCountry country, String national})? uiPhoneSplit(String international, {String? defaultCountry}) {
  final digits = uiPhoneDigits(international);
  for (var n = digits.length < 3 ? digits.length : 3; n >= 1; n--) {
    final list = _byDial[digits.substring(0, n)];
    if (list == null) continue;
    final national = digits.substring(n);
    final fallback = uiPhoneCountry(defaultCountry);
    final matched = national.isEmpty ? const <UiPhoneCountry>[] : [for (final c in list) if (c.leading.isNotEmpty && _leading(c).hasMatch(national)) c];
    UiPhoneCountry? country;
    if (matched.length > 1) {
      country = matched.contains(fallback) ? fallback : matched.where((c) => c.main).firstOrNull;
    }
    country ??= matched.firstOrNull;
    country ??= fallback != null && list.contains(fallback) ? fallback : null;
    country ??= list.firstWhere((c) => c.main);
    return (country: country, national: national);
  }
  return null;
}

RegExp _leading(UiPhoneCountry c) => _leadingRe.putIfAbsent(c.iso2, () => RegExp('^(?:${c.leading})'));

/// The national digits to store: punctuation dropped, then the country's trunk prefix removed. A
/// trunk that starts with '0' ('0', '06') is always removed; another ('1' in North America, '8' in
/// Russia) only when a full 10-digit number follows it, since a number can begin with those digits too.
String uiPhoneNational(UiPhoneCountry country, String text) {
  final digits = uiPhoneDigits(text);
  final t = country.trunk;
  if (t.isNotEmpty && digits.startsWith(t) && (t.startsWith('0') || digits.length - t.length >= 10)) return digits.substring(t.length);
  return digits;
}

/// '+' + dial code + national digits, or null with no digits.
String? uiPhoneE164(UiPhoneCountry country, String nationalText) {
  final national = uiPhoneNational(country, nationalText);
  return national.isEmpty ? null : '+${country.dial}$national';
}

/// Whether typed text is a whole international number ('+44…' or '0044…').
bool uiPhoneIsInternational(String text) {
  final t = text.trim();
  return t.startsWith('+') || RegExp(r'^00\d').hasMatch(t.replaceAll(RegExp(r'[^\d+]'), ''));
}

/// The international digits of '+44 7700…' or '0044 7700…'.
String uiPhoneInternationalDigits(String text) {
  final t = text.trim();
  final d = uiPhoneDigits(t);
  return t.startsWith('+') ? d : d.replaceFirst(RegExp(r'^00'), '');
}

/// Countries matching a search: name (anywhere), ISO code, or dial code ('+44' or '44').
List<UiPhoneCountry> uiPhoneSearch(String query, [List<UiPhoneCountry>? list]) {
  final all = list ?? uiPhoneCountries;
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [...all];
  final dial = q.replaceFirst(RegExp(r'^\+'), '');
  final isDial = RegExp(r'^\d+$').hasMatch(dial);
  return [
    for (final c in all)
      if (isDial ? c.dial.startsWith(dial) : (c.name.toLowerCase().contains(q) || c.iso2.toLowerCase() == q)) c,
  ];
}
