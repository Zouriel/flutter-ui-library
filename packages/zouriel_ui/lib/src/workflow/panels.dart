import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../button/button.dart';
import '../core/icon.dart';
import '../core/types.dart';
import '../dialog/modal.dart';
import '../forms/text/inputs.dart';
import '../theme/theme.dart';
import 'api.dart';
import 'bits.dart';
import 'definition.dart';
import 'editors.dart';
import 'icons.dart';
import 'json.dart';
import 'schema.dart';
import 'scope.dart';
import 'store.dart';

/// A bordered card with a small heading (the panels' `.card`).
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Container(
      padding: EdgeInsets.all(t.space3),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
        Semantics(header: true, child: Text(title, style: context.uiText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: t.text))),
        ...children,
      ]),
    );
  }
}

Widget _page(BuildContext context, double maxWidth, List<Widget> children) {
  final t = context.ui;
  return SingleChildScrollView(
    padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space4),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: children),
      ),
    ),
  );
}

/// Versions: what changed since publishing, publish with a note, earlier versions, roll back (the
/// web `ui-wf-versions`).
class WfVersions extends StatefulWidget {
  const WfVersions({super.key, required this.saved, this.onSynced, this.onLeftError});

  /// Whether the workflow has been saved to the engine (versions live there).
  final bool saved;

  /// The engine's draft now equals this definition (after publishing or rolling back).
  final ValueChanged<UiWorkflowDefinition>? onSynced;

  /// An error that arrived after the panel was left (a publish that failed once the person went
  /// back to Build), for the builder to show.
  final ValueChanged<String>? onLeftError;

  @override
  State<WfVersions> createState() => _WfVersionsState();
}

class _WfVersionsState extends State<WfVersions> {
  UiWfDefinitionDetail? _detail;
  List<String> _diff = const [];
  String _note = '';
  bool _busy = false;
  String _error = '';
  int? _seenVersion;
  UiWorkflowApi? _seenApi;

  /// Publishers' names by user id.
  final Map<String, String> _names = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = WfBuilderScope.of(context).store;
    if (store.api != null && widget.saved && (store.version != _seenVersion || store.api != _seenApi)) {
      _seenVersion = store.version;
      _seenApi = store.api;
      _refresh();
    }
  }

  @override
  void didUpdateWidget(WfVersions oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Saved for the first time while this is showing: the engine has versions to show now.
    if (!oldWidget.saved && widget.saved) {
      final store = WfBuilderScope.read(context).store;
      _seenVersion = store.version;
      _seenApi = store.api;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final store = WfBuilderScope.read(context).store;
    final api = store.api;
    if (api == null) return;
    try {
      final d = await api.definition(store.def.id);
      // The engine's own flag says whether anything is unpublished; the diff only explains what.
      final diff = d.summary.version > 0 && d.summary.hasDraftChanges ? await api.diff(d.summary.id) : const <String>[];
      if (mounted) {
        setState(() {
          _detail = d;
          _diff = diff;
        });
      }
      _loadNames(api, [for (final v in d.versions) ?v.publishedBy]);
    } catch (_) {
      if (mounted) setState(() => _detail = null);
    }
  }

  Future<void> _loadNames(UiWorkflowApi api, List<String> ids) async {
    final missing = {for (final id in ids) if (!_names.containsKey(id)) id};
    if (missing.isEmpty) return;
    for (final id in missing) {
      _names[id] = id;
    }
    final found = await Future.wait([for (final id in missing) api.user(id).catchError((Object _) => null)]);
    if (!mounted) return;
    setState(() {
      var i = 0;
      for (final id in missing) {
        _names[id] = found[i++]?.name ?? id;
      }
    });
  }

  Future<void> _askRollback(UiWorkflowApi api, UiWorkflowBuilderController store, int version) async {
    if (_busy) return;
    final ok = await showUiModal<bool>(
      context: context,
      title: 'Make version $version current?',
      size: UiModalSize.sm,
      builder: (ctx) => Text(
        'This publishes version $version again as a new version, and the draft becomes a copy of it. Edits not yet saved are replaced.',
        style: ctx.uiText.body.copyWith(fontSize: 14, height: 1.5, color: ctx.ui.text),
      ),
      footerBuilder: (ctx) => Row(mainAxisAlignment: MainAxisAlignment.end, spacing: ctx.ui.space2, children: [
        UiButton(label: 'Cancel', variant: UiButtonVariant.ghost, onPressed: () => Navigator.of(ctx).pop(false)),
        UiButton(label: 'Make current', onPressed: () => Navigator.of(ctx).pop(true)),
      ]),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await api.rollback(store.def.id, version);
      // The engine's draft is now the old version: show that, not the edits from before.
      final d = await api.definition(store.def.id);
      if (d.published != null) store.published = d.published;
      store.commit(d.draft);
      widget.onSynced?.call(d.draft);
    });
  }

  Future<void> _run(Future<void> Function() f) async {
    // One at a time: a double tap must not publish (or roll back, archive, restore) twice.
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await f();
      // Gone meanwhile (the person went back to Build): what was done stands, there's nothing to show.
      if (mounted) await _refresh();
    } catch (e) {
      final msg = e is UiWfApiError ? e.message : 'Something went wrong.';
      if (mounted) {
        setState(() => _error = msg);
      } else {
        widget.onLeftError?.call(msg);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = WfBuilderScope.of(context).store;
    final api = store.api;
    if (api == null) return _page(context, 720, [const FbHint('Connect an API (UiWorkflowHttpApi) to publish and see versions.')]);
    if (!widget.saved) return _page(context, 720, [const FbWarn(text: 'Save the workflow first; versions are kept by the engine.')]);
    final d = _detail;
    final current = d?.summary.version ?? 0;
    final errors = store.errorCount;
    return _page(context, 720, [
      _Card(title: 'Unpublished changes', children: [
        if (_diff.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final line in _diff) Text('•  $line', style: context.uiText.body.copyWith(fontSize: 13, height: 1.5, color: t.text)),
          ])
        else
          const FbHint('None. The draft matches the published version.'),
        FbSetting(
          label: 'What changed (kept with the version)',
          child: UiTextarea(size: UiSize.sm, value: _note, rows: 2, autosize: true, placeholder: 'e.g. Added a finance check for large amounts', semanticLabel: 'What changed', onChanged: (v) => setState(() => _note = v)),
        ),
        if (_error.isNotEmpty) WfNote(_error),
        Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          UiButton(
            label: 'Publish version ${current + 1}',
            size: UiSize.sm,
            onPressed: _busy || errors > 0
                ? null
                : () => _run(() async {
                    final def = store.def;
                    // Read now: the panel may be left (Build, Test) while this is on its way, and the
                    // rest must still happen: the published version updated and the host told.
                    final onSynced = widget.onSynced;
                    await api.saveDraft(def);
                    final s = await api.publish(def.id, note: _note.isEmpty ? null : _note);
                    if (mounted) setState(() => _note = '');
                    final pd = await api.definition(s.id);
                    if (pd.published != null) store.published = pd.published;
                    onSynced?.call(def);
                  }),
          ),
          if (errors > 0) FbHint('Fix $errors problem${errors == 1 ? '' : 's'} first.'),
        ]),
        const FbHint('Runs already going keep the version they started on.'),
      ]),
      _Card(title: 'Versions', children: [
        if (d == null || d.versions.isEmpty) const FbHint('Not published yet.'),
        for (final v in d?.versions ?? const <UiWfVersionInfo>[])
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: t.borderSubtle))),
            child: Row(spacing: t.space2, children: [
              SizedBox(width: 36, child: Text('v${v.version}', style: context.uiText.code.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: t.text))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((v.note ?? '').isNotEmpty ? v.note! : 'No note', style: context.uiText.body.copyWith(fontSize: 13, color: t.text)),
                  Text(
                    '${wfDateTime(v.publishedAt)}${v.publishedBy != null ? ' · ${_names[v.publishedBy] ?? v.publishedBy}' : ''} · ${v.instances} run${v.instances == 1 ? '' : 's'}',
                    style: context.uiText.body.copyWith(fontSize: 11.5, color: t.textMuted),
                  ),
                ]),
              ),
              if (v.version != current)
                FbLink(label: 'Make current', onTap: _busy ? null : () => _askRollback(api, store, v.version))
              else
                const WfChip('Current', tone: 'success'),
            ]),
          ),
      ]),
      _Card(title: 'Status', children: [
        FbHint(d?.summary.status == 'archived' ? 'Archived: it starts nothing new; running ones finish.' : 'Active.'),
        if (d?.summary.status == 'archived')
          Align(alignment: AlignmentDirectional.centerStart, child: UiButton(label: 'Restore', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: _busy ? null : () => _run(() => api.restore(store.def.id))))
        else if (current > 0)
          Align(alignment: AlignmentDirectional.centerStart, child: UiButton(label: 'Archive', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: _busy ? null : () => _run(() => api.archive(store.def.id)))),
      ]),
    ]);
  }
}

/// Test runs: run the draft against a real record (or made-up values) without changing anything
/// (the web `ui-wf-test`). The engine reports what each step did or would do; tasks can be
/// decided and time moved forward.
class WfTest extends StatefulWidget {
  const WfTest({super.key});

  @override
  State<WfTest> createState() => _WfTestState();
}

const Map<String, String> _kindLabels = {
  'step.started': 'Step', 'step.completed': 'Done', 'step.failed': 'Failed', 'step.waiting': 'Waiting', 'notify.email': 'Would email', 'notify.inApp': 'Would message',
  'task.created': 'Task', 'task.decided': 'Decision', 'task.timedOut': 'Out of time', 'instance.started': 'Started', 'instance.completed': 'Finished',
  'instance.failed': 'Failed', 'instance.incident': 'Stopped', 'lifecycle.transitioned': 'Moved', 'clock.advanced': 'Time', 'webhook.POST': 'Would call',
};

String wfLogKindLabel(String kind, String action) =>
    _kindLabels['$kind.$action'] ?? (kind == 'notify' ? 'Would send' : kind == 'action' ? 'Would run' : kind == 'webhook' ? 'Would call' : kind);

class _WfTestState extends State<WfTest> {
  String _recordId = '';
  Object? _from;
  Object? _to;
  String _fromState = '';
  String _transition = '';
  List<UiWfSimulationEvent> _events = [];
  bool _busy = false;
  String _error = '';
  UiWfSimulationResult? _result;
  bool _showRecord = false;

  List<({String id, String name, UiWfStep step})> _humanSteps(UiWorkflowDefinition def) => [
    for (final l in indexSteps(def).values)
      if (l.step.type == 'approval' || l.step.type == 'task') (id: l.step.id, name: stepName(l.step), step: l.step),
  ];

  List<WfOption> _outcomesOf(UiWorkflowDefinition def, String? stepId) {
    final s = _humanSteps(def).where((h) => h.id == stepId).firstOrNull?.step;
    if (s == null) return const [];
    if (s.type == 'approval') return const [(value: 'approved', label: 'Approves'), (value: 'rejected', label: 'Rejects')];
    return [for (final o in UiWfTaskStep.of(s).outcomes) (value: o.key, label: o.label)];
  }

  UiWfSimulationEvent _eventOf(UiWorkflowDefinition def, String type, List<UiWfSignalDescriptor> signals) {
    final h = _humanSteps(def).firstOrNull;
    return switch (type) {
      'decide' => UiWfSimulationEvent('decide', {'step': h?.id, 'outcome': h != null ? _outcomesOf(def, h.id).firstOrNull?.value : null}),
      'advance' => UiWfSimulationEvent('advance', const {'duration': 'P1D'}),
      _ => UiWfSimulationEvent(type, {'signal': signals.firstOrNull?.key}),
    };
  }

  Future<void> _run() async {
    final store = WfBuilderScope.read(context).store;
    final api = store.api;
    if (api == null || _busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final def = store.def;
      final r = await api.simulate(
        def,
        UiWfSimulationRequest(
          entityId: _recordId.isEmpty ? null : _recordId,
          trigger: def.kind == 'automation' ? wfCompact({'from': _from, 'to': _to}) : null,
          fromState: _fromState.isEmpty ? null : _fromState,
          transition: _transition.isEmpty ? null : _transition,
          events: _events,
        ),
      );
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) setState(() => _error = e is UiWfApiError ? e.message : 'The test could not run.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final store = WfBuilderScope.of(context).store;
    if (store.api == null) return _page(context, 760, [const FbHint('Connect an API (UiWorkflowHttpApi) to test workflows.')]);
    final def = store.def;
    final lc = def.lifecycle;
    final signals = store.registry?.signals ?? const <UiWfSignalDescriptor>[];
    final trig = def.trigger;
    final triggerField = trig?.type == 'fieldChanged' ? fieldOf(store.registry, def.entity, trig?.field) : null;
    final humans = _humanSteps(def);
    final r = _result;

    Widget event(int i) {
      final e = _events[i];
      void set(UiWfSimulationEvent n) => setState(() => _events = [..._events]..[i] = n);
      final typeSelect = WfSelect(
        label: 'What happens',
        value: e.type,
        options: [(value: 'decide', label: 'Someone decides'), (value: 'advance', label: 'Time passes'), if (signals.isNotEmpty) (value: 'signal', label: 'The app reports')],
        onChanged: (type) => set(_eventOf(def, type, signals)),
      );
      final details = <Widget>[
        if (e.type == 'decide') ...[
          WfSelect(label: 'Task', value: e.step, options: [for (final h in humans) (value: h.id, label: h.name)], onChanged: (id) => set(e.patch({'step': id, 'outcome': _outcomesOf(def, id).firstOrNull?.value}))),
          WfSelect(label: 'Decision', value: e.outcome, options: _outcomesOf(def, e.step), onChanged: (o) => set(e.patch({'outcome': o}))),
        ],
        if (e.type == 'advance') WfDurationInput(value: e.duration ?? 'P1D', label: 'Time', onChanged: (d) => set(e.patch({'duration': d}))),
        if (e.type == 'signal') WfSelect(label: 'Event', value: e.signal, options: [for (final s in signals) (value: s.key, label: s.label)], onChanged: (s) => set(e.patch({'signal': s}))),
      ];
      final remove = FbIconButton(icon: WfIcons.delete02, label: 'Remove', danger: true, onPressed: () => setState(() => _events = [..._events]..removeAt(i)));
      return LayoutBuilder(builder: (context, box) {
        if (box.maxWidth < 560) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 6, children: [typeSelect, ...details])),
            remove,
          ]);
        }
        return Row(spacing: 6, children: [
          Expanded(flex: 8, child: typeSelect),
          if (details.length == 2) ...[Expanded(flex: 10, child: details[0]), Expanded(flex: 8, child: details[1])] else if (details.isNotEmpty) Expanded(flex: 18, child: details[0]),
          remove,
        ]);
      });
    }

    return _page(context, 760, [
      _Card(title: 'Start', children: [
        if ((def.entity ?? '').isNotEmpty)
          FbSetting(label: '${store.entity?.label ?? 'Record'} id', child: UiInput(size: UiSize.sm, value: _recordId, placeholder: 'e.g. 1', semanticLabel: 'Record id', onChanged: (v) => setState(() => _recordId = v))),
        if (lc != null)
          WfPair(children: [
            FbSetting(
              label: 'Record is in',
              child: WfSelect(label: 'Record is in', value: _fromState, options: [(value: '', label: '(its current state)'), for (final s in lc.states) (value: s.key, label: s.label)], onChanged: (v) => setState(() => _fromState = v)),
            ),
            FbSetting(
              label: 'Try',
              child: WfSelect(label: 'Try', value: _transition, options: [(value: '', label: '(no transition)'), for (final x in lc.transitions) (value: x.key, label: x.label)], onChanged: (v) => setState(() => _transition = v)),
            ),
          ])
        else if (triggerField != null)
          WfPair(children: [
            FbSetting(label: '${triggerField.label} was', child: WfValueInput(field: triggerField, value: _from, onChanged: (v) => setState(() => _from = v))),
            FbSetting(label: 'and became', child: WfValueInput(field: triggerField, value: _to, onChanged: (v) => setState(() => _to = v))),
          ]),
      ]),
      _Card(title: 'Then', children: [
        for (var i = 0; i < _events.length; i++) event(i),
        Align(alignment: AlignmentDirectional.centerStart, child: FbLink(label: 'Add what happens next', onTap: () => setState(() => _events = [..._events, _eventOf(def, humans.isNotEmpty ? 'decide' : 'advance', signals)]))),
        Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          UiButton(label: 'Run test', size: UiSize.sm, icon: const UiIcon(WfIcons.play), loading: _busy, onPressed: _busy ? null : _run),
          const FbHint('Nothing real happens: no messages are sent and no records change.'),
        ]),
        if (_error.isNotEmpty) WfNote(_error),
      ]),
      if (r != null)
        _Card(title: 'What happened', children: [
          if (r.error != null) WfNote(r.error!),
          for (final p in r.problems) WfNote(p.message, warning: !p.isError),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2, children: [
            for (var i = 0; i < r.log.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: i.isEven ? t.text.withValues(alpha: 0.03) : null, borderRadius: BorderRadius.circular(t.radiusXs)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      wfLogKindLabel(r.log[i].kind, r.log[i].action),
                      style: context.uiText.label.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: r.log[i].action == 'failed' || r.log[i].kind == 'error'
                            ? t.danger
                            : const ['notify', 'action', 'webhook'].contains(r.log[i].kind)
                            ? t.primary
                            : t.textMuted,
                      ),
                    ),
                  ),
                  Expanded(child: Text(r.log[i].text ?? r.log[i].subject ?? '', style: context.uiText.body.copyWith(fontSize: 12.5, color: t.text))),
                ]),
              ),
          ]),
          if (r.openTasks.isNotEmpty) ...[
            Text('Still waiting for', style: context.uiText.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: t.textSecondary)),
            for (final tk in r.openTasks) Text('•  ${tk.title} — ${tk.assigneeNames.join(', ')}', style: context.uiText.body.copyWith(fontSize: 13, color: t.text)),
          ],
          if (r.record != null) ...[
            Align(alignment: AlignmentDirectional.centerStart, child: FbLink(label: 'The record afterwards', fontSize: 12, onTap: () => setState(() => _showRecord = !_showRecord))),
            if (_showRecord)
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(t.radiusXs)),
                child: SingleChildScrollView(child: Text(const JsonEncoder.withIndent('  ').convert(r.record), style: context.uiText.code.copyWith(fontSize: 11.5, color: t.text))),
              ),
          ],
        ]),
    ]);
  }
}
