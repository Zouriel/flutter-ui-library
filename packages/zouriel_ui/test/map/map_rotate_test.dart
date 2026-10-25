import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// 0.47.0: the person turns the map with two fingers (past 15 degrees before the pinch zooms 10% or
/// pans 30 px), and the compass turns it back; the web's map-rotate.spec.ts.

class _Host {
  bool rotatable = true;
  bool compass = true;
  bool reduced = true;
  UiStrings strings = const UiStrings();
  int moves = 0;
  final bearings = <double>[];
  late StateSetter set;
  final key = GlobalKey<UiMapState>();
}

Future<_Host> _pump(WidgetTester tester, {void Function(_Host h)? init}) async {
  final h = _Host();
  init?.call(h);
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(StatefulBuilder(builder: (context, set) {
    h.set = set;
    return UiApp(
      theme: UiThemeName.maldives,
      config: UiConfig(strings: h.strings),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: h.reduced),
          child: UiMap(
            key: h.key,
            fill: true,
            center: const UiLatLng(4.1755, 73.5093),
            zoom: 15,
            tileProvider: UiMapBlankTiles(),
            markers: const [UiMapMarker(id: 'p', lat: 4.1762, lng: 73.5098, label: 'Lily Magu')],
            rotatable: h.rotatable,
            compass: h.compass,
            onUserMove: () => h.moves++,
            onBearingChanged: h.bearings.add,
          ),
        ),
      ),
    );
  }));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  return h;
}

/// Two fingers [r] px either side of the middle, turned from 0 to each of [angles] (degrees, clockwise),
/// their distance scaled by [scales] (1 if left out).
Future<void> _twist(WidgetTester tester, List<double> angles, {double r = 80, List<double>? scales}) async {
  const c = Offset(195, 422);
  Offset at(double deg, double rr, int side) => c + Offset(math.cos(deg * math.pi / 180), math.sin(deg * math.pi / 180)) * rr * side.toDouble();
  final a = await tester.startGesture(at(0, r, -1), pointer: 11);
  final b = await tester.startGesture(at(0, r, 1), pointer: 12);
  await tester.pump();
  for (var i = 0; i < angles.length; i++) {
    final rr = r * (scales?[i] ?? 1);
    await a.moveTo(at(angles[i], rr, -1));
    await b.moveTo(at(angles[i], rr, 1));
    await tester.pump();
  }
  await a.up();
  await b.up();
  await tester.pump();
}

void main() {
  test('the thresholds: the same as the web', () {
    expect([uiMapRotateThreshold, uiMapPinchZoomThreshold, uiMapPinchMoveThreshold], [15, 0.1, 30]);
    expect([uiMapIsTurned(0), uiMapIsTurned(0.4), uiMapIsTurned(359.8), uiMapIsTurned(10), uiMapIsTurned(-90)], [false, false, false, true, true]);
  });

  testWidgets('two fingers twisting turn the map with them, markers stay upright, and it says so', (tester) async {
    final h = await _pump(tester);
    expect(find.byKey(const ValueKey('ui-map-compass')), findsNothing);
    await _twist(tester, [5, 10, 20, 30, 40]);
    final b = h.key.currentState!.currentBearing;
    // Fingers turned 40 degrees clockwise: so did the map; north is now about 40 degrees clockwise.
    expect(b, inInclusiveRange(315, 330));
    expect(h.moves, greaterThanOrEqualTo(1));
    expect(h.bearings, hasLength(1));
    expect(h.bearings.single, closeTo(b, 1e-9));
    expect(find.byKey(const ValueKey('ui-map-compass')), findsOneWidget);
    // The label reads level on the turned map.
    final label = find.text('Lily Magu');
    expect(tester.getTopLeft(label).dy, closeTo(tester.getTopRight(label).dy, 0.01));
    // The needle points north: turned back by the bearing.
    final needle = tester.widget<Transform>(find.byKey(const ValueKey('ui-map-compass-needle')));
    expect(math.atan2(needle.transform.entry(1, 0), needle.transform.entry(0, 0)) * 180 / math.pi, closeTo(360 - b, 1e-6));
  });

  testWidgets('a small twist during a pinch does not turn the map (the zoom won)', (tester) async {
    final h = await _pump(tester);
    final zoom = h.key.currentState!.controller.camera.zoom;
    await _twist(tester, [4, 8, 20, 30], scales: [1.08, 1.16, 1.2, 1.25]);
    expect(h.key.currentState!.currentBearing, 0);
    expect(h.key.currentState!.controller.camera.zoom, greaterThan(zoom));
    expect(h.bearings, isEmpty);
  });

  testWidgets('rotatable false: no turning', (tester) async {
    final h = await _pump(tester, init: (h) => h.rotatable = false);
    await _twist(tester, [10, 20, 30, 40]);
    expect(h.key.currentState!.currentBearing, 0);
  });

  testWidgets('the compass: under the zoom buttons, named from the strings, 48dp, turns back to north and hides', (tester) async {
    final handle = tester.ensureSemantics();
    final h = await _pump(tester);
    h.key.currentState!.rotateTo(90);
    await tester.pump();
    final compass = find.byKey(const ValueKey('ui-map-compass'));
    expect(compass, findsOneWidget);
    expect(find.bySemanticsLabel('Reset to north'), findsOneWidget);
    // Under the zoom-out button, at the inline start.
    final zoomOut = find.bySemanticsLabel('Zoom out');
    expect(tester.getRect(compass).top, greaterThan(tester.getRect(zoomOut).bottom - 1));
    expect(tester.getRect(compass).left, closeTo(tester.getRect(zoomOut).left, 1));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tap(compass);
    await tester.pump();
    expect(h.key.currentState!.currentBearing, 0);
    expect(h.bearings, [0]);
    expect(compass, findsNothing);
    handle.dispose();
  });

  testWidgets('the compass eases north with motion on, and is Dhivehi in Dhivehi', (tester) async {
    final h = await _pump(tester, init: (h) {
      h.reduced = false;
      h.strings = UiStrings.dv;
    });
    h.key.currentState!.rotateTo(90);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final handle = tester.ensureSemantics();
    await tester.pump();
    expect(find.bySemanticsLabel('އުތުރު މައްޗަށް ގެންނާ'), findsOneWidget);
    handle.dispose();
    await tester.tap(find.byKey(const ValueKey('ui-map-compass')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.key.currentState!.currentBearing, inExclusiveRange(1, 89));
    await tester.pump(const Duration(seconds: 1));
    expect(h.key.currentState!.currentBearing, closeTo(0, 1e-6));
  });

  testWidgets('compass false: never shown', (tester) async {
    final h = await _pump(tester, init: (h) => h.compass = false);
    h.key.currentState!.rotateTo(90);
    await tester.pump();
    expect(find.byKey(const ValueKey('ui-map-compass')), findsNothing);
  });
}
