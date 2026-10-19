import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/workflow/bits.dart' show WfSelect;
import 'package:zouriel_ui/src/workflow/editors.dart';
import 'package:zouriel_ui/src/workflow/inspector.dart';
import 'package:zouriel_ui/src/workflow/scope.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fake_api.dart';

// Regression tests for the editors' audit findings: the people search (late failures, the 180px
// cap, long addresses), a lifecycle that can't be loaded, and a custom schedule carried between
// workflows.

/// Searches that answer (or fail) only when told to, in any order.
class _People extends FakeWorkflowApi {
  final pending = <(String, Completer<List<UiWfUser>>)>[];
  @override
  Future<List<UiWfUser>> searchUsers(String query, {int take = 20}) {
    final c = Completer<List<UiWfUser>>();
    pending.add((query, c));
    return c.future;
  }
}

List<UiWfUser> _many(int n, {String email = 'someone@example.com'}) =>
    [for (var i = 0; i < n; i++) UiWfUser.fromJson({'id': 'u$i', 'name': 'Person $i', 'email': email})];

Future<void> _openSearch(WidgetTester tester, UiWorkflowApi api, {double width = 360}) async {
  await pumpUi(tester, SizedBox(width: width, child: WfAssigneesEditor(value: const [], api: api, onChanged: (_) {})));
  await tester.tap(find.byType(WfSelect));
  await tester.pumpAndSettle();
  await tester.tap(find.text('A specific person…'));
  await tester.pumpAndSettle();
}

Finder get _search => find.descendant(of: find.byWidgetPredicate((w) => w is UiInput && w.semanticLabel == 'Search people'), matching: find.byType(EditableText));

void main() {
  testWidgets('an older search failing late leaves the newer results', (tester) async {
    final api = _People();
    await _openSearch(tester, api);
    await tester.enterText(_search, 'a');
    await tester.pump();
    await tester.enterText(_search, 'al');
    await tester.pump();
    api.pending[1].$2.complete(_many(2));
    await tester.pumpAndSettle();
    expect(find.text('Person 1'), findsOneWidget);
    api.pending[0].$2.completeError(const UiWfApiError(500, 'boom', 'Down'));
    await tester.pumpAndSettle();
    expect(find.text('Person 1'), findsOneWidget);
  });

  testWidgets('results stop at 180px and scroll; a long address never runs past the edge', (tester) async {
    final api = _People();
    await _openSearch(tester, api, width: 300);
    await tester.enterText(_search, 'p');
    await tester.pump();
    api.pending.single.$2.complete(_many(12, email: 'a.very.long.address.for.someone@faculty.example-university.edu'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const ValueKey('wf-people-results'))).height, 180);
    expect(find.descendant(of: find.byKey(const ValueKey('wf-people-results')), matching: find.byType(Scrollable)), findsOneWidget);
  });

  test('a lifecycle that fails to load is not asked for again on every rebuild', () async {
    final api = _FailingDefinition();
    final store = UiWorkflowBuilderController()
      ..api = api
      ..others = [UiWfDefinitionSummary.fromJson({'id': 'lc1', 'key': 'life', 'kind': 'lifecycle', 'version': 1})];
    store.loadLifecycle('life');
    await Future<void>.delayed(Duration.zero);
    store.loadLifecycle('life');
    store.loadLifecycle('life');
    await Future<void>.delayed(Duration.zero);
    expect(api.asked, 1);
    // A new list of workflows (or another api) asks again.
    store.others = [...store.others];
    store.loadLifecycle('life');
    await Future<void>.delayed(Duration.zero);
    expect(api.asked, 2);
  });

  testWidgets('a custom schedule chosen in one workflow isn\'t carried into the next', (tester) async {
    UiWorkflowDefinition scheduled(String id) => UiWorkflowDefinition.fromJson({
          'specVersion': 1, 'id': id, 'key': id, 'kind': 'automation', 'title': id,
          'trigger': {'type': 'schedule', 'cron': '0 9 * * *'}, 'steps': <Object?>[],
        });
    final store = UiWorkflowBuilderController(definition: scheduled('a'))..selection = UiWfSelection.trigger;
    await pumpUi(tester, SizedBox(width: 380, height: 800, child: WfBuilderScope(controller: store, child: const WfInspector())), size: const Size(380, 800));
    WfSelect when() => tester.widget<WfSelect>(find.byWidgetPredicate((w) => w is WfSelect && w.label == 'When'));
    when().onChanged!('custom');
    await tester.pumpAndSettle();
    expect(when().value, 'custom');
    store.load(scheduled('b'));
    store.selection = UiWfSelection.trigger;
    await tester.pumpAndSettle();
    expect(when().value, '0 9 * * *');
  });

  group('phone inspector sheet', _phoneSheetTests);
}

class _FailingDefinition extends FakeWorkflowApi {
  int asked = 0;
  @override
  Future<UiWfDefinitionDetail> definition(String id) async {
    asked++;
    throw const UiWfApiError(500, 'boom', 'Down');
  }
}

UiWorkflowDefinition _lifecycle() => UiWorkflowDefinition.fromJson({
      'specVersion': 1, 'id': 'wf_life', 'key': 'life', 'kind': 'lifecycle', 'title': 'Application', 'entity': 'application',
      'lifecycle': {
        'field': 'status', 'mode': 'enforce',
        'states': [
          {'id': 'draft', 'key': 'Draft', 'label': 'Draft', 'category': 'initial'},
          {'id': 'done', 'key': 'Done', 'label': 'Done', 'category': 'terminal'},
        ],
        'transitions': [
          {'id': 'submit', 'key': 'submit', 'label': 'Submit', 'from': ['draft'], 'to': 'done', 'who': <Object?>[],
            'steps': [{'id': 'n1', 'type': 'end', 'result': 'completed', 'title': 'Finish'}]},
        ],
        'reset': {'label': 'Start over', 'to': 'draft', 'who': <Object?>[]},
      },
    });

void _phoneSheetTests() {
  Future<(UiWorkflowBuilderController, List<String>)> pumpSheet(WidgetTester tester, UiWfSelection sel) async {
    final store = UiWorkflowBuilderController(definition: _lifecycle())..selection = sel;
    final deleted = <String>[];
    await pumpUi(
      tester,
      SizedBox(width: 380, height: 700, child: WfBuilderScope(controller: store, child: WfInspector(showHead: false, onDeleteRequest: () => deleted.add('${store.selection?.kind}')))),
      size: const Size(380, 700),
    );
    return (store, deleted);
  }

  for (final (sel, name) in [(const UiWfSelection.state('done'), 'Done'), (const UiWfSelection.transition('submit'), 'Submit'), (UiWfSelection.reset, 'Start over')]) {
    testWidgets('in a bottom sheet (no header) a ${sel.kind} has no Delete row of its own: the sheet header has it', (tester) async {
      final (_, deleted) = await pumpSheet(tester, sel);
      expect(find.bySemanticsLabel('Delete $name'), findsNothing);
      expect(deleted, isEmpty);
    });
  }

  testWidgets('in a bottom sheet a step in a transition\'s run still links back to its transition', (tester) async {
    final (store, _) = await pumpSheet(tester, const UiWfSelection.step('n1'));
    await tester.tap(find.bySemanticsLabel('‹ Submit'));
    await tester.pumpAndSettle();
    expect(store.selection, const UiWfSelection.transition('submit'));
  });

  testWidgets('read-only: no Delete in the sheet', (tester) async {
    final store = UiWorkflowBuilderController(definition: _lifecycle())
      ..selection = const UiWfSelection.state('done')
      ..readOnly = true;
    await pumpUi(tester, SizedBox(width: 380, height: 700, child: WfBuilderScope(controller: store, child: const WfInspector(showHead: false))), size: const Size(380, 700));
    expect(find.bySemanticsLabel('Delete Done'), findsNothing);
  });
}
