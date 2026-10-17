import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
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

List<String> keys(({List<UiWfPanelStep> steps, int active}) p) => [for (final s in p.steps) s.key];

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
  });
}
