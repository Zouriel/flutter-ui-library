import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/workflow/editors.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

// `me` is optional (the web `me?()`): an API that extends UiWorkflowApi and leaves it out answers
// null, and the builder and the permissions page then offer editing (the server decides).

final _def = createWorkflow('automation', title: 'Pay', entity: 'application').patch({
  'id': 'wf_a',
  'trigger': {'type': 'manual', 'label': 'Pay now', 'who': [{'role': 'finance'}]},
});

/// Only what these screens read; everything else (me included) is left out.
class _NoMe extends UiWorkflowApi {
  @override
  Future<UiWorkflowSchema> schema() async => UiWorkflowSchema(registry: UiWorkflowRegistry.fromJson({'entities': <Object?>[]}));
  @override
  Future<List<UiWfDefinitionSummary>> definitions() async => [UiWfDefinitionSummary.fromJson({'id': 'wf_a', 'title': 'Pay', 'status': 'published', 'version': 1})];
  @override
  Future<UiWfDefinitionDetail> definition(String id) async =>
      UiWfDefinitionDetail.fromJson({'summary': {'id': id, 'version': 1}, 'draft': _def.json, 'published': _def.json, 'versions': <Object?>[], 'problems': <Object?>[]});
  @override
  Future<({UiWorkflowSettings settings, int revision})> settings() async => (settings: UiWorkflowSettings(), revision: 1);
  @override
  Future<List<UiWfProblem>> validate(UiWorkflowDefinition def) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('an API that leaves me() out answers null', () async {
    expect(await _NoMe().me(), isNull);
  });

  testWidgets('the permissions page offers editing when me() is not known', (tester) async {
    await pumpUi(tester, SingleChildScrollView(child: UiWorkflowPermissions(api: _NoMe())), size: const Size(900, 700));
    expect(find.byType(WfAssigneesEditor), findsOneWidget);
    expect(find.textContaining('changing it needs the right to publish'), findsNothing);
  });

  testWidgets('the builder is editable when me() is not known', (tester) async {
    final c = UiWorkflowBuilderController(definition: _def);
    addTearDown(c.dispose);
    tester.view.physicalSize = const Size(1280, 860) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(home: UiWorkflowBuilder(controller: c, api: _NoMe())));
    await tester.pumpAndSettle();
    expect(c.readOnly, isFalse);
    expect(find.text('View only'), findsNothing);
  });
}
