import 'dart:ui' show SemanticsRole;

import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../button/button.dart';
import '../../button/segmented.dart';
import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../forms/choice/switch.dart';
import '../../forms/text/inputs.dart';
import '../../forms/text/number_input.dart';
import '../../forms/text/select.dart';
import '../../theme/theme.dart';
import '../engine/definition.dart';
import '../engine/field_types.dart';
import '../engine/option_sources.dart';
import '../engine/schema.dart';
import 'builder_bits.dart';
import 'builder_condition.dart';
import 'builder_editors.dart';
import 'builder_store.dart';
import 'settings_fields.dart';

const Map<String, String> _refWords = {
  'visibility': 'when it shows',
  'required': 'when it’s required',
  'disabled': 'when it’s read-only',
  'setValue': 'to fill itself in',
  'validator': 'in a check',
  'calc': 'in its calculation',
  'jump': 'in a page jump',
  'source': 'to narrow its list',
};

const List<(String, String)> _autocomplete = [
  ('', 'Let the browser decide'),
  ('off', 'Off'),
  ('name', 'Full name'),
  ('given-name', 'First name'),
  ('family-name', 'Last name'),
  ('email', 'Email'),
  ('tel', 'Phone'),
  ('street-address', 'Street address'),
  ('address-level2', 'Town or city'),
  ('postal-code', 'Postcode'),
  ('country-name', 'Country'),
  ('organization', 'Organisation'),
  ('bday', 'Date of birth'),
];

const _widths = [
  UiSegmentedOption(value: 'full', label: 'Full'),
  UiSegmentedOption(value: 'two-thirds', label: '2/3'),
  UiSegmentedOption(value: 'half', label: '1/2'),
  UiSegmentedOption(value: 'third', label: '1/3'),
];

enum _Tab { settings, logic, checks }

/// `ui-fb-inspector`: settings for whatever is selected: a field, section, text block, page, or
/// (with nothing selected) the form itself. Fields have Settings, Logic and Checks tabs; sections,
/// text and pages Settings and Logic.
///
/// It scrolls itself; give [scrollController] when it sits in a [UiBottomSheet] so dragging the
/// content also moves the sheet.
class UiFbInspector extends StatefulWidget {
  const UiFbInspector({super.key, this.showHead = true, this.onDeleteRequest, this.scrollController});

  /// Hide the header when something around it already names the selection (the phone sheet).
  final bool showHead;

  /// Delete was pressed for an element or page (the builder asks first when answers or rules
  /// would be lost).
  final ValueChanged<String>? onDeleteRequest;
  final ScrollController? scrollController;

  @override
  State<UiFbInspector> createState() => _UiFbInspectorState();
}

class _UiFbInspectorState extends State<UiFbInspector> {
  _Tab _tab = _Tab.settings;

  int _logicCount(Object el) {
    if (el is UiFbPage) return (el.visibility != null ? 1 : 0) + (el.jumps?.length ?? 0);
    final e = el as UiFbElement;
    var n = e.visibility != null ? 1 : 0;
    if (e is UiFbField) n += (e.disabled != null ? 1 : 0) + (e.setValue?.length ?? 0);
    if (e is UiFbGroup && e.disabled != null) n++;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = UiFbBuilderScope.of(context);
    final sel = store.selected;

    final tabs = <(_Tab, String, int)>[];
    if (sel != null) {
      tabs.add((_Tab.settings, 'Settings', 0));
      tabs.add((_Tab.logic, 'Logic', _logicCount(sel.element)));
      final f = sel.asField;
      if (f != null) tabs.add((_Tab.checks, 'Checks', (f.validators?.length ?? 0) + (f.required != null ? 1 : 0)));
    }
    // A tab that doesn't exist for the new selection falls back to Settings.
    final tab = tabs.any((x) => x.$1 == _tab) ? _tab : _Tab.settings;

    Widget body;
    if (sel == null) {
      body = _FormSettings(store: store);
    } else {
      final el = sel.element;
      body = switch (el) {
        UiFbField() => _FieldPanel(field: el, tab: tab, onDelete: widget.onDeleteRequest),
        UiFbGroup() => _GroupPanel(group: el, tab: tab, onDelete: widget.onDeleteRequest),
        UiFbStatic() => _StaticPanel(item: el, tab: tab, onDelete: widget.onDeleteRequest),
        _ => _PagePanel(page: el as UiFbPage, tab: tab, onDelete: widget.onDeleteRequest),
      };
    }

    return ColoredBox(
      color: t.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (widget.showHead) _Head(store: store),
        if (tabs.length > 1) _Tabs(tabs: tabs, value: tab, onChanged: (v) => setState(() => _tab = v)),
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: EdgeInsets.fromLTRB(t.space3, t.space3, t.space3, t.space8),
            // A fresh subtree per selection, so local drafts (keys, pasted lists) don't carry over.
            child: KeyedSubtree(key: ValueKey('${sel?.id}:${tab.name}'), child: body),
          ),
        ),
      ]),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.store});
  final UiFormBuilderController store;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final sel = store.selected;
    final el = sel?.element;
    final (UiIconData icon, String kind) = switch (el) {
      null => (HugeIcons.strokeRoundedSettings02, 'Form settings'),
      UiFbPage() => (HugeIcons.strokeRoundedFileEdit, 'Page'),
      UiFbField(:final type) => (fbFieldIcon(type), fieldTypeInfo(type).label),
      UiFbGroup(:final repeat) => (repeat != null ? fbRepeatIcon : fbGroupIcon, repeat != null ? 'Repeating section' : 'Section'),
      UiFbStatic(:final type) => (fbStaticIcon(type), type == 'heading' ? 'Heading' : type == 'paragraph' ? 'Text block' : 'Divider'),
      _ => (HugeIcons.strokeRoundedSettings02, ''),
    };
    final name = sel != null ? store.name(sel.id) : (store.def.title.isNotEmpty ? store.def.title : 'Untitled form');
    return Padding(
      padding: EdgeInsets.fromLTRB(t.space3, t.space3, t.space3, t.space2),
      child: Row(spacing: t.space2, children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: t.surfaceHover, borderRadius: BorderRadius.circular(t.radius)),
          child: UiIcon(icon, size: 15, color: t.textSecondary),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(kind, style: context.uiText.label.copyWith(fontSize: 11, color: t.textMuted)),
            Semantics(
              header: true,
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.label.copyWith(fontSize: 14, color: t.text)),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Settings / Logic / Checks, with a count of what each holds.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.tabs, required this.value, required this.onChanged});
  final List<(_Tab, String, int)> tabs;
  final _Tab value;
  final ValueChanged<_Tab> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space3),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.borderSubtle))),
      child: Semantics(
        role: SemanticsRole.tabBar,
        container: true,
        explicitChildNodes: true,
        label: 'Settings sections',
        child: Row(spacing: 2, children: [
          for (final (id, label, count) in tabs)
            UiInteractive(
              onTap: () => onChanged(id),
              button: false,
              selected: id == value,
              pressScale: false,
              minTouchSize: const Size(0, uiMinTouchTarget),
              builder: (context, s) {
                final on = id == value;
                return Semantics(
                  role: SemanticsRole.tab,
                  child: Container(
                    height: 36,
                    padding: EdgeInsets.symmetric(horizontal: t.space2),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: on ? t.primary : const Color(0x00000000), width: 2)),
                      boxShadow: s.focused ? t.focusRing : null,
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, spacing: 5, children: [
                      Text(
                        label,
                        style: context.uiText.body.copyWith(
                          fontSize: 13,
                          fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                          color: on || s.hovered ? t.text : t.textSecondary,
                        ),
                      ),
                      if (count > 0)
                        Container(
                          constraints: const BoxConstraints(minWidth: 16),
                          height: 16,
                          padding: EdgeInsets.symmetric(horizontal: t.space1),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: t.primary.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(t.radiusPill)),
                          child: Text('$count', style: context.uiText.label.copyWith(fontSize: 11, color: t.primary, height: 1)),
                        ),
                    ]),
                  ),
                );
              },
            ),
        ]),
      ),
    );
  }
}

Widget _stack(BuildContext context, List<Widget> children) =>
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: context.ui.space3, children: children);

Widget _segmented<T>(String label, T value, List<UiSegmentedOption<T>> options, ValueChanged<T> onChanged) => Align(
  alignment: Alignment.centerLeft,
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: UiSegmented<T>(label: label, size: UiSize.sm, value: value, options: options, onChanged: onChanged),
  ),
);

class _Actions extends StatelessWidget {
  const _Actions({required this.id, this.onDelete});
  final String id;
  final ValueChanged<String>? onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = UiFbBuilderScope.of(context);
    return Container(
      padding: EdgeInsets.only(top: t.space3),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.borderSubtle))),
      child: Wrap(spacing: t.space2, runSpacing: t.space2, children: [
        UiButton(label: 'Duplicate', size: UiSize.sm, variant: UiButtonVariant.outline, icon: const UiIcon(HugeIcons.strokeRoundedCopy01), onPressed: () => store.duplicate(id)),
        UiButton(label: 'Delete', size: UiSize.sm, variant: UiButtonVariant.outline, icon: const UiIcon(HugeIcons.strokeRoundedDelete02), onPressed: () => onDelete?.call(id)),
      ]),
    );
  }
}

/// The data key box: edited locally, saved on Enter or when it loses focus.
class _KeyBox extends StatefulWidget {
  const _KeyBox({required this.id, required this.current, this.showHint = true});
  final String id;
  final String current;
  String get label => 'Saved as';
  final bool showHint;

  @override
  State<_KeyBox> createState() => _KeyBoxState();
}

class _KeyBoxState extends State<_KeyBox> {
  late final TextEditingController _text = TextEditingController(text: widget.current);
  final FocusNode _focus = FocusNode(debugLabel: 'fb key');
  late UiFormBuilderController _store;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = UiFbBuilderScope.of(context);
  }

  @override
  void didUpdateWidget(_KeyBox old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current && !_focus.hasFocus) _text.text = widget.current;
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _error(String raw) {
    final k = raw.trim();
    if (k.isEmpty) return 'Give it a name.';
    if (!fbKeyValid(k)) return 'Use letters, numbers and _ only, starting with a letter.';
    if (uniqueKey(_store.def, k, widget.id) != k) return 'Another question in the same place is already saved as “$k”.';
    return '';
  }

  void _commit() {
    if (!mounted) return;
    final k = _text.text.trim();
    if (_error(k).isNotEmpty || k == widget.current) {
      if (_error(k).isNotEmpty) setState(() => _text.text = widget.current);
      return;
    }
    // Only remember old names when saved answers might use them.
    if (_store.hasAnswers(widget.id)) {
      _store.rename(widget.id, k);
    } else {
      _store.updateAny(widget.id, (x) {
        if (x is UiFbField) x.key = k;
        if (x is UiFbGroup) x.key = k;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = UiFbBuilderScope.of(context);
    final err = _error(_text.text);
    final draft = _text.text.trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FbLabel(widget.label),
      UiInput(
        controller: _text,
        focusNode: _focus,
        size: UiSize.sm,
        invalid: err.isNotEmpty,
        semanticLabel: widget.label,
        keyboardType: TextInputType.visiblePassword,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _commit(),
      ),
      if (widget.showHint || err.isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 4), child: FbHint(err.isNotEmpty ? err : 'The name this answer has in the saved JSON.', bad: err.isNotEmpty)),
      if (store.hasAnswers(widget.id) && draft != widget.current)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: FbWarn(text: 'Answers already use “${widget.current}”. Old answers still load: the old name is remembered.'),
        ),
    ]);
  }
}

/// Keeps the settings that still mean something after a type change.
Map<String, Object?> _pickProps(UiFbFieldProps? props, UiFbFieldType type) {
  if (props == null) return {};
  final j = props.toJson();
  final keep = ['autocomplete'];
  if (const ['number', 'currency', 'slider'].contains(type.name)) keep.addAll(['min', 'max', 'step', 'decimals']);
  if (const ['radio', 'checkboxes'].contains(type.name)) keep.add('orientation');
  if (const ['checkbox', 'toggle'].contains(type.name)) keep.add('caption');
  return {for (final k in keep) if (j[k] != null) k: j[k]};
}

// ── Field ────────────────────────────────────────────────────────────────────────────────────

class _FieldPanel extends StatelessWidget {
  const _FieldPanel({required this.field, required this.tab, this.onDelete});
  final UiFbField field;
  final _Tab tab;
  final ValueChanged<String>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (tab == _Tab.logic) return _LogicPanel(el: field);
    if (tab == _Tab.checks) return UiFbChecksEditor(field: field);
    final store = UiFbBuilderScope.of(context);
    final f = field;
    final info = fieldTypeInfo(f.type);

    void setLabel(String label) {
      // Keys follow labels until the form has answers or someone named it by hand.
      final slug = fbSlug(f.label);
      final auto = !store.hasAnswers(f.id) && (f.key == slug || f.key.startsWith('${slug}_') || f.key == fbSlug(info.defaultLabel));
      final key = auto && label.trim().isNotEmpty ? uniqueKey(store.def, fbSlug(label), f.id) : f.key;
      store.updateField(f.id, (x) {
        x.label = label;
        x.key = key;
      }, mergeKey: 'label:${f.id}');
    }

    void prop(String key, Object? value) => store.updateField(f.id, (x) => fbSetProp(x, key, value), mergeKey: 'prop:${f.id}:$key');

    void layout(String key, String? value) => store.updateField(f.id, (x) {
      final j = x.layout?.toJson() ?? <String, Object?>{};
      if (value == null) {
        j.remove(key);
      } else {
        j[key] = value;
      }
      x.layout = j.isEmpty ? null : UiFbLayout.fromJson(j);
    });

    void changeType(UiFbFieldType type) {
      final ti = fieldTypeInfo(type);
      final fresh = createField(type);
      store.updateField(f.id, (x) {
        final oldType = x.type;
        x.type = type;
        x.props = UiFbFieldProps.fromJson({...?fresh.props?.toJson(), ..._pickProps(x.props, type)});
        if (ti.hasOptions && (x.options?.isEmpty ?? true)) x.options = fresh.options;
        if (!ti.hasOptions) x.options = null;
        // Radio buttons and tick boxes show every option, so a searchable list doesn't fit them.
        if (!uiFbSourceFieldTypes.contains(type)) x.source = null;
        if (type == UiFbFieldType.calculated && x.calc == null) x.calc = fresh.calc;
        if (type != UiFbFieldType.calculated) x.calc = null;
        if (valueKindOf(type) != valueKindOf(oldType)) {
          x.hasDefaultValue = false;
          x.defaultValue = null;
          x.setValue = null;
        }
        if (!ti.textLike && x.layout != null) {
          final j = x.layout!.toJson()..remove('errorPlacement');
          if (j['labelPlacement'] == 'inside') j.remove('labelPlacement');
          x.layout = UiFbLayout.fromJson(j);
        }
        // Checks that don't fit the new type are dropped.
        final fits = {for (final d in store.validatorsForField(x)) d.type};
        final kept = [
          for (final v in x.validators ?? const <UiFbValidatorRule>[])
            if (fits.contains(v.type) || !store.validatorDefs.any((d) => d.type == v.type)) v,
        ];
        x.validators = kept.isEmpty ? null : kept;
      });
    }

    final answers = store.hasAnswers(f.id);
    final types = answers ? [for (final ti in uiFbFieldTypes) if (typesCompatible(f.type, ti.type) && valueKindOf(ti.type) == valueKindOf(f.type)) ti] : uiFbFieldTypes;
    final multi = valueKindOf(f.type) == UiFbValueKind.multi;
    final self = UiFbRefOption(id: f.id, label: f.label, kind: valueKindOf(f.type, f.props?.format).subject, where: '');
    final p = f.props;

    final children = <Widget>[
      if (f.archived == true)
        FbWarn(
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
            const Text('This question is archived: new answers can’t be given, old ones are kept.'),
            FbLink(label: 'Restore it', fontSize: 12, onTap: () => store.setArchived(f.id, false)),
          ]),
        ),
      FbSetting(
        label: f.type == UiFbFieldType.hidden ? 'Name' : 'Question',
        child: UiInput(value: f.label, size: UiSize.sm, placeholder: 'What do you want to ask?', semanticLabel: f.type == UiFbFieldType.hidden ? 'Name' : 'Question', onChanged: setLabel),
      ),
      if (f.type != UiFbFieldType.hidden)
        FbSetting(
          label: 'Help text',
          child: UiTextarea(
            value: f.help ?? '',
            rows: 2,
            autosize: true,
            maxRows: 6,
            placeholder: 'Optional. Shown under the box.',
            semanticLabel: 'Help text',
            onChanged: (v) => store.updateField(f.id, (x) => x.help = v.isEmpty ? null : v, mergeKey: 'help:${f.id}'),
          ),
        ),
      if (info.placeholder)
        FbSetting(
          label: 'Placeholder',
          child: UiInput(
            value: f.placeholder ?? '',
            size: UiSize.sm,
            placeholder: 'Example text shown in the empty box',
            semanticLabel: 'Placeholder',
            onChanged: (v) => store.updateField(f.id, (x) => x.placeholder = v.isEmpty ? null : v, mergeKey: 'ph:${f.id}'),
          ),
        ),
      FbSetting(
        label: 'Type',
        hint: answers ? 'This question has answers, so it can only change to a similar type.' : null,
        child: UiSelect(
          label: 'Type',
          size: UiSize.sm,
          value: f.type.name,
          options: [for (final ti in types) UiSelectOption(value: ti.type.name, label: ti.label)],
          onChanged: (v) => changeType(UiFbFieldType(v)),
        ),
      ),
      if (info.hasOptions) FbSetting(label: 'Options', child: UiFbOptionsEditor(field: f)),
      ..._typeProps(context, f, prop),
      if (f.type != UiFbFieldType.file && f.type != UiFbFieldType.calculated)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: [
          FbLabel(f.type == UiFbFieldType.hidden ? 'Value' : 'Starts with'),
          UiFbValueInput(
            subject: self,
            op: multi ? UiFbOperator.includesAny : UiFbOperator.eq,
            operand: f.hasDefaultValue ? UiFbConstOperand(f.defaultValue) : null,
            constOnly: true,
            label: f.type == UiFbFieldType.hidden ? 'Value' : 'Starts with',
            onChanged: (o) {
              final v = o is UiFbConstOperand ? o.value : null;
              store.updateField(f.id, (x) {
                final none = v == null || v == '' || (v is List && v.isEmpty && false);
                x.hasDefaultValue = !none;
                x.defaultValue = none ? null : v;
              }, mergeKey: 'def:${f.id}');
            },
          ),
          if (f.defaultValue != null && f.defaultValue != '')
            Align(
              alignment: Alignment.centerLeft,
              child: FbLink(
                label: 'Clear',
                fontSize: 12,
                onTap: () => store.updateField(f.id, (x) {
                  x.hasDefaultValue = false;
                  x.defaultValue = null;
                }),
              ),
            ),
          FbHint(f.type == UiFbFieldType.hidden ? 'Saved with every answer, e.g. a campaign name. Apps can also fill it in.' : 'Already filled in when the form opens. People can change it.'),
        ]),
      if (f.type != UiFbFieldType.hidden)
        FbSection(title: 'Layout', children: [
          FbSetting(label: 'Width', child: _segmented<String>('Width', f.layout?.width ?? 'full', _widths, (v) => layout('width', v == 'full' ? null : v))),
          if (f.type != UiFbFieldType.calculated) ...[
            FbPair(children: [
              FbSetting(
                label: 'Question text',
                child: UiSelect(
                  label: 'Question text',
                  size: UiSize.sm,
                  value: f.layout?.labelPlacement ?? '',
                  options: [
                    const UiSelectOption(value: '', label: 'Form default'),
                    const UiSelectOption(value: 'top', label: 'Above the box'),
                    UiSelectOption(value: 'inside', label: 'Inside the box', disabled: !info.textLike),
                    const UiSelectOption(value: 'left', label: 'To the left'),
                    const UiSelectOption(value: 'hidden', label: 'Hidden'),
                  ],
                  onChanged: (v) => layout('labelPlacement', v.isEmpty ? null : v),
                ),
              ),
              FbSetting(
                label: 'Error message',
                child: UiSelect(
                  label: 'Error message',
                  size: UiSize.sm,
                  value: f.layout?.errorPlacement ?? '',
                  options: [
                    const UiSelectOption(value: '', label: 'Form default'),
                    const UiSelectOption(value: 'below', label: 'Below the box'),
                    UiSelectOption(value: 'inside', label: 'Inside the box', disabled: !info.textLike),
                  ],
                  onChanged: (v) => layout('errorPlacement', v.isEmpty ? null : v),
                ),
              ),
            ]),
            if (!info.textLike) const FbHint('“Inside the box” works for text, number and email boxes; this field shows them above and below.'),
            if (f.layout?.labelPlacement == 'hidden') const FbHint('Screen readers still read the question. Use it when the heading above already says it.'),
          ],
        ]),
      FbSection(title: 'Saved data', children: [
        _KeyBox(id: f.id, current: f.key),
        if (info.textLike && f.type != UiFbFieldType.number && f.type != UiFbFieldType.currency)
          FbSetting(
            label: 'Browser autofill',
            child: UiSelect(
              label: 'Browser autofill',
              size: UiSize.sm,
              value: p?.autocomplete ?? '',
              options: [for (final a in _autocomplete) UiSelectOption(value: a.$1, label: a.$2)],
              onChanged: (v) => prop('autocomplete', v.isEmpty ? null : v),
            ),
          ),
      ]),
      _Actions(id: f.id, onDelete: onDelete),
    ];
    return _stack(context, children);
  }

  List<Widget> _typeProps(BuildContext context, UiFbField f, void Function(String key, Object? value) prop) {
    final p = f.props;
    Widget num_(String label, String key, num? value, {num? min, num? max, String placeholder = ''}) => FbSetting(
      label: label,
      child: UiNumberInput(size: UiSize.sm, value: value, min: min, max: max, placeholder: placeholder, semanticLabel: label, onChanged: (v) => prop(key, v)),
    );
    Widget text(String label, String key, String? value, String placeholder, {String Function(String v)? map}) => FbSetting(
      label: label,
      child: UiInput(
        size: UiSize.sm,
        value: value ?? '',
        placeholder: placeholder,
        semanticLabel: label,
        onChanged: (v) => prop(key, map != null ? map(v) : (v.isEmpty ? null : v)),
      ),
    );
    Widget orient() => FbSetting(
      label: 'Arrange options',
      child: _segmented<String>(
        'Arrange options',
        p?.orientation ?? 'vertical',
        const [UiSegmentedOption(value: 'vertical', label: 'Stacked'), UiSegmentedOption(value: 'horizontal', label: 'In a row')],
        (v) => prop('orientation', v),
      ),
    );
    switch (f.type.name) {
      case 'number' || 'currency' || 'slider':
        return [
          FbPair(children: [
            num_('Lowest', 'min', p?.min, placeholder: 'Any'),
            num_('Highest', 'max', p?.max, placeholder: 'Any'),
            if (f.type != UiFbFieldType.currency) num_('Steps of', 'step', p?.step ?? 1, min: 0),
            if (f.type == UiFbFieldType.currency) text('Currency', 'currency', p?.currency ?? 'USD', 'USD', map: (v) => v.toUpperCase()),
            if (f.type != UiFbFieldType.slider) num_('Decimals', 'decimals', p?.decimals, min: 0, max: 6, placeholder: 'Any'),
            if (f.type == UiFbFieldType.number) text('Unit', 'suffix', p?.suffix, 'e.g. kg'),
          ]),
          if (f.type != UiFbFieldType.slider) const FbHint('Lowest and highest guide the arrows. Add a check to enforce them.'),
        ];
      case 'textarea':
        return [
          FbPair(children: [num_('Starts with lines', 'rows', p?.rows ?? 3, min: 1, max: 20), num_('Grows up to', 'maxRows', p?.maxRows ?? 8, min: 1, max: 40)]),
        ];
      case 'rating':
        return [num_('Number of stars', 'maxRating', p?.maxRating ?? 5, min: 2, max: 10)];
      case 'file':
        return [
          UiSwitch(value: p?.multiple == true, label: 'Allow several files', onChanged: (v) => prop('multiple', v ? true : null)),
          FbSetting(
            label: 'Accepted files',
            hint: 'Leave empty to accept any file. Add a “File types” check to enforce it.',
            child: UiInput(size: UiSize.sm, value: p?.accept ?? '', placeholder: '.pdf, .docx, image/*', semanticLabel: 'Accepted files', onChanged: (v) => prop('accept', v.isEmpty ? null : v)),
          ),
        ];
      case 'checkbox' || 'toggle':
        return [text('Text next to it', 'caption', p?.caption, 'I agree')];
      case 'radio':
        return [orient()];
      case 'checkboxes':
        return [orient(), UiSwitch(value: p?.selectAll == true, label: 'Offer “Select all”', onChanged: (v) => prop('selectAll', v ? true : null))];
      case 'calculated':
        final format = p?.format ?? 'number';
        return [
          UiFbCalcEditor(field: f),
          FbSetting(
            label: 'Show the result as',
            child: UiSelect(
              label: 'Show the result as',
              size: UiSize.sm,
              value: format,
              options: const [UiSelectOption(value: 'number', label: 'A number'), UiSelectOption(value: 'currency', label: 'Money'), UiSelectOption(value: 'text', label: 'Text')],
              onChanged: (v) => prop('format', v),
            ),
          ),
          if (format == 'currency')
            text('Currency code', 'currency', p?.currency ?? 'USD', 'USD', map: (v) => v.toUpperCase())
          else if (format != 'text')
            FbPair(children: [text('Before it', 'prefix', p?.prefix, 'e.g. #'), text('After it', 'suffix', p?.suffix, 'e.g. years')]),
          UiSwitch(value: p?.excludeFromData == true, label: 'Show it, but don’t save it', onChanged: (v) => prop('excludeFromData', v ? true : null)),
        ];
    }
    return const [];
  }
}

// ── Logic (fields, sections, text) ───────────────────────────────────────────────────────────

bool _hasRules(UiFbCondition? c) => c != null && (c is! UiFbConditionGroup || c.conditions.isNotEmpty);

const _visModes = [
  UiSegmentedOption(value: 'always', label: 'Always'),
  UiSegmentedOption(value: 'show', label: 'Only when…'),
  UiSegmentedOption(value: 'hide', label: 'Hide when…'),
];

class _LogicPanel extends StatelessWidget {
  const _LogicPanel({required this.el});
  final UiFbElement el;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = UiFbBuilderScope.of(context);
    final vis = el.visibility;
    final disabled = el is UiFbField ? (el as UiFbField).disabled : el is UiFbGroup ? (el as UiFbGroup).disabled : null;
    final lockMode = disabled == null ? 'no' : disabled.flag == true ? 'yes' : disabled.isConditional ? 'when' : 'no';

    void setDisabled(UiFbElement x, UiFbToggle? v) {
      if (x is UiFbField) x.disabled = v;
      if (x is UiFbGroup) x.disabled = v;
    }

    final usedBy = store.externalRefs(el.id);
    final field = el is UiFbField ? el as UiFbField : null;

    return _stack(context, [
      FbSection(first: true, title: el is UiFbGroup ? 'Show this section' : el is UiFbStatic ? 'Show this' : 'Show this question', children: [
        _segmented<String>('When to show it', vis?.action ?? 'always', _visModes, (mode) {
          store.updateAny(el.id, (x) {
            x.visibility = mode == 'show' || mode == 'hide' ? UiFbVisibility(action: mode, when: x.visibility?.when ?? fbEmptyCondition()) : null;
          });
        }),
        if (vis != null) ...[
          UiFbConditionEditor(
            condition: vis.when,
            forId: el.id,
            onChanged: (c) => store.updateAny(el.id, (x) => x.visibility = UiFbVisibility(action: x.visibility?.action ?? 'show', when: c), mergeKey: 'vis:${el.id}'),
          ),
          FbSentence(_hasRules(vis.when) ? '${vis.action == 'show' ? 'Shown only when' : 'Hidden when'} ${store.describe(vis.when)}.' : 'Add a rule to say when.'),
        ],
      ]),
      if (el is! UiFbStatic)
        FbSection(title: 'Can people change it?', children: [
          _segmented<String>(
            'Can people change it',
            lockMode,
            const [UiSegmentedOption(value: 'no', label: 'Yes'), UiSegmentedOption(value: 'yes', label: 'Read-only'), UiSegmentedOption(value: 'when', label: 'Read-only when…')],
            (mode) => store.updateAny(el.id, (x) {
              setDisabled(x, mode == 'yes' ? UiFbToggle.flag(true) : mode == 'when' ? UiFbToggle.when(disabled?.isConditional == true ? disabled!.when : fbEmptyCondition()) : null);
            }),
          ),
          if (lockMode == 'when')
            UiFbConditionEditor(
              condition: disabled!.when,
              forId: el.id,
              onChanged: (c) => store.updateAny(el.id, (x) => setDisabled(x, UiFbToggle.when(c)), mergeKey: 'lock:${el.id}'),
            ),
          const FbHint('Read-only answers are still saved, but not checked.'),
        ]),
      if (field != null && field.type != UiFbFieldType.calculated)
        FbSection(title: 'Fill in automatically', children: [
          for (final sv in field.setValue ?? const <UiFbSetValue>[])
            FbBox(key: ValueKey(sv.id), children: [
              FbRowHead(
                title: const FbLabel('When'),
                removeLabel: 'Remove this rule',
                onRemove: () => store.updateField(field.id, (x) {
                  final list = [...?x.setValue]..removeWhere((s) => s.id == sv.id);
                  x.setValue = list.isEmpty ? null : list;
                }),
              ),
              UiFbConditionEditor(
                condition: sv.when,
                forId: field.id,
                onChanged: (c) => store.updateField(field.id, (x) {
                  for (final s in x.setValue ?? const <UiFbSetValue>[]) {
                    if (s.id == sv.id) s.when = c;
                  }
                }, mergeKey: 'sv:${sv.id}'),
              ),
              const FbLabel('set this to'),
              UiFbValueInput(
                subject: UiFbRefOption(id: field.id, label: field.label, kind: valueKindOf(field.type, field.props?.format).subject, where: ''),
                op: valueKindOf(field.type) == UiFbValueKind.multi ? UiFbOperator.includesAny : UiFbOperator.eq,
                operand: sv.value,
                forId: field.id,
                label: 'Set this to',
                onChanged: (o) => store.updateField(field.id, (x) {
                  for (final s in x.setValue ?? const <UiFbSetValue>[]) {
                    if (s.id == sv.id) s.value = o;
                  }
                }, mergeKey: 'sv:${sv.id}'),
              ),
            ]),
          Align(
            alignment: Alignment.centerLeft,
            child: FbLink(
              label: 'Add a rule',
              icon: HugeIcons.strokeRoundedAdd01,
              onTap: () => store.updateField(field.id, (x) => x.setValue = [...?x.setValue, UiFbSetValue(id: fbUid('set'), when: fbEmptyCondition(), value: UiFbConstOperand(''))]),
            ),
          ),
          const FbHint('The answer is set once each time the rule starts to apply. People can still change it.'),
        ]),
      FbSection(title: 'Used by', children: [
        if (usedBy.isEmpty) const FbHint('No other rules depend on this.'),
        for (final r in usedBy)
          UiInteractive(
            onTap: () => store.select(r.ownerId),
            semanticLabel: '“${store.name(r.ownerId)}” ${_refWords[r.kind] ?? r.kind}',
            excludeChildSemantics: true,
            pressScale: false,
            builder: (context, s) => Container(
              padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: 6),
              decoration: BoxDecoration(
                color: s.hovered || s.pressed ? t.surfaceHover : null,
                borderRadius: BorderRadius.circular(t.radiusXs),
                boxShadow: s.focused ? t.focusRing : null,
              ),
              child: Text.rich(
                TextSpan(text: '“${store.name(r.ownerId)}” ', children: [TextSpan(text: _refWords[r.kind] ?? r.kind, style: TextStyle(color: t.textMuted))]),
                style: context.uiText.body.copyWith(fontSize: 13, color: t.text),
              ),
            ),
          ),
      ]),
    ]);
  }
}

// ── Section ──────────────────────────────────────────────────────────────────────────────────

class _GroupPanel extends StatelessWidget {
  const _GroupPanel({required this.group, required this.tab, this.onDelete});
  final UiFbGroup group;
  final _Tab tab;
  final ValueChanged<String>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (tab == _Tab.logic) return _LogicPanel(el: group);
    final store = UiFbBuilderScope.of(context);
    final g = group;
    final nested = store.index[g.id]?.repeat;
    final rep = g.repeat;

    void repeat(void Function(UiFbRepeat r) edit) => store.updateGroup(g.id, (x) => edit(x.repeat ??= UiFbRepeat()), mergeKey: 'rep:${g.id}');

    return _stack(context, [
      if (g.archived == true)
        FbWarn(
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
            const Text('This section is archived.'),
            FbLink(label: 'Restore it', fontSize: 12, onTap: () => store.setArchived(g.id, false)),
          ]),
        ),
      FbSetting(
        label: 'Title',
        child: UiInput(value: g.title ?? '', size: UiSize.sm, placeholder: 'e.g. Contact details', semanticLabel: 'Title', onChanged: (v) => store.setGroupTitle(g.id, v)),
      ),
      FbSetting(
        label: 'Description',
        child: UiTextarea(
          value: g.description ?? '',
          rows: 2,
          autosize: true,
          maxRows: 6,
          placeholder: 'Optional',
          semanticLabel: 'Description',
          onChanged: (v) => store.updateGroup(g.id, (x) => x.description = v.isEmpty ? null : v, mergeKey: 'desc:${g.id}'),
        ),
      ),
      FbSetting(
        label: 'Columns inside',
        child: _segmented<String>(
          'Columns',
          '${(g.columns ?? 1).toInt()}',
          const [UiSegmentedOption(value: '1', label: 'One'), UiSegmentedOption(value: '2', label: 'Two'), UiSegmentedOption(value: '3', label: 'Three')],
          (v) => store.updateGroup(g.id, (x) => x.columns = v == '1' ? null : int.parse(v)),
        ),
      ),
      FbSetting(
        label: 'Width',
        child: _segmented<String>('Width', g.layout?.width ?? 'full', _widths, (v) => store.updateGroup(g.id, (x) => x.layout = v == 'full' ? null : UiFbLayout(width: v))),
      ),
      FbSection(title: 'Repeating', children: [
        UiSwitch(
          value: rep != null,
          label: 'People can add this section more than once',
          onChanged: nested != null
              ? null
              : (on) {
                  if (on) {
                    final key = g.key ?? uniqueKey(store.def, fbSlug((g.title ?? '').isNotEmpty ? g.title! : 'items'), g.id);
                    store.updateGroup(g.id, (x) {
                      x.repeat = UiFbRepeat(min: 1, addLabel: 'Add another', itemLabel: 'Entry {n}');
                      x.key = key;
                    });
                  } else {
                    store.updateGroup(g.id, (x) => x.repeat = null);
                  }
                },
        ),
        if (nested != null) const FbHint('A section inside a repeating section can’t repeat itself.'),
        if (rep != null) ...[
          FbPair(children: [
            FbSetting(
              label: 'At least',
              child: UiNumberInput(size: UiSize.sm, value: rep.min ?? 0, min: 0, semanticLabel: 'At least', onChanged: (v) => repeat((r) => r.min = v ?? 0)),
            ),
            FbSetting(
              label: 'At most',
              child: UiNumberInput(size: UiSize.sm, value: rep.max, min: 1, placeholder: 'No limit', semanticLabel: 'At most', onChanged: (v) => repeat((r) => r.max = v)),
            ),
          ]),
          FbSetting(
            label: 'Add button',
            child: UiInput(size: UiSize.sm, value: rep.addLabel ?? '', placeholder: 'Add another', semanticLabel: 'Add button', onChanged: (v) => repeat((r) => r.addLabel = v.isEmpty ? null : v)),
          ),
          FbSetting(
            label: 'Each entry is called',
            hint: '{n} becomes the entry’s number.',
            child: UiInput(
              size: UiSize.sm,
              value: rep.itemLabel ?? '',
              placeholder: 'Entry {n}',
              semanticLabel: 'Each entry is called',
              onChanged: (v) => repeat((r) => r.itemLabel = v.isEmpty ? null : v),
            ),
          ),
        ],
      ]),
      FbSection(title: 'Saved data', children: [
        UiSwitch(
          value: (g.key ?? '').isNotEmpty,
          label: 'Keep its answers together',
          onChanged: rep != null
              ? null
              : (on) => store.updateGroup(g.id, (x) => x.key = on ? uniqueKey(store.def, fbSlug((g.title ?? '').isNotEmpty ? g.title! : 'section'), g.id) : null),
        ),
        FbHint(rep != null ? 'Entries are saved as a list under this name.' : 'Saves this section’s answers inside one object, e.g. address.street.'),
        if ((g.key ?? '').isNotEmpty) _KeyBox(id: g.id, current: g.key!, showHint: false),
      ]),
      _Actions(id: g.id, onDelete: onDelete),
    ]);
  }
}

// ── Heading / text / divider ─────────────────────────────────────────────────────────────────

class _StaticPanel extends StatelessWidget {
  const _StaticPanel({required this.item, required this.tab, this.onDelete});
  final UiFbStatic item;
  final _Tab tab;
  final ValueChanged<String>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (tab == _Tab.logic) return _LogicPanel(el: item);
    final store = UiFbBuilderScope.of(context);
    final s = item;
    return _stack(context, [
      FbSetting(
        label: 'Kind',
        child: _segmented<String>(
          'Kind',
          s.type,
          const [UiSegmentedOption(value: 'heading', label: 'Heading'), UiSegmentedOption(value: 'paragraph', label: 'Text'), UiSegmentedOption(value: 'divider', label: 'Divider')],
          (v) => store.updateStatic(s.id, (x) => x.type = v),
        ),
      ),
      if (s.type == 'heading')
        FbSetting(
          label: 'Heading',
          child: UiInput(size: UiSize.sm, value: s.text ?? '', semanticLabel: 'Heading', onChanged: (v) => store.updateStatic(s.id, (x) => x.text = v, mergeKey: 'text:${s.id}')),
        )
      else if (s.type == 'paragraph') ...[
        FbSetting(
          label: 'Text',
          child: UiTextarea(value: s.text ?? '', rows: 4, autosize: true, maxRows: 14, semanticLabel: 'Text', onChanged: (v) => store.updateStatic(s.id, (x) => x.text = v, mergeKey: 'text:${s.id}')),
        ),
        FbSetting(
          label: 'Width',
          child: _segmented<String>('Width', s.layout?.width ?? 'full', _widths, (v) => store.updateStatic(s.id, (x) => x.layout = v == 'full' ? null : UiFbLayout(width: v))),
        ),
      ],
      _Actions(id: s.id, onDelete: onDelete),
    ]);
  }
}

// ── Page ─────────────────────────────────────────────────────────────────────────────────────

class _PagePanel extends StatelessWidget {
  const _PagePanel({required this.page, required this.tab, this.onDelete});
  final UiFbPage page;
  final _Tab tab;
  final ValueChanged<String>? onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = UiFbBuilderScope.of(context);
    final p = page;
    final pages = store.def.pages;
    final i = pages.indexWhere((x) => x.id == p.id);

    if (tab == _Tab.settings) {
      return _stack(context, [
        FbSetting(
          label: 'Page title',
          child: UiInput(
            size: UiSize.sm,
            value: p.title ?? '',
            placeholder: 'Page ${i + 1}',
            semanticLabel: 'Page title',
            onChanged: (v) => store.updatePage(p.id, (x) => x.title = v.isEmpty ? null : v, mergeKey: 'ptitle:${p.id}'),
          ),
        ),
        FbSetting(
          label: 'Description',
          child: UiTextarea(
            value: p.description ?? '',
            rows: 2,
            autosize: true,
            maxRows: 6,
            placeholder: 'Optional',
            semanticLabel: 'Description',
            onChanged: (v) => store.updatePage(p.id, (x) => x.description = v.isEmpty ? null : v, mergeKey: 'pdesc:${p.id}'),
          ),
        ),
        Container(
          padding: EdgeInsets.only(top: t.space3),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: t.borderSubtle))),
          child: Wrap(spacing: t.space2, runSpacing: t.space2, children: [
            UiButton(label: 'Earlier', size: UiSize.sm, variant: UiButtonVariant.outline, icon: const UiIcon(HugeIcons.strokeRoundedArrowLeft01), onPressed: i == 0 ? null : () => store.movePage(p.id, -1)),
            UiButton(
              label: 'Later',
              size: UiSize.sm,
              variant: UiButtonVariant.outline,
              trailingIcon: const UiIcon(HugeIcons.strokeRoundedArrowRight01),
              onPressed: i == pages.length - 1 ? null : () => store.movePage(p.id, 1),
            ),
            if (pages.length > 1)
              UiButton(label: 'Delete page', size: UiSize.sm, variant: UiButtonVariant.outline, icon: const UiIcon(HugeIcons.strokeRoundedDelete02), onPressed: () => onDelete?.call(p.id)),
          ]),
        ),
      ]);
    }

    final vis = p.visibility;
    final later = [for (var k = i + 1; k < pages.length; k++) (id: pages[k].id, label: (pages[k].title ?? '').isNotEmpty ? pages[k].title! : 'Page ${k + 1}')];
    return _stack(context, [
      FbSection(first: true, title: 'Show this page', children: [
        _segmented<String>(
          'When to show the page',
          vis?.action ?? 'always',
          const [UiSegmentedOption(value: 'always', label: 'Always'), UiSegmentedOption(value: 'show', label: 'Only when…'), UiSegmentedOption(value: 'hide', label: 'Skip when…')],
          (mode) => store.updatePage(p.id, (x) => x.visibility = mode == 'show' || mode == 'hide' ? UiFbVisibility(action: mode, when: x.visibility?.when ?? fbEmptyCondition()) : null),
        ),
        if (vis != null) ...[
          UiFbConditionEditor(
            condition: vis.when,
            forId: p.id,
            onChanged: (c) => store.updatePage(p.id, (x) => x.visibility = UiFbVisibility(action: vis.action, when: c), mergeKey: 'pvis:${p.id}'),
          ),
          FbSentence(_hasRules(vis.when) ? '${vis.action == 'show' ? 'Shown only when' : 'Skipped when'} ${store.describe(vis.when)}.' : 'Add a rule to say when.'),
        ],
      ]),
      FbSection(title: 'After this page', children: [
        for (final j in p.jumps ?? const <UiFbJump>[])
          FbBox(key: ValueKey(j.id), children: [
            FbRowHead(
              title: const FbLabel('When'),
              removeLabel: 'Remove this jump',
              onRemove: () => store.updatePage(p.id, (x) {
                final list = [...?x.jumps]..removeWhere((y) => y.id == j.id);
                x.jumps = list.isEmpty ? null : list;
              }),
            ),
            UiFbConditionEditor(
              condition: j.when,
              forId: p.id,
              onChanged: (c) => store.updatePage(p.id, (x) {
                for (final y in x.jumps ?? const <UiFbJump>[]) {
                  if (y.id == j.id) y.when = c;
                }
              }, mergeKey: 'jump:${j.id}'),
            ),
            FbSetting(
              label: 'go to',
              child: UiSelect(
                label: 'go to',
                size: UiSize.sm,
                value: j.to,
                options: [for (final q in later) UiSelectOption(value: q.id, label: q.label), const UiSelectOption(value: 'end', label: 'The end (submit)')],
                onChanged: (v) => store.updatePage(p.id, (x) {
                  for (final y in x.jumps ?? const <UiFbJump>[]) {
                    if (y.id == j.id) y.to = v;
                  }
                }, mergeKey: 'jump:${j.id}'),
              ),
            ),
          ]),
        Align(
          alignment: Alignment.centerLeft,
          child: FbLink(
            label: 'Add a jump',
            icon: HugeIcons.strokeRoundedAdd01,
            onTap: () {
              final to = i + 2 < pages.length ? pages[i + 2].id : (i + 1 < pages.length ? pages[i + 1].id : 'end');
              store.updatePage(p.id, (x) => x.jumps = [...?x.jumps, UiFbJump(id: fbUid('jmp'), when: fbEmptyCondition(), to: to)]);
            },
          ),
        ),
        const FbHint('Without a jump, people continue to the next page. The first jump that matches wins; pages jumped over are skipped.'),
      ]),
    ]);
  }
}

// ── Form ─────────────────────────────────────────────────────────────────────────────────────

class _FormSettings extends StatelessWidget {
  const _FormSettings({required this.store});
  final UiFormBuilderController store;

  @override
  Widget build(BuildContext context) {
    final def = store.def;
    return _stack(context, [
      FbSetting(
        label: 'Form title',
        child: UiInput(size: UiSize.sm, value: def.title, semanticLabel: 'Form title', onChanged: (v) => store.updateForm(title: v, mergeKey: 'ftitle')),
      ),
      FbSetting(
        label: 'Description',
        child: UiTextarea(
          value: def.description ?? '',
          rows: 2,
          autosize: true,
          maxRows: 6,
          placeholder: 'Shown at the top of the form',
          semanticLabel: 'Description',
          onChanged: (v) => store.updateForm(description: v.isEmpty ? null : v, clearDescription: v.isEmpty, mergeKey: 'fdesc'),
        ),
      ),
      UiFbSettingsFields(settings: def.settings ?? UiFbSettings(), onPatch: (edit, {mergeKey}) => store.updateSettings(edit, mergeKey: mergeKey)),
    ]);
  }
}
