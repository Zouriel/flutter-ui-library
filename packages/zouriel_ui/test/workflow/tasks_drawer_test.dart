import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/workflow/runtime.dart' show WfRunView, WfTaskInbox;
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fake_api.dart';

// Port of the web `tasks-drawer.spec.ts`.

class _TasksApi extends Fake implements UiWorkflowApi {
  _TasksApi(this.open, {this.total});
  List<UiWfTask> open;

  /// The count the engine reports, when more exist than it returned.
  int? total;
  final queries = <UiWfTaskQuery>[];
  Object? failNext;

  /// When set, answers wait for it (to race two refreshes).
  Completer<void>? gate;

  @override
  Future<UiWfPage<UiWfTask>> tasks(UiWfTaskQuery q) async {
    queries.add(q);
    final e = failNext;
    failNext = null;
    final g = gate;
    // Like the engine: at most `take` items, with the full count.
    final snapshot = open.take(q.take ?? open.length).toList();
    final n = total ?? snapshot.length;
    if (g != null) await g.future;
    if (e != null) throw e;
    return UiWfPage(snapshot, n);
  }
}

Finder button(String label) => find.byWidgetPredicate((w) => w is UiButton && w.label == label);

/// The tasks API plus a stopped workflow, for someone the engine may or may not let intervene.
class _StoppedApi extends _TasksApi {
  _StoppedApi({required this.intervene}) : super([_task('a')]);
  final bool intervene;

  /// The stopped run was put right (it no longer shows as stopped).
  bool fixed = false;
  final asked = <UiWfInstanceQuery>[];
  int meCalls = 0;

  static final Map<String, Object?> stuck = {
    'id': 's1', 'title': 'Pay approved scholarships', 'entityTitle': 'Bursary – Ali', 'status': 'incident', 'kind': 'automation',
    'error': 'InvalidOperationException: Bank API: 503', 'startedAt': DateTime.now().toUtc().toIso8601String(), 'steps': <Object?>[], 'tokens': <Object?>[],
  };

  @override
  Future<UiWfMe> me() async {
    meCalls++;
    return UiWfMe.fromJson({'can': {'intervene': intervene}});
  }

  @override
  Future<UiWfPage<UiWfInstance>> instances(UiWfInstanceQuery q) async {
    asked.add(q);
    return fixed ? const UiWfPage(<UiWfInstance>[], 0) : UiWfPage([UiWfInstance.fromJson(stuck)], 1);
  }

  @override
  Future<UiWfInstance> instance(String id) async => UiWfInstance.fromJson(fixed ? {...stuck, 'status': 'running', 'error': null} : stuck);
  @override
  Future<UiWorkflowDefinition> instanceDefinition(String id) async => createWorkflow('automation', title: 'W', entity: 'application');
  @override
  Future<UiWfInstance> retry(String id, {String? target}) async {
    fixed = true;
    return UiWfInstance.fromJson({...stuck, 'status': 'running', 'error': null});
  }
}

UiWfTask _task(String id, {bool overdue = false}) => UiWfTask.fromJson(FakeWorkflowApi.taskJson(id, title: 'Task $id', overdue: overdue));

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(900, 700) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(home: Align(alignment: Alignment.topLeft, child: Padding(padding: const EdgeInsets.all(16), child: child))));
  await tester.pumpAndSettle();
}

UiBadge? _badge(WidgetTester tester) {
  final f = find.byType(UiBadge);
  return f.evaluate().isEmpty ? null : tester.widget<UiBadge>(f);
}

void main() {
  testWidgets('shows how many tasks are open, and tells screen readers', (tester) async {
    final api = _TasksApi([_task('a'), _task('b')]);
    await _pump(tester, UiWorkflowTasksDrawer(api: api, refreshSeconds: 0));
    expect(_badge(tester)!.label, '2');
    expect(_badge(tester)!.tone, UiStatus.primary);
    expect(find.bySemanticsLabel('My tasks, 2 open'), findsOneWidget);
    final q = api.queries.single;
    expect(q.scope, 'mine');
    expect(q.status, ['open']);
    expect(q.take, 100);
  });

  testWidgets('turns red when a task is overdue', (tester) async {
    await _pump(tester, UiWorkflowTasksDrawer(api: _TasksApi([_task('a', overdue: true), _task('b')]), refreshSeconds: 0));
    expect(_badge(tester)!.tone, UiStatus.danger);
    expect(find.bySemanticsLabel('My tasks, 2 open, 1 overdue'), findsOneWidget);
  });

  testWidgets('has no badge when nothing is open', (tester) async {
    await _pump(tester, UiWorkflowTasksDrawer(api: _TasksApi([]), refreshSeconds: 0));
    expect(find.byType(UiBadge), findsNothing);
    expect(find.bySemanticsLabel('My tasks, none open'), findsOneWidget);
  });

  testWidgets('above 99 the badge reads 99+, the label the real number', (tester) async {
    await _pump(tester, UiWorkflowTasksDrawer(api: _TasksApi([_task('a')], total: 140), refreshSeconds: 0, label: 'Approvals'));
    expect(_badge(tester)!.label, '99+');
    expect(find.bySemanticsLabel('Approvals, 140 open'), findsOneWidget);
  });

  testWidgets('with scope "all" counts and lists everyone\'s tasks (an admin\'s drawer)', (tester) async {
    final api = _TasksApi([_task('a')]);
    await _pump(tester, UiWorkflowTasksDrawer(api: api, refreshSeconds: 0, scope: 'all', label: 'All tasks'));
    await tester.tap(find.byType(UiButton));
    await tester.pumpAndSettle();
    expect(api.queries.length, greaterThan(1));
    expect({for (final q in api.queries) q.scope}, {'all'});
    expect(find.descendant(of: find.byType(UiDrawer), matching: find.text('All tasks')), findsOneWidget);
  });

  testWidgets('opens from its button, counts again on open and close, and reports both', (tester) async {
    final api = _TasksApi([_task('a')]);
    final changes = <bool>[];
    await _pump(tester, UiWorkflowTasksDrawer(api: api, refreshSeconds: 0, onOpenChanged: changes.add));
    int counts() => api.queries.where((q) => q.take == 100).length;
    final before = counts();
    await tester.tap(find.byType(UiButton));
    await tester.pumpAndSettle();
    expect(find.byType(WfTaskInbox), findsOneWidget);
    expect(find.text('Task a'), findsOneWidget);
    expect(find.descendant(of: find.byType(UiDrawer), matching: find.text('My tasks')), findsOneWidget); // the drawer's title
    expect(counts(), before + 1);
    expect(changes, [true]);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(WfTaskInbox), findsNothing);
    expect(changes, [true, false]);
    expect(counts(), before + 2);
  });

  testWidgets('can be opened and closed from code without its button', (tester) async {
    final api = _TasksApi([_task('a')]);
    var open = false;
    late StateSetter set;
    await _pump(
      tester,
      StatefulBuilder(builder: (context, setState) {
        set = setState;
        return UiWorkflowTasksDrawer(api: api, refreshSeconds: 0, showButton: false, open: open, onOpenChanged: (v) => setState(() => open = v));
      }),
    );
    expect(find.byType(UiButton), findsNothing);
    set(() => open = true);
    await tester.pumpAndSettle();
    expect(find.byType(WfTaskInbox), findsOneWidget);
    set(() => open = false);
    await tester.pumpAndSettle();
    expect(find.byType(WfTaskInbox), findsNothing);
    expect(open, isFalse);
  });

  testWidgets('a GlobalKey can open it too', (tester) async {
    final key = GlobalKey<UiWorkflowTasksDrawerState>();
    await _pump(tester, UiWorkflowTasksDrawer(key: key, api: _TasksApi([_task('a')]), refreshSeconds: 0));
    key.currentState!.show();
    await tester.pumpAndSettle();
    expect(key.currentState!.isOpen, isTrue);
    expect(find.byType(WfTaskInbox), findsOneWidget);
    key.currentState!.hide();
    await tester.pumpAndSettle();
    expect(key.currentState!.isOpen, isFalse);
  });

  testWidgets('an error keeps the last count instead of flashing zero', (tester) async {
    final key = GlobalKey<UiWorkflowTasksDrawerState>();
    final api = _TasksApi([_task('a'), _task('b'), _task('c')]);
    await _pump(tester, UiWorkflowTasksDrawer(key: key, api: api, refreshSeconds: 0));
    expect(_badge(tester)!.label, '3');
    api.failNext = const UiWfApiError(503, 'down', 'Offline');
    await key.currentState!.refresh();
    await tester.pump();
    expect(_badge(tester)!.label, '3');
  });

  testWidgets('a slow, older answer does not overwrite a newer one', (tester) async {
    final key = GlobalKey<UiWorkflowTasksDrawerState>();
    final api = _TasksApi([_task('a')]);
    await _pump(tester, UiWorkflowTasksDrawer(key: key, api: api, refreshSeconds: 0));
    final slow = Completer<void>();
    api.gate = slow;
    api.open = [_task('a'), _task('b'), _task('c'), _task('d'), _task('e')];
    final first = key.currentState!.refresh(); // will answer 5, late
    api.gate = null;
    api.open = [_task('a'), _task('b')];
    await key.currentState!.refresh(); // answers 2 now
    await tester.pump();
    expect(_badge(tester)!.label, '2');
    slow.complete();
    await first;
    await tester.pump();
    expect(_badge(tester)!.label, '2');
  });

  testWidgets('refreshes on its timer, and stops when refreshSeconds is 0', (tester) async {
    final api = _TasksApi([_task('a')]);
    await _pump(tester, UiWorkflowTasksDrawer(api: api, refreshSeconds: 30));
    final start = api.queries.length;
    api.open = [_task('a'), _task('b')];
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(api.queries.length, start + 1);
    expect(_badge(tester)!.label, '2');
    await _pump(tester, UiWorkflowTasksDrawer(api: api, refreshSeconds: 0));
    final now = api.queries.length;
    await tester.pump(const Duration(minutes: 2));
    expect(api.queries.length, now);
  });

  testWidgets('golden: the button with none, some, overdue and 99+ open', (tester) async {
    final apis = [_TasksApi([]), _TasksApi([_task('a'), _task('b'), _task('c')]), _TasksApi([_task('a', overdue: true)]), _TasksApi([_task('a')], total: 120)];
    await expectThemedGolden(
      tester,
      'workflow_tasks_drawer',
      (_) => Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [
        UiWorkflowTasksDrawer(api: apis[0], refreshSeconds: 0),
        UiWorkflowTasksDrawer(api: apis[1], refreshSeconds: 0),
        UiWorkflowTasksDrawer(api: apis[2], refreshSeconds: 0, variant: UiButtonVariant.ghost),
        UiWorkflowTasksDrawer(api: apis[3], refreshSeconds: 0, size: UiSize.md, label: 'Approvals'),
      ]),
      height: 300,
    );
  });

  testWidgets('meets the tap target and label guidelines', (tester) async {
    final h = tester.ensureSemantics();
    await _pump(tester, UiWorkflowTasksDrawer(api: _TasksApi([_task('a')]), refreshSeconds: 0));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    h.dispose();
  });

  testWidgets('says "100+" overdue when more tasks are open than one count looks at', (tester) async {
    final many = [for (var i = 0; i < 120; i++) _task('t$i', overdue: true)];
    await _pump(tester, UiWorkflowTasksDrawer(api: _TasksApi(many, total: 250), refreshSeconds: 0));
    expect(find.bySemanticsLabel('My tasks, 250 open, 100+ overdue'), findsOneWidget);
    expect(_badge(tester)!.label, '99+');
    expect(_badge(tester)!.tone, UiStatus.danger);
  });

  testWidgets('pauses polling while the app is in the background and counts again when it comes back', (tester) async {
    final key = GlobalKey<UiWorkflowTasksDrawerState>();
    final api = _TasksApi([_task('a')]);
    await _pump(tester, UiWorkflowTasksDrawer(key: key, api: api, refreshSeconds: 30));
    expect(key.currentState!.polling, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(key.currentState!.polling, isFalse);
    final before = api.queries.length;
    await tester.pump(const Duration(minutes: 3));
    expect(api.queries.length, before, reason: 'no polling in the background');
    api.open = [_task('a'), _task('b')];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(api.queries.length, before + 1, reason: 'back in view: counted at once');
    expect(_badge(tester)!.label, '2');
    expect(key.currentState!.polling, isTrue);
    await tester.pump(const Duration(seconds: 30));
    expect(api.queries.length, before + 2);
  });

  testWidgets('hide() closes the drawer and what was opened over it, never what is under it', (tester) async {
    final key = GlobalKey<UiWorkflowTasksDrawerState>();
    final api = _TasksApi([_task('a')]);
    await _pump(tester, UiWorkflowTasksDrawer(key: key, api: api, refreshSeconds: 0));
    key.currentState!.show();
    await tester.pumpAndSettle();
    // Something else opens over the drawer (a decision, a confirmation).
    final nav = Navigator.of(tester.element(find.byType(WfTaskInbox)));
    nav.push(PageRouteBuilder<void>(opaque: false, pageBuilder: (context, a, b) => const Center(child: Text('On top'))));
    await tester.pumpAndSettle();
    key.currentState!.hide();
    await tester.pumpAndSettle();
    expect(find.byType(WfTaskInbox), findsNothing);
    expect(find.text('On top'), findsNothing, reason: 'nothing is left floating over the page');
    expect(find.byType(UiWorkflowTasksDrawer), findsOneWidget, reason: 'the page under the drawer stays');
    expect(key.currentState!.isOpen, isFalse);
  });

  testWidgets('hide() with a decision open closes the dialog too', (tester) async {
    final key = GlobalKey<UiWorkflowTasksDrawerState>();
    final api = _TasksApi([_task('a')]);
    await _pump(tester, UiWorkflowTasksDrawer(key: key, api: api, refreshSeconds: 0));
    key.currentState!.show();
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^Task a,')));
    await tester.pumpAndSettle();
    expect(find.byType(UiModal), findsOneWidget);
    key.currentState!.hide();
    await tester.pumpAndSettle();
    expect(find.byType(UiModal), findsNothing);
    expect(find.byType(WfTaskInbox), findsNothing);
  });

  testWidgets('the open drawer follows the host: another scope or api reaches its list', (tester) async {
    final key = GlobalKey<UiWorkflowTasksDrawerState>();
    final a = _TasksApi([_task('a')]);
    final b = _TasksApi([_task('b')]);
    final host = ValueNotifier<(UiWorkflowApi, String)>((a, 'mine'));
    await _pump(tester, ValueListenableBuilder(valueListenable: host, builder: (_, v, _) => UiWorkflowTasksDrawer(key: key, api: v.$1, scope: v.$2, refreshSeconds: 0)));
    key.currentState!.show();
    await tester.pumpAndSettle();
    expect(find.text('Task a'), findsOneWidget);
    host.value = (b, 'all');
    await tester.pumpAndSettle();
    expect(find.text('Task b'), findsOneWidget);
    expect(find.text('Task a'), findsNothing);
    expect(b.queries.last.scope, 'all');
  });

  testWidgets('a decision reaches the host\'s onDecided as it is now, not as it was when the drawer opened', (tester) async {
    final key = GlobalKey<UiWorkflowTasksDrawerState>();
    final api = FakeWorkflowApi();
    final got = <String>[];
    final host = ValueNotifier('first');
    await _pump(tester, ValueListenableBuilder(valueListenable: host, builder: (_, v, _) => UiWorkflowTasksDrawer(key: key, api: api, refreshSeconds: 0, onDecided: (_) => got.add(v))));
    key.currentState!.show();
    await tester.pumpAndSettle();
    host.value = 'second';
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^Task 1,')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(UiModal), matching: button('Approve')));
    await tester.pumpAndSettle();
    expect(got, ['second']);
  });

  testWidgets('the drawer goes away with its button', (tester) async {
    final key = GlobalKey<UiWorkflowTasksDrawerState>();
    final api = _TasksApi([_task('a')]);
    final show = ValueNotifier(true);
    await _pump(tester, ValueListenableBuilder(valueListenable: show, builder: (_, v, _) => v ? UiWorkflowTasksDrawer(key: key, api: api, refreshSeconds: 0) : const SizedBox()));
    key.currentState!.show();
    await tester.pumpAndSettle();
    show.value = false;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(WfTaskInbox), findsNothing);
  });

  group('stopped workflows', () {
    testWidgets('for people who may intervene: counted in the badge (red) and listed above the tasks, each opening its run', (tester) async {
      final api = _StoppedApi(intervene: true);
      await _pump(tester, UiWorkflowTasksDrawer(api: api, refreshSeconds: 0));
      expect(api.asked.single.status, ['incident']);
      expect(api.asked.single.take, 100);
      expect(_badge(tester)!.label, '2');
      // Red: a stopped workflow needs attention even when no task is overdue.
      expect(_badge(tester)!.tone, UiStatus.danger);
      expect(find.bySemanticsLabel('My tasks, 1 open, 1 stopped workflow'), findsOneWidget);
      await tester.tap(find.byType(UiButton));
      await tester.pumpAndSettle();
      expect(find.text('STOPPED WORKFLOWS'), findsOneWidget);
      expect(find.text('Pay approved scholarships · Bursary – Ali'), findsOneWidget);
      expect(find.text('Bank API: 503'), findsOneWidget);
      // Above the tasks.
      expect(tester.getTopLeft(find.text('STOPPED WORKFLOWS')).dy, lessThan(tester.getTopLeft(find.byType(WfTaskInbox)).dy));
      // The drawer asked once (opening it counted again without asking again).
      expect(api.meCalls, 1);
      await tester.tap(find.text('Pay approved scholarships · Bursary – Ali'));
      await tester.pumpAndSettle();
      expect(find.byType(WfRunView), findsOneWidget);
      expect(find.byType(WfTaskInbox), findsNothing);
      // Put right in place: counted again, and back in the list it is gone.
      await tester.tap(button('Try again'));
      await tester.pumpAndSettle();
      expect(api.fixed, isTrue);
      await tester.tap(button('‹ Back to the list'));
      await tester.pumpAndSettle();
      expect(find.text('STOPPED WORKFLOWS'), findsNothing);
      expect(find.byType(WfTaskInbox), findsOneWidget);
    });

    testWidgets('not for people who may not: nothing asked, nothing counted', (tester) async {
      final api = _StoppedApi(intervene: false);
      await _pump(tester, UiWorkflowTasksDrawer(api: api, refreshSeconds: 0));
      expect(api.asked, isEmpty);
      expect(_badge(tester)!.label, '1');
      expect(_badge(tester)!.tone, UiStatus.primary);
      expect(find.bySemanticsLabel('My tasks, 1 open'), findsOneWidget);
    });

    testWidgets('several stopped workflows read in the plural', (tester) async {
      final key = GlobalKey<UiWorkflowTasksDrawerState>();
      await _pump(tester, UiWorkflowTasksDrawer(key: key, api: _StoppedApi(intervene: true), refreshSeconds: 0));
      expect(key.currentState!.countText, ', 1 open, 1 stopped workflow');
      expect(key.currentState!.total, 2);
    });
  });

  // Mirrors @zouriel/ui bae06c5.
  testWidgets('a failed me() is asked again on the next count', (tester) async {
    final api = _FlakyMe();
    final key = GlobalKey<UiWorkflowTasksDrawerState>();
    await _pump(tester, UiWorkflowTasksDrawer(key: key, api: api, refreshSeconds: 0));
    expect(api.meCalls, 1);
    expect(key.currentState!.stopped, isEmpty);
    await key.currentState!.refresh();
    await tester.pump();
    expect(api.meCalls, 2);
    expect(key.currentState!.stopped, hasLength(1));
    await key.currentState!.refresh();
    expect(api.meCalls, 2, reason: 'a good answer is kept');
  });

  testWidgets('counts again when the scope changes', (tester) async {
    final api = _TasksApi([_task('a')]);
    final scope = ValueNotifier('mine');
    await _pump(tester, ValueListenableBuilder(valueListenable: scope, builder: (_, v, _) => UiWorkflowTasksDrawer(api: api, scope: v, refreshSeconds: 0)));
    scope.value = 'all';
    await tester.pumpAndSettle();
    expect(api.queries.last.scope, 'all');
  });

  testWidgets('closing goes back to the list: the next opening starts there, not on a run', (tester) async {
    final key = GlobalKey<UiWorkflowTasksDrawerState>();
    await _pump(tester, UiWorkflowTasksDrawer(key: key, api: _StoppedApi(intervene: true), refreshSeconds: 0));
    key.currentState!.show();
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^Pay approved scholarships')));
    await tester.pumpAndSettle();
    expect(find.byType(WfRunView), findsOneWidget);
    key.currentState!.hide();
    await tester.pumpAndSettle();
    key.currentState!.show();
    await tester.pumpAndSettle();
    expect(find.byType(WfRunView), findsNothing);
    expect(find.byType(WfTaskInbox), findsOneWidget);
  });
}

class _FlakyMe extends _StoppedApi {
  _FlakyMe() : super(intervene: true);
  @override
  Future<UiWfMe> me() async {
    meCalls++;
    if (meCalls == 1) throw const UiWfApiError(503, 'down', 'Down');
    return UiWfMe.fromJson({'can': {'intervene': true}});
  }
}
