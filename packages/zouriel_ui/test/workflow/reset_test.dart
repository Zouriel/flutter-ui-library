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
    expect(button('Start over'), findsNothing);
  });
}
