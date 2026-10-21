import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

const _markers = [
  UiMapMarker(id: 'n1', lat: 4.1762, lng: 73.5105, label: 'Aminath Hassan, RN', tone: UiStatus.success),
  UiMapMarker(id: 'n2', lat: 4.1738, lng: 73.5072, label: 'Ibrahim Rasheed, RN'),
  UiMapMarker(id: 'secret-id-7', lat: 4.1750, lng: 73.5080, semanticLabel: 'Clinic'),
];

class _Host {
  final picked = <String>[];
  final views = <UiMapView>[];
  UiLatLng? pin;
  late StateSetter set;
}

Future<_Host> _pump(WidgetTester tester, {bool pinMode = false, bool pinDraggable = true, UiConfig config = const UiConfig(), UiThemeName theme = UiThemeName.light, TextDirection dir = TextDirection.ltr}) async {
  tester.view.physicalSize = const Size(390, 500) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final h = _Host();
  await tester.pumpWidget(UiApp(
    theme: theme,
    config: config,
    home: Directionality(
      textDirection: dir,
      child: StatefulBuilder(builder: (context, set) {
        h.set = set;
        return SizedBox(
          width: 390,
          height: 400,
          child: UiMap(
            zoom: 15,
            markers: _markers,
            tileProvider: UiMapBlankTiles(), // exported by map.dart: no flutter_map dependency needed
            pinMode: pinMode,
            pinDraggable: pinDraggable,
            pin: h.pin,
            onPinChanged: (p) => set(() => h.pin = p),
            onMarkerSelected: (m) => h.picked.add(m.id),
            onCenterChanged: h.views.add,
          ),
        );
      }),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
  return h;
}

void main() {
  testWidgets('markers show their labels and report a tap', (tester) async {
    final h = await _pump(tester);
    expect(find.text('Aminath Hassan, RN'), findsOneWidget);
    await tester.tap(find.text('Ibrahim Rasheed, RN'));
    await tester.pump();
    expect(h.picked, ['n2']);
  });

  testWidgets('markers are named buttons for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(find.bySemanticsLabel('Aminath Hassan, RN'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('pin mode: a tap places the pin, the screen reader action places it at the centre', (tester) async {
    final handle = tester.ensureSemantics();
    final h = await _pump(tester, pinMode: true);
    expect(h.pin, isNull);
    await tester.tapAt(const Offset(60, 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.pin, isNotNull);
    expect(find.bySemanticsLabel('Chosen location'), findsOneWidget);
    h.set(() => h.pin = null);
    await tester.pump();
    final node = tester.getSemantics(find.byType(UiMap));
    final action = node.getSemanticsData().customSemanticsActionIds!.first;
    node.owner!.performAction(node.id, SemanticsAction.customAction, action);
    await tester.pump();
    expect(h.pin!.lat, closeTo(4.1755, 1e-6));
    expect(h.pin!.lng, closeTo(73.5093, 1e-6));
    handle.dispose();
  });

  testWidgets('zoom buttons at the inline start (swapped in RTL) and they report the new view', (tester) async {
    var h = await _pump(tester);
    expect(tester.getCenter(find.byType(UiMapZoomButton).first).dx, lessThan(100));
    await tester.tap(find.byType(UiMapZoomButton).first);
    await tester.pump();
    expect(h.views.last.zoom, 16);
    await tester.pumpWidget(const SizedBox());
    h = await _pump(tester, dir: TextDirection.rtl);
    expect(tester.getCenter(find.byType(UiMapZoomButton).first).dx, greaterThan(290));
    expect(tester.getCenter(find.text('© OpenStreetMap contributors')).dx, lessThan(195), reason: 'attribution at the inline end: the left in RTL');
  });

  testWidgets('tiles are dimmed on a dark theme only', (tester) async {
    await _pump(tester);
    expect(find.byType(ColorFiltered), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, theme: UiThemeName.maldivesDark);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ColorFiltered), findsWidgets);
  });

  testWidgets('tile headers keep the User-Agent and work with an offline provider', (tester) async {
    final tiles = UiMapBlankTiles();
    await tester.pumpWidget(UiApp(
      home: SizedBox(
        width: 390,
        height: 400,
        child: UiMap(
          tileProvider: tiles,
          tileHeaders: const {'Referer': 'https://example.test/'},
          userAgentPackageName: 'mv.example.app',
        ),
      ),
    ));
    await tester.pump();
    expect(tiles.headers, containsPair('Referer', 'https://example.test/'));
    expect(tiles.headers, containsPair('User-Agent', 'flutter_map (mv.example.app)'));
  });

  testWidgets('Enter on the focused map in pin mode drops the pin at the centre', (tester) async {
    final h = await _pump(tester, pinMode: true);
    await tester.tapAt(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 400));
    h.set(() => h.pin = null);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(h.pin, isNotNull);
  });

  testWidgets('every tap target is named and 48dp, in pin mode too; markers use semanticLabel, never the id', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, pinMode: true);
    await tester.tapAt(const Offset(60, 300));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    expect(find.bySemanticsLabel('Clinic'), findsOneWidget);
    expect(find.bySemanticsLabel('secret-id-7'), findsNothing);
    handle.dispose();
  });

  testWidgets('a fixed pin (pinDraggable false) shows the place, named, and does not move', (tester) async {
    final handle = tester.ensureSemantics();
    final h = await _pump(tester, pinDraggable: false);
    h.set(() => h.pin = const UiLatLng(4.1755, 73.5093));
    await tester.pump();
    expect(find.bySemanticsLabel('Chosen location'), findsOneWidget);
    final before = h.pin;
    await tester.dragFrom(tester.getCenter(find.bySemanticsLabel('Chosen location')), const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.pin, before);
    handle.dispose();
  });

  testWidgets('zoom and pin words come from UiStrings', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, pinMode: true, config: const UiConfig(strings: UiStrings(zoomIn: 'ބޮޑުކުރޭ', placePinAtCentre: 'މެދަށް')));
    expect(find.bySemanticsLabel('ބޮޑުކުރޭ'), findsOneWidget);
    expect(find.bySemanticsLabel('Zoom out'), findsOneWidget);
    final node = tester.getSemantics(find.byType(UiMap));
    expect(node.getSemanticsData().customSemanticsActionIds, isNotEmpty);
    handle.dispose();
  });
}
