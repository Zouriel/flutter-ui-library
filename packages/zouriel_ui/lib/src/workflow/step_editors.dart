import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../core/types.dart';
import '../forms/text/inputs.dart';
import '../forms/text/number_input.dart';
import '../theme/theme.dart';
import 'bits.dart';
import 'definition.dart';
import 'editors.dart';
import 'icons.dart';
import 'json.dart';
import 'schema.dart';
import 'scope.dart';

const List<WfOption> _tones = [
  (value: 'neutral', label: 'neutral'), (value: 'primary', label: 'primary'), (value: 'success', label: 'success'), (value: 'warning', label: 'warning'), (value: 'danger', label: 'danger'),
];
const List<String> _methods = ['POST', 'PUT', 'PATCH', 'GET', 'DELETE'];

/// Settings for one step (the web `ui-wf-step-editor`). Each step type gets its own section;
/// common settings (name, deadlines, what happens on failure, a note) come around it.
class WfStepEditor extends StatefulWidget {
  const WfStepEditor({super.key, required this.step});
  final UiWfStep step;

  @override
  State<WfStepEditor> createState() => _WfStepEditorState();
}

class _WfStepEditorState extends State<WfStepEditor> {
  bool _bodyInvalid = false;
  String? _bodyDraft;

  /// The webhook body the draft goes with (as JSON): the body it wrote, or for text that isn't
  /// JSON yet the body that was there. When the step's body is something else (undo, redo), the
  /// draft is dropped and the step's own body shows.
  String? _bodyDraftOf;

  static String _bodyKey(UiWfStep step) {
    final w = UiWfWebhookStep.of(step);
    return w.hasBody ? jsonEncode(w.body) : '';
  }

  @override
  void didUpdateWidget(WfStepEditor old) {
    super.didUpdateWidget(old);
    if (old.step.id != widget.step.id || (_bodyDraft != null && widget.step.type == 'webhook' && _bodyKey(widget.step) != _bodyDraftOf)) {
      _bodyInvalid = false;
      _bodyDraft = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final ctx = WfBuilderScope.of(context);
    final store = ctx.store;
    final step = widget.step;
    final tokens = store.tokens(UiWfAt.step(step.id));
    final defaultName = stepInfo(step.type).label;

    void patch(UiJson p, [String? mergeKey]) => store.updateStep(step.id, p, mergeKey: mergeKey == null ? null : '${step.id}:$mergeKey');

    Widget field(String label, Widget child) => FbSetting(label: label, child: child);
    Widget del(String label, VoidCallback? onPressed) => FbIconButton(icon: WfIcons.delete02, label: label, danger: true, onPressed: onPressed);
    Widget sw(bool value, String label, ValueChanged<bool> onChanged) => FbSwitch(value: value, label: label, onChanged: onChanged);
    WfAssigneesEditor people(List<UiWfAssignee> value, String label, String emptyText, ValueChanged<List<UiWfAssignee>> onChanged, {bool allowEmail = false, bool managers = false}) => WfAssigneesEditor(
      value: value,
      registry: store.registry,
      tokens: tokens,
      api: store.api,
      label: label,
      emptyText: emptyText,
      allowEmail: allowEmail,
      allowManagerOfAssignees: managers,
      onChanged: onChanged,
    );

    final children = <Widget>[
      field('Name', UiInput(size: UiSize.sm, value: step.title ?? '', placeholder: defaultName, semanticLabel: 'Name', onChanged: (v) => patch({'title': v.isEmpty ? null : v}, 'title'))),
      ..._typeSection(context, step, tokens, patch, field, del, sw, people),
    ];

    // Approval and task: deadline, reminders, escalation, what they see.
    if (step.type == 'approval' || step.type == 'task') {
      final h = UiWfHumanStep.of(step);
      final reminders = h.reminders ?? const <String>[];
      final esc = h.escalation;
      children.add(WfSection(title: 'Deadline and reminders', children: [
        field('Due within', WfDurationInput(value: h.due, label: 'Due', onChanged: (v) => patch({'due': v}))),
        sw(h.calendar == 'working', 'Count working time only', (on) => patch({'calendar': on ? 'working' : null})),
        FbSetting(
          label: 'Reminders',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: [
            for (var i = 0; i < reminders.length; i++)
              Row(children: [
                Expanded(child: WfDurationInput(value: reminders[i], label: 'Reminder', onChanged: (v) => patch({'reminders': [...reminders]..[i] = v}))),
                del('Remove reminder', () {
                  final r = [...reminders]..removeAt(i);
                  patch({'reminders': r.isEmpty ? null : r});
                }),
              ]),
            Align(alignment: AlignmentDirectional.centerStart, child: FbLink(label: 'Add a reminder', onTap: () => patch({'reminders': [...reminders, 'P1D']}))),
          ]),
        ),
        sw(esc != null, 'Escalate if nobody decides', (on) => patch({
          'escalation': on ? {'after': h.due.isNotEmpty ? h.due : 'P2D', 'assignees': [UiWfAssignee.managerOf('assignees')]} : null,
        })),
        if (esc != null) ...[
          field('After', WfDurationInput(value: esc.after, label: 'Escalate after', onChanged: (v) => patch({'escalation': {...esc.json, 'after': v}}))),
          field('Also give it to', people(esc.assignees, 'escalation', '', (v) => patch({'escalation': {...esc.json, 'assignees': v}}), managers: true)),
        ],
        sw(h.allowDelegation, 'Allow handing it to someone else', (on) => patch({'allowDelegation': on ? true : null})),
      ]));
      children.add(WfSection(title: 'What they see', children: [
        field(
          'Instructions',
          WfTemplateEditor(tokens: tokens, value: h.instructions, label: 'Instructions', onChanged: (v) => patch({'instructions': v.isEmpty ? null : v.json}, 'instructions')),
        ),
        field(
          'Questions to answer',
          WfFormField(value: h.form, title: '${(step.title ?? '').isNotEmpty ? step.title : defaultName} form', addLabel: 'Add questions (a form)', onChanged: (f) => patch({'form': f})),
        ),
      ]));
    }

    // Steps that call out: retries and what happens on failure.
    if (const ['action', 'webhook', 'subWorkflow'].contains(step.type)) {
      final retry = step.retry;
      final max = retry?.max ?? 0;
      final onError = step.onError;
      final mode = onError == null ? 'stop' : (onError is String ? onError : 'steps');
      children.add(WfSection(title: 'If it fails', children: [
        FbPair(children: [
          field(
            'Try again',
            UiNumberInput(
              size: UiSize.sm,
              value: max,
              min: 0,
              max: 10,
              suffix: 'times',
              semanticLabel: 'Try again',
              onChanged: (v) {
                final n = (v ?? 0).toInt();
                patch({'retry': n > 0 ? {...(retry?.json ?? {'initial': 'PT1M', 'backoff': 'exponential'}), 'max': n} : null});
              },
            ),
          ),
          if (max > 0)
            field('First wait', WfDurationInput(value: retry?.initial ?? 'PT1M', label: 'Retry delay', onChanged: (v) => patch({'retry': {...retry!.json, 'initial': v, 'backoff': 'exponential'}}))),
        ]),
        field(
          'Then',
          WfSelect(
            label: 'Then',
            value: mode,
            options: const [(value: 'stop', label: 'Stop and tell an admin'), (value: 'continue', label: 'Carry on with the next step'), (value: 'steps', label: 'Run other steps')],
            onChanged: (m) => patch({
              'onError': m == 'continue' ? 'continue' : m == 'steps' ? {'steps': step.onErrorSteps ?? <UiWfStep>[]} : null,
            }),
          ),
        ),
      ]));
    }

    children.add(WfSection(children: [
      field(
        'Note (only builders see it)',
        UiTextarea(value: step.note ?? '', rows: 2, autosize: true, semanticLabel: 'Note', onChanged: (v) => patch({'note': v.isEmpty ? null : v}, 'note')),
      ),
    ]));
    return WfStack(spacing: t.space3, children: children);
  }

  List<Widget> _typeSection(
    BuildContext context,
    UiWfStep step,
    List<UiWfToken> tokens,
    void Function(UiJson p, [String? mergeKey]) patch,
    Widget Function(String, Widget) field,
    Widget Function(String, VoidCallback?) del,
    Widget Function(bool, String, ValueChanged<bool>) sw,
    WfAssigneesEditor Function(List<UiWfAssignee>, String, String, ValueChanged<List<UiWfAssignee>>, {bool allowEmail, bool managers}) people,
  ) {
    final t = context.ui;
    final store = WfBuilderScope.of(context).store;
    final reg = store.registry;
    Widget box(List<Widget> children) => Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: t.borderSubtle), borderRadius: BorderRadius.circular(t.radius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 6, children: children),
    );
    Widget link(String label, VoidCallback onTap) => Align(alignment: AlignmentDirectional.centerStart, child: FbLink(label: label, onTap: onTap));
    List<String> splitList(String text) => text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    switch (step.type) {
      case 'approval':
        final a = UiWfApprovalStep.of(step);
        final rt = a.ruleType;
        return [
          field('Who approves', people(a.assignees, 'approvers', 'Add the people who decide.', (v) => patch({'assignees': v}))),
          FbPair(children: [
            field(
              'Decided when',
              WfSelect(
                label: 'Decided when',
                value: rt,
                options: const [(value: 'any', label: 'Anyone approves'), (value: 'all', label: 'Everyone approves'), (value: 'count', label: 'A number approve'), (value: 'percent', label: 'A share approve')],
                onChanged: (type) => patch({'rule': type == 'count' || type == 'percent' ? {'type': type, 'value': type == 'percent' ? 50 : 2} : {'type': type}}),
              ),
            ),
            if (rt == 'count' || rt == 'percent')
              field(
                rt == 'count' ? 'How many' : 'Percent',
                UiNumberInput(size: UiSize.sm, value: a.ruleValue ?? 1, min: 1, max: rt == 'percent' ? 100 : null, semanticLabel: rt == 'count' ? 'How many' : 'Percent', onChanged: (v) => patch({'rule': {'type': rt, 'value': v ?? 1}})),
              ),
          ]),
          const FbHint('Anyone: the first approval wins. Everyone: one rejection rejects it.'),
          field(
            'Remarks',
            WfSelect(
              label: 'Remarks',
              value: a.requireComment == null || a.requireComment == 'never' ? 'never' : a.requireComment,
              options: const [(value: 'never', label: 'Optional'), (value: 'reject', label: 'Required to reject'), (value: 'always', label: 'Always required')],
              onChanged: (v) => patch({'requireComment': v}),
            ),
          ),
          const FbHint('People can always add remarks; they show in the history and later steps can read them.'),
        ];
      case 'task':
        final tk = UiWfTaskStep.of(step);
        final outs = tk.outcomes;
        return [
          field('Who does it', people(tk.assignees, 'people', 'Add the person or people who decide.', (v) => patch({'assignees': v}))),
          FbSetting(
            label: 'Buttons (what they can choose)',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: [
              for (var i = 0; i < outs.length; i++)
                Row(spacing: 6, children: [
                  Expanded(child: UiInput(size: UiSize.sm, value: outs[i].label, semanticLabel: 'Button ${i + 1}', onChanged: (v) => patch({'outcomes': [...outs]..[i] = outs[i].patch({'label': v})}, 'outcome$i'))),
                  SizedBox(width: 104, child: WfSelect(label: 'Colour', value: outs[i].tone ?? 'neutral', options: _tones, onChanged: (v) => patch({'outcomes': [...outs]..[i] = outs[i].patch({'tone': v})}))),
                  del('Remove button', outs.length < 2 ? null : () => patch({'outcomes': [...outs]..removeAt(i)})),
                ]),
              if (outs.length < 8)
                link('Add a button', () {
                  final label = 'Option ${outs.length + 1}';
                  patch({'outcomes': [...outs, {'id': wfId('o'), 'key': wfKey(label, outs.map((o) => o.key)), 'label': label, 'steps': <Object?>[]}]});
                }),
            ]),
          ),
          field(
            'Remarks',
            WfSelect(
              label: 'Remarks',
              value: tk.requireComment == null || tk.requireComment == 'never' ? 'never' : tk.requireComment,
              options: const [(value: 'never', label: 'Optional'), (value: 'reject', label: 'Required for red buttons'), (value: 'always', label: 'Always required')],
              onChanged: (v) => patch({'requireComment': v}),
            ),
          ),
          if (tk.requireComment == 'reject' && !outs.any((o) => o.tone == 'danger'))
            const FbHint('No button is red yet: colour the negative ones “danger” so they ask for remarks.'),
        ];
      case 'branch':
        final b = UiWfBranchStep.of(step);
        final paths = b.paths;
        return [
          for (var i = 0; i < paths.length; i++)
            box([
              Row(children: [
                Expanded(child: UiInput(size: UiSize.sm, value: paths[i].label, semanticLabel: 'Path ${i + 1} name', onChanged: (v) => patch({'paths': [...paths]..[i] = paths[i].patch({'label': v})}, 'path$i'))),
                del('Remove path', paths.length < 2 ? null : () => patch({'paths': [...paths]..removeAt(i)})),
              ]),
              WfConditionEditor(value: paths[i].when, tokens: tokens, emptyText: 'Add a condition for this path.', onChanged: (c) => patch({'paths': [...paths]..[i] = paths[i].patch({'when': c.json})})),
            ]),
          Wrap(spacing: t.space3, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            FbLink(label: 'Add a path', onTap: () => patch({'paths': [...paths, {'id': wfId('p'), 'label': 'Path ${paths.length + 1}', 'when': {'match': 'all', 'conditions': <Object?>[]}, 'steps': <Object?>[]}]})),
            sw(b.otherwise != null, 'Otherwise path', (on) => patch({'otherwise': on ? {'id': wfId('l'), 'label': 'Otherwise', 'steps': <Object?>[]} : null})),
          ]),
          const FbHint('The first path whose conditions hold runs; if none do, “Otherwise”.'),
        ];
      case 'switch':
        final sw0 = UiWfSwitchStep.of(step);
        final cases = sw0.cases;
        final token = tokens.where((x) => x.path == sw0.on).firstOrNull;
        return [
          field('Switch on', WfTokenSelect(tokens: tokens, value: sw0.on, label: 'Switch on', onChanged: (v) => patch({'on': v}))),
          for (var i = 0; i < cases.length; i++)
            box([
              Row(children: [
                Expanded(child: UiInput(size: UiSize.sm, value: cases[i].label, semanticLabel: 'Case ${i + 1} name', onChanged: (v) => patch({'cases': [...cases]..[i] = cases[i].patch({'label': v})}, 'case$i'))),
                del('Remove case', cases.length < 2 ? null : () => patch({'cases': [...cases]..removeAt(i)})),
              ]),
              if (token?.options?.isNotEmpty ?? false)
                WfChecks(
                  label: 'Values',
                  options: [for (final o in token!.options!) (value: jsString(o.value), label: o.label)],
                  isChecked: (v) => cases[i].values.map(jsString).contains(v),
                  onChanged: (v, on) {
                    final opt = token.options!.firstWhere((o) => jsString(o.value) == v).value;
                    final rest = cases[i].values.where((x) => jsString(x) != v).toList();
                    patch({'cases': [...cases]..[i] = cases[i].patch({'values': on ? [...rest, opt] : rest})}, 'case$i');
                  },
                )
              else
                UiInput(
                  size: UiSize.sm,
                  value: cases[i].values.map(jsString).join(', '),
                  placeholder: 'Values, separated by commas',
                  semanticLabel: 'Values',
                  onChanged: (v) => patch({'cases': [...cases]..[i] = cases[i].patch({'values': splitList(v)})}, 'case$i'),
                ),
            ]),
          Wrap(spacing: t.space3, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            FbLink(label: 'Add a case', onTap: () => patch({'cases': [...cases, {'id': wfId('c'), 'label': 'Case ${cases.length + 1}', 'values': <Object?>[], 'steps': <Object?>[]}]})),
            sw(sw0.otherwise != null, 'Otherwise path', (on) => patch({'otherwise': on ? {'id': wfId('l'), 'label': 'Otherwise', 'steps': <Object?>[]} : null})),
          ]),
        ];
      case 'parallel':
        final p = UiWfParallelStep.of(step);
        final paths = p.paths;
        return [
          for (var i = 0; i < paths.length; i++)
            Row(children: [
              Expanded(child: UiInput(size: UiSize.sm, value: paths[i].label ?? '', semanticLabel: 'Path ${i + 1} name', onChanged: (v) => patch({'paths': [...paths]..[i] = UiWfStepList.fromJson({...paths[i].json, 'label': v})}, 'ppath$i'))),
              del('Remove path', paths.length < 3 ? null : () => patch({'paths': [...paths]..removeAt(i)})),
            ]),
          if (paths.length < 10) link('Add a path', () => patch({'paths': [...paths, {'id': wfId('p'), 'label': 'Path ${paths.length + 1}', 'steps': <Object?>[]}]})),
          FbPair(children: [
            field(
              'Continue when',
              WfSelect(
                label: 'Continue when',
                value: p.joinType,
                options: const [(value: 'all', label: 'All paths finish'), (value: 'any', label: 'The first path finishes'), (value: 'count', label: 'A number of paths finish')],
                onChanged: (v) => patch({'join': wfCompact({'type': v, 'count': p.joinCount})}),
              ),
            ),
            if (p.joinType == 'count')
              field('How many', UiNumberInput(size: UiSize.sm, value: p.joinCount ?? 1, min: 1, max: paths.length, semanticLabel: 'How many', onChanged: (v) => patch({'join': {'type': 'count', 'count': v ?? 1}}))),
          ]),
          if (p.joinType != 'all') const FbHint('Paths still running are stopped (their tasks are cancelled).'),
        ];
      case 'forEach':
        final fe = UiWfForEachStep.of(step);
        return [
          field(
            'For each of',
            WfSelect(
              label: 'For each of',
              placeholder: 'Choose a list…',
              value: fe.collection,
              options: [for (final c in collectionsOf(reg, store.def.entity)) (value: c.path, label: c.label)],
              onChanged: (v) => patch({'collection': v}),
            ),
          ),
          field('Only items where', WfConditionEditor(value: fe.when, tokens: tokens, emptyText: 'Every item.', onChanged: (c) => patch({'when': c.conditions.isNotEmpty ? c.json : null}))),
          FbPair(children: [
            field(
              'One at a time?',
              WfSelect(
                label: 'One at a time?',
                value: fe.mode == 'parallel' ? 'parallel' : 'sequential',
                options: const [(value: 'sequential', label: 'One after another'), (value: 'parallel', label: 'At the same time')],
                onChanged: (v) => patch({'mode': v}),
              ),
            ),
            field('At most', UiNumberInput(size: UiSize.sm, value: fe.max, min: 1, max: 500, suffix: 'items', semanticLabel: 'At most', onChanged: (v) => patch({'max': v ?? 100}))),
          ]),
        ];
      case 'wait':
        final u = UiWfWaitStep.of(step).until;
        void setUntil(UiJson p) => patch({'until': wfPatch(u.json, p)});
        final signals = reg?.signals ?? const <UiWfSignalDescriptor>[];
        return [
          field(
            'Wait',
            WfSelect(
              label: 'Wait',
              value: u.type,
              options: const [
                (value: 'duration', label: 'For a length of time'),
                (value: 'date', label: 'Until a date'),
                (value: 'condition', label: 'Until something is true'),
                (value: 'signal', label: 'Until the app reports an event'),
              ],
              onChanged: (type) => patch({
                'until': switch (type) {
                  'duration' => {'type': type, 'duration': 'P1D'},
                  'date' => {'type': type, 'date': {'ref': ''}},
                  'condition' => {'type': type, 'when': {'match': 'all', 'conditions': <Object?>[]}, 'timeout': 'P7D', 'onTimeout': {'id': wfId('l'), 'steps': <Object?>[]}},
                  _ => {'type': type, 'signal': signals.firstOrNull?.key ?? ''},
                },
              }),
            ),
          ),
          if (u.type == 'duration') ...[
            WfDurationInput(value: u.duration, label: 'How long', onChanged: (v) => setUntil({'duration': v})),
            sw(u.calendar == 'working', 'Count working time only', (on) => setUntil({'calendar': on ? 'working' : null})),
          ],
          if (u.type == 'date') ...[
            field('The date', WfTokenSelect(tokens: tokens, types: const ['date', 'dateTime'], value: u.date?.ref, label: 'The date', onChanged: (v) => setUntil({'date': {'ref': v}}))),
            field('Shift it', WfDurationInput(value: u.offset ?? 'P0D', signed: true, label: 'Offset', onChanged: (v) => setUntil({'offset': v == 'P0D' ? null : v}))),
          ],
          if (u.type == 'condition') ...[
            WfConditionEditor(value: u.when, tokens: tokens, emptyText: 'Add the condition to wait for.', onChanged: (c) => setUntil({'when': c.json})),
            field('Give up after', WfDurationInput(value: u.timeout, label: 'Time limit', onChanged: (v) => setUntil({'timeout': v}))),
            const FbHint('Checked again whenever the record changes.'),
          ],
          if (u.type == 'signal') ...[
            field('Event', WfSelect(label: 'Event', placeholder: 'Choose…', value: u.signal, options: [for (final s in signals) (value: s.key, label: s.label)], onChanged: (v) => setUntil({'signal': v}))),
            sw((u.timeout ?? '').isNotEmpty, 'Give up after a while', (on) => setUntil(on ? {'timeout': 'P7D', 'onTimeout': {'id': wfId('l'), 'steps': <Object?>[]}} : {'timeout': null, 'onTimeout': null})),
            if ((u.timeout ?? '').isNotEmpty) WfDurationInput(value: u.timeout, label: 'Time limit', onChanged: (v) => setUntil({'timeout': v})),
          ],
        ];
      case 'setFields':
        final sf = UiWfSetFieldsStep.of(step);
        final entity = store.entity;
        final relations = [for (final f in entity?.fields ?? const <UiWfFieldDescriptor>[]) if (f.type == 'relation' && f.entity != null) f];
        final target = sf.target;
        final targetEntity = target == null || target == 'self' ? store.def.entity : fieldOf(reg, store.def.entity, target.split('.').elementAtOrNull(1))?.entity;
        final settable = [for (final f in entityOf(reg, targetEntity)?.fields ?? const <UiWfFieldDescriptor>[]) if (f.settable) f];
        final values = sf.values;
        return [
          field(
            'Record',
            WfSelect(
              label: 'Record',
              value: target == null || target == 'self' ? 'self' : target,
              options: [(value: 'self', label: 'This ${entity?.label.toLowerCase() ?? 'record'}'), for (final r in relations) (value: 'entity.${r.key}', label: r.label)],
              onChanged: (v) => patch({'target': v == 'self' ? null : v, 'values': <Object?>[]}),
            ),
          ),
          for (var i = 0; i < values.length; i++)
            _Assign(
              first: WfSelect(
                label: 'Field ${i + 1}',
                placeholder: 'Field…',
                value: values[i].field,
                options: [for (final f in settable) (value: f.key, label: f.label)],
                onChanged: (f) => patch({'values': [...values]..[i] = UiWfFieldValue.fromJson({'field': f, 'value': {'const': null}})}),
              ),
              second: WfOperandEditor(
                value: values[i].value,
                field: fieldOf(reg, targetEntity, values[i].field),
                tokens: tokens,
                label: fieldOf(reg, targetEntity, values[i].field)?.label ?? 'Value',
                onChanged: (v) => patch({'values': [...values]..[i] = UiWfFieldValue.fromJson({...values[i].json, 'value': v.json})}, 'value$i'),
              ),
              remove: del('Remove', () => patch({'values': [...values]..removeAt(i)})),
            ),
          if (settable.isNotEmpty)
            link('Change another field', () => patch({'values': [...values, {'field': '', 'value': {'const': null}}]}))
          else
            const FbHint('The app hasn’t allowed workflows to change any field of this record.'),
        ];
      case 'createRecord':
        final cr = UiWfCreateRecordStep.of(step);
        final kind = cr.entity.isEmpty ? null : cr.entity;
        // A new record's lifecycle-controlled field starts in its first state, so it isn't offered
        // when this workflow or a published lifecycle controls a field of that kind of record.
        final lifecycleOn = kind != null &&
            ((store.def.kind == 'lifecycle' && store.def.entity == kind) || store.others.any((o) => o.kind == 'lifecycle' && o.entity == kind && o.version > 0));
        final settable = [
          for (final f in entityOf(reg, kind)?.fields ?? const <UiWfFieldDescriptor>[])
            if (f.settable && !(f.lifecycle && lifecycleOn)) f,
        ];
        // The chosen kind is not in the registry any more (once the registry is known).
        final unknownKind = kind != null && reg != null && entityOf(reg, kind) == null;
        final values = cr.values;
        return [
          field(
            'Kind of record',
            WfSelect(
              label: 'Kind of record',
              placeholder: 'Choose…',
              value: cr.entity,
              options: [for (final e in reg?.entities ?? const <UiWfEntityDescriptor>[]) (value: e.key, label: e.label)],
              onChanged: (v) => patch({'entity': v, 'values': <Object?>[]}),
            ),
          ),
          if (kind != null) ...[
            for (var i = 0; i < values.length; i++)
              _Assign(
                first: WfSelect(
                  label: 'Field ${i + 1}',
                  placeholder: 'Field…',
                  value: values[i].field,
                  options: [for (final f in settable) (value: f.key, label: f.label)],
                  onChanged: (f) => patch({'values': [...values]..[i] = UiWfFieldValue.fromJson({'field': f, 'value': {'const': null}})}),
                ),
                second: WfOperandEditor(
                  value: values[i].value,
                  field: fieldOf(reg, kind, values[i].field),
                  tokens: tokens,
                  label: fieldOf(reg, kind, values[i].field)?.label ?? 'Value',
                  onChanged: (v) => patch({'values': [...values]..[i] = UiWfFieldValue.fromJson({...values[i].json, 'value': v.json})}, 'value$i'),
                ),
                remove: del('Remove', () => patch({'values': [...values]..removeAt(i)})),
              ),
            if (unknownKind)
              const FbHint('The app no longer offers this kind of record; choose another.')
            else if (settable.isNotEmpty)
              link('Set a field', () => patch({'values': [...values, {'field': '', 'value': {'const': null}}]}))
            else
              const FbHint('The app hasn’t allowed workflows to set any field of this kind of record.'),
            const FbHint('Later steps can read the new record’s id. Resetting the workflow offers to delete it again.'),
          ],
        ];
      case 'setVariables':
        final sv = UiWfSetVariablesStep.of(step);
        final vars = store.def.variables ?? const <UiWfVariable>[];
        final values = sv.values;
        return [
          for (var i = 0; i < values.length; i++)
            _Assign(
              first: WfSelect(
                label: 'Variable ${i + 1}',
                placeholder: 'Variable…',
                value: values[i].variable,
                options: [for (final x in vars) (value: x.id, label: x.label)],
                onChanged: (v) => patch({'values': [...values]..[i] = UiWfVariableValue.fromJson({...values[i].json, 'variable': v})}),
              ),
              second: WfOperandEditor(
                value: values[i].value,
                type: vars.where((x) => x.id == values[i].variable).firstOrNull?.type,
                tokens: tokens,
                onChanged: (v) => patch({'values': [...values]..[i] = UiWfVariableValue.fromJson({...values[i].json, 'value': v.json})}, 'var$i'),
              ),
              remove: del('Remove', () => patch({'values': [...values]..removeAt(i)})),
            ),
          if (vars.isNotEmpty)
            link('Set another variable', () => patch({'values': [...values, {'variable': '', 'value': {'const': null}}]}))
          else
            const FbHint('Add variables in the workflow’s settings first.'),
        ];
      case 'applyTransition':
        final at = UiWfApplyTransitionStep.of(step);
        final def = store.def;
        final lifecycles = <WfOption>[
          if (def.kind == 'lifecycle') (value: def.key, label: '${def.title} (this one)'),
          for (final o in store.others)
            if (o.kind == 'lifecycle' && o.key != def.key && o.version > 0) (value: o.key, label: o.title),
        ];
        return [
          field('Lifecycle', WfSelect(label: 'Lifecycle', placeholder: 'Choose…', value: at.lifecycle, options: lifecycles, onChanged: (v) => patch({'lifecycle': v, 'transition': ''}))),
          field('Transition (key)', UiInput(size: UiSize.sm, value: at.transition, placeholder: 'e.g. approve', semanticLabel: 'Transition (key)', onChanged: (v) => patch({'transition': v}, 'transition'))),
          field(
            'If it isn’t possible',
            WfSelect(
              label: 'If it isn’t possible',
              value: at.ifNotAllowed == 'skip' ? 'skip' : 'fail',
              options: const [(value: 'fail', label: 'Stop with an error'), (value: 'skip', label: 'Skip it and carry on')],
              onChanged: (v) => patch({'ifNotAllowed': v}),
            ),
          ),
        ];
      case 'notify':
        final n = UiWfNotifyStep.of(step);
        return [
          field('Send by', WfSelect(label: 'Send by', value: n.channel, options: [for (final c in reg?.channels ?? const <UiWfLabelled>[]) (value: c.key, label: c.label)], onChanged: (v) => patch({'channel': v}))),
          field('To', people(n.to, 'recipients', 'Add who gets it.', (v) => patch({'to': v}), allowEmail: true)),
          field('Subject', WfTemplateEditor(tokens: tokens, value: n.subject, multiline: false, label: 'Subject', onChanged: (v) => patch({'subject': v.json}, 'subject'))),
          field(
            'Message',
            WfTemplateEditor(tokens: tokens, value: n.body, label: 'Message', placeholder: 'Write the message. Insert values from the record or earlier steps.', onChanged: (v) => patch({'body': v.json}, 'body')),
          ),
          sw(n.link?.json == 'record', 'Include a link to the record', (on) => patch({'link': on ? 'record' : null})),
        ];
      case 'webhook':
        final w = UiWfWebhookStep.of(step);
        final connections = store.settingsConnections;
        final text = _bodyDraft ?? (w.hasBody ? const JsonEncoder.withIndent('  ').convert(w.body) : '');
        return [
          if (connections.isNotEmpty)
            field(
              'Connection',
              WfSelect(
                label: 'Connection',
                value: w.connection ?? '',
                options: [(value: '', label: 'A web address'), for (final c in connections) (value: c.key, label: c.label)],
                onChanged: (k) => patch(k.isNotEmpty ? {'connection': k, 'url': null} : {'connection': null, 'url': ''}),
              ),
            ),
          Row(spacing: 6, crossAxisAlignment: CrossAxisAlignment.end, children: [
            SizedBox(width: 96, child: field('Method', WfSelect(label: 'Method', value: w.method, options: [for (final m in _methods) (value: m, label: m)], onChanged: (v) => patch({'method': v})))),
            if ((w.connection ?? '').isEmpty)
              Expanded(child: field('Address', UiInput(size: UiSize.sm, type: UiInputType.url, value: w.url ?? '', placeholder: 'https://…', semanticLabel: 'Address', onChanged: (v) => patch({'url': v}, 'url')))),
          ]),
          field('Path', WfTemplateEditor(tokens: tokens, value: w.path, multiline: false, label: 'Path', placeholder: '/orders/', onChanged: (v) => patch({'path': v.isEmpty ? null : v.json}, 'path'))),
          field(
            'Body (JSON; use {"ref": "entity.title"} for values)',
            UiTextarea(
              value: text,
              rows: 5,
              invalid: _bodyInvalid,
              semanticLabel: 'Body',
              onChanged: (v) {
                if (v.trim().isEmpty) {
                  setState(() {
                    _bodyInvalid = false;
                    _bodyDraft = null;
                  });
                  patch({'body': null}, 'body');
                  return;
                }
                try {
                  final body = jsonDecode(v);
                  setState(() {
                    _bodyInvalid = false;
                    _bodyDraft = v;
                    _bodyDraftOf = jsonEncode(body);
                  });
                  patch({'body': body}, 'body');
                } catch (_) {
                  setState(() {
                    _bodyInvalid = true;
                    _bodyDraft = v;
                    _bodyDraftOf = _bodyKey(step);
                  });
                }
              },
            ),
          ),
          if (_bodyInvalid) const WfNote('That isn’t valid JSON yet.'),
          const FbHint('Only addresses allowed in the workflow settings can be called.'),
        ];
      case 'action':
        final a = UiWfActionStep.of(step);
        final actionDef = reg?.actions?.where((x) => x.key == a.action).firstOrNull;
        final input = a.input ?? const <String, UiWfOperand>{};
        return [
          field(
            'Action',
            WfSelect(
              label: 'Action',
              placeholder: 'Choose…',
              value: a.action,
              options: [for (final x in reg?.actions ?? const <UiWfActionDescriptor>[]) (value: x.key, label: '${x.category != null ? '${x.category} › ' : ''}${x.label}')],
              onChanged: (v) => patch({'action': v, 'input': <String, Object?>{}}),
            ),
          ),
          if (actionDef != null) ...[
            if ((actionDef.description ?? '').isNotEmpty) FbHint(actionDef.description!),
            for (final p in actionDef.inputs)
              field(
                '${p.label}${p.required ? ' *' : ''}',
                WfOperandEditor(
                  value: input[p.key],
                  type: p.type,
                  field: p.options != null ? UiWfFieldDescriptor.fromJson({'key': p.key, 'label': p.label, 'type': 'enum', 'options': [for (final o in p.options!) o.json]}) : null,
                  tokens: tokens,
                  label: p.label,
                  onChanged: (v) => patch({'input': {...?wfMapOrNull(a.json['input']), p.key: v.json}}, 'input:${p.key}'),
                ),
              ),
            if (actionDef.outputs.isNotEmpty) FbHint('Gives: ${actionDef.outputs.map((o) => o.label).join(', ')}'),
          ],
        ];
      case 'subWorkflow':
        final s = UiWfSubWorkflowStep.of(step);
        final def = store.def;
        return [
          field(
            'Workflow',
            WfSelect(
              label: 'Workflow',
              placeholder: 'Choose…',
              value: s.workflow,
              options: [
                for (final o in store.others)
                  if (o.kind == 'automation' && o.key != def.key && o.version > 0) (value: o.key, label: o.title),
              ],
              onChanged: (v) => patch({'workflow': v}),
            ),
          ),
          sw(s.wait, 'Wait for it to finish (and use its results)', (on) => patch({'wait': on})),
        ];
      case 'goTo':
        final g = UiWfGoToStep.of(step);
        return [
          field(
            'Go back to',
            WfSelect(
              label: 'Go back to',
              placeholder: 'Choose a step…',
              value: g.target,
              options: [for (final x in goToTargets(store.def, step.id)) (value: x.id, label: stepName(x))],
              onChanged: (v) => patch({'target': v}),
            ),
          ),
          field('At most', UiNumberInput(size: UiSize.sm, value: g.maxTimes, min: 1, max: 50, suffix: 'times', semanticLabel: 'At most', onChanged: (v) => patch({'maxTimes': v ?? 1}))),
          const FbHint('After that it carries on to the next step.'),
        ];
      case 'end':
        final e = UiWfEndStep.of(step);
        return [
          field(
            'End as',
            WfSelect(label: 'End as', value: e.result, options: const [(value: 'completed', label: 'Finished'), (value: 'failed', label: 'Failed')], onChanged: (v) => patch({'result': v})),
          ),
          field('Reason', WfTemplateEditor(tokens: tokens, value: e.reason, multiline: false, label: 'Reason', onChanged: (v) => patch({'reason': v.isEmpty ? null : v.json}, 'reason'))),
        ];
    }
    return const [];
  }
}

/// A field (or variable) and what it's set to, with a remove button; stacked when narrow (the web
/// `.assign` grid and its container query).
class _Assign extends StatelessWidget {
  const _Assign({required this.first, required this.second, required this.remove});
  final Widget first;
  final Widget second;
  final Widget remove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth <= 300) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 6, children: [
          Row(children: [Expanded(child: first), remove]),
          second,
        ]);
      }
      return Row(spacing: 6, children: [Expanded(flex: 8, child: first), Expanded(flex: 14, child: second), remove]);
    });
  }
}
