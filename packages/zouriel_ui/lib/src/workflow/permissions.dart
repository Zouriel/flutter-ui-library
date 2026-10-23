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

  UiWfPermissionRow withWho(List<UiWfAssignee> who) => UiWfPermissionRow(node: node, kind: kind, label: label, detail: detail, who: who);
}

/// Every "who" a published workflow has, in reading order (moves, reset, start button, then steps).
List<UiWfPermissionRow> permissionRows(UiWorkflowDefinition def) {
  final rows = <UiWfPermissionRow>[];
  final lc = def.lifecycle;
  if (lc != null) {
    String state(String id) => lc.states.where((s) => s.id == id).firstOrNull?.label ?? id;
    for (final t in lc.transitions) {
      // Hidden moves are never offered to anyone. Automatic ones are still offered to the people in
      // their `who` (who may make them early, by hand), so they stay.
      if (t.hidden) continue;
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

/// What an empty "who" means for each kind of row (the builder's wording). [editing]: the text an
/// editor shows, which for a step says what to do about it.
String emptyWhoText(String kind, {bool editing = false}) => switch (kind) {
  'trigger' => 'Anyone who can see the record.',
  'transition' => 'Nobody by hand: only automatically, or from other workflows.',
  'reset' => 'Nobody.',
  // The engine refuses an approval or task nobody can decide.
  _ => editing ? 'Nobody yet: add the people who decide. A step without people can’t be saved.' : 'Nobody yet.',
};

/// Whether two "who" lists name the same people, in any order (and any key order).
bool sameWho(List<UiWfAssignee> a, List<UiWfAssignee> b) {
  if (a.length != b.length) return false;
  List<String> key(List<UiWfAssignee> x) => [for (final w in x) _canonical(w.json)]..sort();
  final ka = key(a), kb = key(b);
  for (var i = 0; i < ka.length; i++) {
    if (ka[i] != kb[i]) return false;
  }
  return true;
}

String _canonical(Object? v) {
  if (v is List) return '[${v.map(_canonical).join(',')}]';
  if (v is Map) {
    final keys = [for (final e in v.entries) if (e.value != null) '${e.key}']..sort();
    return '{${keys.map((k) => '${jsonEncode(k)}:${_canonical(v[k])}').join(',')}}';
  }
  return jsonEncode(v);
}

class _Workflow {
  _Workflow(this.summary, this.def, UiWorkflowRegistry? registry, [List<UiWfPermissionRow>? rows])
    : rows = rows ?? permissionRows(def),
      tokens = tokensAt(def, registry);
  _Workflow._only(_Workflow of, this.rows) : summary = of.summary, def = of.def, tokens = of.tokens;
  final UiWfDefinitionSummary summary;
  final UiWorkflowDefinition def;
  final List<UiWfPermissionRow> rows;
  final List<UiWfToken> tokens;
}

String _errorText(Object e, String fallback) => e is UiWfApiError ? e.message : fallback;

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

  /// Conflicting saves: the published version changed since the page loaded it.
  final Set<String> _conflicts = {};

  /// People's names by user id, for the read-only rows (the editors look their own up).
  final Map<String, String> _userNames = {};
  final Set<String> _askedUsers = {};

  /// Bumped per workflow when its note is cleared, so the field starts empty.
  final Map<String, int> _noteGen = {};

  /// The workflow being saved or reloaded (one at a time).
  String? _busy;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(UiWorkflowPermissions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) load();
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
        _conflicts.clear();
        _loading = false;
      });
      if (!_canEdit) _lookUpNames(api, [for (final w in list) ...w.rows]);
    } catch (e) {
      if (!mounted || n != _loadSeq) return;
      setState(() {
        _loadError = _errorText(e, 'Could not load the workflows.');
        _loading = false;
      });
    }
  }

  /// Finds the names of people named directly (once per id; failures keep showing the id).
  void _lookUpNames(UiWorkflowApi api, List<UiWfPermissionRow> rows) {
    for (final r in rows) {
      for (final a in r.who) {
        if (a.kind != 'user' || _askedUsers.contains(a.value)) continue;
        final id = a.value;
        _askedUsers.add(id);
        Future.sync(() => api.user(id)).then((u) {
          if (u != null && mounted) setState(() => _userNames[id] = u.name);
        }).catchError((Object _) {
          _askedUsers.remove(id);
        });
      }
    }
  }

  List<_Workflow> get _shown {
    final q = _query.trim().toLowerCase();
    final all = _workflows.where((w) => w.rows.isNotEmpty);
    if (q.isEmpty) return all.toList();
    // Rows with unsaved edits always stay, so "Save N changes" never counts rows nobody can see.
    return [
      for (final w in all)
        if (w.summary.title.toLowerCase().contains(q))
          w
        else if ([
          for (final r in w.rows)
            if ((_edits[w.summary.id]?.containsKey(r.node) ?? false) || '${r.label} ${r.detail}'.toLowerCase().contains(q)) r,
        ] case final rows when rows.isNotEmpty)
          _Workflow._only(w, rows),
    ];
  }

  List<UiWfAssignee> _whoOf(_Workflow w, UiWfPermissionRow r) => _edits[w.summary.id]?[r.node] ?? r.who;
  bool _isChanged(_Workflow w, UiWfPermissionRow r) => _edits[w.summary.id]?.containsKey(r.node) ?? false;
  int _changeCount(_Workflow w) => _edits[w.summary.id]?.length ?? 0;

  /// Why this workflow's changes can't be saved yet (an approval or task left with nobody), or ''.
  String _blocked(_Workflow w) {
    final pending = _edits[w.summary.id] ?? const {};
    final empty = [for (final r in w.rows) if (r.kind == 'step' && (pending[r.node]?.isEmpty ?? false)) r];
    if (empty.isEmpty) return '';
    return 'Add someone to ${empty.map((r) => '“${r.label}”').join(', ')}: an approval or task needs at least one person to decide it.';
  }

  String _describe(_Workflow w, UiWfPermissionRow r) {
    if (r.who.isEmpty) return emptyWhoText(r.kind);
    final text = describeAssignees(r.who, UiWfDescribeContext(registry: _registry, def: w.def, tokens: w.tokens, userName: (id) => _userNames[id]));
    return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
  }

  void _edit(_Workflow w, UiWfPermissionRow r, List<UiWfAssignee> who) {
    final id = w.summary.id;
    setState(() {
      final mine = _edits.putIfAbsent(id, () => {});
      // Back to what is published (in any order): not a change any more.
      if (sameWho(who, r.who)) {
        mine.remove(r.node);
      } else {
        mine[r.node] = who;
      }
      _saved[id] = '';
      _errors[id] = '';
    });
  }

  void _clearNote(String id) {
    _notes[id] = '';
    _noteGen[id] = (_noteGen[id] ?? 0) + 1;
  }

  void _discard(_Workflow w) => setState(() {
        final id = w.summary.id;
        _edits[id] = {};
        _clearNote(id);
        _errors[id] = '';
      });

  void _replace(String id, UiWfDefinitionSummary summary, UiWorkflowDefinition def, [List<UiWfPermissionRow>? rows]) {
    final next = _Workflow(summary, def, _registry, rows);
    _workflows = [for (final x in _workflows) x.summary.id == id ? next : x];
    final api = widget.api;
    if (api != null && !_canEdit) _lookUpNames(api, next.rows);
  }

  /// After a conflict: loads this workflow's published version again and drops the edits made on the old one.
  Future<void> _reloadOne(_Workflow w) async {
    final api = widget.api;
    final id = w.summary.id;
    if (api == null || _busy != null) return;
    setState(() => _busy = id);
    try {
      final d = await api.definition(id);
      if (!mounted) return;
      setState(() {
        _replace(id, d.summary, d.published ?? w.def);
        _edits[id] = {};
        _conflicts.remove(id);
        _errors[id] = '';
        _saved[id] = 'Reloaded: version ${d.summary.version} is in use.';
      });
    } catch (e) {
      if (mounted) setState(() => _errors[id] = _errorText(e, 'Could not reload this workflow.'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// Publishes one workflow's changes as a new version.
  Future<void> _save(_Workflow w) async {
    final api = widget.api;
    final id = w.summary.id;
    final pending = Map.of(_edits[id] ?? const <String, List<UiWfAssignee>>{});
    if (api == null || _busy != null || pending.isEmpty || _blocked(w).isNotEmpty || _conflicts.contains(id)) return;
    final changes = [for (final e in pending.entries) (node: e.key, who: e.value)];
    final note = _notes[id]?.trim() ?? '';
    setState(() {
      _busy = id;
      _errors[id] = '';
    });
    final UiWfPermissionsSummary summary;
    try {
      // Someone else may have published since this page loaded: saving would quietly undo their change.
      final now = await api.definition(id);
      if (now.summary.version != w.summary.version || now.published == null) {
        if (mounted) {
          setState(() {
            _conflicts.add(id);
            _busy = null;
          });
        }
        return;
      }
      summary = await api.updatePermissions(id, changes, note: note.isEmpty ? null : note);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errors[id] = _errorText(e, 'Saving failed.');
          _busy = null;
        });
      }
      return;
    }
    if (!mounted) return;
    // Published: from here on nothing may offer to save these changes again.
    setState(() {
      _edits[id] = {};
      _clearNote(id);
    });
    widget.onSaved?.call(summary);
    try {
      final d = await api.definition(id);
      if (!mounted) return;
      setState(() {
        _replace(id, summary, d.published ?? w.def);
        _saved[id] = _savedMessage(summary, w.rows);
      });
    } catch (_) {
      // Show what was saved from the edits themselves; the definition catches up on the next load.
      if (!mounted) return;
      final full = _workflows.firstWhere((x) => x.summary.id == id, orElse: () => w);
      setState(() {
        _replace(id, summary, full.def, [for (final r in full.rows) pending.containsKey(r.node) ? r.withWho(pending[r.node]!) : r]);
        _saved[id] = '${_savedMessage(summary, w.rows)} The page couldn’t load it again; reload to see the latest.';
      });
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// What a save did, in words: the version in use, records that now follow it, records left on an
  /// older version because its states or transitions differ, and draft steps it couldn't change.
  String _savedMessage(UiWfPermissionsSummary summary, List<UiWfPermissionRow> rows) {
    if (summary.changed == false) return 'Nothing changed: version ${summary.version} stays in use.';
    final moved = summary.recordsMoved;
    final kept = summary.recordsKept;
    final movedPart = moved > 0 ? ', and $moved existing record${moved == 1 ? '' : 's'} follow${moved == 1 ? 's' : ''} it' : '';
    final keptWho = moved > 0 ? '$kept' : '$kept existing record${kept == 1 ? '' : 's'}';
    final keptPart = kept > 0 ? '; $keptWho ${kept == 1 ? 'stays on its' : 'stay on their'} version because it differs' : '';
    final parts = ['Saved: version ${summary.version} is now in use$movedPart$keptPart.'];
    final skipped = [for (final n in summary.draftSkipped) '“${rows.where((r) => r.node == n).firstOrNull?.label ?? n}”'];
    if (skipped.isNotEmpty) parts.add('Your draft no longer has ${skipped.join(', ')}, so the draft kept ${skipped.length == 1 ? 'it' : 'them'} as before.');
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final shown = _loading || _loadError.isNotEmpty ? const <_Workflow>[] : _shown;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space4, children: [
      Wrap(spacing: t.space3, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: UiSearchInput(
            size: UiSize.sm,
            value: _query,
            placeholder: 'Find a workflow or step',
            label: 'Find a workflow or step',
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (!_canEdit && !_loading) const FbHint('You can see who may do what; changing it needs the right to publish workflows.'),
      ]),
      if (_loading)
        const FbHint('Loading…')
      else if (_loadError.isNotEmpty)
        WfNote(_loadError)
      else if (widget.api == null)
        const FbHint('No workflow API is connected: pass api (e.g. a UiWorkflowHttpApi) to UiWorkflowPermissions.')
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
    final blocked = n > 0 ? _blocked(w) : '';
    final conflict = _conflicts.contains(id);
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
                child: Text(w.summary.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.body.copyWith(fontSize: 14 * context.ui.fontScale, fontWeight: FontWeight.w600, color: t.text)),
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
        if (_canEdit && (n > 0 || saved.isNotEmpty || error.isNotEmpty || conflict))
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
                    UiButton(
                      label: 'Save $n change${n == 1 ? '' : 's'}',
                      size: UiSize.sm,
                      loading: _busy == id,
                      onPressed: _busy != null || blocked.isNotEmpty || conflict ? null : () => _save(w),
                    ),
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
              if (blocked.isNotEmpty) WfNote(blocked),
              if (conflict)
                WfNote.custom(
                  child: Wrap(spacing: t.space3, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    const Text('Someone changed these permissions since you opened the page. Reload to see their version, then make your changes again.'),
                    UiButton(label: 'Reload', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: _busy == id ? null : () => _reloadOne(w)),
                  ]),
                ),
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
      Text(r.label, style: context.uiText.body.copyWith(fontSize: 13.5 * context.ui.fontScale, fontWeight: FontWeight.w600, color: t.text)),
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
            emptyText: emptyWhoText(r.kind, editing: true),
            onChanged: (v) => _edit(w, r, v),
          )
        : Text(_describe(w, r), style: context.uiText.body.copyWith(fontSize: 13 * context.ui.fontScale, color: r.who.isEmpty ? t.textMuted : t.textSecondary));
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
