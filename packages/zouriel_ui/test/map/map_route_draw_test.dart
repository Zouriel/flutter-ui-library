import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart' show PolylineLayer;
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// 0.46.2: a route draws in from its start to its end when it appears or its points change.

const _road = [UiLatLng(4.1755, 73.5093), UiLatLng(4.19, 73.525), UiLatLng(4.2105, 73.5402)];
const _other = [UiLatLng(4.1755, 73.5093), UiLatLng(4.2, 73.53)];

class _Host {
  List<UiMapRoute> routes = const [];
  bool reduced = false;
  late StateSetter set;
}

Future<_Host> _pump(WidgetTester tester, {bool reduced = false}) async {
  final h = _Host()..reduced = reduced;
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(StatefulBuilder(builder: (context, set) {
    h.set = set;
    return UiApp(
      theme: UiThemeName.maldives,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: h.reduced),
          child: UiMap(fill: true, center: const UiLatLng(4.19, 73.525), zoom: 13, tileProvider: UiMapBlankTiles(), routes: h.routes),
        ),
      ),
    );
  }));
  await tester.pump(const Duration(milliseconds: 50));
  return h;
}

/// Sets the routes and pumps the frame that starts their draw-in.
Future<void> _set(WidgetTester tester, _Host h, List<UiMapRoute> routes) async {
  h.set(() => h.routes = routes);
  await tester.pump();
}

List<List<UiLatLng>> _lines(WidgetTester tester) {
  final f = find.byType(PolylineLayer<String>);
  if (f.evaluate().isEmpty) return const [];
  return [for (final l in tester.widget<PolylineLayer<String>>(f).polylines) [for (final p in l.points) UiLatLng(p.latitude, p.longitude)]];
}

double _drawn(WidgetTester tester, [int i = 0]) => uiMapRouteLength(_lines(tester)[i]);

final _total = uiMapRouteLength(_road);

void main() {
  test('the maths: the same numbers as the web', () {
    expect(uiMapRouteDrawDuration(1000), const Duration(milliseconds: 450));
    expect(uiMapRouteDrawDuration(4000), const Duration(milliseconds: 750));
    expect(uiMapRouteDrawDuration(100000), const Duration(milliseconds: 900)); // a long drive never drags
    expect(uiMapRouteDrawDuration(50), const Duration(milliseconds: 250)); // a street-length one is quick
    expect(uiMapRouteDrawDuration(300) < uiMapRouteDrawDuration(5000), isTrue);
    expect([uiMapRouteEase(0), uiMapRouteEase(0.5), uiMapRouteEase(1), uiMapRouteEase(2)], [0, 0.875, 1, 1]);
    expect(uiMapRoutePartial(_road, 0), [_road.first, _road.first]);
    final half = uiMapRoutePartial(_road, 0.5);
    expect(uiMapRouteLength(half) / _total, closeTo(0.5, 1e-3));
    expect(uiMapRoutePartial(_road, 1), _road);
    expect(uiMapRouteFade, const Duration(milliseconds: 150));
  });

  testWidgets('grows along the path: partial mid-way, whole at the end, then stops', (tester) async {
    final h = await _pump(tester);
    final ms = uiMapRouteDrawDuration(_total).inMilliseconds;
    expect(ms, inInclusiveRange(600, 900));
    await _set(tester, h, const [UiMapRoute(id: 'r', points: _road)]);
    expect(_drawn(tester), lessThan(1)); // a dot at the start
    expect(_lines(tester).single.first, _road.first);
    await tester.pump(Duration(milliseconds: ms ~/ 4));
    final quarter = _drawn(tester) / _total;
    expect(quarter, closeTo(uiMapRouteEase(0.25), 0.02));
    await tester.pump(Duration(milliseconds: ms ~/ 4));
    final half = _drawn(tester) / _total;
    expect(half, closeTo(0.875, 0.02)); // ease-out: most of it by half time
    expect(half, lessThan(0.99));
    await tester.pump(Duration(milliseconds: ms ~/ 2 + 16));
    await tester.pump();
    expect(_lines(tester).single, _road);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the same points again (a new list, same id) do not replay; new points do', (tester) async {
    final h = await _pump(tester);
    await _set(tester, h, const [UiMapRoute(id: 'r', points: _road, semanticLabel: 'Route')]);
    await tester.pump(const Duration(seconds: 2));
    expect(_drawn(tester), closeTo(_total, 1e-6));
    await _set(tester, h, [UiMapRoute(id: 'r', points: List.of(_road), semanticLabel: 'Route, 5 km', tone: UiMapRouteTone.success)]);
    expect(_drawn(tester), closeTo(_total, 1e-6));
    // New points draw in again; the same points mid-draw don't restart it.
    await _set(tester, h, const [UiMapRoute(id: 'r', points: _other)]);
    expect(_drawn(tester), lessThan(1));
    await tester.pump(const Duration(milliseconds: 100));
    final before = _drawn(tester);
    expect(before, greaterThan(1));
    await _set(tester, h, [UiMapRoute(id: 'r', points: List.of(_other))]);
    expect(_drawn(tester), greaterThanOrEqualTo(before));
    await tester.pump(const Duration(seconds: 2));
    expect(_drawn(tester), closeTo(uiMapRouteLength(_other), 1e-6));
  });

  testWidgets('reduced motion: drawn whole at once', (tester) async {
    final h = await _pump(tester, reduced: true);
    await _set(tester, h, const [UiMapRoute(id: 'r', points: _road)]);
    expect(_lines(tester).single, _road);
    await _set(tester, h, const [UiMapRoute(id: 'r', points: _other)]);
    expect(_lines(tester).single, _other);
  });

  testWidgets('animate: false draws that route at once, the others still draw in', (tester) async {
    final h = await _pump(tester);
    await _set(tester, h, const [UiMapRoute(id: 'r', points: _road, animate: false), UiMapRoute(id: 'o', points: _other)]);
    expect(_lines(tester)[0], _road);
    expect(_drawn(tester, 1), lessThan(1));
  });

  testWidgets('a removed route fades out over 150 ms, then goes; at once under reduced motion', (tester) async {
    final h = await _pump(tester);
    await _set(tester, h, const [UiMapRoute(id: 'r', points: _road, semanticLabel: 'Route')]);
    await tester.pump(const Duration(seconds: 2));
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Route'), findsOneWidget);
    final full = tester.widget<PolylineLayer<String>>(find.byType(PolylineLayer<String>)).polylines.single.color.a;
    await _set(tester, h, const []);
    await tester.pump(const Duration(milliseconds: 75));
    final fading = tester.widget<PolylineLayer<String>>(find.byType(PolylineLayer<String>)).polylines.single;
    expect(fading.color.a, inExclusiveRange(0, full));
    expect(fading.borderColor.a, lessThan(1));
    expect(_lines(tester).single, _road); // fades whole, where it was
    expect(find.bySemanticsLabel('Route'), findsNothing); // no longer read out
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.byType(PolylineLayer<String>), findsNothing);
    handle.dispose();

    final r = await _pump(tester, reduced: true);
    await _set(tester, r, const [UiMapRoute(id: 'r', points: _road)]);
    await _set(tester, r, const []);
    expect(find.byType(PolylineLayer<String>), findsNothing);
  });

  testWidgets('a route put back while it fades draws again, with no stale line left', (tester) async {
    final h = await _pump(tester);
    await _set(tester, h, const [UiMapRoute(id: 'r', points: _road)]);
    await tester.pump(const Duration(seconds: 2));
    await _set(tester, h, const []);
    await tester.pump(const Duration(milliseconds: 50));
    await _set(tester, h, const [UiMapRoute(id: 'r', points: _road)]);
    expect(_lines(tester), hasLength(1));
    expect(_drawn(tester), lessThan(1)); // it appeared again: it draws in again
    await tester.pump(const Duration(seconds: 2));
    expect(_lines(tester).single, _road);
  });
}
