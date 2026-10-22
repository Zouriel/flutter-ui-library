import 'dart:ui' show GestureSettings;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// 0.44.0: the search area on UiMap.

const _center = UiLatLng(4.1755, 73.5093);
const _width = 390.0, _height = 500.0;

class _Host {
  double radius = 2000, min = uiMapAreaMinMeters, max = uiMapAreaMaxMeters;
  bool editable = true, preview = false;
  double zoom = 13;
  EdgeInsetsDirectional insets = EdgeInsetsDirectional.zero;
  final changing = <double>[];
  final changed = <double>[];
  late StateSetter set;
  final key = GlobalKey<UiMapState>();
}

Future<_Host> _pump(WidgetTester tester, {TextDirection dir = TextDirection.ltr, bool follow = true}) async {
  final h = _Host();
  tester.view.physicalSize = const Size(_width, 844) * tester.view.devicePixelRatio;
  tester.view.gestureSettings = GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(StatefulBuilder(builder: (context, set) {
    h.set = set;
    return UiApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: Directionality(
            textDirection: dir,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: _width,
                height: _height,
                child: UiMap(
                  key: h.key,
                  center: _center,
                  zoom: h.zoom,
                  tileProvider: UiMapBlankTiles(),
                  viewInsets: h.insets,
                  preview: h.preview,
                  area: UiMapArea(center: _center, radiusMeters: h.radius, editable: h.editable, minMeters: h.min, maxMeters: h.max),
                  onAreaChanging: h.changing.add,
                  onAreaChanged: (r) {
                    h.changed.add(r);
                    if (follow) set(() => h.radius = r);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }));
  await tester.pump(const Duration(milliseconds: 100));
  return h;
}

UiMapAreaPainter _painter(WidgetTester tester) =>
    tester.widgetList<CustomPaint>(find.byType(CustomPaint)).map((p) => p.painter).whereType<UiMapAreaPainter>().single;

Offset _mapOrigin(WidgetTester tester) => tester.getTopLeft(find.byType(UiMap));

void _focusHandle(WidgetTester tester) =>
    Focus.of(tester.element(find.descendant(of: find.byType(UiMapAreaHandle), matching: find.byType(RawGestureDetector)))).requestFocus();

double _mpp(double zoom) => uiMapMetersPerPx(_center.lat, zoom);

void main() {
  group('helpers', () {
    test('uiMapFormatRadius: metres under 1 km, one decimal under 10 km, whole km after', () {
      expect(uiMapFormatRadius(800), '800 m');
      expect(uiMapFormatRadius(999.4), '999 m');
      expect(uiMapFormatRadius(1000), '1 km');
      expect(uiMapFormatRadius(1500), '1.5 km');
      expect(uiMapFormatRadius(2040), '2 km');
      expect(uiMapFormatRadius(9960), '10 km');
      expect(uiMapFormatRadius(20000), '20 km');
      expect(uiMapFormatRadius(20400), '20 km');
      expect(uiMapFormatRadius(1500, const UiStrings(mapRadiusKilometers: '{n} ކ.މ')), '1.5 ކ.މ');
      expect(uiMapFormatRadius(300, const UiStrings(mapRadiusMeters: '{n} މ')), '300 މ');
    });

    test('uiMapNiceRadius rounds to 10 m, 100 m or 1 km', () {
      expect(uiMapNiceRadius(834), 830);
      expect(uiMapNiceRadius(2468), 2500);
      expect(uiMapNiceRadius(23456), 23000);
    });

    test('uiMapAreaStep: 10% out or in, nicely rounded, at least one unit, clamped', () {
      expect(uiMapAreaStep(2000, 1, 200, 50000), 2200);
      expect(uiMapAreaStep(2200, -1, 200, 50000), 2000);
      expect(uiMapAreaStep(200, -1, 200, 50000), 200);
      expect(uiMapAreaStep(49000, 1, 200, 50000), 50000);
      // 10% of 20 m rounds back to 20 m: one unit anyway.
      expect(uiMapAreaStep(20, 1, 0, 50000), 30);
      expect(uiMapAreaStep(30, -1, 0, 50000), 20);
    });

    test('uiMapMetersPerPx halves with each zoom level', () {
      expect(uiMapMetersPerPx(0, 0), closeTo(156543.03, 0.01));
      expect(uiMapMetersPerPx(_center.lat, 14) * 2, closeTo(uiMapMetersPerPx(_center.lat, 13), 1e-9));
    });
  });

  testWidgets('the circle is drawn in true metres around the centre and scales with the zoom', (tester) async {
    final h = await _pump(tester);
    final cam = h.key.currentState!.controller.camera;
    var p = _painter(tester);
    expect(p.radius, closeTo(2000 / _mpp(13), 1e-6));
    expect(p.radius, greaterThan(100));
    final c = cam.latLngToScreenOffset(const LatLng(4.1755, 73.5093));
    expect(p.center.dx, closeTo(c.dx, 1e-6));
    expect(p.center.dy, closeTo(c.dy, 1e-6));

    h.set(() => h.zoom = 14);
    await tester.pump(const Duration(milliseconds: 100));
    p = _painter(tester);
    expect(p.radius, closeTo(2 * 2000 / _mpp(13), 1e-6));
  });

  testWidgets('dragging the handle changes the radius (changing while dragging, changed once on release) and the map does not pan', (tester) async {
    final h = await _pump(tester);
    final cam = h.key.currentState!.controller.camera;
    final before = cam.center;
    final handle = tester.getCenter(find.byKey(const ValueKey('ui-map-area-handle')));
    final c = _mapOrigin(tester) + cam.latLngToScreenOffset(const LatLng(4.1755, 73.5093));
    // The handle sits on the circle's east edge.
    expect(handle.dy, closeTo(c.dy, 0.5));
    expect(handle.dx - c.dx, closeTo(2000 / _mpp(13), 0.5));

    final g = await tester.startGesture(handle);
    for (var i = 0; i < 5; i++) {
      await g.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    expect(h.changing, isNotEmpty);
    expect(h.changed, isEmpty);
    await g.up();
    await tester.pump(const Duration(milliseconds: 100));
    final expected = uiMapNiceRadius((handle.dx + 50 - c.dx) * _mpp(13));
    expect(h.changed, [expected]);
    expect(h.changing.last, expected);
    expect(h.radius, expected);
    expect(h.key.currentState!.controller.camera.center, before);
    expect(_painter(tester).radius, closeTo(expected / _mpp(13), 1e-6));
  });

  testWidgets('a drag anywhere else, inside the circle too, still pans the map and leaves the area alone', (tester) async {
    final h = await _pump(tester);
    final before = h.key.currentState!.controller.camera.center;
    // Inside the circle, away from the handle and the zoom buttons.
    await tester.dragFrom(_mapOrigin(tester) + const Offset(180, 300), const Offset(-60, -40));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.key.currentState!.controller.camera.center, isNot(before));
    expect(h.changing, isEmpty);
    expect(h.changed, isEmpty);
  });

  testWidgets('a release reports the radius even unchanged; without the app following, the chosen radius stays drawn', (tester) async {
    final h = await _pump(tester, follow: false);
    final handle = tester.getCenter(find.byKey(const ValueKey('ui-map-area-handle')));
    await tester.tapAt(handle);
    await tester.pump();
    expect(h.changed, [2000]);
    expect(h.changing, isEmpty);
    await tester.dragFrom(handle, const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 100));
    final r = h.changed.last;
    expect(r, greaterThan(2000));
    expect(h.radius, 2000);
    expect(_painter(tester).radius, closeTo(r / _mpp(13), 1e-6));
    // A new area from the app wins.
    h.set(() => h.radius = 1500);
    await tester.pump();
    expect(_painter(tester).radius, closeTo(1500 / _mpp(13), 1e-6));
  });

  testWidgets('the drag is clamped to min and max', (tester) async {
    final h = await _pump(tester);
    h.set(() {
      h.min = 1000;
      h.max = 2500;
    });
    await tester.pump();
    final handle = tester.getCenter(find.byKey(const ValueKey('ui-map-area-handle')));
    await tester.dragFrom(handle, const Offset(150, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.changed.last, 2500);
    final again = tester.getCenter(find.byKey(const ValueKey('ui-map-area-handle')));
    final c = _mapOrigin(tester) + h.key.currentState!.controller.camera.latLngToScreenOffset(const LatLng(4.1755, 73.5093));
    // To just beside the centre: a radius under the minimum.
    await tester.dragFrom(again, Offset(c.dx + 5 - again.dx, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.changed.last, 1000);
    expect(h.changing.every((r) => r >= 1000 && r <= 2500), isTrue);
  });

  testWidgets('keyboard: arrows step 10%, Home and End go to min and max, each step calls both callbacks', (tester) async {
    final h = await _pump(tester);
    _focusHandle(tester);
    await tester.pump();
    final camBefore = h.key.currentState!.controller.camera.center;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(h.changed, [2200]);
    expect(h.changing, [2200]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(h.changed.last, 2000);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(h.changed.last, 2200);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(h.changed.last, 2000);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(h.changed.last, uiMapAreaMaxMeters);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(h.changed.last, uiMapAreaMinMeters);
    // The arrows went to the handle, not the map's own panning.
    expect(h.key.currentState!.controller.camera.center, camBefore);
  });

  testWidgets('RTL: the handle is on the west edge and Left steps out', (tester) async {
    final h = await _pump(tester, dir: TextDirection.rtl);
    final cam = h.key.currentState!.controller.camera;
    final handle = tester.getCenter(find.byKey(const ValueKey('ui-map-area-handle')));
    final c = _mapOrigin(tester) + cam.latLngToScreenOffset(const LatLng(4.1755, 73.5093));
    expect(c.dx - handle.dx, closeTo(2000 / _mpp(13), 0.5));
    _focusHandle(tester);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(h.changed, [2200]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(h.changed.last, 2000);
  });

  testWidgets('semantics: a slider named by the area label with the radius as its value', (tester) async {
    final sem = tester.ensureSemantics();
    final h = await _pump(tester);
    final node = tester.getSemantics(find.bySemanticsLabel('Search area'));
    final d = node.getSemanticsData();
    expect(d.label, 'Search area');
    expect(d.value, '2 km');
    expect(d.increasedValue, '2.2 km');
    expect(d.decreasedValue, '1.8 km');
    expect(d.flagsCollection.isSlider, isTrue);
    expect(d.hasAction(SemanticsAction.increase), isTrue);
    tester.semantics.increase(find.semantics.byLabel('Search area'));
    await tester.pump();
    expect(h.changed, [2200]);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    sem.dispose();
  });

  testWidgets('not editable, or a preview: the circle without a handle', (tester) async {
    final h = await _pump(tester);
    expect(find.byType(UiMapAreaHandle), findsOneWidget);
    h.set(() => h.editable = false);
    await tester.pump();
    expect(find.byType(UiMapAreaHandle), findsNothing);
    expect(_painter(tester).radius, greaterThan(0));
    h.set(() {
      h.editable = true;
      h.preview = true;
    });
    await tester.pump();
    expect(find.byType(UiMapAreaHandle), findsNothing);
    expect(_painter(tester).radius, greaterThan(0));
  });

  testWidgets('fitArea shows the whole circle inside the visible part (between the insets)', (tester) async {
    final h = await _pump(tester);
    h.set(() {
      h.radius = 20000;
      h.insets = const EdgeInsetsDirectional.only(bottom: 200);
    });
    await tester.pump(const Duration(milliseconds: 100));
    // At zoom 13 a 20 km circle is far bigger than the map.
    expect(_painter(tester).radius, greaterThan(_width));
    h.key.currentState!.fitArea(animate: false);
    await tester.pump(const Duration(milliseconds: 100));
    final p = _painter(tester);
    expect(p.center.dx - p.radius, greaterThanOrEqualTo(0));
    expect(p.center.dx + p.radius, lessThanOrEqualTo(_width));
    expect(p.center.dy - p.radius, greaterThanOrEqualTo(0));
    expect(p.center.dy + p.radius, lessThanOrEqualTo(_height - 200));
    // At the closest whole zoom where the circle fits the visible part less 24 each side.
    var z = 19.0;
    while (2 * 20000 / _mpp(z) > _height - 200 - 48 || 2 * 20000 / _mpp(z) > _width - 48) {
      z--;
    }
    expect(h.key.currentState!.controller.camera.zoom, z);
  });

  testWidgets('golden: an editable search area with its handle and chip', (tester) async {
    await expectThemedGolden(
      tester,
      'map_area',
      (context) => UiMap(
        center: _center,
        zoom: 13,
        tileProvider: UiMapBlankTiles(),
        area: const UiMapArea(center: _center, radiusMeters: 1500, editable: true),
        markers: const [UiMapMarker(id: 'a', lat: 4.1800, lng: 73.5050, label: 'Clinic')],
      ),
      height: 320,
    );
  });
}
