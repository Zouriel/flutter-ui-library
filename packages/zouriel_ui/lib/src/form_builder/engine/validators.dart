import 'dart:async';

import 'conditions.dart';
import 'field_types.dart';
import 'js.dart';
import 'option_sources.dart';
import 'schema.dart';

/// What a check returns: `true`/`null` pass; `false` fails with the rule's message; a `String`
/// fails with that text. (Typed `Object?` to mirror the web's `boolean | string | null`.)
typedef UiFbValidatorResult = Object?;

/// Signature of a check. Return a [UiFbValidatorResult] or a `Future` of one.
typedef UiFbValidateFn = FutureOr<UiFbValidatorResult> Function(Object? value, Map<String, Object?> params, UiFbValidatorContext ctx);

class UiFbValidatorContext {
  UiFbValidatorContext({required this.field, required this._value, required this._label, required this._today, this.signal});

  final UiFbField field;
  final Object? Function(String) _value;
  final String Function(String) _label;
  final String Function() _today;

  /// Aborted when the answer changes again before an async check finishes.
  final UiFbAbortSignal? signal;

  /// Another field's current answer (same repeat entry when shared).
  Object? value(String ref) => _value(ref);

  /// Another field's label.
  String label(String ref) => _label(ref);
  String today() => _today();

  UiFbValidatorContext withSignal(UiFbAbortSignal signal) => UiFbValidatorContext(field: field, value: _value, label: _label, today: _today, signal: signal);
}

class UiFbParamSpec {
  const UiFbParamSpec({required this.key, required this.label, required this.kind, this.options, this.hint, this.placeholder, this.hasDefault = false, this.defaultValue, this.fieldKinds});
  final String key;
  final String label;

  /// `number`, `text`, `date`, `field` or `select`.
  final String kind;
  final List<({String value, String label})>? options;
  final String? hint;
  final String? placeholder;

  /// Whether [defaultValue] is set (it is merged under the rule's own params).
  final bool hasDefault;
  final Object? defaultValue;

  /// For `field` params: which kinds of field can be picked.
  final List<UiFbValueKind>? fieldKinds;
}

/// A check that can be added to a field. Built-ins and app-registered checks use the same shape,
/// so registered ones appear in the builder's "Add a rule" list with a settings form generated
/// from `params`.
class UiFbValidatorDef {
  const UiFbValidatorDef({
    required this.type,
    required this.label,
    this.description,
    this.valueKinds,
    this.fieldTypes,
    this.params,
    required this.defaultMessage,
    required this.validate,
    this.debounceMs,
    this.runWhenEmpty = false,
  });

  final String type;
  final String label;
  final String? description;

  /// Which answers it applies to. Leave out to allow every field.
  final List<UiFbValueKind>? valueKinds;

  /// Narrower than `valueKinds`: specific field types only.
  final List<UiFbFieldType>? fieldTypes;
  final List<UiFbParamSpec>? params;

  /// Supports `{label}` (the field's label) and `{paramKey}` placeholders.
  final String defaultMessage;
  final UiFbValidateFn validate;

  /// Runs while typing only after this pause (async checks default to 400ms). Setting it marks
  /// the check as async.
  final int? debounceMs;

  /// Also run on empty answers (most checks skip them and leave that to "required").
  final bool runWhenEmpty;
}

// ── Helpers ──────────────────────────────────────────────────────────────────────────────────

double? _n(Object? v) {
  if (v is num) return v.isFinite ? v.toDouble() : null;
  if (v is String && v.trim().isNotEmpty) {
    final n = jsNumber(v);
    if (n.isFinite) return n;
  }
  return null;
}

final RegExp _todayParam = RegExp(r'^today\s*([+-]\s*\d+)?$', caseSensitive: false);
final RegExp _isoDay = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// `2026-01-31`, `today`, `today+30`, `today-7` → `YYYY-MM-DD`.
String? resolveDateParam(Object? v, String today) {
  if (v is! String || v.isEmpty) return null;
  final m = _todayParam.firstMatch(v.trim());
  if (m != null) return addDays(today, m.group(1) != null ? int.parse(m.group(1)!.replaceAll(RegExp(r'\s'), '')) : 0);
  return _isoDay.hasMatch(v) ? v : null;
}

/// Shows a date param the way people read it.
String describeDateParam(Object? v) {
  if (v is! String) return '';
  final m = _todayParam.firstMatch(v.trim());
  if (m == null) return v;
  final d = m.group(1) != null ? int.parse(m.group(1)!.replaceAll(RegExp(r'\s'), '')) : 0;
  return d == 0 ? 'today' : d > 0 ? '$d days from today' : '${-d} days ago';
}

int _words(Object? v) => (v == null ? '' : jsString(v)).trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;

class UiFbPatternPreset {
  const UiFbPatternPreset(this.value, this.label, this.regex);
  final String value;
  final String label;
  final String regex;
}

const List<UiFbPatternPreset> uiFbPatternPresets = [
  UiFbPatternPreset('letters', 'Letters and spaces only', r"^[\p{L} '\-]+$"),
  UiFbPatternPreset('alphanumeric', 'Letters and numbers only', r'^[\p{L}\p{N}]+$'),
  UiFbPatternPreset('digits', 'Digits only', r'^\d+$'),
  UiFbPatternPreset('noSpaces', 'No spaces', r'^\S+$'),
  UiFbPatternPreset('uppercase', 'Capital letters only', r'^[\p{Lu}\p{N} ]+$'),
  UiFbPatternPreset('custom', 'Custom pattern (advanced)', ''),
];

RegExp? _patternRegex(Map<String, Object?> params) {
  UiFbPatternPreset? preset;
  for (final p in uiFbPatternPresets) {
    if (p.value == params['preset']) preset = p;
  }
  final source = preset != null && preset.value != 'custom' ? preset.regex : (params['regex'] == null ? '' : jsString(params['regex']));
  if (source.isEmpty) return null;
  try {
    return RegExp(source, unicode: true);
  } catch (_) {
    return null;
  }
}

int? _age(String dob, String today) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(dob)) return null;
  final d = dob.split('-').map(jsNumber).toList();
  final t = today.split('-').map(jsNumber).toList();
  if (d.length < 3 || t.length < 3) return null;
  var a = t[0] - d[0];
  if (t[1] < d[1] || (t[1] == d[1] && t[2] < d[2])) a--;
  return a.isFinite ? a.toInt() : null;
}

final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
final RegExp _url = RegExp(r'^(https?:\/\/)?([\w-]+\.)+[\w-]{2,}(\/\S*)?$', caseSensitive: false);
final RegExp _phone = RegExp(r'^\+?[\d\s().-]{6,20}$');

String _s(Object? v) => jsString(v);

List<Map<Object?, Object?>> _files(Object? v) => [for (final f in (v as List)) f as Map<Object?, Object?>];

/// JS `a > b` etc. for a number-or-string pair (mixed pairs compare as numbers, like JS).
bool _jsCmp(Object a, Object b, String op) {
  if (op == 'eq') return a is num && b is num ? a == b : (a is String && b is String && a == b);
  num? x;
  num? y;
  if (a is String && b is String) {
    final c = a.compareTo(b);
    return switch (op) { 'gt' => c > 0, 'gte' => c >= 0, 'lt' => c < 0, 'lte' => c <= 0, _ => true };
  }
  x = a is num ? a : jsNumber(a);
  y = b is num ? b : jsNumber(b);
  if (x.isNaN || y.isNaN) return false;
  return switch (op) { 'gt' => x > y, 'gte' => x >= y, 'lt' => x < y, 'lte' => x <= y, _ => true };
}

const _comparisons = [
  (value: 'eq', label: 'the same as'),
  (value: 'gt', label: 'more than / after'),
  (value: 'gte', label: 'at least / on or after'),
  (value: 'lt', label: 'less than / before'),
  (value: 'lte', label: 'at most / on or before'),
];

// ── Built-ins ────────────────────────────────────────────────────────────────────────────────

const _text = [UiFbValueKind.text];
const _number = [UiFbValueKind.number];
const _date = [UiFbValueKind.date];
const _time = [UiFbValueKind.time];
const _multi = [UiFbValueKind.multi];
const _file = [UiFbValueKind.file];

final List<UiFbValidatorDef> uiFbBuiltinValidators = List.unmodifiable(<UiFbValidatorDef>[
  UiFbValidatorDef(
    type: 'email', label: 'Valid email', description: 'Looks like name@example.com', fieldTypes: const [UiFbFieldType.email, UiFbFieldType.text], //
    defaultMessage: 'Enter an email address like name@example.com.',
    validate: (v, p, c) => _email.hasMatch(_s(v).trim()),
  ),
  UiFbValidatorDef(
    type: 'url', label: 'Valid web address', description: 'Looks like example.com', fieldTypes: const [UiFbFieldType.url, UiFbFieldType.text], //
    defaultMessage: 'Enter a web address like example.com.',
    validate: (v, p, c) => _url.hasMatch(_s(v).trim()),
  ),
  UiFbValidatorDef(
    type: 'phone', label: 'Valid phone number', description: 'Digits, spaces, + and brackets', fieldTypes: const [UiFbFieldType.phone, UiFbFieldType.text], //
    defaultMessage: 'Enter a phone number, like +44 20 7946 0958.',
    validate: (v, p, c) => _phone.hasMatch(_s(v).trim()) && RegExp(r'\d').allMatches(_s(v)).length >= 6,
  ),
  UiFbValidatorDef(
    type: 'minLength', label: 'Minimum length', valueKinds: _text,
    params: const [UiFbParamSpec(key: 'min', label: 'At least', kind: 'number', placeholder: 'characters')],
    defaultMessage: '{label} must be at least {min} characters.',
    validate: (v, p, c) => _s(v).length >= (_n(p['min']) ?? 0),
  ),
  UiFbValidatorDef(
    type: 'maxLength', label: 'Maximum length', valueKinds: _text,
    params: const [UiFbParamSpec(key: 'max', label: 'At most', kind: 'number', placeholder: 'characters')],
    defaultMessage: '{label} must be {max} characters or fewer.',
    validate: (v, p, c) => _s(v).length <= (_n(p['max']) ?? double.infinity),
  ),
  UiFbValidatorDef(
    type: 'minWords', label: 'Minimum words', fieldTypes: const [UiFbFieldType.textarea, UiFbFieldType.text],
    params: const [UiFbParamSpec(key: 'min', label: 'At least', kind: 'number', placeholder: 'words')],
    defaultMessage: '{label} must be at least {min} words.',
    validate: (v, p, c) => _words(v) >= (_n(p['min']) ?? 0),
  ),
  UiFbValidatorDef(
    type: 'maxWords', label: 'Maximum words', fieldTypes: const [UiFbFieldType.textarea, UiFbFieldType.text],
    params: const [UiFbParamSpec(key: 'max', label: 'At most', kind: 'number', placeholder: 'words')],
    defaultMessage: '{label} must be {max} words or fewer.',
    validate: (v, p, c) => _words(v) <= (_n(p['max']) ?? double.infinity),
  ),
  UiFbValidatorDef(
    type: 'pattern', label: 'Allowed characters', description: 'Only accept certain kinds of characters', valueKinds: _text,
    params: [
      UiFbParamSpec(key: 'preset', label: 'Allow', kind: 'select', options: [for (final p in uiFbPatternPresets) (value: p.value, label: p.label)], hasDefault: true, defaultValue: 'letters'),
      const UiFbParamSpec(key: 'regex', label: 'Pattern', kind: 'text', hint: 'A regular expression. Only used with “Custom pattern”.', placeholder: r'^[A-Z]{2}\d{6}$'),
    ],
    defaultMessage: '{label} contains characters that are not allowed.',
    validate: (v, p, c) {
      final re = _patternRegex(p);
      return re == null || re.hasMatch(_s(v));
    },
  ),
  UiFbValidatorDef(
    type: 'min', label: 'Minimum value', valueKinds: _number,
    params: const [UiFbParamSpec(key: 'min', label: 'At least', kind: 'number')],
    defaultMessage: '{label} must be {min} or more.',
    validate: (v, p, c) => (_n(v) ?? 0) >= (_n(p['min']) ?? double.negativeInfinity),
  ),
  UiFbValidatorDef(
    type: 'max', label: 'Maximum value', valueKinds: _number,
    params: const [UiFbParamSpec(key: 'max', label: 'At most', kind: 'number')],
    defaultMessage: '{label} must be {max} or less.',
    validate: (v, p, c) => (_n(v) ?? 0) <= (_n(p['max']) ?? double.infinity),
  ),
  UiFbValidatorDef(
    type: 'integer', label: 'Whole number', valueKinds: _number, fieldTypes: const [UiFbFieldType.number, UiFbFieldType.calculated],
    defaultMessage: '{label} must be a whole number.',
    validate: (v, p, c) {
      final x = _n(v);
      return x != null && x == x.truncateToDouble();
    },
  ),
  UiFbValidatorDef(
    type: 'decimalPlaces', label: 'Decimal places', valueKinds: _number,
    params: const [UiFbParamSpec(key: 'places', label: 'At most', kind: 'number', placeholder: 'decimal places')],
    defaultMessage: '{label} can have at most {places} decimal places.',
    validate: (v, p, c) {
      final x = _n(v);
      final s = x == null ? '' : jsNumberToString(x);
      final dot = s.indexOf('.');
      return dot < 0 || s.length - dot - 1 <= (_n(p['places']) ?? 0);
    },
  ),
  UiFbValidatorDef(
    type: 'minDate', label: 'Earliest date', valueKinds: _date,
    params: const [UiFbParamSpec(key: 'date', label: 'On or after', kind: 'date', hint: 'A date, or “today”, “today+7”, “today-30”.')],
    defaultMessage: '{label} must be on or after {date}.',
    validate: (v, p, c) {
      final d = resolveDateParam(p['date'], c.today());
      return d == null || _s(v).compareTo(d) >= 0;
    },
  ),
  UiFbValidatorDef(
    type: 'maxDate', label: 'Latest date', valueKinds: _date,
    params: const [UiFbParamSpec(key: 'date', label: 'On or before', kind: 'date', hint: 'A date, or “today”, “today+7”, “today-30”.')],
    defaultMessage: '{label} must be on or before {date}.',
    validate: (v, p, c) {
      final d = resolveDateParam(p['date'], c.today());
      return d == null || _s(v).compareTo(d) <= 0;
    },
  ),
  UiFbValidatorDef(
    type: 'ageAtLeast', label: 'Minimum age', description: 'For a date of birth', valueKinds: _date,
    params: const [UiFbParamSpec(key: 'years', label: 'At least', kind: 'number', placeholder: 'years old')],
    defaultMessage: 'You must be at least {years} years old.',
    validate: (v, p, c) => (_age(_s(v), c.today()) ?? double.infinity) >= (_n(p['years']) ?? 0),
  ),
  UiFbValidatorDef(
    type: 'ageAtMost', label: 'Maximum age', description: 'For a date of birth', valueKinds: _date,
    params: const [UiFbParamSpec(key: 'years', label: 'At most', kind: 'number', placeholder: 'years old')],
    defaultMessage: 'You must be {years} years old or younger.',
    validate: (v, p, c) => (_age(_s(v), c.today()) ?? double.negativeInfinity) <= (_n(p['years']) ?? double.infinity),
  ),
  UiFbValidatorDef(
    type: 'earliestTime', label: 'Earliest time', valueKinds: _time,
    params: const [UiFbParamSpec(key: 'time', label: 'At or after', kind: 'text', placeholder: '09:00')],
    defaultMessage: '{label} must be {time} or later.',
    validate: (v, p, c) => !jsTruthy(p['time']) || _s(v).compareTo(_s(p['time'])) >= 0,
  ),
  UiFbValidatorDef(
    type: 'latestTime', label: 'Latest time', valueKinds: _time,
    params: const [UiFbParamSpec(key: 'time', label: 'At or before', kind: 'text', placeholder: '17:00')],
    defaultMessage: '{label} must be {time} or earlier.',
    validate: (v, p, c) => !jsTruthy(p['time']) || _s(v).compareTo(_s(p['time'])) <= 0,
  ),
  UiFbValidatorDef(
    type: 'minSelected', label: 'Tick at least', valueKinds: _multi,
    params: const [UiFbParamSpec(key: 'count', label: 'At least', kind: 'number', placeholder: 'options')],
    defaultMessage: 'Choose at least {count} options for {label}.',
    validate: (v, p, c) => (v is List ? v.length : 0) >= (_n(p['count']) ?? 0),
  ),
  UiFbValidatorDef(
    type: 'maxSelected', label: 'Tick at most', valueKinds: _multi,
    params: const [UiFbParamSpec(key: 'count', label: 'At most', kind: 'number', placeholder: 'options')],
    defaultMessage: 'Choose no more than {count} options for {label}.',
    validate: (v, p, c) => (v is List ? v.length : 0) <= (_n(p['count']) ?? double.infinity),
  ),
  UiFbValidatorDef(
    type: 'fileType', label: 'File types', valueKinds: _file,
    params: const [UiFbParamSpec(key: 'accept', label: 'Allowed types', kind: 'text', placeholder: '.pdf, .docx, image/*', hint: 'Extensions or types, separated by commas.')],
    defaultMessage: 'Upload files of these types: {accept}.',
    validate: (v, p, c) {
      final rules = (p['accept'] == null ? '' : _s(p['accept'])).split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList();
      if (rules.isEmpty) return true;
      return _files(v).every((f) {
        final name = (f['name'] as String).toLowerCase();
        final type = (f['type'] as String).toLowerCase();
        return rules.any((r) => r.startsWith('.') ? name.endsWith(r) : r.endsWith('/*') ? type.startsWith(r.substring(0, r.length - 1)) : type == r);
      });
    },
  ),
  UiFbValidatorDef(
    type: 'maxFileSize', label: 'Largest file', valueKinds: _file,
    params: const [UiFbParamSpec(key: 'mb', label: 'Up to', kind: 'number', placeholder: 'MB')],
    defaultMessage: 'Each file must be {mb} MB or smaller.',
    validate: (v, p, c) => _files(v).every((f) => (f['size'] as num) <= (_n(p['mb']) ?? double.infinity) * 1024 * 1024),
  ),
  UiFbValidatorDef(
    type: 'maxFiles', label: 'Number of files', valueKinds: _file,
    params: const [UiFbParamSpec(key: 'count', label: 'At most', kind: 'number', placeholder: 'files')],
    defaultMessage: 'Upload no more than {count} files.',
    validate: (v, p, c) => (v as List).length <= (_n(p['count']) ?? double.infinity),
  ),
  UiFbValidatorDef(
    type: 'equalsField', label: 'Matches another answer', description: 'e.g. “Confirm email” must match “Email”',
    valueKinds: const [UiFbValueKind.text, UiFbValueKind.number, UiFbValueKind.date, UiFbValueKind.time, UiFbValueKind.choice],
    params: const [UiFbParamSpec(key: 'field', label: 'Must match', kind: 'field')],
    defaultMessage: '{label} must match {field}.',
    validate: (v, p, c) {
      final other = c.value(p['field'] == null ? '' : _s(p['field']));
      return isEmptyValue(other) || _s(v).trim().toLowerCase() == _s(other).trim().toLowerCase();
    },
  ),
  UiFbValidatorDef(
    type: 'compareField', label: 'Compared with another answer', description: 'e.g. end date after start date',
    valueKinds: const [UiFbValueKind.number, UiFbValueKind.date, UiFbValueKind.time],
    params: [
      UiFbParamSpec(key: 'comparison', label: 'Must be', kind: 'select', options: _comparisons, hasDefault: true, defaultValue: 'gt'),
      const UiFbParamSpec(key: 'field', label: 'Than', kind: 'field', fieldKinds: [UiFbValueKind.number, UiFbValueKind.date, UiFbValueKind.time]),
    ],
    defaultMessage: '{label} must be {comparison} {field}.',
    validate: (v, p, c) {
      final other = c.value(p['field'] == null ? '' : _s(p['field']));
      if (isEmptyValue(other)) return true;
      final Object a = _n(v) ?? _s(v);
      final Object b = _n(other) ?? _s(other);
      final op = p['comparison'];
      if (op is! String || !const {'eq', 'gt', 'gte', 'lt', 'lte'}.contains(op)) return true;
      return _jsCmp(a, b, op);
    },
  ),
]);

/// Format checks every email/url/phone field gets without anyone adding them.
const Map<UiFbFieldType, String> uiFbImplicitValidator = {UiFbFieldType.email: 'email', UiFbFieldType.url: 'url', UiFbFieldType.phone: 'phone'};

/// Checks that make sense for a field, built-ins first.
List<UiFbValidatorDef> validatorsFor(UiFbFieldType type, String? format, List<UiFbValidatorDef> all) {
  final kind = valueKindOf(type, format);
  final info = fieldTypeInfo(type);
  if (type == UiFbFieldType.hidden) return [];
  return all.where((d) {
    if (d.fieldTypes != null && !d.fieldTypes!.contains(type)) return false;
    if (d.valueKinds != null && !d.valueKinds!.contains(kind)) return false;
    // Format checks belong to their own field types; a text field can opt in.
    if (info.type != UiFbFieldType.text && const ['email', 'url', 'phone'].contains(d.type) && uiFbImplicitValidator[type] != d.type) return false;
    return true;
  }).toList();
}

final RegExp _placeholder = RegExp(r'\{(\w+)\}');

/// Fills `{label}` and `{param}` placeholders; unknown or empty ones stay as written.
String formatMessage(String template, Map<String, Object?> vars) => template.replaceAllMapped(_placeholder, (m) {
  final k = m.group(1)!;
  final v = vars[k];
  return vars.containsKey(k) && v != null && v != '' ? jsString(v) : m.group(0)!;
});

/// The words shown for a comparison param in messages.
String comparisonWords(Object? v) =>
    const {'eq': 'the same as', 'gt': 'more than', 'gte': 'at least', 'lt': 'less than', 'lte': 'at most'}[v == null ? '' : jsString(v)] ?? (v == null ? '' : jsString(v));

/// Today's local date as `YYYY-MM-DD`.
String todayIso() => isoDate(DateTime.now());
