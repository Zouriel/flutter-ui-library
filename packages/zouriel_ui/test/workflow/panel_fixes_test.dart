import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fake_api.dart';

// Regression tests for the workflow panel's audit findings: another record drops the old one at
// once, the host opens and closes the drawer ([open] / [onOpenChanged]), and load errors carry
// the engine's details.

Finder button(String label) => find.byWidgetPredicate((w) => w is UiButton && w.label == label);

class _SlowRecordApi extends FakeWorkflowApi {
  Completer<void>? gate;
  @override
  Future<UiWfRecord> record(String entity, String id) async {
    final g = gate;
    if (g != null) await g.future;
    return super.record(entity, id);
  }
}

void main() {
  testWidgets('switching to another record drops the old one\'s buttons at once', (tester) async {
    final api = _SlowRecordApi();
    final id = ValueNotifier('1');
    await pumpUi(tester, ValueListenableBuilder<String>(valueListenable: id, builder: (_, v, _) => UiWorkflowPanel(api: api, entity: 'application', entityId: v)), size: const Size(700, 1200));
    expect(button('Approve'), findsOneWidget);
    api.gate = Completer<void>();
    id.value = '2';
    await tester.pump();
    expect(button('Approve'), findsNothing);
    expect(find.text('Loading…'), findsOneWidget);
    api.gate!.complete();
    await tester.pumpAndSettle();
    expect(api.calls.last, 'record:application/2');
    expect(button('Approve'), findsOneWidget);
  });

  testWidgets('a load error shows the engine\'s details', (tester) async {
    final api = FakeWorkflowApi()
      ..failNext = const UiWfApiError(422, 'invalid', 'The record could not be read.', [{'message': 'Its type is unknown.'}]);
    await pumpUi(tester, UiWorkflowPanel(api: api, entity: 'application', entityId: '1'), size: const Size(700, 900));
    expect(find.text('The record could not be read. Its type is unknown.'), findsOneWidget);
  });

  group('drawer open / onOpenChanged', () {
    Future<void> pumpHost(WidgetTester tester, ValueNotifier<bool> open, List<bool> told) => pumpUi(
          tester,
          SizedBox(
            width: 700,
            height: 700,
            child: ValueListenableBuilder<bool>(
              valueListenable: open,
              builder: (_, v, _) => UiWorkflowPanel(api: FakeWorkflowApi(), entity: 'application', entityId: '1', layout: UiWorkflowPanelLayout.sideDrawer, open: v, onOpenChanged: told.add),
            ),
          ),
          size: const Size(700, 700),
        );

    testWidgets('the host opens and closes the drawer', (tester) async {
      final open = ValueNotifier(false);
      final told = <bool>[];
      await pumpHost(tester, open, told);
      expect(find.byType(UiDrawer), findsNothing);
      open.value = true;
      await tester.pumpAndSettle();
      expect(find.byType(UiDrawer), findsOneWidget);
      expect(told, [true]);
      open.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(UiDrawer), findsNothing);
      expect(told, [true, false]);
    });

    testWidgets('opening with open: true from the start', (tester) async {
      final told = <bool>[];
      await pumpHost(tester, ValueNotifier(true), told);
      await tester.pumpAndSettle();
      expect(find.byType(UiDrawer), findsOneWidget);
      expect(told, [true]);
    });

    testWidgets('the host hears about the rail, a hover and closing', (tester) async {
      final told = <bool>[];
      await pumpHost(tester, ValueNotifier(false), told);
      await tester.tap(find.byType(UiStepper));
      await tester.pumpAndSettle();
      expect(told, [true]);
      await tester.tapAt(const Offset(5, 350)); // the backdrop
      await tester.pumpAndSettle();
      expect(told, [true, false]);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1, 1));
      await mouse.moveTo(tester.getCenter(find.byType(UiStepper)));
      await tester.pumpAndSettle();
      expect(told, [true, false, true]);
      await mouse.moveTo(const Offset(40, 450));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(told, [true, false, true, false]);
      await mouse.removePointer();
    });
  });
}
