import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// 0.42.1: a fit owns the camera. When the insets change while a fit animates (the Dhirumi nurse
/// app: the route makes the sheet's peek taller just as it appears) or after it, the fit is worked
/// out again for the new insets instead of a stale inset pan (0.42.0 ended ~900px off at zoom 17).

const _nurse = UiLatLng(4.1755, 73.5093);
const _patient = UiLatLng(4.2105, 73.5402);
const _road = [UiLatLng(4.1755, 73.5093), UiLatLng(4.19, 73.525), UiLatLng(4.2105, 73.5402)];
// A short route (about 150m), which fits at zoom 17: the case the nurse app hit.
const _short = [UiLatLng(4.17682, 73.5121), UiLatLng(4.17708, 73.51244), UiLatLng(4.17785, 73.51146)];
const _w = 390.0, _h = 844.0;

class _Host {
  EdgeInsetsDirectional insets = EdgeInsetsDirectional.zero;
  TextDirection dir = TextDirection.ltr;
  bool reduced = false;
  late StateSetter set;
  final key = GlobalKey<UiMapState>();
}

Future<_Host> _pump(WidgetTester tester, {void Function(_Host h)? init}) async {
  final h = _Host();
  init?.call(h);
  tester.view.physicalSize = const Size(_w, _h) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(StatefulBuilder(builder: (context, set) {
    h.set = set;
    return UiApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: h.reduced),
          child: Directionality(
            textDirection: h.dir,
            child: SizedBox(
              width: _w,
              height: _h,
              child: UiMap(key: h.key, fill: true, center: _nurse, zoom: 15, tileProvider: UiMapBlankTiles(), viewInsets: h.insets),
            ),
          ),
        ),
      ),
    );
  }));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  return h;
}

Offset _screen(_Host h, UiLatLng p) => h.key.currentState!.controller.camera.latLngToScreenOffset(LatLng(p.lat, p.lng));

/// The points' bounds are centred in the part [insets] leave visible (the fit's own centring).
void _expectCentred(_Host h, List<UiLatLng> points, EdgeInsets insets) {
  final pts = [for (final p in points) _screen(h, p)];
  final xs = pts.map((p) => p.dx), ys = pts.map((p) => p.dy);
  double mid(Iterable<double> v) => (v.reduce((a, b) => a < b ? a : b) + v.reduce((a, b) => a > b ? a : b)) / 2;
  expect(mid(xs), closeTo((insets.left + _w - insets.right) / 2, 1), reason: 'centred across');
  expect(mid(ys), closeTo((insets.top + _h - insets.bottom) / 2, 1), reason: 'centred down');
}

/// Every point inside the part [insets] leave visible, less the 24px fit padding (half a px slack).
void _expectInside(_Host h, List<UiLatLng> points, EdgeInsets insets, {String? reason}) {
  for (final p in points) {
    final s = _screen(h, p);
    expect(s.dx, inInclusiveRange(insets.left + 24 - 0.5, _w - insets.right - 24 + 0.5), reason: '$reason: x of $p');
    expect(s.dy, inInclusiveRange(insets.top + 24 - 0.5, _h - insets.bottom - 24 + 0.5), reason: '$reason: y of $p');
  }
}

void main() {
  group('fitPoints and changing insets', () {
    testWidgets('insets change mid-fit: every point ends inside the new visible part (short route, zoom 17)', (tester) async {
      final h = await _pump(tester, init: (h) => h.insets = const EdgeInsetsDirectional.only(top: 100, bottom: 200));
      h.key.currentState!.fitPoints(_short);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120)); // on its way
      h.set(() => h.insets = const EdgeInsetsDirectional.only(top: 100, bottom: 420)); // the peek grew
      await tester.pumpAndSettle();
      _expectInside(h, _short, const EdgeInsets.only(top: 100, bottom: 420), reason: 'short');
      _expectCentred(h, _short, const EdgeInsets.only(top: 100, bottom: 420));
      expect(h.key.currentState!.controller.camera.zoom, 17);
    });

    testWidgets('insets that grow frame by frame while the fit runs (a sheet animating its height)', (tester) async {
      final h = await _pump(tester, init: (h) => h.insets = const EdgeInsetsDirectional.only(bottom: 160));
      h.key.currentState!.fitPoints([_nurse, _patient, ..._road]);
      await tester.pump();
      for (var i = 1; i <= 20; i++) {
        h.set(() => h.insets = EdgeInsetsDirectional.only(bottom: 160 + 12.0 * i));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      _expectInside(h, [_nurse, _patient, ..._road], const EdgeInsets.only(bottom: 400), reason: 'animated sheet');
      _expectCentred(h, [_nurse, _patient, ..._road], const EdgeInsets.only(bottom: 400));
      final zoom = h.key.currentState!.controller.camera.zoom;
      expect(zoom, zoom.roundToDouble(), reason: 'a whole zoom');
    });

    testWidgets('insets change right after a fit (it still owns the camera): fitted again, not panned', (tester) async {
      final h = await _pump(tester, init: (h) => h.reduced = true);
      h.key.currentState!.fitPoints([_nurse, _patient]);
      await tester.pump();
      h.set(() => h.insets = const EdgeInsetsDirectional.only(top: 140, bottom: 460));
      await tester.pumpAndSettle();
      _expectInside(h, [_nurse, _patient], const EdgeInsets.only(top: 140, bottom: 460), reason: 'after');
      // And with motion on: the move to the new fit is animated, and lands inside too.
      h.set(() => h.reduced = false);
      await tester.pump();
      h.set(() => h.insets = const EdgeInsetsDirectional.only(top: 140, bottom: 200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      _expectInside(h, [_nurse, _patient], const EdgeInsets.only(top: 140, bottom: 200), reason: 'animated after');
    });

    testWidgets('RTL: an end inset changing mid-fit is on the left', (tester) async {
      final h = await _pump(tester, init: (h) => h.dir = TextDirection.rtl);
      h.key.currentState!.fitPoints([_nurse, _patient]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      h.set(() => h.insets = const EdgeInsetsDirectional.only(end: 150));
      await tester.pumpAndSettle();
      _expectInside(h, [_nurse, _patient], const EdgeInsets.only(left: 150), reason: 'rtl');
      _expectCentred(h, [_nurse, _patient], const EdgeInsets.only(left: 150));
    });

    testWidgets('once something else moves the map (flyTo, the zoom buttons, a drag), insets pan as before', (tester) async {
      final h = await _pump(tester, init: (h) => h.reduced = true);
      final s = h.key.currentState!;
      s.fitPoints([_nurse, _patient]);
      await tester.pump();
      s.flyTo(_patient, zoom: 16); // the app takes the camera back
      await tester.pump();
      h.set(() => h.insets = const EdgeInsetsDirectional.only(bottom: 400));
      await tester.pumpAndSettle();
      // The point in the middle of the visible part stays there; no refit (zoom unchanged).
      expect(s.controller.camera.zoom, 16);
      expect(_screen(h, _patient).dx, closeTo(_w / 2, 0.5));
      expect(_screen(h, _patient).dy, closeTo((_h - 400) / 2, 0.5));

      s.fitPoints([_nurse, _patient]);
      await tester.pump();
      await tester.drag(find.byType(UiMap), const Offset(-60, 0)); // the person pans
      await tester.pumpAndSettle();
      final before = _screen(h, _nurse);
      h.set(() => h.insets = const EdgeInsetsDirectional.only(bottom: 200));
      await tester.pumpAndSettle();
      // Panned by half the inset difference (the middle of the visible part moves down 100px).
      expect(_screen(h, _nurse).dy - before.dy, closeTo(100, 0.5));
      expect(_screen(h, _nurse).dx, closeTo(before.dx, 0.5));
    });

    testWidgets('an inset pan running when the zoom changes still lands the point in the middle (no jump to another scale)', (tester) async {
      final h = await _pump(tester);
      final s = h.key.currentState!;
      s.flyTo(_nurse, zoom: 15);
      await tester.pump();
      h.set(() => h.insets = const EdgeInsetsDirectional.only(bottom: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      // Something zooms the map while the pan runs.
      s.controller.move(s.controller.camera.center, 17);
      await tester.pumpAndSettle();
      // The pan still brings the nurse to the middle of the visible part at the new zoom, not
      // hundreds of px away (0.42.0 unprojected zoom-15 px at zoom 17).
      expect((_screen(h, _nurse) - const Offset(_w / 2, (_h - 300) / 2)).distance, lessThan(1));
    });
  });
}
