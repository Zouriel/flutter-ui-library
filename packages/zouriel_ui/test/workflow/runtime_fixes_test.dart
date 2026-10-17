import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/workflow/bits.dart' show WfSectionTitle, WfSelect;
import 'package:zouriel_ui/src/workflow/runtime.dart' show WfDashedTopRule, WfRecordActions, WfRunView, WfTaskInbox, showWfDecideDialog;
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fake_api.dart';

// Regression tests for the runtime widgets' audit findings: dialogs that close (or are taken away)
// while an answer is on its way, a skip opened twice, audit titles from another engine, the task
// list's loading and wording, and parity with the web (hand-over combobox, bulleted decisions,
// dashed reset rule, audit filters).

Finder button(String label) => find.byWidgetPredicate((w) => w is UiButton && w.label == label);
Finder inModal(Finder f) => find.descendant(of: find.byType(UiModal), matching: f);
bool enabled(WidgetTester tester, Finder f) => tester.widget<UiButton>(f).onPressed != null;

final _pay = UiWfStep.fromJson({...createStep('action').json, 'id': 'pay', 'title': 'Create the payment', 'action': 'bank.pay', 'input': <String, Object?>{}});
final UiWorkflowDefinition _def = createWorkflow('automation', title: 'Pay', entity: 'application').patch({'steps': [_pay.json]});
UiWfInstance _stuck([Map<String, Object?> extra = const {}]) => UiWfInstance.fromJson({
      'id': 'r1', 'definitionId': _def.id, 'definitionKey': _def.key, 'title': _def.title, 'version': 1, 'kind': 'automation',
      'entity': 'application', 'entityId': '1', 'status': 'incident', 'error': 'X: boom', 'errorStepId': 'pay',
      'startedAt': DateTime.now().toUtc().toIso8601String(), 'steps': <Object?>[],
      'tokens': [{'id': 'tk', 'status': 'waiting', 'waiting': 'incident', 'stepId': 'pay'}], ...extra,
    });

/// Holds decide, delegate, skip, cancel and schema until told, and fails them on request.
class _GateApi extends FakeWorkflowApi {
  Completer<void> gate = Completer<void>();
  Completer<void>? schemaGate;
  bool fail = false;
  int schemaCalls = 0;

  Future<void> _wait() async {
    await gate.future;
    if (fail) throw const UiWfApiError(409, 'conflict', 'Too late');
  }

  @override
  Future<UiWfInstance> instance(String id) async => _stuck();
  @override
  Future<UiWorkflowDefinition> instanceDefinition(String id) async => _def;
  @override
  Future<UiWfMe> me() async => UiWfMe.fromJson({'type': 'user', 'id': 'u', 'can': {'intervene': true}});
  @override
  Future<UiWorkflowSchema> schema() async {
    schemaCalls++;
    await schemaGate?.future;
    return super.schema();
  }

  @override
  Future<UiWfInstance> cancel(String id, {String? reason}) async {
    await _wait();
    return _stuck({'status': 'cancelled', 'tokens': <Object?>[]});
  }

  @override
  Future<UiWfInstance> skip(String id, {UiJson? outputs, String? target}) async {
    await _wait();
    return _stuck({'status': 'running', 'tokens': <Object?>[]});
  }

  @override
  Future<UiWfTask> decide(String id, String outcome, {String? comment, UiJson? data}) async {
    calls.add('decide:$id:$outcome');
    await _wait();
    taskList = taskList.where((t) => t['id'] != id).toList();
    recordJson = {...recordJson, 'tasks': <Object?>[]};
    return UiWfTask.fromJson({...FakeWorkflowApi.taskJson(id), 'status': 'completed', 'outcome': outcome});
  }
}

Future<void> _pumpPage(WidgetTester tester, Widget child, {Size size = const Size(700, 900)}) =>
    pumpUi(tester, SizedBox(width: size.width, height: size.height, child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)), size: size);

/// Takes the top route away without asking it (as the tasks drawer's hide() does).
void _removeTopRoute(WidgetTester tester) => Navigator.of(tester.element(find.byType(UiModal)), rootNavigator: true).pop();

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  group('decide dialog', () {
    testWidgets('can\'t be closed while a decision is on its way: Close, backdrop, Escape and Back wait', (tester) async {
      final api = _GateApi();
      final task = UiWfTask.fromJson(FakeWorkflowApi.taskJson('t1'));
      await pumpUi(tester, Builder(builder: (ctx) => UiButton(label: 'Open', onPressed: () => showWfDecideDialog(ctx, task: task, api: api))), size: const Size(700, 900));
      await tester.tap(button('Open'));
      await tester.pumpAndSettle();
      expect(enabled(tester, button('Close')), isTrue);
      await tester.tap(button('Approve'));
      await tester.pump();
      expect(enabled(tester, button('Close')), isFalse);
      await tester.tapAt(const Offset(5, 5)); // the backdrop
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(UiModal), findsOneWidget);
      api.gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(UiModal), findsNothing);
    });

    testWidgets('a failure that arrives after the dialog was taken away is dropped quietly', (tester) async {
      final api = _GateApi()..fail = true;
      final task = UiWfTask.fromJson(FakeWorkflowApi.taskJson('t1'));
      await pumpUi(tester, Builder(builder: (ctx) => UiButton(label: 'Open', onPressed: () => showWfDecideDialog(ctx, task: task, api: api))), size: const Size(700, 900));
      await tester.tap(button('Open'));
      await tester.pumpAndSettle();
      await tester.tap(button('Approve'));
      await tester.pump();
      _removeTopRoute(tester);
      await tester.pumpAndSettle();
      api.gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a decision saved after the dialog was taken away still reloads the list', (tester) async {
      final api = _GateApi();
      UiWfTask? decided;
      await _pumpPage(tester, WfTaskInbox(api: api, onDecided: (t) => decided = t));
      await tester.tap(find.bySemanticsLabel(RegExp('^Task 1,')));
      await tester.pumpAndSettle();
      await tester.tap(inModal(button('Approve')));
      await tester.pump();
      _removeTopRoute(tester);
      await tester.pumpAndSettle();
      final before = api.calls.where((c) => c.startsWith('tasks:')).length;
      api.gate.complete();
      await tester.pumpAndSettle();
      expect(decided?.outcome, 'approved');
      expect(api.calls.where((c) => c.startsWith('tasks:')).length, before + 1);
      expect(find.text('Task 1'), findsNothing);
    });

    testWidgets('the workflow panel reloads after a decision even when its dialog was taken away', (tester) async {
      final api = _GateApi();
      await _pumpPage(tester, UiWorkflowPanel(api: api, entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.compact));
      await tester.tap(find.bySemanticsLabel(RegExp('^Finance sign-off,')));
      await tester.pumpAndSettle();
      await tester.tap(inModal(button('Approve')));
      await tester.pump();
      _removeTopRoute(tester);
      await tester.pumpAndSettle();
      final before = api.calls.where((c) => c.startsWith('record:')).length;
      api.gate.complete();
      await tester.pumpAndSettle();
      expect(api.calls.where((c) => c.startsWith('record:')).length, before + 1);
      expect(find.text('Finance sign-off'), findsNothing);
    });

    testWidgets('hands over through one combobox that searches the directory as the name is typed', (tester) async {
      final api = FakeWorkflowApi();
      await _pumpPage(tester, WfTaskInbox(api: api));
      await tester.tap(find.bySemanticsLabel(RegExp('^Task 1,')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Hand it to someone else'));
      await tester.pumpAndSettle();
      expect(find.byType(UiCombobox), findsOneWidget);
      expect(find.byType(UiSearchInput), findsNothing);
      await tester.enterText(find.descendant(of: find.byType(UiCombobox), matching: find.byType(EditableText)), 'ali');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(api.calls, contains('searchUsers:ali'));
      expect(enabled(tester, button('Hand over')), isFalse);
      await tester.tap(find.text('Ali Rasheed (ali@example.com)'));
      await tester.pumpAndSettle();
      expect(enabled(tester, button('Hand over')), isTrue);
      // Searching again keeps the chosen person listed, so the field still names them.
      final field = find.descendant(of: find.byType(UiCombobox), matching: find.byType(EditableText));
      await tester.enterText(field, 'mar');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(api.calls, contains('searchUsers:mar'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(field).controller.text, 'Ali Rasheed (ali@example.com)');
      await tester.tap(button('Hand over'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('delegate:t1:ali'));
    });

    testWidgets('Close sits at the start of the footer and the decisions at its end', (tester) async {
      final task = UiWfTask.fromJson(FakeWorkflowApi.taskJson('t1'));
      await pumpUi(tester, Builder(builder: (ctx) => UiButton(label: 'Open', onPressed: () => showWfDecideDialog(ctx, task: task, api: FakeWorkflowApi()))), size: const Size(700, 900));
      await tester.tap(button('Open'));
      await tester.pumpAndSettle();
      final modal = tester.getRect(find.byType(UiModal));
      final dialog = find.descendant(of: find.byType(UiModal), matching: find.byType(DecoratedBox)).first;
      final panel = tester.getRect(dialog);
      expect(modal.contains(panel.center), isTrue);
      expect(tester.getRect(button('Close')).left - panel.left, lessThan(40));
      expect(panel.right - tester.getRect(button('Reject')).right, lessThan(40));
    });

    testWidgets('earlier decisions read as a bulleted list', (tester) async {
      final api = FakeWorkflowApi();
      final task = UiWfTask.fromJson({
        ...FakeWorkflowApi.taskJson('t1'),
        'decisions': [
          {'userId': 'ali', 'name': 'Ali', 'outcome': 'approved'},
          {'userId': 'hana', 'name': 'Hana', 'outcome': 'rejected', 'comment': 'No'},
        ],
      });
      await pumpUi(tester, Builder(builder: (ctx) => UiButton(label: 'Open', onPressed: () => showWfDecideDialog(ctx, task: task, api: api))), size: const Size(700, 900));
      await tester.tap(button('Open'));
      await tester.pumpAndSettle();
      expect(find.text('•'), findsNWidgets(2));
      expect(tester.getTopLeft(find.text('•').first).dx, lessThan(tester.getTopLeft(find.textContaining('chose “Approve”', findRichText: true)).dx));
    });
  });

  group('skip and cancel dialogs', () {
    Future<_GateApi> pumpRun(WidgetTester tester, {bool fail = false}) async {
      final api = _GateApi()..fail = fail;
      await pumpUi(tester, SizedBox(width: 520, child: WfRunView(api: api, instanceId: 'r1')), size: const Size(520, 900));
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('Back and the confirm button wait while cancelling, and so do the backdrop and Back', (tester) async {
      final api = await pumpRun(tester);
      await tester.tap(button('Cancel the run'));
      await tester.pumpAndSettle();
      await tester.tap(inModal(button('Cancel the run')));
      await tester.pump();
      expect(enabled(tester, button('Back')), isFalse);
      expect(enabled(tester, inModal(button('Cancel the run'))), isFalse);
      await tester.tapAt(const Offset(5, 5));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(UiModal), findsOneWidget);
      api.gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(UiModal), findsNothing);
    });

    testWidgets('a cancel that fails after the dialog was taken away is dropped quietly', (tester) async {
      final api = await pumpRun(tester, fail: true);
      await tester.tap(button('Cancel the run'));
      await tester.pumpAndSettle();
      await tester.tap(inModal(button('Cancel the run')));
      await tester.pump();
      _removeTopRoute(tester);
      await tester.pumpAndSettle();
      api.gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The error shows under the run's buttons instead.
      expect(find.text('Too late'), findsOneWidget);
    });

    testWidgets('a skip that fails after the dialog was taken away is dropped quietly', (tester) async {
      final api = await pumpRun(tester, fail: true);
      await tester.tap(button('Skip the step'));
      await tester.pumpAndSettle();
      await tester.tap(inModal(button('Skip the step')));
      await tester.pump();
      expect(enabled(tester, button('Back')), isFalse);
      _removeTopRoute(tester);
      await tester.pumpAndSettle();
      api.gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a double tap on Skip opens one dialog while the step\'s outputs are read', (tester) async {
      final api = await pumpRun(tester);
      api.schemaGate = Completer<void>();
      await tester.tap(button('Skip the step'));
      await tester.pump();
      await tester.tap(button('Skip the step'));
      await tester.pump();
      api.schemaGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(UiModal), findsOneWidget);
      expect(api.schemaCalls, 1);
    });
  });

  group('task list', () {
    testWidgets('says it is loading before the first answer, not that nothing is waiting', (tester) async {
      final api = _SlowTasks();
      await pumpUi(tester, SizedBox(width: 500, child: WfTaskInbox(api: api)), size: const Size(500, 600));
      expect(find.text('Loading…'), findsOneWidget);
      expect(find.text('Nothing is waiting for you.'), findsNothing);
      api.pending.single.complete(UiWfPage(const [], 0));
      await tester.pumpAndSettle();
      expect(find.text('Nothing is waiting for you.'), findsOneWidget);
    });

    testWidgets('says nothing about an empty list next to an error', (tester) async {
      final api = FakeWorkflowApi()..failNext = const UiWfApiError(500, 'boom', 'The server is down.');
      await pumpUi(tester, SizedBox(width: 500, child: WfTaskInbox(api: api)), size: const Size(500, 600));
      expect(find.text('The server is down.'), findsOneWidget);
      expect(find.text('Nothing is waiting for you.'), findsNothing);
      expect(find.text('Loading…'), findsNothing);
    });

    testWidgets('words the empty list for everyone\'s tasks when scope is all', (tester) async {
      final api = FakeWorkflowApi()..taskList = [];
      await pumpUi(tester, SizedBox(width: 500, child: WfTaskInbox(api: api, scope: 'all')), size: const Size(500, 600));
      expect(find.text('No open tasks.'), findsOneWidget);
      await pumpUi(tester, SizedBox(width: 500, child: WfTaskInbox(key: const ValueKey('mine'), api: api)), size: const Size(500, 600));
      expect(find.text('Nothing is waiting for you.'), findsOneWidget);
    });

    testWidgets('its switch is named "Which tasks" and Show more is an outline button', (tester) async {
      final h = tester.ensureSemantics();
      await pumpUi(tester, SizedBox(width: 500, child: WfTaskInbox(api: FakeWorkflowApi(), pageSize: 2)), size: const Size(500, 600));
      expect(tester.widget<UiSegmented<String>>(find.byType(UiSegmented<String>)).label, 'Which tasks');
      expect(tester.widget<UiButton>(button('Show more')).variant, UiButtonVariant.outline);
      h.dispose();
    });
  });

  testWidgets('section headings reach screen readers as written, not upper-cased', (tester) async {
    final h = tester.ensureSemantics();
    await pumpUi(tester, const WfSectionTitle('Waiting for'));
    expect(find.text('WAITING FOR'), findsOneWidget);
    expect(find.bySemanticsLabel('Waiting for'), findsOneWidget);
    expect(find.bySemanticsLabel('WAITING FOR'), findsNothing);
    h.dispose();
  });

  testWidgets('the reset row is set apart by a dashed rule', (tester) async {
    final api = FakeWorkflowApi();
    api.recordJson = {...api.recordJson, 'reset': {'label': 'Start over', 'to': 'draft', 'toLabel': 'Draft'}};
    final record = await api.record('application', '1');
    await _pumpPage(tester, WfRecordActions(api: api, record: record, entity: 'application', entityId: '1'));
    final paint = tester.widget<CustomPaint>(find.byKey(const ValueKey('wf-reset-row')));
    expect(paint.painter, isA<WfDashedTopRule>());
  });

  group('audit log', () {
    testWidgets('names workflows by the new engine\'s titles when the api changes', (tester) async {
      final a = _TitledApi('Old title');
      final b = _TitledApi('New title');
      final api = ValueNotifier<UiWorkflowApi>(a);
      await _pumpPage(tester, ValueListenableBuilder(valueListenable: api, builder: (_, v, _) => UiWorkflowAudit(api: v)), size: const Size(800, 900));
      expect(find.textContaining('Old title'), findsWidgets);
      api.value = b;
      await tester.pumpAndSettle();
      expect(b.definitionCalls, 1);
      expect(find.textContaining('New title'), findsWidgets);
      expect(find.textContaining('Old title'), findsNothing);
    });

    testWidgets('the Kind filter is 200 wide and the buttons sit at the right on wide screens', (tester) async {
      await _pumpPage(tester, UiWorkflowAudit(api: FakeWorkflowApi(), onExport: (_, _) {}), size: const Size(900, 900));
      expect(tester.getSize(find.ancestor(of: find.byType(WfSelect), matching: find.byType(SizedBox)).first).width, 200);
      final right = tester.getTopRight(button('CSV')).dx;
      expect(right, closeTo(900 - 16, 1));
    });

    testWidgets('an opened entry lines up under its text on wide screens, at the edge on phones', (tester) async {
      await _pumpPage(tester, UiWorkflowAudit(api: FakeWorkflowApi()), size: const Size(900, 1600));
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Entry 60:')));
      await tester.pumpAndSettle();
      final listLeft = tester.getTopLeft(find.bySemanticsLabel(RegExp(r'^Entry 60:'))).dx;
      expect(tester.getTopLeft(find.text('About')).dx - listLeft, closeTo(66, 1));
      await _pumpPage(tester, UiWorkflowAudit(key: const ValueKey('phone'), api: FakeWorkflowApi()), size: const Size(380, 1600));
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Entry 60:')));
      await tester.pumpAndSettle();
      final phoneLeft = tester.getTopLeft(find.bySemanticsLabel(RegExp(r'^Entry 60:'))).dx;
      expect(tester.getTopLeft(find.text('About')).dx - phoneLeft, closeTo(10, 1));
    });
  });

}

/// Answers tasks() only when told to.
class _SlowTasks extends FakeWorkflowApi {
  final pending = <Completer<UiWfPage<UiWfTask>>>[];
  @override
  Future<UiWfPage<UiWfTask>> tasks(UiWfTaskQuery q) {
    final c = Completer<UiWfPage<UiWfTask>>();
    pending.add(c);
    return c.future;
  }
}

/// An engine whose entries come from a workflow it calls [title].
class _TitledApi extends FakeWorkflowApi {
  _TitledApi(this.title) {
    auditList = [
      {
        'seq': 1, 'id': 'e1', 'at': '2026-10-17T09:00:00Z', 'actorType': 'workflow', 'actorId': 'review', 'category': 'lifecycle', 'action': 'transitioned',
        'subjectType': 'record', 'subjectId': '1', 'entity': 'application', 'entityId': '1', 'correlationId': 'c', 'prevHash': 'p', 'hash': 'h',
      },
    ];
  }
  final String title;
  int definitionCalls = 0;
  @override
  Future<List<UiWfDefinitionSummary>> definitions() async {
    definitionCalls++;
    return [UiWfDefinitionSummary.fromJson({'id': 'd', 'key': 'review', 'title': title})];
  }
}
