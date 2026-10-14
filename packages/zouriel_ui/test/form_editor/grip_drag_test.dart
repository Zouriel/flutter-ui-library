import 'dart:ui' show GestureSettings, PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import 'support.dart';

UiFormDefinition three() => formOf([fj('a', 'text', {'label': 'First'}), fj('b', 'text', {'label': 'Second'}), fj('c', 'text', {'label': 'Third'})]);

Future<ValueNotifier<UiFormDefinition>> pumpFull(WidgetTester tester, {required bool insidePage}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  // A real Android phone reports its touch slop (about 8dp); scroll views use it, and so must the
  // grip, or the list claims every drag first. Tests default to 18 for everything, hiding that.
  tester.view.gestureSettings = GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
  final def = ValueNotifier(three());
  Widget builder() => ValueListenableBuilder(
        valueListenable: def,
        builder: (context, d, _) => UiFormBuilder(definition: d, onChanged: (n) => def.value = n),
      );
  await tester.pumpWidget(UiApp(
    home: insidePage
        ? ListView(children: [const SizedBox(height: 120), SizedBox(height: 720, child: builder()), const SizedBox(height: 600)])
        : builder(),
  ));
  await tester.pumpAndSettle();
  return def;
}

Future<void> fingerDrag(WidgetTester tester, Finder grip, double dy) async {
  final start = tester.getCenter(grip);
  final g = await tester.startGesture(start, kind: PointerDeviceKind.touch);
  await tester.pump(const Duration(milliseconds: 30));
  for (var i = 1; i <= 20; i++) {
    await g.moveTo(start + Offset(0, dy * i / 20));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await tester.pumpAndSettle();
}

List<String> order(ValueNotifier<UiFormDefinition> d) => [for (final e in d.value.pages[0].elements) e.id];

void main() {
  for (final insidePage in [false, true]) {
    testWidgets('a finger on the grip moves a field down (${insidePage ? 'inside a scrolling page' : 'full screen'})', (tester) async {
      final h = tester.ensureSemantics();
      final def = await pumpFull(tester, insidePage: insidePage);
      final grip = find.bySemanticsLabel('Drag First to move it');
      // Onto the lower half of the next card, still at the grip's x, as a thumb would (grips sit at
      // the top of their cards, so 70% of the way to the third grip is low on the second card).
      final second = tester.getRect(find.bySemanticsLabel('Drag Second to move it')).top;
      final third = tester.getRect(find.bySemanticsLabel('Drag Third to move it')).top;
      await fingerDrag(tester, grip, second + (third - second) * 0.7 - tester.getCenter(grip).dy);
      expect(order(def), ['b', 'a', 'c']);
      h.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
