import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/workflow/editors.dart';
import 'package:zouriel_ui/src/workflow/inspector.dart';
import 'package:zouriel_ui/src/workflow/scope.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

final _schema = UiWorkflowSchema.fromJson({
  'specVersion': 1,
  'steps': <Object?>[],
  'registry': {
    'specVersion': 1,
    'entities': [
      {'key': 'application', 'label': 'Application', 'fields': [
        {'key': 'title', 'label': 'Title', 'type': 'text'},
        {'key': 'track', 'label': 'Type', 'type': 'enum', 'options': [{'value': 'passport', 'label': 'Passport'}, {'value': 'visa', 'label': 'Visa'}]},
        {'key': 'status', 'label': 'Status', 'type': 'enum', 'lifecycle': true, 'options': [{'value': 'draft', 'label': 'Draft'}, {'value': 'done', 'label': 'Done'}]},
        {'key': 'programme', 'label': 'Programme', 'type': 'relation', 'entity': 'programme'},
      ]},
      {'key': 'programme', 'label': 'Programme', 'fields': [{'key': 'name', 'label': 'Name', 'type': 'text'}]},
    ],
  },
});

Future<UiWorkflowBuilderController> _pump(WidgetTester tester) async {
  final d = createWorkflow('lifecycle', title: 'Passport application', entity: 'application');
  final c = UiWorkflowBuilderController(definition: UiWorkflowDefinition.fromJson({...d.json, 'lifecycle': {...d.lifecycle!.json, 'field': 'status'}}));
  c.schema = _schema;
  final wfUi = WfBuilderUi();
  addTearDown(() {
    c.dispose();
    wfUi.dispose();
  });
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(home: WfBuilderScope(controller: c, ui: wfUi, child: const SingleChildScrollView(child: WfWorkflowEditor()))));
  await tester.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('applies to offers only the record’s own fields, never the controlled field or related records', (tester) async {
    await _pump(tester);
    expect(find.text('APPLIES TO'), findsOneWidget);
    expect(find.text('Every application that no other lifecycle on this field covers.'), findsOneWidget);
    final editor = tester.widget<WfConditionEditor>(find.byType(WfConditionEditor));
    expect([for (final t in editor.tokens) t.path], ['entity.title', 'entity.track', 'entity.programme']);
  });

  testWidgets('applies to is stored on the lifecycle and dropped with its last condition', (tester) async {
    final c = await _pump(tester);
    final when = UiWfCondition.fromJson({'match': 'all', 'conditions': [{'ref': 'entity.track', 'op': 'eq', 'value': {'const': 'passport'}}]});
    tester.widget<WfConditionEditor>(find.byType(WfConditionEditor)).onChanged(when);
    await tester.pumpAndSettle();
    expect(c.def.lifecycle!.appliesWhen?.json, when.json);
    tester.widget<WfConditionEditor>(find.byType(WfConditionEditor)).onChanged(UiWfCondition.fromJson({'match': 'all', 'conditions': <Object?>[]}));
    await tester.pumpAndSettle();
    expect(c.def.lifecycle!.appliesWhen, isNull);
    expect(c.def.lifecycle!.json.containsKey('appliesWhen'), isFalse);
  });

  test('own-field tokens keep plain record fields only', () {
    final tokens = [
      for (final p in ['entity.id', 'entity.status', 'entity.track', 'entity.programme.name', 'trigger.actor', 'vars.x']) UiWfToken(path: p, label: p, group: 'g', type: 'text'),
    ];
    expect([for (final t in wfOwnFieldTokens(tokens, 'status')) t.path], ['entity.track']);
  });
}
