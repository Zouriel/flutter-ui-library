import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/workflow/dnd.dart';
import 'package:zouriel_ui/src/workflow/lifecycle.dart';
import 'package:zouriel_ui/src/workflow/scope.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

UiWorkflowDefinition sample() => UiWorkflowDefinition.fromJson({
  'specVersion': 1, 'id': 'wf_life', 'key': 'life', 'kind': 'lifecycle', 'title': 'Application', 'entity': 'application',
  'lifecycle': {
    'field': 'status', 'mode': 'enforce',
    'states': [
      {'id': 'draft', 'key': 'Draft', 'label': 'Draft', 'category': 'initial', 'tone': 'neutral'},
      {'id': 'review', 'key': 'Review', 'label': 'Review', 'category': 'active', 'tone': 'info', 'sla': {'within': 'P2D', 'steps': <Object?>[]}},
      {'id': 'done', 'key': 'Done', 'label': 'Done', 'category': 'terminal', 'tone': 'success'},
    ],
    'transitions': [
      {'id': 'submit', 'key': 'submit', 'label': 'Submit', 'from': ['draft'], 'to': 'review', 'who': <Object?>[]},
      {'id': 'approve', 'key': 'approve', 'label': 'Approve', 'from': ['review'], 'to': 'done', 'who': <Object?>[], 'auto': {'after': 'P7D'}},
      {'id': 'back', 'key': 'back', 'label': 'Send back', 'from': ['review'], 'to': 'draft', 'who': <Object?>[]},
      {'id': 'cancel', 'key': 'cancel', 'label': 'Cancel', 'from': '*', 'to': 'done', 'who': <Object?>[]},
    ],
  },
});

Future<(UiWorkflowBuilderController, WfBuilderUi)> pumpLifecycle(WidgetTester tester, {Widget? child, Size size = const Size(900, 640)}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  tester.view.gestureSettings = ui.GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
  addTearDown(tester.view.reset);
  final c = UiWorkflowBuilderController(definition: sample());
  final dnd = WfDnd(c);
  final wfUi = WfBuilderUi();
  addTearDown(() {
    dnd.dispose();
    c.dispose();
    wfUi.dispose();
  });
  await tester.pumpWidget(UiApp(home: WfBuilderScope(controller: c, ui: wfUi, dnd: dnd, child: child ?? const WfLifecycleCanvas())));
  await tester.pumpAndSettle();
  return (c, wfUi);
}

Finder state(String semantic) => find.bySemanticsLabel(semantic);

List<String> moves(UiWorkflowBuilderController c) => [for (final t in c.def.lifecycle!.transitions) '${t.fromAny ? '*' : t.from.join(',')}>${t.to}'];

void main() {
  testWidgets('dragging a state moves it and stores a snapped position', (tester) async {
    final (c, _) = await pumpLifecycle(tester);
    final g = await tester.startGesture(tester.getCenter(state('Review')));
    for (var i = 1; i <= 8; i++) {
      await g.moveBy(const Offset(0, 10));
      await tester.pump();
    }
    await g.up();
    await tester.pump();
    final p = c.def.lifecycle!.layout!['review']!;
    expect(p[0], 272); // snapped to the 8px grid, like the web
    expect(p[1] % 8, 0);
    expect(p[1], greaterThan(0));
    expect(c.canUndo, isTrue);
  });

  testWidgets('a short press selects a state', (tester) async {
    final (c, _) = await pumpLifecycle(tester);
    await tester.tap(state('Review'));
    await tester.pump();
    expect(c.selection, const UiWfSelection.state('review'));
    expect(c.def.lifecycle!.layout, isNull);
  });

  testWidgets('dragging from the handle with a mouse onto another state adds a transition', (tester) async {
    final (c, _) = await pumpLifecycle(tester);
    final from = tester.getCenter(state('Add a transition from Draft'));
    final to = tester.getCenter(state('Done, final state'));
    final g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    for (var i = 1; i <= 8; i++) {
      await g.moveTo(Offset.lerp(from, to, i / 8)!);
      await tester.pump();
    }
    await g.up();
    await tester.pump();
    expect(moves(c).last, 'draft>done');
    expect(c.selectedTransition?.label, 'To Done');
  });

  testWidgets('touch: tap the handle, then the target', (tester) async {
    final (c, _) = await pumpLifecycle(tester);
    await tester.tap(state('Add a transition from Draft'));
    await tester.pump();
    expect(find.text('Now tap the state it goes to'), findsOneWidget);
    await tester.tap(state('Done, final state'));
    await tester.pump();
    expect(moves(c).last, 'draft>done');
    expect(find.text('Now tap the state it goes to'), findsNothing);
  });

  testWidgets('Tidy up forgets manual positions', (tester) async {
    final (c, _) = await pumpLifecycle(tester);
    c.placeState('done', 40, 400);
    await tester.pump();
    await tester.tap(find.text('Tidy up'));
    await tester.pumpAndSettle();
    expect(c.def.lifecycle!.layout, isNull);
  });

  testWidgets('edge labels and "from any state" chips select transitions', (tester) async {
    final (c, _) = await pumpLifecycle(tester);
    await tester.tap(find.bySemanticsLabel('Transition Submit'));
    await tester.pump();
    expect(c.selection, const UiWfSelection.transition('submit'));
    expect(find.textContaining('Cancel'), findsWidgets);
    await tester.tap(find.bySemanticsLabel(RegExp('^Cancel .* Done')));
    await tester.pump();
    expect(c.selection, const UiWfSelection.transition('cancel'));
  });

  testWidgets('the list view lists moves and adds a transition', (tester) async {
    final (c, _) = await pumpLifecycle(tester);
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    expect(find.text('Send back'), findsOneWidget);
    await tester.tap(find.text('Add a transition').first);
    await tester.pump();
    expect(moves(c).last, 'draft>review');
    expect(c.selection?.kind, 'transition');
  });

  testWidgets('adding a state places it to the right and selects it', (tester) async {
    final (c, _) = await pumpLifecycle(tester);
    await tester.tap(find.text('State'));
    await tester.pumpAndSettle();
    final added = c.def.lifecycle!.states.last;
    expect(added.label, 'New state');
    expect(c.selection, UiWfSelection.state(added.id));
    expect(c.def.lifecycle!.layout![added.id]![0], greaterThan(500));
  });

  testWidgets('the steps pane is idle until a state is selected, then lists its steps', (tester) async {
    final (c, wfUi) = await pumpLifecycle(tester, child: const WfLifecycleRuns());
    final added = <WfDropTarget>[];
    wfUi.onAddRequest = added.add;
    expect(WfLifecycleRuns.isIdle(c), isTrue);
    expect(find.text('Select a state or a transition to see the steps it runs.'), findsOneWidget);
    c.selection = const UiWfSelection.state('review');
    await tester.pumpAndSettle();
    expect(WfLifecycleRuns.isIdle(c), isFalse);
    expect(find.text('In “Review”'), findsOneWidget);
    expect(find.text('On leaving'), findsOneWidget);
    expect(find.text('When late'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Add a step here').first);
    expect(added, [const WfDropTarget('onEnter:review', 0)]);
    await tester.tap(find.text('When late'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Add a step here').first);
    expect(added.last, const WfDropTarget('sla:review', 0));
    // The starting state has no "On leaving".
    c.selection = const UiWfSelection.state('draft');
    await tester.pumpAndSettle();
    expect(find.text('On leaving'), findsNothing);
  });

  testWidgets('golden: lifecycle diagram', (tester) async {
    final c = UiWorkflowBuilderController(definition: sample())..selection = const UiWfSelection.transition('submit');
    addTearDown(c.dispose);
    await expectThemedGolden(
      tester,
      'workflow_lifecycle',
      (_) => WfBuilderScope(controller: c, child: const WfLifecycleCanvas()),
      width: 760,
      height: 440,
    );
  });
}
