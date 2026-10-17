/// Operations on workflow definitions (the web `definition.ts`): ids and keys, new workflows and
/// steps with their defaults, the step lists inside a definition and every edit to them, what a
/// step can read (tokens), and plain-English summaries.
///
/// Every function returns a new definition and never changes the one it is given. Parts it doesn't
/// touch stay the identical objects, as in the web version, so `identical(next, def)` means
/// "nothing changed".
library;

import 'dart:convert';
import 'dart:math' as math;

import '../form_builder/engine/field_types.dart';
import '../form_builder/engine/slug_table.g.dart';
import 'json.dart';
import 'schema.dart';

// ── Ids and keys ────────────────────────────────────────────────────────────────────────────

int _seq = 0;
final math.Random _random = math.Random();

/// A new immutable id: short, unique enough for one definition, valid per the spec (`[A-Za-z0-9_-]`).
String wfId(String prefix) {
  _seq = (_seq + 1) % 1296;
  final time = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final rand = List.generate(3, (_) => _random.nextInt(36).toRadixString(36)).join();
  return '${prefix}_${time.substring(math.max(0, time.length - 4))}${_seq.toRadixString(36).padLeft(2, '0')}$rand';
}

final RegExp _nonKey = RegExp(r'[^A-Za-z0-9]+');

/// `Send reminder` → `sendReminder` (a key: starts with a letter, letters/digits/underscores).
String wfKey(String label, [Iterable<String> taken = const []]) {
  final folded = StringBuffer();
  for (final rune in label.runes) {
    if (rune >= 0x300 && rune <= 0x36F) continue;
    folded.write(fbSlugFold[rune] ?? String.fromCharCode(rune));
  }
  final words = folded.toString().replaceAll(_nonKey, ' ').trim().split(' ').where((w) => w.isNotEmpty).toList();
  var base = [
    for (var i = 0; i < words.length; i++) i == 0 ? words[i].toLowerCase() : words[i][0].toUpperCase() + words[i].substring(1).toLowerCase(),
  ].join();
  if (base.isEmpty) base = 'item';
  if (!RegExp(r'^[a-z]').hasMatch(base)) base = 'k$base';
  if (base.length > 48) base = base.substring(0, 48);
  final used = taken.toSet();
  if (!used.contains(base)) return base;
  for (var i = 2;; i++) {
    if (!used.contains('$base$i')) return '$base$i';
  }
}

// ── Creating definitions ────────────────────────────────────────────────────────────────────

/// A new automation (a field-change trigger, no steps) or lifecycle (a start state, a final state
/// and a move between them).
UiWorkflowDefinition createWorkflow(String kind, {String? title, String? entity}) {
  final t = title ?? (kind == 'lifecycle' ? 'New lifecycle' : 'New workflow');
  final id = wfId('wf');
  final def = <String, Object?>{'specVersion': 1, 'id': id, 'key': wfKey(t) + id.substring(id.length - 4), 'kind': kind, 'title': t};
  if (entity != null && entity.isNotEmpty) def['entity'] = entity;
  if (kind == 'automation') {
    def['trigger'] = {'type': 'fieldChanged'};
    def['steps'] = <UiWfStep>[];
  } else {
    final draft = createState('Draft', category: 'initial');
    final done = createState('Done', category: 'terminal');
    def['lifecycle'] = {
      'field': '',
      'mode': 'enforce',
      'states': [draft, done],
      'transitions': [
        {'id': wfId('tr'), 'key': 'finish', 'label': 'Finish', 'from': [draft.id], 'to': done.id, 'who': <Object?>[]},
      ],
    };
  }
  return UiWorkflowDefinition.fromJson(def);
}

UiWfState createState(String label, {String category = 'active', String? key}) => UiWfState.fromJson({
  'id': wfId('st'),
  'key': key ?? label,
  'label': label,
  'category': category,
  'tone': category == 'terminal' ? 'success' : (category == 'initial' ? 'neutral' : 'info'),
});

UiWfTransition createTransition(String from, String to, String label, List<UiWfTransition> existing) => UiWfTransition.fromJson({
  'id': wfId('tr'),
  'key': wfKey(label, existing.map((t) => t.key)),
  'label': label,
  'from': [from],
  'to': to,
  'who': <Object?>[],
});

// ── Step catalogue ──────────────────────────────────────────────────────────────────────────

/// Categories of the step picker: `People`, `Logic`, `Timing`, `Data`, `Messages`, `Advanced`.
const List<String> uiWfStepCategories = ['People', 'Logic', 'Timing', 'Data', 'Messages', 'Advanced'];

class UiWfStepInfo {
  const UiWfStepInfo({required this.type, required this.label, required this.description, required this.category, required this.outputs, this.container = false});
  final String type;
  final String label;
  final String description;
  final String category;

  /// Outputs other steps can read as `steps.ID.<output>`. Actions add the outputs their app declares.
  final List<String> outputs;

  /// Has nested step lists (paths, outcomes…), so it renders as a container.
  final bool container;
}

const List<UiWfStepInfo> uiWfStepTypes = [
  UiWfStepInfo(type: 'approval', label: 'Approval', description: 'Ask people to approve or reject, with a deadline', category: 'People', outputs: ['outcome', 'decidedBy', 'comments', 'data'], container: true),
  UiWfStepInfo(type: 'task', label: 'Task', description: 'Ask someone to choose what happens next', category: 'People', outputs: ['outcome', 'decidedBy', 'comment', 'data'], container: true),
  UiWfStepInfo(type: 'branch', label: 'Branch', description: 'Take a different path depending on conditions', category: 'Logic', outputs: ['path'], container: true),
  UiWfStepInfo(type: 'switch', label: 'Switch', description: 'A path for each value of a field', category: 'Logic', outputs: ['case'], container: true),
  UiWfStepInfo(type: 'parallel', label: 'Parallel paths', description: 'Run several paths at the same time', category: 'Logic', outputs: ['completed'], container: true),
  UiWfStepInfo(type: 'forEach', label: 'For each', description: 'Repeat steps for every related record', category: 'Logic', outputs: ['count'], container: true),
  UiWfStepInfo(type: 'goTo', label: 'Go back', description: 'Repeat from an earlier step, up to a limit', category: 'Logic', outputs: ['count']),
  UiWfStepInfo(type: 'end', label: 'End', description: 'Stop the workflow here', category: 'Logic', outputs: []),
  UiWfStepInfo(type: 'wait', label: 'Wait', description: 'Pause for a time, until a date, a condition or an event', category: 'Timing', outputs: ['timedOut', 'data']),
  UiWfStepInfo(type: 'setFields', label: 'Update record', description: 'Change fields on the record', category: 'Data', outputs: []),
  UiWfStepInfo(type: 'createRecord', label: 'Create record', description: 'Add a new record of any kind', category: 'Data', outputs: ['id']),
  UiWfStepInfo(type: 'applyTransition', label: 'Move lifecycle', description: 'Move a record to another state', category: 'Data', outputs: ['applied']),
  UiWfStepInfo(type: 'setVariables', label: 'Set variables', description: 'Remember a value for later steps', category: 'Data', outputs: []),
  UiWfStepInfo(type: 'notify', label: 'Send notification', description: 'Email or message people', category: 'Messages', outputs: ['sent']),
  UiWfStepInfo(type: 'action', label: 'Run action', description: 'Run something the app provides', category: 'Advanced', outputs: []),
  UiWfStepInfo(type: 'webhook', label: 'Call webhook', description: 'Send data to another system', category: 'Advanced', outputs: ['status', 'body']),
  UiWfStepInfo(type: 'subWorkflow', label: 'Run workflow', description: 'Start another workflow and use its result', category: 'Advanced', outputs: ['instanceId', 'status', 'outputs']),
];

final Map<String, UiWfStepInfo> _stepInfo = {for (final s in uiWfStepTypes) s.type: s};

UiWfStepInfo stepInfo(String type) => _stepInfo[type] ?? UiWfStepInfo(type: type, label: type, description: '', category: 'Advanced', outputs: const []);

/// A step's display name: its title, else its type's label.
String stepName(UiWfStep step) {
  final t = step.title?.trim() ?? '';
  return t.isNotEmpty ? t : stepInfo(step.type).label;
}

/// A new step with sensible defaults.
UiWfStep createStep(String type, [UiWorkflowRegistry? reg]) {
  final id = wfId('s');
  final UiJson j = switch (type) {
    'approval' => {'id': id, 'type': type, 'assignees': <Object?>[], 'rule': {'type': 'any'}, 'due': 'P3D', 'reminders': ['P1D'], 'outcomes': {'approved': <Object?>[], 'rejected': <Object?>[], 'timedOut': <Object?>[]}},
    'task' => {
      'id': id, 'type': type, 'assignees': <Object?>[], 'due': 'P3D',
      'outcomes': [{'id': wfId('o'), 'key': 'done', 'label': 'Done', 'tone': 'primary', 'steps': <Object?>[]}],
      'onTimeout': {'id': wfId('l'), 'steps': <Object?>[]},
    },
    'branch' => {
      'id': id, 'type': type,
      'paths': [{'id': wfId('p'), 'label': 'If', 'when': {'match': 'all', 'conditions': <Object?>[]}, 'steps': <Object?>[]}],
      'otherwise': {'id': wfId('l'), 'label': 'Otherwise', 'steps': <Object?>[]},
    },
    'switch' => {
      'id': id, 'type': type, 'on': '',
      'cases': [{'id': wfId('c'), 'label': 'Case 1', 'values': <Object?>[], 'steps': <Object?>[]}],
      'otherwise': {'id': wfId('l'), 'label': 'Otherwise', 'steps': <Object?>[]},
    },
    'parallel' => {
      'id': id, 'type': type, 'join': {'type': 'all'},
      'paths': [{'id': wfId('p'), 'label': 'Path 1', 'steps': <Object?>[]}, {'id': wfId('p'), 'label': 'Path 2', 'steps': <Object?>[]}],
    },
    'forEach' => {'id': id, 'type': type, 'collection': '', 'max': 100, 'mode': 'sequential', 'steps': <Object?>[]},
    'wait' => {'id': id, 'type': type, 'until': {'type': 'duration', 'duration': 'P1D'}},
    'setFields' => {'id': id, 'type': type, 'values': <Object?>[]},
    'createRecord' => {'id': id, 'type': type, 'entity': '', 'values': <Object?>[]},
    'setVariables' => {'id': id, 'type': type, 'values': <Object?>[]},
    'applyTransition' => {'id': id, 'type': type, 'lifecycle': '', 'transition': '', 'ifNotAllowed': 'fail'},
    'notify' => {'id': id, 'type': type, 'channel': reg?.channels?.firstOrNull?.key ?? 'email', 'to': <Object?>[], 'subject': '', 'body': ''},
    'webhook' => {'id': id, 'type': type, 'method': 'POST', 'url': ''},
    'action' => {'id': id, 'type': type, 'action': reg?.actions?.firstOrNull?.key ?? '', 'input': <String, Object?>{}},
    'subWorkflow' => {'id': id, 'type': type, 'workflow': '', 'wait': true},
    'goTo' => {'id': id, 'type': type, 'target': '', 'maxTimes': 3},
    'end' => {'id': id, 'type': type, 'result': 'completed'},
    _ => {'id': id, 'type': type},
  };
  return UiWfStep.fromJson(j);
}

// ── Step lists ──────────────────────────────────────────────────────────────────────────────
//
// Every list of steps has an id, the same ids the engines use: `root` for an automation;
// `transition:ID`, `onEnter:ID`, `onExit:ID`, `sla:ID` in a lifecycle; `STEP/SLOT` for lists inside
// a step (`s3/path:p1`, `s5/outcome:approved`, `s9/each`, `s2/error`).

/// A step list nested in a step.
class UiWfSlot {
  const UiWfSlot({required this.slot, required this.label, required this.steps, required this.kind, this.tone});
  final String slot;

  /// Shown above the list: "If amount is over 5,000", "Approved", "Otherwise"…
  final String label;
  final List<UiWfStep> steps;

  /// How the slot behaves: `path`, `otherwise`, `case`, `outcome`, `each`, `timeout`, `error`.
  final String kind;
  final String? tone;
}

String _or(String? s, String fallback) => s == null || s.isEmpty ? fallback : s;

/// The step lists nested in a step, in display order.
List<UiWfSlot> stepSlots(UiWfStep step) {
  final slots = <UiWfSlot>[];
  switch (step.type) {
    case 'branch':
      final b = UiWfBranchStep.of(step);
      for (final p in b.paths) {
        slots.add(UiWfSlot(slot: 'path:${p.id}', label: _or(p.label, 'If'), steps: p.steps, kind: 'path'));
      }
      final o = b.otherwise;
      if (o != null) slots.add(UiWfSlot(slot: 'otherwise', label: _or(o.label, 'Otherwise'), steps: o.steps, kind: 'otherwise'));
    case 'switch':
      final s = UiWfSwitchStep.of(step);
      for (final c in s.cases) {
        slots.add(UiWfSlot(slot: 'case:${c.id}', label: c.label, steps: c.steps, kind: 'case'));
      }
      final o = s.otherwise;
      if (o != null) slots.add(UiWfSlot(slot: 'otherwise', label: _or(o.label, 'Otherwise'), steps: o.steps, kind: 'otherwise'));
    case 'parallel':
      for (final p in UiWfParallelStep.of(step).paths) {
        slots.add(UiWfSlot(slot: 'path:${p.id}', label: _or(p.label, 'Path'), steps: p.steps, kind: 'path'));
      }
    case 'forEach':
      slots.add(UiWfSlot(slot: 'each', label: 'For each item', steps: UiWfForEachStep.of(step).steps, kind: 'each'));
    case 'approval':
      final a = UiWfApprovalStep.of(step);
      slots.add(UiWfSlot(slot: 'outcome:approved', label: 'Approved', steps: a.outcome('approved'), kind: 'outcome', tone: 'success'));
      slots.add(UiWfSlot(slot: 'outcome:rejected', label: 'Rejected', steps: a.outcome('rejected'), kind: 'outcome', tone: 'danger'));
      slots.add(UiWfSlot(slot: 'outcome:timedOut', label: 'Out of time', steps: a.outcome('timedOut'), kind: 'timeout', tone: 'warning'));
    case 'task':
      final t = UiWfTaskStep.of(step);
      for (final o in t.outcomes) {
        slots.add(UiWfSlot(slot: 'outcome:${o.key}', label: o.label, steps: o.steps, kind: 'outcome', tone: o.tone));
      }
      slots.add(UiWfSlot(slot: 'onTimeout', label: 'Out of time', steps: t.onTimeout.steps, kind: 'timeout', tone: 'warning'));
    case 'wait':
      final u = UiWfWaitStep.of(step).until;
      if (u.json.containsKey('onTimeout') && u.onTimeout != null) {
        slots.add(UiWfSlot(slot: 'onTimeout', label: 'Timed out', steps: u.onTimeout!.steps, kind: 'timeout', tone: 'warning'));
      }
  }
  final errorSteps = step.onErrorSteps;
  if (errorSteps != null) slots.add(UiWfSlot(slot: 'error', label: 'If it fails', steps: errorSteps, kind: 'error', tone: 'danger'));
  return slots;
}

(String, String?) _splitSlot(String slot) {
  final i = slot.indexOf(':');
  if (i < 0) return (slot, null);
  final rest = slot.substring(i + 1);
  final j = rest.indexOf(':');
  return (slot.substring(0, i), j < 0 ? rest : rest.substring(0, j));
}

/// A copy of [step] whose list in [slot] is [steps].
UiWfStep withSlot(UiWfStep step, String slot, List<UiWfStep> steps) {
  final j = step.json;
  if (slot == 'error') return UiWfStep.fromJson({...j, 'onError': {'steps': steps}});
  final (kind, key) = _splitSlot(slot);
  List<Object?> mapItems(Object? list, String idKey, String? match) => [
    for (final x in (list is List ? list : const []))
      if (x is Map && wfStr(x[idKey]) == match) {...wfMap(x), 'steps': steps} else x,
  ];
  UiJson otherwise() => {...(wfMapOrNull(j['otherwise']) ?? {'id': wfId('l'), 'label': 'Otherwise'}), 'steps': steps};
  switch (step.type) {
    case 'branch':
      if (kind == 'otherwise') return UiWfStep.fromJson({...j, 'otherwise': otherwise()});
      return UiWfStep.fromJson({...j, 'paths': mapItems(j['paths'], 'id', key)});
    case 'switch':
      if (kind == 'otherwise') return UiWfStep.fromJson({...j, 'otherwise': otherwise()});
      return UiWfStep.fromJson({...j, 'cases': mapItems(j['cases'], 'id', key)});
    case 'parallel':
      return UiWfStep.fromJson({...j, 'paths': mapItems(j['paths'], 'id', key)});
    case 'forEach':
      return UiWfStep.fromJson({...j, 'steps': steps});
    case 'approval':
      return UiWfStep.fromJson({...j, 'outcomes': {...wfMap(j['outcomes']), key ?? '': steps}});
    case 'task':
      if (kind == 'onTimeout') return UiWfStep.fromJson({...j, 'onTimeout': {...wfMap(j['onTimeout']), 'steps': steps}});
      return UiWfStep.fromJson({...j, 'outcomes': mapItems(j['outcomes'], 'key', key)});
    case 'wait':
      final u = wfMap(j['until']);
      if (u.containsKey('onTimeout') && u['onTimeout'] is Map) {
        return UiWfStep.fromJson({...j, 'until': {...u, 'onTimeout': {...wfMap(u['onTimeout']), 'steps': steps}}});
      }
      return step;
  }
  return step;
}

/// A top-level step list of a definition.
class UiWfRootList {
  const UiWfRootList(this.id, this.label, this.steps);
  final String id;
  final String label;
  final List<UiWfStep> steps;
}

/// The top-level step lists of a definition.
List<UiWfRootList> rootLists(UiWorkflowDefinition def) {
  if (def.kind == 'automation') return [UiWfRootList('root', 'Steps', def.steps ?? const [])];
  final lc = def.lifecycle;
  if (lc == null) return const [];
  final out = <UiWfRootList>[];
  for (final s in lc.states) {
    if (s.onEnter != null) out.add(UiWfRootList('onEnter:${s.id}', 'On entering ${s.label}', s.onEnter!));
    if (s.onExit != null) out.add(UiWfRootList('onExit:${s.id}', 'On leaving ${s.label}', s.onExit!));
    if (s.sla != null) out.add(UiWfRootList('sla:${s.id}', 'When ${s.label} runs late', s.sla!.steps));
  }
  for (final t in lc.transitions) {
    if (t.steps != null) out.add(UiWfRootList('transition:${t.id}', 'After ${t.label}', t.steps!));
  }
  final reset = lc.reset;
  if (reset?.steps != null) out.add(UiWfRootList('reset', 'On ${reset!.label ?? 'reset'}', reset.steps!));
  return out;
}

class UiWfStepLocation {
  const UiWfStepLocation({required this.step, required this.listId, required this.index, required this.parentId, required this.path});
  final UiWfStep step;
  final String listId;
  final int index;

  /// The step holding the list, or null for a top-level list.
  final String? parentId;

  /// Every list on the way from the top, outermost first (the step's own list last).
  final List<String> path;
}

/// Every step with where it sits, in document order.
Map<String, UiWfStepLocation> indexSteps(UiWorkflowDefinition def) {
  final map = <String, UiWfStepLocation>{};
  void walk(String listId, List<UiWfStep> steps, String? parentId, List<String> path) {
    final here = [...path, listId];
    for (var index = 0; index < steps.length; index++) {
      final step = steps[index];
      map.putIfAbsent(step.id, () => UiWfStepLocation(step: step, listId: listId, index: index, parentId: parentId, path: here));
      for (final s in stepSlots(step)) {
        walk('${step.id}/${s.slot}', s.steps, step.id, here);
      }
    }
  }

  for (final l in rootLists(def)) {
    walk(l.id, l.steps, null, const []);
  }
  return map;
}

/// The steps in a list, or null if the list does not exist.
List<UiWfStep>? listSteps(UiWorkflowDefinition def, String listId) {
  for (final l in rootLists(def)) {
    if (l.id == listId) return l.steps;
  }
  final slash = listId.indexOf('/');
  if (slash < 0) return null;
  final owner = indexSteps(def)[listId.substring(0, slash)];
  if (owner == null) return null;
  final slot = listId.substring(slash + 1);
  for (final s in stepSlots(owner.step)) {
    if (s.slot == slot) return s.steps;
  }
  return null;
}

typedef UiWfListMapper = List<UiWfStep> Function(String listId, List<UiWfStep> steps);

/// Rebuilds every list (bottom-up), letting [f] replace any of them. Return the list you were given
/// to leave it; untouched lists and steps keep their identity.
UiWorkflowDefinition mapLists(UiWorkflowDefinition def, UiWfListMapper f) {
  List<UiWfStep> mapList(String listId, List<UiWfStep> steps) {
    var changed = false;
    final next = <UiWfStep>[];
    for (final step in steps) {
      var s = step;
      for (final slot in stepSlots(step)) {
        final inner = mapList('${step.id}/${slot.slot}', slot.steps);
        if (!identical(inner, slot.steps)) s = withSlot(s, slot.slot, inner);
      }
      if (!identical(s, step)) changed = true;
      next.add(s);
    }
    return f(listId, changed ? next : steps);
  }

  if (def.kind == 'automation') {
    final before = def.steps ?? <UiWfStep>[];
    final steps = mapList('root', before);
    return identical(steps, before) ? def : UiWorkflowDefinition.fromJson({...def.json, 'steps': steps});
  }
  final lc = def.lifecycle;
  if (lc == null) return def;
  var lcChanged = false;
  final states = <Object?>[];
  for (final s in lc.states) {
    var n = s.json;
    final onEnter = s.onEnter;
    if (onEnter != null) {
      final l = mapList('onEnter:${s.id}', onEnter);
      if (!identical(l, onEnter)) n = {...n, 'onEnter': l};
    }
    final onExit = s.onExit;
    if (onExit != null) {
      final l = mapList('onExit:${s.id}', onExit);
      if (!identical(l, onExit)) n = {...n, 'onExit': l};
    }
    final sla = s.sla;
    if (sla != null) {
      final before = sla.steps;
      final l = mapList('sla:${s.id}', before);
      if (!identical(l, before)) n = {...n, 'sla': {...sla.json, 'steps': l}};
    }
    if (!identical(n, s.json)) lcChanged = true;
    states.add(n);
  }
  final transitions = <Object?>[];
  for (final t in lc.transitions) {
    final steps = t.steps;
    if (steps == null) {
      transitions.add(t.json);
      continue;
    }
    final l = mapList('transition:${t.id}', steps);
    if (identical(l, steps)) {
      transitions.add(t.json);
      continue;
    }
    lcChanged = true;
    transitions.add({...t.json, 'steps': l});
  }
  Object? reset = lc.json['reset'];
  final resetSteps = lc.reset?.steps;
  if (resetSteps != null) {
    final l = mapList('reset', resetSteps);
    if (!identical(l, resetSteps)) {
      reset = {...lc.reset!.json, 'steps': l};
      lcChanged = true;
    }
  }
  return lcChanged
      ? UiWorkflowDefinition.fromJson({...def.json, 'lifecycle': {...lc.json, 'states': states, 'transitions': transitions, 'reset': ?reset}})
      : def;
}

/// Replaces one step (found anywhere) with `f(step)`.
UiWorkflowDefinition updateStep(UiWorkflowDefinition def, String id, UiWfStep Function(UiWfStep s) f) => mapLists(def, (_, steps) {
  final i = steps.indexWhere((s) => s.id == id);
  if (i < 0) return steps;
  return [...steps]..[i] = f(steps[i]);
});

/// Ensures a lifecycle list exists (e.g. a transition's "then do" list) so steps can be added to it.
UiWorkflowDefinition ensureList(UiWorkflowDefinition def, String listId) {
  final lc = def.lifecycle;
  if (listSteps(def, listId) != null || lc == null) return def;
  if (listId == 'reset') {
    final reset = lc.reset;
    return reset == null ? def : UiWorkflowDefinition.fromJson({...def.json, 'lifecycle': {...lc.json, 'reset': {...reset.json, 'steps': reset.steps ?? <UiWfStep>[]}}});
  }
  final (kind, id) = _splitSlot(listId);
  if (kind == 'transition') {
    return UiWorkflowDefinition.fromJson({
      ...def.json,
      'lifecycle': {
        ...lc.json,
        'transitions': [for (final t in lc.transitions) t.id == id ? {...t.json, 'steps': t.steps ?? <UiWfStep>[]} : t.json],
      },
    });
  }
  return UiWorkflowDefinition.fromJson({
    ...def.json,
    'lifecycle': {
      ...lc.json,
      'states': [
        for (final s in lc.states)
          if (s.id != id)
            s.json
          else if (kind == 'onEnter')
            {...s.json, 'onEnter': s.onEnter ?? <UiWfStep>[]}
          else if (kind == 'onExit')
            {...s.json, 'onExit': s.onExit ?? <UiWfStep>[]}
          else if (kind == 'sla')
            {...s.json, 'sla': s.sla?.json ?? {'within': 'P2D', 'steps': <UiWfStep>[]}}
          else
            s.json,
      ],
    },
  });
}

UiWorkflowDefinition insertStep(UiWorkflowDefinition def, String listId, int index, UiWfStep step) {
  final d = ensureList(def, listId);
  return mapLists(d, (id, steps) {
    if (id != listId) return steps;
    return [...steps]..insert(index.clamp(0, steps.length), step);
  });
}

UiWorkflowDefinition removeStep(UiWorkflowDefinition def, String id) =>
    mapLists(def, (_, steps) => steps.any((s) => s.id == id) ? steps.where((s) => s.id != id).toList() : steps);

/// Whether [listId] is inside step [stepId] (so the step cannot be dropped there).
bool isInsideStep(UiWorkflowDefinition def, String listId, String stepId) {
  if (listId.startsWith('$stepId/')) return true;
  final slash = listId.indexOf('/');
  if (slash < 0) return false;
  final owner = indexSteps(def)[listId.substring(0, slash)];
  return owner != null && (owner.step.id == stepId || owner.path.any((p) => p.startsWith('$stepId/')));
}

/// Moves a step to [index] in [listId] (index counted before removal, like a drop line).
UiWorkflowDefinition moveStep(UiWorkflowDefinition def, String id, String listId, int index) {
  final loc = indexSteps(def)[id];
  if (loc == null || isInsideStep(def, listId, id)) return def;
  if (loc.listId == listId && (index == loc.index || index == loc.index + 1)) return def;
  final adjusted = loc.listId == listId && index > loc.index ? index - 1 : index;
  return insertStep(removeStep(def, id), listId, adjusted, loc.step);
}

/// Steps a "Go back" step may jump to: earlier steps in its own list, then earlier steps around
/// each enclosing container, stopping at a parallel path or a loop body (a jump can't leave those).
List<UiWfStep> goToTargets(UiWorkflowDefinition def, String stepId) {
  final idx = indexSteps(def);
  final loc = idx[stepId];
  if (loc == null) return const [];
  final out = <UiWfStep>[];
  var listId = loc.listId;
  var index = loc.index;
  for (;;) {
    out.insertAll(0, (listSteps(def, listId) ?? const <UiWfStep>[]).take(index));
    final slash = listId.indexOf('/');
    if (slash < 0) break;
    final owner = idx[listId.substring(0, slash)];
    if (owner == null || owner.step.type == 'parallel' || owner.step.type == 'forEach') break;
    listId = owner.listId;
    index = owner.index;
  }
  return out;
}

/// A deep copy of a step with fresh ids everywhere inside it.
UiWfStep cloneStep(UiWfStep step) {
  Object? fresh(Object? x, [String? key]) {
    if (x is List) return [for (final v in x) fresh(v)];
    if (x is Map) {
      final o = <String, Object?>{for (final e in wfMap(x).entries) e.key: fresh(e.value, e.key)};
      // Steps, paths, cases, outcomes and step lists carry ids; forms (`schemaVersion`) keep theirs.
      if (o['id'] is String && !o.containsKey('schemaVersion') && key != 'form') {
        final prefix = (o['id'] as String).split('_').first;
        o['id'] = wfId(prefix.isEmpty ? 'x' : prefix);
      }
      return o;
    }
    return x;
  }

  final copy = UiWfStep.fromJson(fresh(step.json));
  // Steps inside the copy that read each other (tokens, go-back targets) now point at the copies.
  final ids = <String, String>{};
  void pair(UiWfStep a, UiWfStep b) {
    ids[a.id] = b.id;
    final sa = stepSlots(a), sb = stepSlots(b);
    for (var i = 0; i < sa.length; i++) {
      for (var j = 0; j < sa[i].steps.length; j++) {
        pair(sa[i].steps[j], sb[i].steps[j]);
      }
    }
  }

  pair(step, copy);
  var json = jsonEncode(copy.json);
  for (final e in ids.entries) {
    json = json.replaceAll('steps.${e.key}.', 'steps.${e.value}.').replaceAll('"target":"${e.key}"', '"target":"${e.value}"');
  }
  final out = wfMap(jsonDecode(json));
  out['title'] = '${stepName(step)} (copy)';
  return UiWfStep.fromJson(out);
}

/// Duplicates a step right after itself; the copy's id, or null when the step wasn't found.
({UiWorkflowDefinition def, String? id}) duplicateStep(UiWorkflowDefinition def, String id) {
  final loc = indexSteps(def)[id];
  if (loc == null) return (def: def, id: null);
  final copy = cloneStep(loc.step);
  return (def: insertStep(def, loc.listId, loc.index + 1, copy), id: copy.id);
}

/// Steps (anywhere) that refer to step [id] through a token or a go-back.
List<UiWfStep> stepReferences(UiWorkflowDefinition def, String id) {
  final out = <UiWfStep>[];
  final needle = 'steps.$id.';
  for (final loc in indexSteps(def).values) {
    final step = loc.step;
    if (step.id == id) continue;
    final json = jsonEncode(step.json);
    if (json.contains('"$needle') || json.contains('"ref":"$needle') || (step.type == 'goTo' && UiWfGoToStep.of(step).target == id)) out.add(step);
  }
  return out;
}

// ── Registry helpers ────────────────────────────────────────────────────────────────────────

UiWfEntityDescriptor? entityOf(UiWorkflowRegistry? reg, String? key) =>
    key == null || key.isEmpty ? null : reg?.entities.where((e) => e.key == key).firstOrNull;

UiWfFieldDescriptor? fieldOf(UiWorkflowRegistry? reg, String? entity, String? field) =>
    field == null || field.isEmpty ? null : entityOf(reg, entity)?.fields.where((f) => f.key == field).firstOrNull;

/// The form-builder value kind of a registry field, for choosing condition operators.
UiFbValueKind valueKindOfField(String? type) => switch (type) {
  'number' || 'currency' => UiFbValueKind.number,
  'date' || 'dateTime' => UiFbValueKind.date,
  'enum' || 'user' || 'relation' => UiFbValueKind.choice,
  'boolean' => UiFbValueKind.boolean,
  'collection' => UiFbValueKind.multi,
  _ => UiFbValueKind.text,
};

/// Shows a stored value the way people recognise it (an option's label). The web `optionLabel`;
/// renamed here because the form engine already exports an `optionLabel`.
String wfOptionLabel(UiWfFieldDescriptor? field, Object? value) => wfOptionLabelIn(field?.options, value);

/// [optionLabel] over a list of options.
String wfOptionLabelIn(List<UiWfFieldOption>? options, Object? value) {
  if (value == null || value == '') return '…';
  final o = options?.where((x) => jsString(x.value) == jsString(value)).firstOrNull;
  if (o != null) return o.label;
  if (value is bool) return value ? 'Yes' : 'No';
  return jsString(value);
}

// ── Tokens (values steps can read) ──────────────────────────────────────────────────────────

/// A value a step can read, for pickers.
class UiWfToken {
  const UiWfToken({required this.path, required this.label, required this.group, required this.type, this.options, this.entity});
  final String path;
  final String label;

  /// The group it is listed under: "Application", "Trigger", "Approval: Finance sign-off"…
  final String group;

  /// A registry field type, or `any`.
  final String type;
  final List<UiWfFieldOption>? options;
  final String? entity;
}

/// Where a value is used: a step (tokens upstream of it) or a list position.
class UiWfAt {
  const UiWfAt.step(String this.stepId) : listId = null, index = 0;
  const UiWfAt.list(String this.listId, this.index) : stepId = null;
  final String? stepId;
  final String? listId;
  final int index;
}

/// A question of a form whose answers are `input.*`.
typedef UiWfInputField = ({String key, String label});

/// The questions of a form (fields on every page, inside groups too), as answer keys and labels.
List<UiWfInputField> wfFormFields(UiJson? form) {
  final out = <UiWfInputField>[];
  void walk(Object? els, String prefix) {
    if (els is! List) return;
    for (final e in els) {
      if (e is! Map) continue;
      final key = e['key'];
      if (e['kind'] == 'field' && key is String) {
        final label = e['label'];
        out.add((key: '$prefix$key', label: label is String && label.isNotEmpty ? label : key));
      } else if (e['kind'] == 'group') {
        walk(e['elements'], key is String && key.isNotEmpty ? '$prefix$key.' : prefix);
      }
    }
  }

  final pages = form?['pages'];
  if (pages is List) {
    for (final page in pages) {
      if (page is Map) walk(page['elements'], '');
    }
  }
  return out;
}

/// The form answers (`input.*`) steps at a position can read: the transition's or the reset's form.
List<UiWfInputField> _inputFieldsAt(UiWorkflowDefinition def, UiWfAt? at) {
  final lc = def.lifecycle;
  if (at == null || lc == null) return const [];
  final idx = indexSteps(def);
  final listId = at.listId;
  // The top-level list the position is in (a nested list belongs to the step that holds it).
  final root = at.stepId != null
      ? idx[at.stepId]?.path.first
      : listId == null
          ? null
          : listId.contains('/')
              ? idx[listId.split('/').first]?.path.first
              : listId;
  if (root == null) return const [];
  if (root == 'reset') return wfFormFields(lc.reset?.inputForm);
  if (root.startsWith('transition:')) {
    final id = root.substring('transition:'.length);
    return wfFormFields(lc.transitions.where((t) => t.id == id).firstOrNull?.inputForm);
  }
  return const [];
}

const List<String> _fieldTypesForPickers = ['text', 'longText', 'email', 'phone', 'url', 'number', 'currency', 'boolean', 'date', 'dateTime', 'enum', 'user', 'relation', 'json'];

List<UiWfToken> _entityTokens(UiWorkflowRegistry? reg, String entityKey, String prefix, String group, [int depth = 0]) {
  final e = entityOf(reg, entityKey);
  if (e == null) return const [];
  final out = <UiWfToken>[];
  for (final f in e.fields) {
    if (!f.readable || !_fieldTypesForPickers.contains(f.type)) continue;
    out.add(UiWfToken(path: '$prefix.${f.key}', label: f.label, group: group, type: f.type, options: f.options, entity: f.entity));
    if (f.type == 'relation' && f.entity != null && depth < 1) out.addAll(_entityTokens(reg, f.entity!, '$prefix.${f.key}', '$group › ${f.label}', depth + 1));
  }
  return out;
}

/// Steps upstream of a position: earlier in the same list, and earlier around every enclosing container.
List<UiWfStep> upstreamSteps(UiWorkflowDefinition def, UiWfAt? at) {
  if (at == null) return const [];
  final idx = indexSteps(def);
  String listId;
  int index;
  if (at.stepId != null) {
    final loc = idx[at.stepId];
    if (loc == null) return const [];
    listId = loc.listId;
    index = loc.index;
  } else {
    listId = at.listId!;
    index = at.index;
  }
  final out = <UiWfStep>[];
  for (;;) {
    final steps = listSteps(def, listId) ?? const <UiWfStep>[];
    out.insertAll(0, steps.take(index));
    final slash = listId.indexOf('/');
    if (slash < 0) break;
    final owner = idx[listId.substring(0, slash)];
    if (owner == null) break;
    // The container itself has run (its outputs are available inside its lists); parallel paths
    // and loop bodies don't see their siblings.
    out.add(owner.step);
    listId = owner.listId;
    index = owner.index;
  }
  return out;
}

/// Everything a value can be read from at a position, grouped for a picker. [outputs] are the
/// outputs per step type as the engine reports them (`GET /schema`); [inputFields] are the form
/// answers (`input.*`) available here.
List<UiWfToken> tokensAt(UiWorkflowDefinition def, UiWorkflowRegistry? reg, {Map<String, List<String>>? outputs, UiWfAt? at, List<UiWfInputField>? inputFields}) {
  final tokens = <UiWfToken>[];
  final entity = entityOf(reg, def.entity);
  if (entity != null) {
    tokens.add(UiWfToken(path: 'entity.id', label: '${entity.label} id', group: entity.label, type: 'text'));
    tokens.addAll(_entityTokens(reg, entity.key, 'entity', entity.label));
  }
  final trig = def.trigger;
  if (def.kind == 'automation' && trig != null) {
    if (trig.type == 'fieldChanged' && (trig.field ?? '').isNotEmpty) {
      final f = fieldOf(reg, def.entity, trig.field);
      tokens.add(UiWfToken(path: 'trigger.from', label: '${f?.label ?? trig.field} before', group: 'What started it', type: f?.type ?? 'any', options: f?.options));
      tokens.add(UiWfToken(path: 'trigger.to', label: '${f?.label ?? trig.field} after', group: 'What started it', type: f?.type ?? 'any', options: f?.options));
    }
    if (trig.type == 'stateEntered' || trig.type == 'transitionApplied') {
      tokens.addAll(const [
        UiWfToken(path: 'trigger.from', label: 'State before', group: 'What started it', type: 'text'),
        UiWfToken(path: 'trigger.to', label: 'State after', group: 'What started it', type: 'text'),
        UiWfToken(path: 'trigger.transition', label: 'Transition', group: 'What started it', type: 'text'),
        UiWfToken(path: 'trigger.comment', label: 'Remarks', group: 'What started it', type: 'text'),
      ]);
    }
    if (trig.type == 'signal') {
      final sig = reg?.signals?.where((s) => s.key == trig.signal).firstOrNull;
      for (final f in sig?.fields ?? const <UiWfParamDescriptor>[]) {
        tokens.add(UiWfToken(path: 'trigger.data.${f.key}', label: f.label, group: sig!.label, type: f.type, options: f.options));
      }
    }
  } else if (def.kind == 'lifecycle') {
    tokens.addAll(const [
      UiWfToken(path: 'trigger.from', label: 'State before', group: 'The move', type: 'text'),
      UiWfToken(path: 'trigger.to', label: 'State after', group: 'The move', type: 'text'),
      UiWfToken(path: 'trigger.transition', label: 'Transition', group: 'The move', type: 'text'),
      UiWfToken(path: 'trigger.comment', label: 'Remarks', group: 'The move', type: 'text'),
    ]);
  }
  tokens.addAll(const [
    UiWfToken(path: 'trigger.actor', label: 'Person who started it', group: 'What started it', type: 'user'),
    UiWfToken(path: 'trigger.at', label: 'When it started', group: 'What started it', type: 'dateTime'),
  ]);
  for (final f in inputFields ?? _inputFieldsAt(def, at)) {
    tokens.add(UiWfToken(path: 'input.${f.key}', label: f.label, group: 'Form answers', type: 'any'));
  }
  // Inside a forEach, the current item.
  if (at != null) {
    final idx = indexSteps(def);
    final listId = at.stepId != null ? idx[at.stepId]?.listId : at.listId;
    final path = listId != null ? [...(at.stepId != null ? idx[at.stepId]?.path ?? const <String>[] : const <String>[]), listId] : const <String>[];
    for (final l in path) {
      final slash = l.indexOf('/');
      if (slash < 0 || l.substring(slash + 1) != 'each') continue;
      final fe = idx[l.substring(0, slash)]?.step;
      if (fe == null || fe.type != 'forEach') continue;
      final coll = collectionField(reg, def.entity, UiWfForEachStep.of(fe).collection);
      if (coll?.entity != null) {
        final label = entityOf(reg, coll!.entity)?.label ?? 'Item';
        final group = 'Current ${label.toLowerCase()}';
        tokens.add(UiWfToken(path: 'item.id', label: '$label id', group: group, type: 'text'));
        tokens.add(UiWfToken(path: 'item.index', label: 'Position (from 0)', group: group, type: 'number'));
        tokens.addAll(_entityTokens(reg, coll.entity!, 'item', group));
      }
    }
  }
  for (final s in upstreamSteps(def, at)) {
    final outs = s.type == 'action'
        ? [...?reg?.actions?.where((a) => a.key == UiWfActionStep.of(s).action).firstOrNull?.outputs.map((o) => o.key)]
        : outputs?[s.type] ?? stepInfo(s.type).outputs;
    for (final o in outs) {
      tokens.add(UiWfToken(path: 'steps.${s.id}.$o', label: _outputLabel(s, o, reg), group: stepName(s), type: o == 'decidedBy' ? 'user' : s.type == 'createRecord' && o == 'id' ? 'text' : 'any'));
    }
  }
  for (final v in def.variables ?? const <UiWfVariable>[]) {
    tokens.add(UiWfToken(path: 'vars.${v.key}', label: v.label, group: 'Variables', type: v.type == 'json' ? 'json' : v.type));
  }
  tokens.addAll(const [
    UiWfToken(path: 'today', label: 'Today', group: 'Time', type: 'date'),
    UiWfToken(path: 'now', label: 'Now', group: 'Time', type: 'dateTime'),
  ]);
  return tokens;
}

const Map<String, String> _outputWords = {
  'outcome': 'Outcome', 'decidedBy': 'Decided by', 'comments': 'Comments', 'comment': 'Comment', 'data': 'Answers', 'path': 'Path taken', 'case': 'Case taken',
  'completed': 'Paths finished', 'count': 'Count', 'timedOut': 'Timed out', 'applied': 'Applied', 'sent': 'Messages sent', 'status': 'Status code', 'body': 'Response',
  'instanceId': 'Run id', 'outputs': 'Results', 'error': 'Error',
};

String _outputLabel(UiWfStep step, String output, UiWorkflowRegistry? reg) {
  if (step.type == 'action') {
    return reg?.actions?.where((a) => a.key == UiWfActionStep.of(step).action).firstOrNull?.outputs.where((o) => o.key == output).firstOrNull?.label ?? output;
  }
  if (step.type == 'createRecord' && output == 'id') return 'New ${entityOf(reg, UiWfCreateRecordStep.of(step).entity)?.label.toLowerCase() ?? 'record'} id';
  return _outputWords[output] ?? output;
}

/// The registry field a collection path (`entity.documents`, `entity.programme.courses`) ends at.
UiWfFieldDescriptor? collectionField(UiWorkflowRegistry? reg, String? entity, String path) {
  final parts = path.split('.');
  if (parts[0] != 'entity' || parts.length < 2) return null;
  var e = entity;
  UiWfFieldDescriptor? f;
  for (var i = 1; i < parts.length; i++) {
    f = fieldOf(reg, e, parts[i]);
    if (f == null) return null;
    e = f.entity;
  }
  return f?.type == 'collection' ? f : null;
}

/// A collection the record has (for forEach).
typedef UiWfCollection = ({String path, String label, String entity});

/// Collections the record has (for forEach).
List<UiWfCollection> collectionsOf(UiWorkflowRegistry? reg, String? entity) {
  final e = entityOf(reg, entity);
  if (e == null) return const [];
  final out = <UiWfCollection>[];
  for (final f in e.fields) {
    if (f.type == 'collection' && f.entity != null) out.add((path: 'entity.${f.key}', label: f.label, entity: f.entity!));
    if (f.type == 'relation' && f.entity != null) {
      for (final g in entityOf(reg, f.entity)?.fields ?? const <UiWfFieldDescriptor>[]) {
        if (g.type == 'collection' && g.entity != null) out.add((path: 'entity.${f.key}.${g.key}', label: '${f.label} › ${g.label}', entity: g.entity!));
      }
    }
  }
  return out;
}

/// A token's label for display: "Application › Status".
String tokenLabel(List<UiWfToken> tokens, String path) {
  final t = tokens.where((x) => x.path == path).firstOrNull;
  if (t != null) return t.group == 'Time' || t.group == 'Variables' ? t.label : '${t.group} › ${t.label}';
  return path;
}

// ── Plain-English summaries ─────────────────────────────────────────────────────────────────

class UiWfDescribeContext {
  const UiWfDescribeContext({required this.registry, required this.def, this.tokens, this.workflowTitle, this.userName, this.lifecycle});
  final UiWorkflowRegistry? registry;
  final UiWorkflowDefinition def;
  final List<UiWfToken>? tokens;

  /// Other workflows' titles by key (for sub-workflows and lifecycle triggers).
  final String? Function(String key)? workflowTitle;
  final String? Function(String id)? userName;

  /// Another lifecycle's published definition by key, when loaded (names its states and transitions).
  final UiWorkflowDefinition? Function(String key)? lifecycle;
}

final RegExp _duration = RegExp(r'^(-)?P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$');

/// `P2DT3H` → "2 days 3 hours"; `-P1W` → "1 week before".
String describeDuration(String? iso) {
  if (iso == null || iso.isEmpty) return 'no time set';
  final m = _duration.firstMatch(iso);
  if (m == null) return iso;
  final parts = <String>[];
  void add(String? n, String unit) {
    final v = n == null ? 0 : int.parse(n);
    if (v != 0) parts.add('$v $unit${v == 1 ? '' : 's'}');
  }

  add(m.group(2), 'year');
  add(m.group(3), 'month');
  add(m.group(4), 'week');
  add(m.group(5), 'day');
  add(m.group(6), 'hour');
  add(m.group(7), 'minute');
  add(m.group(8), 'second');
  final text = parts.isNotEmpty ? parts.join(' ') : 'no time';
  return m.group(1) != null ? '$text before' : text;
}

/// "Finance and whoever started it".
String describeAssignees(List<UiWfAssignee>? list, UiWfDescribeContext ctx) {
  if (list == null || list.isEmpty) return 'nobody yet';
  final names = [
    for (final a in list)
      switch (a.kind) {
        'role' => ctx.registry?.roles?.where((r) => r.key == a.value).firstOrNull?.label ?? a.value,
        'group' => ctx.registry?.groups?.where((g) => g.key == a.value).firstOrNull?.label ?? a.value,
        'user' => ctx.userName?.call(a.value) ?? a.value,
        'field' => ctx.tokens != null ? tokenLabel(ctx.tokens!, a.value) : a.value,
        'managerOf' => a.value == 'initiator'
            ? 'manager of whoever started it'
            : a.value == 'assignees'
            ? 'their managers'
            : 'manager of ${ctx.tokens != null ? tokenLabel(ctx.tokens!, a.value) : a.value}',
        'initiator' => 'whoever started it',
        'email' => a.email!.isText ? a.email!.json as String : templateText(a.email, ctx.tokens),
        _ => '?',
      },
  ];
  return names.length > 2 ? '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}' : names.join(' and ');
}

/// A template as text, tokens as `[Group › Label]`.
String templateText(UiWfTemplate? t, [List<UiWfToken>? tokens]) {
  if (t == null) return '';
  if (t.isText) return t.json as String;
  return t.parts.map((p) => p is UiWfTemplateRef ? '[${tokens != null ? tokenLabel(tokens, p.ref) : p.ref}]' : p as String).join();
}

/// "When Status changes to Submitted".
String describeTrigger(UiWfTrigger? t, UiWfDescribeContext ctx) {
  if (t == null) return 'Choose what starts this workflow';
  final e = entityOf(ctx.registry, ctx.def.entity);
  final rec = e?.label.toLowerCase() ?? 'record';
  final aRec = '${RegExp('^[aeiou]').hasMatch(rec) ? 'an' : 'a'} $rec';
  final f = fieldOf(ctx.registry, ctx.def.entity, t.field);
  String vals(List<Object?>? v) => (v ?? const []).map((x) => wfOptionLabel(f, x)).join(' or ');
  String lifecycleName() => ctx.workflowTitle?.call(t.lifecycle ?? '') ?? t.lifecycle ?? 'a lifecycle';
  switch (t.type) {
    case 'created':
      return 'When $aRec is created';
    case 'deleted':
      return 'When $aRec is deleted';
    case 'fieldChanged':
      if ((t.field ?? '').isEmpty) return 'When $aRec changes';
      final from = t.from;
      final to = t.to;
      return 'When ${f?.label ?? t.field} ${from != null && from.isNotEmpty ? 'changes from ${vals(from)} ' : 'changes '}${to != null && to.isNotEmpty ? 'to ${vals(to)}' : ''}'.trim();
    case 'stateEntered':
      final known = ctx.lifecycle?.call(t.lifecycle ?? '')?.lifecycle?.states ?? const <UiWfState>[];
      final states = [for (final k in t.states ?? const <String>[]) known.where((s) => s.key == k).firstOrNull?.label ?? k].join(' or ');
      return 'When ${lifecycleName()} enters ${states.isEmpty ? '…' : states}';
    case 'transitionApplied':
      final moves = ctx.lifecycle?.call(t.lifecycle ?? '')?.lifecycle?.transitions ?? const <UiWfTransition>[];
      final ts = [for (final k in t.transitions ?? const <String>[]) '“${moves.where((m) => m.key == k).firstOrNull?.label ?? k}”'].join(' or ');
      return 'After ${ts.isEmpty ? '…' : ts} in ${lifecycleName()}';
    case 'dateReached':
      return '${describeDuration(t.offset)} ${f?.label ?? t.field ?? 'a date'}'.replaceFirst(RegExp(r'^no time set '), 'On ');
    case 'schedule':
      return 'On a schedule (${t.cron ?? '…'})${t.forEach != null ? ' for each matching $rec' : ''}';
    case 'manual':
      return 'When someone presses “${_or(t.label, 'Start')}”';
    case 'signal':
      return 'When the app reports ${ctx.registry?.signals?.where((s) => s.key == t.signal).firstOrNull?.label ?? t.signal ?? '…'}';
  }
  return t.type;
}

/// One line about what a step does: "any of Finance · due in 3 days".
String describeStep(UiWfStep step, UiWfDescribeContext ctx) {
  final reg = ctx.registry;
  String tl(String path) => ctx.tokens != null ? tokenLabel(ctx.tokens!, path) : path;
  switch (step.type) {
    case 'approval':
      final a = UiWfApprovalStep.of(step);
      final v = a.ruleValue == null ? '?' : jsNumberToString(a.ruleValue!);
      final rule = switch (a.ruleType) { 'all' => 'all of', 'count' => '$v of', 'percent' => '$v% of', _ => 'any of' };
      return '$rule ${describeAssignees(a.assignees, ctx)} · due in ${describeDuration(a.due)}';
    case 'task':
      final t = UiWfTaskStep.of(step);
      return '${describeAssignees(t.assignees, ctx)} · due in ${describeDuration(t.due)}';
    case 'branch':
      final b = UiWfBranchStep.of(step);
      final n = b.paths.length;
      return '$n path${n == 1 ? '' : 's'}${b.otherwise != null ? ' and otherwise' : ''}';
    case 'switch':
      final s = UiWfSwitchStep.of(step);
      return s.on.isNotEmpty ? 'on ${tl(s.on)}' : 'Choose what to switch on';
    case 'parallel':
      final p = UiWfParallelStep.of(step);
      final when = switch (p.joinType) { 'all' => 'all finish', 'any' => 'the first finishes', _ => '${p.joinCount ?? '?'} finish' };
      return '${p.paths.length} paths · continue when $when';
    case 'forEach':
      final fe = UiWfForEachStep.of(step);
      final c = collectionsOf(reg, ctx.def.entity).where((x) => x.path == fe.collection).firstOrNull;
      return c != null ? 'each of ${c.label}${fe.mode == 'parallel' ? ', at the same time' : ''}' : 'Choose a list';
    case 'wait':
      final u = UiWfWaitStep.of(step).until;
      if (u.type == 'duration') return 'for ${describeDuration(u.duration)}${u.calendar == 'working' ? ' of working time' : ''}';
      if (u.type == 'date') {
        final d = u.date;
        return 'until ${d != null && d.isRef && ctx.tokens != null ? tokenLabel(ctx.tokens!, d.ref!) : 'a date'}${(u.offset ?? '').isNotEmpty ? ' (${describeDuration(u.offset)})' : ''}';
      }
      if (u.type == 'condition') return 'until a condition holds · at most ${describeDuration(u.timeout)}';
      final sig = u.signal ?? '';
      return 'for ${reg?.signals?.where((s) => s.key == sig).firstOrNull?.label ?? (sig.isNotEmpty ? sig : 'an event')}';
    case 'setFields':
      final values = UiWfSetFieldsStep.of(step).values;
      return values.isNotEmpty ? values.map((v) => fieldOf(reg, ctx.def.entity, v.field)?.label ?? v.field).join(', ') : 'Choose fields to change';
    case 'createRecord':
      final cr = UiWfCreateRecordStep.of(step);
      final e = entityOf(reg, cr.entity);
      if (e == null) return 'Choose what to create';
      return 'a new ${e.label.toLowerCase()}${cr.values.isNotEmpty ? ' with ${cr.values.map((v) => fieldOf(reg, e.key, v.field)?.label ?? v.field).join(', ')}' : ''}';
    case 'setVariables':
      final values = UiWfSetVariablesStep.of(step).values;
      return values.isNotEmpty ? values.map((v) => ctx.def.variables?.where((x) => x.id == v.variable).firstOrNull?.label ?? '?').join(', ') : 'Choose variables';
    case 'applyTransition':
      final a = UiWfApplyTransitionStep.of(step);
      return a.transition.isNotEmpty ? '${a.transition} in ${ctx.workflowTitle?.call(a.lifecycle) ?? a.lifecycle}' : 'Choose a transition';
    case 'notify':
      final n = UiWfNotifyStep.of(step);
      return '${reg?.channels?.where((c) => c.key == n.channel).firstOrNull?.label ?? n.channel} to ${describeAssignees(n.to, ctx)}';
    case 'webhook':
      final w = UiWfWebhookStep.of(step);
      return '${w.method} ${w.connection ?? w.url ?? ''}'.trim();
    case 'action':
      final a = UiWfActionStep.of(step);
      return reg?.actions?.where((x) => x.key == a.action).firstOrNull?.label ?? (a.action.isNotEmpty ? a.action : 'Choose an action');
    case 'subWorkflow':
      final s = UiWfSubWorkflowStep.of(step);
      return s.workflow.isNotEmpty ? '${ctx.workflowTitle?.call(s.workflow) ?? s.workflow}${s.wait ? ', and wait' : ''}' : 'Choose a workflow';
    case 'goTo':
      final g = UiWfGoToStep.of(step);
      if (g.target.isEmpty) return 'Choose a step';
      final t = indexSteps(ctx.def)[g.target]?.step;
      return 'to ${t != null ? stepName(t) : '?'} · up to ${g.maxTimes}×';
    case 'end':
      return UiWfEndStep.of(step).result == 'failed' ? 'as failed' : 'as finished';
  }
  return '';
}

// ── Lifecycle helpers ───────────────────────────────────────────────────────────────────────

/// Whether transition [t] can start from state [stateId].
bool transitionAllows(UiWorkflowDefinition def, UiWfTransition t, String stateId) {
  if (t.fromAny) {
    final s = def.lifecycle?.states.where((x) => x.id == stateId).firstOrNull;
    return s != null && s.category != 'terminal' && s.id != t.to;
  }
  return t.from.contains(stateId);
}

/// The states "from [stateId] onwards": that state and every state its moves lead to, without
/// passing through the reset's target (the starting state unless the reset says otherwise), so final
/// states are included and send-back loops to the start are not. In diagram order.
List<String> wfStatesFrom(UiWorkflowDefinition def, String stateId) {
  final lc = def.lifecycle;
  if (lc == null || !lc.states.any((s) => s.id == stateId)) return const [];
  final target = lc.reset?.to ?? lc.states.where((s) => s.category == 'initial').firstOrNull?.id;
  final seen = {stateId};
  final queue = [stateId];
  while (queue.isNotEmpty) {
    final at = queue.removeAt(0);
    for (final t in lc.transitions) {
      if (!transitionAllows(def, t, at) || seen.contains(t.to) || t.to == target) continue;
      seen.add(t.to);
      queue.add(t.to);
    }
  }
  return [for (final s in lc.states) if (seen.contains(s.id)) s.id];
}

UiWorkflowDefinition updateLifecycle(UiWorkflowDefinition def, UiWfLifecycle Function(UiWfLifecycle lc) f) {
  final lc = def.lifecycle;
  return lc != null ? UiWorkflowDefinition.fromJson({...def.json, 'lifecycle': f(lc).json}) : def;
}

/// Replaces a state with `f(state)`.
UiWorkflowDefinition updateStateWith(UiWorkflowDefinition def, String id, UiWfState Function(UiWfState s) f) =>
    updateLifecycle(def, (lc) => lc.patch({'states': [for (final s in lc.states) s.id == id ? f(s) : s]}));

/// Merges [patch] into a state (null values remove keys).
UiWorkflowDefinition updateState(UiWorkflowDefinition def, String id, UiJson patch) => updateStateWith(def, id, (s) => s.patch(patch));

/// Replaces a transition with `f(transition)`.
UiWorkflowDefinition updateTransitionWith(UiWorkflowDefinition def, String id, UiWfTransition Function(UiWfTransition t) f) =>
    updateLifecycle(def, (lc) => lc.patch({'transitions': [for (final t in lc.transitions) t.id == id ? f(t) : t]}));

/// Merges [patch] into a transition (null values remove keys).
UiWorkflowDefinition updateTransition(UiWorkflowDefinition def, String id, UiJson patch) => updateTransitionWith(def, id, (t) => t.patch(patch));

/// Removes a state with the transitions into and out of it.
UiWorkflowDefinition removeState(UiWorkflowDefinition def, String id) => updateLifecycle(def, (lc) {
  final layout = <String, Object?>{...?wfMapOrNull(lc.json['layout'])}..remove(id);
  final transitions = <Object?>[];
  for (final t in lc.transitions) {
    if (t.to == id) continue;
    if (t.fromAny) {
      transitions.add(t);
      continue;
    }
    final from = t.from.where((f) => f != id).toList();
    if (from.isEmpty) continue;
    transitions.add(t.patch({'from': from}));
  }
  return lc.patch({'states': lc.states.where((s) => s.id != id).toList(), 'transitions': transitions, 'layout': layout});
});
