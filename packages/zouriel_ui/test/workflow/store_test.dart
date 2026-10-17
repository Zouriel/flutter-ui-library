import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

// Port of the web `store.spec.ts`.

void main() {
  late DateTime now;
  UiWorkflowBuilderController fresh() {
    now = DateTime(2026, 10, 17, 9);
    final s = UiWorkflowBuilderController(clock: () => now);
    s.load(createWorkflow('automation', title: 'Test', entity: 'application'));
    return s;
  }

  test('undoes and redoes edits', () {
    final s = fresh();
    final id = s.addStep('notify', 'root', 0);
    expect(s.canUndo, isTrue);
    s.undo();
    expect(s.def.steps, isEmpty);
    expect(s.selection, isNull); // the added step is gone, so is its selection
    s.redo();
    expect(s.def.steps!.map((x) => x.id), [id]);
    expect(s.canRedo, isFalse);
  });

  test('merges quick edits with the same key into one undo step', () {
    final s = fresh();
    s.patch({'title': 'A'}, mergeKey: 'title');
    now = now.add(const Duration(milliseconds: 300));
    s.patch({'title': 'AB'}, mergeKey: 'title');
    now = now.add(const Duration(milliseconds: 300));
    s.patch({'title': 'ABC'}, mergeKey: 'title');
    s.undo();
    expect(s.def.title, 'Test');
    expect(s.canUndo, isFalse);
  });

  test('edits further apart than the merge window undo separately', () {
    final s = fresh();
    s.patch({'title': 'A'}, mergeKey: 'title');
    now = now.add(const Duration(milliseconds: 1300));
    s.patch({'title': 'AB'}, mergeKey: 'title');
    s.undo();
    expect(s.def.title, 'A');
  });

  test('history keeps at most 200 steps', () {
    final s = fresh();
    for (var i = 0; i < 205; i++) {
      s.patch({'title': 'T$i'});
    }
    var n = 0;
    while (s.canUndo) {
      s.undo();
      n++;
    }
    expect(n, 200);
    expect(s.def.title, 'T4');
  });

  test('a new edit clears redo', () {
    final s = fresh();
    s.patch({'title': 'A'});
    s.undo();
    s.patch({'title': 'B'});
    expect(s.canRedo, isFalse);
  });

  test('removing keys with null and replacing with a function', () {
    final s = fresh();
    final id = s.addStep('notify', 'root', 0);
    s.updateStep(id, {'title': 'Hello'});
    expect(s.selectedStep?.title, 'Hello');
    s.updateStep(id, {'title': null});
    expect(s.selectedStep!.json.containsKey('title'), isFalse);
    s.replaceStep(id, (st) => st.patch({'disabled': true}));
    expect(s.selectedStep?.disabled, isTrue);
  });

  test('deleting the selected step, state or transition clears the selection', () {
    final s = fresh();
    final id = s.addStep('wait', 'root', 0);
    s.removeStep(id);
    expect(s.selection, isNull);

    s.load(createWorkflow('lifecycle', title: 'Life', entity: 'application'));
    final st = s.addState('Review');
    expect(s.selection, UiWfSelection.state(st));
    s.removeState(st);
    expect(s.selection, isNull);
    final [a, b] = s.def.lifecycle!.states;
    final t = s.addTransition(a.id, b.id);
    s.removeTransition(t);
    expect(s.selection, isNull);
  });

  test('new states get unique keys and transitions are named after their target', () {
    final s = fresh();
    s.load(createWorkflow('lifecycle', title: 'Life', entity: 'application'));
    s.addState('Review');
    s.addState('Review');
    expect(s.def.lifecycle!.states.map((x) => x.key), ['Draft', 'Done', 'Review', 'Review 2']);
    final [a, b, ...] = s.def.lifecycle!.states;
    final t = s.addTransition(a.id, b.id);
    expect(s.selectedTransition?.label, 'To Done');
    expect(s.selectedTransition?.id, t);
  });

  test('dragging a state stores its place; tidying forgets it', () {
    final s = fresh();
    s.load(createWorkflow('lifecycle', title: 'Life', entity: 'application'));
    final a = s.def.lifecycle!.states.first;
    s.placeState(a.id, 10.4, 20.6);
    expect(s.def.lifecycle!.layout, {a.id: [10, 21]});
    s.tidyLayout();
    expect(s.def.lifecycle!.layout, isNull);
  });

  test('loading another workflow clears history; echoing the same one keeps it', () {
    final s = fresh();
    s.patch({'title': 'X'});
    s.load(UiWorkflowDefinition.fromJson({...s.def.json}));
    expect(s.canUndo, isTrue);
    s.load(createWorkflow('automation'));
    expect(s.canUndo, isFalse);
  });

  test('a move that changes nothing is not an edit', () {
    final s = fresh();
    final a = s.addStep('notify', 'root', 0);
    s.addStep('notify', 'root', 1);
    final before = s.def;
    expect(s.moveStep(a, 'root', 1), isFalse);
    expect(identical(s.def, before), isTrue);
    expect(s.moveStep(a, 'root', 2), isTrue);
  });

  test('every commit bumps the version and notifies', () {
    final s = fresh();
    var calls = 0;
    s.addListener(() => calls++);
    final v = s.version;
    s.patch({'title': 'Y'});
    s.undo();
    s.redo();
    expect(s.version, v + 3);
    expect(calls, greaterThanOrEqualTo(3));
  });

  test('problems are grouped by node', () {
    final s = fresh();
    s.serverProblems = [
      UiWfProblem(code: 'a', severity: 'error', node: 's1', message: 'One'),
      UiWfProblem(code: 'b', severity: 'warning', node: 's1', message: 'Two'),
      UiWfProblem(code: 'c', severity: 'error', message: 'Whole'),
    ];
    expect(s.errorCount, 2);
    expect(s.problemsOf('s1').map((p) => p.message), ['One', 'Two']);
    expect(s.problemsOf(null).single.message, 'Whole');
  });
}
