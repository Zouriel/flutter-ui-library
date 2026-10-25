import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart' show PolylineLayer;
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// 0.47.0: UiMapNavigation, on the web spec's drive (navigation.spec.ts / map-navigation.spec.ts).

const _o = UiLatLng(4.17, 73.51);
const _mLat = 111194.93;
UiLatLng at(double north, double east) => UiLatLng(_o.lat + north / _mLat, _o.lng + east / (_mLat * math.cos(_o.lat * math.pi / 180)));
final baseRoute = [at(0, 0), at(500, 0), at(500, 300), at(700, 300)];
UiNavStep step(String type, String? modifier, UiLatLng loc, double d, double s, String instruction, [String? street, int? exit]) => UiNavStep(
    maneuver: UiNavManeuver(type: type, modifier: modifier, location: loc, exit: exit), distanceMeters: d, durationSeconds: s, instruction: instruction, streetName: street);
final steps = [
  step('depart', null, at(0, 0), 500, 60, 'Head north', 'Majeedhee Magu'),
  step('turn', 'right', at(500, 0), 300, 40, 'Turn right onto Orchid Magu', 'Orchid Magu'),
  step('roundabout', 'left', at(500, 300), 200, 30, 'At the roundabout, take the 2nd exit', 'Chaandhanee Magu', 2),
  step('arrive', null, at(700, 300), 0, 0, 'You have arrived'),
];
UiLatLng along(double d, [double side = 0]) => d <= 500 ? at(d, side) : d <= 800 ? at(500 - side, d - 500) : at(500 + d - 800, 300 + side);

class _Host {
  List<UiLatLng> route = [...baseRoute];
  UiNavPosition? position;
  TextDirection dir = TextDirection.ltr;
  bool reduced = true;
  UiStrings strings = const UiStrings();
  final events = <UiNavEvent>[];
  final states = <UiNavState>[];
  int ended = 0;
  late StateSetter set;
  final key = GlobalKey<UiMapNavigationState>();
}

Future<_Host> _pump(WidgetTester tester, {void Function(_Host h)? init}) async {
  final h = _Host();
  init?.call(h);
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(StatefulBuilder(builder: (context, set) {
    h.set = set;
    return UiApp(
      theme: UiThemeName.maldives,
      config: UiConfig(strings: h.strings),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: h.reduced),
          child: Directionality(
            textDirection: h.dir,
            child: UiMapNavigation(
              key: h.key,
              route: h.route,
              steps: steps,
              position: h.position,
              options: const UiNavOptions(offRouteSeconds: 0),
              destinationLabel: 'Lily Magu',
              tileProvider: UiMapBlankTiles(),
              formatTime: (t) => 'T${t.millisecondsSinceEpoch ~/ 1000}',
              onAnnounce: h.events.add,
              onOffRoute: h.events.add,
              onArrived: () => h.events.add(const UiNavArrived()),
              onProgress: h.states.add,
              onEnd: () => h.ended++,
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

Future<void> _feed(WidgetTester tester, _Host h, UiLatLng p, {required int t, double? heading, double speed = 10}) async {
  h.set(() => h.position = UiNavPosition(p.lat, p.lng, heading: heading, speed: speed, timestamp: t));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

String _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;
UiMapState _map(WidgetTester tester) => tester.state<UiMapState>(find.byType(UiMap));

void main() {
  testWidgets('the banner: the next maneuver\'s arrow, "in 500 m", instruction and street; the one after small; the bar', (tester) async {
    final handle = tester.ensureSemantics();
    final h = await _pump(tester);
    await _feed(tester, h, along(0), t: 1000000, heading: 0);
    expect(_text(tester, 'ui-nav-distance'), 'in 500 m');
    expect(_text(tester, 'ui-nav-instruction'), 'Turn right onto Orchid Magu');
    expect(_text(tester, 'ui-nav-street'), 'Orchid Magu');
    expect(find.byKey(const ValueKey('ui-nav-icon-right')), findsOneWidget);
    expect(_text(tester, 'ui-nav-then-text'), 'At the roundabout, take the 2nd exit');
    expect(find.text('Then'), findsOneWidget);
    expect(_text(tester, 'ui-nav-time'), '3 min');
    expect([_text(tester, 'ui-nav-distance-left'), _text(tester, 'ui-nav-clock')], ['1 km', 'T1130']);
    expect(find.bySemanticsLabel('3 min left, 1 km, arrive at T1130'), findsOneWidget);
    expect(find.bySemanticsLabel('in 500 m, Turn right onto Orchid Magu, Orchid Magu'), findsOneWidget);
    expect(tester.getSemantics(find.byType(UiMapNavigation)).label, 'Navigation');
    handle.dispose();
  });

  testWidgets('steps along a simulated drive: banner, roundabout exit, events, the way behind dimmed', (tester) async {
    final h = await _pump(tester);
    for (var d = 0; d <= 560; d += 20) {
      await _feed(tester, h, along(d.toDouble()), t: d * 100, heading: d < 500 ? 0 : 90);
    }
    expect(_text(tester, 'ui-nav-instruction'), 'At the roundabout, take the 2nd exit');
    expect(find.byKey(const ValueKey('ui-nav-icon-roundabout-left')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('ui-nav-exit')), matching: find.text('2')), findsOneWidget);
    expect(_text(tester, 'ui-nav-then-text'), 'You have arrived');
    final t = UiTheme.of(tester.element(find.byType(UiMap))).tokens;
    final lines = tester.widget<PolylineLayer<String>>(find.byType(PolylineLayer<String>)).polylines;
    expect(lines.map((l) => l.hitValue), ['nav-traveled', 'nav-remaining']);
    expect(lines[0].color.a, closeTo(t.mapRouteMuted.a * 0.6, 1e-6)); // dimmed: the muted tone at 60%
    expect(lines[1].color, t.mapRoutePrimary);
    expect(lines[0].points.last, lines[1].points.first);
    final ann = h.events.whereType<UiNavAnnounce>().map((e) => '${e.stepIndex}:${e.reason.name}${e.threshold?.round() ?? ''}');
    expect(ann, ['1:step', '1:distance200', '1:distance30', '2:step']);
    expect(h.states, hasLength(29));
    for (var d = 580; d <= 1000; d += 20) {
      await _feed(tester, h, along(d.toDouble()), t: d * 100, heading: d <= 800 ? 90 : 0);
    }
    expect(h.events.whereType<UiNavArrived>(), hasLength(1));
    expect(_text(tester, 'ui-nav-time'), '0 min');
  });

  testWidgets('off the route: onOffRoute with the distance; a new route (a reroute) starts over', (tester) async {
    final h = await _pump(tester);
    await _feed(tester, h, along(100), t: 0);
    await _feed(tester, h, along(120, 90), t: 1000);
    final off = h.events.whereType<UiNavOffRoute>().toList();
    expect(off, hasLength(1));
    expect(off.single.distanceMeters, closeTo(90, 0.5));
    h.set(() => h.route = [along(120, 90), at(500, 90), at(500, 300), at(700, 300)]);
    await _feed(tester, h, along(120, 90), t: 2000);
    expect(h.states.last.distanceFromRoute, lessThan(1));
    expect(_text(tester, 'ui-nav-distance'), 'in 400 m');
  });

  testWidgets('turns the map heading-up about the person (at once under reduced motion), the arrow on the person', (tester) async {
    final h = await _pump(tester);
    await _feed(tester, h, along(600), t: 0, heading: 90);
    final cam = _map(tester).controller.camera;
    expect(cam.rotation, closeTo(-90, 1e-6));
    expect(_map(tester).currentBearing, closeTo(90, 1e-6));
    // The person's arrow, turned to the heading on the map.
    final puck = tester.widget<Transform>(find.byKey(const ValueKey('ui-map-user-puck')));
    expect(math.atan2(puck.transform.entry(1, 0), puck.transform.entry(0, 0)) * 180 / math.pi, closeTo(90, 1e-6));
    // The person sits in the visible part, 68% of the way from the banner to the bar.
    final mapBox = tester.getRect(find.byType(UiMap));
    final p = mapBox.topLeft + cam.latLngToScreenOffset(cam.center);
    expect(p.dx, closeTo(195, 1));
    // Upright: the destination label reads level on the turned map.
    await _feed(tester, h, along(820), t: 1000, heading: 0);
    await _feed(tester, h, along(840), t: 2000, heading: 45);
    final label = find.text('Lily Magu');
    expect(tester.getTopLeft(label).dy, closeTo(tester.getTopRight(label).dy, 0.01));
    // The shorter way round: 45 to 350 turns -55, not +305.
    await _feed(tester, h, along(860), t: 3000, heading: 350);
    expect(_map(tester).bearingTarget, closeTo(-10, 1e-6));
  });

  testWidgets('with motion: the turn eases over motionSlow, and the arrow eases with it', (tester) async {
    final h = await _pump(tester, init: (h) => h.reduced = false);
    await _feed(tester, h, along(600), t: 0, heading: 0);
    await tester.pump(const Duration(seconds: 1));
    await _feed(tester, h, along(620), t: 1000, heading: 90);
    final mid = _map(tester).currentBearing;
    expect(mid, inExclusiveRange(1, 89)); // partway
    // The arrow on screen still points up the road (heading minus the turn still to come).
    final puck = tester.widget<Transform>(find.byKey(const ValueKey('ui-map-user-puck')));
    final onMap = math.atan2(puck.transform.entry(1, 0), puck.transform.entry(0, 0)) * 180 / math.pi;
    expect(onMap - mid, closeTo(0, 1e-6));
    await tester.pump(const Duration(seconds: 1));
    expect(_map(tester).currentBearing, closeTo(90, 1e-6));
  });

  testWidgets('a drag stops the following (the map keeps its turn), shows Recenter and the compass; Recenter follows again', (tester) async {
    final h = await _pump(tester);
    await _feed(tester, h, along(600), t: 0, heading: 90);
    expect(find.byKey(const ValueKey('ui-nav-recenter')), findsNothing);
    expect(find.byKey(const ValueKey('ui-map-compass')), findsNothing); // heading-up while following
    await tester.dragFrom(const Offset(195, 600), const Offset(80, 60));
    await tester.pump();
    expect(h.key.currentState!.following, isFalse);
    expect(find.byKey(const ValueKey('ui-nav-recenter')), findsOneWidget);
    expect(find.byKey(const ValueKey('ui-map-compass')), findsOneWidget);
    _map(tester).controller.move(_map(tester).controller.camera.center, 13);
    final c = _map(tester).controller.camera.center;
    await _feed(tester, h, along(640), t: 1000, heading: 0);
    expect(_map(tester).controller.camera.center, c); // not following: fixes don't move the map
    expect(_map(tester).currentBearing, closeTo(90, 1e-6)); // and the turn holds
    await tester.tap(find.byKey(const ValueKey('ui-nav-recenter')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(h.key.currentState!.following, isTrue);
    expect(find.byKey(const ValueKey('ui-nav-recenter')), findsNothing);
    expect(_map(tester).controller.camera.zoom, 17);
    expect(_map(tester).currentBearing, closeTo(0, 1e-6));
  });

  testWidgets('a two-finger turn pauses heading-up (compass shows); Recenter turns back heading-up', (tester) async {
    final h = await _pump(tester);
    await _feed(tester, h, along(600), t: 0, heading: 90);
    const c = Offset(195, 500);
    Offset pt(double deg, int side) => c + Offset(math.cos(deg * math.pi / 180), math.sin(deg * math.pi / 180)) * 80 * side.toDouble();
    final a = await tester.startGesture(pt(0, -1), pointer: 21);
    final b = await tester.startGesture(pt(0, 1), pointer: 22);
    await tester.pump();
    for (final d in <double>[5, 10, 20, 30]) {
      await a.moveTo(pt(d, -1));
      await b.moveTo(pt(d, 1));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pump();
    expect(h.key.currentState!.following, isFalse);
    final turned = _map(tester).currentBearing;
    expect(turned, inInclusiveRange(55, 80)); // 90 less about the 30 degree turn
    expect(find.byKey(const ValueKey('ui-map-compass')), findsOneWidget);
    await _feed(tester, h, along(620), t: 1000, heading: 90);
    expect(_map(tester).currentBearing, closeTo(turned, 1e-6)); // paused: fixes don't turn it back
    await tester.tap(find.byKey(const ValueKey('ui-nav-recenter')));
    await tester.pump();
    expect(h.key.currentState!.following, isTrue);
    expect(_map(tester).currentBearing, closeTo(90, 1e-6));
    expect(find.byKey(const ValueKey('ui-map-compass')), findsNothing);
  });

  testWidgets('End calls onEnd; the strings follow the language', (tester) async {
    final h = await _pump(tester, init: (h) => h.strings = UiStrings.dv);
    await _feed(tester, h, along(0), t: 0);
    await tester.tap(find.byKey(const ValueKey('ui-nav-end')));
    expect(h.ended, 1);
    expect(_text(tester, 'ui-nav-distance'), '500 މީޓަރު ދުރުން');
    expect(find.text('ނިންމާ'), findsOneWidget);
  });

  testWidgets('RTL mirrors the banner and bar, never the arrows', (tester) async {
    final h = await _pump(tester, init: (h) => h.dir = TextDirection.rtl);
    await _feed(tester, h, along(0), t: 0);
    final icon = tester.getRect(find.byKey(const ValueKey('ui-nav-maneuver')));
    final text = tester.getRect(find.byKey(const ValueKey('ui-nav-instruction')));
    expect(icon.left, greaterThan(text.right - 1)); // the arrow at the start: the right
    expect(find.byKey(const ValueKey('ui-nav-icon-right')), findsOneWidget); // still the right turn
    final arrow = tester.widget<UiIcon>(find.byKey(const ValueKey('ui-nav-icon-right')));
    expect(arrow.matchTextDirection, isFalse);
    final time = tester.getRect(find.byKey(const ValueKey('ui-nav-time')));
    final end = tester.getRect(find.byKey(const ValueKey('ui-nav-end')));
    expect(end.right, lessThan(time.left)); // End at the bar's end: the left
  });

  test('the follow point: 68% of the way from the banner to the bar', () {
    final ins = uiNavFollowInsets(844, 150, 90);
    expect((ins.top + 844 - ins.bottom) / 2, closeTo(150 + (844 - 150 - 90) * uiNavFollowAt, 1e-9));
    expect(ins.bottom, 90);
  });
}
