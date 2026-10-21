import 'package:flutter/rendering.dart' show RenderCustomPaint;
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// 0.39.0: the pulse ("searching" rings), view insets and fill, for a full-screen map page.

const _c = UiLatLng(4.1755, 73.5093);
const _w = 390.0, _h = 800.0;

class _Host {
  UiMapPulse? pulse = const UiMapPulse(lat: 4.1755, lng: 73.5093, tone: UiStatus.success);
  EdgeInsetsDirectional insets = EdgeInsetsDirectional.zero;
  UiLatLng center = _c;
  UiLatLng? pin;
  final views = <UiMapView>[];
  bool reduced = false;
  TextDirection dir = TextDirection.ltr;
  late StateSetter set;
  final key = GlobalKey<UiMapState>();
}

Future<_Host> _pump(WidgetTester tester, {void Function(_Host h)? init}) async {
  tester.view.physicalSize = const Size(_w, _h) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final h = _Host();
  init?.call(h);
  await tester.pumpWidget(UiApp(
    home: StatefulBuilder(builder: (context, set) {
      h.set = set;
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: h.reduced),
        child: Directionality(
          textDirection: h.dir,
          child: SizedBox(
            width: _w,
            height: _h,
            child: UiMap(
              key: h.key,
              fill: true,
              center: h.center,
              zoom: 15,
              tileProvider: UiMapBlankTiles(),
              pulse: h.pulse,
              viewInsets: h.insets,
              pinMode: true,
              pin: h.pin,
              onPinChanged: (p) => set(() => h.pin = p),
              onCenterChanged: h.views.add,
            ),
          ),
        ),
      );
    }),
  ));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  return h;
}

/// Where a point is on screen, from the map's camera.
Offset _screen(WidgetTester tester, _Host h, UiLatLng p) {
  final cam = h.key.currentState!.controller.camera;
  return tester.getTopLeft(find.byType(UiMap)) + cam.latLngToScreenOffset(LatLng(p.lat, p.lng));
}

bool _running(WidgetTester tester) => (tester.state(find.byType(UiMapPulseRings)) as dynamic).running as bool;

/// The pulse's painter, to read what it draws.
Finder get _rings => find.descendant(of: find.byType(UiMapPulseRings), matching: find.byType(CustomPaint));

void main() {
  group('pulse', () {
    testWidgets('three staggered rings animate while active, hidden from screen readers and hits', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      expect(find.byType(UiMapPulseRings), findsOneWidget);
      expect(_running(tester), isTrue, reason: 'the loop runs');
      // Mid-loop, all three rings are on screen: six circles (a fill and an edge each).
      await tester.pump(const Duration(milliseconds: 2000));
      expect(_rings, paints..circle()..circle()..circle()..circle()..circle()..circle());
      // Its rings grow: the first ring's edge is bigger 400ms later.
      double first() {
        final p = tester.renderObject<RenderCustomPaint>(_rings).painter!;
        var r = 0.0;
        p.paint(_RecordingCanvas((radius) => r = r == 0 ? radius : r), const Size(120, 120));
        return r;
      }

      await tester.pump(const Duration(milliseconds: 100));
      final a = first();
      await tester.pump(const Duration(milliseconds: 300));
      expect(first(), isNot(a));
      expect(find.descendant(of: find.byType(UiMapPulseRings), matching: find.byType(IgnorePointer)), findsNothing);
      expect(find.ancestor(of: find.byType(UiMapPulseRings), matching: find.byType(IgnorePointer)), findsWidgets);
      expect(find.ancestor(of: find.byType(UiMapPulseRings), matching: find.byType(ExcludeSemantics)), findsWidgets);
      handle.dispose();
    });

    testWidgets('inactive or null: nothing drawn and nothing running; active again brings it back', (tester) async {
      final h = await _pump(tester);
      var state = tester.state(find.byType(UiMapPulseRings));
      h.set(() => h.pulse = const UiMapPulse(lat: 4.1755, lng: 73.5093, active: false));
      await tester.pump();
      expect(find.byType(UiMapPulseRings), findsNothing);
      expect([state.mounted, (state as dynamic).running], [false, false], reason: 'its controller is disposed');
      h.set(() => h.pulse = const UiMapPulse(lat: 4.1755, lng: 73.5093));
      await tester.pump();
      expect(find.byType(UiMapPulseRings), findsOneWidget);
      expect(_running(tester), isTrue);
      state = tester.state(find.byType(UiMapPulseRings));
      h.set(() => h.pulse = null);
      await tester.pump();
      expect(find.byType(UiMapPulseRings), findsNothing);
      expect([state.mounted, (state as dynamic).running], [false, false]);
      // With the tiles settled, nothing animates any more.
      await tester.pumpAndSettle();
    });

    testWidgets('leaves nothing running once the map is gone', (tester) async {
      await _pump(tester);
      final state = tester.state(find.byType(UiMapPulseRings));
      expect(_running(tester), isTrue);
      await tester.pumpWidget(const SizedBox());
      expect([state.mounted, (state as dynamic).running], [false, false]);
      expect(tester.binding.transientCallbackCount, 0, reason: 'no ticker left behind');
    });

    testWidgets('reduced motion: one still 72px halo, no loop', (tester) async {
      await _pump(tester, init: (h) => h.reduced = true);
      expect(find.byType(UiMapPulseRings), findsOneWidget);
      expect(_running(tester), isFalse);
      expect(_rings, paints..circle(radius: 36)..circle(radius: 35));
      expect(_rings, isNot(paints..circle()..circle()..circle()));
    });

    testWidgets('stays on its point when the map moves (geo-anchored), under the markers', (tester) async {
      final h = await _pump(tester);
      Offset centre() => tester.getCenter(find.byType(UiMapPulseRings));
      expect(centre(), _screen(tester, h, _c));
      await tester.dragFrom(const Offset(200, 600), const Offset(-120, 40));
      await tester.pump(const Duration(milliseconds: 50));
      final now = _screen(tester, h, _c);
      expect((centre() - now).distance, lessThan(0.5));
      expect((now - const Offset(195, 400)).distance, greaterThan(50), reason: 'the map did move');
    });
  });

  group('view insets', () {
    test('the middle of the visible part, mirrored in RTL', () {
      expect(uiMapInsetShift(const EdgeInsetsDirectional.only(top: 100, bottom: 300), TextDirection.ltr), const Offset(0, -100));
      expect(uiMapInsetShift(const EdgeInsetsDirectional.only(start: 40), TextDirection.ltr), const Offset(20, 0));
      expect(uiMapInsetShift(const EdgeInsetsDirectional.only(start: 40), TextDirection.rtl), const Offset(-20, 0));
    });

    testWidgets('center lands in the middle of the part between the insets', (tester) async {
      final h = await _pump(tester, init: (h) => h.insets = const EdgeInsetsDirectional.only(top: 100, bottom: 300, start: 40));
      final p = _screen(tester, h, _c);
      expect(p.dx, closeTo((40 + _w) / 2, 0.5));
      expect(p.dy, closeTo((100 + 500) / 2, 0.5));
    });

    testWidgets('in RTL the start inset is on the right', (tester) async {
      final h = await _pump(tester, init: (h) {
        h.insets = const EdgeInsetsDirectional.only(start: 40);
        h.dir = TextDirection.rtl;
      });
      expect(_screen(tester, h, _c).dx, closeTo((_w - 40) / 2, 0.5));
    });

    testWidgets('a new center lands in the visible part too', (tester) async {
      final h = await _pump(tester, init: (h) => h.insets = const EdgeInsetsDirectional.only(bottom: 400));
      const next = UiLatLng(4.18, 73.52);
      h.set(() => h.center = next);
      await tester.pump();
      final p = _screen(tester, h, next);
      expect(p.dx, closeTo(_w / 2, 0.5));
      expect(p.dy, closeTo(200, 0.5));
    });

    testWidgets('changing insets pans smoothly so the visible middle stays in the middle', (tester) async {
      final h = await _pump(tester, init: (h) => h.pulse = null);
      expect(_screen(tester, h, _c).dy, closeTo(400, 0.5));
      h.set(() => h.insets = const EdgeInsetsDirectional.only(bottom: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final mid = _screen(tester, h, _c).dy;
      expect(mid, inExclusiveRange(250.5, 399.5), reason: 'moving, not jumping');
      await tester.pumpAndSettle();
      expect(_screen(tester, h, _c).dy, closeTo(250, 0.5));
      h.set(() => h.insets = const EdgeInsetsDirectional.only(top: 80, bottom: 300));
      await tester.pumpAndSettle();
      expect(_screen(tester, h, _c).dy, closeTo(290, 0.5));
      // The app echoing the same centre doesn't move it again.
      h.set(() => h.center = const UiLatLng(4.1755, 73.5093));
      await tester.pumpAndSettle();
      expect(_screen(tester, h, _c).dy, closeTo(290, 0.5));
    });

    testWidgets('under reduced motion an inset change re-centres at once', (tester) async {
      final h = await _pump(tester, init: (h) => h.reduced = true);
      h.set(() => h.insets = const EdgeInsetsDirectional.only(bottom: 300));
      await tester.pump();
      expect(_screen(tester, h, _c).dy, closeTo(250, 0.5));
    });

    testWidgets('Enter / the screen reader action drops the pin in the middle of the visible part', (tester) async {
      final h = await _pump(tester, init: (h) => h.insets = const EdgeInsetsDirectional.only(bottom: 300));
      final cam = h.key.currentState!.controller.camera;
      expect(cam.center.latitude, isNot(closeTo(_c.lat, 1e-6)), reason: "the map's own centre is lower down");
      final node = tester.getSemantics(find.byType(UiMap));
      final action = node.getSemanticsData().customSemanticsActionIds!.first;
      node.owner!.performAction(node.id, SemanticsAction.customAction, action);
      await tester.pump();
      expect(h.pin!.lat, closeTo(_c.lat, 1e-6));
      expect(h.pin!.lng, closeTo(_c.lng, 1e-6));
    }, semanticsEnabled: true);

    testWidgets('zoom buttons and attribution sit inside the insets; zooming keeps the visible middle', (tester) async {
      final h = await _pump(tester, init: (h) {
        h.insets = const EdgeInsetsDirectional.only(top: 80, bottom: 240, start: 12, end: 4);
        h.pulse = null;
      });
      await tester.pumpAndSettle();
      final zoomIn = find.byType(UiIconButton).first;
      expect(tester.getTopLeft(zoomIn).dx, closeTo(12 + 8, 4.5)); // the 48dp target may extend past the visible button
      expect(tester.getTopLeft(find.byType(UiIconButton).first).dy, greaterThanOrEqualTo(80));
      final attribution = tester.getBottomRight(find.text('© OpenStreetMap contributors'));
      expect(attribution.dy, lessThanOrEqualTo(_h - 240));
      expect(attribution.dx, closeTo(_w - 4 - 4, 4.5)); // its own 4px padding
      await tester.tap(zoomIn);
      await tester.pumpAndSettle();
      expect(h.key.currentState!.controller.camera.zoom, 16);
      final p = _screen(tester, h, _c);
      expect(p.dy, closeTo((80 + _h - 240) / 2, 0.5));
      expect(p.dx, closeTo((12 + _w - 4) / 2, 0.5));
    });

    testWidgets('fill draws square corners; without it the map is rounded', (tester) async {
      await _pump(tester);
      final clip = tester.widget<ClipRRect>(find.descendant(of: find.byType(UiMap), matching: find.byType(ClipRRect)).first);
      expect(clip.borderRadius, BorderRadius.zero);
      await tester.pumpWidget(UiApp(home: SizedBox(width: 300, height: 300, child: UiMap(tileProvider: UiMapBlankTiles()))));
      final rounded = tester.widget<ClipRRect>(find.descendant(of: find.byType(UiMap), matching: find.byType(ClipRRect)).first);
      expect(rounded.borderRadius, isNot(BorderRadius.zero));
    });
  });

  group('a full-screen map page', () {
    testWidgets('the status card and sheet feed the map insets, and both stay usable over the map', (tester) async {
      tester.view.physicalSize = const Size(_w, 844) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      final key = GlobalKey<UiMapState>();
      var top = 0.0, bottom = 0.0, cancelled = 0, snap = 0;
      final views = <UiMapView>[];
      await tester.pumpWidget(UiApp(
        theme: UiThemeName.maldives,
        home: StatefulBuilder(builder: (context, set) {
          return Stack(children: [
            Positioned.fill(
              child: UiMap(
                key: key,
                fill: true,
                center: _c,
                zoom: 15,
                tileProvider: UiMapBlankTiles(),
                pulse: const UiMapPulse(lat: 4.1755, lng: 73.5093),
                viewInsets: EdgeInsetsDirectional.only(top: top, bottom: bottom),
                onCenterChanged: views.add,
              ),
            ),
            UiFloatingPanel(
              placement: UiFloatingPanelPlacement.top,
              semanticLabel: 'Status',
              onCoverChanged: (v) => set(() => top = v),
              child: Row(children: [
                const Expanded(child: Text('Looking for a nurse near you')),
                UiButton(label: 'Cancel', size: UiSize.sm, variant: UiButtonVariant.ghost, onPressed: () => cancelled++),
              ]),
            ),
            UiBottomSheet(
              snaps: const [0.3, 0.6],
              snap: snap,
              title: 'Find a nurse',
              closable: false,
              onSnapChanged: (i) => set(() => snap = i),
              onCoverChanged: (v) => set(() => bottom = v),
              child: const UiInput(semanticLabel: 'Address'),
            ),
          ]);
        }),
      ));
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5)).catchError((_) => 0);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final card = tester.getRect(find.byType(UiFloatingPanel));
      expect(top, closeTo(card.bottom, 0.5), reason: 'gutter + height');
      expect(bottom, greaterThan(200));
      // The pulse (on the centre) sits in the middle of what the card and the sheet leave.
      final pulse = tester.getCenter(find.byType(UiMapPulseRings));
      expect(pulse.dy, closeTo((top + 844 - bottom) / 2, 1));

      await tester.tap(find.text('Cancel'));
      expect(cancelled, 1);
      await tester.tap(find.byType(UiInput));
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<UiBottomSheet>(), isNotNull);
      // The map between them still pans.
      await tester.dragFrom(Offset(_w / 2, top + 60), const Offset(80, 30));
      await tester.pump(const Duration(milliseconds: 600));
      expect(views, isNotEmpty);
    });
  });

  testWidgets('blank tiles are fully transparent (they used to tint the map blue)', (tester) async {
    final image = UiMapBlankTiles().getImage(const TileCoordinates(0, 0, 0), TileLayer()) as MemoryImage;
    final rgba = await tester.runAsync(() async {
      final img = await decodeImageFromList(image.bytes);
      return (await img.toByteData(format: ImageByteFormat.rawRgba))!.buffer.asUint8List();
    });
    expect(rgba![3], 0);
  });

  testWidgets('golden: the pulse over a map with insets (maldives, maldives dark)', (tester) async {
    await expectThemedGolden(
      tester,
      'map_pulse',
      (context) => SizedBox(
        height: 268,
        child: UiMap(
          zoom: 15,
          tileProvider: UiMapBlankTiles(),
          markers: const [UiMapMarker(id: 'n1', lat: 4.1762, lng: 73.5105, label: 'Aminath Hassan, RN', tone: UiStatus.success)],
          pin: _c,
          pinDraggable: false,
          pulse: const UiMapPulse(lat: 4.1755, lng: 73.5093),
          viewInsets: const EdgeInsetsDirectional.only(top: 40),
        ),
      ),
      themes: const [UiThemeName.maldives, UiThemeName.maldivesDark],
    );
  });
}

/// A canvas that reports each circle's radius (to read the first ring's size).
class _RecordingCanvas implements Canvas {
  _RecordingCanvas(this.onCircle);
  final void Function(double radius) onCircle;

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    if (paint.style == PaintingStyle.stroke) onCircle(radius);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
