import 'package:flutter/foundation.dart';

import 'api.dart';
import 'definition.dart';
import 'definition.dart' as d;
import '../form_builder/engine/js.dart' show jsRound;
import 'json.dart';
import 'schema.dart';

/// What is selected in the builder: the workflow, its trigger, a step, a state or a transition.
@immutable
class UiWfSelection {
  const UiWfSelection._(this.kind) : id = null;
  static const workflow = UiWfSelection._('workflow');
  static const trigger = UiWfSelection._('trigger');
  const UiWfSelection.step(String this.id) : kind = 'step';
  const UiWfSelection.state(String this.id) : kind = 'state';
  const UiWfSelection.transition(String this.id) : kind = 'transition';

  /// `workflow`, `trigger`, `step`, `state` or `transition`.
  final String kind;
  final String? id;

  @override
  bool operator ==(Object other) => other is UiWfSelection && other.kind == kind && other.id == id;
  @override
  int get hashCode => Object.hash(kind, id);
  @override
  String toString() => id == null ? kind : '$kind:$id';
}

const int _historyLimit = 200;

/// Edits to the same setting within this window are undone together (typing a title).
const Duration _mergeWindow = Duration(milliseconds: 1200);

/// The workflow builder's state (the web `WfBuilderStore`): the definition being edited, the app's
/// registry, what is selected, the problems the engine reports, and undo/redo. Every change goes
/// through [commit] so it can be undone.
///
/// [UiWorkflowBuilder] makes one for itself; pass your own to drive it from outside.
class UiWorkflowBuilderController extends ChangeNotifier {
  UiWorkflowBuilderController({UiWorkflowDefinition? definition, DateTime Function()? clock})
    : _def = definition ?? createWorkflow('automation'),
      _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  UiWorkflowDefinition _def;
  UiWorkflowSchema? _schema;
  UiWorkflowDefinition? _published;
  List<UiWfDefinitionSummary> _others = const [];
  UiWorkflowApi? _api;
  UiWorkflowSettings? _settings;
  final Map<String, UiWorkflowDefinition> _lifecycleCache = {};
  final Set<String> _loading = {};
  UiWfSelection? _selection;
  List<UiWfProblem> _serverProblems = const [];
  bool _validating = false;
  int _version = 0;

  final List<UiWorkflowDefinition> _past = [];
  final List<UiWorkflowDefinition> _future = [];
  ({String key, DateTime at})? _lastMerge;

  Map<String, UiWfStepLocation>? _steps;
  Map<String?, List<UiWfProblem>>? _byNode;

  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ── State ───────────────────────────────────────────────────────────────────────────────

  /// The workflow being built.
  UiWorkflowDefinition get def => _def;

  /// The app's registry and step outputs (`GET /schema`).
  UiWorkflowSchema? get schema => _schema;
  set schema(UiWorkflowSchema? v) {
    _schema = v;
    _notify();
  }

  /// The published version, if any (locks the record type).
  UiWorkflowDefinition? get published => _published;
  set published(UiWorkflowDefinition? v) {
    _published = v;
    _notify();
  }

  /// Other workflows (for sub-workflows and lifecycle triggers).
  List<UiWfDefinitionSummary> get others => _others;
  set others(List<UiWfDefinitionSummary> v) {
    _others = v;
    _notify();
  }

  UiWorkflowApi? get api => _api;
  set api(UiWorkflowApi? v) {
    _api = v;
    _notify();
  }

  /// The app's global workflow settings (webhook connections, calendar…), when known.
  UiWorkflowSettings? get settings => _settings;
  set settings(UiWorkflowSettings? v) {
    _settings = v;
    _notify();
  }

  /// Published versions of other lifecycles, by key (for lifecycle triggers), loaded on demand.
  Map<String, UiWorkflowDefinition> get lifecycleCache => Map.unmodifiable(_lifecycleCache);

  UiWfSelection? get selection => _selection;
  set selection(UiWfSelection? v) {
    if (v == _selection) return;
    _selection = v;
    _notify();
  }

  /// The engine's problems from the last check.
  List<UiWfProblem> get serverProblems => _serverProblems;
  set serverProblems(List<UiWfProblem> v) {
    _serverProblems = v;
    _byNode = null;
    _notify();
  }

  bool get validating => _validating;
  set validating(bool v) {
    if (v == _validating) return;
    _validating = v;
    _notify();
  }

  /// Bumped on every commit, undo and redo.
  int get version => _version;
  bool get canUndo => _past.isNotEmpty;
  bool get canRedo => _future.isNotEmpty;

  // ── Derived ─────────────────────────────────────────────────────────────────────────────

  UiWorkflowRegistry? get registry => _schema?.registry;
  List<UiWfConnection> get settingsConnections => _settings?.connections ?? const [];
  UiWfEntityDescriptor? get entity => entityOf(registry, _def.entity);
  Map<String, UiWfStepLocation> get steps => _steps ??= indexSteps(_def);
  List<UiWfProblem> get problems => _serverProblems;
  int get errorCount => problems.where((p) => p.isError).length;

  /// Problems per step, state or transition id (null key = the workflow itself).
  Map<String?, List<UiWfProblem>> get problemsByNode {
    final cached = _byNode;
    if (cached != null) return cached;
    final m = <String?, List<UiWfProblem>>{};
    for (final p in problems) {
      (m[p.node] ??= []).add(p);
    }
    return _byNode = m;
  }

  List<UiWfProblem> problemsOf(String? node) => problemsByNode[node] ?? const [];

  /// Outputs per step type, as the engine reports them.
  Map<String, List<String>>? get outputs => _schema == null ? null : {for (final s in _schema!.steps) s.type: s.outputs};

  UiWfStep? get selectedStep => _selection?.kind == 'step' ? steps[_selection!.id]?.step : null;
  UiWfState? get selectedState => _selection?.kind == 'state' ? _def.lifecycle?.states.where((x) => x.id == _selection!.id).firstOrNull : null;
  UiWfTransition? get selectedTransition => _selection?.kind == 'transition' ? _def.lifecycle?.transitions.where((x) => x.id == _selection!.id).firstOrNull : null;

  /// Fetches another lifecycle's published version once, so its states and transitions can be offered.
  void loadLifecycle(String key) {
    final api = _api;
    final summary = _others.where((o) => o.key == key).firstOrNull;
    if (api == null || summary == null || _lifecycleCache.containsKey(key) || _loading.contains(key)) return;
    _loading.add(key);
    api.definition(summary.id).then((d) {
      final p = d.published;
      if (p != null) {
        _lifecycleCache[key] = p;
        _notify();
      }
    }).catchError((Object _) {}).whenComplete(() => _loading.remove(key));
  }

  /// Tokens available at a step or list position, for pickers.
  List<UiWfToken> tokens([UiWfAt? at, List<UiWfInputField>? inputFields]) => tokensAt(_def, registry, outputs: outputs, at: at, inputFields: inputFields);

  UiWfDescribeContext describeContext([List<UiWfToken>? tokens]) => UiWfDescribeContext(
    registry: registry,
    def: _def,
    tokens: tokens,
    workflowTitle: (key) => _others.where((o) => o.key == key).firstOrNull?.title,
  );

  // ── History ─────────────────────────────────────────────────────────────────────────────

  /// Loads a definition. History is kept when it is the same workflow (e.g. the host echoed a save).
  void load(UiWorkflowDefinition def) {
    if (identical(def, _def)) return;
    if (def.id != _def.id) _clear();
    _def = def;
    _steps = null;
    _pruneSelection();
    _notify();
  }

  void _clear() {
    _past.clear();
    _future.clear();
    _lastMerge = null;
  }

  void clearHistory() {
    _clear();
    _notify();
  }

  /// Applies a change. Changes with the same [mergeKey] in quick succession undo as one.
  void commit(UiWorkflowDefinition next, {String? mergeKey}) {
    if (identical(next, _def)) return;
    final now = _clock();
    final last = _lastMerge;
    final merge = mergeKey != null && last != null && last.key == mergeKey && now.difference(last.at) < _mergeWindow;
    if (!merge) {
      _past.add(_def);
      if (_past.length > _historyLimit) _past.removeAt(0);
    }
    _lastMerge = mergeKey != null ? (key: mergeKey, at: now) : null;
    _future.clear();
    _apply(next, keepMerge: true);
  }

  void undo() {
    if (_past.isEmpty) return;
    _future.add(_def);
    _apply(_past.removeLast());
  }

  void redo() {
    if (_future.isEmpty) return;
    _past.add(_def);
    _apply(_future.removeLast());
  }

  void _apply(UiWorkflowDefinition def, {bool keepMerge = false}) {
    if (!keepMerge) _lastMerge = null;
    _def = def;
    _steps = null;
    _version++;
    _pruneSelection();
    _notify();
  }

  /// Drops a selection whose item no longer exists (after undo or delete).
  void _pruneSelection() {
    final s = _selection;
    if (s == null) return;
    final exists = switch (s.kind) {
      'workflow' || 'trigger' => true,
      'step' => steps.containsKey(s.id),
      'state' => _def.lifecycle?.states.any((x) => x.id == s.id) ?? false,
      _ => _def.lifecycle?.transitions.any((x) => x.id == s.id) ?? false,
    };
    if (!exists) _selection = null;
  }

  // ── Edits ───────────────────────────────────────────────────────────────────────────────

  /// Merges [patch] into the definition (null values remove keys).
  void patch(UiJson patch, {String? mergeKey}) => commit(_def.patch(patch), mergeKey: mergeKey);

  void setTrigger(UiWfTrigger trigger, {String? mergeKey}) => commit(_def.patch({'trigger': trigger.json}), mergeKey: mergeKey);

  /// Adds a new step of [type] and selects it; its id.
  String addStep(String type, String listId, int index) {
    final step = createStep(type, registry);
    commit(d.insertStep(_def, listId, index, step));
    selection = UiWfSelection.step(step.id);
    return step.id;
  }

  void insertStep(UiWfStep step, String listId, int index) => commit(d.insertStep(_def, listId, index, step));

  /// Moves a step; false when nothing changed.
  bool moveStep(String id, String listId, int index) {
    final next = d.moveStep(_def, id, listId, index);
    if (identical(next, _def)) return false;
    commit(next);
    return true;
  }

  /// Merges [patch] into a step (null values remove keys).
  void updateStep(String id, UiJson patch, {String? mergeKey}) => commit(d.updateStep(_def, id, (s) => s.patch(patch)), mergeKey: mergeKey);

  /// Replaces a step with `edit(step)`.
  void replaceStep(String id, UiWfStep Function(UiWfStep s) edit, {String? mergeKey}) => commit(d.updateStep(_def, id, edit), mergeKey: mergeKey);

  void removeStep(String id) => commit(d.removeStep(_def, id));

  void duplicateStep(String id) {
    final r = d.duplicateStep(_def, id);
    if (r.id == null) return;
    commit(r.def);
    selection = UiWfSelection.step(r.id!);
  }

  // ── Lifecycle edits ─────────────────────────────────────────────────────────────────────

  /// Adds a state (placed at [at] when given) and selects it; its id.
  String addState([String label = 'New state', List<num>? at]) {
    final taken = {...?_def.lifecycle?.states.map((s) => s.key)};
    var key = label;
    for (var i = 2; taken.contains(key); i++) {
      key = '$label $i';
    }
    final state = createState(key);
    commit(updateLifecycle(_def, (lc) => lc.patch({
      'states': [...lc.states, state],
      if (at != null) 'layout': {...?wfMapOrNull(lc.json['layout']), state.id: at},
    })));
    selection = UiWfSelection.state(state.id);
    return state.id;
  }

  void updateState(String id, UiJson patch, {String? mergeKey}) => commit(d.updateState(_def, id, patch), mergeKey: mergeKey);
  void replaceState(String id, UiWfState Function(UiWfState s) edit, {String? mergeKey}) => commit(updateStateWith(_def, id, edit), mergeKey: mergeKey);
  void removeState(String id) => commit(d.removeState(_def, id));

  /// Adds a transition, named after its target, and selects it; its id.
  String addTransition(String from, String to, [String? label]) {
    final lc = _def.lifecycle;
    if (lc == null) return '';
    final toState = lc.states.where((s) => s.id == to).firstOrNull;
    final t = createTransition(from, to, label ?? (toState != null ? 'To ${toState.label}' : 'Move'), lc.transitions);
    commit(updateLifecycle(_def, (l) => l.patch({'transitions': [...l.transitions, t]})));
    selection = UiWfSelection.transition(t.id);
    return t.id;
  }

  void updateTransition(String id, UiJson patch, {String? mergeKey}) => commit(d.updateTransition(_def, id, patch), mergeKey: mergeKey);
  void replaceTransition(String id, UiWfTransition Function(UiWfTransition t) edit, {String? mergeKey}) =>
      commit(updateTransitionWith(_def, id, edit), mergeKey: mergeKey);
  void removeTransition(String id) => commit(updateLifecycle(_def, (lc) => lc.patch({'transitions': lc.transitions.where((t) => t.id != id).toList()})));

  /// Stores a state's position on the diagram (one undo step per drag).
  void placeState(String id, double x, double y) => commit(updateLifecycle(_def, (lc) => lc.patch({
    'layout': {...?wfMapOrNull(lc.json['layout']), id: [jsRound(x).toInt(), jsRound(y).toInt()]},
  })));

  /// Forgets manual positions so the diagram lays itself out again.
  void tidyLayout() => commit(updateLifecycle(_def, (lc) => UiWfLifecycle.fromJson({...lc.json}..remove('layout'))));
}
