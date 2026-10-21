import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/map_page.dart';

void main() {
  testWidgets('map page demo: searching shows the pulse and says so; RTL moves the zoom buttons; the map centres between card and sheet', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(theme: UiThemeName.maldives, home: MapPageDemo(tileProvider: UiMapBlankTiles())));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(UiMapPulseRings), findsNothing);
    final map = tester.widget<UiMap>(find.byType(UiMap));
    expect(map.viewInsets.top, greaterThan(60));
    expect(map.viewInsets.bottom, greaterThan(200));
    await tester.ensureVisible(find.text('Find a nurse').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Find a nurse').last);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(UiMapPulseRings), findsOneWidget);
    expect(find.text('Looking for a nurse near you'), findsOneWidget);
    final ltr = tester.getCenter(find.bySemanticsLabel('Zoom in')).dx;
    expect(ltr, lessThan(195));
    await tester.ensureVisible(find.text('RTL'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('RTL'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.getCenter(find.bySemanticsLabel('Zoom in')).dx, greaterThan(195));
    await tester.ensureVisible(find.text('Stop searching'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Stop searching'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(UiMapPulseRings), findsNothing);
  });

  testWidgets('map page demo: the my-location button floats just above the sheet and shows the you-are-here dot', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(theme: UiThemeName.maldives, home: MapPageDemo(tileProvider: UiMapBlankTiles())));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final map = tester.widget<UiMap>(find.byType(UiMap));
    final button = tester.getRect(find.byType(UiMapLocateButton));
    // Just above the sheet's top edge, at the end.
    expect(button.bottom, lessThanOrEqualTo(844 - map.viewInsets.bottom));
    expect(button.bottom, greaterThan(844 - map.viewInsets.bottom - 60));
    expect(button.right, greaterThan(390 - 60));
    expect(find.byType(UiMapUserDot), findsNothing);
    await tester.tap(find.byType(UiMapLocateButton));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.descendant(of: find.byType(UiMapLocateButton), matching: find.byType(UiSpinner)), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(UiMapUserDot), findsOneWidget);
  });
}
