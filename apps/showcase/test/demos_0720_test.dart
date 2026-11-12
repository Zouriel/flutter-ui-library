import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/feedback/shutter_loader.dart' show UiShutterMark;
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/registry.dart';
import 'package:zouriel_ui_showcase/pages/shutter_page.dart';

/// 0.72.0 showcase demos: the shutter loader page, its spinner and overscroll switches, and pull to
/// refresh, with a phone's touch slop.

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  tester.view.gestureSettings = ui.GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.takeException(), isNull);
}

Future<void> _show(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  test('the page is in the menu', () {
    expect(showcasePageById('shutter-loader')?.label, 'Shutter loader');
  });

  testWidgets('pull to refresh demo: a pull adds a row after the ball has clicked', (tester) async {
    await _pump(tester, const UiApp(home: ShutterPage()));
    final list = find.byKey(const ValueKey('refresh-list'));
    await _show(tester, list);
    expect(find.text('New photo 1'), findsNothing);
    final g = await tester.startGesture(tester.getRect(list).topCenter + const Offset(0, 40));
    for (var i = 0; i < 20; i++) {
      await g.moveBy(const Offset(0, 8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.descendant(of: find.byType(UiPullToRefresh), matching: find.byType(UiShutterLoader)), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('New photo 1'), findsOneWidget);
    expect(find.descendant(of: find.byType(UiPullToRefresh), matching: find.byType(UiShutterLoader)), findsNothing);
  });

  testWidgets('the spinner switch turns every UiSpinner into the shutter', (tester) async {
    await _pump(tester, const UiApp(home: ShutterPage()));
    await _show(tester, find.text('Uploading'));
    final inSwitchDemo = find.ancestor(of: find.text('Uploading'), matching: find.byType(UiButton));
    expect(find.descendant(of: inSwitchDemo, matching: find.byType(UiShutterLoader)), findsNothing);
    await _show(tester, find.text('Shutter').first);
    await tester.tap(find.text('Shutter').first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.descendant(of: inSwitchDemo, matching: find.byType(UiShutterLoader)), findsOneWidget);
  });

  testWidgets('the overscroll switch puts the shutter ball on the demo list (and the app)', (tester) async {
    final controller = UiThemeController();
    addTearDown(controller.dispose);
    await _pump(tester, UiApp(controller: controller, home: const ShutterPage()));
    final list = find.byKey(const ValueKey('overscroll-list'));
    final ball = find.descendant(of: list, matching: find.byType(UiShutterMark));
    Future<void> pull(bool expectBall) async {
      final g = await tester.startGesture(tester.getRect(list).topCenter + const Offset(0, 40));
      for (var i = 0; i < 12; i++) {
        await g.moveBy(const Offset(0, 8));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(ball, expectBall ? findsOneWidget : findsNothing);
      await g.up();
      // The page's own loaders loop, so it never settles: wait out the spring back.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(ball, findsNothing);
    }

    await _show(tester, list);
    await pull(false);
    await _show(tester, find.text('Shutter').last);
    await tester.tap(find.text('Shutter').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.config.overscroll, UiOverscrollStyle.shutter);
    await _show(tester, list);
    await pull(true);
  });
}
