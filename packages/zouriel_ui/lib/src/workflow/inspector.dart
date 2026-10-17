import 'package:flutter/widgets.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../forms/choice/checkbox.dart';
import '../forms/text/inputs.dart';
import '../forms/text/number_input.dart';
import '../forms/text/time_picker.dart';
import '../theme/theme.dart';
import 'bits.dart';
import 'definition.dart';
import 'editors.dart';
import 'icons.dart';
import 'json.dart';
import 'schema.dart';
import 'scope.dart';
import 'step_editors.dart';
import 'store.dart';

const List<({String type, String label, String hint})> _triggerTypes = [
  (type: 'fieldChanged', label: 'A field changes', hint: 'e.g. status becomes Submitted'),
  (type: 'created', label: 'A record is created', hint: 'every new record'),
  (type: 'stateEntered', label: 'A lifecycle reaches a state', hint: 'uses a published lifecycle'),
  (type: 'transitionApplied', label: 'A lifecycle transition happens', hint: 'e.g. after “Approve”'),
  (type: 'dateReached', label: 'A date comes up', hint: 'e.g. 2 days before the deadline'),
  (type: 'schedule', label: 'On a schedule', hint: 'every day, week or month'),
  (type: 'manual', label: 'Someone presses a button', hint: 'on the record page'),
  (type: 'signal', label: 'The app reports an event', hint: 'e.g. payment received'),
  (type: 'deleted', label: 'A record is deleted', hint: 'gets the record as it was'),
];

const List<WfOption> _cronPresets = [
  (value: '0 9 * * *', label: 'Every day at 09:00'),
  (value: '0 9 * * 1-5', label: 'Every weekday at 09:00'),
  (value: '0 9 * * 1', label: 'Every Monday at 09:00'),
  (value: '0 9 1 * *', label: 'On the 1st of each month at 09:00'),
  (value: '0 * * * *', label: 'Every hour'),
];

/// The trigger: what starts an automation (the web `ui-wf-trigger-editor`).
class WfTriggerEditor extends StatefulWidget {
  const WfTriggerEditor({super.key});

  @override
  State<WfTriggerEditor> createState() => _WfTriggerEditorState();
}

class _WfTriggerEditorState extends State<WfTriggerEditor> {
  bool _custom = false;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = WfBuilderScope.of(context).store;
    final def = store.def;
    final trigger = def.trigger ?? UiWfTrigger('fieldChanged');
    final tokens = store.tokens(const UiWfAt.list('root', 0));
    final summary = describeTrigger(trigger, store.describeContext(tokens));
    final watchable = [for (final f in store.entity?.fields ?? const <UiWfFieldDescriptor>[]) if (f.watchable) f];
    final dateFields = [for (final f in watchable) if (f.type == 'date' || f.type == 'dateTime') f];
    final field = fieldOf(store.registry, def.entity, trigger.field);
    final lifecycles = [
      for (final o in store.others)
        if (o.kind == 'lifecycle' && o.version > 0 && ((def.entity ?? '').isEmpty || o.entity == def.entity)) o,
    ];
    final lcKey = trigger.lifecycle;
    if (lcKey != null && lcKey.isNotEmpty) store.loadLifecycle(lcKey);
    final lcDef = store.lifecycleCache[lcKey ?? ''];
    final isPreset = _cronPresets.any((p) => p.value == trigger.cron);

    void patch(UiJson p, [String? mergeKey]) => store.setTrigger(trigger.patch(p), mergeKey: mergeKey == null ? null : 'trigger:$mergeKey');

    void setType(String type) {
      if (type == trigger.type) return;
      store.setTrigger(UiWfTrigger.fromJson({
        'type': type,
        if (type == 'schedule') 'cron': _cronPresets.first.value,
        if (type == 'dateReached') ...{'offset': '-P1D', 'at': '09:00'},
        if (type == 'manual') 'label': 'Start',
      }));
    }

    bool has(List<Object?>? list, Object? v) => (list ?? const []).any((x) => jsString(x) == jsString(v));
    void toggle(String key, Object? v, bool on) {
      final cur = [for (final x in (key == 'to' ? trigger.to : trigger.from) ?? const <Object?>[]) if (jsString(x) != jsString(v)) x];
      final next = on ? [...cur, v] : cur;
      patch({key: next.isNotEmpty ? next : null});
    }

    void toggleList(String key, String v, bool on) {
      final cur = [for (final x in (key == 'states' ? trigger.states : trigger.transitions) ?? const <String>[]) if (x != v) x];
      patch({key: on ? [...cur, v] : cur});
    }

    Widget sw(bool value, String label, ValueChanged<bool>? onChanged) => FbSwitch(value: value, label: label, onChanged: onChanged);
    WfSelect lifecycleSelect(String resetKey) => WfSelect(
      label: 'Lifecycle',
      placeholder: 'Choose…',
      value: trigger.lifecycle,
      options: [for (final l in lifecycles) (value: l.key, label: l.title)],
      onChanged: (v) => patch({'lifecycle': v, resetKey: <Object?>[]}),
    );

    final typeSettings = <Widget>[
      if (trigger.type == 'fieldChanged') ...[
        FbSetting(label: 'Field', child: WfSelect(label: 'Field', placeholder: 'Choose a field…', value: trigger.field, options: [for (final f in watchable) (value: f.key, label: f.label)], onChanged: (v) => patch({'field': v, 'from': null, 'to': null}))),
        if (watchable.isEmpty && store.entity != null) const FbHint('The app hasn’t allowed any field of this record to be watched.'),
        if (field != null)
          if (field.options?.isNotEmpty ?? false) ...[
            FbSetting(
              label: 'Changes to (leave empty for any value)',
              child: WfChecks(label: 'Changes to', options: [for (final o in field.options!) (value: jsString(o.value), label: o.label)], isChecked: (v) => has(trigger.to, v), onChanged: (v, on) => toggle('to', field.options!.firstWhere((o) => jsString(o.value) == v).value, on)),
            ),
            FbSetting(
              label: 'Only when it was (optional)',
              child: WfChecks(label: 'Only when it was', options: [for (final o in field.options!) (value: jsString(o.value), label: o.label)], isChecked: (v) => has(trigger.from, v), onChanged: (v, on) => toggle('from', field.options!.firstWhere((o) => jsString(o.value) == v).value, on)),
            ),
          ] else
            FbHint('Starts on any change to ${field.label}. Add conditions below to narrow it.'),
        sw(trigger.retrigger, 'Also start when this workflow itself changes it', (on) => patch({'retrigger': on ? true : null})),
      ],
      if (trigger.type == 'stateEntered') ...[
        FbSetting(label: 'Lifecycle', child: lifecycleSelect('states')),
        if (lcDef?.lifecycle?.states case final states? when states.isNotEmpty)
          FbSetting(
            label: 'Reaches',
            child: WfChecks(label: 'Reaches', options: [for (final s in states) (value: s.key, label: s.label)], isChecked: (v) => (trigger.states ?? const []).contains(v), onChanged: (v, on) => toggleList('states', v, on)),
          ),
      ],
      if (trigger.type == 'transitionApplied') ...[
        FbSetting(label: 'Lifecycle', child: lifecycleSelect('transitions')),
        if (lcDef?.lifecycle?.transitions case final ts? when ts.isNotEmpty)
          FbSetting(
            label: 'After',
            child: WfChecks(label: 'After', options: [for (final x in ts) (value: x.key, label: x.label)], isChecked: (v) => (trigger.transitions ?? const []).contains(v), onChanged: (v, on) => toggleList('transitions', v, on)),
          ),
      ],
      if (trigger.type == 'dateReached') ...[
        FbSetting(label: 'Date field', child: WfSelect(label: 'Date field', placeholder: 'Choose…', value: trigger.field, options: [for (final f in dateFields) (value: f.key, label: f.label)], onChanged: (v) => patch({'field': v}))),
        FbSetting(label: 'When', child: WfDurationInput(value: trigger.offset ?? '-P1D', signed: true, label: 'Offset', onChanged: (v) => patch({'offset': v}))),
        FbSetting(label: 'At (time of day)', child: UiTimePicker(size: UiSize.sm, value: trigger.at ?? '09:00', label: 'At (time of day)', onChanged: (v) => patch({'at': v}))),
      ],
      if (trigger.type == 'schedule') ...[
        FbSetting(
          label: 'When',
          child: WfSelect(
            label: 'When',
            value: isPreset && !_custom ? trigger.cron : 'custom',
            options: [..._cronPresets, (value: 'custom', label: 'Custom…')],
            onChanged: (v) {
              setState(() => _custom = v == 'custom');
              if (v != 'custom') patch({'cron': v});
            },
          ),
        ),
        if (!isPreset || _custom)
          FbSetting(
            label: 'Schedule (minute hour day month weekday)',
            child: UiInput(size: UiSize.sm, value: trigger.cron ?? '', placeholder: '30 8 * * 1-5', semanticLabel: 'Schedule', onChanged: (v) => patch({'cron': v}, 'cron')),
          ),
        sw(trigger.forEach != null, 'Run once for each matching record', store.entity == null ? null : (on) => patch({'forEach': on ? {'limit': 100} : null})),
        if (trigger.forEach case final fe?) ...[
          WfConditionEditor(
            value: fe['when'] is Map ? UiWfCondition.fromJson(fe['when']) : null,
            tokens: tokens,
            emptyText: 'Every record.',
            onChanged: (c) => patch({'forEach': wfPatch(fe, {'when': c.conditions.isNotEmpty ? c.json : null})}),
          ),
          FbSetting(
            label: 'At most',
            child: UiNumberInput(size: UiSize.sm, value: wfNum(fe['limit']) ?? 100, min: 1, max: 500, suffix: 'records', semanticLabel: 'At most', onChanged: (v) => patch({'forEach': {...fe, 'limit': v ?? 100}})),
          ),
        ],
      ],
      if (trigger.type == 'manual') ...[
        FbSetting(label: 'Button label', child: UiInput(size: UiSize.sm, value: trigger.label ?? '', placeholder: 'e.g. Ask for more documents', semanticLabel: 'Button label', onChanged: (v) => patch({'label': v}, 'label'))),
        FbSetting(
          label: 'Who can press it',
          child: WfAssigneesEditor(value: trigger.who ?? const [], registry: store.registry, tokens: tokens, api: store.api, emptyText: 'Anyone who can see the record.', onChanged: (v) => patch({'who': v})),
        ),
        FbSetting(label: 'Ask for', child: WfFormField(value: trigger.form, title: 'Questions when starting', addLabel: 'Add questions (a form)', onChanged: (f) => patch({'form': f}))),
      ],
      if (trigger.type == 'signal')
        FbSetting(
          label: 'Event',
          child: WfSelect(label: 'Event', placeholder: 'Choose…', value: trigger.signal, options: [for (final s in store.registry?.signals ?? const <UiWfSignalDescriptor>[]) (value: s.key, label: s.label)], onChanged: (v) => patch({'signal': v})),
        ),
    ];

    return WfStack(children: [
      Semantics(
        container: true,
        label: 'What starts it',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2, children: [
          for (final tt in _triggerTypes)
            UiInteractive(
              onTap: () => setType(tt.type),
              checked: trigger.type == tt.type,
              semanticLabel: tt.label,
              semanticHint: tt.hint,
              excludeChildSemantics: true,
              pressScale: false,
              builder: (context, s) {
                final on = trigger.type == tt.type;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: on ? t.primary.withValues(alpha: 0.08) : (s.hovered ? t.surfaceHover : null),
                    border: Border.all(color: on ? t.primary : const Color(0x00000000)),
                    borderRadius: BorderRadius.circular(t.radius),
                    boxShadow: s.focused ? t.focusRing : null,
                  ),
                  child: Row(spacing: 8, children: [
                    UiIcon(wfTriggerIcon(tt.type), size: 14, color: on ? t.primary : t.textSecondary),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tt.label, style: context.uiText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: t.text)),
                        Text(tt.hint, style: context.uiText.body.copyWith(fontSize: 11.5, color: t.textMuted)),
                      ]),
                    ),
                  ]),
                );
              },
            ),
        ]),
      ),
      ...typeSettings,
      if (trigger.type != 'schedule')
        WfSection(title: 'Only if', children: [
          WfConditionEditor(value: trigger.when, tokens: tokens, emptyText: 'No extra conditions.', onChanged: (c) => patch({'when': c.conditions.isNotEmpty ? c.json : null})),
        ]),
      FbHint('$summary.'),
    ]);
  }
}

const List<WfOption> _varTypes = [
  (value: 'text', label: 'Text'), (value: 'number', label: 'Number'), (value: 'boolean', label: 'Yes/no'),
  (value: 'date', label: 'Date'), (value: 'user', label: 'Person'), (value: 'json', label: 'Anything'),
];

/// The tokens "Applies to" offers: only the record's own fields, never its id or the field the
/// lifecycle controls (spec §6).
List<UiWfToken> wfOwnFieldTokens(List<UiWfToken> tokens, String controlled) => [
      for (final t in tokens)
        if (RegExp(r'^entity\.[^.]+$').hasMatch(t.path) && t.path != 'entity.id' && t.path != 'entity.$controlled') t,
    ];

/// The workflow's own settings: name, record type, variables, who looks after it (the web
/// `ui-wf-workflow-editor`).
class WfWorkflowEditor extends StatelessWidget {
  const WfWorkflowEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = WfBuilderScope.of(context).store;
    final def = store.def;
    final published = store.published != null;
    final lc = def.lifecycle;
    final settings = def.settings?.json ?? const <String, Object?>{};
    final lifecycleFields = [for (final f in store.entity?.fields ?? const <UiWfFieldDescriptor>[]) if (f.lifecycle && f.type == 'enum') f];
    final vars = def.variables ?? const <UiWfVariable>[];

    void patch(UiJson p, [String? mergeKey]) => store.patch(p, mergeKey: mergeKey == null ? null : 'wf:$mergeKey');
    void patchSettings(UiJson p) => patch({'settings': wfPatch(settings, p)});

    void setLifecycleField(String field) {
      if (lc == null) return;
      final f = fieldOf(store.registry, def.entity, field);
      final opts = f?.options ?? const <UiWfFieldOption>[];
      // Fresh lifecycle: one state per value of the field, the first one starting.
      final fresh = lc.states.length <= 2 && lc.transitions.length <= 1 && opts.isNotEmpty;
      if (fresh) {
        final states = [
          for (var i = 0; i < opts.length; i++)
            {
              'id': wfId('st'), 'key': jsString(opts[i].value), 'label': opts[i].label,
              'category': i == 0 ? 'initial' : (i == opts.length - 1 ? 'terminal' : 'active'),
              'tone': i == 0 ? 'neutral' : (i == opts.length - 1 ? 'success' : 'info'),
            },
        ];
        final transitions = [
          for (var i = 1; i < states.length; i++)
            {'id': wfId('tr'), 'key': wfKey('to ${states[i]['label']}'), 'label': 'To ${states[i]['label']}', 'from': [states[i - 1]['id']], 'to': states[i]['id'], 'who': <Object?>[]},
        ];
        patch({'lifecycle': lc.patch({'field': field, 'states': states, 'transitions': transitions, 'layout': null}).json});
      } else {
        patch({'lifecycle': lc.patch({'field': field}).json});
      }
    }

    void setVariable(int i, UiJson p) {
      final next = [
        for (var j = 0; j < vars.length; j++)
          if (j != i)
            vars[j]
          else
            () {
              var n = vars[j].patch(p);
              // The key follows the name only while nothing reads the variable yet; renaming then never breaks a step.
              final used = jsonStringify(def.json).contains('vars.${vars[j].key}');
              if (p.containsKey('label') && !used) n = n.patch({'key': wfKey(p['label'] as String, [for (var k = 0; k < vars.length; k++) if (k != i) vars[k].key])});
              final d = n.defaultValue;
              if (d == null || d == '') n = n.patch({'default': null});
              return n;
            }(),
      ];
      patch({'variables': next}, 'var$i');
    }

    return WfStack(children: [
      FbSetting(label: 'Name', child: UiInput(size: UiSize.sm, value: def.title, semanticLabel: 'Name', onChanged: (v) => patch({'title': v}, 'title'))),
      FbSetting(label: 'Description', child: UiTextarea(value: def.description ?? '', rows: 2, autosize: true, semanticLabel: 'Description', onChanged: (v) => patch({'description': v.isEmpty ? null : v}, 'description'))),
      FbSetting(
        label: 'Record type',
        child: WfSelect(
          label: 'Record type',
          enabled: !published,
          value: def.entity ?? '',
          options: [(value: '', label: def.kind == 'lifecycle' ? 'Choose…' : 'None (not about a record)'), for (final e in store.registry?.entities ?? const <UiWfEntityDescriptor>[]) (value: e.key, label: e.label)],
          onChanged: (v) => patch({'entity': v.isEmpty ? null : v}),
        ),
      ),
      if (published) const FbHint('The record type can’t change once the workflow is published.'),
      if (lc != null) ...[
        FbSetting(
          label: 'Field it controls',
          child: WfSelect(label: 'Field it controls', enabled: !published, placeholder: 'Choose…', value: lc.field, options: [for (final f in lifecycleFields) (value: f.key, label: f.label)], onChanged: setLifecycleField),
        ),
        FbSetting(
          label: 'If the app changes the field directly',
          child: WfSelect(
            label: 'If the app changes the field directly',
            value: lc.mode == 'observe' ? 'observe' : 'enforce',
            options: const [(value: 'enforce', label: 'Refuse it (only transitions may change it)'), (value: 'observe', label: 'Accept it and record it')],
            onChanged: (m) => patch({'lifecycle': lc.patch({'mode': m}).json}),
          ),
        ),
        WfSection(title: 'Applies to', children: [
          WfConditionEditor(
            value: lc.appliesWhen,
            tokens: wfOwnFieldTokens(store.tokens(const UiWfAt.list('root', 0)), lc.field),
            emptyText: 'Every ${(store.entity?.label ?? 'record').toLowerCase()} that no other lifecycle on this field covers.',
            onChanged: (c) => patch({'lifecycle': lc.patch({'appliesWhen': c.conditions.isNotEmpty ? c.json : null}).json}, 'appliesWhen'),
          ),
          const FbHint('Only records that meet these get this lifecycle, e.g. only those whose type is Passport. Pick fields that are set when the record is created: a record keeps its lifecycle if they change later. Another lifecycle on the same field can cover the rest.'),
        ]),
      ] else
        FbSetting(
          label: 'If it starts again for the same record while running',
          child: WfSelect(
            label: 'If it starts again for the same record while running',
            value: def.settings?.concurrency ?? 'perRecordSerial',
            options: const [(value: 'perRecordSerial', label: 'Wait for the earlier run'), (value: 'parallel', label: 'Run both'), (value: 'skipIfRunning', label: 'Don’t start it again')],
            onChanged: (v) => patchSettings({'concurrency': v}),
          ),
        ),
      FbSwitch(value: def.settings?.calendar == 'working', label: 'Count deadlines in working time', onChanged: (on) => patchSettings({'calendar': on ? 'working' : null})),
      if (def.kind == 'lifecycle')
        WfSection(title: 'Starting over', children: [
          FbSwitch(
            value: def.lifecycle?.reset != null,
            label: 'Let people reset a record\'s workflow',
            onChanged: (on) => on ? store.enableReset() : store.removeReset(),
          ),
          if (def.lifecycle?.reset != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FbLink(label: 'Who, where to and what changes on reset ›', fontSize: 12, onTap: () => store.selection = UiWfSelection.reset),
            ),
        ]),
      WfSection(title: 'Looked after by', children: [
        WfAssigneesEditor(value: def.settings?.owners ?? const [], registry: store.registry, api: store.api, emptyText: 'Nobody yet.', label: 'owners', onChanged: (v) => patchSettings({'owners': v})),
        FbSwitch(value: def.settings?.notifyOwnersOnIncident ?? false, label: 'Tell them when a run gets stuck', onChanged: (on) => patchSettings({'notifyOwnersOnIncident': on ? true : null})),
      ]),
      WfSection(title: 'Variables', children: [
        for (var i = 0; i < vars.length; i++)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 6, children: [
            Row(spacing: 6, children: [
              Expanded(child: UiInput(size: UiSize.sm, value: vars[i].label, semanticLabel: 'Variable ${i + 1} name', onChanged: (v) => setVariable(i, {'label': v}))),
              SizedBox(width: 104, child: WfSelect(label: 'Type', value: vars[i].type, options: _varTypes, onChanged: (v) => setVariable(i, {'type': v, 'default': null}))),
              FbIconButton(
                icon: WfIcons.delete02,
                label: 'Remove variable',
                danger: true,
                onPressed: () {
                  final next = [...vars]..removeAt(i);
                  patch({'variables': next.isEmpty ? null : next});
                },
              ),
            ]),
            WfValueInput(type: vars[i].type == 'json' ? 'text' : vars[i].type, value: vars[i].defaultValue, label: 'Starting value', placeholder: 'Starting value', onChanged: (v) => setVariable(i, {'default': v})),
          ]),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FbLink(
            label: 'Add a variable',
            onTap: () {
              final label = 'Variable ${vars.length + 1}';
              patch({'variables': [...vars, {'id': wfId('v'), 'key': wfKey(label, vars.map((v) => v.key)), 'label': label, 'type': 'text'}]});
            },
          ),
        ),
        const FbHint('Steps can set variables and read them later, e.g. to count attempts.'),
      ]),
      WfSection(spacing: 4, children: [
        const FbLabel('Key (used by the API and other workflows)'),
        Text(def.key, style: context.uiText.code.copyWith(fontSize: 12, color: t.textSecondary)),
      ]),
    ]);
  }
}

const List<WfOption> _stateTones = [(value: 'neutral', label: 'neutral'), (value: 'info', label: 'info'), (value: 'success', label: 'success'), (value: 'warning', label: 'warning'), (value: 'danger', label: 'danger')];

/// A lifecycle state: name and stored value, kind, colour, time limit (the web `ui-wf-state-editor`).
class WfStateEditor extends StatelessWidget {
  const WfStateEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final store = WfBuilderScope.of(context).store;
    final s = store.selectedState;
    if (s == null) return const SizedBox.shrink();
    final field = fieldOf(store.registry, store.def.entity, store.def.lifecycle?.field);
    void patch(UiJson p, [String? mergeKey]) => store.updateState(s.id, p, mergeKey: mergeKey == null ? null : 'state:${s.id}:$mergeKey');

    void setCategory(String category) {
      if (s.category == category) return;
      // Only one starting state: making this one the start turns the old start into an ordinary state,
      // in the same change, so one undo puts both back.
      store.commit(updateLifecycle(store.def, (lc) => lc.patch({
            'states': [
              for (final o in lc.states)
                o.id == s.id ? o.patch({'category': category}) : (category == 'initial' && o.category == 'initial' ? o.patch({'category': 'active'}) : o),
            ],
          })));
    }

    final sla = s.sla;
    return WfStack(children: [
      FbSetting(label: 'Name', child: UiInput(size: UiSize.sm, value: s.label, semanticLabel: 'Name', onChanged: (v) => patch({'label': v}, 'label'))),
      FbSetting(
        label: 'Stored value',
        child: (field?.options?.isNotEmpty ?? false)
            ? WfSelect(
                label: 'Stored value',
                value: s.key,
                unknownSuffix: 'not a value of the field',
                options: [for (final o in field!.options!) (value: jsString(o.value), label: '${o.label} (${jsString(o.value)})')],
                onChanged: (v) => patch({'key': v}),
              )
            : UiInput(size: UiSize.sm, value: s.key, semanticLabel: 'Stored value', onChanged: (v) => patch({'key': v}, 'key')),
      ),
      FbPair(children: [
        FbSetting(
          label: 'Kind',
          child: WfSelect(label: 'Kind', value: s.category, options: const [(value: 'initial', label: 'Starting state'), (value: 'active', label: 'In progress'), (value: 'terminal', label: 'Final state')], onChanged: setCategory),
        ),
        FbSetting(label: 'Colour', child: WfSelect(label: 'Colour', value: s.tone ?? 'neutral', options: _stateTones, onChanged: (v) => patch({'tone': v}))),
      ]),
      FbSetting(label: 'Description', child: UiTextarea(value: s.description ?? '', rows: 2, autosize: true, semanticLabel: 'Description', onChanged: (v) => patch({'description': v.isEmpty ? null : v}, 'description'))),
      if (s.category != 'terminal')
        WfSection(title: 'Time limit', children: [
          FbSwitch(value: sla != null, label: 'Do something if a record stays here too long', onChanged: (on) => patch({'sla': on ? {'within': 'P2D', 'steps': <Object?>[]} : null})),
          if (sla != null) ...[
            FbSetting(label: 'Longer than', child: WfDurationInput(value: sla.within, label: 'Time limit', onChanged: (v) => patch({'sla': {...sla.json, 'within': v}}))),
            FbSwitch(value: sla.calendar == 'working', label: 'Count working time only', onChanged: (on) => patch({'sla': wfPatch(sla.json, {'calendar': on ? 'working' : null})})),
          ],
        ]),
      FbSwitch(value: s.keepRunsOnExit, label: 'Keep its steps running after the record leaves', onChanged: (on) => patch({'keepRunsOnExit': on ? true : null})),
      const FbHint('Edit what happens on entering, leaving or running late in the steps panel under the diagram.'),
    ]);
  }
}

const List<WfOption> _transitionTones = [(value: 'neutral', label: 'neutral'), (value: 'primary', label: 'primary'), (value: 'success', label: 'success'), (value: 'warning', label: 'warning'), (value: 'danger', label: 'danger')];

/// A transition: who may apply it, when it is possible, what it asks for, and when it happens by
/// itself (the web `ui-wf-transition-editor`).
class WfTransitionEditor extends StatefulWidget {
  const WfTransitionEditor({super.key});

  @override
  State<WfTransitionEditor> createState() => _WfTransitionEditorState();
}

class _WfTransitionEditorState extends State<WfTransitionEditor> {
  bool _moreFrom = false;

  @override
  Widget build(BuildContext context) {
    final store = WfBuilderScope.of(context).store;
    final tr = store.selectedTransition;
    if (tr == null) return const SizedBox.shrink();
    final states = store.def.lifecycle?.states ?? const <UiWfState>[];
    final tokens = store.tokens(UiWfAt.list('transition:${tr.id}', 0));
    // What "Check before" and an automatic move can read: not the move's form answers, its remarks or
    // who made it, which don't exist yet when the check runs (and never for a move that happens by itself).
    final checkTokens = [for (final x in tokens) if (!x.path.startsWith('input.') && x.path != 'trigger.comment' && x.path != 'trigger.actor') x];
    void patch(UiJson p, [String? mergeKey]) => store.updateTransition(tr.id, p, mergeKey: mergeKey == null ? null : 'tr:${tr.id}:$mergeKey');
    final auto = tr.auto;
    final autoKind = auto == null ? '' : (auto.containsKey('after') ? 'after' : (auto.containsKey('when') ? 'when' : ''));
    final fromValue = tr.fromAny ? '*' : (tr.from.length == 1 ? tr.from.first : (tr.from.length > 1 ? '' : null));

    return WfStack(children: [
      FbSetting(label: 'Button label', child: UiInput(size: UiSize.sm, value: tr.label, semanticLabel: 'Button label', onChanged: (v) => patch({'label': v}, 'label'))),
      FbPair(children: [
        FbSetting(
          label: 'From',
          child: WfSelect(
            label: 'From',
            value: fromValue,
            options: [
              (value: '*', label: 'Any state (not final)'),
              for (final s in states) (value: s.id, label: s.label),
              if (!tr.fromAny && tr.from.length > 1) (value: '', label: '${tr.from.length} states'),
            ],
            onChanged: (v) {
              if (v.isEmpty) return;
              patch({'from': v == '*' ? '*' : [v]});
            },
          ),
        ),
        FbSetting(label: 'To', child: WfSelect(label: 'To', value: tr.to, options: [for (final s in states) (value: s.id, label: s.label)], onChanged: (v) => patch({'to': v}))),
      ]),
      if (!tr.fromAny) ...[
        Align(alignment: AlignmentDirectional.centerStart, child: FbLink(label: 'Starts from several states', fontSize: 12, onTap: () => setState(() => _moreFrom = !_moreFrom))),
        if (_moreFrom || tr.from.length > 1)
          WfChecks(
            label: 'Starts from',
            options: [for (final s in states) (value: s.id, label: s.label)],
            isChecked: tr.from.contains,
            onChanged: (id, on) {
              final next = on ? {...tr.from, id}.toList() : tr.from.where((x) => x != id).toList();
              if (next.isNotEmpty) patch({'from': next});
            },
          ),
      ],
      WfSection(title: 'Who can do this', children: [
        WfAssigneesEditor(
          value: tr.who ?? const [],
          registry: store.registry,
          tokens: tokens,
          api: store.api,
          label: 'people',
          emptyText: 'Nobody by hand: only automatically, or from other workflows.',
          onChanged: (v) => patch({'who': v}),
        ),
        FbSwitch(value: tr.hidden, label: 'Hide it from the record page', onChanged: (on) => patch({'hidden': on ? true : null})),
      ]),
      WfSection(title: 'Check before', children: [
        WfConditionEditor(value: tr.when, tokens: checkTokens, emptyText: 'Always possible from the states above.', onChanged: (c) => patch({'when': c.conditions.isNotEmpty ? c.json : null})),
      ]),
      WfSection(title: 'Ask for', children: [
        WfFormField(value: tr.inputForm, title: '${tr.label} form', addLabel: 'Add questions (a form)', onChanged: (f) => patch({'input': f == null ? null : {'form': f}})),
        FbSetting(
          label: 'Confirmation message',
          child: UiInput(size: UiSize.sm, value: tr.confirm ?? '', placeholder: 'e.g. Approve this application?', semanticLabel: 'Confirmation message', onChanged: (v) => patch({'confirm': v.isEmpty ? null : v}, 'confirm')),
        ),
        FbSetting(label: 'Button colour', child: WfSelect(label: 'Button colour', value: tr.tone ?? 'neutral', options: _transitionTones, onChanged: (v) => patch({'tone': v == 'neutral' ? null : v}))),
        FbSetting(
          label: 'Remarks',
          child: WfSelect(
            label: 'Remarks',
            value: tr.comment?.name ?? '',
            options: [
              (value: '', label: 'Default (${tr.tone == 'danger' ? 'optional, as it is red' : 'not asked'})'),
              (value: 'none', label: 'Not asked'),
              (value: 'optional', label: 'Optional'),
              (value: 'required', label: 'Required'),
            ],
            onChanged: (v) => patch({'comment': v.isEmpty ? null : v}),
          ),
        ),
        const FbHint('People explain the move in a few words; it shows in the history and steps can use it (“Remarks”). Moves that happen by themselves never ask.'),
      ]),
      WfSection(title: 'Happens by itself', children: [
        WfSelect(
          label: 'Automatic',
          value: autoKind,
          options: const [(value: '', label: 'No, only when applied'), (value: 'after', label: 'After some time in the state'), (value: 'when', label: 'When a condition becomes true')],
          onChanged: (k) => patch({'auto': k == 'after' ? {'after': 'P7D'} : (k == 'when' ? {'when': {'match': 'all', 'conditions': <Object?>[]}} : null)}),
        ),
        if (autoKind == 'after') WfDurationInput(value: wfStrOrNull(auto!['after']), label: 'After', onChanged: (v) => patch({'auto': {...auto, 'after': v}})),
        if (autoKind == 'when')
          WfConditionEditor(value: UiWfCondition.fromJson(auto!['when']), tokens: checkTokens, emptyText: 'Add the condition.', onChanged: (c) => patch({'auto': {'when': c.json}})),
      ]),
      const FbHint('Edit what happens afterwards (“Then do”) in the steps panel under the diagram.'),
    ]);
  }
}

/// The lifecycle's reset (the web `ui-wf-reset-editor`): who may start a record over, back to which
/// state, in which states it is offered, what it asks, and what else stops.
class WfResetEditor extends StatelessWidget {
  const WfResetEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final store = WfBuilderScope.of(context).store;
    final r = store.def.lifecycle?.reset;
    if (r == null) return const SizedBox.shrink();
    final states = store.def.lifecycle?.states ?? const <UiWfState>[];
    final start = states.where((s) => s.category == 'initial').firstOrNull;
    void patch(UiJson p, [String? mergeKey]) => store.updateReset(p, mergeKey: mergeKey);
    return WfStack(children: [
      const FbHint('Starting over stops the record\'s open tasks and runs, moves it back, then runs the steps under the diagram (“On reset”), which can change this record, related records and each item of a list.'),
      FbSetting(
        label: 'Button label',
        child: UiInput(size: UiSize.sm, value: r.label ?? '', placeholder: 'Reset workflow', semanticLabel: 'Button label', onChanged: (v) => patch({'label': v.isEmpty ? null : v}, 'label')),
      ),
      FbSetting(
        label: 'Back to',
        child: WfSelect(
          label: 'Back to',
          value: r.to ?? '',
          options: [
            (value: '', label: 'The starting state${start == null ? '' : ' (${start.label})'}'),
            for (final s in states)
              if (s.id != start?.id) (value: s.id, label: s.label),
          ],
          // When the ticks were "from a state onwards", they are worked out again for the new target in
          // the same change (the onward states stop at the reset's target).
          onChanged: (v) {
            final to = v.isEmpty ? null : v;
            if (r.to == to) return;
            final ticked = r.states;
            final from = ticked == null ? '' : _fromState(store.def, ticked);
            if (from.isEmpty) {
              patch({'to': to});
              return;
            }
            final next = updateLifecycle(store.def, (lc) => lc.patch({'reset': lc.reset!.patch({'to': to}).json}));
            patch({'to': to, 'states': wfStatesFrom(next, from)});
          },
        ),
      ),
      WfSection(title: 'Offer it', children: [
        WfSelect(
          label: 'Offer it',
          value: r.states != null ? 'some' : '',
          options: const [(value: '', label: 'In every state'), (value: 'some', label: 'From a state onwards')],
          onChanged: (m) {
            if (m != 'some') {
              patch({'states': null});
              return;
            }
            // Start from the first state after the start, the usual choice.
            final lc = store.def.lifecycle!;
            final initial = {for (final x in lc.states) if (x.category == 'initial') x.id};
            final first = lc.transitions.where((t) => !t.fromAny && t.from.any(initial.contains)).firstOrNull?.to ?? lc.states.firstOrNull?.id;
            patch({'states': first == null ? <String>[] : wfStatesFrom(store.def, first)});
          },
        ),
        if (r.states case final ticked?) ...[
          FbSetting(
            label: 'From',
            child: WfSelect(
              label: 'From',
              value: _fromState(store.def, ticked),
              placeholder: 'Choose a state…',
              options: [for (final x in states) (value: x.id, label: x.label)],
              onChanged: (id) {
                if (id.isNotEmpty) patch({'states': wfStatesFrom(store.def, id)});
              },
            ),
          ),
          Semantics(
            container: true,
            label: 'States it is offered in',
            child: Wrap(spacing: context.ui.space4, runSpacing: context.ui.space2, children: [
              for (final x in states)
                UiCheckbox(
                  value: ticked.contains(x.id),
                  label: x.label,
                  onChanged: (on) {
                    final rest = ticked.where((id) => id != x.id);
                    final next = {...rest, if (on) x.id};
                    patch({'states': [for (final y in states) if (next.contains(y.id)) y.id]});
                  },
                ),
            ]),
          ),
          if (ticked.isEmpty)
            const FbHint('Tick at least one state, or nobody can start a record over.')
          else if (_fromState(store.def, ticked).isEmpty)
            const FbHint('The ticked states aren’t one state and the ones after it, as the lifecycle is now. Keep them if that is what you meant, or choose a state under “From” to tick its states again.'),
        ],
      ]),
      WfSection(title: 'Who can reset', children: [
        WfAssigneesEditor(
          value: r.who,
          registry: store.registry,
          api: store.api,
          label: 'people',
          emptyText: 'Nobody yet: choose who may start records over.',
          onChanged: (v) => patch({'who': v}),
        ),
      ]),
      WfSection(title: 'Ask for', children: [
        WfFormField(value: r.inputForm, title: '${r.label ?? 'Reset'} form', addLabel: 'Add questions (e.g. a reason)', onChanged: (f) => patch({'input': f == null ? null : {'form': f}})),
        FbSetting(
          label: 'Confirmation message',
          child: UiInput(size: UiSize.sm, value: r.confirm ?? '', placeholder: 'e.g. Start this application over?', semanticLabel: 'Confirmation message', onChanged: (v) => patch({'confirm': v.isEmpty ? null : v}, 'confirm')),
        ),
        FbSetting(
          label: 'Remarks',
          child: WfSelect(
            label: 'Remarks',
            value: r.comment?.name ?? '',
            options: const [(value: '', label: 'Optional (default)'), (value: 'required', label: 'Required'), (value: 'none', label: 'Not asked')],
            onChanged: (v) => patch({'comment': v.isEmpty ? null : v}),
          ),
        ),
      ]),
      WfSection(title: 'What else happens', children: [
        FbSwitch(value: r.cancelAutomations, label: 'Also stop other workflows running about the record', onChanged: (on) => patch({'cancelAutomations': on ? null : false})),
        FbSwitch(value: r.runExitEnter, label: 'Run the state\'s “on leaving” and the start\'s “on entering” steps', onChanged: (on) => patch({'runExitEnter': on ? true : null})),
      ]),
    ]);
  }
}

/// The state whose "onwards" set is exactly what is ticked, if any (so the From picker shows it).
String _fromState(UiWorkflowDefinition def, List<String> ticked) {
  if (ticked.isEmpty) return '';
  final want = ({...ticked}.toList()..sort()).join(',');
  for (final x in def.lifecycle?.states ?? const <UiWfState>[]) {
    if ((wfStatesFrom(def, x.id).toList()..sort()).join(',') == want) return x.id;
  }
  return '';
}

/// The settings panel: settings for whatever is selected, with a short header and its problems
/// (the web `ui-wf-inspector`).
class WfInspector extends StatelessWidget {
  const WfInspector({super.key, this.showHead = true, this.onDeleteRequest, this.scrollController});

  /// The header (icon, name, delete); off inside a bottom sheet, which has its own title.
  final bool showHead;
  final VoidCallback? onDeleteRequest;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = WfBuilderScope.of(context).store;
    final sel = store.selection;
    final kind = sel?.kind ?? 'workflow';
    final heading = switch (kind) {
      'step' => store.selectedStep != null ? stepName(store.selectedStep!) : 'Step',
      'trigger' => 'What starts it',
      'state' => store.selectedState?.label ?? 'State',
      'transition' => store.selectedTransition?.label ?? 'Transition',
      'reset' => store.def.lifecycle?.reset?.label ?? 'Reset workflow',
      _ => store.def.kind == 'lifecycle' ? 'Lifecycle settings' : 'Workflow settings',
    };
    final icon = switch (kind) {
      'step' => wfStepIcon(store.selectedStep?.type ?? ''),
      'trigger' => WfIcons.flash,
      'state' => WfIcons.flag01,
      'transition' => WfIcons.arrowRight02,
      'reset' => WfIcons.refresh,
      _ => WfIcons.settings02,
    };
    final canDelete = const ['step', 'state', 'transition', 'reset'].contains(kind);
    // Reset problems have no node of their own; they show with the workflow's.
    final problems = store.problemsOf(sel == null || kind == 'workflow' || kind == 'trigger' || kind == 'reset' ? null : sel.id);

    // For a step inside a lifecycle run: the state or transition it belongs to.
    UiWfSelection? parent;
    String? parentLabel;
    if (kind == 'step') {
      final root = store.steps[sel!.id]?.path.firstOrNull;
      if (root == 'reset') {
        final reset = store.def.lifecycle?.reset;
        if (reset != null) (parent, parentLabel) = (UiWfSelection.reset, reset.label ?? 'Reset workflow');
      } else if (root != null && root != 'root') {
        final i = root.indexOf(':');
        final k = root.substring(0, i), id = root.substring(i + 1);
        final lc = store.def.lifecycle;
        if (k == 'transition') {
          final tr = lc?.transitions.where((x) => x.id == id).firstOrNull;
          if (tr != null) (parent, parentLabel) = (UiWfSelection.transition(id), tr.label);
        } else {
          final st = lc?.states.where((x) => x.id == id).firstOrNull;
          if (st != null) (parent, parentLabel) = (UiWfSelection.state(id), st.label);
        }
      }
    }

    final Widget editor = switch (kind) {
      'step' => store.selectedStep != null ? WfStepEditor(key: ValueKey(store.selectedStep!.id), step: store.selectedStep!) : const SizedBox.shrink(),
      // Keyed by the workflow: a custom schedule chosen in one isn't carried into the next.
      'trigger' => WfTriggerEditor(key: ValueKey('trigger-${store.def.id}')),
      'state' => WfStateEditor(key: ValueKey(sel!.id)),
      'transition' => WfTransitionEditor(key: ValueKey(sel!.id)),
      'reset' => const WfResetEditor(),
      _ => const WfWorkflowEditor(),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (showHead)
        Container(
          padding: EdgeInsets.fromLTRB(t.space3, t.space3, t.space3, t.space2),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.borderSubtle))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2, children: [
            if (parent != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FbLink(label: '‹ $parentLabel', fontSize: 12, onTap: () => store.selection = parent),
              ),
            Row(spacing: t.space2, children: [
              WfIconTile(icon, color: t.primary, size: 24, iconSize: 15),
              Expanded(child: Semantics(header: true, child: Text(heading, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.label.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: t.text)))),
              if (canDelete && !store.readOnly) FbIconButton(icon: WfIcons.delete02, label: 'Delete $heading', danger: true, onPressed: onDeleteRequest),
            ]),
          ]),
        ),
      Expanded(
        child: SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.all(t.space3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // In a bottom sheet (no header) the way back to the parent and Delete still have to be
            // somewhere: a small row above the settings.
            if (!showHead && (parent != null || (canDelete && !store.readOnly)))
              Padding(
                padding: EdgeInsets.only(bottom: t.space2),
                child: Row(spacing: t.space2, children: [
                  if (parent != null) FbLink(label: '‹ $parentLabel', fontSize: 12, onTap: () => store.selection = parent),
                  const Spacer(),
                  if (canDelete && !store.readOnly) FbIconButton(icon: WfIcons.delete02, label: 'Delete $heading', danger: true, onPressed: onDeleteRequest),
                ]),
              ),
            if (problems.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: t.space3),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: [
                  for (final p in problems)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: (p.isError ? t.danger : t.warning).withValues(alpha: p.isError ? 0.10 : 0.12),
                        border: Border(left: BorderSide(color: p.isError ? t.danger : t.warning, width: 3)),
                        borderRadius: BorderRadius.circular(t.radiusXs),
                      ),
                      child: Text(p.message, style: context.uiText.body.copyWith(fontSize: 12.5, height: 1.4, color: t.text)),
                    ),
                ]),
              ),
            WfReadOnly(readOnly: store.readOnly, child: editor),
          ]),
        ),
      ),
    ]);
  }
}
