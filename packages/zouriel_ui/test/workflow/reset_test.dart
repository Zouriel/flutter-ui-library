import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fake_api.dart';

Finder button(String label) => find.byWidgetPredicate((w) => w is UiButton && w.label == label);

UiWorkflowDefinition withReset() {
  final d = createWorkflow('lifecycle', title: 'Life', entity: 'application');
  return UiWorkflowDefinition.fromJson({
    ...d.json,
    'lifecycle': {
      ...d.lifecycle!.json,
      'reset': {
        'who': <Object?>[],
        'input': {
          'form': {
            'schemaVersion': 1, 'id': 'f', 'title': 'Reset',
            'pages': [
              {'id': 'p', 'elements': [
                {'kind': 'field', 'id': 'r', 'key': 'reason', 'type': 'textarea', 'label': 'Why'},
                {'kind': 'group', 'id': 'g', 'key': 'extra', 'elements': [{'kind': 'field', 'id': 'n', 'key': 'note', 'type': 'text', 'label': 'Note'}]},
              ]},
            ],
          },
        },
      },
    },
  });
}

void main() {
  group('reset in the definition', () {
    test('its steps are a list called reset, created on first use', () {
      final d = withReset();
      expect(listSteps(d, 'reset'), isNull);
      final next = insertStep(d, 'reset', 0, createStep('notify'));
      expect(listSteps(next, 'reset'), hasLength(1));
      expect(indexSteps(next).values.single.listId, 'reset');
    });

    test('no reset, no list', () {
      final d = createWorkflow('lifecycle');
      final next = insertStep(d, 'reset', 0, createStep('notify'));
      expect(next.lifecycle!.reset, isNull);
      expect(listSteps(next, 'reset'), isNull);
    });

    test('steps on reset can read the reset form\'s answers, groups included', () {
      final step = createStep('notify');
      final d = insertStep(withReset(), 'reset', 0, step);
      final paths = tokensAt(d, null, at: UiWfAt.step(step.id)).map((t) => t.path).toList();
      expect(paths, containsAll(['input.reason', 'input.extra.note']));
      expect(wfFormFields(null), isEmpty);
    });
  });

  test('the store turns reset on, edits it, undoes and removes it', () {
    final s = UiWorkflowBuilderController();
    s.load(createWorkflow('lifecycle', title: 'Life', entity: 'application'));
    s.enableReset();
    expect(s.def.lifecycle!.reset!.json, {'label': 'Reset workflow', 'who': <Object?>[], 'steps': <Object?>[]});
    expect(s.selection, UiWfSelection.reset);
    s.updateReset({'label': 'Start over', 'confirm': 'Sure?'});
    s.updateReset({'confirm': null});
    expect(s.def.lifecycle!.reset!.label, 'Start over');
    expect(s.def.lifecycle!.reset!.confirm, isNull);
    s.removeReset();
    expect(s.def.lifecycle!.reset, isNull);
    expect(s.selection, isNull);
    s.undo();
    expect(s.def.lifecycle!.reset!.label, 'Start over');
  });

  testWidgets('the record panel offers the reset: confirm, then the engine starts it over', (tester) async {
    final api = FakeWorkflowApi();
    api.recordJson['reset'] = {'label': 'Start over', 'to': 'draft', 'toLabel': 'Draft', 'confirm': 'Start this application over?', 'form': null};
    await pumpUi(tester, SizedBox(width: 420, height: 900, child: SingleChildScrollView(child: UiWorkflowRecordPanel(api: api, entity: 'application', entityId: '1'))), size: const Size(420, 900));
    await tester.pumpAndSettle();
    expect(find.textContaining('Back to “Draft”'), findsOneWidget);
    await tester.tap(button('Start over'));
    await tester.pumpAndSettle();
    expect(find.text('Start this application over?'), findsOneWidget);
    await tester.tap(button('Start over').last);
    await tester.pumpAndSettle();
    expect(api.calls, contains('reset'));
    expect(api.lastResetUndo, isNull);
    expect(button('Start over'), findsNothing);
  });

  testWidgets('the reset lists what the workflow did: ticked by default, changed-since unticked, messages locked, chosen ids sent', (tester) async {
    final api = FakeWorkflowApi();
    api.recordJson['reset'] = {'label': 'Start over', 'to': 'draft', 'toLabel': 'Draft', 'confirm': null, 'form': null};
    Map<String, Object?> item(String id, String kind, String title, {required bool undoable, required bool selected, String? warning}) =>
        {'id': id, 'kind': kind, 'title': title, 'detail': null, 'workflow': 'Application review', 'step': 'Assign', 'undoable': undoable, 'selected': selected, 'warning': warning};
    api.resetItems = [
      item('created:document:d9', 'created', 'Delete Document “Checklist”', undoable: true, selected: true),
      item('field:programme:p1:budget', 'field', 'Budget of Programme “Engineering”: back to 50000', undoable: true, selected: false,
          warning: 'Changed again since the workflow set it to 60000; ticking it overwrites that.'),
      item('message:s3', 'message', 'Message to Ali', undoable: false, selected: false, warning: "Already sent; it can't be taken back."),
    ];
    await pumpUi(tester, SizedBox(width: 420, height: 900, child: SingleChildScrollView(child: UiWorkflowRecordPanel(api: api, entity: 'application', entityId: '1'))), size: const Size(420, 900));
    await tester.pumpAndSettle();
    await tester.tap(button('Start over'));
    await tester.pumpAndSettle();
    expect(find.text('ALSO TAKE BACK'), findsOneWidget);
    UiCheckbox box(String title) => tester.widget<UiCheckbox>(find.ancestor(of: find.text(title), matching: find.byType(UiCheckbox)));
    expect(box('Delete Document “Checklist”').value, isTrue);
    expect(box('Budget of Programme “Engineering”: back to 50000').value, isFalse);
    expect(box('Message to Ali').value, isFalse);
    expect(box('Message to Ali').onChanged, isNull);
    expect(find.textContaining('Changed again since'), findsOneWidget);
    // Keep the new document, put the budget back.
    await tester.tap(find.text('Delete Document “Checklist”'));
    await tester.tap(find.text('Budget of Programme “Engineering”: back to 50000'));
    await tester.pumpAndSettle();
    await tester.tap(button('Start over').last);
    await tester.pumpAndSettle();
    expect(api.lastResetUndo, ['field:programme:p1:budget']);
  });

  testWidgets('golden: the reset list on a phone', (tester) async {
    final api = FakeWorkflowApi();
    api.recordJson['reset'] = {'label': 'Start over', 'to': 'draft', 'toLabel': 'Draft', 'confirm': 'Start this application over? Open tasks and runs stop.', 'form': null};
    api.resetItems = [
      {'id': 'field:application:1:reviewer', 'kind': 'field', 'title': 'Reviewer of Application “Bursary”: back to nobody', 'detail': 'Now Rana Ibrahim',
        'workflow': 'Scholarship review', 'step': 'Assign the reviewer', 'undoable': true, 'selected': true},
      {'id': 'created:document:d9', 'kind': 'created', 'title': 'Delete Document “Review checklist”', 'detail': 'Created by the workflow',
        'workflow': 'Scholarship review', 'step': 'Open a checklist', 'undoable': true, 'selected': true},
      {'id': 'field:programme:p1:budget', 'kind': 'field', 'title': 'Budget of Programme “Engineering”: back to 50,000', 'detail': 'Now 42,000',
        'workflow': 'Scholarship review', 'step': 'Reserve the amount', 'undoable': true, 'selected': false,
        'warning': 'Changed again since the workflow set it to 45,200; ticking it overwrites that.'},
      {'id': 'message:m1', 'kind': 'message', 'title': 'Message to Ali Hassan', 'detail': null, 'workflow': 'Scholarship review', 'step': 'Thank the applicant',
        'undoable': false, 'selected': false, 'warning': "Already sent; it can't be taken back."},
    ];
    debugDisableShadows = false;
    tester.view.devicePixelRatio = 2;
    await pumpUi(tester, SizedBox(width: 390, child: UiWorkflowRecordPanel(api: api, entity: 'application', entityId: '1')), size: const Size(390, 900));
    await tester.tap(button('Start over'));
    await tester.pumpAndSettle();
    try {
      await expectLater(find.byType(UiApp), matchesGoldenFile('goldens/workflow_reset_list.png'));
    } finally {
      debugDisableShadows = true;
    }
  });
}
