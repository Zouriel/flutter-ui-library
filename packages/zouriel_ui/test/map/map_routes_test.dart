import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart' show FlutterMap, MarkerLayer, PolylineLayer;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// 0.42.0: route lines, fitPoints and the map's polish (zoom controls, label chips).

const _nurse = UiLatLng(4.1755, 73.5093);
const _patient = UiLatLng(4.2105, 73.5402);
const _road = [UiLatLng(4.1755, 73.5093), UiLatLng(4.19, 73.525), UiLatLng(4.2105, 73.5402)];
const _w = 390.0, _h = 844.0;
const _address = 'Lily Magu, Hiyaa Tower 4, Hulhumale Male'; // 40 characters

class _Host {
  List<UiMapRoute> routes = const [UiMapRoute(id: 'r', points: _road, semanticLabel: 'Route, 5.1 km')];
  List<UiMapMarker> markers = const [UiMapMarker(id: 'p', lat: 4.1765, lng: 73.5083, label: _address, tone: UiStatus.danger)];
  EdgeInsetsDirectional insets = EdgeInsetsDirectional.zero;
  TextDirection dir = TextDirection.ltr;
  bool reduced = true;
  UiThemeName theme = UiThemeName.maldives;
  double width = _w;
  final views = <UiMapView>[];
  late StateSetter set;
  final key = GlobalKey<UiMapState>();
}

Future<_Host> _pump(WidgetTester tester, {void Function(_Host h)? init}) async {
  final h = _Host();
  init?.call(h);
  tester.view.physicalSize = Size(h.width, _h) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(StatefulBuilder(builder: (context, set) {
    h.set = set;
    return UiApp(
      theme: h.theme,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: h.reduced),
          child: Directionality(
            textDirection: h.dir,
            child: SizedBox(
              width: h.width,
              height: _h,
              child: UiMap(
                key: h.key,
                fill: true,
                center: _nurse,
                zoom: 15,
                tileProvider: UiMapBlankTiles(),
                routes: h.routes,
                markers: h.markers,
                userLocation: const UiMapUserLocation(4.1755, 73.5093),
                pin: _patient,
                pinDraggable: false,
                viewInsets: h.insets,
                onCenterChanged: h.views.add,
              ),
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

UiTokens _t(WidgetTester tester) => UiTheme.of(tester.element(find.byType(UiMap))).tokens;

Offset _screen(WidgetTester tester, _Host h, UiLatLng p) {
  final cam = h.key.currentState!.controller.camera;
  return tester.getTopLeft(find.byType(UiMap)) + cam.latLngToScreenOffset(LatLng(p.lat, p.lng));
}

PolylineLayer<String> _layer(WidgetTester tester) => tester.widget<PolylineLayer<String>>(find.byType(PolylineLayer<String>));

void main() {
  group('routes', () {
    testWidgets('a casing with the tone line over it, round caps and joins, in the theme route colours', (tester) async {
      await _pump(tester);
      final t = _t(tester);
      final lines = _layer(tester).polylines;
      expect(lines, hasLength(1));
      final l = lines.single;
      expect(l.points, [for (final p in _road) LatLng(p.lat, p.lng)]);
      expect(l.color, t.mapRoutePrimary);
      expect(l.borderColor, t.mapRouteCasing);
      expect((l.strokeWidth, l.strokeWidth + l.borderStrokeWidth), (5.0, 9.0)); // zoom 15: full width
      expect((l.strokeCap, l.strokeJoin), (StrokeCap.round, StrokeJoin.round));
    });

    testWidgets('sits over the tiles and under the pulse, the dot, the markers and the pin', (tester) async {
      await _pump(tester);
      final children = tester.widget<FlutterMap>(find.byType(FlutterMap)).children;
      final route = children.indexWhere((c) => c.runtimeType.toString() == '_RouteLayer');
      final tiles = children.indexWhere((c) => c is TileLayer);
      final user = children.indexWhere((c) => c.runtimeType.toString() == '_UserLayer');
      final firstMarkers = children.indexWhere((c) => c is MarkerLayer);
      expect(tiles, 0);
      expect(route, greaterThan(tiles));
      expect(route, lessThan(user));
      expect(route, lessThan(firstMarkers));
      // And it never takes a tap from the map or a marker.
      expect(find.ancestor(of: find.byType(PolylineLayer<String>), matching: find.byType(IgnorePointer)), findsWidgets);
    });

    testWidgets('a new list redraws on the same map: new points, a new tone; empty removes the line', (tester) async {
      final h = await _pump(tester);
      final state = h.key.currentState;
      final controller = state!.controller;
      h.set(() => h.routes = const [UiMapRoute(id: 'r', points: [_nurse, UiLatLng(4.2, 73.53)], tone: UiMapRouteTone.success)]);
      await tester.pump();
      final l = _layer(tester).polylines.single;
      expect(l.points.last, const LatLng(4.2, 73.53));
      expect(l.color, _t(tester).mapRouteSuccess);
      expect(h.key.currentState, same(state)); // not a new map
      expect(h.key.currentState!.controller, same(controller));
      h.set(() => h.routes = const []);
      await tester.pump();
      expect(find.byType(PolylineLayer<String>), findsNothing);
      h.set(() => h.routes = const [UiMapRoute(id: 'a', points: _road), UiMapRoute(id: 'b', points: [_patient]), UiMapRoute(id: 'c', points: [_nurse, _patient], tone: UiMapRouteTone.muted)]);
      await tester.pump();
      expect(_layer(tester).polylines.map((p) => p.hitValue), ['a', 'c']); // one point is no line
      expect(_layer(tester).polylines.last.color, _t(tester).mapRouteMuted);
    });

    testWidgets('thinner zoomed out, following the zoom', (tester) async {
      expect(uiMapRouteWidth(16), (line: 5.0, casing: 9.0));
      expect(uiMapRouteWidth(8).line, closeTo(3, 1e-9));
      expect(uiMapRouteWidth(8).casing, closeTo(5.4, 1e-9));
      expect(uiMapRouteWidth(12).line, closeTo(4, 1e-9));
      final h = await _pump(tester);
      h.key.currentState!.controller.move(const LatLng(4.19, 73.52), 12);
      await tester.pump();
      final l = _layer(tester).polylines.single;
      expect(l.strokeWidth, closeTo(4, 1e-9));
      expect(l.strokeWidth + l.borderStrokeWidth, closeTo(7.2, 1e-9));
    });

    testWidgets('one name for screen readers, from the app; none without it', (tester) async {
      final handle = tester.ensureSemantics();
      final h = await _pump(tester);
      expect(find.bySemanticsLabel('Route, 5.1 km'), findsOneWidget);
      h.set(() => h.routes = const [UiMapRoute(id: 'r', points: _road)]);
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('Route')), findsNothing);
      handle.dispose();
    });

    testWidgets('RTL: the line stays on the road (the map is laid out LTR)', (tester) async {
      final h = await _pump(tester, init: (h) => h.dir = TextDirection.rtl);
      // The patient is east of the nurse: still to the right in RTL.
      expect(_screen(tester, h, _patient).dx, greaterThan(_screen(tester, h, _nurse).dx));
      expect(_layer(tester).polylines.single.points.first, const LatLng(4.1755, 73.5093));
    });

    test('every tone holds 3:1 against the map tiles (streets-v2, dataviz) in the theme brightness and its casing, in every theme', () {
      // The same colour lists as the web style contract: MapTiler streets-v2 / -dark and dataviz /
      // -dark over Male and Hulhumale at zoom 15-16, every colour covering more than 0.2% of the view.
      const light = [0xffd1e6e9, 0xffd2e7ea, 0xffdedede, 0xffe1e1e1, 0xffe6e6e6, 0xffedf5e1, 0xfffaf9f9, 0xffffffff, //
        0xff84caf9, 0xfffefefe, 0xfff5f0e4, 0xffededed, 0xfffcf5cd, 0xffe9e4d9, 0xfff2ecd6, 0xffe8e3d1, 0xffe4ecd7, 0xffdae9c7, 0xffe4e0d6, 0xffe6e4d5];
      const dark = [0xff000000, 0xff141414, 0xff222222, 0xff292929, 0xff323232, //
        0xff162030, 0xff151f2f, 0xff162132, 0xff365485, 0xff545454, 0xff25364e, 0xff243650, 0xff16465a, 0xff2c3758, 0xff2c405f, 0xff2e4870];
      final fails = <String>[];
      for (final name in UiThemeName.values) {
        final t = uiThemeTokens[name]!;
        final isDark = uiContrast(const Color(0xff000000), t.surface) < uiContrast(const Color(0xffffffff), t.surface);
        expect(t.mapRouteCasing.a, 1, reason: '$name casing is opaque');
        for (final tone in UiMapRouteTone.values) {
          final c = Color.alphaBlend(uiMapRouteColor(t, tone), t.mapRouteCasing);
          final worst = [for (final g in isDark ? dark : light) uiContrast(c, Color(g))].reduce((a, b) => a < b ? a : b);
          if (worst < 3) fails.add('$name $tone: ${worst.toStringAsFixed(2)}:1 over the tiles');
          if (uiContrast(c, t.mapRouteCasing) < 3) fails.add('$name $tone: under 3:1 on its casing');
        }
      }
      expect(fails, isEmpty);
    });
  });

  group('fitPoints', () {
    test('the maths: a whole zoom that fits the free part, centred there; the same numbers as the web', () {
      const area = EdgeInsets.fromLTRB(24, 100, 24, 300);
      final v = uiMapFitView(const [_nurse, _patient], const Size(_w, _h), area)!;
      expect(v.zoom, 13);
      expect(v.lat, closeTo(4.175879817558261, 1e-9));
      expect(v.lng, closeTo(73.52475000000001, 1e-9));
      expect(uiMapFitView(const [], const Size(_w, _h), area), isNull);
      final one = uiMapFitView(const [_nurse], const Size(_w, _h), EdgeInsets.zero)!;
      expect(one.lat, closeTo(_nurse.lat, 1e-9));
      expect(one.lng, closeTo(_nurse.lng, 1e-9));
      expect(one.zoom, uiMapFitMaxZoom);
      expect(uiMapFitView(const [_nurse, _patient], const Size(_w, _h), area, maxZoom: 12)!.zoom, 12);
    });

    testWidgets('every point lands inside the part the insets leave visible, plus the padding', (tester) async {
      final h = await _pump(tester, init: (h) => h.insets = const EdgeInsetsDirectional.only(top: 120, bottom: 360));
      h.key.currentState!.fitPoints(const [_nurse, _patient, ..._road]);
      await tester.pump();
      final pts = [for (final p in [_nurse, _patient, ..._road]) _screen(tester, h, p)];
      for (final p in pts) {
        expect(p.dx, inInclusiveRange(24 - 0.5, _w - 24 + 0.5));
        expect(p.dy, inInclusiveRange(120 + 24 - 0.5, _h - 360 - 24 + 0.5));
      }
      final ys = pts.map((p) => p.dy);
      expect((ys.reduce((a, b) => a < b ? a : b) + ys.reduce((a, b) => a > b ? a : b)) / 2, closeTo((144 + _h - 384) / 2, 1));
      final zoom = h.key.currentState!.controller.camera.zoom;
      expect(zoom, zoom.roundToDouble());
      expect(h.views.last.zoom, zoom);
    });

    testWidgets('its own padding and maxZoom; the start inset is on the right in RTL', (tester) async {
      final h = await _pump(tester, init: (h) {
        h.insets = const EdgeInsetsDirectional.only(start: 100);
        h.dir = TextDirection.rtl;
      });
      h.key.currentState!.fitPoints(const [_nurse, _patient], padding: const EdgeInsets.all(10), maxZoom: 12);
      await tester.pump();
      expect(h.key.currentState!.controller.camera.zoom, lessThanOrEqualTo(12));
      for (final p in [_nurse, _patient]) {
        expect(_screen(tester, h, p).dx, inInclusiveRange(10 - 0.5, _w - 100 - 10 + 0.5));
      }
    });

    testWidgets('one point: centred in the visible part at maxZoom (17 by default)', (tester) async {
      final h = await _pump(tester, init: (h) => h.insets = const EdgeInsetsDirectional.only(bottom: 400));
      h.key.currentState!.fitPoints(const [_patient]);
      await tester.pump();
      expect(h.key.currentState!.controller.camera.zoom, 17);
      final p = _screen(tester, h, _patient);
      expect(p.dx, closeTo(_w / 2, 0.5));
      expect(p.dy, closeTo((_h - 400) / 2, 0.5));
      h.key.currentState!.fitPoints(const [_nurse], maxZoom: 15);
      await tester.pump();
      expect(h.key.currentState!.controller.camera.zoom, 15);
    });

    testWidgets('animates with motion on, jumps under reduced motion or animate: false', (tester) async {
      final h = await _pump(tester, init: (h) => h.reduced = false);
      final cam = h.key.currentState!.controller;
      h.key.currentState!.fitPoints(const [_patient]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(cam.camera.zoom, inExclusiveRange(15, 17)); // on its way
      await tester.pumpAndSettle();
      expect(cam.camera.zoom, 17);
      h.key.currentState!.fitPoints(const [_nurse], maxZoom: 14, animate: false);
      expect(cam.camera.zoom, 14); // at once
      h.set(() => h.reduced = true);
      await tester.pump();
      h.key.currentState!.fitPoints(const [_patient]);
      expect(cam.camera.zoom, 17);
    });
  });

  group('polish', () {
    testWidgets('zoom controls: the locate button’s opaque raised surface, border and shadow; icons readable', (tester) async {
      for (final theme in [UiThemeName.maldives, UiThemeName.maldivesDark]) {
        await _pump(tester, init: (h) => h.theme = theme);
        final t = _t(tester);
        final boxes = find.descendant(of: find.byType(UiMapZoomButton), matching: find.byType(AnimatedContainer));
        expect(boxes, findsNWidgets(2));
        for (final e in boxes.evaluate()) {
          final d = (e.widget as AnimatedContainer).decoration! as BoxDecoration;
          expect(d.color, t.surfaceRaised, reason: '$theme');
          expect(d.color!.a, 1, reason: '$theme: opaque over the map');
          expect(d.boxShadow, t.shadow2);
          expect((d.border! as Border).top.color, t.border);
          final icon = tester.widget<UiIcon>(find.descendant(of: find.byWidget(e.widget), matching: find.byType(UiIcon)));
          expect(uiContrast(icon.color!, d.color!), greaterThanOrEqualTo(4.5), reason: '$theme');
        }
      }
    });

    testWidgets('zoom controls: 48dp targets on touch, the visible squares 44dp and 4dp apart', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await _pump(tester);
      final t = _t(tester);
      final hits = find.byType(UiMapZoomButton);
      for (final e in hits.evaluate()) {
        expect(tester.getSize(find.byWidget(e.widget)), const Size(48, 48));
      }
      final squares = find.descendant(of: hits, matching: find.byType(AnimatedContainer));
      final a = tester.getRect(squares.first), b = tester.getRect(squares.last);
      expect(a.width, t.sizeTouch);
      expect(b.top - a.bottom, closeTo(t.space1, 0.01));
      expect(a.left, closeTo(t.space2, 0.01)); // stays where it was
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      debugDefaultTargetPlatformOverride = null;
    });

    RenderParagraph label(WidgetTester tester, String text) => tester.renderObject<RenderParagraph>(find.text(text));

    testWidgets('a 40-character address fits its label on one line at 390 wide, nothing cut off', (tester) async {
      expect(_address.length, 40);
      await _pump(tester);
      final p = label(tester, _address);
      expect(p.didExceedMaxLines, isFalse);
      expect(tester.getSize(find.text(_address)).width, lessThanOrEqualTo(320));
      expect(tester.getSize(find.text(_address)).height, lessThan(24), reason: 'one line: 320 leaves room for it (the old 196px chip cut it)');
    });

    testWidgets('a longer label wraps to two lines before the ellipsis, up to min(320, width - 32)', (tester) async {
      const long = 'Lily Magu, Hiyaa Tower 4, flat 11-B, Hulhumale Phase 2, Male';
      final h = await _pump(tester, init: (h) => h.markers = const [UiMapMarker(id: 'p', lat: 4.1765, lng: 73.5083, label: long)]);
      expect(label(tester, long).didExceedMaxLines, isFalse);
      expect(tester.getSize(find.text(long)).height, greaterThan(24)); // two lines of 16
      const huge = 'Lily Magu, Hiyaa Tower 4, flat 11-B, Hulhumale Phase 2, Male, Kaafu Atoll, Republic of Maldives, by the beach';
      h.set(() => h.markers = const [UiMapMarker(id: 'p', lat: 4.1765, lng: 73.5083, label: huge)]);
      await tester.pump();
      expect(label(tester, huge).didExceedMaxLines, isTrue); // two lines, then the ellipsis
      expect(label(tester, huge).maxLines, 2);
    });

    testWidgets('a narrow map caps the label at its width less 32', (tester) async {
      const long = 'Lily Magu, Hiyaa Tower 4, flat 11-B, Hulhumale Phase 2, Male';
      await _pump(tester, init: (h) {
        h.width = 300;
        h.markers = const [UiMapMarker(id: 'p', lat: 4.1765, lng: 73.5083, label: long)];
      });
      final chip = find.ancestor(of: find.text(long), matching: find.byType(Container)).first;
      expect(tester.getSize(chip).width, lessThanOrEqualTo(268 + 0.01));
    });
  });

  testWidgets('golden: a route under the dot, a two-line label and the zoom controls (maldives, maldives dark)', (tester) async {
    await expectThemedGolden(
      tester,
      'map_routes',
      (context) => SizedBox(
        height: 300,
        child: UiMap(
          center: const UiLatLng(4.1762, 73.5100),
          zoom: 16,
          tileProvider: UiMapBlankTiles(),
          routes: const [UiMapRoute(id: 'r', points: [UiLatLng(4.1750, 73.5112), UiLatLng(4.1758, 73.5104), UiLatLng(4.1757, 73.5090), UiLatLng(4.1771, 73.5076)], semanticLabel: 'Route, 400 m')],
          userLocation: const UiMapUserLocation(4.1750, 73.5112),
          markers: const [UiMapMarker(id: 'p', lat: 4.1771, lng: 73.5076, label: 'Lily Magu, Hiyaa Tower 4, flat 11-B, Hulhumale Phase 2, Male', tone: UiStatus.danger)],
        ),
      ),
      themes: const [UiThemeName.maldives, UiThemeName.maldivesDark],
      width: 480,
    );
  });
}
