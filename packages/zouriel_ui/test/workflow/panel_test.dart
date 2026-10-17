import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/workflow/bits.dart' show WfArrowText, wfArrow;
import 'package:zouriel_ui/src/workflow/panel.dart' show wfPanelPath, UiWfPanelStep;
import 'package:zouriel_ui/src/workflow/runtime.dart' show WfRunView;
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import '../media/media_helpers.dart';
import 'fake_api.dart';

Finder button(String label) => find.byWidgetPredicate((w) => w is UiButton && w.label == label);

UiWfRecord record(String state, {List<Object?> transitions = const []}) => UiWfRecord.fromJson({
      'entity': 'application', 'id': '1', 'title': 'A', 'lifecycle': 'l', 'lifecycleTitle': 'L', 'state': state, 'stateLabel': state, 'stateTone': null,
      'status': 'active', 'stateEnteredAt': DateTime.now().toUtc().toIso8601String(), 'transitions': transitions, 'tasks': <Object?>[],
      'instances': <Object?>[], 'manual': <Object?>[],
      'states': [
        {'key': 'Draft', 'label': 'Draft', 'category': 'initial', 'tone': null},
        {'key': 'Submitted', 'label': 'Submitted', 'category': 'active', 'tone': null},
        {'key': 'Review', 'label': 'Under review', 'category': 'active', 'tone': null},
        {'key': 'Approved', 'label': 'Approved', 'category': 'terminal', 'tone': 'success'},
        {'key': 'Rejected', 'label': 'Rejected', 'category': 'terminal', 'tone': 'danger'},
      ],
    });

int _seq = 0;
UiWfAuditEntry entry(String action, String? after, {String? before, String category = 'lifecycle'}) => UiWfAuditEntry.fromJson({
      'seq': ++_seq, 'at': DateTime.now().toUtc().toIso8601String(), 'actorType': 'user', 'actorName': 'Ali', 'category': category, 'action': action,
      'before': before == null ? null : '{"state":"$before"}', 'after': after == null ? null : '{"state":"$after"}', 'data': '{}',
    });

List<String> keys(({List<UiWfPanelStep> steps, int active, List<UiWfAuditEntry> earlier}) p) => [for (final s in p.steps) s.key];

Future<void> pumpPanel(WidgetTester tester, UiWorkflowPanel panel, {Size size = const Size(480, 900)}) async {
  await pumpUi(tester, SizedBox(width: size.width, height: size.height, child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: panel)), size: size);
  await tester.pumpAndSettle();
}

/// A fake whose record has nothing for the viewer to do.
class _IdleApi extends FakeWorkflowApi {
  @override
  void reset() {
    super.reset();
    recordJson['transitions'] = <Object?>[];
    recordJson['manual'] = <Object?>[];
    recordJson['tasks'] = <Object?>[];
  }
}

/// One record and its history, nothing else.
class _RecordApi extends Fake implements UiWorkflowApi {
  _RecordApi(this.rec, this.history);
  final UiWfRecord rec;
  final List<UiWfAuditEntry> history;
  @override
  Future<UiWfRecord> record(String entity, String id) async => rec;
  @override
  Future<List<UiWfAuditEntry>> recordHistory(String entity, String id, {int take = 200}) async => history;
}

Map<String, Object?> _run(String id, String title, String status, [String? error]) => {
      'id': id, 'definitionId': 'd', 'definitionKey': 'k', 'title': title, 'version': 1, 'kind': 'automation', 'entity': 'application', 'entityId': '1',
      'entityTitle': 'A', 'status': status, 'error': error, 'startedAt': DateTime.now().toUtc().toIso8601String(), 'updatedAt': '',
      'steps': <Object?>[], 'tokens': <Object?>[],
    };

/// A record with runs, which the panel lists under "Running" and opens with their steps.
class _RunsApi extends _RecordApi {
  _RunsApi(List<Map<String, Object?>> runs, {this.canIntervene = true})
    : runs = runs,
      super(UiWfRecord.fromJson({...record('Submitted').json, 'instances': runs}), const []);
  final List<Map<String, Object?>> runs;
  final bool canIntervene;
  final loaded = <String>[];
  final retried = <String>[];

  @override
  Future<UiWfInstance> instance(String id) async {
    loaded.add(id);
    return UiWfInstance.fromJson(runs.firstWhere((r) => r['id'] == id));
  }

  /// What [instanceDefinition] answers (an empty workflow unless set).
  UiWorkflowDefinition runDefinition = createWorkflow('automation', title: 'W', entity: 'application');

  @override
  Future<UiWorkflowDefinition> instanceDefinition(String id) async => runDefinition;
  @override
  Future<UiWfMe> me() async => UiWfMe.fromJson({'can': {'intervene': canIntervene}});
  @override
  Future<UiWfInstance> retry(String id, {String? target}) async {
    retried.add(id);
    return UiWfInstance.fromJson({...runs.firstWhere((r) => r['id'] == id), 'status': 'running', 'error': null});
  }
}

/// A record type with no lifecycle, with one manual workflow.
UiWfRecord noLifecycle() => UiWfRecord.fromJson({
      ...record('Draft').json,
      'lifecycle': null, 'lifecycleTitle': null, 'state': null, 'stateLabel': null, 'status': null, 'stateEnteredAt': null, 'states': <Object?>[],
      'manual': [{'key': 'remind', 'label': 'Send a reminder', 'form': null}],
    });

void main() {
  group('wfPanelPath', () {
    test('visited states first, then the ones not reached, in the lifecycle order', () {
      final p = wfPanelPath(record('Submitted'), [entry('created', 'Draft'), entry('transitioned', 'Submitted', before: 'Draft')]);
      expect(keys(p), ['Draft', 'Submitted', 'Review', 'Approved', 'Rejected']);
      expect(p.active, 1);
    });

    test('each entry sits under the state it happened in, whatever order the history arrives in', () {
      final created = entry('created', 'Draft');
      final moved = entry('transitioned', 'Submitted', before: 'Draft');
      final task = entry('created', null, category: 'task');
      final p = wfPanelPath(record('Submitted'), [task, moved, created]);
      expect(p.steps[0].entries.map((e) => e.seq), [created.seq]);
      expect(p.steps[1].entries.map((e) => e.seq), [moved.seq, task.seq]);
    });

    test('a finished record shows only the path it took', () {
      final p = wfPanelPath(record('Rejected'), [entry('created', 'Draft'), entry('transitioned', 'Rejected', before: 'Draft')]);
      expect(keys(p), ['Draft', 'Rejected']);
      expect(p.active, 1);
    });

    test('sent back: active on the earlier state, the later one counts as not reached', () {
      final p = wfPanelPath(record('Draft'), [entry('created', 'Draft'), entry('transitioned', 'Submitted', before: 'Draft'), entry('transitioned', 'Draft', before: 'Submitted')]);
      expect(keys(p).take(2), ['Draft', 'Submitted']);
      expect(p.active, 0);
    });
  });

  group('UiWorkflowPanel', () {
    testWidgets('vertical: the states, history under each, and the current state\'s moves', (tester) async {
      final api = FakeWorkflowApi();
      await pumpPanel(tester, UiWorkflowPanel(api: api, entity: 'application', entityId: '1'));
      expect(find.text('Workflow'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Started in Draft'), findsOneWidget);
      expect(button('Approve'), findsOneWidget);
      expect(button('Ask for documents'), findsOneWidget);
      expect(find.text('Not reached yet'), findsOneWidget); // Approved
      expect(find.text('Nothing for you to do here right now.'), findsNothing);
    });

    testWidgets('with nothing for this person to do, it says so', (tester) async {
      await pumpPanel(tester, UiWorkflowPanel(api: _IdleApi(), entity: 'application', entityId: '1'));
      expect(find.text('Nothing for you to do here right now.'), findsOneWidget);
    });

    testWidgets('a move applies through the engine and reloads', (tester) async {
      final api = FakeWorkflowApi();
      UiWfRecord? changed;
      await pumpPanel(tester, UiWorkflowPanel(api: api, entity: 'application', entityId: '1', onChanged: (r) => changed = r));
      await tester.tap(button('Withdraw'));
      await tester.pumpAndSettle();
      expect(api.calls.where((c) => c.startsWith('apply')), isNotEmpty);
      expect(changed, isNotNull);
    });

    testWidgets('side drawer: a rail of dots; a mouse hover peeks, moving away closes it', (tester) async {
      final api = FakeWorkflowApi();
      await pumpPanel(tester, UiWorkflowPanel(api: api, entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.sideDrawer));
      final h = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Workflow: In review, step 2 of 3. Open'), findsOneWidget);
      h.dispose();
      expect(find.byType(UiDrawer), findsNothing);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1, 1));
      await mouse.moveTo(tester.getCenter(find.byType(UiStepper)));
      await tester.pumpAndSettle();
      expect(find.byType(UiDrawer), findsOneWidget);
      expect(button('Approve'), findsOneWidget);

      await mouse.moveTo(const Offset(40, 450));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byType(UiDrawer), findsNothing);
      await mouse.removePointer();
    });

    testWidgets('a tap on the rail opens the drawer; a finger never peeks', (tester) async {
      final api = FakeWorkflowApi();
      await pumpPanel(tester, UiWorkflowPanel(api: api, entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.bottomDrawer));
      await tester.tap(find.byType(UiStepper));
      await tester.pumpAndSettle();
      expect(find.byType(UiDrawer), findsOneWidget);
      expect(find.text('HISTORY'), findsOneWidget); // the horizontal body
    });

    testWidgets('tap targets and labels', (tester) async {
      final h = tester.ensureSemantics();
      await pumpPanel(tester, UiWorkflowPanel(api: FakeWorkflowApi(), entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.sideDrawer));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      h.dispose();
    });

    testWidgets('golden: vertical and horizontal', (tester) async {
      await expectThemedGolden(
        tester,
        'workflow_panel',
        (context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 24, children: [
          UiWorkflowPanel(api: FakeWorkflowApi(), entity: 'application', entityId: '1'),
          UiWorkflowPanel(api: FakeWorkflowApi(), entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.horizontal),
        ]),
        width: 520,
        height: 1100,
      );
    });

    testWidgets('compact: the state as a badge and a strip, the moves, and one flat history newest first (what the record panel was)', (tester) async {
      final api = _RecordApi(
        record('Submitted', transitions: [{'key': 'approve', 'label': 'Approve', 'to': 'Approved', 'toLabel': 'Approved', 'tone': 'success', 'confirm': null, 'form': null}]),
        [entry('created', 'Draft'), UiWfAuditEntry.fromJson({...entry('transitioned', 'Submitted', before: 'Draft').json, 'data': '{"label":"Submit"}'})],
      );
      await pumpPanel(tester, UiWorkflowPanel(api: api, entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.compact));
      expect(find.byType(UiStepper), findsNothing);
      final track = find.byKey(const ValueKey('wf-track'));
      final strip = [for (final t in tester.widgetList<Text>(find.descendant(of: track, matching: find.byType(Text)))) t];
      expect([for (final t in strip) t.data], ['Draft', 'Submitted', 'Under review', 'Approved', 'Rejected']);
      final ui = tester.element(track).ui;
      Color? colorOf(String label) => strip.firstWhere((t) => t.data == label).style?.color;
      expect(colorOf('Submitted'), ui.primaryContrast, reason: 'here');
      expect(colorOf('Draft'), ui.success, reason: 'done: a tint of success, like the stepper');
      expect(colorOf('Approved'), ui.textMuted, reason: 'not reached');
      expect(button('Approve'), findsOneWidget);
      final log = [for (final w in tester.widgetList<WfArrowText>(find.byType(WfArrowText))) w.text];
      expect(log, ['Submit: Draft $wfArrow Submitted', 'Started in Draft']);
    });

    testWidgets('compact: an empty history says so; an empty title hides the heading', (tester) async {
      await pumpPanel(tester, UiWorkflowPanel(api: _RecordApi(record('Draft'), const []), entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.compact, title: ''));
      expect(find.text('Nothing yet.'), findsOneWidget);
      expect(find.text('Workflow'), findsNothing);
      await pumpPanel(tester, UiWorkflowPanel(api: _RecordApi(record('Draft'), const []), entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.compact));
      expect(find.text('Workflow'), findsOneWidget);
    });

    testWidgets('compact: the panel\'s gap is the only space between its blocks', (tester) async {
      await pumpPanel(tester, UiWorkflowPanel(api: FakeWorkflowApi(), entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.compact));
      final ui = tester.element(find.byType(UiWorkflowPanel)).ui;
      final heading = tester.getRect(find.text('Workflow'));
      final badge = tester.getRect(find.byType(UiWorkflowStateBadge).first);
      final track = tester.getRect(find.byKey(const ValueKey('wf-track')));
      expect(badge.top - heading.bottom, moreOrLessEquals(ui.space2, epsilon: 0.5));
      final stateRow = tester.getRect(find.ancestor(of: find.byType(UiWorkflowStateBadge).first, matching: find.byType(Wrap)).first);
      expect(track.top - stateRow.bottom, moreOrLessEquals(ui.space2, epsilon: 0.5));
    });

    for (final layout in [UiWorkflowPanelLayout.vertical, UiWorkflowPanelLayout.horizontal, UiWorkflowPanelLayout.compact]) {
      testWidgets('a record type with no lifecycle still shows its manual workflows and history (${layout.name})', (tester) async {
        final api = _RecordApi(noLifecycle(), [entry('started', null, category: 'instance')]);
        await pumpPanel(tester, UiWorkflowPanel(api: api, entity: 'application', entityId: '1', layout: layout));
        expect(find.text('No lifecycle for this record type.'), findsOneWidget);
        expect(button('Send a reminder'), findsOneWidget);
        expect(find.byType(WfArrowText), findsOneWidget); // the one history entry
        expect(find.text('Nothing for you to do here right now.'), findsNothing);
        expect(find.byType(UiStepper), findsNothing);
      });
    }

    testWidgets('a drawer still opens for a record with no lifecycle: its rail keeps one dot', (tester) async {
      final api = _RecordApi(noLifecycle(), const []);
      await pumpPanel(tester, UiWorkflowPanel(api: api, entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.sideDrawer));
      expect(tester.widget<UiStepper>(find.byType(UiStepper)).steps, hasLength(1));
      await tester.tap(find.byType(UiStepper));
      await tester.pumpAndSettle();
      expect(find.byType(UiDrawer), findsOneWidget);
      expect(button('Send a reminder'), findsOneWidget);
    });

    testWidgets('lists the record\'s workflows still running: a stopped one opens with its steps, a waiting one opens when tapped', (tester) async {
      final api = _RunsApi([
        _run('w1', 'Tell the panel', 'waiting'),
        _run('s1', 'Pay approved scholarships', 'incident', 'InvalidOperationException: Bank API: 503'),
        _run('d1', 'Old run', 'completed'),
      ]);
      await pumpPanel(tester, UiWorkflowPanel(api: api, entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.compact));
      expect(find.text('RUNNING'), findsOneWidget);
      // Stopped first, finished runs not listed.
      final titles = [for (final t in ['Pay approved scholarships', 'Tell the panel']) tester.getTopLeft(find.text(t)).dy];
      expect(titles[0], lessThan(titles[1]));
      expect(find.text('Old run'), findsNothing);
      expect(find.text('Bank API: 503'), findsOneWidget, reason: 'the readable error, without the exception type');
      expect(find.textContaining('since '), findsWidgets);
      expect(find.byType(WfRunView), findsOneWidget, reason: 'the stopped one opened by itself');
      expect(button('Try again'), findsOneWidget);
      await tester.tap(find.text('Tell the panel'));
      await tester.pumpAndSettle();
      expect(find.byType(WfRunView), findsNWidgets(2));
      expect(api.loaded, ['s1', 'w1']);
      // Tapped again, it closes; the stopped one doesn't reopen by itself after a reload.
      await tester.tap(find.text('Pay approved scholarships'));
      await tester.pumpAndSettle();
      expect(find.byType(WfRunView), findsOneWidget);
      await tester.state<UiWorkflowPanelState>(find.byType(UiWorkflowPanel)).reload();
      await tester.pumpAndSettle();
      expect(find.byType(WfRunView), findsOneWidget);
    });

    testWidgets('a run changed in place (tried again) reloads the panel', (tester) async {
      final api = _RunsApi([_run('s1', 'Pay approved scholarships', 'incident', 'Bank API: 503')]);
      var records = 0;
      await pumpPanel(tester, UiWorkflowPanel(api: api, entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.horizontal, onChanged: (_) => records++), size: const Size(900, 900));
      final before = api.loaded.length;
      await tester.tap(button('Try again'));
      await tester.pumpAndSettle();
      expect(api.retried, ['s1']);
      expect(api.loaded.length, before, reason: 'the panel reloaded the record, not the run');
    });

    for (final layout in [UiWorkflowPanelLayout.vertical, UiWorkflowPanelLayout.horizontal, UiWorkflowPanelLayout.compact]) {
      testWidgets('Running comes after the actions (${layout.name})', (tester) async {
        final api = _RunsApi([_run('w1', 'Tell the panel', 'waiting')]);
        api.rec.json['transitions'] = [{'key': 'approve', 'label': 'Approve', 'to': 'Approved', 'toLabel': 'Approved', 'tone': 'success', 'confirm': null, 'form': null}];
        // Five states side by side need the room.
        await pumpPanel(tester, UiWorkflowPanel(api: api, entity: 'application', entityId: '1', layout: layout), size: const Size(900, 1200));
        expect(tester.getTopLeft(find.text('RUNNING')).dy, greaterThan(tester.getBottomLeft(button('Approve')).dy));
      });
    }

    testWidgets('people who may not intervene see why it stopped and who can fix it', (tester) async {
      final api = _RunsApi([_run('s1', 'Pay approved scholarships', 'incident', 'Bank API: 503')], canIntervene: false);
      await pumpPanel(tester, UiWorkflowPanel(api: api, entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.compact));
      expect(button('Try again'), findsNothing);
      expect(find.text('Someone who looks after workflows can try it again or skip it.'), findsOneWidget);
    });

    testWidgets('golden: a stopped run in the panel', (tester) async {
      const failure = 'InvalidOperationException: Bank API: 503 Service Unavailable';
      final api = _RunsApi([
        {
          ..._run('s1', 'Pay approved scholarships', 'incident', failure),
          'errorStepId': 'pay',
          'steps': [
            {'id': 'r1', 'nodeId': 'check', 'type': 'approval', 'attempt': 1, 'status': 'completed', 'output': {'outcome': 'approved'}, 'startedAt': ''},
            {'id': 'r2', 'nodeId': 'pay', 'type': 'action', 'attempt': 4, 'status': 'failed', 'error': failure, 'startedAt': ''},
          ],
          'tokens': [{'id': 't1', 'status': 'waiting', 'waiting': 'incident', 'stepId': 'pay'}],
        },
        _run('w1', 'Tell the panel', 'waiting'),
      ]);
      api.runDefinition = createWorkflow('automation', title: 'Pay approved scholarships', entity: 'application').patch({
        'steps': [
          {...createStep('approval').json, 'id': 'check', 'title': 'Finance sign-off'},
          {...createStep('action').json, 'id': 'pay', 'title': 'Create the payment', 'action': 'bank.pay'},
          {...createStep('notify').json, 'id': 'mail', 'title': 'Email the student'},
        ],
      });
      await expectThemedGoldenAfter(
        tester,
        'workflow_panel_running',
        (context) => UiWorkflowPanel(api: api, entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.compact),
        before: (tester) => tester.pumpAndSettle(),
        width: 460,
        height: 760,
      );
    });
  });

  // Mirrors @zouriel/ui 1935963.
  group('wfPanelPath after a reset and with a cut-short history', () {
    test('groups what happened before the latest reset apart; states visited only before it count as not reached', () {
      final h = [
        entry('created', 'Draft'), entry('transitioned', 'Submitted', before: 'Draft'), entry('transitioned', 'Review', before: 'Submitted'),
        entry('reset', 'Draft', before: 'Review'), entry('transitioned', 'Submitted', before: 'Draft'),
      ];
      final p = wfPanelPath(record('Submitted'), h);
      expect([for (final e in p.earlier) e.seq], [for (final e in h.sublist(0, 3)) e.seq]);
      expect(keys(p), ['Draft', 'Submitted', 'Review', 'Approved', 'Rejected']);
      expect([for (final e in p.steps[0].entries) e.action], ['reset']);
      expect(p.steps[2].entries, isEmpty);
      expect(p.active, 1);
    });

    test('entries before the first move of a cut-short history belong to the state that move left', () {
      final task = entry('created', null, category: 'task');
      final moved = entry('transitioned', 'Review', before: 'Submitted');
      final p = wfPanelPath(record('Review'), [task, moved]);
      expect(keys(p).sublist(0, 2), ['Submitted', 'Review']);
      expect([for (final e in p.steps[0].entries) e.seq], [task.seq]);
    });
  });

  group('UiWorkflowPanel reloads', () {
    testWidgets('a late answer for the old record is dropped after a switch', (tester) async {
      final api = _SwitchApi();
      final id = ValueNotifier('1');
      await pumpUi(tester, ValueListenableBuilder<String>(valueListenable: id, builder: (_, v, _) => UiWorkflowPanel(api: api, entity: 'application', entityId: v)), size: const Size(700, 1200));
      api.gates['1'] = Completer<void>();
      tester.state<UiWorkflowPanelState>(find.byType(UiWorkflowPanel)).reload();
      id.value = '2';
      await tester.pumpAndSettle();
      expect(find.text('State 2'), findsWidgets);
      api.gates['1']!.complete();
      await tester.pumpAndSettle();
      expect(find.text('State 1'), findsNothing);
      expect(find.text('State 2'), findsWidgets);
    });

    testWidgets('fires onChanged after any reload that finds a new state, not only for moves made in the panel', (tester) async {
      final api = FakeWorkflowApi();
      final changed = <String?>[];
      await pumpPanel(tester, UiWorkflowPanel(api: api, entity: 'application', entityId: '1', onChanged: (r) => changed.add(r.state)));
      final panel = tester.state<UiWorkflowPanelState>(find.byType(UiWorkflowPanel));
      await panel.reload();
      expect(changed, isEmpty, reason: 'nothing changed');
      api.recordJson = {...api.recordJson, 'state': 'approved', 'stateLabel': 'Approved'};
      await panel.reload();
      expect(changed, ['approved']);
      api.recordJson = {...api.recordJson, 'instances': [_run('r9', 'Pay', 'waiting')]};
      await panel.reload();
      expect(changed, ['approved', 'approved'], reason: 'a run started');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows a failed reload over the record it still shows, with Try again; and a failed history as such', (tester) async {
      final api = _FlakyApi();
      await pumpPanel(tester, UiWorkflowPanel(api: api, entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.compact));
      expect(find.text('Nothing yet.'), findsNothing);
      expect(find.text('The history could not be loaded.'), findsOneWidget);
      api.failRecord = true;
      await tester.state<UiWorkflowPanelState>(find.byType(UiWorkflowPanel)).reload();
      await tester.pumpAndSettle();
      expect(find.text('The engine is down. What is shown may be out of date.'), findsOneWidget);
      expect(button('Approve'), findsOneWidget, reason: 'the record stays');
      api.failRecord = false;
      await tester.tap(find.bySemanticsLabel('Try again'));
      await tester.pumpAndSettle();
      expect(find.textContaining('may be out of date'), findsNothing);
    });

    testWidgets('says "Stopped" over runs that all stopped, and looks again every 15 s while one is still going', (tester) async {
      final api = FakeWorkflowApi();
      api.recordJson = {...api.recordJson, 'instances': [_run('r1', 'Pay', 'incident', 'X: boom')]};
      await pumpPanel(tester, UiWorkflowPanel(api: api, entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.compact));
      expect(find.text('STOPPED'), findsOneWidget);
      final panel = tester.state<UiWorkflowPanelState>(find.byType(UiWorkflowPanel));
      expect(panel.polling, isFalse, reason: 'nothing is still going');
      api.recordJson = {...api.recordJson, 'instances': [_run('r1', 'Pay', 'incident', 'X: boom'), _run('r2', 'Remind', 'waiting')]};
      await panel.reload();
      await tester.pump();
      expect(find.text('RUNNING'), findsOneWidget);
      expect(panel.polling, isTrue);
      final reads = api.calls.where((c) => c.startsWith('record:')).length;
      await tester.pump(const Duration(seconds: 15));
      expect(api.calls.where((c) => c.startsWith('record:')).length, reads + 1);
      // In the background it waits.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(panel.polling, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(panel.polling, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(panel.polling, isFalse, reason: 'stopped when it goes away');
    });

    testWidgets('vertical: what happened before starting over is grouped apart, not under states not reached', (tester) async {
      final h = [
        entry('created', 'Draft'), entry('transitioned', 'Submitted', before: 'Draft'),
        entry('reset', 'Draft', before: 'Submitted'),
      ];
      await pumpPanel(tester, UiWorkflowPanel(api: _RecordApi(record('Draft'), h), entity: 'application', entityId: '1'));
      final label = find.bySemanticsLabel('Earlier, before starting over (2)');
      expect(label, findsOneWidget);
      expect(find.text('Started in Draft'), findsNothing, reason: 'folded away');
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(find.text('Started in Draft'), findsOneWidget);
    });

    testWidgets('reads 500 history entries and says when only the latest were read', (tester) async {
      final api = _ManyApi();
      await pumpPanel(tester, UiWorkflowPanel(api: api, entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.compact), size: const Size(480, 900));
      expect(api.took, 500);
      expect(find.text('Showing the latest 500 entries.'), findsOneWidget);
    });
  });
}

class _SwitchApi extends FakeWorkflowApi {
  final gates = <String, Completer<void>>{};
  @override
  Future<UiWfRecord> record(String entity, String id) async {
    await gates[id]?.future;
    return UiWfRecord.fromJson({...recordJson, 'id': id, 'stateLabel': 'State $id'});
  }
}

class _FlakyApi extends FakeWorkflowApi {
  bool failRecord = false;
  @override
  Future<UiWfRecord> record(String entity, String id) async {
    if (failRecord) throw const UiWfApiError(503, 'down', 'The engine is down.');
    return super.record(entity, id);
  }

  @override
  Future<List<UiWfAuditEntry>> recordHistory(String entity, String id, {int take = 200}) async => throw const UiWfApiError(500, 'boom', 'No history');
}

class _ManyApi extends FakeWorkflowApi {
  int? took;
  @override
  Future<List<UiWfAuditEntry>> recordHistory(String entity, String id, {int take = 200}) async {
    took = take;
    return [for (var i = take; i >= 1; i--) entry('decided', null, category: 'task')];
  }
}
