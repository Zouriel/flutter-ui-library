import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fake_api.dart';

Future<void> pumpPage(WidgetTester tester, Widget child, {Size size = const Size(420, 900)}) =>
    pumpUi(tester, SizedBox(width: size.width, height: size.height, child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)), size: size);

final String arrow = String.fromCharCode(0x2192);

Finder button(String label) => find.byWidgetPredicate((w) => w is UiButton && w.label == label);

void main() {
  group('UiWorkflowStateBadge', () {
    testWidgets('shows its label and is announced by it', (tester) async {
      final h = tester.ensureSemantics();
      await pumpPage(tester, const UiWorkflowStateBadge(label: 'In review', tone: 'info'));
      expect(find.text('In review'), findsOneWidget);
      expect(find.bySemanticsLabel('In review'), findsOneWidget);
      h.dispose();
    });
  });

  group('UiWorkflowRecordPanel', () {
    testWidgets('shows the state, track, moves, tasks and history', (tester) async {
      final api = FakeWorkflowApi();
      await pumpPage(tester, UiWorkflowRecordPanel(api: api, entity: 'application', entityId: '1'));
      expect(api.calls, containsAll(['record:application/1', 'history']));
      expect(find.text('In review'), findsNWidgets(2)); // the badge and the track
      expect(find.textContaining('since 3 hours ago'), findsOneWidget);
      expect(button('Approve'), findsOneWidget);
      expect(button('Ask for documents'), findsOneWidget);
      expect(find.text('Finance sign-off'), findsOneWidget);
      expect(find.text('Your turn'), findsOneWidget);
      expect(find.bySemanticsLabel('Submit: Draft $arrow In review'), findsOneWidget);
      expect(find.text('Started in Draft'), findsOneWidget);
    });

    testWidgets('a move with a confirmation asks first, then applies and reports the change', (tester) async {
      final api = FakeWorkflowApi();
      UiWfRecord? changed;
      await pumpPage(tester, UiWorkflowRecordPanel(api: api, entity: 'application', entityId: '1', onChanged: (r) => changed = r));
      await tester.tap(button('Approve'));
      await tester.pumpAndSettle();
      expect(find.text('Approve this application?'), findsOneWidget);
      expect(api.calls.where((c) => c.startsWith('apply')), isEmpty);
      // The dialog's own Approve button (the last one).
      await tester.tap(button('Approve').last);
      await tester.pumpAndSettle();
      expect(api.calls, contains('apply:approve'));
      expect(changed?.state, 'approved');
      expect(find.text('Approve this application?'), findsNothing);
      expect(find.text('Approved'), findsWidgets);
    });

    testWidgets('a move with a form checks the form before sending anything', (tester) async {
      final api = FakeWorkflowApi();
      final ts = [...(api.recordJson['transitions'] as List)];
      api.recordJson['transitions'] = ts;
      ts[1] = <String, Object?>{
        ...(ts[1] as Map<String, Object?>),
        'form': {
          'schemaVersion': 1, 'id': 'f_withdraw', 'title': 'Withdraw',
          'pages': [{'id': 'p1', 'elements': [{'kind': 'field', 'id': 'f_reason', 'type': 'text', 'key': 'reason', 'label': 'Reason', 'required': true}]}],
        },
      };
      await pumpPage(tester, UiWorkflowRecordPanel(api: api, entity: 'application', entityId: '1'));
      await tester.tap(button('Withdraw'));
      await tester.pumpAndSettle();
      expect(find.text('Reason'), findsWidgets);
      await tester.tap(button('Withdraw').last);
      await tester.pumpAndSettle();
      // The empty required answer stops it here; nothing reached the engine.
      expect(api.calls.where((c) => c.startsWith('apply')), isEmpty);
      await tester.enterText(find.byType(EditableText).first, 'Changed my mind');
      await tester.pumpAndSettle();
      await tester.tap(button('Withdraw').last);
      await tester.pumpAndSettle();
      expect(api.calls, contains('apply:withdraw'));
    });

    testWidgets('a move without confirmation or form applies straight away', (tester) async {
      final api = FakeWorkflowApi();
      await pumpPage(tester, UiWorkflowRecordPanel(api: api, entity: 'application', entityId: '1'));
      await tester.tap(button('Withdraw'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('apply:withdraw'));
    });

    testWidgets('a refusal from the engine shows in the confirm dialog', (tester) async {
      final api = FakeWorkflowApi();
      await pumpPage(tester, UiWorkflowRecordPanel(api: api, entity: 'application', entityId: '1'));
      await tester.tap(button('Approve'));
      await tester.pumpAndSettle();
      api.failNext = const UiWfApiError(403, 'notAllowed', 'You are not allowed to “Approve”.');
      await tester.tap(button('Approve').last);
      await tester.pumpAndSettle();
      expect(find.text('You are not allowed to “Approve”.'), findsOneWidget);
    });

    testWidgets('deciding a task through the decide dialog sends the outcome and comment, then reloads', (tester) async {
      final api = FakeWorkflowApi();
      await pumpPage(tester, UiWorkflowRecordPanel(api: api, entity: 'application', entityId: '1'));
      await tester.tap(find.text('Finance sign-off'));
      await tester.pumpAndSettle();
      expect(find.text('Check the amount.'), findsOneWidget);
      expect(find.text('Comment (required to reject)'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).first, 'Looks right');
      await tester.pump();
      await tester.tap(button('Approve').last);
      await tester.pumpAndSettle();
      expect(api.calls, contains('decide:t1:approved:Looks right'));
      // The panel reloaded: the task is gone.
      expect(find.text('Finance sign-off'), findsNothing);
      expect(api.calls.where((c) => c.startsWith('record:')).length, 2);
    });

    testWidgets('a manual workflow without a form starts at once', (tester) async {
      final api = FakeWorkflowApi();
      await pumpPage(tester, UiWorkflowRecordPanel(api: api, entity: 'application', entityId: '1'));
      await tester.tap(button('Ask for documents'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('manual:escalate'));
    });

    testWidgets('meets the tap target and label guidelines', (tester) async {
      final h = tester.ensureSemantics();
      await pumpPage(tester, UiWorkflowRecordPanel(api: FakeWorkflowApi(), entity: 'application', entityId: '1'));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      h.dispose();
    });

    testWidgets('golden', (tester) async {
      final api = FakeWorkflowApi();
      await expectThemedGolden(tester, 'workflow_record_panel', (_) => UiWorkflowRecordPanel(api: api, entity: 'application', entityId: '1'), height: 560);
    });
  });

  group('UiWorkflowTasks', () {
    testWidgets('lists open tasks, overdue marked; Done shows finished ones', (tester) async {
      final api = FakeWorkflowApi();
      await pumpPage(tester, UiWorkflowTasks(api: api, pageSize: 2));
      expect(find.text('Task 1'), findsOneWidget);
      expect(find.text('Task 2'), findsOneWidget);
      expect(find.text('Task 3'), findsNothing);
      expect(find.textContaining('Overdue'), findsOneWidget);
      await tester.tap(button('Show more'));
      await tester.pumpAndSettle();
      expect(find.text('Task 3'), findsOneWidget);
      expect(api.calls, contains('tasks:open:4'));
      expect(button('Show more'), findsNothing);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Old task'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget); // its outcome's label
    });

    testWidgets('deciding from the inbox reports the decision', (tester) async {
      final api = FakeWorkflowApi();
      UiWfTask? decided;
      await pumpPage(tester, UiWorkflowTasks(api: api, onDecided: (t) => decided = t));
      await tester.tap(find.text('Task 1'));
      await tester.pumpAndSettle();
      await tester.tap(button('Reject'));
      await tester.pumpAndSettle();
      expect(decided?.outcome, 'rejected');
      expect(find.text('Task 1'), findsNothing);
    });
  });

  group('UiWorkflowRun', () {
    testWidgets('steps of the run with their status, the paths not taken dimmed', (tester) async {
      await pumpPage(tester, UiWorkflowRun(api: FakeWorkflowApi(), instanceId: 'i1'));
      expect(find.text('Stopped'), findsOneWidget);
      expect(find.text('Tell the ERP'), findsOneWidget);
      expect(find.text('Timed out'), findsOneWidget);
      expect(find.text('Failed'), findsNWidgets(2));
      // Without intervention rights there are no buttons.
      expect(button('Try again'), findsNothing);
      final notRun = tester.widget<Opacity>(find.ancestor(of: find.text('Tell the applicant'), matching: find.byType(Opacity)).first);
      expect(notRun.opacity, 0.45);
    });

    testWidgets('two stopped paths: each can be retried or skipped on its own', (tester) async {
      final api = FakeWorkflowApi();
      UiWfInstance? changed;
      await pumpPage(tester, UiWorkflowRun(api: api, instanceId: 'i1', canIntervene: true, onChanged: (r) => changed = r));
      expect(button('Try again'), findsNWidgets(2));
      expect(button('Skip'), findsNWidgets(2));
      expect(button('Skip the step'), findsNothing);
      await tester.tap(button('Try again').at(1));
      await tester.pumpAndSettle();
      expect(api.calls, contains('retry:i1:tokB'));
      expect(changed?.status, 'running');
    });

    testWidgets('one stopped path keeps the three buttons', (tester) async {
      final api = FakeWorkflowApi();
      api.instanceJson = {...api.instanceJson, 'tokens': [{'id': 'tokA', 'status': 'waiting', 'waiting': 'incident', 'stepId': 'a'}]};
      await pumpPage(tester, UiWorkflowRun(api: api, instanceId: 'i1', canIntervene: true));
      await tester.tap(button('Skip the step'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('skip:i1:'));
      // Running again: only Cancel stays.
      expect(button('Cancel the run'), findsOneWidget);
      expect(button('Try again'), findsNothing);
    });
  });

  group('UiWorkflowAudit', () {
    testWidgets('filters, pages, expands an entry and checks the chain', (tester) async {
      final api = FakeWorkflowApi();
      await pumpPage(tester, UiWorkflowAudit(api: api, pageSize: 20), size: const Size(700, 1400));
      expect(find.text('#60'), findsOneWidget);
      expect(find.text('#41'), findsOneWidget);
      await tester.tap(button('Older entries'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('audit:::41'));
      await tester.tap(find.text('#60'));
      await tester.pumpAndSettle();
      expect(find.text('hash60'), findsOneWidget);
      await tester.tap(button('Check integrity'));
      await tester.pumpAndSettle();
      expect(find.text('The chain is intact: 60 entries checked.'), findsOneWidget);
      // Filter by kind.
      await tester.tap(find.text('Everything'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record moves').last);
      await tester.pumpAndSettle();
      expect(api.calls, contains('audit:lifecycle::'));
    });

    testWidgets('export hands the bytes to the app', (tester) async {
      final api = FakeWorkflowApi();
      String? got;
      await pumpPage(tester, UiWorkflowAudit(api: api, onExport: (bytes, format) => got = '$format:${bytes.length}'), size: const Size(700, 900));
      await tester.tap(button('CSV'));
      await tester.pumpAndSettle();
      expect(got, 'csv:7');
    });
  });
}
