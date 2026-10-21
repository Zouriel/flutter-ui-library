import 'dart:convert' show base64Decode;

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../overlay/screens.dart';

/// 0.40.0: tiles that follow the theme, the "my location" button and the "you are here" dot.

const _c = UiLatLng(4.1755, 73.5093);
const _light = 'https://tiles.example/light/{z}/{x}/{y}{r}.png?key=KEY';
const _dark = 'https://tiles.example/dark/{z}/{x}/{y}{r}.png?key=KEY';
const _w = 390.0, _h = 800.0;

/// Tiles without the network that note every URL asked for, and the headers that went with it.
class _Recorder extends TileProvider {
  _Recorder();
  final urls = <String>[];
  final sentHeaders = <Map<String, String>>[];
  static final MemoryImage _pixel = MemoryImage(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='));

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    urls.add(getTileUrl(coordinates, options));
    sentHeaders.add({...headers});
    return _pixel;
  }
}

class _Host {
  final controller = UiThemeController(theme: UiThemeName.light);
  String? dark = _dark;
  int tileSize = 256;
  double zoomOffset = 0;
  bool locateControl = true, locating = false, off = false;
  int locates = 0;
  UiMapUserLocation? user;
  EdgeInsetsDirectional insets = EdgeInsetsDirectional.zero;
  TextDirection dir = TextDirection.ltr;
  Map<String, String>? headers;
  final tiles = _Recorder();
  final key = GlobalKey<UiMapState>();
  late StateSetter set;
}

Future<_Host> _pump(WidgetTester tester, {void Function(_Host h)? init}) async {
  tester.view.physicalSize = const Size(_w, _h) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final h = _Host();
  init?.call(h);
  await tester.pumpWidget(UiApp(
    controller: h.controller,
    home: StatefulBuilder(builder: (context, set) {
      h.set = set;
      return Directionality(
        textDirection: h.dir,
        child: SizedBox(
          width: _w,
          height: _h,
          child: UiMap(
            key: h.key,
            fill: true,
            center: _c,
            zoom: 15,
            tileUrl: _light,
            tileUrlDark: h.dark,
            tileSize: h.tileSize,
            zoomOffset: h.zoomOffset,
            tileHeaders: h.headers,
            tileProvider: h.tiles,
            locateControl: h.locateControl,
            locating: h.locating,
            locateOff: h.off,
            onLocate: () => h.locates++,
            userLocation: h.user,
            viewInsets: h.insets,
          ),
        ),
      );
    }),
  ));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  return h;
}

TileLayer _layer(WidgetTester tester) => tester.widget<TileLayer>(find.byType(TileLayer));
Finder get _button => find.byType(UiMapLocateButton);
Finder get _circle => find.descendant(of: _button, matching: find.byType(AnimatedContainer));

Future<void> _theme(WidgetTester tester, _Host h, UiThemeName name) async {
  h.controller.set(name);
  await tester.pumpAndSettle();
}

void main() {
  group('tiles that follow the theme', () {
    test('the dark tiles only on a dark theme that has them', () {
      expect(uiMapTileUrl(_light, _dark, false), _light);
      expect(uiMapTileUrl(_light, _dark, true), _dark);
      expect(uiMapTileUrl(_light, null, true), _light);
      expect(uiMapTileUrl(_light, '', true), _light);
    });

    testWidgets('swaps to tileUrlDark live on a dark theme, undimmed, in the same tile layer; and back', (tester) async {
      final h = await _pump(tester);
      final state = tester.state(find.byType(TileLayer));
      expect(_layer(tester).urlTemplate, _light);
      await _theme(tester, h, UiThemeName.dark);
      expect(_layer(tester).urlTemplate, _dark);
      expect(_layer(tester).tileBuilder, isNull); // not dimmed
      expect(tester.state(find.byType(TileLayer)), same(state)); // the same layer: no map rebuild
      expect(h.tiles.urls.last, contains('/dark/'));
      await _theme(tester, h, UiThemeName.maldives);
      expect(_layer(tester).urlTemplate, _light);
    });

    testWidgets('without tileUrlDark, a dark theme dims the light tiles as before', (tester) async {
      final h = await _pump(tester, init: (h) => h.dark = null);
      await _theme(tester, h, UiThemeName.maldivesDark);
      expect(_layer(tester).urlTemplate, _light);
      expect(_layer(tester).tileBuilder, isNotNull);
    });

    testWidgets('tileHeaders go with the dark tiles too (a Referer for a key restricted to a web origin)', (tester) async {
      final h = await _pump(tester, init: (h) => h.headers = {'Referer': 'https://staging.example/'});
      await _theme(tester, h, UiThemeName.dark);
      await tester.pump(const Duration(milliseconds: 100));
      final i = h.tiles.urls.lastIndexWhere((u) => u.contains('/dark/'));
      expect(i, isNot(-1));
      expect(h.tiles.sentHeaders[i]['Referer'], 'https://staging.example/');
      expect(_layer(tester).tileProvider.headers['Referer'], 'https://staging.example/');
      expect(h.tiles.urls.where((u) => u.contains('/light/')), isNotEmpty);
      final j = h.tiles.urls.indexWhere((u) => u.contains('/light/'));
      expect(h.tiles.sentHeaders[j]['Referer'], 'https://staging.example/');
    });

    testWidgets('a map that starts on a dark theme sends tileHeaders with its first (dark) tiles', (tester) async {
      final h = await _pump(tester, init: (h) {
        h.headers = {'Referer': 'https://staging.example/'};
        h.controller.set(UiThemeName.maldivesDark);
      });
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.tiles.urls, isNotEmpty);
      expect(h.tiles.urls.every((u) => u.contains('/dark/')), isTrue);
      expect(h.tiles.sentHeaders.every((m) => m['Referer'] == 'https://staging.example/'), isTrue);
    });

    testWidgets('fills {r} with @2x on a high-density screen and nothing at 1x', (tester) async {
      tester.view.devicePixelRatio = 2;
      final h = await _pump(tester);
      expect(h.tiles.getTileUrl(const TileCoordinates(1, 2, 15), _layer(tester)), 'https://tiles.example/light/15/1/2@2x.png?key=KEY');
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(_w, _h);
      await tester.pump();
      expect(h.tiles.getTileUrl(const TileCoordinates(1, 2, 15), _layer(tester)), 'https://tiles.example/light/15/1/2.png?key=KEY');
    });

    testWidgets('takes 512 px tiles with a zoom offset (MapTiler raster)', (tester) async {
      await _pump(tester, init: (h) => h
        ..tileSize = 512
        ..zoomOffset = -1);
      expect([_layer(tester).tileDimension, _layer(tester).zoomOffset], [512, -1]);
    });
  });

  group('"my location" button', () {
    testWidgets('is there only with locateControl, named from the strings, and calls onLocate', (tester) async {
      final handle = tester.ensureSemantics();
      final h = await _pump(tester, init: (h) => h.locateControl = false);
      expect(_button, findsNothing);
      h.set(() => h.locateControl = true);
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('Show my location'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is UiIcon && w.icon == HugeIcons.strokeRoundedGps01), findsOneWidget);
      await tester.tap(_button);
      expect(h.locates, 1);
      handle.dispose();
    });

    testWidgets('while locating: a spinner, and taps do nothing', (tester) async {
      final h = await _pump(tester, init: (h) => h.locating = true);
      expect(find.descendant(of: _button, matching: find.byType(UiSpinner)), findsOneWidget);
      await tester.tap(_button);
      expect(h.locates, 0);
    });

    testWidgets('location off: struck-through icon, "Location is off" as its tooltip (read out too), still pressable', (tester) async {
      final handle = tester.ensureSemantics();
      final h = await _pump(tester, init: (h) => h.off = true);
      expect(find.byWidgetPredicate((w) => w is UiIcon && w.icon == HugeIcons.strokeRoundedGpsOff01), findsOneWidget);
      // Read out with the name: the tooltip is part of the button's node.
      expect(tester.getSemantics(find.bySemanticsLabel('Show my location')).tooltip, 'Location is off');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(_button));
      await tester.pumpAndSettle();
      expect(find.text('Location is off'), findsOneWidget);
      await mouse.removePointer();
      await tester.tap(_button);
      expect(h.locates, 1);
      handle.dispose();
    });

    testWidgets('sits at the bottom-end of the visible part and follows the insets (above a bottom sheet); at the end in RTL', (tester) async {
      final h = await _pump(tester, init: (h) => h.insets = const EdgeInsetsDirectional.only(bottom: 300, end: 10));
      await tester.pumpAndSettle();
      final t = UiTheme.of(tester.element(_button)).tokens;
      // The drawn circle (the hit area around it is padded on touch screens).
      var r = tester.getRect(_circle);
      expect(r.bottom, _h - 300 - t.space8);
      expect(r.right, _w - 10 - t.space3);
      expect(r.width, r.height);
      h.set(() {
        h.insets = const EdgeInsetsDirectional.only(bottom: 420, end: 10); // the sheet rose
        h.dir = TextDirection.rtl;
      });
      await tester.pumpAndSettle();
      r = tester.getRect(_circle);
      expect(r.bottom, _h - 420 - t.space8);
      expect(r.left, 10 + t.space3);
    });

    // 0.40.1: the Dhirumi apps' tap-target check found the 44dp circle was also its whole hit area.
    testWidgets('on touch: a 48dp hit area around the 44dp circle, which stays in place; the zoom buttons meet 48dp too', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final handle = tester.ensureSemantics();
      final h = await _pump(tester, init: (h) => h.insets = const EdgeInsetsDirectional.only(bottom: 300));
      await tester.pumpAndSettle();
      final t = UiTheme.of(tester.element(_button)).tokens;
      final circle = tester.getRect(_circle);
      expect(circle.width, t.sizeTouch);
      expect(circle.bottom, _h - 300 - t.space8);
      expect(circle.right, _w - t.space3);
      final hit = tester.getRect(_button);
      expect(hit.size, const Size(48, 48));
      expect(hit.center, circle.center);
      // A tap just outside the circle, inside the padded area, still counts.
      await tester.tapAt(Offset(hit.right - 1, hit.center.dy));
      expect(h.locates, 1);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('with a mouse: the 38px circle is the whole button', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await _pump(tester);
      final t = UiTheme.of(tester.element(_button)).tokens;
      expect(tester.getRect(_circle).width, t.sizeLg);
      expect(tester.getRect(_button), tester.getRect(_circle));
      expect(tester.getRect(_circle).right, _w - t.space3);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  // 0.40.1: in Dhivehi the English credits came out right to left, with the © signs misplaced.
  group('attribution', () {
    testWidgets('is laid out LTR in an RTL map, in the mirrored (bottom-left) corner', (tester) async {
      final h = await _pump(tester, init: (h) => h.dir = TextDirection.rtl);
      await tester.pumpAndSettle();
      final text = find.text('© OpenStreetMap contributors');
      final para = tester.renderObject<RenderParagraph>(text);
      expect(para.textDirection, TextDirection.ltr);
      expect(tester.getRect(text).left, lessThan(_w / 2));
      h.set(() => h.dir = TextDirection.ltr);
      await tester.pumpAndSettle();
      expect(tester.renderObject<RenderParagraph>(text).textDirection, TextDirection.ltr);
      expect(tester.getRect(text).right, greaterThan(_w / 2));
    });
  });

  group('"you are here" dot', () {
    test('sizes the accuracy halo in metres at the zoom, clamped (the same sums as the web)', () {
      expect(uiMapAccuracyPx(50, 0, 16), 42);
      expect(uiMapAccuracyPx(50, 0, 17), 84);
      expect(uiMapAccuracyPx(1, 0, 10), uiMapAccuracyMin);
      expect(uiMapAccuracyPx(5000, 0, 18), uiMapAccuracyMax);
      expect(uiMapAccuracyPx(null, 0, 18), 0);
      expect(uiMapAccuracyPx(0, 0, 18), 0);
    });

    testWidgets('a ringed dot over a halo on its point, named "Your location", following the zoom', (tester) async {
      final handle = tester.ensureSemantics();
      final h = await _pump(tester, init: (h) => h.user = const UiMapUserLocation(4.1755, 73.5093, accuracy: 40));
      expect(find.semantics.byLabel('Your location'), findsOneWidget);
      final dot = tester.widget<UiMapUserDot>(find.byType(UiMapUserDot));
      expect(dot.halo, uiMapAccuracyPx(40, _c.lat, 15));
      // On its point.
      final cam = h.key.currentState!.controller.camera;
      final p = tester.getTopLeft(find.byType(UiMap)) + cam.latLngToScreenOffset(const LatLng(4.1755, 73.5093));
      expect((tester.getCenter(find.byType(UiMapUserDot)) - p).distance, lessThan(1));
      // The colours are the location tokens.
      final t = UiTheme.of(tester.element(find.byType(UiMapUserDot))).tokens;
      final inner = tester.widgetList<Container>(find.descendant(of: find.byType(UiMapUserDot), matching: find.byType(Container))).last;
      final deco = inner.decoration! as BoxDecoration;
      expect([deco.color, deco.border!.top.color, deco.border!.top.width], [t.location, t.locationRing, 3]);
      // Zooming in grows the halo.
      h.key.currentState!.controller.move(const LatLng(4.1755, 73.5093), 17);
      await tester.pump();
      expect(tester.widget<UiMapUserDot>(find.byType(UiMapUserDot)).halo, uiMapAccuracyPx(40, _c.lat, 17));
      h.set(() => h.user = null);
      await tester.pump();
      expect(find.byType(UiMapUserDot), findsNothing);
      handle.dispose();
    });

    testWidgets('flyTo puts a point in the middle of the visible part (between the insets)', (tester) async {
      final h = await _pump(tester, init: (h) => h.insets = const EdgeInsetsDirectional.only(bottom: 400));
      const there = UiLatLng(4.19, 73.53);
      h.key.currentState!.flyTo(there, zoom: 16);
      await tester.pump();
      final cam = h.key.currentState!.controller.camera;
      final p = cam.latLngToScreenOffset(const LatLng(4.19, 73.53));
      expect(cam.zoom, 16);
      expect(p.dx, closeTo(_w / 2, 1));
      expect(p.dy, closeTo((_h - 400) / 2, 1));
    });
  });

  testWidgets('golden: the locate button just above a bottom sheet, and the dot with its halo (Maldives light and dark)', (tester) async {
    debugDisableShadows = false;
    await pumpScreens(tester, (context) => Stack(children: [
          Positioned.fill(
            child: UiMap(
              fill: true,
              center: _c,
              zoom: 16,
              tileProvider: UiMapBlankTiles(),
              userLocation: const UiMapUserLocation(4.1755, 73.5093, accuracy: 60),
              locateControl: true,
              viewInsets: const EdgeInsetsDirectional.only(bottom: 224),
            ),
          ),
          UiBottomSheet(snaps: const [0.35], snap: 0, title: 'Find a nurse', closable: false, child: const UiText('Where should the nurse come?')),
        ]), themes: const [UiThemeName.maldives, UiThemeName.maldivesDark]);
    await expectScreensGolden(tester, 'map_locate');
    debugDisableShadows = true;
  });
}
