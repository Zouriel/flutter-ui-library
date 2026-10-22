import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// 0.44.2: fitPoints / fitArea asked in the frame the map is built (before flutter_map is ready,
/// e.g. from the app's own post-frame callback on opening) are held and run once it is, without
/// animating; they used to do nothing (the Dhirumi nurse map).

const _male = UiLatLng(4.1755, 73.5093);
const _hulhumale = UiLatLng(4.2105, 73.5402);
const _w = 390.0, _h = 844.0;

/// Asks [ask] from a post-frame callback registered in its initState: it runs in the map's first
/// frame, before flutter_map's own onMapReady callback (registered later, by the child).
class _Asker extends StatefulWidget {
  const _Asker({required this.mapKey, required this.ask, required this.child});
  final GlobalKey<UiMapState> mapKey;
  final void Function(UiMapState s) ask;
  final Widget child;
  @override
  State<_Asker> createState() => _AskerState();
}

class _AskerState extends State<_Asker> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.ask(widget.mapKey.currentState!));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<UiMapState> _open(WidgetTester tester, void Function(UiMapState s) ask, {List<double>? zooms}) async {
  final key = GlobalKey<UiMapState>();
  tester.view.physicalSize = const Size(_w, _h) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(
    home: _Asker(
      mapKey: key,
      ask: ask,
      child: SizedBox(
        width: _w,
        height: _h,
        child: UiMap(
          key: key,
          fill: true,
          center: _male,
          zoom: 5,
          tileProvider: UiMapBlankTiles(),
          area: const UiMapArea(center: _male, radiusMeters: 20000),
          onCenterChanged: (v) => zooms?.add(v.zoom),
        ),
      ),
    ),
  ));
  // One more frame only: the held fit lands straight away (no animation to wait for).
  await tester.pump();
  return key.currentState!;
}

Offset _screen(UiMapState s, UiLatLng p) => s.controller.camera.latLngToScreenOffset(LatLng(p.lat, p.lng));

void main() {
  testWidgets('fitPoints asked in the first frame: both points in view once the map is ready, not animated', (tester) async {
    final zooms = <double>[];
    final s = await _open(tester, (s) => s.fitPoints([_male, _hulhumale]), zooms: zooms);
    expect(s.controller.camera.zoom, greaterThan(10), reason: 'fitted, not the input zoom 5');
    for (final p in [_male, _hulhumale]) {
      final o = _screen(s, p);
      expect(o.dx, inInclusiveRange(24 - 0.5, _w - 24 + 0.5), reason: 'x of $p');
      expect(o.dy, inInclusiveRange(24 - 0.5, _h - 24 + 0.5), reason: 'y of $p');
    }
    final z = s.controller.camera.zoom;
    expect(z, z.roundToDouble(), reason: 'a whole zoom');
    expect(zooms, [z], reason: 'one jump, reported once, no fly in between');
    await tester.pumpAndSettle();
    expect(s.controller.camera.zoom, z, reason: 'nothing left animating');
  });

  testWidgets('fitArea asked in the first frame: the whole 20 km circle in view once the map is ready', (tester) async {
    final s = await _open(tester, (s) => s.fitArea());
    final z = s.controller.camera.zoom;
    expect(z, greaterThan(5), reason: 'fitted, not the input zoom 5');
    for (final p in uiMapAreaBounds(const UiMapArea(center: _male, radiusMeters: 20000))) {
      final o = _screen(s, p);
      expect(o.dx, inInclusiveRange(24 - 0.5, _w - 24 + 0.5), reason: 'x of $p');
      expect(o.dy, inInclusiveRange(24 - 0.5, _h - 24 + 0.5), reason: 'y of $p');
    }
    // The closest whole zoom: one more and the circle no longer fits across.
    final mpp = uiMapMetersPerPx(_male.lat, z + 1);
    expect(2 * 20000 / mpp, greaterThan(_w - 48));
  });
}
