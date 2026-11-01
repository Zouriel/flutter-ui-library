import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/behaviors_page.dart';

void main() {
  testWidgets('behaviors page: pinching the demo grid changes its column count', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const UiApp(home: BehaviorsPage()));
    await tester.pump(const Duration(milliseconds: 300));

    final pinch = find.byType(UiPinch);
    await tester.ensureVisible(pinch);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('3 columns. Pinch with two fingers.'), findsOneWidget);

    final c = tester.getCenter(pinch);
    final a = await tester.startGesture(c - const Offset(50, 0), pointer: 41);
    final b = await tester.startGesture(c + const Offset(50, 0), pointer: 42);
    await a.moveBy(const Offset(-20, 0));
    await b.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(find.text('2 columns. Pinch with two fingers.'), findsOneWidget);

    await a.moveBy(const Offset(30, 0)); // 110 of 140
    await tester.pump();
    expect(find.text('3 columns. Pinch with two fingers.'), findsOneWidget);
    await a.up();
    await b.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
