import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../button/button.dart';
import '../../button/segmented.dart';
import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../datepicker/date_picker.dart';
import '../../forms/choice/switch.dart';
import '../../forms/text/inputs.dart';
import '../../forms/text/number_input.dart';
import '../../forms/text/select.dart';
import '../../overlay/menu.dart';
import '../../theme/theme.dart';
import '../engine/calc.dart';
import '../engine/definition.dart';
import '../engine/engine.dart' show requiredMessage;
import '../engine/field_types.dart';
import '../engine/js.dart';
import '../engine/option_sources.dart';
import '../engine/schema.dart';
import '../engine/validators.dart';
import 'builder_bits.dart';
import 'builder_condition.dart';
import 'builder_source.dart';
import 'builder_store.dart';

/// Sets one prop of a field (removing it when [value] is null), keeping the stored JSON small.
void fbSetProp(UiFbField f, String key, Object? value) {
  final j = f.props?.toJson() ?? <String, Object?>{};
  if (value == null) {
    j.remove(key);
  } else {
    j[key] = value;
  }
  f.props = j.isEmpty ? null : UiFbFieldProps.fromJson(j);
}

// ── Options ──────────────────────────────────────────────────────────────────────────────────

/// `ui-fb-options`: the choices of a dropdown, radio or checkbox field. Stored values follow the
/// labels until the form has answers; after that they're locked (old answers point at them) and
/// removing an option archives it.
class UiFbOptionsEditor extends StatefulWidget {
  const UiFbOptionsEditor({super.key, required this.field});
  final UiFbField field;

  @override
  State<UiFbOptionsEditor> createState() => _UiFbOptionsEditorState();
}

class _UiFbOptionsEditorState extends State<UiFbOptionsEditor> {
  bool _showValues = false;
  bool _pasting = false;
  String _pasted = '';

  UiFbField get f => widget.field;

  Set<String> _published(UiFormBuilderController store) {
    final pub = store.live ? store.published : null;
    final pf = pub == null ? null : indexDefinition(pub)[f.id]?.asField;
    return {for (final o in pf?.options ?? const <UiFbOption>[]) o.value};
  }

  void _write(UiFormBuilderController store, List<UiFbOption> options, {String? mergeKey}) =>
      store.updateField(f.id, (x) => x.options = options, mergeKey: mergeKey);

  List<UiFbOption> _copy() => [for (final o in f.options ?? const <UiFbOption>[]) UiFbOption.fromJson(o.toJson())];

  String _unique(String base, {String? exceptId}) {
    final taken = {for (final o in f.options ?? const <UiFbOption>[]) if (o.id != exceptId) o.value};
    final b = base.isEmpty ? 'option' : base;
    var v = b;
    var n = 2;
    while (taken.contains(v)) {
      v = '${b}_${n++}';
    }
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = UiFbBuilderScope.of(context);
    final locked = _published(store);
    final canSource = uiFbSourceFieldTypes.contains(f.type) && (store.optionSourceDefs.isNotEmpty || f.source != null);
    final pub = store.live ? indexDefinition(store.published!)[f.id]?.asField : null;
    final switchedToSource = f.source != null && pub != null && pub.source == null;

    void setFrom(String mode) {
      if (mode == 'source' && f.source == null) {
        store.updateField(f.id, (x) => x.source = UiFbOptionSourceRef(type: store.optionSourceDefs.firstOrNull?.type ?? '', params: {}));
      }
      // The typed options are kept while a source is on, so switching back restores them.
      if (mode == 'list' && f.source != null) store.updateField(f.id, (x) => x.source = null);
    }

    void setLabel(UiFbOption o, String label) {
      // The saved value follows the label until it's locked or was set by hand.
      final follows = !locked.contains(o.value) &&
          (o.value == fbSlug(o.label) || RegExp(r'^option_?\d*$').hasMatch(o.value) || o.value.startsWith('${fbSlug(o.label)}_'));
      final value = follows ? _unique(fbSlug(label), exceptId: o.id) : o.value;
      _write(store, [for (final x in _copy()) x.id == o.id ? (x..label = label..value = value) : x], mergeKey: 'opt:${o.id}');
    }

    void setValue(UiFbOption o, String raw) {
      final value = _unique(raw.trim().isEmpty ? fbSlug(o.label) : raw.trim(), exceptId: o.id);
      _write(store, [for (final x in _copy()) x.id == o.id ? (x..value = value) : x], mergeKey: 'optv:${o.id}');
    }

    void addAt(int at) {
      final list = _copy();
      final label = 'Option ${list.length + 1}';
      list.insert(at, UiFbOption(id: fbUid('opt'), label: label, value: _unique(fbSlug(label))));
      _write(store, list);
    }

    void remove(UiFbOption o) {
      if (locked.contains(o.value)) {
        _write(store, [for (final x in _copy()) x.id == o.id ? (x..archived = true) : x]);
      } else {
        _write(store, _copy()..removeWhere((x) => x.id == o.id));
      }
    }

    void restore(UiFbOption o) => _write(store, [for (final x in _copy()) x.id == o.id ? (x..archived = null) : x]);

    void move(int i, int d) {
      final list = _copy();
      final o = list.removeAt(i);
      list.insert(i + d, o);
      _write(store, list);
    }

    void applyPaste() {
      final existing = {for (final o in f.options ?? const <UiFbOption>[]) o.label.trim().toLowerCase()};
      final list = _copy();
      for (final line in _pasted.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty)) {
        if (!existing.add(line.toLowerCase())) continue;
        final base = fbSlug(line);
        final taken = {for (final o in list) o.value};
        var v = base;
        var n = 2;
        while (taken.contains(v)) {
          v = '${base}_${n++}';
        }
        list.add(UiFbOption(id: fbUid('opt'), label: line, value: v));
      }
      _write(store, list);
      setState(() {
        _pasted = '';
        _pasting = false;
      });
    }

    final opts = f.options ?? const <UiFbOption>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
      if (canSource) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: UiSegmented<String>(
            label: 'Where the options come from',
            size: UiSize.sm,
            value: f.source != null ? 'source' : 'list',
            options: const [UiSegmentedOption(value: 'list', label: 'Typed list'), UiSegmentedOption(value: 'source', label: 'Data source')],
            onChanged: setFrom,
          ),
        ),
        if (switchedToSource)
          const FbWarn(text: 'People have answered this with the typed options. Those answers keep their saved values, shown as the value itself.'),
      ],
      if (f.source != null)
        UiFbSourceSettings(field: f)
      else ...[
        for (var i = 0; i < opts.length; i++)
          _OptionRow(
            key: ValueKey(opts[i].id),
            option: opts[i],
            index: i,
            last: i == opts.length - 1,
            locked: locked.contains(opts[i].value),
            showValue: _showValues,
            onLabel: (l) => setLabel(opts[i], l),
            onValue: (v) => setValue(opts[i], v),
            onEnter: () => addAt(i + 1),
            onMove: (d) => move(i, d),
            onRemove: () => remove(opts[i]),
            onRestore: () => restore(opts[i]),
          ),
        Wrap(spacing: t.space3, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          FbLink(label: 'Add option', icon: HugeIcons.strokeRoundedAdd01, onTap: () => addAt(opts.length)),
          FbLink(label: _pasting ? 'Close the list box' : 'Paste a list', onTap: () => setState(() => _pasting = !_pasting)),
          UiSwitch(value: _showValues, label: 'Show saved values', onChanged: (v) => setState(() => _showValues = v)),
        ]),
        if (_pasting)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            UiTextarea(value: _pasted, rows: 4, placeholder: 'One option per line', semanticLabel: 'Options, one per line', onChanged: (v) => _pasted = v),
            Row(spacing: t.space2, children: [
              UiButton(label: 'Add these', size: UiSize.sm, onPressed: applyPaste),
              UiButton(label: 'Cancel', size: UiSize.sm, variant: UiButtonVariant.ghost, onPressed: () => setState(() => _pasting = false)),
            ]),
          ]),
      ],
    ]);
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.option,
    required this.index,
    required this.last,
    required this.locked,
    required this.showValue,
    required this.onLabel,
    required this.onValue,
    required this.onEnter,
    required this.onMove,
    required this.onRemove,
    required this.onRestore,
  });

  final UiFbOption option;
  final int index;
  final bool last;
  final bool locked;
  final bool showValue;
  final ValueChanged<String> onLabel;
  final ValueChanged<String> onValue;
  final VoidCallback onEnter;
  final ValueChanged<int> onMove;
  final VoidCallback onRemove;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final o = option;
    final archived = o.archived == true;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
      FbIconButton(icon: HugeIcons.strokeRoundedArrowUp01, label: 'Move ${o.label} up', onPressed: index == 0 ? null : () => onMove(-1)),
      FbIconButton(icon: HugeIcons.strokeRoundedArrowDown01, label: 'Move ${o.label} down', onPressed: last ? null : () => onMove(1)),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 3, children: [
          Opacity(
            opacity: archived ? 0.55 : 1,
            child: UiInput(
              size: UiSize.sm,
              value: o.label,
              placeholder: 'Option label',
              semanticLabel: 'Option ${index + 1}',
              textInputAction: TextInputAction.next,
              onChanged: onLabel,
              onSubmitted: (_) => onEnter(),
            ),
          ),
          if (showValue)
            Row(spacing: 6, children: [
              Text('Saved as', style: context.uiText.body.copyWith(fontSize: 11, color: t.textMuted)),
              Expanded(
                child: UiInput(
                  size: UiSize.sm,
                  value: o.value,
                  enabled: !locked,
                  semanticLabel: 'Saved value of ${o.label}',
                  onSubmitted: onValue,
                  onChanged: onValue,
                ),
              ),
              if (locked) Text('locked', style: context.uiText.body.copyWith(fontSize: 11, color: t.warning)),
            ]),
          if (archived)
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
              Text('Archived: hidden from new answers, kept in old ones.', style: context.uiText.body.copyWith(fontSize: 11, color: t.textMuted)),
              FbLink(label: 'Restore', fontSize: 12, onTap: onRestore),
            ]),
        ]),
      ),
      if (!archived) FbIconButton(icon: HugeIcons.strokeRoundedCancel01, label: locked ? 'Archive ${o.label} (answers use it)' : 'Remove ${o.label}', danger: true, onPressed: onRemove),
    ]);
  }
}

// ── Checks (required + validators) ───────────────────────────────────────────────────────────

/// `ui-fb-checks`: whether an answer is needed, and the checks it must pass, each with its own
/// message (shown under the field by default).
class UiFbChecksEditor extends StatelessWidget {
  const UiFbChecksEditor({super.key, required this.field});
  final UiFbField field;

  static const _repeatable = {'pattern', 'compareField', 'equalsField'};

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = UiFbBuilderScope.of(context);
    final f = field;
    final r = f.required;
    final requiredMode = r == null ? 'no' : (r.flag == true ? 'yes' : (r.isConditional ? 'when' : 'no'));
    final requiredWhen = r != null && r.isConditional ? r.when : null;
    final label = f.label.isNotEmpty ? f.label : 'This field';
    final defaultRequired = formatMessage(requiredMessage(f, label), {'label': label});
    UiFbValidatorDef? defOf(String type) => store.validatorDefs.where((d) => d.type == type).firstOrNull;
    final implicitType = uiFbImplicitValidator[f.type];
    final implicitDef = implicitType == null ? null : defOf(implicitType);
    final have = {for (final v in f.validators ?? const <UiFbValidatorRule>[]) v.type};
    final addable = [
      for (final d in store.validatorsForField(f))
        if ((_repeatable.contains(d.type) || !have.contains(d.type)) && d.type != implicitType) d,
    ];

    void setRequiredMode(String mode) {
      store.updateField(f.id, (x) {
        if (mode == 'yes') {
          x.required = UiFbToggle.fromJson(true);
        } else if (mode == 'when') {
          x.required = UiFbToggle.fromJson({'when': (requiredWhen ?? fbEmptyCondition()).toJson()});
        } else {
          x.required = null;
          x.requiredMessage = null;
        }
      });
    }

    List<UiFbValidatorRule> rules() => [for (final v in f.validators ?? const <UiFbValidatorRule>[]) UiFbValidatorRule.fromJson(v.toJson())];
    void writeRules(List<UiFbValidatorRule> list, {String? mergeKey}) =>
        store.updateField(f.id, (x) => x.validators = list.isEmpty ? null : list, mergeKey: mergeKey);

    void add(UiFbValidatorDef d) {
      final params = {for (final p in d.params ?? const <UiFbParamSpec>[]) if (p.hasDefault) p.key: p.defaultValue};
      writeRules([...rules(), UiFbValidatorRule(id: fbUid('val'), type: d.type, params: params.isEmpty ? null : params)]);
    }

    void patch(UiFbValidatorRule rule, void Function(UiFbValidatorRule r) edit, {String? merge}) =>
        writeRules([for (final x in rules()) x.id == rule.id ? (x..let(edit)) : x], mergeKey: merge == null ? null : '$merge:${rule.id}');

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
      if (f.type != UiFbFieldType.calculated && f.type != UiFbFieldType.hidden)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
          const FbLabel('Answer needed?'),
          Align(
            alignment: Alignment.centerLeft,
            child: UiSegmented<String>(
              label: 'Answer needed',
              size: UiSize.sm,
              value: requiredMode,
              options: const [
                UiSegmentedOption(value: 'no', label: 'Optional'),
                UiSegmentedOption(value: 'yes', label: 'Required'),
                UiSegmentedOption(value: 'when', label: 'Required when…'),
              ],
              onChanged: setRequiredMode,
            ),
          ),
          if (requiredMode == 'when')
            UiFbConditionEditor(
              condition: requiredWhen,
              forId: f.id,
              onChanged: (c) => store.updateField(f.id, (x) => x.required = UiFbToggle.fromJson({'when': c.toJson()}), mergeKey: 'req:${f.id}'),
            ),
          if (requiredMode != 'no')
            FbSetting(
              label: 'Message when it’s left empty',
              child: UiInput(
                size: UiSize.sm,
                value: f.requiredMessage ?? '',
                placeholder: defaultRequired,
                semanticLabel: 'Message when it’s left empty',
                onChanged: (v) => store.updateField(f.id, (x) => x.requiredMessage = v.isEmpty ? null : v, mergeKey: 'reqmsg:${f.id}'),
              ),
            ),
        ]),
      if (implicitDef != null)
        FbBox(children: [
          Row(spacing: 6, children: [
            Flexible(child: Text(implicitDef.label, style: context.uiText.label.copyWith(fontSize: 13))),
            const FbChip('Automatic', tone: FbTone.ok),
          ]),
          FbHint('${implicitDef.description ?? implicitDef.label}. Every ${f.type == UiFbFieldType.email ? 'email' : f.type == UiFbFieldType.url ? 'website' : 'phone'} field checks this.'),
          if (!have.contains(implicitDef.type)) Align(alignment: Alignment.centerLeft, child: FbLink(label: 'Change its message', onTap: () => add(implicitDef))),
        ]),
      for (final rule in f.validators ?? const <UiFbValidatorRule>[])
        _CheckBox(
          key: ValueKey(rule.id),
          field: f,
          rule: rule,
          def: defOf(rule.type),
          onRemove: () => writeRules(rules()..removeWhere((x) => x.id == rule.id)),
          onPatch: (edit, {merge}) => patch(rule, edit, merge: merge),
        ),
      if (addable.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: UiMenu(
            items: [for (final d in addable) UiMenuItem(label: d.label, value: d.type)],
            onSelect: (item) {
              final d = defOf(item.value);
              if (d != null) add(d);
            },
            builder: (context, toggle, open) => _DashedButton(label: 'Add a check', onTap: toggle),
          ),
        )
      else if (f.type == UiFbFieldType.hidden)
        const FbHint('Hidden values aren’t checked: people never see them.'),
    ]);
  }
}

extension _Let<T> on T {
  void let(void Function(T it) fn) => fn(this);
}

class _DashedButton extends StatelessWidget {
  const _DashedButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      semanticLabel: label,
      excludeChildSemantics: true,
      builder: (context, s) => Container(
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: t.space3),
        decoration: BoxDecoration(
          border: Border.all(color: s.hovered ? t.borderStrong : t.border),
          borderRadius: BorderRadius.circular(t.radius),
          boxShadow: s.focused ? t.focusRing : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
          UiIcon(HugeIcons.strokeRoundedAdd01, size: 14, color: s.hovered ? t.text : t.textSecondary),
          Text(label, style: context.uiText.body.copyWith(fontSize: 13, color: s.hovered ? t.text : t.textSecondary)),
        ]),
      ),
    );
  }
}

typedef _RulePatch = void Function(void Function(UiFbValidatorRule r) edit, {String? merge});

/// One added check: its settings, message, "only sometimes" and "warn" switches.
class _CheckBox extends StatelessWidget {
  const _CheckBox({super.key, required this.field, required this.rule, required this.def, required this.onRemove, required this.onPatch});
  final UiFbField field;
  final UiFbValidatorRule rule;
  final UiFbValidatorDef? def;
  final VoidCallback onRemove;
  final _RulePatch onPatch;

  Object? _raw(UiFbParamSpec p) => rule.params != null && rule.params!.containsKey(p.key) ? rule.params![p.key] : (p.hasDefault ? p.defaultValue : null);
  String _param(UiFbParamSpec p) {
    final v = _raw(p);
    return v == null ? '' : jsString(v);
  }

  void _setParam(String key, Object? value) => onPatch((r) => r.params = {...?r.params, key: value}, merge: 'p:$key');

  @override
  Widget build(BuildContext context) {
    final store = UiFbBuilderScope.of(context);
    final d = def;
    final label = d?.label ?? rule.type;

    String preview() {
      final vars = <String, Object?>{'label': field.label.isNotEmpty ? field.label : 'This field'};
      for (final p in d!.params ?? const <UiFbParamSpec>[]) {
        final v = _raw(p);
        vars[p.key] = p.kind == 'field' ? '“${store.name(v == null ? '' : jsString(v))}”' : p.kind == 'date' ? describeDateParam(v) : p.key == 'comparison' ? comparisonWords(v) : v;
      }
      return formatMessage(d.defaultMessage, vars);
    }

    Widget paramInput(UiFbParamSpec p) {
      switch (p.kind) {
        case 'number':
          final v = _raw(p);
          final n = v is num ? v : (v is String && v.isNotEmpty && jsNumber(v).isFinite ? jsNumber(v) : null);
          return UiNumberInput(size: UiSize.sm, value: n, placeholder: p.placeholder ?? '', semanticLabel: p.label, onChanged: (x) => _setParam(p.key, x));
        case 'select':
          return UiSelect(
            label: p.label,
            size: UiSize.sm,
            value: _param(p).isEmpty ? null : _param(p),
            options: [for (final o in p.options ?? const <({String value, String label})>[]) UiSelectOption(value: o.value, label: o.label)],
            onChanged: (x) => _setParam(p.key, x),
          );
        case 'field':
          final kinds = p.fieldKinds ?? [valueKindOf(field.type, field.props?.format)];
          final choices = [for (final o in store.refOptions(field.id)) if (kinds.any((k) => k.subject == o.kind)) o];
          return UiSelect(
            label: p.label,
            size: UiSize.sm,
            placeholder: 'Choose a question…',
            value: _param(p).isEmpty ? null : _param(p),
            options: [for (final o in choices) UiSelectOption(value: o.id, label: o.label)],
            onChanged: (x) => _setParam(p.key, x),
          );
        case 'date':
          final v = _param(p);
          final mode = v.isEmpty || RegExp(r'^today$', caseSensitive: false).hasMatch(v.trim())
              ? 'today'
              : RegExp(r'^today', caseSensitive: false).hasMatch(v)
              ? 'offset'
              : 'date';
          final m = RegExp(r'^today\s*([+-]\s*\d+)', caseSensitive: false).firstMatch(v);
          final offset = m != null ? int.parse(m.group(1)!.replaceAll(RegExp(r'\s'), '')) : 0;
          return FbPair(children: [
            UiSelect(
              label: '${p.label}: kind of date',
              size: UiSize.sm,
              value: mode,
              options: const [UiSelectOption(value: 'today', label: 'Today'), UiSelectOption(value: 'offset', label: 'Days from today'), UiSelectOption(value: 'date', label: 'A set date')],
              onChanged: (x) => _setParam(p.key, x == 'today' ? 'today' : x == 'offset' ? 'today+7' : ''),
            ),
            if (mode == 'offset')
              UiNumberInput(
                size: UiSize.sm,
                value: offset,
                semanticLabel: 'Days from today',
                onChanged: (x) => _setParam(p.key, 'today${(x ?? 0) >= 0 ? '+' : ''}${jsNumberToString(x ?? 0)}'),
              ),
            if (mode == 'date')
              UiDatePicker(size: UiSize.sm, label: '${p.label}: date', value: RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v) ? v : null, onChanged: (x) => _setParam(p.key, x)),
          ]);
        default:
          return UiInput(size: UiSize.sm, value: _param(p), placeholder: p.placeholder ?? '', semanticLabel: p.label, onChanged: (x) => _setParam(p.key, x));
      }
    }

    return FbBox(dashed: d == null, children: [
      Row(spacing: 6, children: [
        Flexible(child: Text(label, style: context.uiText.label.copyWith(fontSize: 13))),
        if (rule.severity == 'warning') const FbChip('Warning', tone: FbTone.warn),
        const Spacer(),
        FbIconButton(icon: HugeIcons.strokeRoundedCancel01, label: 'Remove $label', danger: true, onPressed: onRemove),
      ]),
      if (d == null)
        const FbHint('This check is provided by the app, which hasn’t registered it here. It is kept, but can’t be edited.')
      else ...[
        if (d.description != null && d.description!.isNotEmpty) FbHint(d.description!),
        for (final p in d.params ?? const <UiFbParamSpec>[])
          if (!(p.key == 'regex' && rule.params?['preset'] != 'custom')) FbSetting(label: p.label, hint: p.hint, child: paramInput(p)),
        FbSetting(
          label: 'Message',
          child: UiInput(
            size: UiSize.sm,
            value: rule.message ?? '',
            placeholder: preview(),
            semanticLabel: 'Message',
            onChanged: (v) => onPatch((r) => r.message = v.isEmpty ? null : v, merge: 'msg'),
          ),
        ),
        UiSwitch(
          value: rule.when != null,
          label: 'Only check sometimes',
          onChanged: (on) => onPatch((r) => r.when = on ? fbEmptyCondition() : null),
        ),
        UiSwitch(
          value: rule.severity == 'warning',
          label: 'Warn but allow submitting',
          onChanged: (on) => onPatch((r) => r.severity = on ? 'warning' : null),
        ),
        if (rule.when != null)
          FbSetting(
            label: 'Check only when',
            child: UiFbConditionEditor(condition: rule.when, forId: field.id, onChanged: (c) => onPatch((r) => r.when = c, merge: 'when')),
          ),
      ],
    ]);
  }
}

// ── Calculations ─────────────────────────────────────────────────────────────────────────────

/// `ui-fb-calc`: how a calculated field works its value out: an operation and its inputs (other
/// answers or fixed numbers).
class UiFbCalcEditor extends StatelessWidget {
  const UiFbCalcEditor({super.key, required this.field});
  final UiFbField field;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = UiFbBuilderScope.of(context);
    final me = field;
    final c = me.calc ?? UiFbCalc(op: UiFbCalcOp.sum, args: []);
    final info = calcOpInfo(c.op);

    // Answers a calculation can use. Fields inside a repeating section are allowed from outside it:
    // they combine every entry (e.g. a total).
    final myRepeat = store.index[me.id]?.repeat;
    final choices = <({String id, String label})>[];
    for (final e in store.index.values) {
      if (e.id == me.id || e.kind == 'page' || e.kind == 'static') continue;
      if (e.repeat != null && myRepeat != null && e.repeat!.id != myRepeat.id) continue;
      if (e.kind == 'group') {
        final g = e.asGroup!;
        if (g.repeat != null && c.op == UiFbCalcOp.count) choices.add((id: g.id, label: '${(g.title ?? '').isNotEmpty ? g.title : 'Repeating section'} (entries)'));
        continue;
      }
      final f = e.asField!;
      if (f.archived == true) continue;
      final kind = valueKindOf(f.type, f.props?.format);
      final ok = c.op == UiFbCalcOp.count
          ? true
          : info.dates
          ? kind == UiFbValueKind.date
          : info.text
          ? true
          : kind == UiFbValueKind.number || kind == UiFbValueKind.boolean;
      if (!ok) continue;
      choices.add((id: f.id, label: (f.label.isNotEmpty ? f.label : f.key) + (e.repeat != null && myRepeat == null ? ' (each entry)' : '')));
    }

    UiFbCalc copy() => UiFbCalc.fromJson(c.toJson());
    void write(UiFbCalc next) => store.updateField(me.id, (x) => x.calc = next, mergeKey: 'calc:${me.id}');

    void setOp(UiFbCalcOp op) {
      final oi = calcOpInfo(op);
      store.updateField(me.id, (x) {
        final next = copy()..op = op;
        if (oi.arity != null && next.args.length > oi.arity!) next.args = next.args.sublist(0, oi.arity);
        x.calc = next;
        final format = oi.text ? 'text' : (x.props?.format == 'text' ? 'number' : (x.props?.format ?? 'number'));
        fbSetProp(x, 'format', format);
      });
    }

    void setArgSource(int i, String v) {
      final next = copy();
      next.args[i] = v == '__const' ? UiFbCalcConstArg(info.text ? '' : 0) : UiFbCalcRefArg(v);
      write(next);
    }

    void setConst(int i, Object? v) {
      final next = copy();
      next.args[i] = UiFbCalcConstArg(v ?? (info.text ? '' : 0));
      write(next);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
      FbSetting(
        label: 'Work out',
        child: UiSelect(
          label: 'Work out',
          size: UiSize.sm,
          value: c.op.name,
          options: [for (final o in uiFbCalcOps) UiSelectOption(value: o.op.name, label: o.label)],
          onChanged: (v) => setOp(UiFbCalcOp(v)),
        ),
      ),
      FbHint(info.hint),
      const FbLabel('Using'),
      for (var i = 0; i < c.args.length; i++)
        Row(spacing: 4, children: [
          Expanded(
            child: UiSelect(
              label: 'Input ${i + 1}',
              size: UiSize.sm,
              value: switch (c.args[i]) {
                UiFbCalcRefArg(:final ref) => ref,
                _ => '__const',
              },
              options: [
                UiSelectOption(value: '__const', label: info.text ? 'Fixed text' : 'A fixed number'),
                for (final o in choices) UiSelectOption(value: o.id, label: o.label),
              ],
              onChanged: (v) => setArgSource(i, v),
            ),
          ),
          if (c.args[i] is UiFbCalcConstArg)
            SizedBox(
              width: 120,
              child: info.text
                  ? UiInput(size: UiSize.sm, value: jsString((c.args[i] as UiFbCalcConstArg).value ?? ''), placeholder: 'Text', semanticLabel: 'Text', onChanged: (v) => setConst(i, v))
                  : UiNumberInput(
                      size: UiSize.sm,
                      value: (c.args[i] as UiFbCalcConstArg).value is num ? (c.args[i] as UiFbCalcConstArg).value as num : null,
                      semanticLabel: 'Number',
                      onChanged: (v) => setConst(i, v),
                    ),
            ),
          FbIconButton(icon: HugeIcons.strokeRoundedCancel01, label: 'Remove input', danger: true, onPressed: () => write(copy()..args.removeAt(i))),
        ]),
      if (info.arity == null || c.args.length < info.arity!)
        Align(
          alignment: Alignment.centerLeft,
          child: FbLink(
            label: 'Add an input',
            icon: HugeIcons.strokeRoundedAdd01,
            onTap: () {
              final first = choices.firstOrNull;
              write(copy()..args.add(first != null ? UiFbCalcRefArg(first.id) : UiFbCalcConstArg(0)));
            },
          ),
        ),
      if (!info.text && !info.dates && c.op != UiFbCalcOp.count)
        FbSetting(
          label: 'Round to',
          child: UiSelect(
            label: 'Round to',
            size: UiSize.sm,
            value: c.decimals == null ? '' : jsNumberToString(c.decimals!),
            options: [
              const UiSelectOption(value: '', label: 'Don’t round'),
              for (final d in const [0, 1, 2, 3, 4]) UiSelectOption(value: '$d', label: d == 0 ? 'Whole number' : '$d decimal place${d > 1 ? 's' : ''}'),
            ],
            onChanged: (v) => write(copy()..decimals = v.isEmpty ? null : int.parse(v)),
          ),
        ),
      FbSentence('= ${store.describeCalcOf(me)}', tinted: false),
    ]);
  }
}
