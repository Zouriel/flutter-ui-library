import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// 0.42.1: the app's own map controls, and marker labels that flip away from the map's edge.

const _c = UiLatLng(4.1755, 73.5093);
const _w = 390.0, _h = 844.0;
const _address = 'Lily Magu, Hiyaa Tower 4, Hulhumale Male'; // 40 characters

class _Host {
  List<UiMapControl> controls = const [];
  List<UiMapMarker> markers = const [];
  bool locate = true;
  EdgeInsetsDirectional insets = EdgeInsetsDirectional.zero;
  TextDirection dir = TextDirection.ltr;
  final tapped = <String>[];
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
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: Directionality(
            textDirection: h.dir,
            child: SizedBox(
              width: _w,
              height: _h,
              child: UiMap(
                key: h.key,
                fill: true,
                center: _c,
                zoom: 15,
                tileProvider: UiMapBlankTiles(),
                markers: h.markers,
                onMarkerSelected: (m) => h.tapped.add(m.id),
                controls: h.controls,
                locateControl: h.locate,
                onLocate: () {},
                viewInsets: h.insets,
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

/// The visible disc of a map button (the AnimatedContainer inside it).
Rect _disc(WidgetTester tester, Finder button) => tester.getRect(find.descendant(of: button, matching: find.byType(AnimatedContainer)).first);

/// The point [px] from the map's top-left, as a map position.
UiLatLng _at(_Host h, Offset px) {
  final ll = h.key.currentState!.controller.camera.screenOffsetToLatLng(px);
  return UiLatLng(ll.latitude, ll.longitude);
}

Rect _chip(WidgetTester tester, String label) => tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(Container)).first);

void main() {
  group('controls', () {
    testWidgets('an app control: the locate button’s round raised surface, above it at the bottom-end, pressed calls back', (tester) async {
      var pressed = 0;
      await _pump(tester, init: (h) => h.controls = [UiMapControl(id: 'fit', icon: HugeIcons.strokeRoundedCenterFocus, semanticLabel: 'Show both', tooltip: 'Show both', onPressed: () => pressed++)]);
      final t = _t(tester);
      final control = find.byType(UiMapControlButton);
      expect(control, findsOneWidget);
      final d = tester.widget<AnimatedContainer>(find.descendant(of: control, matching: find.byType(AnimatedContainer))).decoration! as BoxDecoration;
      final locate = tester.widget<AnimatedContainer>(find.descendant(of: find.byType(UiMapLocateButton), matching: find.byType(AnimatedContainer))).decoration! as BoxDecoration;
      expect(d.shape, BoxShape.circle);
      expect((d.color, d.boxShadow, (d.border! as Border).top.color), (locate.color, locate.boxShadow, (locate.border! as Border).top.color));
      expect(d.color, t.surfaceRaised);
      expect(d.color!.a, 1, reason: 'opaque over the map');
      final a = _disc(tester, control), b = _disc(tester, find.byType(UiMapLocateButton));
      expect(a.size, b.size);
      expect(a.center.dx, closeTo(b.center.dx, 0.01), reason: 'one column');
      expect(b.top - a.bottom, closeTo(t.space2, 0.01), reason: 'just above the locate button');
      await tester.tap(control);
      expect(pressed, 1);
      final icon = tester.widget<UiIcon>(find.descendant(of: control, matching: find.byType(UiIcon)));
      expect(uiContrast(icon.color!, d.color!), greaterThanOrEqualTo(4.5));
    });

    testWidgets('several controls stack upwards in order; without the locate button they take its place', (tester) async {
      final h = await _pump(tester, init: (h) {
        h.locate = false;
        h.controls = [
          UiMapControl(id: 'a', icon: HugeIcons.strokeRoundedCenterFocus, semanticLabel: 'Show both', onPressed: () {}),
          UiMapControl(id: 'b', icon: HugeIcons.strokeRoundedLayers01, semanticLabel: 'Layers', onPressed: () {}),
        ];
      });
      final t = _t(tester);
      final a = _disc(tester, find.byKey(const ValueKey('ui-map-control-a'))), b = _disc(tester, find.byKey(const ValueKey('ui-map-control-b')));
      expect(b.top - a.bottom, closeTo(t.space2, 0.01));
      // Where the locate button would sit: space8 above the bottom, space3 from the end.
      expect(b.bottom, closeTo(_h - t.space8, 0.01));
      expect(b.right, closeTo(_w - t.space3, 0.01));
      // They follow the insets (above a bottom sheet, beside an end panel).
      h.set(() => h.insets = const EdgeInsetsDirectional.only(bottom: 300, end: 20));
      await tester.pumpAndSettle();
      final b2 = _disc(tester, find.byKey(const ValueKey('ui-map-control-b')));
      expect(b2.bottom, closeTo(_h - 300 - t.space8, 0.01));
      expect(b2.right, closeTo(_w - 20 - t.space3, 0.01));
    });

    testWidgets('RTL: at the bottom-left, the tooltip facing into the map', (tester) async {
      await _pump(tester, init: (h) {
        h.dir = TextDirection.rtl;
        h.controls = [UiMapControl(id: 'fit', icon: HugeIcons.strokeRoundedCenterFocus, semanticLabel: 'Show both', tooltip: 'Show both', onPressed: () {})];
      });
      final t = _t(tester);
      final a = _disc(tester, find.byType(UiMapControlButton));
      expect(a.left, closeTo(t.space3, 0.01));
      expect(tester.widget<UiTooltip>(find.ancestor(of: find.byType(UiInteractive), matching: find.byType(UiTooltip)).last).position, UiTooltipPosition.right);
    });

    testWidgets('named for screen readers; no onPressed is disabled; 48dp targets on touch', (tester) async {
      final handle = tester.ensureSemantics();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await _pump(tester, init: (h) => h.controls = const [
        UiMapControl(id: 'off', icon: HugeIcons.strokeRoundedCenterFocus, semanticLabel: 'Show both'),
      ]);
      final t = _t(tester);
      expect(tester.getSemantics(find.bySemanticsLabel('Show both')), matchesSemantics(label: 'Show both', isButton: true, hasEnabledState: true, isEnabled: false));
      expect(tester.getSize(find.byType(UiMapControlButton)), const Size(48, 48));
      final a = _disc(tester, find.byType(UiMapControlButton)), b = _disc(tester, find.byType(UiMapLocateButton));
      expect(a.width, t.sizeTouch);
      expect(b.top - a.bottom, closeTo(t.space2, 0.01), reason: 'the same 8px gap on touch');
      expect(tester.widget<UiIcon>(find.descendant(of: find.byType(UiMapControlButton), matching: find.byType(UiIcon))).color, t.textMuted);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      debugDefaultTargetPlatformOverride = null;
      handle.dispose();
    });
  });

  group('labels near the edge', () {
    test('the side: the inline end unless it runs off there, then the other, else the roomier', () {
      expect(uiMapLabelSide(100, 200, 390), UiMapLabelSide.right);
      expect(uiMapLabelSide(350, 200, 390), UiMapLabelSide.left); // 40px from the right edge
      expect(uiMapLabelSide(220, 150, 390), UiMapLabelSide.right); // 220 + 12 + 150 = 382: just fits
      expect(uiMapLabelSide(221, 150, 390), UiMapLabelSide.left);
      // Neither side fits: the roomier one.
      expect(uiMapLabelSide(170, 300, 390), UiMapLabelSide.right);
      expect(uiMapLabelSide(250, 300, 390), UiMapLabelSide.left);
      // RTL mirrored: the left first, the right near the left edge.
      expect(uiMapLabelSide(250, 100, 390, rtl: true), UiMapLabelSide.left);
      expect(uiMapLabelSide(40, 200, 390, rtl: true), UiMapLabelSide.right);
    });

    testWidgets('390 wide, a pin 40px from the right edge: the label sits left of the dot, all of it on the map', (tester) async {
      final h = await _pump(tester);
      final p = _at(h, const Offset(_w - 40, 400));
      h.set(() => h.markers = [UiMapMarker(id: 'p', lat: p.lat, lng: p.lng, label: _address, tone: UiStatus.danger)]);
      await tester.pump();
      final chip = _chip(tester, _address);
      expect(chip.right, lessThanOrEqualTo(_w - 40 - 12 + 0.5), reason: 'left of the dot, 12px from its point');
      expect(chip.left, greaterThanOrEqualTo(0));
      expect(chip.right, closeTo(_w - 40 - uiMapLabelGap, 0.5));
    });

    testWidgets('wherever one side has room, all of the label is on the map (measured with its padding)', (tester) async {
      final h = await _pump(tester);
      for (final x in [60.0, 300.0, 350.0]) {
        final p = _at(h, Offset(x, 400));
        h.set(() => h.markers = [UiMapMarker(id: 'p', lat: p.lat, lng: p.lng, label: _address)]);
        await tester.pump();
        final chip = _chip(tester, _address);
        expect(chip.width, greaterThan(200), reason: 'a long chip, so the side matters');
        expect(chip.left, greaterThanOrEqualTo(uiMapLabelEdge - 0.5), reason: 'x $x');
        expect(chip.right, lessThanOrEqualTo(_w - uiMapLabelEdge + 0.5), reason: 'x $x');
      }
    });

    testWidgets('in the middle the label stays on the right, 12px from the point; it flips as the map pans', (tester) async {
      final h = await _pump(tester);
      final p = _at(h, const Offset(100, 400));
      h.set(() => h.markers = [UiMapMarker(id: 'p', lat: p.lat, lng: p.lng, label: _address)]);
      await tester.pump();
      expect(_chip(tester, _address).left, closeTo(100 + uiMapLabelGap, 0.5));
      // Pan so the marker is 40px from the right edge: the label goes left.
      final cam = h.key.currentState!.controller.camera;
      h.key.currentState!.controller.move(cam.screenOffsetToLatLng(const Offset(_w / 2 - 250, _h / 2)), cam.zoom);
      await tester.pump();
      expect(_chip(tester, _address).right, closeTo(_w - 40 - uiMapLabelGap, 0.5));
    });

    testWidgets('the dot stays on the point and keeps its 48dp target whichever side the label is on', (tester) async {
      final h = await _pump(tester);
      final l = _at(h, const Offset(100, 300)), r = _at(h, const Offset(_w - 40, 500));
      h.set(() => h.markers = [UiMapMarker(id: 'l', lat: l.lat, lng: l.lng, label: _address), UiMapMarker(id: 'r', lat: r.lat, lng: r.lng, label: _address)]);
      await tester.pump();
      // Beside the dot, away from the label (20px out): still that marker's target.
      await tester.tapAt(const Offset(100 - 20, 300));
      await tester.tapAt(const Offset(_w - 40 + 20, 500));
      expect(h.tapped, ['l', 'r']);
      // The dots' centres are on their points.
      final dots = find.descendant(of: find.byType(UiMap), matching: find.byWidgetPredicate((w) => w is Container && w.constraints == const BoxConstraints.tightFor(width: 16, height: 16)));
      final centres = [for (final e in dots.evaluate()) tester.getCenter(find.byWidget(e.widget))]..sort((a, b) => a.dx.compareTo(b.dx));
      expect(centres.first.dx, closeTo(100, 0.5));
      expect(centres.last.dx, closeTo(_w - 40, 0.5));
      expect(h.key.currentState!.controller.camera.latLngToScreenOffset(LatLng(r.lat, r.lng)).dx, closeTo(_w - 40, 0.5));
    });

    testWidgets('RTL mirrored: the label starts on the left; near the left edge it flips right', (tester) async {
      final h = await _pump(tester, init: (h) => h.dir = TextDirection.rtl);
      final mid = _at(h, const Offset(250, 300)), edge = _at(h, const Offset(40, 500));
      h.set(() => h.markers = [UiMapMarker(id: 'm', lat: mid.lat, lng: mid.lng, label: 'Hiyaa Tower 4'), UiMapMarker(id: 'e', lat: edge.lat, lng: edge.lng, label: _address)]);
      await tester.pump();
      expect(_chip(tester, 'Hiyaa Tower 4').right, closeTo(250 - uiMapLabelGap, 0.5));
      final e = _chip(tester, _address);
      expect(e.left, closeTo(40 + uiMapLabelGap, 0.5));
      expect(e.right, lessThanOrEqualTo(_w));
    });
  });
}
