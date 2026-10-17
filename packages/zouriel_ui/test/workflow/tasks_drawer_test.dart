import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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
    final snapshot = List.of(open);
    final n = total ?? snapshot.length;
    if (g != null) await g.future;
    if (e != null) throw e;
    return UiWfPage(snapshot, n);
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

  testWidgets('opens from its button, counts again on open and close, and reports both', (tester) async {
    final api = _TasksApi([_task('a')]);
    final changes = <bool>[];
    await _pump(tester, UiWorkflowTasksDrawer(api: api, refreshSeconds: 0, onOpenChanged: changes.add));
    int counts() => api.queries.where((q) => q.take == 100).length;
    final before = counts();
    await tester.tap(find.byType(UiButton));
    await tester.pumpAndSettle();
    expect(find.byType(UiWorkflowTasks), findsOneWidget);
    expect(find.text('Task a'), findsOneWidget);
    expect(find.descendant(of: find.byType(UiDrawer), matching: find.text('My tasks')), findsOneWidget); // the drawer's title
    expect(counts(), before + 1);
    expect(changes, [true]);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(UiWorkflowTasks), findsNothing);
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
    expect(find.byType(UiWorkflowTasks), findsOneWidget);
    set(() => open = false);
    await tester.pumpAndSettle();
    expect(find.byType(UiWorkflowTasks), findsNothing);
    expect(open, isFalse);
  });

  testWidgets('a GlobalKey can open it too', (tester) async {
    final key = GlobalKey<UiWorkflowTasksDrawerState>();
    await _pump(tester, UiWorkflowTasksDrawer(key: key, api: _TasksApi([_task('a')]), refreshSeconds: 0));
    key.currentState!.show();
    await tester.pumpAndSettle();
    expect(key.currentState!.isOpen, isTrue);
    expect(find.byType(UiWorkflowTasks), findsOneWidget);
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
}
