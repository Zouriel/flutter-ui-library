import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../combobox/combobox.dart' show UiComboboxOption;
import '../../combobox/multi_select.dart';
import '../../core/types.dart';
import '../../datepicker/date_picker.dart';
import '../../forms/text/inputs.dart';
import '../../forms/text/number_input.dart';
import '../../forms/text/select.dart';
import '../../forms/text/time_picker.dart';
import '../../theme/theme.dart';
import '../engine/field_types.dart';
import '../engine/js.dart';
import '../engine/option_sources.dart';
import '../engine/schema.dart';
import '../sources/source_picker.dart';
import 'builder_bits.dart';
import 'builder_store.dart';

/// Turns any condition into a group, so the editor always edits "match + list".
UiFbConditionGroup fbAsGroup(UiFbCondition? c) {
  if (c == null) return UiFbConditionGroup(match: 'all', conditions: []);
  if (c is UiFbConditionGroup) return c;
  return UiFbConditionGroup(match: 'all', conditions: [c]);
}

/// Unwraps a one-rule "all" group back to the rule, keeping stored JSON small.
UiFbCondition fbTidy(UiFbConditionGroup g) =>
    g.match == 'all' && g.conditions.length == 1 && g.conditions[0] is! UiFbConditionGroup ? g.conditions[0] : g;

/// An empty "all of these" group, what a new rule section starts with.
UiFbConditionGroup fbEmptyCondition() => UiFbConditionGroup(match: 'all', conditions: []);

UiFbCondition _copy(UiFbCondition c) => UiFbCondition.fromJson(c.toJson());

/// `ui-fb-value`: the right-hand side of a rule, shaped by what's being compared: an option list
/// for choices, a date picker (or "today ± days") for dates, a number box for counts, or another
/// question's answer.
class UiFbValueInput extends StatefulWidget {
  const UiFbValueInput({
    super.key,
    required this.subject,
    this.op = UiFbOperator.eq,
    this.operand,
    this.forId,
    this.label = 'Value',
    this.constOnly = false,
    required this.onChanged,
  });

  /// What's being asked about (the rule's subject).
  final UiFbRefOption? subject;
  final UiFbOperator op;
  final UiFbOperand? operand;

  /// The element the rule lives on (its own answer can't be compared with itself).
  final String? forId;

  /// What the value is, for screen readers ("Value", "Starts with"…).
  final String label;

  /// Only fixed values (e.g. a default answer), never "another answer".
  final bool constOnly;
  final ValueChanged<UiFbOperand> onChanged;

  @override
  State<UiFbValueInput> createState() => _UiFbValueInputState();
}

class _UiFbValueInputState extends State<UiFbValueInput> {
  /// What to browse a dependent list with. Only for picking here; not saved.
  final Map<String, Object?> _browse = {};

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = UiFbBuilderScope.of(context);
    final subject = widget.subject;
    final kind = subject?.kind ?? UiFbSubjectKind.text;
    final info = operatorInfo(widget.op);
    final count = info.countValue;
    final multi = info.multiValue;
    final field = subject == null ? null : store.field(subject.id);
    final options = [for (final o in field?.options ?? const <UiFbOption>[]) if (o.archived != true) (label: o.label, value: o.value)];
    final sourceDef = field?.source == null ? null : store.optionSourceDefs.where((d) => d.type == field!.source!.type).firstOrNull;
    final o = widget.operand;
    final constRaw = o is UiFbConstOperand ? o.value : null;
    final constText = constRaw == null ? '' : jsString(constRaw);
    final constNum = constRaw is num ? constRaw : null;

    final comparable = [for (final r in store.refOptions(widget.forId)) if (r.kind == subject?.kind && r.id != subject?.id) r];
    final sources = <(String, String)>[('const', 'a value')];
    if (!(widget.constOnly || count || multi || !const [UiFbSubjectKind.text, UiFbSubjectKind.number, UiFbSubjectKind.date, UiFbSubjectKind.time].contains(kind))) {
      if (comparable.isNotEmpty) sources.add(('ref', 'another answer'));
      if (kind == UiFbSubjectKind.date) sources.add(('today', 'a date from today'));
    }
    final source = switch (o) {
      UiFbRefOperand() => 'ref',
      UiFbTodayOperand() => 'today',
      _ => 'const',
    };

    void emit(UiFbOperand v) => widget.onChanged(v);

    Widget body;
    if (source == 'ref') {
      final refId = o is UiFbRefOperand ? o.ref : '';
      body = UiSelect(
        label: 'Other answer',
        size: UiSize.sm,
        placeholder: 'Choose an answer…',
        value: refId.isEmpty ? null : refId,
        options: [for (final r in comparable) UiSelectOption(value: r.id, label: r.label)],
        onChanged: (v) => emit(UiFbRefOperand(v)),
      );
    } else if (source == 'today') {
      final days = o is UiFbTodayOperand ? o.days : 0;
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: [
        Row(spacing: t.space2, children: [
          SizedBox(width: 120, child: UiNumberInput(size: UiSize.sm, value: days, step: 1, semanticLabel: 'Days from today', onChanged: (v) => emit(UiFbTodayOperand(v ?? 0)))),
          Text('days from today', style: context.uiText.body.copyWith(fontSize: 12, color: t.textSecondary)),
        ]),
        const FbHint('0 is today, 7 is a week from now, -7 a week ago.'),
      ]);
    } else if (count) {
      body = UiNumberInput(size: UiSize.sm, value: constNum, min: 0, step: 1, semanticLabel: 'How many', onChanged: (v) => emit(UiFbConstOperand(v)));
    } else if (sourceDef != null) {
      // A sourced question: search the same list; the rule keeps {value, label} so it reads well later.
      final params = field!.source!.params ?? const <String, UiFbOperand>{};
      final refParams = [for (final p in sourceDef.params ?? const <UiFbSourceParamSpec>[]) if (params[p.key] is UiFbRefOperand) p];
      final resolved = {for (final e in params.entries) e.key: e.value is UiFbConstOperand ? (e.value as UiFbConstOperand).value : _browse[e.key]};
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: [
        // Its list follows another answer, which a rule doesn't have: pick one to browse with (not saved).
        for (final p in refParams) _BrowseRow(prefix: 'From ${p.label.toLowerCase()}', spec: p, value: _browse[p.key], onChanged: (v) => setState(() => _browse[p.key] = v)),
        UiFbSourcePicker(
          source: sourceDef,
          params: resolved,
          multiple: multi,
          value: constRaw,
          label: widget.label,
          placeholder: 'Search ${sourceDef.label.toLowerCase()}…',
          onChanged: (v) => emit(UiFbConstOperand(v)),
        ),
      ]);
    } else if (options.isNotEmpty && multi) {
      body = UiMultiSelect(
        label: widget.label,
        size: UiSize.sm,
        placeholder: 'Choose options…',
        value: constRaw is List ? [for (final x in constRaw) jsString(x)] : const [],
        options: [for (final op in options) UiComboboxOption(label: op.label, value: op.value)],
        onChanged: (v) => emit(UiFbConstOperand(v)),
      );
    } else if (options.isNotEmpty) {
      body = UiSelect(
        label: widget.label,
        size: UiSize.sm,
        placeholder: 'Choose…',
        value: constText.isEmpty ? null : constText,
        options: [for (final op in options) UiSelectOption(value: op.value, label: op.label)],
        onChanged: (v) => emit(UiFbConstOperand(v)),
      );
    } else {
      body = switch (kind) {
        UiFbSubjectKind.boolean => UiSelect(
          label: widget.label,
          size: UiSize.sm,
          placeholder: 'Choose…',
          value: constText.isEmpty ? null : constText,
          options: const [UiSelectOption(value: 'true', label: 'Ticked (yes)'), UiSelectOption(value: 'false', label: 'Not ticked (no)')],
          onChanged: (v) => emit(UiFbConstOperand(v == 'true')),
        ),
        UiFbSubjectKind.number => UiNumberInput(size: UiSize.sm, value: constNum, semanticLabel: widget.label, onChanged: (v) => emit(UiFbConstOperand(v))),
        UiFbSubjectKind.date => UiDatePicker(size: UiSize.sm, label: widget.label, value: constText.isEmpty ? null : constText, onChanged: (v) => emit(UiFbConstOperand(v))),
        UiFbSubjectKind.time => UiTimePicker(size: UiSize.sm, label: widget.label, value: constText.isEmpty ? null : constText, onChanged: (v) => emit(UiFbConstOperand(v))),
        _ => UiInput(size: UiSize.sm, value: constText, placeholder: 'Value', semanticLabel: widget.label, onChanged: (v) => emit(UiFbConstOperand(v))),
      };
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: [
      if (sources.length > 1)
        UiSelect(
          label: 'Compare with',
          size: UiSize.sm,
          value: source,
          options: [for (final s in sources) UiSelectOption(value: s.$1, label: s.$2)],
          onChanged: (s) => emit(s == 'ref' ? UiFbRefOperand('') : s == 'today' ? UiFbTodayOperand(0) : UiFbConstOperand('')),
        ),
      body,
    ]);
  }
}

/// "From faculty [choose]": a stand-in answer for a list setting that follows another question.
class _BrowseRow extends StatelessWidget {
  const _BrowseRow({required this.prefix, required this.spec, required this.value, required this.onChanged});
  final String prefix;
  final UiFbSourceParamSpec spec;
  final Object? value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final opts = spec.options ?? const [];
    return Row(spacing: t.space2, children: [
      Text(prefix, style: context.uiText.body.copyWith(fontSize: 12, color: t.textSecondary)),
      Expanded(
        child: opts.isNotEmpty
            ? UiSelect(
                label: '$prefix: ${spec.label}',
                size: UiSize.sm,
                placeholder: 'Choose…',
                value: value is String && (value as String).isNotEmpty ? value as String : null,
                options: [for (final o in opts) UiSelectOption(value: o.value, label: o.label)],
                onChanged: (v) => onChanged(v.isEmpty ? null : v),
              )
            : UiInput(size: UiSize.sm, value: value == null ? '' : jsString(value), placeholder: 'A value', semanticLabel: '$prefix: ${spec.label}', onChanged: (v) => onChanged(v.isEmpty ? null : v)),
      ),
    ]);
  }
}

/// `ui-fb-condition`: builds "when …" rules as sentences: pick a question, how to compare, and a
/// value. Rules combine with all/any/none, and one level of nested groups covers "A and (B or C)".
class UiFbConditionEditor extends StatelessWidget {
  const UiFbConditionEditor({super.key, required this.condition, this.forId, this.nested = false, required this.onChanged, this.onRemoved});

  final UiFbCondition? condition;

  /// The element the rule belongs to (decides what it may ask about).
  final String? forId;
  final bool nested;
  final ValueChanged<UiFbCondition> onChanged;

  /// The nested group's remove button was pressed.
  final VoidCallback? onRemoved;

  static String _opLabel(UiFbOperatorInfo i) => i.label.replaceAll(' … ', ' N ').replaceAll('…', 'N');

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = UiFbBuilderScope.of(context);
    final g = fbAsGroup(condition);
    final options = store.refOptions(forId);
    UiFbRefOption? subjectOf(String id) => options.where((o) => o.id == id).firstOrNull;
    List<UiFbOperatorInfo> opsFor(UiFbSubjectKind k) => operatorsFor(k);

    void write(List<UiFbCondition> conditions, [String? match]) {
      final next = UiFbConditionGroup(match: match ?? g.match, conditions: conditions);
      onChanged(nested ? next : fbTidy(next));
    }

    List<UiFbCondition> list() => [for (final c in g.conditions) _copy(c)];
    void replace(int i, UiFbCondition c) => write(list()..[i] = c);
    void remove(int i) => write(list()..removeAt(i));

    UiFbConditionRule newRule(UiFbRefOption? first) =>
        first != null ? UiFbConditionRule(ref: first.id, op: opsFor(first.kind).first.op) : UiFbConditionRule(ref: '', op: UiFbOperator.eq);

    void addRule() {
      // Start from the question asked about most recently: rules usually share it.
      final prev = g.conditions.reversed.whereType<UiFbConditionRule>().firstOrNull;
      final first = prev != null && prev.ref.isNotEmpty
          ? subjectOf(prev.ref)
          : options.where((o) => o.kind != UiFbSubjectKind.page && o.kind != UiFbSubjectKind.group).firstOrNull;
      write([...list(), newRule(first)]);
    }

    void addGroup() => write([...list(), UiFbConditionGroup(match: 'any', conditions: [newRule(options.firstOrNull)])]);

    void setRef(int i, String ref) {
      final subj = subjectOf(ref);
      final old = g.conditions[i] as UiFbConditionRule;
      final sameKind = subj != null && subjectOf(old.ref)?.kind == subj.kind;
      final ops = subj != null ? opsFor(subj.kind) : const <UiFbOperatorInfo>[];
      final op = sameKind && ops.any((o) => o.op == old.op) ? old.op : (ops.firstOrNull?.op ?? UiFbOperator.eq);
      replace(i, UiFbConditionRule(ref: ref, op: op));
    }

    void setOp(int i, UiFbOperator op) {
      final old = g.conditions[i] as UiFbConditionRule;
      final was = operatorInfo(old.op);
      final now = operatorInfo(op);
      // Keep the value when it still makes sense for the new comparison.
      final keep = now.arity > 0 && was.multiValue == now.multiValue && was.countValue == now.countValue;
      replace(i, UiFbConditionRule(ref: old.ref, op: op, value: keep ? old.value : null, value2: keep && now.arity == 2 ? old.value2 : null));
    }

    void setValue(int i, bool second, UiFbOperand v) {
      final old = g.conditions[i] as UiFbConditionRule;
      replace(i, UiFbConditionRule(ref: old.ref, op: old.op, value: second ? old.value : v, value2: second ? v : old.value2, extra: old.extra));
    }

    final joiner = g.match == 'any' ? 'or' : g.match == 'none' ? 'nor' : 'and';
    Widget joinerText(String s) => Text(s.toUpperCase(), style: context.uiText.label.copyWith(fontSize: 11, color: t.textMuted, letterSpacing: 0.5));

    final rows = <Widget>[];
    if (g.conditions.length > 1 || nested) {
      rows.add(Row(spacing: t.space2, children: [
        Expanded(
          child: UiSelect(
            label: 'How to combine these rules',
            size: UiSize.sm,
            value: g.match,
            options: const [UiSelectOption(value: 'all', label: 'All of these'), UiSelectOption(value: 'any', label: 'Any of these'), UiSelectOption(value: 'none', label: 'None of these')],
            onChanged: (m) => write(list(), m),
          ),
        ),
        if (nested) FbIconButton(icon: HugeIcons.strokeRoundedCancel01, label: 'Remove this group', danger: true, onPressed: onRemoved),
      ]));
    }
    for (var i = 0; i < g.conditions.length; i++) {
      final c = g.conditions[i];
      if (c is UiFbConditionGroup) {
        rows.add(UiFbConditionEditor(condition: c, forId: forId, nested: true, onChanged: (n) => replace(i, n), onRemoved: () => remove(i)));
        continue;
      }
      final rule = c as UiFbConditionRule;
      final subj = subjectOf(rule.ref);
      final info = operatorInfo(rule.op);
      rows.add(Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: [
        if (i > 0) joinerText(joiner),
        Row(spacing: 4, children: [
          Expanded(
            child: UiSelect(
              label: 'Question',
              size: UiSize.sm,
              placeholder: 'Choose a question…',
              invalid: rule.ref.isEmpty,
              value: rule.ref.isEmpty ? null : rule.ref,
              options: [
                for (final o in options)
                  UiSelectOption(
                    value: o.id,
                    label: o.label +
                        (o.kind == UiFbSubjectKind.group || o.kind == UiFbSubjectKind.repeat ? ' (section)' : o.kind == UiFbSubjectKind.page ? ' (page)' : ''),
                  ),
                if (rule.ref.isNotEmpty && subj == null) UiSelectOption(value: rule.ref, label: 'Deleted question'),
              ],
              onChanged: (v) => setRef(i, v),
            ),
          ),
          FbIconButton(icon: HugeIcons.strokeRoundedCancel01, label: 'Remove this rule', danger: true, onPressed: () => remove(i)),
        ]),
        if (subj != null) ...[
          UiSelect(
            label: 'Comparison',
            size: UiSize.sm,
            value: rule.op.name,
            options: [for (final op in opsFor(subj.kind)) UiSelectOption(value: op.op.name, label: _opLabel(op))],
            onChanged: (v) => setOp(i, UiFbOperator(v)),
          ),
          if (info.arity >= 1) UiFbValueInput(subject: subj, op: rule.op, operand: rule.value, forId: forId, onChanged: (v) => setValue(i, false, v)),
          if (info.arity == 2) ...[
            joinerText('and'),
            UiFbValueInput(subject: subj, op: rule.op, operand: rule.value2, forId: forId, label: 'Second value', onChanged: (v) => setValue(i, true, v)),
          ],
        ],
      ]));
    }
    rows.add(Wrap(spacing: t.space3, runSpacing: 4, children: [
      FbLink(label: 'Add rule', icon: HugeIcons.strokeRoundedAdd01, onTap: addRule),
      if (!nested && g.conditions.isNotEmpty) FbLink(label: 'Add a group of rules', icon: HugeIcons.strokeRoundedAdd01, onTap: addGroup),
    ]));
    if (options.isEmpty) rows.add(const FbHint('Add other questions to the form first. Rules compare with other answers.'));

    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: rows);
    if (!nested) return body;
    return Container(
      padding: EdgeInsets.all(t.space2),
      decoration: BoxDecoration(
        color: t.surfaceHover.withValues(alpha: t.surfaceHover.a * 0.5),
        border: Border.all(color: t.borderSubtle),
        borderRadius: BorderRadius.circular(t.radius),
      ),
      child: body,
    );
  }
}
