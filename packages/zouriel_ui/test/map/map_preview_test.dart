import 'dart:ui' show GestureSettings, PointerDeviceKind, Tristate;

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// 0.43.0: the preview map (a still picture that is one button), the selected marker, and the
/// marker label modes.

const _c = UiLatLng(4.1755, 73.5093);
const _w = 390.0, _h = 844.0;

const _markers = [
  UiMapMarker(id: 'a', lat: 4.1762, lng: 73.5105, label: 'Aminath Hassan, RN', tone: UiStatus.success),
  UiMapMarker(id: 'b', lat: 4.1738, lng: 73.5072, label: 'Ibrahim Rasheed, RN'),
  UiMapMarker(id: 'c', lat: 4.1781, lng: 73.5068, label: 'Busy', tone: UiStatus.warning, semanticLabel: 'Busy nurse'),
];

class _Host {
  bool preview = true;
  String? selected;
  UiMapMarkerLabels labels = UiMapMarkerLabels.all;
  TextDirection dir = TextDirection.ltr;
  UiStrings strings = const UiStrings();
  int presses = 0, attributionTaps = 0;
  final tapped = <String>[];
  late StateSetter set;
  final key = GlobalKey<UiMapState>();
}

Widget _map(_Host h) => UiMap(
      key: h.key,
      center: _c,
      zoom: 15,
      tileProvider: UiMapBlankTiles(),
      markers: _markers,
      onMarkerSelected: (m) => h.tapped.add(m.id),
      locateControl: true,
      onLocate: () {},
      controls: [UiMapControl(id: 'fit', icon: HugeIcons.strokeRoundedCenterFocus, semanticLabel: 'Show both')],
      preview: h.preview,
      onPreviewPressed: () => h.presses++,
      onAttributionTap: () => h.attributionTaps++,
      selectedMarkerId: h.selected,
      markerLabels: h.labels,
    );

Widget _app(_Host h, Widget Function() child) => StatefulBuilder(builder: (context, set) {
      h.set = set;
      return UiApp(
        config: UiConfig(strings: h.strings),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Directionality(textDirection: h.dir, child: child()),
          ),
        ),
      );
    });

/// A 390 x 300 map on its own.
Future<_Host> _pump(WidgetTester tester, {void Function(_Host h)? init}) async {
  final h = _Host();
  init?.call(h);
  tester.view.physicalSize = const Size(_w, _h) * tester.view.devicePixelRatio;
  tester.view.gestureSettings = GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(h, () => Align(alignment: Alignment.topLeft, child: SizedBox(width: _w, height: 300, child: _map(h)))));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  return h;
}

LatLngish _center(_Host h) {
  final c = h.key.currentState!.controller.camera;
  return (c.center.latitude, c.center.longitude, c.zoom);
}

typedef LatLngish = (double, double, double);

/// The marker dots (16px, or 22px when selected), in paint order.
List<Rect> _dots(WidgetTester tester, double size) => tester
    .widgetList<Container>(find.descendant(of: find.byType(UiMap), matching: find.byWidgetPredicate((w) => w is Container && w.constraints == BoxConstraints.tightFor(width: size, height: size))))
    .map((w) => tester.getRect(find.byWidget(w)))
    .toList();

void main() {
  group('preview', () {
    testWidgets('a drag, a double tap and the wheel leave the map where it is; no controls; markers not selectable', (tester) async {
      final h = await _pump(tester);
      final before = _center(h);
      await tester.drag(find.byType(UiMap), const Offset(-120, -80));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_center(h), before);
      // Double tap (a zoom on the full map).
      await tester.tapAt(const Offset(195, 150));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(const Offset(195, 150));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_center(h), before);
      // The wheel.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(195, 150));
      await tester.sendEventToBinding(const PointerScrollEvent(position: Offset(195, 150), scrollDelta: Offset(0, -200)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_center(h), before);
      await mouse.removePointer();
      // Arrow keys (they pan the full map once it has focus).
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_center(h), before);
      // No zoom, locate or app buttons on a picture.
      expect(find.byType(UiMapZoomButton), findsNothing);
      expect(find.byType(UiMapLocateButton), findsNothing);
      expect(find.byType(UiMapControlButton), findsNothing);
      // Markers are drawn, but a tap on one is the preview's tap, not a selection.
      expect(_dots(tester, 16), hasLength(3));
      await tester.tapAt(_dots(tester, 16).first.center);
      await tester.pump(const Duration(milliseconds: 400));
      expect(h.tapped, isEmpty);
    });

    testWidgets('one press per tap, per Enter and per Space; read out as one button named Open map', (tester) async {
      final handle = tester.ensureSemantics();
      final h = await _pump(tester);
      await tester.tapAt(const Offset(195, 150));
      await tester.pump(const Duration(milliseconds: 400));
      expect(h.presses, 1);
      final node = tester.getSemantics(find.bySemanticsLabel('Open map'));
      final flags = node.getSemanticsData().flagsCollection;
      expect(flags.isButton, isTrue);
      expect(flags.isFocused, isNot(Tristate.none), reason: 'focusable');
      // The markers and the map's own surface are not read out separately.
      expect(find.bySemanticsLabel('Aminath Hassan, RN'), findsNothing);
      expect(find.bySemanticsLabel('Busy nurse'), findsNothing);
      expect(find.bySemanticsLabel('Show my location'), findsNothing);
      // The preview is the map's only focus stop (the map surface takes none).
      final stops = FocusManager.instance.rootScope.traversalDescendants
          .where((n) => n.context != null && n.canRequestFocus && !n.skipTraversal && find.descendant(of: find.byType(UiMap), matching: find.byWidget(n.context!.widget)).evaluate().isNotEmpty)
          .toList();
      expect(stops, hasLength(1));
      // The credits show (the licence) but a tap on them is the preview's.
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      await tester.tap(find.text('© OpenStreetMap contributors'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(h.attributionTaps, 0);
      expect(h.presses, 2);
      // Keyboard: Tab reaches the preview, Enter and Space each press it once.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(h.presses, 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(h.presses, 4);
      handle.dispose();
    });

    testWidgets('the name comes from UiStrings.mapOpen, so apps can translate it', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, init: (h) => h.strings = const UiStrings(mapOpen: 'OpenMapDV'));
      expect(find.bySemanticsLabel('OpenMapDV'), findsOneWidget);
      expect(find.bySemanticsLabel('Open map'), findsNothing);
      handle.dispose();
    });

    testWidgets('the expand badge sits in the top-end corner: top-right, top-left in RTL', (tester) async {
      final h = await _pump(tester);
      final t = UiTheme.of(tester.element(find.byType(UiMap))).tokens;
      var badge = tester.getRect(find.byType(UiMapPreviewBadge));
      expect(badge.size, Size(t.sizeMd, t.sizeMd));
      expect(badge.top, t.space2);
      expect(badge.right, _w - t.space2);
      h.set(() => h.dir = TextDirection.rtl);
      await tester.pump();
      badge = tester.getRect(find.byType(UiMapPreviewBadge));
      expect(badge.left, t.space2);
      expect(badge.top, t.space2);
    });

    testWidgets('a vertical drag or the wheel over the preview scrolls the list it is in', (tester) async {
      final h = _Host();
      tester.view.physicalSize = const Size(_w, _h) * tester.view.devicePixelRatio;
      // A phone's touch slop, as the mistake log asks.
      tester.view.gestureSettings = GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
      addTearDown(tester.view.reset);
      final list = ScrollController();
      addTearDown(list.dispose);
      await tester.pumpWidget(_app(h, () => ListView(controller: list, children: [
            const SizedBox(height: 100),
            SizedBox(height: 260, child: _map(h)),
            const SizedBox(height: 2000),
          ])));
      await tester.pump(const Duration(milliseconds: 100));
      final mapAt = tester.getCenter(find.byType(UiMap));
      final before = _center(h);
      await tester.dragFrom(mapAt, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(list.offset, greaterThan(150));
      expect(_center(h), before);
      expect(h.presses, 0);
      // The mouse wheel over the map scrolls the page too.
      final offset = list.offset;
      final at = tester.getCenter(find.byType(UiMap));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: at);
      await tester.sendEventToBinding(PointerScrollEvent(position: at, scrollDelta: const Offset(0, 120)));
      await tester.pumpAndSettle();
      expect(list.offset, greaterThan(offset + 100));
      await mouse.removePointer();
      // The full map, in the same place, takes the drag itself.
      h.set(() => h.preview = false);
      await tester.pump(const Duration(milliseconds: 100));
      list.jumpTo(0);
      await tester.pump(const Duration(milliseconds: 100));
      final full = _center(h);
      await tester.dragFrom(tester.getCenter(find.byType(UiMap)), const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(_center(h).$2, isNot(closeTo(full.$2, 1e-6)));
    });

    testWidgets('turning preview off gives the full map back: drags pan, the controls return, the button goes', (tester) async {
      final handle = tester.ensureSemantics();
      final h = await _pump(tester);
      final state = h.key.currentState;
      h.set(() => h.preview = false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.key.currentState, same(state));
      expect(find.byType(UiMapPreviewButton), findsNothing);
      expect(find.bySemanticsLabel('Open map'), findsNothing);
      expect(find.byType(UiMapZoomButton), findsNWidgets(2));
      expect(find.byType(UiMapLocateButton), findsOneWidget);
      expect(find.byType(UiMapControlButton), findsOneWidget);
      final before = _center(h);
      await tester.drag(find.byType(UiMap), const Offset(-120, -80));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_center(h).$2, isNot(closeTo(before.$2, 1e-6)));
      await tester.tapAt(_dots(tester, 16).first.center);
      await tester.pump(const Duration(milliseconds: 400));
      expect(h.tapped, isNotEmpty);
      expect(h.presses, 0);
      // And back: still again.
      h.set(() => h.preview = true);
      await tester.pump(const Duration(milliseconds: 100));
      final still = _center(h);
      await tester.drag(find.byType(UiMap), const Offset(-120, -80));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_center(h), still);
      handle.dispose();
    });

    testWidgets('center, zoom and fitPoints still place a preview, at once (no animation)', (tester) async {
      // Full motion: the full map would animate a fit.
      final h = _Host();
      tester.view.physicalSize = const Size(_w, _h) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UiApp(home: Align(alignment: Alignment.topLeft, child: SizedBox(width: _w, height: 300, child: _map(h)))));
      await tester.pump(const Duration(milliseconds: 100));
      h.key.currentState!.fitPoints(const [UiLatLng(4.20, 73.50), UiLatLng(4.16, 73.53)]);
      await tester.pump();
      final c = h.key.currentState!.controller.camera;
      expect(c.center.latitude, closeTo(4.18, 0.01));
      expect(c.center.longitude, closeTo(73.515, 0.01));
      expect(c.zoom, lessThan(15));
      expect(c.zoom, c.zoom.roundToDouble());
    });
  });

  group('selected marker', () {
    testWidgets('drawn bigger (22px) with a white ring and a halo in its tone, on top of the others, read out as selected', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, init: (h) {
        h.preview = false;
        h.selected = 'a';
      });
      final t = UiTheme.of(tester.element(find.byType(UiMap))).tokens;
      expect(_dots(tester, uiMapSelectedDot), hasLength(1));
      expect(_dots(tester, 16), hasLength(2));
      final dot = tester.widget<Container>(find.byWidgetPredicate((w) => w is Container && w.constraints == const BoxConstraints.tightFor(width: uiMapSelectedDot, height: uiMapSelectedDot)));
      final deco = dot.decoration! as BoxDecoration;
      expect((deco.border! as Border).top.color, t.locationRing);
      expect(deco.color, t.success);
      expect(deco.boxShadow!.any((s) => s.spreadRadius == 6 && s.color == t.success.withValues(alpha: 0.30)), isTrue);
      // On top: its marker is painted after the others (later in the marker layer's stack).
      final order = find.descendant(of: find.byType(UiMap), matching: find.byWidgetPredicate((w) => w is Container && (w.constraints == const BoxConstraints.tightFor(width: 16, height: 16) || w.constraints == const BoxConstraints.tightFor(width: uiMapSelectedDot, height: uiMapSelectedDot))));
      final sizes = tester.widgetList<Container>(order).map((w) => w.constraints!.maxWidth).toList();
      expect(sizes, [16, 16, uiMapSelectedDot], reason: 'the selected marker comes last (on top)');
      Tristate selected(String l) => tester.getSemantics(find.bySemanticsLabel(l)).getSemanticsData().flagsCollection.isSelected;
      expect(selected('Aminath Hassan, RN'), Tristate.isTrue);
      expect(selected('Ibrahim Rasheed, RN'), Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('changing it moves the selection on the same map, without rebuilding or moving it', (tester) async {
      final h = await _pump(tester, init: (h) {
        h.preview = false;
        h.selected = 'a';
      });
      final state = h.key.currentState;
      final controller = state!.controller;
      final before = _center(h);
      // Where b is on screen (the map sits at the top-left).
      final b = controller.camera.latLngToScreenOffset(LatLng(_markers[1].lat, _markers[1].lng));
      h.set(() => h.selected = 'b');
      await tester.pump();
      expect(h.key.currentState, same(state));
      expect(h.key.currentState!.controller, same(controller));
      expect(_center(h), before);
      expect(_dots(tester, uiMapSelectedDot), hasLength(1));
      // The selected dot is now b's.
      expect(_dots(tester, 16), hasLength(2));
      final sel = _dots(tester, uiMapSelectedDot).single.center;
      expect(sel.dx, closeTo(b.dx, 0.5));
      expect(sel.dy, closeTo(b.dy, 0.5));
      h.set(() => h.selected = null);
      await tester.pump();
      expect(_dots(tester, uiMapSelectedDot), isEmpty);
      expect(_dots(tester, 16), hasLength(3));
    });
  });

  group('marker labels', () {
    Future<void> labels(WidgetTester tester, UiMapMarkerLabels mode, {required List<String> shown}) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, init: (h) {
        h.preview = false;
        h.selected = 'b';
        h.labels = mode;
      });
      for (final l in ['Aminath Hassan, RN', 'Ibrahim Rasheed, RN', 'Busy']) {
        expect(find.text(l), shown.contains(l) ? findsOneWidget : findsNothing, reason: '$mode: $l');
      }
      // Every marker keeps its name, label shown or not.
      for (final l in ['Aminath Hassan, RN', 'Ibrahim Rasheed, RN', 'Busy nurse']) {
        expect(find.bySemanticsLabel(l), findsOneWidget, reason: '$mode: the name $l');
      }
      handle.dispose();
    }

    testWidgets('all (the default) shows every label', (tester) => labels(tester, UiMapMarkerLabels.all, shown: ['Aminath Hassan, RN', 'Ibrahim Rasheed, RN', 'Busy']));
    testWidgets('selected shows only the selected marker\'s label', (tester) => labels(tester, UiMapMarkerLabels.selected, shown: ['Ibrahim Rasheed, RN']));
    testWidgets('none shows no label', (tester) => labels(tester, UiMapMarkerLabels.none, shown: const []));

    testWidgets('selected with nothing selected shows no label', (tester) async {
      await _pump(tester, init: (h) {
        h.preview = false;
        h.labels = UiMapMarkerLabels.selected;
      });
      expect(find.text('Busy'), findsNothing);
      expect(find.text('Aminath Hassan, RN'), findsNothing);
    });
  });

  testWidgets('golden: a preview (expand badge, no controls, no labels) over a map with a selected marker (Winter Dark, Winter Light)', (tester) async {
    await expectThemedGolden(
      tester,
      'map_preview',
      (context) => Column(spacing: 12, children: [
        SizedBox(
          height: 150,
          child: UiMap(center: const UiLatLng(4.1760, 73.5087), zoom: 15, tileProvider: UiMapBlankTiles(), markers: _markers, markerLabels: UiMapMarkerLabels.none, preview: true, onPreviewPressed: () {}),
        ),
        Expanded(
          child: UiMap(center: const UiLatLng(4.1760, 73.5087), zoom: 16, tileProvider: UiMapBlankTiles(), markers: _markers, selectedMarkerId: 'b', markerLabels: UiMapMarkerLabels.selected),
        ),
      ]),
      height: 460,
    );
  });
}
