import 'dart:ui' show GestureSettings;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// 0.43.1: onMapTap reports only a tap on the map background.

const _center = UiLatLng(4.1755, 73.5093);
const _marker = UiMapMarker(id: 'nurse', lat: 4.1762, lng: 73.5105, label: 'Aminath Hassan, RN');
const _width = 390.0, _height = 300.0;

class _Host {
  bool preview = false, pinMode = false, pinDraggable = false, markerSelectable = true;
  UiLatLng? pin;
  UiMapUserLocation? user;
  final mapTaps = <UiLatLng>[];
  final pins = <UiLatLng>[];
  final selected = <String>[];
  int previewPresses = 0, locates = 0, controls = 0, attributions = 0;
  late StateSetter set;
  final key = GlobalKey<UiMapState>();
}

Widget _map(_Host h, {bool attributionCallback = true}) => UiMap(
      key: h.key,
      center: _center,
      zoom: 15,
      tileProvider: UiMapBlankTiles(),
      markers: const [_marker],
      onMarkerSelected: h.markerSelectable ? (m) => h.selected.add(m.id) : null,
      onMapTap: h.mapTaps.add,
      pin: h.pin,
      pinMode: h.pinMode,
      pinDraggable: h.pinDraggable,
      onPinChanged: h.pins.add,
      userLocation: h.user,
      locateControl: true,
      onLocate: () => h.locates++,
      controls: [UiMapControl(id: 'fit', icon: HugeIcons.strokeRoundedCenterFocus, semanticLabel: 'Show both', onPressed: () => h.controls++)],
      onAttributionTap: attributionCallback ? () => h.attributions++ : null,
      preview: h.preview,
      onPreviewPressed: () => h.previewPresses++,
    );

Future<_Host> _pump(WidgetTester tester, {bool attributionCallback = true}) async {
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
          child: Align(alignment: Alignment.topLeft, child: SizedBox(width: _width, height: _height, child: _map(h, attributionCallback: attributionCallback))),
        ),
      ),
    );
  }));
  await tester.pump(const Duration(milliseconds: 100));
  return h;
}

Offset _global(WidgetTester tester, Offset local) => tester.getTopLeft(find.byType(UiMap)) + local;

Future<void> _tap(WidgetTester tester, Offset local) async {
  await tester.tapAt(_global(tester, local));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('a background tap calls onMapTap once with its point; pinMode moves the pin first and still calls it', (tester) async {
    final h = await _pump(tester);
    const firstAt = Offset(90, 210);
    final first = h.key.currentState!.controller.camera.screenOffsetToLatLng(firstAt);
    await _tap(tester, firstAt);
    expect(h.mapTaps.single.lat, closeTo(first.latitude, 1e-9));
    expect(h.mapTaps.single.lng, closeTo(first.longitude, 1e-9));

    h.set(() => h.pinMode = true);
    await tester.pump();
    const secondAt = Offset(150, 60);
    final second = h.key.currentState!.controller.camera.screenOffsetToLatLng(secondAt);
    await _tap(tester, secondAt);
    expect(h.mapTaps, hasLength(2));
    expect(h.pins, hasLength(1));
    expect(h.pins.single.lat, closeTo(second.latitude, 1e-9));
    expect(h.pins.single.lng, closeTo(second.longitude, 1e-9));
    expect(h.mapTaps.last, h.pins.single);
  });

  testWidgets('a marker tap selects it but does not call onMapTap, even without a selection callback', (tester) async {
    final h = await _pump(tester);
    Offset markerPoint() => h.key.currentState!.controller.camera.latLngToScreenOffset(LatLng(_marker.lat, _marker.lng));
    await _tap(tester, markerPoint());
    expect(h.selected, ['nurse']);
    expect(h.mapTaps, isEmpty);

    h.set(() => h.markerSelectable = false);
    await tester.pump();
    await _tap(tester, markerPoint());
    expect(h.selected, ['nurse']);
    expect(h.mapTaps, isEmpty);
  });

  testWidgets('zoom, locate and app controls, plus attribution without a callback, do not call onMapTap', (tester) async {
    final h = await _pump(tester, attributionCallback: false);
    await tester.tap(find.byType(UiMapZoomButton).first);
    await tester.tap(find.byType(UiMapLocateButton));
    await tester.tap(find.byType(UiMapControlButton));
    await tester.tap(find.text('© OpenStreetMap contributors'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.locates, 1);
    expect(h.controls, 1);
    expect(h.attributions, 0);
    expect(h.mapTaps, isEmpty);
  });

  testWidgets('preview calls only onPreviewPressed', (tester) async {
    final h = await _pump(tester);
    h.set(() => h.preview = true);
    await tester.pump();
    await _tap(tester, const Offset(195, 150));
    expect(h.previewPresses, 1);
    expect(h.mapTaps, isEmpty);
  });

  testWidgets('a drag and a double tap do not call onMapTap', (tester) async {
    final h = await _pump(tester);
    final before = h.key.currentState!.controller.camera.center;
    await tester.dragFrom(_global(tester, const Offset(90, 210)), const Offset(100, -60));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.key.currentState!.controller.camera.center, isNot(before));
    expect(h.mapTaps, isEmpty);

    final at = _global(tester, const Offset(150, 60));
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.mapTaps, isEmpty);
  });

  testWidgets('the fixed or draggable pin does not call onMapTap', (tester) async {
    final semantics = tester.ensureSemantics();
    final h = await _pump(tester);
    h.set(() {
      h.pin = const UiLatLng(4.1745, 73.5085);
      h.user = const UiMapUserLocation(4.177, 73.507);
    });
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Chosen location'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.mapTaps, isEmpty);

    h.set(() => h.pinDraggable = true);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Chosen location'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.mapTaps, isEmpty);
    semantics.dispose();
  });

  testWidgets('the user dot (its halo can be 240 px) is map background: a tap there calls onMapTap', (tester) async {
    final h = await _pump(tester);
    h.set(() => h.user = const UiMapUserLocation(4.177, 73.507));
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byType(UiMapUserDot)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.mapTaps, hasLength(1));
  });
}
