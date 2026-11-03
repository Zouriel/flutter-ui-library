import 'dart:ui' show GestureSettings;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

void main() {
  late List<String> got;

  Widget host({bool enabled = true, Widget? child}) => UiPinch(
        enabled: enabled,
        onPinchIn: () => got.add('in'),
        onPinchOut: () => got.add('out'),
        child: SizedBox(width: 390, height: 600, child: child ?? const ColoredBox(color: Color(0x00000000))),
      );

  /// A finger at (x, 300), moved by absolute x so a position reads as the distance from x = 100.
  Future<TestGesture> down(WidgetTester tester, double x, int pointer) => tester.startGesture(Offset(x, 300), pointer: pointer);
  Future<void> to(TestGesture finger, double x) => finger.moveTo(Offset(x, 300));

  /// Two fingers 100 apart; the second's x is 100 + the distance.
  Future<List<TestGesture>> pinch(WidgetTester tester) async {
    final a = await down(tester, 100, 11);
    final b = await down(tester, 200, 12);
    return [a, b];
  }

  setUp(() => got = []);

  testWidgets('steps out at exactly 1.25x the baseline, and not before', (tester) async {
    await pumpUi(tester, host());
    final f = await pinch(tester);
    await to(f[1], 224);
    expect(got, isEmpty);
    await to(f[1], 225);
    expect(got, ['out']);
  });

  testWidgets('steps in at exactly 0.8x the baseline, and not before', (tester) async {
    await pumpUi(tester, host());
    final f = await pinch(tester);
    await to(f[1], 181);
    expect(got, isEmpty);
    await to(f[1], 180);
    expect(got, ['in']);
  });

  testWidgets('measures diagonally, not along one axis', (tester) async {
    await pumpUi(tester, host());
    final f = await pinch(tester);
    await f[1].moveTo(const Offset(200, 400)); // x has not changed; about 141 apart
    expect(got, ['out']);
  });

  testWidgets('takes several steps in one long pinch, each from the last', (tester) async {
    await pumpUi(tester, host());
    final f = await pinch(tester);
    await to(f[1], 225); // baseline 125
    await to(f[1], 250); // 1.2x: not yet
    expect(got, ['out']);
    await to(f[1], 257); // 1.256x
    expect(got, ['out', 'out']);
    await to(f[1], 226); // 0.803x of 157: not yet
    expect(got, ['out', 'out']);
    await to(f[1], 225); // 0.796x
    expect(got, ['out', 'out', 'in']);
  });

  testWidgets('onPinch reports each step with its direction and the fingers\' midpoint, before onPinchIn/Out', (tester) async {
    final steps = <UiPinchStep>[];
    await pumpUi(
      tester,
      UiPinch(
        onPinch: (s) {
          steps.add(s);
          got.add(s.apart ? 'step out' : 'step in');
        },
        onPinchIn: () => got.add('in'),
        onPinchOut: () => got.add('out'),
        child: const SizedBox(width: 390, height: 600),
      ),
    );
    final f = await pinch(tester);
    await to(f[1], 225);
    expect(steps.single.apart, isTrue);
    expect(steps.single.focal, const Offset(162.5, 300));
    await to(f[0], 145); // 80 apart of 125: in, midpoint 185
    expect(steps.last.apart, isFalse);
    expect(steps.last.focal, const Offset(185, 300));
    expect(got, ['step out', 'out', 'step in', 'in']);
    await f[0].up();
    await f[1].up();
  });

  testWidgets('a step in also becomes the new baseline', (tester) async {
    await pumpUi(tester, host());
    final f = await pinch(tester);
    await to(f[1], 180); // 80, the new baseline
    await to(f[1], 179); // 79 is 0.8x of the old 100, not of 80
    expect(got, ['in']);
    await to(f[1], 164); // 64 is 0.8x of 80
    expect(got, ['in', 'in']);
  });

  testWidgets('fires once for one big jump, and stays quiet until the fingers move on from it', (tester) async {
    await pumpUi(tester, host());
    final f = await pinch(tester);
    await to(f[1], 380);
    await f[1].moveTo(const Offset(380, 300.5));
    expect(got, ['out']);
  });

  testWidgets('either finger moving counts', (tester) async {
    await pumpUi(tester, host());
    final f = await pinch(tester);
    await to(f[0], 75); // 125 apart
    expect(got, ['out']);
  });

  testWidgets('ignores a third finger, however far it goes', (tester) async {
    await pumpUi(tester, host());
    final f = await pinch(tester);
    final c = await down(tester, 210, 13);
    await to(c, 380);
    await to(c, 2);
    expect(got, isEmpty);
    await to(f[1], 225);
    expect(got, ['out']);
  });

  testWidgets('carries on from a fresh baseline when one of the two lifts and a third remains', (tester) async {
    await pumpUi(tester, host());
    final f = await pinch(tester);
    final c = await down(tester, 300, 13);
    await f[0].up(); // the pair is now b and c: 100 apart, still no step
    expect(got, isEmpty);
    await to(c, 324); // 124 of 100
    expect(got, isEmpty);
    await to(c, 325);
    expect(got, ['out']);
  });

  testWidgets('a fresh baseline means a wide new pair can not read as a step', (tester) async {
    await pumpUi(tester, host());
    final f = await pinch(tester);
    final c = await down(tester, 380, 13);
    await f[0].up(); // b and c are 180 apart, 1.8x the old baseline
    await to(c, 381);
    expect(got, isEmpty);
  });

  testWidgets('resets when fewer than two fingers remain', (tester) async {
    await pumpUi(tester, host());
    final f = await pinch(tester);
    await f[1].up();
    await to(f[0], 380);
    expect(got, isEmpty);
    // The next pinch measures from its own landing, not from the first one's 100.
    await to(f[0], 100);
    final d = await down(tester, 300, 14); // 200 apart
    await to(d, 349); // 249
    expect(got, isEmpty);
    await to(d, 350);
    expect(got, ['out']);
  });

  testWidgets('a cancelled pointer ends the pinch too', (tester) async {
    await pumpUi(tester, host());
    final f = await pinch(tester);
    await f[1].cancel();
    await to(f[0], 380);
    expect(got, isEmpty);
  });

  testWidgets('two fingers landing on one spot wait for a distance before measuring', (tester) async {
    await pumpUi(tester, host());
    final a = await down(tester, 100, 11);
    final b = await down(tester, 100, 12);
    await to(b, 140); // becomes the baseline, not a step
    expect(got, isEmpty);
    await to(b, 150); // 50 of 40
    expect(got, ['out']);
    await a.up();
    await b.up();
  });

  testWidgets('a mouse is not a finger', (tester) async {
    await pumpUi(tester, host());
    final mouse = await tester.startGesture(const Offset(100, 300), kind: PointerDeviceKind.mouse, pointer: 21);
    final b = await down(tester, 200, 12);
    await to(b, 380);
    await mouse.up();
    await b.up();
    expect(got, isEmpty);
  });

  testWidgets('does nothing while disabled, and lets go of a pinch it is disabled during', (tester) async {
    await pumpUi(tester, host(enabled: false));
    var f = await pinch(tester);
    await to(f[1], 380);
    expect(got, isEmpty);
    await f[0].up();
    await f[1].up();

    await pumpUi(tester, host());
    f = await pinch(tester);
    await to(f[1], 225);
    expect(got, ['out']);
    await pumpUi(tester, host(enabled: false));
    await to(f[1], 380);
    expect(got, ['out']);
    await f[0].up();
    await f[1].up();
  });

  testWidgets('keeps measuring when the child under the fingers is replaced mid-pinch', (tester) async {
    Widget grid(int columns) => UiPinch(
          onPinchOut: () => got.add('out'),
          child: SizedBox(width: 390, height: 600, child: ColoredBox(key: ValueKey(columns), color: const Color(0x00000000))),
        );
    await pumpUi(tester, grid(3));
    final f = await pinch(tester);
    await to(f[1], 225);
    await pumpUi(tester, grid(4));
    await to(f[1], 257);
    expect(got, ['out', 'out']);
  });

  testWidgets('one finger still scrolls at a phone touch slop, and two fingers do not stop the steps', (tester) async {
    // A real Android device reports about 8dp, where tests default to 18 (see AGENTS.md, 2026-10-14).
    tester.view.gestureSettings = GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
    addTearDown(tester.view.resetGestureSettings);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await pumpUi(
      tester,
      host(
        child: ListView.builder(controller: scroll, itemExtent: 100, itemCount: 40, itemBuilder: (_, i) => Text('Row $i')),
      ),
    );

    final one = await tester.startGesture(const Offset(200, 500), pointer: 31);
    await one.moveBy(const Offset(0, -20));
    await tester.pump();
    await one.moveBy(const Offset(0, -200));
    await tester.pump();
    expect(scroll.offset, greaterThan(100));
    expect(got, isEmpty);
    await one.up();
    await tester.pumpAndSettle();

    final f = await pinch(tester);
    await to(f[1], 225);
    await tester.pump();
    expect(got, ['out']);
    await f[0].up();
    await f[1].up();
    await tester.pumpAndSettle();
  });

  testWidgets('hears the second finger inside a scroll view that took the first', (tester) async {
    // The scroll view's only recognizer wins the first finger at once and ignores pointers for
    // everything inside it, so the second is never hit-tested to the Listener.
    final tall = ListView(children: [SizedBox(height: 700, child: host()), const SizedBox(height: 700)]);
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(home: tall));
    await tester.pump();
    final f = await pinch(tester);
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(position.activity!.shouldIgnorePointer, isTrue, reason: 'the condition this test is about');
    await to(f[1], 224);
    expect(got, isEmpty);
    await to(f[1], 225);
    expect(got, ['out']);
    await f[0].up();
    await f[1].up();
    await tester.pumpAndSettle();
  });

  testWidgets('does not count a finger that lands outside the widget', (tester) async {
    await tester.pumpWidget(UiApp(home: Align(alignment: Alignment.topLeft, child: SizedBox(width: 390, height: 300, child: host()))));
    final a = await tester.startGesture(const Offset(100, 100), pointer: 11);
    final outside = await tester.startGesture(const Offset(200, 500), pointer: 15);
    await outside.moveTo(const Offset(380, 500));
    await a.moveTo(const Offset(5, 280));
    expect(got, isEmpty);
    // The same widget does answer a second finger that lands inside it.
    final inside = await tester.startGesture(const Offset(105, 280), pointer: 16);
    await inside.moveTo(const Offset(205, 280));
    expect(got, ['out']);
    await a.up();
    await outside.up();
    await inside.up();
  });

  testWidgets('stops watching pointers when removed mid-pinch, and when the fingers lift', (tester) async {
    final router = GestureBinding.instance.pointerRouter;
    await pumpUi(tester, host());
    final idle = router.debugGlobalRouteCount;
    final f = await pinch(tester);
    expect(router.debugGlobalRouteCount, idle + 1);
    await f[0].up();
    expect(router.debugGlobalRouteCount, idle + 1);
    await f[1].up();
    expect(router.debugGlobalRouteCount, idle);

    final g = await pinch(tester);
    await pumpUi(tester, const SizedBox());
    expect(router.debugGlobalRouteCount, idle);
    await to(g[1], 380);
    await g[0].up();
    await g[1].up();
    expect(got, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an enclosing UiSwipe still answers one finger', (tester) async {
    await pumpUi(
      tester,
      UiSwipe(onSwipeLeft: () => got.add('swipe'), child: host()),
    );
    await tester.dragFrom(const Offset(300, 300), const Offset(-150, 0));
    expect(got, ['swipe']);
  });
}
