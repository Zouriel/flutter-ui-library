import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// 0.44.2, the twin of the web fix: every marker's dot is centred on its own point, with no offset
/// that grows from one marker to the next (the web drew each about 16px below the one before, so
/// 280 pins became a column). flutter_map places each Marker on its own, so this side never had it.

const _male = UiLatLng(4.1755, 73.5093);
const _w = 390.0, _h = 844.0;

final _markers = [
  for (var i = 0; i < 60; i++)
    UiMapMarker(
      id: 'm$i',
      lat: _male.lat + ((i % 6) - 3) * 0.004,
      lng: _male.lng + ((i ~/ 6) - 5) * 0.004,
      label: i % 4 == 0 ? 'Clinic $i' : null,
      tone: i % 3 == 0 ? UiStatus.success : UiStatus.primary,
    ),
];

List<Rect> _dots(WidgetTester tester, double size) => tester
    .widgetList<Container>(find.descendant(of: find.byType(UiMap), matching: find.byWidgetPredicate((w) => w is Container && w.constraints == BoxConstraints.tightFor(width: size, height: size))))
    .map((w) => tester.getRect(find.byWidget(w)))
    .toList();

void main() {
  for (final selected in <String?>[null, 'm17']) {
    testWidgets('60 markers${selected == null ? '' : ', one selected'}: each dot centred on its own point', (tester) async {
      final key = GlobalKey<UiMapState>();
      tester.view.physicalSize = const Size(_w, _h) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UiApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: _w,
            height: _h,
            child: UiMap(key: key, center: _male, zoom: 14, tileProvider: UiMapBlankTiles(), markers: _markers, selectedMarkerId: selected),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      final cam = key.currentState!.controller.camera;
      final small = _dots(tester, 16), big = _dots(tester, uiMapSelectedDot);
      expect(small.length + big.length, _markers.length);
      expect(big, hasLength(selected == null ? 0 : 1));
      final dots = [...small, ...big].map((r) => r.center).toList();
      final missing = <String>[];
      for (final m in _markers) {
        final p = cam.latLngToScreenOffset(LatLng(m.lat, m.lng));
        final i = dots.indexWhere((d) => (d - p).distance <= 0.5);
        if (i < 0) {
          missing.add('${m.id} at $p');
        } else {
          dots.removeAt(i);
        }
      }
      expect(missing, isEmpty, reason: 'no dot centred on these points');
      if (selected != null) {
        final s = _markers.firstWhere((m) => m.id == selected);
        expect((big.single.center - cam.latLngToScreenOffset(LatLng(s.lat, s.lng))).distance, lessThanOrEqualTo(0.5), reason: 'the selected dot on its own point');
      }
    });
  }
}
