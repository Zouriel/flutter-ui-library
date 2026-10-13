import 'schema.dart';

/// The shape of a field's answer; drives which operators and validators make sense.
enum UiFbValueKind { text, number, date, time, choice, multi, boolean, file }

/// What a condition can be about: a field's value kind, or a group / repeatable group / page.
enum UiFbSubjectKind { text, number, date, time, choice, multi, boolean, file, group, repeat, page }

extension UiFbValueKindSubject on UiFbValueKind {
  UiFbSubjectKind get subject => UiFbSubjectKind.values.byName(name);
}

class UiFbFieldTypeInfo {
  const UiFbFieldTypeInfo({
    required this.type,
    required this.label,
    required this.description,
    required this.category,
    required this.valueKind,
    this.hasOptions = false,
    this.placeholder = false,
    this.textLike = false,
    this.noInput = false,
    required this.defaultLabel,
    this.defaultProps,
  });

  final UiFbFieldType type;
  final String label;
  final String description;

  /// `Text`, `Choice`, `Number & date`, `Other` or `Layout`.
  final String category;
  final UiFbValueKind valueKind;

  /// Has a list of options to choose from.
  final bool hasOptions;

  /// Shows a placeholder when empty.
  final bool placeholder;

  /// A single text box, so the label and error can sit inside it.
  final bool textLike;

  /// Has no input for people to fill in.
  final bool noInput;
  final String defaultLabel;

  /// Props a new field of this type starts with (as JSON).
  final Map<String, Object?>? defaultProps;
}

const List<UiFbFieldTypeInfo> uiFbFieldTypes = [
  UiFbFieldTypeInfo(type: UiFbFieldType.text, label: 'Short text', description: 'One line of text, like a name', category: 'Text', valueKind: UiFbValueKind.text, placeholder: true, textLike: true, defaultLabel: 'Short answer'),
  UiFbFieldTypeInfo(type: UiFbFieldType.textarea, label: 'Long text', description: 'Several lines, like a comment', category: 'Text', valueKind: UiFbValueKind.text, placeholder: true, textLike: true, defaultLabel: 'Long answer', defaultProps: {'rows': 3, 'maxRows': 8}),
  UiFbFieldTypeInfo(type: UiFbFieldType.email, label: 'Email', description: 'An email address, checked automatically', category: 'Text', valueKind: UiFbValueKind.text, placeholder: true, textLike: true, defaultLabel: 'Email address', defaultProps: {'autocomplete': 'email'}),
  UiFbFieldTypeInfo(type: UiFbFieldType.phone, label: 'Phone', description: 'A phone number', category: 'Text', valueKind: UiFbValueKind.text, placeholder: true, textLike: true, defaultLabel: 'Phone number', defaultProps: {'autocomplete': 'tel'}),
  UiFbFieldTypeInfo(type: UiFbFieldType.url, label: 'Website', description: 'A web address', category: 'Text', valueKind: UiFbValueKind.text, placeholder: true, textLike: true, defaultLabel: 'Website'),
  UiFbFieldTypeInfo(type: UiFbFieldType.select, label: 'Dropdown', description: 'Pick one option from a list', category: 'Choice', valueKind: UiFbValueKind.choice, hasOptions: true, placeholder: true, defaultLabel: 'Choose one'),
  UiFbFieldTypeInfo(type: UiFbFieldType.radio, label: 'Single choice', description: 'Pick one, all options visible', category: 'Choice', valueKind: UiFbValueKind.choice, hasOptions: true, defaultLabel: 'Pick one', defaultProps: {'orientation': 'vertical'}),
  UiFbFieldTypeInfo(type: UiFbFieldType.checkboxes, label: 'Multiple choice', description: 'Tick any number of options', category: 'Choice', valueKind: UiFbValueKind.multi, hasOptions: true, defaultLabel: 'Pick all that apply', defaultProps: {'orientation': 'vertical'}),
  UiFbFieldTypeInfo(type: UiFbFieldType.multiselect, label: 'Multi-select', description: 'Pick several from a long list', category: 'Choice', valueKind: UiFbValueKind.multi, hasOptions: true, placeholder: true, defaultLabel: 'Choose several'),
  UiFbFieldTypeInfo(type: UiFbFieldType.checkbox, label: 'Checkbox', description: 'A single tick, like agreeing to terms', category: 'Choice', valueKind: UiFbValueKind.boolean, defaultLabel: 'Agreement', defaultProps: {'caption': 'I agree'}),
  UiFbFieldTypeInfo(type: UiFbFieldType.toggle, label: 'Yes / no', description: 'An on/off switch', category: 'Choice', valueKind: UiFbValueKind.boolean, defaultLabel: 'Yes or no', defaultProps: {'caption': 'Yes'}),
  UiFbFieldTypeInfo(type: UiFbFieldType.number, label: 'Number', description: 'A whole or decimal number', category: 'Number & date', valueKind: UiFbValueKind.number, placeholder: true, textLike: true, defaultLabel: 'Number'),
  UiFbFieldTypeInfo(type: UiFbFieldType.currency, label: 'Amount', description: 'A money amount', category: 'Number & date', valueKind: UiFbValueKind.number, placeholder: true, textLike: true, defaultLabel: 'Amount', defaultProps: {'decimals': 2, 'currency': 'USD', 'min': 0}),
  UiFbFieldTypeInfo(type: UiFbFieldType.date, label: 'Date', description: 'A day from a calendar', category: 'Number & date', valueKind: UiFbValueKind.date, placeholder: true, defaultLabel: 'Date'),
  UiFbFieldTypeInfo(type: UiFbFieldType.time, label: 'Time', description: 'A time of day', category: 'Number & date', valueKind: UiFbValueKind.time, defaultLabel: 'Time'),
  UiFbFieldTypeInfo(type: UiFbFieldType.rating, label: 'Rating', description: 'Stars from 1 to 5', category: 'Number & date', valueKind: UiFbValueKind.number, defaultLabel: 'Rating', defaultProps: {'maxRating': 5}),
  UiFbFieldTypeInfo(type: UiFbFieldType.slider, label: 'Slider', description: 'A number picked on a scale', category: 'Number & date', valueKind: UiFbValueKind.number, defaultLabel: 'Scale', defaultProps: {'min': 0, 'max': 10, 'step': 1}),
  UiFbFieldTypeInfo(type: UiFbFieldType.file, label: 'File upload', description: 'Attach one or more files', category: 'Other', valueKind: UiFbValueKind.file, defaultLabel: 'Attachment'),
  UiFbFieldTypeInfo(type: UiFbFieldType.calculated, label: 'Calculated', description: 'Worked out from other answers', category: 'Other', valueKind: UiFbValueKind.number, noInput: true, defaultLabel: 'Total', defaultProps: {'format': 'number'}),
  UiFbFieldTypeInfo(type: UiFbFieldType.hidden, label: 'Hidden value', description: 'Stored with the answers, never shown', category: 'Other', valueKind: UiFbValueKind.text, noInput: true, defaultLabel: 'Hidden value'),
];

class UiFbStaticTypeInfo {
  const UiFbStaticTypeInfo({required this.type, required this.label, required this.description});

  /// `heading`, `paragraph` or `divider`.
  final String type;
  final String label;
  final String description;
}

const List<UiFbStaticTypeInfo> uiFbStaticTypes = [
  UiFbStaticTypeInfo(type: 'heading', label: 'Heading', description: 'A title between questions'),
  UiFbStaticTypeInfo(type: 'paragraph', label: 'Text block', description: 'Instructions or an explanation'),
  UiFbStaticTypeInfo(type: 'divider', label: 'Divider', description: 'A line between sections'),
];

final Map<UiFbFieldType, UiFbFieldTypeInfo> _byType = {for (final t in uiFbFieldTypes) t.type: t};

/// The palette entry for a type; unknown types fall back to short text.
UiFbFieldTypeInfo fieldTypeInfo(UiFbFieldType type) => _byType[type] ?? uiFbFieldTypes[0];

/// The value kind a field's answer has. A calculated field that joins text is text; every other
/// calculation is a number.
UiFbValueKind valueKindOf(UiFbFieldType type, [String? format]) {
  if (type == UiFbFieldType.calculated) return format == 'text' ? UiFbValueKind.text : UiFbValueKind.number;
  return fieldTypeInfo(type).valueKind;
}

class UiFbOperatorInfo {
  const UiFbOperatorInfo(this.op, this.label, this.arity, {this.multiValue = false, this.countValue = false});
  final UiFbOperator op;

  /// Reads after the field name: "Age *is more than* 18".
  final String label;

  /// How many values it compares against (0, 1 or 2).
  final int arity;

  /// The operand is a list of options rather than one.
  final bool multiValue;

  /// The operand is a count rather than the field's own kind of value.
  final bool countValue;
}

const Map<UiFbOperator, UiFbOperatorInfo> _ops = {
  UiFbOperator.empty: UiFbOperatorInfo(UiFbOperator.empty, 'is empty', 0),
  UiFbOperator.notEmpty: UiFbOperatorInfo(UiFbOperator.notEmpty, 'is filled in', 0),
  UiFbOperator.eq: UiFbOperatorInfo(UiFbOperator.eq, 'is', 1),
  UiFbOperator.neq: UiFbOperatorInfo(UiFbOperator.neq, 'is not', 1),
  UiFbOperator.contains: UiFbOperatorInfo(UiFbOperator.contains, 'contains', 1),
  UiFbOperator.notContains: UiFbOperatorInfo(UiFbOperator.notContains, 'does not contain', 1),
  UiFbOperator.startsWith: UiFbOperatorInfo(UiFbOperator.startsWith, 'starts with', 1),
  UiFbOperator.endsWith: UiFbOperatorInfo(UiFbOperator.endsWith, 'ends with', 1),
  UiFbOperator.gt: UiFbOperatorInfo(UiFbOperator.gt, 'is more than', 1),
  UiFbOperator.gte: UiFbOperatorInfo(UiFbOperator.gte, 'is at least', 1),
  UiFbOperator.lt: UiFbOperatorInfo(UiFbOperator.lt, 'is less than', 1),
  UiFbOperator.lte: UiFbOperatorInfo(UiFbOperator.lte, 'is at most', 1),
  UiFbOperator.between: UiFbOperatorInfo(UiFbOperator.between, 'is between', 2),
  UiFbOperator.before: UiFbOperatorInfo(UiFbOperator.before, 'is before', 1),
  UiFbOperator.after: UiFbOperatorInfo(UiFbOperator.after, 'is after', 1),
  UiFbOperator.onOrBefore: UiFbOperatorInfo(UiFbOperator.onOrBefore, 'is on or before', 1),
  UiFbOperator.onOrAfter: UiFbOperatorInfo(UiFbOperator.onOrAfter, 'is on or after', 1),
  UiFbOperator.anyOf: UiFbOperatorInfo(UiFbOperator.anyOf, 'is any of', 1, multiValue: true),
  UiFbOperator.noneOf: UiFbOperatorInfo(UiFbOperator.noneOf, 'is none of', 1, multiValue: true),
  UiFbOperator.includes: UiFbOperatorInfo(UiFbOperator.includes, 'includes', 1),
  UiFbOperator.excludes: UiFbOperatorInfo(UiFbOperator.excludes, 'does not include', 1),
  UiFbOperator.includesAny: UiFbOperatorInfo(UiFbOperator.includesAny, 'includes any of', 1, multiValue: true),
  UiFbOperator.includesAll: UiFbOperatorInfo(UiFbOperator.includesAll, 'includes all of', 1, multiValue: true),
  UiFbOperator.countGte: UiFbOperatorInfo(UiFbOperator.countGte, 'has at least … ticked', 1, countValue: true),
  UiFbOperator.countLte: UiFbOperatorInfo(UiFbOperator.countLte, 'has at most … ticked', 1, countValue: true),
  UiFbOperator.isTrue: UiFbOperatorInfo(UiFbOperator.isTrue, 'is ticked', 0),
  UiFbOperator.isFalse: UiFbOperatorInfo(UiFbOperator.isFalse, 'is not ticked', 0),
  UiFbOperator.visible: UiFbOperatorInfo(UiFbOperator.visible, 'is shown', 0),
  UiFbOperator.hidden: UiFbOperatorInfo(UiFbOperator.hidden, 'is hidden', 0),
  UiFbOperator.complete: UiFbOperatorInfo(UiFbOperator.complete, 'is complete', 0),
  UiFbOperator.incomplete: UiFbOperatorInfo(UiFbOperator.incomplete, 'is not complete', 0),
  UiFbOperator.rowsGte: UiFbOperatorInfo(UiFbOperator.rowsGte, 'has at least … entries', 1, countValue: true),
  UiFbOperator.rowsLte: UiFbOperatorInfo(UiFbOperator.rowsLte, 'has at most … entries', 1, countValue: true),
};

/// The description of an operator. Unknown operators read as a one-value "is".
UiFbOperatorInfo operatorInfo(UiFbOperator op) => _ops[op] ?? UiFbOperatorInfo(op, op.name, 1);

/// Whether [op] is one the library knows.
bool isKnownOperator(UiFbOperator op) => _ops.containsKey(op);

const Map<UiFbSubjectKind, List<UiFbOperator>> _opsByKind = {
  UiFbSubjectKind.text: [UiFbOperator.eq, UiFbOperator.neq, UiFbOperator.contains, UiFbOperator.notContains, UiFbOperator.startsWith, UiFbOperator.endsWith, UiFbOperator.notEmpty, UiFbOperator.empty],
  UiFbSubjectKind.number: [UiFbOperator.eq, UiFbOperator.neq, UiFbOperator.gt, UiFbOperator.gte, UiFbOperator.lt, UiFbOperator.lte, UiFbOperator.between, UiFbOperator.notEmpty, UiFbOperator.empty],
  UiFbSubjectKind.date: [UiFbOperator.eq, UiFbOperator.before, UiFbOperator.after, UiFbOperator.onOrBefore, UiFbOperator.onOrAfter, UiFbOperator.between, UiFbOperator.notEmpty, UiFbOperator.empty],
  UiFbSubjectKind.time: [UiFbOperator.eq, UiFbOperator.before, UiFbOperator.after, UiFbOperator.between, UiFbOperator.notEmpty, UiFbOperator.empty],
  UiFbSubjectKind.choice: [UiFbOperator.eq, UiFbOperator.neq, UiFbOperator.anyOf, UiFbOperator.noneOf, UiFbOperator.notEmpty, UiFbOperator.empty],
  UiFbSubjectKind.multi: [UiFbOperator.includes, UiFbOperator.excludes, UiFbOperator.includesAny, UiFbOperator.includesAll, UiFbOperator.countGte, UiFbOperator.countLte, UiFbOperator.notEmpty, UiFbOperator.empty],
  UiFbSubjectKind.boolean: [UiFbOperator.isTrue, UiFbOperator.isFalse],
  UiFbSubjectKind.file: [UiFbOperator.notEmpty, UiFbOperator.empty, UiFbOperator.countGte, UiFbOperator.countLte],
  UiFbSubjectKind.group: [UiFbOperator.complete, UiFbOperator.incomplete, UiFbOperator.visible, UiFbOperator.hidden],
  UiFbSubjectKind.repeat: [UiFbOperator.rowsGte, UiFbOperator.rowsLte, UiFbOperator.complete, UiFbOperator.incomplete, UiFbOperator.visible, UiFbOperator.hidden],
  UiFbSubjectKind.page: [UiFbOperator.complete, UiFbOperator.incomplete, UiFbOperator.visible, UiFbOperator.hidden],
};

/// Operators offered for a value kind (or for a group / repeatable group / page).
List<UiFbOperatorInfo> operatorsFor(UiFbSubjectKind kind) => [for (final op in _opsByKind[kind]!) _ops[op]!];

/// Field types whose answers can safely change into each other's without losing meaning.
const List<List<UiFbFieldType>> _compatible = [
  [UiFbFieldType.text, UiFbFieldType.textarea, UiFbFieldType.email, UiFbFieldType.phone, UiFbFieldType.url, UiFbFieldType.hidden],
  [UiFbFieldType.select, UiFbFieldType.radio],
  [UiFbFieldType.checkboxes, UiFbFieldType.multiselect],
  [UiFbFieldType.checkbox, UiFbFieldType.toggle],
  [UiFbFieldType.number, UiFbFieldType.currency, UiFbFieldType.slider, UiFbFieldType.rating],
];

bool typesCompatible(UiFbFieldType a, UiFbFieldType b) => a == b || _compatible.any((set) => set.contains(a) && set.contains(b));
