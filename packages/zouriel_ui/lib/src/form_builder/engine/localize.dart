/// Languages of a form: resolving and writing [UiFbText], and each locale's direction.
/// Pure functions shared by the builder, the renderer and the engine. Port of the web `localize.ts`.
library;

import 'schema.dart';

const String uiFbDefaultLocale = 'en';

/// Languages written right to left (by their base code).
const Set<String> _rtlLangs = {'ar', 'arc', 'ckb', 'dv', 'fa', 'he', 'ks', 'nqo', 'ps', 'sd', 'syr', 'ug', 'ur', 'yi'};

const Map<String, String> _names = {
  'en': 'English', 'dv': 'ދިވެހި', 'ar': 'العربية', 'he': 'עברית', 'fa': 'فارسی', 'ur': 'اردو', 'hi': 'हिन्दी', 'si': 'සිංහල', //
  'ta': 'தமிழ்', 'bn': 'বাংলা', 'fr': 'Français', 'de': 'Deutsch', 'es': 'Español', 'it': 'Italiano', 'pt': 'Português',
  'ru': 'Русский', 'zh': '中文', 'ja': '日本語', 'ko': '한국어', 'tr': 'Türkçe', 'id': 'Bahasa Indonesia', 'ms': 'Bahasa Melayu',
};

/// A form language with label and direction filled in (see [fbLocales]).
class UiFbResolvedLocale {
  const UiFbResolvedLocale({required this.code, required this.label, required this.dir});
  final String code;
  final String label;
  final UiFbDir dir;

  @override
  bool operator ==(Object other) => other is UiFbResolvedLocale && other.code == code && other.label == label && other.dir == dir;

  @override
  int get hashCode => Object.hash(code, label, dir.name);

  @override
  String toString() => 'UiFbResolvedLocale($code, $label, ${dir.name})';
}

/// `dv-MV` -> `dv`.
String fbBaseLocale(String code) => code.toLowerCase().split(RegExp('[-_]')).first;

/// The direction a locale is written in when the form doesn't say.
UiFbDir fbDefaultDir(String code) => _rtlLangs.contains(fbBaseLocale(code)) ? UiFbDir.rtl : UiFbDir.ltr;

/// The language's own name (`ދިވެހި` for `dv`), or the code in capitals when it isn't known.
String fbLocaleName(String code) => _names[code.toLowerCase()] ?? _names[fbBaseLocale(code)] ?? code.toUpperCase();

String fbDefaultLocale(UiFormDefinition? def) {
  final d = def?.defaultLocale;
  if (d != null && d.isNotEmpty) return d;
  final first = def?.supportedLocales?.firstOrNull?.code;
  if (first != null && first.isNotEmpty) return first;
  return uiFbDefaultLocale;
}

/// The form's languages with label and direction filled in, the default one first. Never empty.
List<UiFbResolvedLocale> fbLocales(UiFormDefinition? def) {
  final supported = def?.supportedLocales ?? const <UiFbLocale>[];
  final seen = <String>{};
  final out = <UiFbResolvedLocale>[];
  for (final l in [UiFbLocale(code: fbDefaultLocale(def)), ...supported]) {
    if (l.code.isEmpty || !seen.add(l.code)) continue;
    // The explicit entry for the default locale (label, dir) wins over the bare one added above.
    final full = supported.where((x) => x.code == l.code).firstOrNull ?? l;
    final label = full.label;
    out.add(UiFbResolvedLocale(code: full.code, label: label != null && label.isNotEmpty ? label : fbLocaleName(full.code), dir: full.dir ?? fbDefaultDir(full.code)));
  }
  return out;
}

/// The locale a form is shown in for a requested one: an exact match, else the same language
/// (`dv-MV` -> `dv`, `en` -> `en-GB`), else the form's default.
String fbResolveLocale(UiFormDefinition? def, [String? requested]) {
  final all = fbLocales(def);
  if (requested == null || requested.isEmpty) return all.first.code;
  final lower = requested.toLowerCase();
  final exact = all.where((l) => l.code.toLowerCase() == lower).firstOrNull;
  if (exact != null) return exact.code;
  final base = fbBaseLocale(requested);
  return all.where((l) => fbBaseLocale(l.code) == base).firstOrNull?.code ?? all.first.code;
}

UiFbDir fbLocaleDir(UiFormDefinition? def, [String? locale]) {
  final code = fbResolveLocale(def, locale);
  return fbLocales(def).where((l) => l.code == code).firstOrNull?.dir ?? fbDefaultDir(code);
}

/// Whether [text] is a per-locale map rather than one string for every language.
bool fbIsLocalized(UiFbText? text) => text != null && text.isLocalized;

/// [text] in [locale]. A plain string is returned as is. A map falls back, in order, to the same
/// language (`dv-MV` -> `dv`), [defaultLocale], then its first non-empty entry. Blank counts as missing.
String fbText(UiFbText? text, [String? locale, String? defaultLocale]) {
  if (text == null) return '';
  final map = text.map;
  if (map == null) return text.plain!;
  String? has(String? k) {
    if (k == null || k.isEmpty) return null;
    final v = map[k];
    return v != null && v.trim().isNotEmpty ? v : null;
  }

  final direct = has(locale);
  if (direct != null) return direct;
  if (locale != null && locale.isNotEmpty) {
    final base = fbBaseLocale(locale);
    for (final k in map.keys) {
      if (fbBaseLocale(k) == base && has(k) != null) return map[k]!;
    }
  }
  final fallback = has(defaultLocale ?? uiFbDefaultLocale);
  if (fallback != null) return fallback;
  for (final v in map.values) {
    if (v.trim().isNotEmpty) return v;
  }
  return '';
}

/// [text] in exactly [locale], with no fallback: '' when that translation is missing. For editors and lint.
String fbTextIn(UiFbText? text, String locale, [String? defaultLocale]) {
  if (text == null) return '';
  final map = text.map;
  if (map == null) return locale == (defaultLocale ?? uiFbDefaultLocale) ? text.plain! : '';
  return map[locale] ?? '';
}

/// [text] with its [locale] entry set to [value]. Stays a plain string while only the default
/// locale has text; becomes a map on the first translation; drops blank translations and goes
/// back to a plain string when only the default one is left.
UiFbText fbSetText(UiFbText? text, String locale, String value, [String? defaultLocale]) {
  final def = defaultLocale ?? uiFbDefaultLocale;
  final Map<String, String> map;
  if (text == null) {
    map = {};
  } else if (text.map == null) {
    map = text.plain!.isNotEmpty ? {def: text.plain!} : {};
  } else {
    map = {...text.map!};
  }
  if (value.trim().isNotEmpty || locale == def) {
    map[locale] = value;
  } else {
    map.remove(locale);
  }
  final keys = [for (final e in map.entries) if (e.key == def || e.value.trim().isNotEmpty) e.key];
  if (keys.isEmpty) return const UiFbText('');
  if (keys.length == 1 && keys.first == def) return UiFbText(map[def]!);
  return UiFbText.localized({for (final k in keys) k: map[k]!});
}
