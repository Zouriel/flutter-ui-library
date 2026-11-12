import 'dart:async';
import 'dart:ui' show GestureSettings;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/behaviors/pull_to_refresh.dart' show UiShutterOverscroll;
import 'package:zouriel_ui/src/feedback/shutter_loader.dart' show UiShutterMark, uiShutterBlades;
import 'package:zouriel_ui/zouriel_ui.dart';

// 0.72.0: UiPullToRefresh and the overscroll shutter ball. Every test sets a phone's touch slop (8dp),
// which scroll views read from MediaQuery, rather than the test default of 18.

Future<void> _pump(WidgetTester tester, Widget home, {UiConfig config = const UiConfig()}) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  tester.view.gestureSettings = GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(config: config, home: home));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Drags a finger [dy] px (down when positive) from [from] in small steps, as a hand does, and
/// keeps it down; returns the gesture so the test can look before lifting.
Future<TestGesture> _hold(WidgetTester tester, double dy, {Offset from = const Offset(195, 300)}) async {
  final g = await tester.startGesture(from);
  const steps = 20;
  for (var i = 0; i < steps; i++) {
    await g.moveBy(Offset(0, dy / steps));
    await tester.pump(const Duration(milliseconds: 16));
  }
  return g;
}

Future<void> _pull(WidgetTester tester, double dy, {Offset from = const Offset(195, 300)}) async {
  final g = await _hold(tester, dy, from: from);
  await g.up();
  await tester.pump();
}

Widget _list({ScrollPhysics? physics, ScrollController? controller}) => ListView.builder(
      controller: controller,
      physics: physics,
      itemCount: 40,
      itemExtent: 60,
      itemBuilder: (_, i) => Text('Item $i'),
    );

Finder get _ball => find.byType(UiShutterMark);
Finder get _busyBall => find.descendant(of: find.byType(UiPullToRefresh), matching: find.byType(UiShutterLoader));

void main() {
  group('UiPullToRefresh', () {
    testWidgets('a pull short of the threshold shows the ball and lets it go without refreshing', (tester) async {
      var calls = 0;
      await _pump(tester, UiPullToRefresh(onRefresh: () async => calls++, child: _list()));
      final g = await _hold(tester, 60);
      expect(_ball, findsOneWidget);
      // The ball has dropped in from the top edge, following the finger.
      final top = tester.getRect(_ball).top;
      expect(top, greaterThan(-40));
      await g.up();
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(_ball, findsNothing);
    });

    testWidgets('past the threshold it refreshes once, rests, clicks while busy, then goes', (tester) async {
      var calls = 0;
      final done = Completer<void>();
      await _pump(tester, UiPullToRefresh(onRefresh: () {
        calls++;
        return done.future;
      }, child: _list()));
      final g = await _hold(tester, 160); // well past 80, and still moving after it fired
      expect(calls, 1);
      await g.up();
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 1);
      expect(_busyBall, findsOneWidget);
      // Resting spot: its centre about 56 px below the top.
      expect(tester.getCenter(find.byType(UiPullToRefresh).first).dy, isNotNull);
      final ballCentre = tester.getCenter(_busyBall).dy - tester.getTopLeft(find.byType(UiPullToRefresh)).dy;
      expect(ballCentre, closeTo(56, 2));
      await tester.pump(const Duration(seconds: 3));
      expect(_busyBall, findsOneWidget, reason: 'stays while onRefresh runs');
      done.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_busyBall, findsNothing);
      expect(_ball, findsNothing);
      expect(calls, 1);
    });

    testWidgets('a pull, or the screen reader action, during a refresh does nothing', (tester) async {
      final handle = tester.ensureSemantics();
      var calls = 0;
      final done = Completer<void>();
      await _pump(tester, UiPullToRefresh(onRefresh: () {
        calls++;
        return done.future;
      }, child: _list()));
      await _pull(tester, 160);
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 1);
      await _pull(tester, 200);
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 1);
      _refreshAction(tester);
      await tester.pump();
      expect(calls, 1);
      done.complete();
      await tester.pumpAndSettle();
      // Afterwards a new pull refreshes again.
      await _pull(tester, 160);
      expect(calls, 2);
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('a throwing onRefresh is reported and the ball still goes away', (tester) async {
      await _pump(tester, UiPullToRefresh(onRefresh: () async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        throw StateError('offline');
      }, child: _list()));
      await _pull(tester, 160);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_busyBall, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isA<StateError>());
      await tester.pumpAndSettle();
      expect(_ball, findsNothing);
      expect(_busyBall, findsNothing);
    });

    testWidgets('screen readers get a Refresh action that runs onRefresh', (tester) async {
      final handle = tester.ensureSemantics();
      var calls = 0;
      await _pump(tester, UiPullToRefresh(onRefresh: () async => calls++, child: _list()));
      _refreshAction(tester);
      await tester.pump();
      expect(calls, 1);
      await tester.pumpAndSettle();
      handle.dispose();
    });

    for (final (name, physics) in [
      ('clamping (Android)', const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics())),
      ('bouncing (iOS)', const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())),
    ]) {
      testWidgets('works with $name physics', (tester) async {
        var calls = 0;
        await _pump(tester, UiPullToRefresh(onRefresh: () async => calls++, child: _list(physics: physics)));
        await _pull(tester, 60);
        await tester.pumpAndSettle();
        expect(calls, 0, reason: 'below the threshold');
        await _pull(tester, 160);
        expect(calls, 1);
        await tester.pumpAndSettle();
        expect(_ball, findsNothing);
      });
    }

    testWidgets('only at the top: the same pull in the middle of the list scrolls', (tester) async {
      var calls = 0;
      final c = ScrollController(initialScrollOffset: 600);
      addTearDown(c.dispose);
      await _pump(tester, UiPullToRefresh(onRefresh: () async => calls++, child: _list(controller: c)));
      await _pull(tester, 160);
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(c.offset, lessThan(600));
    });

    for (final (name, child) in [
      ('GridView', GridView.count(crossAxisCount: 3, children: [for (var i = 0; i < 60; i++) Text('$i')])),
      ('CustomScrollView', CustomScrollView(slivers: [
        SliverList.builder(itemCount: 40, itemBuilder: (_, i) => SizedBox(height: 60, child: Text('Row $i'))),
      ])),
      // A vertical list holding horizontal carousels: their sideways scrolling doesn't count.
      ('ListView of carousels', ListView(children: [
        for (var r = 0; r < 8; r++)
          SizedBox(
            height: 120,
            child: ListView(scrollDirection: Axis.horizontal, children: [for (var i = 0; i < 10; i++) SizedBox(width: 140, child: Text('$r.$i'))]),
          ),
      ])),
    ]) {
      testWidgets('works with a $name', (tester) async {
        var calls = 0;
        await _pump(tester, UiPullToRefresh(onRefresh: () async => calls++, child: child));
        await _pull(tester, 160);
        expect(calls, 1);
        await tester.pumpAndSettle();
      });
    }

    testWidgets('works inside a NestedScrollView by following the inner list', (tester) async {
      var calls = 0;
      await _pump(
        tester,
        UiPullToRefresh(
          notificationPredicate: (n) => n.depth == 1,
          onRefresh: () async => calls++,
          child: NestedScrollView(
            headerSliverBuilder: (_, _) => [const SliverToBoxAdapter(child: SizedBox(height: 120, child: Text('Header')))],
            body: _list(),
          ),
        ),
      );
      await _pull(tester, 160);
      expect(calls, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('leaves taps, long presses and double taps in the content alone', (tester) async {
      var taps = 0, longs = 0, doubles = 0;
      await _pump(
        tester,
        UiPullToRefresh(
          onRefresh: () async {},
          child: ListView(children: [
            GestureDetector(onLongPress: () => longs++, child: const SizedBox(height: 120, child: Text('Hold me'))),
            GestureDetector(onDoubleTap: () => doubles++, child: const SizedBox(height: 120, child: Text('Double'))),
            GestureDetector(onTap: () => taps++, child: const SizedBox(height: 120, child: Text('Tap'))),
            for (var i = 0; i < 20; i++) SizedBox(height: 60, child: Text('$i')),
          ]),
        ),
      );
      await tester.longPress(find.text('Hold me'));
      await tester.tap(find.text('Double'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Double'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tap'));
      await tester.pumpAndSettle();
      expect((taps, longs, doubles), (1, 1, 1));
    });

    testWidgets('reduced motion: the busy ball pulses instead of clicking', (tester) async {
      final done = Completer<void>();
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _pump(tester, UiPullToRefresh(onRefresh: () => done.future, child: _list()));
      await _pull(tester, 160);
      await tester.pump(const Duration(milliseconds: 90));
      final open = uiShutterBlades(1.47)[0];
      expect(find.byType(UiShutterLoader), paints..circle()..line(p1: open.$1, p2: open.$2));
      done.complete();
      await tester.pump();
      expect(_ball, findsNothing, reason: 'with motion off it goes at once');
    });
  });

  group('overscroll shutter ball', () {
    testWidgets('with UiOverscrollStyle.shutter, pulling past the top drops the ball, which springs back', (tester) async {
      await _pump(tester, _list(), config: const UiConfig(overscroll: UiOverscrollStyle.shutter));
      expect(find.byType(UiShutterOverscroll), findsOneWidget);
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      final g = await _hold(tester, 60);
      expect(_ball, findsOneWidget);
      final small = tester.getRect(_ball).center.dy;
      await g.moveBy(const Offset(0, 200));
      await tester.pump(const Duration(milliseconds: 16));
      final big = tester.getRect(_ball).center.dy;
      // Rubber band: it went further, but much less than the finger did, and never past its limit.
      expect(big, greaterThan(small));
      expect(big - small, lessThan(100));
      expect(big, lessThan(110));
      await g.up();
      await tester.pump(const Duration(milliseconds: 150));
      expect(_ball, findsOneWidget, reason: 'springing back, not gone at once');
      await tester.pump(const Duration(milliseconds: 320)); // a 300 ms spring from its first frame
      expect(_ball, findsNothing);
    });

    testWidgets('past the bottom it rises from the bottom edge', (tester) async {
      final c = ScrollController();
      addTearDown(c.dispose);
      await _pump(tester, _list(controller: c), config: const UiConfig(overscroll: UiOverscrollStyle.shutter));
      c.jumpTo(c.position.maxScrollExtent);
      await tester.pump();
      final g = await _hold(tester, -120, from: const Offset(195, 600));
      expect(_ball, findsOneWidget);
      expect(tester.getRect(_ball).center.dy, greaterThan(844 - 110));
      await g.up();
      await tester.pumpAndSettle();
      expect(_ball, findsNothing);
    });

    testWidgets('with the platform style there is no ball, and Android stretches (no glow)', (tester) async {
      await _pump(tester, _list());
      expect(find.byType(StretchingOverscrollIndicator), findsOneWidget);
      expect(find.byType(GlowingOverscrollIndicator), findsNothing);
      await _pull(tester, 120);
      expect(_ball, findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('horizontal scroll views keep the platform stretch with the shutter style', (tester) async {
      await _pump(
        tester,
        SizedBox(height: 200, child: ListView(scrollDirection: Axis.horizontal, children: [for (var i = 0; i < 20; i++) SizedBox(width: 100, child: Text('$i'))])),
        config: const UiConfig(overscroll: UiOverscrollStyle.shutter),
      );
      expect(find.byType(UiShutterOverscroll), findsNothing);
      expect(find.byType(StretchingOverscrollIndicator), findsOneWidget);
    });

    testWidgets('under UiPullToRefresh only one ball shows at the top', (tester) async {
      await _pump(tester, UiPullToRefresh(onRefresh: () async {}, child: _list()), config: const UiConfig(overscroll: UiOverscrollStyle.shutter));
      final g = await _hold(tester, 60);
      expect(_ball, findsOneWidget);
      await g.up();
      await tester.pumpAndSettle();
    });
  });
}

void _refreshAction(WidgetTester tester) {
  final node = tester.getSemantics(find.byType(UiPullToRefresh));
  final id = CustomSemanticsAction.getIdentifier(const CustomSemanticsAction(label: 'Refresh'));
  expect(node.getSemanticsData().customSemanticsActionIds, contains(id));
  tester.binding.pipelineOwner.semanticsOwner!.performAction(node.id, SemanticsAction.customAction, id);
}
