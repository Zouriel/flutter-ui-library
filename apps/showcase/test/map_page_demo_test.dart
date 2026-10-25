import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/map_page.dart';
import 'package:zouriel_ui_showcase/pages/nav_demo.dart';

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
  testWidgets('map page demo (0.42.1): the Show all control sits above the locate button and fits every nurse between card and sheet', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(theme: UiThemeName.maldives, home: MapPageDemo(tileProvider: UiMapBlankTiles())));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final control = tester.getRect(find.byType(UiMapControlButton));
    final locate = tester.getRect(find.byType(UiMapLocateButton));
    expect(control.bottom, lessThanOrEqualTo(locate.top + 0.01));
    expect(control.center.dx, closeTo(locate.center.dx, 0.01));
    final dots = find.descendant(of: find.byType(UiMap), matching: find.byWidgetPredicate((w) => w is Container && w.constraints == const BoxConstraints.tightFor(width: 16, height: 16)));
    // Look somewhere else first: no nurse in view.
    tester.state<UiMapState>(find.byType(UiMap)).flyTo(const UiLatLng(4.30, 73.60), zoom: 17);
    await tester.pump();
    expect(dots, findsNothing);
    await tester.tap(find.byType(UiMapControlButton));
    await tester.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5)).catchError((_) => 0);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final map = tester.widget<UiMap>(find.byType(UiMap));
    // The markers' dots (16px discs) are all between the status card and the sheet.
    expect(dots, findsNWidgets(map.markers.length));
    for (final e in dots.evaluate()) {
      final p = tester.getCenter(find.byWidget(e.widget));
      expect(p.dy, inInclusiveRange(map.viewInsets.top, 844 - map.viewInsets.bottom));
      expect(p.dx, inInclusiveRange(0, 390));
    }
  });

  testWidgets('results map (0.43.1): a pin selects it and an empty-map tap clears its card', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(theme: UiThemeName.maldives, home: MapResultsDemo(tileProvider: UiMapBlankTiles())));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    Finder dots(double size) => find.descendant(of: find.byType(UiMap), matching: find.byWidgetPredicate((w) => w is Container && w.constraints == BoxConstraints.tightFor(width: size, height: size)));
    expect(dots(16), findsNWidgets(3));
    expect(dots(uiMapSelectedDot), findsNothing);
    // markerLabels: selected, and nothing selected yet: no labels.
    expect(find.text('Busy'), findsNothing);
    expect(find.text('Tap a pin to see the nurse.'), findsOneWidget);
    final handle = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Ibrahim Rasheed, RN'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(dots(uiMapSelectedDot), findsOneWidget);
    expect(dots(16), findsNWidgets(2));
    // Its label on the map and its name in the card; the others' labels stay hidden.
    expect(find.text('Ibrahim Rasheed, RN'), findsNWidgets(2));
    expect(find.text('Busy'), findsNothing);
    await tester.tapAt(const Offset(40, 700));
    await tester.pump(const Duration(milliseconds: 400));
    expect(dots(uiMapSelectedDot), findsNothing);
    expect(dots(16), findsNWidgets(3));
    expect(find.text('Tap a pin to see the nurse.'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('nav demo (0.47.1): Mute and SOS under the banner, a toggle; the App bar pushes the banner down; off the road shows Rerouting', (tester) async {
    tester.view.physicalSize = const Size(420, 1000) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    final key = GlobalKey<NavDriveDemoState>();
    await tester.pumpWidget(UiApp(theme: UiThemeName.maldives, home: SingleChildScrollView(child: NavDriveDemo(key: key, tileProvider: UiMapBlankTiles()))));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final banner = tester.getRect(find.byKey(const ValueKey('ui-nav-banner')));
    final mute = tester.getRect(find.bySemanticsLabel('Mute'));
    final sos = tester.getRect(find.bySemanticsLabel('SOS'));
    expect(mute.top, greaterThan(banner.bottom));
    expect(sos.top, greaterThan(mute.bottom));
    await tester.tap(find.bySemanticsLabel('Mute'));
    await tester.pump();
    expect(find.bySemanticsLabel('Unmute'), findsOneWidget);
    await tester.tap(find.text('On').last);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const ValueKey('nav-demo-appbar')), findsOneWidget);
    expect(tester.getRect(find.byKey(const ValueKey('ui-nav-banner'))).top, closeTo(banner.top + 48, 0.5));
    expect(tester.getRect(find.byKey(const ValueKey('ui-nav-banner'))).top, greaterThanOrEqualTo(tester.getRect(find.byKey(const ValueKey('nav-demo-appbar'))).bottom));
    // Off the road for the off-route time: Rerouting.
    await tester.tap(find.text('Wander off'));
    for (var i = 0; i < 16 && find.text('offRoute, 80 m off').evaluate().isEmpty; i++) {
      key.currentState!.advance(1);
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump();
    expect(find.text('offRoute, 80 m off'), findsOneWidget);
    // One tracker for the drive: each maneuver announced once (the demo used to start a new one every frame).
    final log = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').where((d) => d.startsWith('announce (step)')).toList();
    expect(log.toSet().length, log.length);
    expect(find.byKey(const ValueKey('ui-nav-status')), findsOneWidget);
    expect(find.text('Rerouting…'), findsOneWidget);
    key.currentState!.stop();
  });

  testWidgets('nav demo (0.47.2): SOS needs a 2 s hold, a tap is the app\'s fallback; Long status wraps to two lines', (tester) async {
    tester.view.physicalSize = const Size(420, 1000) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    final key = GlobalKey<NavDriveDemoState>();
    await tester.pumpWidget(UiApp(theme: UiThemeName.maldives, home: SingleChildScrollView(child: NavDriveDemo(key: key, tileProvider: UiMapBlankTiles()))));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final sos = find.bySemanticsLabel('SOS');
    await tester.tap(sos);
    await tester.pump();
    expect(find.text('SOS tapped: the app opens its confirm sheet (onTap)'), findsOneWidget);
    expect(find.text('SOS held: sent'), findsNothing);
    final g = await tester.startGesture(tester.getCenter(sos));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('SOS held: sent'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1010));
    expect(find.text('SOS held: sent'), findsOneWidget);
    await g.up();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('SOS tapped: the app opens its confirm sheet (onTap)'), findsOneWidget);
    final banner = tester.getRect(find.byKey(const ValueKey('ui-nav-banner')));
    await tester.tap(find.text('On').at(find.text('On').evaluate().length - 2));
    await tester.pump();
    await tester.pump();
    final shown = tester.widget<Text>(find.byKey(const ValueKey('ui-nav-status-text'))).data!;
    expect(shown.endsWith('…'), isTrue, reason: shown);
    expect(tester.getRect(find.byKey(const ValueKey('ui-nav-status'))).height, greaterThan(40));
    expect(tester.getRect(find.byKey(const ValueKey('ui-nav-banner'))), banner);
    key.currentState!.stop();
  });
}
