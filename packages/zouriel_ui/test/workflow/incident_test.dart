import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/workflow/history.dart' show wfParkedTimerName, wfReadableError, wfStoppedLabel, wfTimerParked;
import 'package:zouriel_ui/src/workflow/runtime.dart' show WfRunView;
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fake_api.dart';

// Mirrors @zouriel/ui 0502ab8: a timer that kept failing puts its instance in `incident` (record
// instances included); Try again re-arms it, Skip drops it.

Finder button(String label) => find.byWidgetPredicate((w) => w is UiButton && w.label == label);
Finder inModal(Finder f) => find.descendant(of: find.byType(UiModal), matching: f);

const _tail = ' failed 10 times and was stopped: InvalidOperationException: The database refused writing application.status.';
const _timer = 'A timer (reminder) failed 10 times and was stopped: mail down';

UiWfInstance inst(Map<String, Object?> j) => UiWfInstance.fromJson({
      'id': 'x', 'title': 'T', 'kind': 'automation', 'status': 'incident', 'startedAt': DateTime.now().toUtc().toIso8601String(), 'steps': <Object?>[], ...j,
    });

/// An engine with one instance in incident (a run held by a reminder, or a record instance).
class _Stuck extends FakeWorkflowApi {
  _Stuck(this.run, {bool intervene = true}) {
    canIntervene = intervene;
  }
  Map<String, Object?> run;
  final acted = <String>[];
  final asked = <UiWfInstanceQuery>[];

  @override
  Future<UiWfInstance> instance(String id) async => UiWfInstance.fromJson(run);
  @override
  Future<UiWorkflowDefinition> instanceDefinition(String id) async => createWorkflow('lifecycle', title: 'Application status', entity: 'application');
  @override
  Future<UiWfInstance> retry(String id, {String? target}) async {
    acted.add('retry:$id:${target ?? ''}');
    run = {...run, 'status': 'active', 'error': null};
    recordJson = {...recordJson, 'status': 'active', 'error': null};
    return UiWfInstance.fromJson(run);
  }

  @override
  Future<UiWfInstance> skip(String id, {UiJson? outputs, String? target}) async {
    acted.add('skip:$id:${outputs ?? ''}');
    run = {...run, 'status': 'active', 'error': null};
    recordJson = {...recordJson, 'status': 'active', 'error': null};
    return UiWfInstance.fromJson(run);
  }

  @override
  Future<UiWfPage<UiWfInstance>> instances(UiWfInstanceQuery q) async {
    asked.add(q);
    return UiWfPage([
      inst({'id': 'other', 'kind': 'record', 'definitionKey': 'someOther'}),
      inst({'id': 'own', 'kind': 'record', 'definitionKey': 'appLife'}),
    ], 2);
  }
}

void main() {
  group('helpers', () {
    test('names a parked timer by what it was for, and drops the exception type after its own prefix', () {
      expect(wfReadableError('A timer (auto:tx)$_tail'), 'An automatic move failed 10 times and was stopped: The database refused writing application.status.');
      expect(wfReadableError('A timer (sla:s)$_tail'), startsWith('A time limit failed'));
      expect(wfReadableError('A timer (reminder)$_tail'), startsWith('A reminder failed'));
      expect(wfReadableError('A timer (escalation)$_tail'), startsWith('An escalation failed'));
      expect(wfReadableError('A timer (somethingNew)$_tail'), startsWith('A timer failed'));
      expect(wfReadableError('Step failed: NoException: x'), 'Step failed: x');
      expect(wfReadableError('See MyException docs'), 'See MyException docs');
      expect(wfReadableError('InvalidOperationException: Bank API: 503'), 'Bank API: 503');
    });

    test('wfParkedTimerName: the timer an incident names, as a sentence object', () {
      expect(wfParkedTimerName('A timer (auto:tx) failed 2 times and was stopped: x'), 'the automatic move');
      expect(wfParkedTimerName('A timer (sla:s) failed'), 'the time limit');
      expect(wfParkedTimerName('A timer (reminder) failed'), 'the reminder');
      expect(wfParkedTimerName('A timer (escalation) failed'), 'the escalation');
      expect(wfParkedTimerName(null), 'the timer');
    });

    test('wfTimerParked: a record instance in incident, or a run in incident with no path stopped on a step', () {
      expect(wfTimerParked(inst({'kind': 'record', 'error': 'anything'})), isTrue);
      expect(wfTimerParked(inst({'kind': 'run', 'error': _timer, 'tokens': [{'id': 't', 'status': 'waiting', 'waiting': 'task', 'stepId': 'ap'}]})), isTrue);
      expect(wfTimerParked(inst({'kind': 'run', 'error': _timer, 'tokens': [{'id': 't', 'status': 'waiting', 'waiting': 'incident', 'stepId': 'pay'}]})), isFalse);
      expect(wfTimerParked(inst({'kind': 'automation', 'error': 'Bank API: 503', 'tokens': <Object?>[]})), isFalse);
      expect(wfTimerParked(inst({'kind': 'record', 'status': 'active'})), isFalse);
    });

    test('wfStoppedLabel: "<workflow> · <record>", the record by title, else id', () {
      expect(wfStoppedLabel(inst({'title': 'Expiry', 'entityTitle': 'Grant a1', 'entityId': 'a1'})), 'Expiry · Grant a1');
      expect(wfStoppedLabel(inst({'title': 'Expiry', 'entityId': 'a1'})), 'Expiry · a1');
      expect(wfStoppedLabel(inst({'title': 'Nightly'})), 'Nightly');
    });
  });

  group('run view', () {
    Map<String, Object?> parkedRun() => {
          'id': 'r1', 'title': 'Review', 'kind': 'run', 'status': 'incident', 'error': _timer, 'version': 1,
          'startedAt': DateTime.now().toUtc().toIso8601String(), 'steps': <Object?>[],
          'tokens': [{'id': 't', 'status': 'waiting', 'waiting': 'task', 'stepId': 'ap'}],
        };
    Map<String, Object?> recordInstance() => {
          'id': 'rec1', 'title': 'Application status', 'kind': 'record', 'status': 'incident', 'error': 'A timer (auto:t2)$_tail', 'version': 1,
          'startedAt': DateTime.now().toUtc().toIso8601String(), 'steps': <Object?>[], 'tokens': <Object?>[],
        };
    Future<_Stuck> pump(WidgetTester tester, Map<String, Object?> run, {bool intervene = true}) async {
      final api = _Stuck(run, intervene: intervene);
      await pumpUi(tester, SizedBox(width: 520, child: WfRunView(api: api, instanceId: run['id']! as String)), size: const Size(520, 900));
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('a run held by a parked timer shows the readable error and tries it again', (tester) async {
      final api = await pump(tester, parkedRun());
      expect(find.text('Stopped: A reminder failed 10 times and was stopped: mail down', findRichText: true), findsOneWidget);
      expect(find.text('Try again runs it now. Skip drops it; the task stays open and can still be decided.'), findsOneWidget);
      expect(button('Cancel the run'), findsOneWidget);
      await tester.tap(button('Try again'));
      await tester.pumpAndSettle();
      expect(api.acted, ['retry:r1:']);
    });

    testWidgets('skipping a parked timer is confirmed, asks for no results, and drops it', (tester) async {
      final api = await pump(tester, parkedRun());
      await tester.tap(button('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Skip the reminder'), findsOneWidget);
      expect(find.text('It is dropped without running. The task stays open and can still be decided.'), findsOneWidget);
      expect(find.byType(UiInput), findsNothing);
      await tester.tap(inModal(button('Skip it')));
      await tester.pumpAndSettle();
      expect(api.acted, ['skip:r1:']);
    });

    testWidgets('a lifecycle record instance in incident shows its error with Try again and Skip, no step list and no cancel', (tester) async {
      await pump(tester, recordInstance());
      expect(find.textContaining('An automatic move failed 10 times', findRichText: true), findsOneWidget);
      expect(find.text('Try again runs it now. Skip drops it: the record stays where it is. Moving the record by hand also clears this.'), findsOneWidget);
      expect(button('Try again'), findsOneWidget);
      expect(button('Skip'), findsOneWidget);
      expect(button('Cancel the run'), findsNothing);
      await tester.tap(button('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Skip the automatic move'), findsOneWidget);
      expect(find.text('It is dropped without running: the record stays where it is, with nothing scheduled in its place. It can still be moved by hand.'), findsOneWidget);
    });

    testWidgets('people who may not intervene see why a parked timer stopped it and who can fix it, without buttons', (tester) async {
      await pump(tester, parkedRun(), intervene: false);
      expect(find.textContaining('A reminder failed', findRichText: true), findsOneWidget);
      expect(find.text('Someone who looks after workflows can try it again or skip it.'), findsOneWidget);
      expect(button('Try again'), findsNothing);
    });

    testWidgets('a waiting run is not flagged, whatever its error field says', (tester) async {
      await pump(tester, {...parkedRun(), 'status': 'waiting'});
      expect(find.textContaining('Stopped:', findRichText: true), findsNothing);
      expect(button('Try again'), findsNothing);
    });
  });

  group('panel: a record whose own lifecycle is stuck', () {
    Future<_Stuck> pumpPanel(WidgetTester tester, {bool intervene = true}) async {
      final api = _Stuck({}, intervene: intervene);
      api.recordJson = {...api.recordJson, 'status': 'incident', 'error': 'A timer (auto:t2)$_tail'};
      await pumpUi(tester, SizedBox(width: 520, height: 1200, child: SingleChildScrollView(child: UiWorkflowPanel(api: api, entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.compact))), size: const Size(520, 1200));
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('shows a warning banner with the readable error, and the moves still work', (tester) async {
      final api = await pumpPanel(tester);
      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('An automatic move failed 10 times and was stopped: The database refused writing application.status.'), findsOneWidget);
      expect(api.calls, contains('me'));
      expect(button('Approve'), findsOneWidget);
      expect(find.textContaining('Skip drops it, and the record stays in In review.'), findsOneWidget);
    });

    testWidgets('people who may not intervene read the reason and that someone has been told, without buttons', (tester) async {
      await pumpPanel(tester, intervene: false);
      expect(find.text('The record can still be moved. Someone who looks after workflows has been told.'), findsOneWidget);
      expect(button('Try again'), findsNothing);
      expect(button('Skip'), findsNothing);
    });

    testWidgets('Try again finds the record\'s own lifecycle instance and retries it, then reads the record again', (tester) async {
      final api = await pumpPanel(tester);
      final reads = api.calls.where((c) => c.startsWith('record:')).length;
      await tester.tap(button('Try again'));
      await tester.pumpAndSettle();
      final q = api.asked.single;
      expect((q.entity, q.entityId, q.take), ('application', '1', 10));
      expect(q.kind, ['record']);
      expect(q.status, ['incident']);
      expect(api.acted, ['retry:own:']);
      expect(api.calls.where((c) => c.startsWith('record:')).length, reads + 1);
      expect(find.text('Needs attention'), findsNothing);
    });

    testWidgets('Skip asks first, then skips the record\'s lifecycle instance', (tester) async {
      final api = await pumpPanel(tester);
      await tester.tap(button('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Skip the automatic move'), findsOneWidget);
      expect(find.text('It is dropped without running: the record stays where it is, with nothing scheduled in its place. It can still be moved by hand.'), findsOneWidget);
      expect(api.acted, isEmpty);
      await tester.tap(inModal(button('Skip it')));
      await tester.pumpAndSettle();
      expect(api.acted, ['skip:own:']);
      expect(find.byType(UiModal), findsNothing);
    });

    testWidgets('me() is asked only once the record is stuck', (tester) async {
      final api = FakeWorkflowApi();
      await pumpUi(tester, SizedBox(width: 520, child: UiWorkflowPanel(api: api, entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.compact)), size: const Size(520, 900));
      expect(api.calls, isNot(contains('me')));
    });
  });

  testWidgets('tasks drawer: a stopped record instance is listed as "<lifecycle> · <record>" and opens with Try again and Skip', (tester) async {
    final api = _DrawerStuck();
    final key = GlobalKey<UiWorkflowTasksDrawerState>();
    await pumpUi(tester, UiWorkflowTasksDrawer(key: key, api: api, refreshSeconds: 0), size: const Size(900, 900));
    key.currentState!.show();
    await tester.pumpAndSettle();
    expect(find.text('They need someone to try again or skip what stopped them.'), findsOneWidget);
    expect(find.text('Application status · a1'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('^Application status · a1')));
    await tester.pumpAndSettle();
    expect(button('Try again'), findsOneWidget);
    expect(button('Skip'), findsOneWidget);
    expect(button('Cancel the run'), findsNothing);
  });
}

class _DrawerStuck extends _Stuck {
  _DrawerStuck()
      : super({
          'id': 'rec1', 'title': 'Application status', 'kind': 'record', 'status': 'incident', 'entityId': 'a1', 'error': 'A timer (sla:s)$_tail',
          'version': 1, 'startedAt': DateTime.now().toUtc().toIso8601String(), 'steps': <Object?>[], 'tokens': <Object?>[],
        });
  @override
  Future<UiWfPage<UiWfInstance>> instances(UiWfInstanceQuery q) async => UiWfPage([UiWfInstance.fromJson(run)], 1);
}
