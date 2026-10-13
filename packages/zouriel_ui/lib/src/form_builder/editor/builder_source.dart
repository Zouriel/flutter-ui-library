import 'package:flutter/widgets.dart';

import '../../button/button.dart';
import '../../core/types.dart';
import '../../forms/text/inputs.dart';
import '../../forms/text/number_input.dart';
import '../../forms/text/select.dart';
import '../../theme/theme.dart';
import '../engine/field_types.dart';
import '../engine/js.dart';
import '../engine/option_sources.dart';
import '../engine/schema.dart';
import 'builder_bits.dart';
import 'builder_store.dart';

/// `ui-fb-source-settings`: where a dropdown or multi-select gets its options from a registered
/// list: which list, its settings (each a fixed value or another question's answer, for lists
/// that depend on each other), and "Test the list" to try it.
class UiFbSourceSettings extends StatefulWidget {
  const UiFbSourceSettings({super.key, required this.field});
  final UiFbField field;

  @override
  State<UiFbSourceSettings> createState() => _UiFbSourceSettingsState();
}

class _UiFbSourceSettingsState extends State<UiFbSourceSettings> {
  /// Stand-in answers for settings that follow another question, only for trying the list here.
  final Map<String, Object?> _tryWith = {};
  bool _testing = false;
  ({bool ok, String text})? _result;
  int _run = 0;

  UiFbOptionSourceRef get _src => widget.field.source ?? UiFbOptionSourceRef(type: '');

  Map<String, Object?> get _previewParams => {
    for (final e in (_src.params ?? const <String, UiFbOperand>{}).entries)
      e.key: e.value is UiFbConstOperand ? (e.value as UiFbConstOperand).value : _tryWith[e.key],
  };

  /// Loads the first page with the current settings and says what came back.
  Future<void> _test(UiFbOptionSourceDef d) async {
    final params = _previewParams;
    final missing = (d.params ?? const <UiFbSourceParamSpec>[]).where((p) => p.required && (params[p.key] == null || params[p.key] == '')).firstOrNull;
    if (missing != null) {
      setState(() => _result = (ok: false, text: 'Choose ${missing.label.toLowerCase()} to test with first.'));
      return;
    }
    final run = ++_run;
    setState(() {
      _testing = true;
      _result = null;
    });
    final pageSize = d.pageSize ?? 20;
    ({bool ok, String text}) result;
    try {
      final res = await d.search(UiFbSourceQuery(query: '', page: 1, pageSize: pageSize, params: params));
      final n = res.total ?? res.items.length;
      final more = res.total == null && sourceHasMore(res, res.items.length, pageSize) ? '+' : '';
      final eg = res.items.take(3).map((i) => i.label).join(', ');
      result = res.items.isNotEmpty
          ? (ok: true, text: 'Works: ${jsNumberToString(n)}$more ${d.label.toLowerCase()}, e.g. $eg.')
          : (ok: true, text: 'Works, but the list is empty with these settings.');
    } catch (e) {
      final msg = e.toString();
      result = (ok: false, text: 'Couldn’t load it${msg.isNotEmpty ? ': $msg' : ''}.');
    }
    if (!mounted || run != _run) return;
    setState(() {
      _testing = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = UiFbBuilderScope.of(context);
    final f = widget.field;
    final src = _src;
    final def = store.optionSourceDefs.where((d) => d.type == src.type).firstOrNull;
    // Questions a setting can follow: answers outside this field that aren't files.
    const notAnswers = {UiFbSubjectKind.group, UiFbSubjectKind.repeat, UiFbSubjectKind.page, UiFbSubjectKind.file};
    final answers = [for (final r in store.refOptions(f.id)) if (r.id != f.id && !notAnswers.contains(r.kind)) r];

    void setType(String type) {
      setState(() => _result = null);
      store.updateField(f.id, (x) => x.source = UiFbOptionSourceRef(type: type, params: {}));
    }

    void setParam(UiFbSourceParamSpec p, UiFbOperand v, {String? mergeKey}) {
      setState(() => _result = null);
      store.updateField(f.id, (x) {
        final next = UiFbOptionSourceRef.fromJson(x.source?.toJson() ?? {'type': src.type})!;
        final params = next.params ?? <String, UiFbOperand>{};
        final empty = v is UiFbConstOperand && (v.value == null || v.value == '');
        if (empty) {
          params.remove(p.key);
        } else {
          params[p.key] = v;
        }
        next.params = params;
        x.source = next;
      }, mergeKey: mergeKey);
    }

    final rows = <Widget>[
      FbSetting(
        label: 'List',
        child: UiSelect(
          label: 'List',
          size: UiSize.sm,
          placeholder: src.type.isNotEmpty ? '“${src.type}” (not available here)' : 'Choose a list…',
          value: def?.type,
          options: [for (final d in store.optionSourceDefs) UiSelectOption(value: d.type, label: d.label)],
          onChanged: setType,
        ),
      ),
    ];
    if (def == null) {
      if (store.optionSourceDefs.isEmpty) rows.add(const FbWarn(text: 'This app hasn’t registered any lists. Switch back to a typed list, or ask a developer to add one.'));
    } else {
      if (def.description != null && def.description!.isNotEmpty) rows.add(FbHint(def.description!));
      for (final p in def.params ?? const <UiFbSourceParamSpec>[]) {
        final v = src.params?[p.key];
        final isRef = v is UiFbRefOperand;
        final constV = v is UiFbConstOperand ? v.value : null;
        Widget valueBox;
        if (isRef) {
          valueBox = UiSelect(
            label: '${p.label}: question',
            size: UiSize.sm,
            placeholder: 'Choose a question…',
            value: v.ref.isEmpty ? null : v.ref,
            options: [for (final r in answers) UiSelectOption(value: r.id, label: r.label)],
            onChanged: (id) => setParam(p, UiFbRefOperand(id)),
          );
        } else {
          valueBox = switch (p.kind ?? 'text') {
            'select' => UiSelect(
              label: p.label,
              size: UiSize.sm,
              value: constV == null ? '' : jsString(constV),
              options: [
                UiSelectOption(value: '', label: p.required ? 'Choose…' : 'Any'),
                for (final o in p.options ?? const <({String value, String label})>[]) UiSelectOption(value: o.value, label: o.label),
              ],
              onChanged: (x) => setParam(p, UiFbConstOperand(x)),
            ),
            'number' => UiNumberInput(size: UiSize.sm, value: constV is num ? constV : null, semanticLabel: p.label, onChanged: (x) => setParam(p, UiFbConstOperand(x))),
            _ => UiInput(
              size: UiSize.sm,
              value: constV == null ? '' : jsString(constV),
              placeholder: p.placeholder ?? '',
              semanticLabel: p.label,
              onChanged: (x) => setParam(p, UiFbConstOperand(x), mergeKey: 'srcp:${f.id}:${p.key}'),
            ),
          };
        }
        rows.add(Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: [
          FbLabel(p.label, required: p.required),
          Row(spacing: t.space2, children: [
            SizedBox(
              width: 150,
              child: UiSelect(
                label: '${p.label}: where the value comes from',
                size: UiSize.sm,
                value: isRef ? 'ref' : 'const',
                options: [const UiSelectOption(value: 'const', label: 'is'), if (answers.isNotEmpty || isRef) const UiSelectOption(value: 'ref', label: 'is the answer to')],
                onChanged: (m) => setParam(p, m == 'ref' ? UiFbRefOperand('') : UiFbConstOperand('')),
              ),
            ),
            Expanded(child: valueBox),
          ]),
          if (p.hint != null && p.hint!.isNotEmpty) FbHint(p.hint!),
          if (isRef) const FbHint('Changing that answer clears this one, since the list changes.'),
        ]));
      }
      final refParams = [for (final p in def.params ?? const <UiFbSourceParamSpec>[]) if (src.params?[p.key] is UiFbRefOperand) p];
      rows.add(Container(
        padding: EdgeInsets.only(top: t.space2),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: [
          const FbLabel('Check the list'),
          // Settings that follow another answer have no answer here; let the admin pick one to try with.
          for (final p in refParams)
            Row(spacing: t.space2, children: [
              Text('Test with ${p.label.toLowerCase()}', style: context.uiText.body.copyWith(fontSize: 12, color: t.textSecondary)),
              Expanded(
                child: (p.options ?? const []).isNotEmpty
                    ? UiSelect(
                        label: 'Try with ${p.label}',
                        size: UiSize.sm,
                        placeholder: 'Choose…',
                        value: _tryWith[p.key] as String?,
                        options: [for (final o in p.options!) UiSelectOption(value: o.value, label: o.label)],
                        onChanged: (x) => setState(() {
                          _result = null;
                          _tryWith[p.key] = x.isEmpty ? null : x;
                        }),
                      )
                    : UiInput(
                        size: UiSize.sm,
                        value: _tryWith[p.key] == null ? '' : jsString(_tryWith[p.key]),
                        placeholder: 'A value to try',
                        semanticLabel: 'Try with ${p.label}',
                        onChanged: (x) => setState(() {
                          _result = null;
                          _tryWith[p.key] = x.isEmpty ? null : x;
                        }),
                      ),
              ),
            ]),
          Row(spacing: t.space2, children: [
            UiButton(label: 'Test the list', size: UiSize.sm, variant: UiButtonVariant.outline, loading: _testing, onPressed: () => _test(def)),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _result?.text ?? '',
                  style: context.uiText.body.copyWith(fontSize: 12, color: _result?.ok == false ? t.danger : t.textSecondary),
                ),
              ),
            ),
          ]),
          const FbHint('Answers are saved with both the value and its label, so they stay readable later. To pre-fill one, use “Starts with” below.'),
        ]),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: rows);
  }
}
