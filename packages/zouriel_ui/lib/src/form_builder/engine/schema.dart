/// The form definition format shared by the builder (which edits it) and the renderer (which
/// fills it in). It is the same JSON the Angular `@zouriel/ui/form-builder` reads and writes, so a
/// form built on the web runs unchanged in Flutter and back.
///
/// Identity: every element has an immutable `id` (generated, never shown). Fields also have an
/// editable `key`, the property name their answer is stored under. Rules, calculations and jumps
/// always point at ids, so renaming a key never breaks logic; a renamed key is remembered in
/// `keyHistory` so answers saved under the old name still load.
///
/// Each class reads its JSON with `fromJson` and writes it back with `toJson`. Keys the class
/// doesn't know are kept in `extra` and written back unchanged, so a round trip through Dart never
/// loses data a newer web version added. The classes are mutable on purpose: the definition
/// helpers (`definition.dart`) copy a definition with [UiFormDefinition.clone] and then edit the
/// copy, which mirrors the Angular helpers' "return a new definition" behaviour.
library;

import 'js.dart';

const int uiFbSchemaVersion = 1;

// ── Enumerations (string-backed so unknown values from newer forms survive) ────────────────

/// A field's type. String-backed: `UiFbFieldType('text') == UiFbFieldType.text`.
extension type const UiFbFieldType(String name) implements Object {
  static const text = UiFbFieldType('text');
  static const textarea = UiFbFieldType('textarea');
  static const email = UiFbFieldType('email');
  static const phone = UiFbFieldType('phone');
  static const url = UiFbFieldType('url');
  static const number = UiFbFieldType('number');
  static const currency = UiFbFieldType('currency');
  static const date = UiFbFieldType('date');
  static const time = UiFbFieldType('time');
  static const select = UiFbFieldType('select');
  static const radio = UiFbFieldType('radio');
  static const checkboxes = UiFbFieldType('checkboxes');
  static const multiselect = UiFbFieldType('multiselect');
  static const checkbox = UiFbFieldType('checkbox');
  static const toggle = UiFbFieldType('toggle');
  static const rating = UiFbFieldType('rating');
  static const slider = UiFbFieldType('slider');
  static const file = UiFbFieldType('file');
  static const hidden = UiFbFieldType('hidden');
  static const calculated = UiFbFieldType('calculated');
}

/// A comparison in a rule. String-backed like [UiFbFieldType].
extension type const UiFbOperator(String name) implements Object {
  static const empty = UiFbOperator('empty');
  static const notEmpty = UiFbOperator('notEmpty');
  static const eq = UiFbOperator('eq');
  static const neq = UiFbOperator('neq');
  static const contains = UiFbOperator('contains');
  static const notContains = UiFbOperator('notContains');
  static const startsWith = UiFbOperator('startsWith');
  static const endsWith = UiFbOperator('endsWith');
  static const gt = UiFbOperator('gt');
  static const gte = UiFbOperator('gte');
  static const lt = UiFbOperator('lt');
  static const lte = UiFbOperator('lte');
  static const between = UiFbOperator('between');
  static const before = UiFbOperator('before');
  static const after = UiFbOperator('after');
  static const onOrBefore = UiFbOperator('onOrBefore');
  static const onOrAfter = UiFbOperator('onOrAfter');
  static const anyOf = UiFbOperator('anyOf');
  static const noneOf = UiFbOperator('noneOf');
  static const includes = UiFbOperator('includes');
  static const excludes = UiFbOperator('excludes');
  static const includesAny = UiFbOperator('includesAny');
  static const includesAll = UiFbOperator('includesAll');
  static const countGte = UiFbOperator('countGte');
  static const countLte = UiFbOperator('countLte');
  static const isTrue = UiFbOperator('isTrue');
  static const isFalse = UiFbOperator('isFalse');
  static const visible = UiFbOperator('visible');
  static const hidden = UiFbOperator('hidden');
  static const complete = UiFbOperator('complete');
  static const incomplete = UiFbOperator('incomplete');
  static const rowsGte = UiFbOperator('rowsGte');
  static const rowsLte = UiFbOperator('rowsLte');
}

/// What a calculation does. String-backed like [UiFbFieldType].
extension type const UiFbCalcOp(String name) implements Object {
  static const sum = UiFbCalcOp('sum');
  static const subtract = UiFbCalcOp('subtract');
  static const multiply = UiFbCalcOp('multiply');
  static const divide = UiFbCalcOp('divide');
  static const average = UiFbCalcOp('average');
  static const min = UiFbCalcOp('min');
  static const max = UiFbCalcOp('max');
  static const count = UiFbCalcOp('count');
  static const ageYears = UiFbCalcOp('ageYears');
  static const daysBetween = UiFbCalcOp('daysBetween');
  static const concat = UiFbCalcOp('concat');
}

// ── JSON helpers ─────────────────────────────────────────────────────────────────────────────

UiJson _map(Object? v) => v is Map ? v.cast<String, Object?>() : <String, Object?>{};
String? _str(Object? v) => v == null ? null : (v is String ? v : jsString(v));
num? _num(Object? v) => v is num ? v : null;
bool? _bool(Object? v) => v is bool ? v : null;
List<T>? _list<T>(Object? v, T Function(Object? x) read) => v is List ? [for (final x in v) read(x)] : null;
List<String>? _strings(Object? v) => _list(v, (x) => _str(x) ?? '');

UiJson _extra(UiJson j, Set<String> known) => {
  for (final e in j.entries)
    if (!known.contains(e.key)) e.key: jsonClone(e.value),
};

void _put(UiJson out, String key, Object? value) {
  if (value != null) out[key] = value;
}

UiJson _withExtra(UiJson out, UiJson extra) {
  for (final e in extra.entries) {
    out.putIfAbsent(e.key, () => jsonClone(e.value));
  }
  return out;
}

// ── Conditions ───────────────────────────────────────────────────────────────────────────────

/// The right-hand side of a comparison: a fixed value, another field's answer, or today ± days.
/// Also used for an option source's params (`const` or `ref`).
sealed class UiFbOperand {
  const UiFbOperand();

  static UiFbOperand fromJson(Object? json) {
    final j = _map(json);
    if (j.containsKey('ref')) return UiFbRefOperand(_str(j['ref']) ?? '', extra: _extra(j, const {'ref'}));
    if (j.containsKey('today')) return UiFbTodayOperand(_num(j['today']) ?? 0, extra: _extra(j, const {'today'}));
    return UiFbConstOperand.raw(j.containsKey('const'), jsonClone(j['const']), extra: _extra(j, const {'const'}));
  }

  UiJson get extra;
  UiJson toJson();
}

/// `{ const: value }`. [hasValue] is false for a stored `{}` (an unfinished rule).
class UiFbConstOperand extends UiFbOperand {
  UiFbConstOperand(this.value, {UiJson? extra}) : hasValue = true, extra = extra ?? {};
  UiFbConstOperand.raw(this.hasValue, this.value, {UiJson? extra}) : extra = extra ?? {};
  final bool hasValue;
  final Object? value;
  @override
  final UiJson extra;
  @override
  UiJson toJson() => _withExtra({if (hasValue) 'const': jsonClone(value)}, extra);
}

/// `{ ref: id }`: another field's current answer.
class UiFbRefOperand extends UiFbOperand {
  UiFbRefOperand(this.ref, {UiJson? extra}) : extra = extra ?? {};
  final String ref;
  @override
  final UiJson extra;
  @override
  UiJson toJson() => _withExtra({'ref': ref}, extra);
}

/// `{ today: n }`: today's date shifted by n days (dates only).
class UiFbTodayOperand extends UiFbOperand {
  UiFbTodayOperand(this.days, {UiJson? extra}) : extra = extra ?? {};
  final num days;
  @override
  final UiJson extra;
  @override
  UiJson toJson() => _withExtra({'today': days}, extra);
}

/// A condition: one rule, or a group of conditions.
sealed class UiFbCondition {
  static UiFbCondition fromJson(Object? json) {
    final j = _map(json);
    return j.containsKey('conditions') ? UiFbConditionGroup.fromJson(j) : UiFbConditionRule.fromJson(j);
  }

  static UiFbCondition? maybe(Object? json) => json is Map ? fromJson(json) : null;

  UiJson toJson();
}

/// One comparison: "`ref` `op` `value`", where `ref` is an element id.
class UiFbConditionRule extends UiFbCondition {
  UiFbConditionRule({required this.ref, required this.op, this.value, this.value2, UiJson? extra}) : extra = extra ?? {};

  factory UiFbConditionRule.fromJson(UiJson j) => UiFbConditionRule(
    ref: _str(j['ref']) ?? '',
    op: UiFbOperator(_str(j['op']) ?? ''),
    value: j['value'] is Map ? UiFbOperand.fromJson(j['value']) : null,
    value2: j['value2'] is Map ? UiFbOperand.fromJson(j['value2']) : null,
    extra: _extra(j, const {'ref', 'op', 'value', 'value2'}),
  );

  String ref;
  UiFbOperator op;
  UiFbOperand? value;

  /// Second bound for `between`.
  UiFbOperand? value2;
  final UiJson extra;

  @override
  UiJson toJson() {
    final out = <String, Object?>{'ref': ref, 'op': op.name};
    _put(out, 'value', value?.toJson());
    _put(out, 'value2', value2?.toJson());
    return _withExtra(out, extra);
  }
}

/// A set of conditions combined with `all` (AND), `any` (OR) or `none` (NOR).
class UiFbConditionGroup extends UiFbCondition {
  UiFbConditionGroup({required this.match, required this.conditions, UiJson? extra}) : extra = extra ?? {};

  factory UiFbConditionGroup.fromJson(UiJson j) => UiFbConditionGroup(
    match: _str(j['match']) ?? 'all',
    conditions: _list(j['conditions'], UiFbCondition.fromJson) ?? [],
    extra: _extra(j, const {'match', 'conditions'}),
  );

  /// `all`, `any` or `none`.
  String match;
  List<UiFbCondition> conditions;
  final UiJson extra;

  @override
  UiJson toJson() => _withExtra({'match': match, 'conditions': [for (final c in conditions) c.toJson()]}, extra);
}

/// `true`/`false`, or "only when this condition holds".
class UiFbToggle {
  UiFbToggle.flag(bool this.flag) : when = null, extra = {};
  UiFbToggle.when(this.when, {UiJson? extra}) : flag = null, extra = extra ?? {};

  static UiFbToggle? fromJson(Object? json) {
    if (json is bool) return UiFbToggle.flag(json);
    if (json is Map) {
      final j = _map(json);
      return UiFbToggle.when(UiFbCondition.maybe(j['when']), extra: _extra(j, const {'when'}));
    }
    return null;
  }

  /// Set for `true`/`false`; null for a conditional toggle.
  final bool? flag;

  /// The condition of a conditional toggle (null in a stored `{}`, which always holds).
  final UiFbCondition? when;
  final UiJson extra;

  bool get isConditional => flag == null;

  Object toJson() => flag ?? _withExtra({if (when != null) 'when': when!.toJson()}, extra);
}

/// Shows or hides an element (or page) when a condition holds.
class UiFbVisibility {
  UiFbVisibility({required this.action, this.when, UiJson? extra}) : extra = extra ?? {};

  static UiFbVisibility? fromJson(Object? json) {
    if (json is! Map) return null;
    final j = _map(json);
    return UiFbVisibility(action: _str(j['action']) ?? 'show', when: UiFbCondition.maybe(j['when']), extra: _extra(j, const {'action', 'when'}));
  }

  /// `show` or `hide`.
  String action;
  UiFbCondition? when;
  final UiJson extra;

  UiJson toJson() {
    final out = <String, Object?>{'action': action};
    _put(out, 'when', when?.toJson());
    return _withExtra(out, extra);
  }
}

/// "When … set this field to …".
class UiFbSetValue {
  UiFbSetValue({required this.id, this.when, required this.value, UiJson? extra}) : extra = extra ?? {};

  factory UiFbSetValue.fromJson(Object? json) {
    final j = _map(json);
    return UiFbSetValue(
      id: _str(j['id']) ?? '',
      when: UiFbCondition.maybe(j['when']),
      value: UiFbOperand.fromJson(j['value']),
      extra: _extra(j, const {'id', 'when', 'value'}),
    );
  }

  String id;
  UiFbCondition? when;
  UiFbOperand value;
  final UiJson extra;

  UiJson toJson() {
    final out = <String, Object?>{'id': id};
    _put(out, 'when', when?.toJson());
    out['value'] = value.toJson();
    return _withExtra(out, extra);
  }
}

// ── Validation ───────────────────────────────────────────────────────────────────────────────

/// A check on a field: a built-in validator type (`minLength`, `email`, …) or an app-registered one.
class UiFbValidatorRule {
  UiFbValidatorRule({required this.id, required this.type, this.params, this.message, this.when, this.severity, UiJson? extra})
    : extra = extra ?? {};

  factory UiFbValidatorRule.fromJson(Object? json) {
    final j = _map(json);
    return UiFbValidatorRule(
      id: _str(j['id']) ?? '',
      type: _str(j['type']) ?? '',
      params: j['params'] is Map ? jsonCloneMap(_map(j['params'])) : null,
      message: _str(j['message']),
      when: UiFbCondition.maybe(j['when']),
      severity: _str(j['severity']),
      extra: _extra(j, const {'id', 'type', 'params', 'message', 'when', 'severity'}),
    );
  }

  String id;
  String type;
  UiJson? params;

  /// Overrides the validator's default message. Supports `{label}` and `{param}` placeholders.
  String? message;

  /// Only check this rule when the condition holds.
  UiFbCondition? when;

  /// `error` (default) or `warning`; warnings are shown but don't block submitting.
  String? severity;
  final UiJson extra;

  UiJson toJson() {
    final out = <String, Object?>{'id': id, 'type': type};
    _put(out, 'params', params == null ? null : jsonClone(params));
    _put(out, 'message', message);
    _put(out, 'when', when?.toJson());
    _put(out, 'severity', severity);
    return _withExtra(out, extra);
  }
}

// ── Calculations ─────────────────────────────────────────────────────────────────────────────

/// An input of a calculation: a field, a fixed value, or a nested calculation.
sealed class UiFbCalcArg {
  static UiFbCalcArg fromJson(Object? json) {
    final j = _map(json);
    if (j.containsKey('ref')) return UiFbCalcRefArg(_str(j['ref']) ?? '', extra: _extra(j, const {'ref'}));
    if (j.containsKey('calc')) return UiFbCalcNestedArg(UiFbCalc.fromJson(j['calc']), extra: _extra(j, const {'calc'}));
    return UiFbCalcConstArg(jsonClone(j['const']), extra: _extra(j, const {'const'}));
  }

  UiJson toJson();
}

class UiFbCalcRefArg extends UiFbCalcArg {
  UiFbCalcRefArg(this.ref, {UiJson? extra}) : extra = extra ?? {};
  final String ref;
  final UiJson extra;
  @override
  UiJson toJson() => _withExtra({'ref': ref}, extra);
}

class UiFbCalcConstArg extends UiFbCalcArg {
  UiFbCalcConstArg(this.value, {UiJson? extra}) : extra = extra ?? {};

  /// A number or a string.
  final Object? value;
  final UiJson extra;
  @override
  UiJson toJson() => _withExtra({'const': value}, extra);
}

class UiFbCalcNestedArg extends UiFbCalcArg {
  UiFbCalcNestedArg(this.calc, {UiJson? extra}) : extra = extra ?? {};
  final UiFbCalc calc;
  final UiJson extra;
  @override
  UiJson toJson() => _withExtra({'calc': calc.toJson()}, extra);
}

class UiFbCalc {
  UiFbCalc({required this.op, required this.args, this.decimals, UiJson? extra}) : extra = extra ?? {};

  factory UiFbCalc.fromJson(Object? json) {
    final j = _map(json);
    return UiFbCalc(
      op: UiFbCalcOp(_str(j['op']) ?? 'sum'),
      args: _list(j['args'], UiFbCalcArg.fromJson) ?? [],
      decimals: _num(j['decimals']),
      extra: _extra(j, const {'op', 'args', 'decimals'}),
    );
  }

  UiFbCalcOp op;
  List<UiFbCalcArg> args;

  /// Round the result to this many decimal places.
  num? decimals;
  final UiJson extra;

  UiJson toJson() {
    final out = <String, Object?>{'op': op.name, 'args': [for (final a in args) a.toJson()]};
    _put(out, 'decimals', decimals);
    return _withExtra(out, extra);
  }
}

// ── Elements ─────────────────────────────────────────────────────────────────────────────────

class UiFbOption {
  UiFbOption({required this.id, required this.value, required this.label, this.archived, UiJson? extra}) : extra = extra ?? {};

  factory UiFbOption.fromJson(Object? json) {
    final j = _map(json);
    return UiFbOption(
      id: _str(j['id']) ?? '',
      value: _str(j['value']) ?? '',
      label: _str(j['label']) ?? '',
      archived: _bool(j['archived']),
      extra: _extra(j, const {'id', 'value', 'label', 'archived'}),
    );
  }

  String id;

  /// Stored in the submitted data. Locked once a form has answers.
  String value;
  String label;

  /// Hidden from new answers but still understood in old ones.
  bool? archived;
  final UiJson extra;

  UiJson toJson() {
    final out = <String, Object?>{'id': id, 'value': value, 'label': label};
    _put(out, 'archived', archived);
    return _withExtra(out, extra);
  }
}

/// Width and label/error placement. Groups and static elements use only `width`.
class UiFbLayout {
  UiFbLayout({this.width, this.labelPlacement, this.errorPlacement, UiJson? extra}) : extra = extra ?? {};

  static UiFbLayout? fromJson(Object? json) {
    if (json is! Map) return null;
    final j = _map(json);
    return UiFbLayout(
      width: _str(j['width']),
      labelPlacement: _str(j['labelPlacement']),
      errorPlacement: _str(j['errorPlacement']),
      extra: _extra(j, const {'width', 'labelPlacement', 'errorPlacement'}),
    );
  }

  /// `full`, `two-thirds`, `half` or `third`.
  String? width;

  /// `top`, `inside`, `left` or `hidden`.
  String? labelPlacement;

  /// `below` or `inside`.
  String? errorPlacement;
  final UiJson extra;

  UiJson toJson() {
    final out = <String, Object?>{};
    _put(out, 'width', width);
    _put(out, 'labelPlacement', labelPlacement);
    _put(out, 'errorPlacement', errorPlacement);
    return _withExtra(out, extra);
  }
}

/// Type-specific settings. Only the ones relevant to a field's type are used.
class UiFbFieldProps {
  UiFbFieldProps({
    this.min,
    this.max,
    this.step,
    this.decimals,
    this.currency,
    this.prefix,
    this.suffix,
    this.rows,
    this.maxRows,
    this.maxRating,
    this.orientation,
    this.selectAll,
    this.multiple,
    this.accept,
    this.autocomplete,
    this.caption,
    this.format,
    this.excludeFromData,
    UiJson? extra,
  }) : extra = extra ?? {};

  static UiFbFieldProps? fromJson(Object? json) {
    if (json is! Map) return null;
    final j = _map(json);
    return UiFbFieldProps(
      min: _num(j['min']),
      max: _num(j['max']),
      step: _num(j['step']),
      decimals: _num(j['decimals']),
      currency: _str(j['currency']),
      prefix: _str(j['prefix']),
      suffix: _str(j['suffix']),
      rows: _num(j['rows']),
      maxRows: _num(j['maxRows']),
      maxRating: _num(j['maxRating']),
      orientation: _str(j['orientation']),
      selectAll: _bool(j['selectAll']),
      multiple: _bool(j['multiple']),
      accept: _str(j['accept']),
      autocomplete: _str(j['autocomplete']),
      caption: _str(j['caption']),
      format: _str(j['format']),
      excludeFromData: _bool(j['excludeFromData']),
      extra: _extra(j, _keys),
    );
  }

  static const _keys = {
    'min', 'max', 'step', 'decimals', 'currency', 'prefix', 'suffix', 'rows', 'maxRows', 'maxRating', 'orientation', //
    'selectAll', 'multiple', 'accept', 'autocomplete', 'caption', 'format', 'excludeFromData',
  };

  num? min;
  num? max;
  num? step;
  num? decimals;
  String? currency;
  String? prefix;
  String? suffix;
  num? rows;
  num? maxRows;
  num? maxRating;

  /// `vertical` or `horizontal`.
  String? orientation;
  bool? selectAll;
  bool? multiple;
  String? accept;
  String? autocomplete;

  /// Text shown next to a single checkbox or toggle.
  String? caption;

  /// For calculated fields: `number`, `currency` or `text`.
  String? format;

  /// For calculated fields: leave the result out of the submitted data.
  bool? excludeFromData;
  final UiJson extra;

  UiJson toJson() {
    final out = <String, Object?>{};
    _put(out, 'min', min);
    _put(out, 'max', max);
    _put(out, 'step', step);
    _put(out, 'decimals', decimals);
    _put(out, 'currency', currency);
    _put(out, 'prefix', prefix);
    _put(out, 'suffix', suffix);
    _put(out, 'rows', rows);
    _put(out, 'maxRows', maxRows);
    _put(out, 'maxRating', maxRating);
    _put(out, 'orientation', orientation);
    _put(out, 'selectAll', selectAll);
    _put(out, 'multiple', multiple);
    _put(out, 'accept', accept);
    _put(out, 'autocomplete', autocomplete);
    _put(out, 'caption', caption);
    _put(out, 'format', format);
    _put(out, 'excludeFromData', excludeFromData);
    return _withExtra(out, extra);
  }
}

/// A param's value for an option source: fixed (`UiFbConstOperand`) or another answer (`UiFbRefOperand`).
typedef UiFbSourceParamValue = UiFbOperand;

/// Which registered list a dropdown or multi-select searches, and its settings.
class UiFbOptionSourceRef {
  UiFbOptionSourceRef({required this.type, this.params, UiJson? extra}) : extra = extra ?? {};

  static UiFbOptionSourceRef? fromJson(Object? json) {
    if (json is! Map) return null;
    final j = _map(json);
    return UiFbOptionSourceRef(
      type: _str(j['type']) ?? '',
      params: j['params'] is Map ? {for (final e in _map(j['params']).entries) e.key: UiFbOperand.fromJson(e.value)} : null,
      extra: _extra(j, const {'type', 'params'}),
    );
  }

  /// The registered source's `type`.
  String type;
  Map<String, UiFbSourceParamValue>? params;
  final UiJson extra;

  UiJson toJson() {
    final out = <String, Object?>{'type': type};
    _put(out, 'params', params == null ? null : {for (final e in params!.entries) e.key: e.value.toJson()});
    return _withExtra(out, extra);
  }
}

/// One item on a page: a question, a section, or static content.
sealed class UiFbElement {
  static UiFbElement fromJson(Object? json) {
    final j = _map(json);
    return switch (j['kind']) {
      'field' => UiFbField.fromJson(j),
      'group' => UiFbGroup.fromJson(j),
      'static' => UiFbStatic.fromJson(j),
      _ => throw FormatException('Unknown element kind "${j['kind']}"', j),
    };
  }

  String get id;
  set id(String v);
  String get kind;
  UiFbVisibility? get visibility;
  set visibility(UiFbVisibility? v);
  bool? get archived;
  UiJson get extra;
  UiJson toJson();
}

class UiFbField extends UiFbElement {
  UiFbField({
    required this.id,
    required this.type,
    required this.key,
    this.keyHistory,
    this.label = '',
    this.help,
    this.placeholder,
    this.hasDefaultValue = false,
    this.defaultValue,
    this.readOnly,
    this.required,
    this.requiredMessage,
    this.disabled,
    this.visibility,
    this.options,
    this.source,
    this.props,
    this.validators,
    this.calc,
    this.setValue,
    this.layout,
    this.archived,
    UiJson? extra,
  }) : extra = extra ?? {};

  factory UiFbField.fromJson(UiJson j) => UiFbField(
    id: _str(j['id']) ?? '',
    type: UiFbFieldType(_str(j['type']) ?? 'text'),
    key: _str(j['key']) ?? '',
    keyHistory: _strings(j['keyHistory']),
    label: _str(j['label']) ?? '',
    help: _str(j['help']),
    placeholder: _str(j['placeholder']),
    hasDefaultValue: j.containsKey('defaultValue'),
    defaultValue: jsonClone(j['defaultValue']),
    readOnly: _bool(j['readOnly']),
    required: UiFbToggle.fromJson(j['required']),
    requiredMessage: _str(j['requiredMessage']),
    disabled: UiFbToggle.fromJson(j['disabled']),
    visibility: UiFbVisibility.fromJson(j['visibility']),
    options: _list(j['options'], UiFbOption.fromJson),
    source: UiFbOptionSourceRef.fromJson(j['source']),
    props: UiFbFieldProps.fromJson(j['props']),
    validators: _list(j['validators'], UiFbValidatorRule.fromJson),
    calc: j['calc'] is Map ? UiFbCalc.fromJson(j['calc']) : null,
    setValue: _list(j['setValue'], UiFbSetValue.fromJson),
    layout: UiFbLayout.fromJson(j['layout']),
    archived: _bool(j['archived']),
    extra: _extra(j, _keys),
  );

  static const _keys = {
    'kind', 'id', 'type', 'key', 'keyHistory', 'label', 'help', 'placeholder', 'defaultValue', 'readOnly', 'required', //
    'requiredMessage', 'disabled', 'visibility', 'options', 'source', 'props', 'validators', 'calc', 'setValue', 'layout', 'archived',
  };

  @override
  String get kind => 'field';
  @override
  String id;
  UiFbFieldType type;
  String key;
  List<String>? keyHistory;
  String label;
  String? help;
  String? placeholder;

  /// Whether the JSON has a `defaultValue` (it may be `null`).
  bool hasDefaultValue;
  Object? defaultValue;
  bool? readOnly;
  UiFbToggle? required;
  String? requiredMessage;
  UiFbToggle? disabled;
  @override
  UiFbVisibility? visibility;
  List<UiFbOption>? options;

  /// Dropdowns and multi-selects only: take the options from an app-registered list instead of
  /// `options`. Answers are then saved as `{ value, label }` (a list of them for multi-selects).
  UiFbOptionSourceRef? source;
  UiFbFieldProps? props;
  List<UiFbValidatorRule>? validators;
  UiFbCalc? calc;
  List<UiFbSetValue>? setValue;
  UiFbLayout? layout;
  @override
  bool? archived;
  @override
  final UiJson extra;

  @override
  UiJson toJson() {
    final out = <String, Object?>{'kind': 'field', 'id': id, 'type': type.name, 'key': key};
    _put(out, 'keyHistory', keyHistory == null ? null : [...keyHistory!]);
    out['label'] = label;
    _put(out, 'help', help);
    _put(out, 'placeholder', placeholder);
    if (hasDefaultValue) out['defaultValue'] = jsonClone(defaultValue);
    _put(out, 'readOnly', readOnly);
    _put(out, 'required', required?.toJson());
    _put(out, 'requiredMessage', requiredMessage);
    _put(out, 'disabled', disabled?.toJson());
    _put(out, 'visibility', visibility?.toJson());
    _put(out, 'options', options?.map((o) => o.toJson()).toList());
    _put(out, 'source', source?.toJson());
    _put(out, 'props', props?.toJson());
    _put(out, 'validators', validators?.map((v) => v.toJson()).toList());
    _put(out, 'calc', calc?.toJson());
    _put(out, 'setValue', setValue?.map((s) => s.toJson()).toList());
    _put(out, 'layout', layout?.toJson());
    _put(out, 'archived', archived);
    return _withExtra(out, extra);
  }
}

class UiFbRepeat {
  UiFbRepeat({this.min, this.max, this.addLabel, this.itemLabel, UiJson? extra}) : extra = extra ?? {};

  static UiFbRepeat? fromJson(Object? json) {
    if (json is! Map) return null;
    final j = _map(json);
    return UiFbRepeat(
      min: _num(j['min']),
      max: _num(j['max']),
      addLabel: _str(j['addLabel']),
      itemLabel: _str(j['itemLabel']),
      extra: _extra(j, const {'min', 'max', 'addLabel', 'itemLabel'}),
    );
  }

  num? min;
  num? max;

  /// Label of the "add another" button.
  String? addLabel;

  /// Title of each entry; `{n}` is replaced by its number.
  String? itemLabel;
  final UiJson extra;

  UiJson toJson() {
    final out = <String, Object?>{};
    _put(out, 'min', min);
    _put(out, 'max', max);
    _put(out, 'addLabel', addLabel);
    _put(out, 'itemLabel', itemLabel);
    return _withExtra(out, extra);
  }
}

class UiFbGroup extends UiFbElement {
  UiFbGroup({
    required this.id,
    this.title,
    this.description,
    this.key,
    this.keyHistory,
    this.columns,
    this.repeat,
    this.visibility,
    this.disabled,
    this.layout,
    List<UiFbElement>? elements,
    this.archived,
    UiJson? extra,
  }) : elements = elements ?? [],
       extra = extra ?? {};

  factory UiFbGroup.fromJson(UiJson j) => UiFbGroup(
    id: _str(j['id']) ?? '',
    title: _str(j['title']),
    description: _str(j['description']),
    key: _str(j['key']),
    keyHistory: _strings(j['keyHistory']),
    columns: _num(j['columns']),
    repeat: UiFbRepeat.fromJson(j['repeat']),
    visibility: UiFbVisibility.fromJson(j['visibility']),
    disabled: UiFbToggle.fromJson(j['disabled']),
    layout: UiFbLayout.fromJson(j['layout']),
    elements: _list(j['elements'], UiFbElement.fromJson) ?? [],
    archived: _bool(j['archived']),
    extra: _extra(j, const {'kind', 'id', 'title', 'description', 'key', 'keyHistory', 'columns', 'repeat', 'visibility', 'disabled', 'layout', 'elements', 'archived'}),
  );

  @override
  String get kind => 'group';
  @override
  String id;
  String? title;
  String? description;

  /// When set, the group's answers are nested under this key. Required for repeatable groups.
  String? key;
  List<String>? keyHistory;

  /// 1, 2 or 3.
  num? columns;
  UiFbRepeat? repeat;
  @override
  UiFbVisibility? visibility;
  UiFbToggle? disabled;
  UiFbLayout? layout;
  List<UiFbElement> elements;
  @override
  bool? archived;
  @override
  final UiJson extra;

  @override
  UiJson toJson() {
    final out = <String, Object?>{'kind': 'group', 'id': id};
    _put(out, 'title', title);
    _put(out, 'description', description);
    _put(out, 'key', key);
    _put(out, 'keyHistory', keyHistory == null ? null : [...keyHistory!]);
    _put(out, 'columns', columns);
    _put(out, 'repeat', repeat?.toJson());
    _put(out, 'visibility', visibility?.toJson());
    _put(out, 'disabled', disabled?.toJson());
    _put(out, 'layout', layout?.toJson());
    out['elements'] = [for (final e in elements) e.toJson()];
    _put(out, 'archived', archived);
    return _withExtra(out, extra);
  }
}

/// A heading, paragraph or divider.
class UiFbStatic extends UiFbElement {
  UiFbStatic({required this.id, required this.type, this.text, this.visibility, this.layout, this.archived, UiJson? extra}) : extra = extra ?? {};

  factory UiFbStatic.fromJson(UiJson j) => UiFbStatic(
    id: _str(j['id']) ?? '',
    type: _str(j['type']) ?? 'paragraph',
    text: _str(j['text']),
    visibility: UiFbVisibility.fromJson(j['visibility']),
    layout: UiFbLayout.fromJson(j['layout']),
    archived: _bool(j['archived']),
    extra: _extra(j, const {'kind', 'id', 'type', 'text', 'visibility', 'layout', 'archived'}),
  );

  @override
  String get kind => 'static';
  @override
  String id;

  /// `heading`, `paragraph` or `divider`.
  String type;
  String? text;
  @override
  UiFbVisibility? visibility;
  UiFbLayout? layout;
  @override
  bool? archived;
  @override
  final UiJson extra;

  @override
  UiJson toJson() {
    final out = <String, Object?>{'kind': 'static', 'id': id, 'type': type};
    _put(out, 'text', text);
    _put(out, 'visibility', visibility?.toJson());
    _put(out, 'layout', layout?.toJson());
    _put(out, 'archived', archived);
    return _withExtra(out, extra);
  }
}

class UiFbJump {
  UiFbJump({required this.id, this.when, required this.to, UiJson? extra}) : extra = extra ?? {};

  factory UiFbJump.fromJson(Object? json) {
    final j = _map(json);
    return UiFbJump(id: _str(j['id']) ?? '', when: UiFbCondition.maybe(j['when']), to: _str(j['to']) ?? '', extra: _extra(j, const {'id', 'when', 'to'}));
  }

  String id;
  UiFbCondition? when;

  /// A later page's id, or `end` to go straight to submitting.
  String to;
  final UiJson extra;

  UiJson toJson() {
    final out = <String, Object?>{'id': id};
    _put(out, 'when', when?.toJson());
    out['to'] = to;
    return _withExtra(out, extra);
  }
}

class UiFbPage {
  UiFbPage({required this.id, this.title, this.description, this.visibility, this.jumps, List<UiFbElement>? elements, UiJson? extra})
    : elements = elements ?? [],
      extra = extra ?? {};

  factory UiFbPage.fromJson(Object? json) {
    final j = _map(json);
    return UiFbPage(
      id: _str(j['id']) ?? '',
      title: _str(j['title']),
      description: _str(j['description']),
      visibility: UiFbVisibility.fromJson(j['visibility']),
      jumps: _list(j['jumps'], UiFbJump.fromJson),
      elements: _list(j['elements'], UiFbElement.fromJson) ?? [],
      extra: _extra(j, const {'id', 'title', 'description', 'visibility', 'jumps', 'elements'}),
    );
  }

  String id;
  String? title;
  String? description;
  UiFbVisibility? visibility;

  /// Checked in order after this page; the first that holds decides where to go next.
  List<UiFbJump>? jumps;
  List<UiFbElement> elements;
  final UiJson extra;

  UiJson toJson() {
    final out = <String, Object?>{'id': id};
    _put(out, 'title', title);
    _put(out, 'description', description);
    _put(out, 'visibility', visibility?.toJson());
    _put(out, 'jumps', jumps?.map((j) => j.toJson()).toList());
    out['elements'] = [for (final e in elements) e.toJson()];
    return _withExtra(out, extra);
  }
}

class UiFbSettings {
  UiFbSettings({
    this.labelPlacement,
    this.errorPlacement,
    this.validateOn,
    this.clearHidden,
    this.errorSummary,
    this.requiredMarker,
    this.submitLabel,
    this.nextLabel,
    this.backLabel,
    this.showProgress,
    UiJson? extra,
  }) : extra = extra ?? {};

  factory UiFbSettings.fromJson(Object? json) {
    final j = _map(json);
    return UiFbSettings(
      labelPlacement: _str(j['labelPlacement']),
      errorPlacement: _str(j['errorPlacement']),
      validateOn: _str(j['validateOn']),
      clearHidden: _str(j['clearHidden']),
      errorSummary: _bool(j['errorSummary']),
      requiredMarker: _str(j['requiredMarker']),
      submitLabel: _str(j['submitLabel']),
      nextLabel: _str(j['nextLabel']),
      backLabel: _str(j['backLabel']),
      showProgress: _bool(j['showProgress']),
      extra: _extra(j, const {
        'labelPlacement', 'errorPlacement', 'validateOn', 'clearHidden', 'errorSummary', 'requiredMarker', //
        'submitLabel', 'nextLabel', 'backLabel', 'showProgress',
      }),
    );
  }

  /// `top`, `inside`, `left` or `hidden`.
  String? labelPlacement;

  /// `below` or `inside`.
  String? errorPlacement;

  /// `blur`: check a field when it is left, then live once it shows an error. `submit`: only on next/submit.
  String? validateOn;

  /// What happens to the answer of a field that rules hide: `onSubmit` or `never`.
  String? clearHidden;
  bool? errorSummary;

  /// `asterisk`, `optional` or `none`.
  String? requiredMarker;
  String? submitLabel;
  String? nextLabel;
  String? backLabel;
  bool? showProgress;
  final UiJson extra;

  UiFbSettings clone() => UiFbSettings.fromJson(toJson());

  UiJson toJson() {
    final out = <String, Object?>{};
    _put(out, 'labelPlacement', labelPlacement);
    _put(out, 'errorPlacement', errorPlacement);
    _put(out, 'validateOn', validateOn);
    _put(out, 'clearHidden', clearHidden);
    _put(out, 'errorSummary', errorSummary);
    _put(out, 'requiredMarker', requiredMarker);
    _put(out, 'submitLabel', submitLabel);
    _put(out, 'nextLabel', nextLabel);
    _put(out, 'backLabel', backLabel);
    _put(out, 'showProgress', showProgress);
    return _withExtra(out, extra);
  }
}

class UiFormDefinition {
  UiFormDefinition({
    this.schemaVersion = uiFbSchemaVersion,
    required this.id,
    required this.title,
    this.description,
    this.revision,
    this.settings,
    required this.pages,
    UiJson? extra,
  }) : extra = extra ?? {};

  /// Reads a stored definition as-is. Use `migrateDefinition` for JSON that may be old or partial.
  factory UiFormDefinition.fromJson(Object? json) {
    final j = _map(json);
    return UiFormDefinition(
      schemaVersion: _num(j['schemaVersion'])?.toInt() ?? uiFbSchemaVersion,
      id: _str(j['id']) ?? '',
      title: _str(j['title']) ?? '',
      description: _str(j['description']),
      revision: _num(j['revision']),
      settings: j['settings'] is Map ? UiFbSettings.fromJson(j['settings']) : null,
      pages: _list(j['pages'], UiFbPage.fromJson) ?? [],
      extra: _extra(j, const {'schemaVersion', 'id', 'title', 'description', 'revision', 'settings', 'pages'}),
    );
  }

  int schemaVersion;
  String id;
  String title;
  String? description;

  /// Bumped by the host each time it publishes; recorded on every submission.
  num? revision;
  UiFbSettings? settings;
  List<UiFbPage> pages;
  final UiJson extra;

  /// A deep copy (through JSON, so it shares nothing with this one).
  UiFormDefinition clone() => UiFormDefinition.fromJson(toJson());

  UiJson toJson() {
    final out = <String, Object?>{'schemaVersion': schemaVersion, 'id': id, 'title': title};
    _put(out, 'description', description);
    _put(out, 'revision', revision);
    _put(out, 'settings', settings?.toJson());
    out['pages'] = [for (final p in pages) p.toJson()];
    return _withExtra(out, extra);
  }
}

// ── Answers ──────────────────────────────────────────────────────────────────────────────────

/// What a file field stores. `url`/`id` come from the host's uploader. Answers are kept as plain
/// JSON maps in the engine; this class reads and writes that shape.
class UiFbFileValue {
  const UiFbFileValue({required this.name, required this.size, required this.type, this.url, this.id});

  factory UiFbFileValue.fromJson(Object? json) {
    final j = _map(json);
    return UiFbFileValue(name: _str(j['name']) ?? '', size: _num(j['size']) ?? 0, type: _str(j['type']) ?? '', url: _str(j['url']), id: _str(j['id']));
  }

  final String name;
  final num size;
  final String type;
  final String? url;
  final String? id;

  UiJson toJson() {
    final out = <String, Object?>{'name': name, 'size': size, 'type': type};
    _put(out, 'url', url);
    _put(out, 'id', id);
    return out;
  }
}

/// A file picked in this session: its metadata plus whatever handle the app needs to upload it
/// later (bytes, a path, a platform file object). The engine never reads [handle].
class UiFbPickedFile {
  const UiFbPickedFile({required this.name, required this.size, required this.type, this.handle});
  final String name;
  final int size;
  final String type;
  final Object? handle;
}

/// Emitted when a form is submitted. `data` is the JSON to store.
class UiFormSubmission {
  const UiFormSubmission({required this.formId, required this.revision, required this.data, required this.submittedAt, required this.files});
  final String formId;
  final num? revision;
  final UiJson data;

  /// ISO 8601 in UTC with milliseconds, like JS `toISOString()`.
  final String submittedAt;

  /// Files picked in this session that have no uploader URL yet, keyed by data path.
  final Map<String, List<UiFbPickedFile>> files;

  UiJson toJson() => {'formId': formId, 'revision': revision, 'data': data, 'submittedAt': submittedAt};
}

/// One difference between the data a form was opened with and its current data.
class UiFbChange {
  const UiFbChange({required this.path, required this.label, required this.from, required this.to});
  final String path;
  final String label;
  final Object? from;
  final Object? to;

  UiJson toJson() => {'path': path, 'label': label, 'from': from, 'to': to};

  @override
  bool operator ==(Object other) =>
      other is UiFbChange && other.path == path && other.label == label && jsonEquals(other.from, from) && jsonEquals(other.to, to);

  @override
  int get hashCode => Object.hash(path, label);

  @override
  String toString() => 'UiFbChange(${toJson()})';
}
