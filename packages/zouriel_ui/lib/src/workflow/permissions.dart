import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../button/button.dart';
import '../core/types.dart';
import '../forms/text/inputs.dart';
import '../theme/theme.dart';
import 'api.dart';
import 'bits.dart';
import 'definition.dart';
import 'editors.dart';
import 'schema.dart';

/// One "who" in a published workflow: a transition, the reset, the start button or a person's step.
class UiWfPermissionRow {
  const UiWfPermissionRow({required this.node, required this.kind, required this.label, required this.detail, required this.who});

  /// What [UiWorkflowApi.updatePermissions] changes: a transition or step id, `reset` or `trigger`.
  final String node;

  /// `transition`, `reset`, `trigger` or `step`.
  final String kind;
  final String label;

  /// Where it is: "Submitted [wfArrow] Under review", "Approval"…
  final String detail;
  final List<UiWfAssignee> who;
}

/// Every "who" a published workflow has, in reading order (moves, reset, start button, then steps).
List<UiWfPermissionRow> permissionRows(UiWorkflowDefinition def) {
  final rows = <UiWfPermissionRow>[];
  final lc = def.lifecycle;
  if (lc != null) {
    String state(String id) => lc.states.where((s) => s.id == id).firstOrNull?.label ?? id;
    for (final t in lc.transitions) {
      // Automatic moves happen on their own: nobody is asked.
      if (t.auto != null) continue;
      final from = t.fromAny ? 'Any state' : t.from.map(state).join(', ');
      rows.add(UiWfPermissionRow(node: t.id, kind: 'transition', label: t.label, detail: '$from $wfArrow ${state(t.to)}', who: t.who ?? const []));
    }
    final reset = lc.reset;
    if (reset != null) {
      final to = reset.to != null ? state(reset.to!) : lc.states.where((s) => s.category == 'initial').firstOrNull?.label ?? 'the start';
      final label = reset.label ?? '';
      rows.add(UiWfPermissionRow(node: 'reset', kind: 'reset', label: label.isEmpty ? 'Start over' : label, detail: 'Back to $to', who: reset.who));
    }
  }
  final trig = def.trigger;
  if (trig != null && trig.type == 'manual') {
    final label = trig.label ?? '';
    rows.add(UiWfPermissionRow(node: 'trigger', kind: 'trigger', label: '“${label.isEmpty ? 'Start' : label}” button', detail: 'Starts this workflow', who: trig.who ?? const []));
  }
  for (final loc in indexSteps(def).values) {
    final s = loc.step;
    if (s.type != 'approval' && s.type != 'task') continue;
    rows.add(UiWfPermissionRow(node: s.id, kind: 'step', label: stepName(s), detail: stepInfo(s.type).label, who: UiWfHumanStep.of(s).assignees));
  }
  return rows;
}

class _Workflow {
  _Workflow(this.summary, this.def, UiWorkflowRegistry? registry) : rows = permissionRows(def), tokens = tokensAt(def, registry);
  _Workflow._only(_Workflow of, this.rows) : summary = of.summary, def = of.def, tokens = of.tokens;
  final UiWfDefinitionSummary summary;
  final UiWorkflowDefinition def;
  final List<UiWfPermissionRow> rows;
  final List<UiWfToken> tokens;
}

String _errorText(Object e, String fallback) => e is UiWfApiError ? e.message : fallback;

String _whoKey(List<UiWfAssignee> who) => jsonEncode([for (final a in who) a.json]);

/// `ui-workflow-permissions`: who may do what in every published workflow, on one settings page:
/// who may make each lifecycle move, start a record over, press a start button, and decide each
/// approval or task. Saving publishes a new version straight away (only these changes), so admins
/// can change people without opening the builder. People without the right to publish see who may
/// do what, read-only.
class UiWorkflowPermissions extends StatefulWidget {
  const UiWorkflowPermissions({super.key, required this.api, this.onSaved});
  final UiWorkflowApi? api;

  /// After a workflow's permissions were saved (the new version's summary).
  final ValueChanged<UiWfDefinitionSummary>? onSaved;

  @override
  State<UiWorkflowPermissions> createState() => UiWorkflowPermissionsState();
}

class UiWorkflowPermissionsState extends State<UiWorkflowPermissions> {
  List<_Workflow> _workflows = const [];
  UiWorkflowRegistry? _registry;
  bool _loading = true;
  String _loadError = '';
  bool _canEdit = false;
  String _query = '';
  int _loadSeq = 0;

  /// Unsaved "who" per workflow id and node.
  final Map<String, Map<String, List<UiWfAssignee>>> _edits = {};
  final Map<String, String> _notes = {};
  final Map<String, String> _errors = {};
  final Map<String, String> _saved = {};

  /// Bumped per workflow when its note is cleared, so the field starts empty.
  final Map<String, int> _noteGen = {};

  /// The workflow being saved (one at a time).
  String? _busy;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(UiWorkflowPermissions oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.api != widget.api) load();
  }

  /// Loads every published workflow (again).
  Future<void> load() async {
    final api = widget.api;
    final n = ++_loadSeq;
    if (api == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadError = '';
    });
    try {
      final summariesF = api.definitions();
      final schemaF = Future.sync(api.schema).then<UiWorkflowSchema?>((s) => s).catchError((Object _) => null);
      final meF = Future.sync(api.me).then<UiWfMe?>((m) => m).catchError((Object _) => null);
      final summaries = await summariesF;
      final schema = await schemaF;
      final me = await meF;
      final published = summaries.where((s) => s.version > 0 && s.status != 'archived').toList();
      final details = await Future.wait([
        for (final s in published) Future.sync(() => api.definition(s.id)).then<UiWfDefinitionDetail?>((d) => d).catchError((Object _) => null),
      ]);
      if (!mounted || n != _loadSeq) return;
      final registry = schema?.registry;
      final list = <_Workflow>[
        for (var i = 0; i < published.length; i++)
          if (details[i]?.published case final def?) _Workflow(published[i], def, registry),
      ]..sort((a, b) => a.summary.title.toLowerCase().compareTo(b.summary.title.toLowerCase()));
      setState(() {
        _registry = registry;
        // Without /me the server still decides; offer editing and show its answer if it refuses.
        _canEdit = me?.canPublish ?? true;
        _workflows = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || n != _loadSeq) return;
      setState(() {
        _loadError = _errorText(e, 'Could not load the workflows.');
        _loading = false;
      });
    }
  }

  List<_Workflow> get _shown {
    final q = _query.trim().toLowerCase();
    final all = _workflows.where((w) => w.rows.isNotEmpty);
    if (q.isEmpty) return all.toList();
    return [
      for (final w in all)
        if (w.summary.title.toLowerCase().contains(q))
          w
        else if (w.rows.where((r) => '${r.label} ${r.detail}'.toLowerCase().contains(q)).toList() case final rows when rows.isNotEmpty)
          _Workflow._only(w, rows),
    ];
  }

  List<UiWfAssignee> _whoOf(_Workflow w, UiWfPermissionRow r) => _edits[w.summary.id]?[r.node] ?? r.who;
  bool _isChanged(_Workflow w, UiWfPermissionRow r) => _edits[w.summary.id]?.containsKey(r.node) ?? false;
  int _changeCount(_Workflow w) => _edits[w.summary.id]?.length ?? 0;

  String _describe(_Workflow w, UiWfPermissionRow r) {
    final text = describeAssignees(r.who, UiWfDescribeContext(registry: _registry, def: w.def, tokens: w.tokens));
    return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
  }

  void _edit(_Workflow w, UiWfPermissionRow r, List<UiWfAssignee> who) {
    final id = w.summary.id;
    setState(() {
      final mine = _edits.putIfAbsent(id, () => {});
      // Back to what is published: not a change any more.
      if (_whoKey(who) == _whoKey(r.who)) {
        mine.remove(r.node);
      } else {
        mine[r.node] = who;
      }
      _saved[id] = '';
      _errors[id] = '';
    });
  }

  void _discard(_Workflow w) => setState(() {
        _edits[w.summary.id] = {};
        _errors[w.summary.id] = '';
      });

  /// Publishes one workflow's changes as a new version.
  Future<void> _save(_Workflow w) async {
    final api = widget.api;
    final id = w.summary.id;
    final pending = _edits[id] ?? const {};
    if (api == null || _busy != null || pending.isEmpty) return;
    final changes = [for (final e in pending.entries) (node: e.key, who: e.value)];
    final note = _notes[id]?.trim() ?? '';
    setState(() {
      _busy = id;
      _errors[id] = '';
    });
    try {
      final summary = await api.updatePermissions(id, changes, note: note.isEmpty ? null : note);
      final d = await api.definition(id);
      if (!mounted) return;
      final def = d.published ?? w.def;
      setState(() {
        _workflows = [for (final x in _workflows) x.summary.id == id ? _Workflow(summary, def, _registry) : x];
        _edits[id] = {};
        _notes[id] = '';
        _noteGen[id] = (_noteGen[id] ?? 0) + 1;
        _saved[id] = 'Saved: version ${summary.version} is now in use.';
      });
      widget.onSaved?.call(summary);
    } catch (e) {
      if (mounted) setState(() => _errors[id] = _errorText(e, 'Saving failed.'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final shown = _loading || _loadError.isNotEmpty ? const <_Workflow>[] : _shown;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space4, children: [
      Wrap(spacing: t.space3, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: UiInput(
            size: UiSize.sm,
            type: UiInputType.search,
            value: _query,
            placeholder: 'Find a workflow or step',
            semanticLabel: 'Find a workflow or step',
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (!_canEdit && !_loading) const FbHint('You can see who may do what; changing it needs the right to publish workflows.'),
      ]),
      if (_loading)
        const FbHint('Loading…')
      else if (_loadError.isNotEmpty)
        WfNote(_loadError)
      else if (shown.isEmpty)
        FbHint(_query.trim().isNotEmpty ? 'Nothing matches.' : 'No published workflow asks anyone for anything yet.')
      else
        for (final w in shown) _section(context, w),
    ]);
  }

  Widget _section(BuildContext context, _Workflow w) {
    final t = context.ui;
    final id = w.summary.id;
    final n = _changeCount(w);
    final saved = _saved[id] ?? '';
    final error = _errors[id] ?? '';
    final divider = BorderSide(color: t.borderSubtle);
    return Container(
      key: ValueKey('perm-$id'),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space3),
          decoration: BoxDecoration(border: Border(bottom: divider)),
          child: Row(spacing: t.space2, children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(w.summary.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: t.text)),
              ),
            ),
            WfChip('${w.summary.kind == 'lifecycle' ? 'Lifecycle' : 'Automation'} · v${w.summary.version}'),
          ]),
        ),
        LayoutBuilder(builder: (context, box) {
          final stacked = box.maxWidth < 560;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < w.rows.length; i++) _row(context, w, w.rows[i], first: i == 0, stacked: stacked),
          ]);
        }),
        if (_canEdit && (n > 0 || saved.isNotEmpty || error.isNotEmpty))
          Container(
            padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space3),
            decoration: BoxDecoration(border: Border(top: divider)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
              if (n > 0)
                LayoutBuilder(builder: (context, box) {
                  final note = UiInput(
                    key: ValueKey('note-$id-${_noteGen[id] ?? 0}'),
                    size: UiSize.sm,
                    value: _notes[id] ?? '',
                    placeholder: 'Why (kept with the version)',
                    semanticLabel: 'Why these changes',
                    onChanged: (v) => _notes[id] = v,
                  );
                  final buttons = [
                    UiButton(label: 'Undo', size: UiSize.sm, variant: UiButtonVariant.ghost, onPressed: _busy == id ? null : () => _discard(w)),
                    UiButton(label: 'Save $n change${n == 1 ? '' : 's'}', size: UiSize.sm, loading: _busy == id, onPressed: _busy != null ? null : () => _save(w)),
                  ];
                  if (box.maxWidth < 420) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
                      note,
                      Row(mainAxisAlignment: MainAxisAlignment.end, spacing: t.space2, children: buttons),
                    ]);
                  }
                  return Row(spacing: t.space2, children: [Expanded(child: note), ...buttons]);
                })
              else if (saved.isNotEmpty)
                Semantics(liveRegion: true, child: FbHint(saved)),
              if (error.isNotEmpty) WfNote(error),
            ]),
          ),
      ]),
    );
  }

  Widget _row(BuildContext context, _Workflow w, UiWfPermissionRow r, {required bool first, required bool stacked}) {
    final t = context.ui;
    final changed = _isChanged(w, r);
    final what = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, spacing: 2, children: [
      Text(r.label, style: context.uiText.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, color: t.text)),
      WfArrowText(r.detail, style: context.uiText.body.copyWith(fontSize: 12, color: t.textMuted)),
    ]);
    final who = _canEdit
        ? WfAssigneesEditor(
            key: ValueKey('who-${w.summary.id}-${r.node}'),
            value: _whoOf(w, r),
            registry: _registry,
            tokens: w.tokens,
            api: widget.api,
            label: r.label,
            emptyText: 'Nobody yet.',
            onChanged: (v) => _edit(w, r, v),
          )
        : Text(_describe(w, r), style: context.uiText.body.copyWith(fontSize: 13, color: t.textSecondary));
    return Semantics(
      container: true,
      value: changed ? 'Changed' : null,
      child: Container(
        key: ValueKey('row-${w.summary.id}-${r.node}'),
        decoration: BoxDecoration(
          border: Border(
            top: first ? BorderSide.none : BorderSide(color: t.borderSubtle),
            left: BorderSide(color: changed ? t.primary : t.primary.withValues(alpha: 0), width: 3),
          ),
        ),
        padding: EdgeInsetsDirectional.only(start: t.space4 - 3, end: t.space4, top: t.space3, bottom: t.space3),
        child: stacked
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [what, who])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space4, children: [
                Expanded(flex: 10, child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 160), child: what)),
                Expanded(flex: 14, child: who),
              ]),
      ),
    );
  }
}
