import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/workflow/runtime.dart' show WfRunView, showWfDecideDialog;
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fake_api.dart';

// Goldens for the runtime widgets the audit found without one: the open tasks drawer, the run
// view's Skip and Cancel dialogs, the decide dialog, the panel's drawer rail and peek, a panel
// with no lifecycle and its error, the audit log, the state badge's tones, and the global settings
// on a phone. Dialogs and drawers live in the app's overlay, so those are taken per theme.

Finder button(String label) => find.byWidgetPredicate((w) => w is UiButton && w.label == label);

/// The fake engine plus one stopped workflow (for the drawer).
class _WithStopped extends FakeWorkflowApi {
  _WithStopped() {
    canIntervene = true;
  }
  @override
  Future<UiWfPage<UiWfInstance>> instances(UiWfInstanceQuery q) async => UiWfPage([
        UiWfInstance.fromJson({
          'id': 's1', 'title': 'Pay approved scholarships', 'entityTitle': 'Bursary – Ali', 'status': 'incident', 'kind': 'automation',
          'error': 'InvalidOperationException: Bank API: 503 Service Unavailable', 'startedAt': DateTime.now().toUtc().toIso8601String(),
          'steps': <Object?>[], 'tokens': <Object?>[],
        }),
      ], 1);
}

/// An engine that can't read the record (for the panel's error), every time.
class _Down extends FakeWorkflowApi {
  @override
  Future<UiWfRecord> record(String entity, String id) async => throw const UiWfApiError(500, 'boom', 'The engine is not answering.', [{'message': 'Try again in a minute.'}]);
}

/// The whole app (overlays included), once per theme.
Future<void> appGolden(WidgetTester tester, String name, Widget Function() home, Future<void> Function() act, {Size size = const Size(390, 844), DateTime? now}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  addTearDown(tester.view.reset);
  for (final th in [UiThemeName.dark, UiThemeName.light]) {
    debugDisableShadows = false;
    try {
      final app = UiApp(key: ValueKey(th), theme: th, home: home());
      await tester.pumpWidget(now == null ? app : UiWorkflowClock(now: () => now, child: app));
      await tester.pumpAndSettle();
      await act();
      await tester.pumpAndSettle();
      await expectLater(find.byType(UiApp), matchesGoldenFile('goldens/${name}_${th.name}.png'));
    } finally {
      debugDisableShadows = true;
    }
    // Close whatever is open before the next theme.
    await tester.pumpWidget(const SizedBox());
  }
}

Widget _page(Widget child) => Align(alignment: Alignment.topLeft, child: Padding(padding: const EdgeInsets.all(16), child: child));

void main() {
  testWidgets('golden: the tasks drawer open, with a stopped workflow above the tasks', (tester) async {
    final key = GlobalKey<UiWorkflowTasksDrawerState>();
    await appGolden(tester, 'workflow_tasks_drawer_open', () => _page(UiWorkflowTasksDrawer(key: key, api: _WithStopped(), refreshSeconds: 0)), () async {
      key.currentState!.show();
    });
  });

  testWidgets('golden: the run view\'s Skip dialog', (tester) async {
    await appGolden(
      tester,
      'workflow_run_skip_dialog',
      () => _page(SizedBox(width: 358, child: WfRunView(api: FakeWorkflowApi()..canIntervene = true, instanceId: 'i1'))),
      () async {
        await tester.tap(button('Skip').first);
      },
    );
  });

  testWidgets('golden: the run view\'s Cancel dialog', (tester) async {
    await appGolden(
      tester,
      'workflow_run_cancel_dialog',
      () => _page(SizedBox(width: 358, child: WfRunView(api: FakeWorkflowApi()..canIntervene = true, instanceId: 'i1'))),
      () async {
        await tester.tap(button('Cancel the run'));
      },
    );
  });

  testWidgets('golden: the decide dialog, with earlier decisions and the hand-over open', (tester) async {
    final task = UiWfTask.fromJson({
      ...FakeWorkflowApi.taskJson('t1'),
      // Fixed, with a fixed clock: the dialog shows the due date itself.
      'dueAt': '2026-10-20T09:00:00Z',
      'decisions': [
        {'userId': 'ali', 'name': 'Ali Rasheed', 'outcome': 'approved', 'comment': 'Budget line checked.'},
      ],
    });
    await appGolden(
      tester,
      'workflow_decide_dialog',
      () => _page(Builder(builder: (ctx) => UiButton(label: 'Open', onPressed: () => showWfDecideDialog(ctx, task: task, api: FakeWorkflowApi())))),
      () async {
        await tester.tap(button('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Hand it to someone else'));
      },
      now: DateTime.utc(2026, 10, 18, 9),
    );
  });

  testWidgets('golden: the panel\'s side-drawer rail', (tester) async {
    await appGolden(tester, 'workflow_panel_rail', () => UiWorkflowPanel(api: FakeWorkflowApi(), entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.sideDrawer), () async {});
  });

  testWidgets('golden: the panel peeking under the mouse', (tester) async {
    await appGolden(
      tester,
      'workflow_panel_peek',
      () => UiWorkflowPanel(api: FakeWorkflowApi(), entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.sideDrawer),
      () async {
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(1, 1));
        await mouse.moveTo(tester.getCenter(find.byType(UiStepper)));
        await tester.pumpAndSettle();
        await mouse.removePointer();
      },
      size: const Size(700, 844),
    );
  });

  testWidgets('golden: a panel with no lifecycle, and one that could not load', (tester) async {
    final none = FakeWorkflowApi();
    none.recordJson = {...none.recordJson, 'state': null, 'stateLabel': null, 'lifecycle': null, 'states': <Object?>[], 'transitions': <Object?>[]};
    final failing = _Down();
    await expectThemedGolden(
      tester,
      'workflow_panel_no_lifecycle_and_error',
      (context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 24, children: [
        UiWorkflowPanel(api: none, entity: 'application', entityId: '1'),
        UiWorkflowPanel(api: failing, entity: 'application', entityId: '1'),
      ]),
      height: 480,
    );
  });

  testWidgets('golden: the audit log with an entry open', (tester) async {
    final api = FakeWorkflowApi()..auditList = FakeWorkflowApi().auditList.take(6).toList();
    await expectThemedGolden(tester, 'workflow_audit', (context) => UiWorkflowAudit(api: api, onExport: (_, _) {}), width: 640, height: 820);
    // The newest entry opened, in both themes.
    for (final e in find.bySemanticsLabel(RegExp(r'^Entry 60:')).evaluate().toList()) {
      await tester.tap(find.byElementPredicate((x) => x == e));
    }
    await tester.pump(const Duration(milliseconds: 400));
    debugDisableShadows = false;
    try {
      await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/workflow_audit_open.png'));
    } finally {
      debugDisableShadows = true;
    }
  });

  testWidgets('golden: the state badge in every tone', (tester) async {
    await expectThemedGolden(
      tester,
      'workflow_state_badges',
      (context) => const Wrap(spacing: 8, runSpacing: 8, children: [
        UiWorkflowStateBadge(label: 'Draft', tone: 'neutral'),
        UiWorkflowStateBadge(label: 'Submitted', tone: 'info'),
        UiWorkflowStateBadge(label: 'In progress', tone: 'primary'),
        UiWorkflowStateBadge(label: 'Under review', tone: 'warning'),
        UiWorkflowStateBadge(label: 'Approved', tone: 'success'),
        UiWorkflowStateBadge(label: 'Rejected', tone: 'danger'),
      ]),
      height: 110,
    );
  });

  testWidgets('golden: the global settings on a phone', (tester) async {
    final settings = UiWorkflowSettings.fromJson({'version': 1, 'calendar': {'holidays': ['2026-12-25', '2027-01-01']}});
    await expectThemedGolden(
      tester,
      'workflow_global_settings_phone',
      (_) => SizedBox(height: 900, child: UiWorkflowGlobalSettings(settings: settings, registry: FakeWorkflowApi().registry)),
      width: 360,
      height: 940,
    );
  });
}
