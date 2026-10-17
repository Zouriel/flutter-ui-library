import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/workflow/history.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fake_api.dart';

// The runtime fixes of @zouriel/ui 432120c: words instead of keys, a people picker for handing a
// task over, no double submits, and no older answer overwriting a newer one.

Future<void> pumpPage(WidgetTester tester, Widget child, {Size size = const Size(520, 900)}) =>
    pumpUi(tester, SizedBox(width: size.width, height: size.height, child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)), size: size);

Finder button(String label) => find.byWidgetPredicate((w) => w is UiButton && w.label == label);

/// Answers tasks() only when told to, in any order.
class _SlowTasks extends FakeWorkflowApi {
  final pending = <Completer<UiWfPage<UiWfTask>>>[];
  @override
  Future<UiWfPage<UiWfTask>> tasks(UiWfTaskQuery q) {
    final c = Completer<UiWfPage<UiWfTask>>();
    pending.add(c);
    return c.future;
  }
}

/// Counts decisions and answers them only when told to.
class _SlowDecide extends FakeWorkflowApi {
  final pending = <Completer<UiWfTask>>[];
  int decisions = 0;
  @override
  Future<UiWfTask> decide(String id, String outcome, {String? comment, UiJson? data}) {
    decisions++;
    final c = Completer<UiWfTask>();
    pending.add(c);
    return c.future;
  }
}

UiWfTask _task(String id, String title) => UiWfTask.fromJson(FakeWorkflowApi.taskJson(id, title: title));

void main() {
  group('labels', () {
    test('outcomes, task results and run statuses read as words', () {
      expect(wfOutcomeLabel('approved'), 'Approved');
      expect(wfOutcomeLabel('needsMoreInfo'), 'Needs more info');
      expect(wfTaskResult(UiWfTask.fromJson({'status': 'timedOut'})), 'Out of time');
      expect(wfTaskResult(UiWfTask.fromJson({'status': 'completed', 'outcome': 'ok', 'outcomes': [{'key': 'ok', 'label': 'Looks good'}]})), 'Looks good');
      expect(wfRunStatusLabel('incident'), 'Stopped');
      expect(wfRunStatusLabel('somethingNew'), 'Something new');
      expect(wfRunStatusTone('failed'), 'danger');
      expect(wfAuditCategoryLabel('lifecycle'), 'Record moves');
      expect(wfAuditActionLabel('lifecycle', 'slaBreached'), 'Stayed too long in a state');
    });
  });

  testWidgets('a slower older task list never replaces a newer one', (tester) async {
    final api = _SlowTasks();
    final key = GlobalKey<UiWorkflowTasksState>();
    await pumpPage(tester, UiWorkflowTasks(key: key, api: api));
    key.currentState!.reload();
    await tester.pump();
    expect(api.pending, hasLength(2));
    // The newer answer comes first, then the old one.
    api.pending[1].complete(UiWfPage([_task('t2', 'Newer')], 1));
    await tester.pump();
    api.pending[0].complete(UiWfPage([_task('t1', 'Older')], 1));
    await tester.pump();
    expect(find.text('Newer'), findsOneWidget);
    expect(find.text('Older'), findsNothing);
  });

  testWidgets('a double tap on a decision sends it once', (tester) async {
    final api = _SlowDecide();
    await pumpPage(tester, UiWorkflowTasks(api: api));
    await tester.tap(find.text('Task 1'));
    await tester.pumpAndSettle();
    final approve = button('Approve').last;
    await tester.tap(approve);
    await tester.tap(approve, warnIfMissed: false);
    await tester.pump();
    expect(api.decisions, 1);
    api.pending.single.complete(_task('t1', 'Task 1'));
    await tester.pumpAndSettle();
  });

  testWidgets('handing a task over picks a person from the directory', (tester) async {
    final api = FakeWorkflowApi();
    await pumpPage(tester, UiWorkflowTasks(api: api));
    await tester.tap(find.text('Task 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Hand it to someone else'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('searchUsers:'));
    await tester.enterText(find.descendant(of: find.byType(UiSearchInput), matching: find.byType(EditableText)), 'ali');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Hana Ibrahim'), findsNothing);
    await tester.tap(find.text('Ali Rasheed'));
    await tester.pump();
    expect(find.text('Hand it to Ali Rasheed.'), findsOneWidget);
    await tester.tap(button('Hand over'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('delegate:t1:ali'));
  });

  testWidgets('the run view asks the engine whether the viewer may intervene', (tester) async {
    final api = FakeWorkflowApi()..canIntervene = true;
    await pumpPage(tester, UiWorkflowRun(api: api, instanceId: 'i1'));
    expect(api.calls, contains('me'));
    expect(button('Cancel the run'), findsOneWidget);
    final no = FakeWorkflowApi();
    await pumpPage(tester, UiWorkflowRun(key: const ValueKey('no'), api: no, instanceId: 'i1'));
    expect(button('Cancel the run'), findsNothing);
    // The host can still decide.
    await pumpPage(tester, UiWorkflowRun(key: const ValueKey('yes'), api: no, instanceId: 'i1', canIntervene: true));
    expect(button('Cancel the run'), findsOneWidget);
  });

  testWidgets('audit entries read as words, as key/value rows, with the raw data on request', (tester) async {
    final api = FakeWorkflowApi();
    await pumpPage(tester, UiWorkflowAudit(api: api), size: const Size(700, 1600));
    expect(find.textContaining('Record moved'), findsWidgets);
    expect(find.textContaining('Decided'), findsWidgets);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Entry 60:')));
    await tester.pumpAndSettle();
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Record 1 (Application 1)'), findsOneWidget);
    expect(find.text('Label'), findsOneWidget); // a row of the details, not the JSON
    expect(find.text('{"state":"draft"}'), findsNothing);
    await tester.tap(button('Show the raw data'));
    await tester.pumpAndSettle();
    expect(find.text('{"state":"draft"}'), findsOneWidget);
  });

  testWidgets('the audit record filter waits for a pause in typing', (tester) async {
    final api = FakeWorkflowApi();
    await pumpPage(tester, UiWorkflowAudit(api: api), size: const Size(700, 1600));
    final before = api.calls.where((c) => c.startsWith('audit:')).length;
    final input = find.byWidgetPredicate((w) => w is UiInput && w.semanticLabel == 'Record id');
    await tester.enterText(find.descendant(of: input, matching: find.byType(EditableText)), '4');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.descendant(of: input, matching: find.byType(EditableText)), '42');
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.calls.where((c) => c.startsWith('audit:')).length, before);
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.calls.where((c) => c.startsWith('audit:')).toList().sublist(before), ['audit::42:']);
  });
}
