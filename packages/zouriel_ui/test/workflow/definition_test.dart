import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

// Port of the web `definition.spec.ts`.

final registry = UiWorkflowRegistry.fromJson({
  'entities': [
    {
      'key': 'application', 'label': 'Application',
      'fields': [
        {'key': 'status', 'label': 'Status', 'type': 'enum', 'options': [{'value': 'Draft', 'label': 'Draft'}, {'value': 'Submitted', 'label': 'Submitted'}]},
        {'key': 'amount', 'label': 'Amount', 'type': 'currency'},
        {'key': 'documents', 'label': 'Documents', 'type': 'collection', 'entity': 'document'},
      ],
    },
    {'key': 'document', 'label': 'Document', 'fields': [{'key': 'name', 'label': 'Name', 'type': 'text'}, {'key': 'verified', 'label': 'Verified', 'type': 'boolean'}]},
  ],
});

UiWfStep step(String id, [String type = 'notify', UiJson more = const {}]) => UiWfStep.fromJson({...createStep(type).json, 'id': id, ...more});

/// root: a, b(branch: path p → [c], otherwise → [d]), e(parallel: p1 → [f], p2 → []), g
UiWorkflowDefinition sample() {
  final def = createWorkflow('automation', title: 'Sample', entity: 'application');
  final b = step('b', 'branch');
  final bj = {
    ...b.json,
    'paths': [{...UiWfBranchStep.of(b).paths[0].json, 'id': 'p', 'steps': [step('c')]}],
    'otherwise': {'id': 'o', 'label': 'Otherwise', 'steps': [step('d')]},
  };
  final e = {
    ...step('e', 'parallel').json,
    'paths': [
      {'id': 'p1', 'label': 'Path 1', 'steps': [step('f')]},
      {'id': 'p2', 'label': 'Path 2', 'steps': <Object?>[]},
    ],
  };
  return def.patch({'steps': [step('a'), bj, e, step('g')]});
}

List<String> ids(List<UiWfStep>? steps) => [for (final s in steps ?? const <UiWfStep>[]) s.id];

void main() {
  group('ids and keys', () {
    test('wfId is spec-valid and unique', () {
      final many = {for (var i = 0; i < 2000; i++) wfId('s')};
      expect(many.length, 2000);
      for (final id in many) {
        expect(id, matches(RegExp(r'^s_[A-Za-z0-9_-]+$')));
      }
    });

    test('wfKey camel-cases, strips accents, starts with a letter and avoids taken keys', () {
      expect(wfKey('Send reminder'), 'sendReminder');
      expect(wfKey('  Révision  finale! '), 'revisionFinale');
      expect(wfKey('2nd review'), 'k2ndReview');
      expect(wfKey('!!!'), 'item');
      expect(wfKey('Approve', ['approve', 'approve2']), 'approve3');
    });
  });

  group('creating', () {
    test('an automation starts with a field-change trigger and no steps', () {
      final d = createWorkflow('automation', title: 'Remind', entity: 'application');
      expect(d.specVersion, 1);
      expect(d.kind, 'automation');
      expect(d.entity, 'application');
      expect(d.trigger?.type, 'fieldChanged');
      expect(d.steps, isEmpty);
    });

    test('a lifecycle starts with a start state, a final state and a move between them', () {
      final d = createWorkflow('lifecycle');
      final [draft, done] = d.lifecycle!.states;
      expect([draft.category, done.category], ['initial', 'terminal']);
      final ts = d.lifecycle!.transitions;
      expect(ts, hasLength(1));
      expect(ts[0].from, [draft.id]);
      expect(ts[0].to, done.id);
    });

    test('every step type gets the lists it needs', () {
      expect(stepSlots(createStep('approval')).map((s) => s.slot), ['outcome:approved', 'outcome:rejected', 'outcome:timedOut']);
      expect(stepSlots(createStep('task')).map((s) => s.kind), ['outcome', 'timeout']);
      expect(stepSlots(createStep('parallel')), hasLength(2));
      expect(stepSlots(createStep('notify')), isEmpty);
    });

    test('every step type has a catalogue entry and creates a step of its type', () {
      for (final info in uiWfStepTypes) {
        final s = createStep(info.type);
        expect(s.type, info.type);
        expect(stepName(s), info.label);
      }
    });
  });

  group('step lists', () {
    test('indexes every step with its list, parent and path', () {
      final idx = indexSteps(sample());
      final a = idx['a']!;
      expect([a.listId, a.index, a.parentId, a.path], ['root', 0, null, ['root']]);
      final c = idx['c']!;
      expect([c.listId, c.index, c.parentId, c.path], ['b/path:p', 0, 'b', ['root', 'b/path:p']]);
      expect(idx['d']?.listId, 'b/otherwise');
      expect(idx['f']?.listId, 'e/path:p1');
    });

    test('finds lists by id', () {
      final d = sample();
      expect(ids(listSteps(d, 'root')), ['a', 'b', 'e', 'g']);
      expect(ids(listSteps(d, 'e/path:p2')), isEmpty);
      expect(listSteps(d, 'nope/path:x'), isNull);
    });

    test('withSlot replaces one nested list', () {
      final b = sample().steps![1];
      final next = withSlot(b, 'otherwise', [step('z')]);
      expect(ids(stepSlots(next).firstWhere((s) => s.slot == 'otherwise').steps), ['z']);
      expect(ids(stepSlots(next).firstWhere((s) => s.slot == 'path:p').steps), ['c']);
    });

    test('mapLists keeps untouched branches identical', () {
      final d = sample();
      expect(identical(mapLists(d, (_, s) => s), d), isTrue);
      final next = mapLists(d, (id, s) => id == 'b/path:p' ? [...s, step('x')] : s);
      expect(identical(next.steps![2], d.steps![2]), isTrue);
      expect(identical(next.steps![1], d.steps![1]), isFalse);
    });

    test('inserts, clamping the index', () {
      final d = insertStep(sample(), 'e/path:p2', 99, step('n'));
      expect(ids(listSteps(d, 'e/path:p2')), ['n']);
      expect(ids(listSteps(insertStep(d, 'root', -3, step('m')), 'root'))[0], 'm');
    });

    test('removes a step wherever it is', () {
      expect(indexSteps(removeStep(sample(), 'f')).containsKey('f'), isFalse);
      expect(indexSteps(removeStep(sample(), 'b')).containsKey('c'), isFalse);
    });

    test('moves within a list using drop-line indexes', () {
      final d = sample();
      expect(ids(listSteps(moveStep(d, 'a', 'root', 2), 'root')), ['b', 'a', 'e', 'g']);
      expect(ids(listSteps(moveStep(d, 'g', 'root', 0), 'root')), ['g', 'a', 'b', 'e']);
      // Dropping right above or below itself changes nothing.
      expect(identical(moveStep(d, 'b', 'root', 1), d), isTrue);
      expect(identical(moveStep(d, 'b', 'root', 2), d), isTrue);
    });

    test('moves into another branch, but never into itself', () {
      final d = moveStep(sample(), 'a', 'b/otherwise', 1);
      expect(ids(listSteps(d, 'b/otherwise')), ['d', 'a']);
      expect(isInsideStep(sample(), 'b/path:p', 'b'), isTrue);
      final s = sample();
      expect(identical(moveStep(s, 'b', 'b/path:p', 0), s), isTrue);
    });

    test('a lifecycle list is created on first use', () {
      final d = createWorkflow('lifecycle');
      final t = d.lifecycle!.transitions[0];
      expect(listSteps(d, 'transition:${t.id}'), isNull);
      final next = insertStep(d, 'transition:${t.id}', 0, step('x'));
      expect(ids(listSteps(next, 'transition:${t.id}')), ['x']);
      final st = d.lifecycle!.states[0];
      expect(ensureList(d, 'sla:${st.id}').lifecycle!.states[0].sla!.json, {'within': 'P2D', 'steps': <Object?>[]});
    });

    test('duplicates with fresh ids everywhere inside, placed right after', () {
      final r = duplicateStep(sample(), 'b');
      expect(ids(listSteps(r.def, 'root')), ['a', 'b', r.id, 'e', 'g']);
      final copy = indexSteps(r.def)[r.id]!.step;
      final inner = [for (final s in stepSlots(copy)) ...ids(s.steps)];
      expect(inner, isNot(contains('c')));
      expect(inner, hasLength(2));
    });

    test('cloneStep keeps embedded form ids and marks the title', () {
      final s = step('t', 'task', {'title': 'Check', 'form': {'schemaVersion': 1, 'id': 'form1', 'elements': <Object?>[]}});
      final c = cloneStep(s);
      expect((c.json['form'] as Map)['id'], 'form1');
      expect(c.title, 'Check (copy)');
      expect(c.id, isNot('t'));
    });
  });

  group('what a step can see', () {
    test('upstream steps: earlier in the list, enclosing containers, never parallel siblings', () {
      final d = sample();
      expect(ids(upstreamSteps(d, const UiWfAt.step('g'))), ['a', 'b', 'e']);
      expect(ids(upstreamSteps(d, const UiWfAt.step('c'))), ['a', 'b']);
      expect(ids(upstreamSteps(d, const UiWfAt.list('e/path:p2', 0))), ['a', 'b', 'e']);
    });

    test('go back targets stop at a parallel path', () {
      final d = insertStep(sample(), 'e/path:p1', 1, step('back', 'goTo'));
      expect(ids(goToTargets(d, 'back')), ['f']);
      final top = insertStep(sample(), 'b/path:p', 1, step('back', 'goTo'));
      expect(ids(goToTargets(top, 'back')), ['a', 'c']);
    });

    test('tokens include the record, the trigger, upstream outputs and the loop item', () {
      var d = sample();
      d = d.patch({'trigger': {'type': 'fieldChanged', 'field': 'status'}});
      d = insertStep(d, 'root', 4, step('loop', 'forEach', {'collection': 'entity.documents'}));
      d = insertStep(d, 'loop/each', 0, step('inside'));
      final paths = [for (final t in tokensAt(d, registry, at: const UiWfAt.step('inside'))) t.path];
      expect(paths, containsAll(['entity.amount', 'trigger.from', 'trigger.to', 'item.name', 'item.verified', 'steps.b.path', 'steps.loop.count', 'today']));
      expect(paths, isNot(contains('steps.inside.sent')));
      expect([for (final t in tokensAt(d, registry, at: const UiWfAt.step('a'))) t.path], isNot(contains('item.name')));
    });

    test('finds steps that refer to another step', () {
      var d = sample();
      d = insertStep(d, 'root', 4, step('n', 'notify', {'subject': ['Path: ', {'ref': 'steps.b.path'}]}));
      d = insertStep(d, 'root', 5, step('j', 'goTo', {'target': 'a'}));
      expect(ids(stepReferences(d, 'b')), ['n']);
      expect(ids(stepReferences(d, 'a')), ['j']);
    });
  });

  group('summaries', () {
    test('durations read naturally', () {
      expect(describeDuration('P1D'), '1 day');
      expect(describeDuration('P2DT3H'), '2 days 3 hours');
      expect(describeDuration('-P1W'), '1 week before');
      expect(describeDuration('PT0S'), 'no time');
      expect(describeDuration(null), 'no time set');
      expect(describeDuration('soon'), 'soon');
    });

    test('triggers read naturally, with option labels', () {
      final def = createWorkflow('automation', title: 'x', entity: 'application');
      final ctx = UiWfDescribeContext(registry: registry, def: def);
      expect(describeTrigger(UiWfTrigger.fromJson({'type': 'fieldChanged', 'field': 'status', 'to': ['Submitted']}), ctx), 'When Status changes to Submitted');
      expect(describeTrigger(UiWfTrigger('fieldChanged'), ctx), 'When a application changes');
      expect(describeTrigger(UiWfTrigger('created'), ctx), 'When a application is created');
      expect(describeTrigger(UiWfTrigger.fromJson({'type': 'manual', 'label': 'Escalate'}), ctx), 'When someone presses “Escalate”');
      expect(describeTrigger(UiWfTrigger.fromJson({'type': 'dateReached', 'field': 'deadline', 'offset': '-P2D'}), ctx), '2 days before deadline');
    });

    test('steps read naturally', () {
      final def = createWorkflow('automation', title: 'x', entity: 'application');
      final ctx = UiWfDescribeContext(registry: registry, def: def);
      expect(describeStep(createStep('approval'), ctx), 'any of nobody yet · due in 3 days');
      expect(describeStep(step('w', 'wait'), ctx), 'for 1 day');
      expect(describeStep(createStep('parallel'), ctx), '2 paths · continue when all finish');
      expect(describeStep(createStep('branch'), ctx), '1 path and otherwise');
      expect(describeStep(createStep('end'), ctx), 'as finished');
      expect(describeAssignees([UiWfAssignee.initiator(), UiWfAssignee.role('fin'), UiWfAssignee.managerOf('assignees')], ctx), 'whoever started it, fin and their managers');
    });
  });

  group('lifecycle helpers', () {
    test('removing a state removes arrows into it and its place, and drops moves left with no source', () {
      final d = createWorkflow('lifecycle');
      final [draft, done] = d.lifecycle!.states;
      final withLayout = d.patch({'lifecycle': d.lifecycle!.patch({'layout': {draft.id: [0, 0]}}).json});
      final next = removeState(withLayout, draft.id);
      expect(next.lifecycle!.states.map((s) => s.id), [done.id]);
      expect(next.lifecycle!.transitions, isEmpty);
      expect(next.lifecycle!.layout, isEmpty);
    });

    test('"from any state" allows every state but final ones and its own target', () {
      final d = createWorkflow('lifecycle');
      final [draft, done] = d.lifecycle!.states;
      final t = UiWfTransition.fromJson({'id': 't', 'key': 'w', 'label': 'W', 'from': '*', 'to': draft.id, 'who': <Object?>[]});
      expect(transitionAllows(d, t, draft.id), isFalse);
      expect(transitionAllows(d, t, done.id), isFalse);
      expect(transitionAllows(d, t.patch({'to': done.id}), draft.id), isTrue);
    });
  });
}
