import 'dart:ui' show GestureSettings;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// 0.44.0: UiSwipeScreens, a chat with a map to its right.

const _w = 390.0, _h = 844.0;

class _Host {
  int index = 0;
  bool follow = true;
  bool animate = false;
  bool drawer = true, third = false;
  TextDirection dir = TextDirection.ltr;
  final changes = <int>[];
  final announced = <String>[];
  int drawerDrags = 0, mapPans = 0, counter = 0;
  bool? mapTickers;
  late StateSetter set;
  final key = GlobalKey<UiSwipeScreensState>();
  final mapFocus = FocusNode(debugLabel: 'map field');
  final scroll = ScrollController();
}

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: () => setState(() => n++), child: SizedBox(height: 60, child: Text('Count $n')));
}

Widget _chat(_Host h) => Stack(children: [
      Column(children: [
        const _Counter(),
        Expanded(
          child: ListView(controller: h.scroll, children: [for (var i = 0; i < 60; i++) SizedBox(height: 48, child: Text('Message $i'))]),
        ),
      ]),
      // The app's own drawer edge, as the chat's sidebar swipe.
      if (h.drawer)
        PositionedDirectional(
        start: 0,
        top: 0,
        bottom: 0,
        width: 20,
        child: GestureDetector(behavior: HitTestBehavior.translucent, onHorizontalDragStart: (_) => h.drawerDrags++),
      ),
    ]);

Widget _map(_Host h) => Builder(builder: (context) {
      h.mapTickers = TickerMode.valuesOf(context).enabled;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => h.mapPans++,
        child: Column(children: [
          const Text('Map content'),
          Focus(focusNode: h.mapFocus, child: const SizedBox(width: 40, height: 40)),
        ]),
      );
    });

Future<_Host> _pump(WidgetTester tester, {TextDirection dir = TextDirection.ltr, bool animate = false, bool drawer = true, bool third = false}) async {
  final h = _Host()
    ..drawer = drawer
    ..third = third
    ..dir = dir
    ..animate = animate;
  tester.view.physicalSize = const Size(_w, _h) * tester.view.devicePixelRatio;
  tester.view.gestureSettings = GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
  addTearDown(tester.view.reset);
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (msg) async {
    final data = (msg as Map)['data'];
    if (data is Map && data['message'] is String) h.announced.add(data['message'] as String);
    return null;
  });
  await tester.pumpWidget(StatefulBuilder(builder: (context, set) {
    h.set = set;
    return UiApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: !h.animate),
          child: Directionality(
            textDirection: h.dir,
            child: UiSwipeScreens(
              key: h.key,
              index: h.index,
              onIndexChanged: (i) {
                h.changes.add(i);
                if (h.follow) set(() => h.index = i);
              },
              screens: [
                UiSwipeScreen(label: 'Chat', child: _chat(h)),
                UiSwipeScreen(label: 'Map', edgeSwipeOnly: true, child: _map(h)),
                if (h.third) const UiSwipeScreen(label: 'Profile', child: Center(child: Text('Profile content'))),
              ],
            ),
          ),
        ),
      ),
    );
  }));
  await tester.pump();
  return h;
}

Finder _mapRoot() => find.ancestor(of: find.text('Map content'), matching: find.byType(GestureDetector)).first;

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('a slow drag past half the width moves to the next screen; under half springs back', (tester) async {
    final h = await _pump(tester);
    await tester.timedDragFrom(const Offset(300, 400), const Offset(-_w * 0.3, 0), const Duration(seconds: 1));
    await _settle(tester);
    expect(h.key.currentState!.index, 0);
    expect(h.changes, isEmpty);
    await tester.timedDragFrom(const Offset(300, 400), const Offset(-_w * 0.6, 0), const Duration(seconds: 2));
    await _settle(tester);
    expect(h.key.currentState!.index, 1);
    expect(h.changes, [1]);
    expect(h.key.currentState!.position, 1);
  });

  testWidgets('a short fast fling moves one screen; a slow short drag of the same length does not', (tester) async {
    final h = await _pump(tester);
    await tester.timedDragFrom(const Offset(300, 400), const Offset(-80, 0), const Duration(milliseconds: 800));
    await _settle(tester);
    expect(h.key.currentState!.index, 0);
    await tester.flingFrom(const Offset(300, 400), const Offset(-80, 0), 1200);
    await _settle(tester);
    expect(h.key.currentState!.index, 1);
    expect(h.changes, [1]);
  });

  testWidgets('the screens follow the finger, clamped at the ends', (tester) async {
    final sem = tester.ensureSemantics();
    final h = await _pump(tester);
    final g = await tester.startGesture(const Offset(300, 400));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(-10, 0));
      await tester.pump();
    }
    // Past the slop, the screens moved with the finger.
    final p = h.key.currentState!.position;
    // Half in view, but not the current screen: still not read out.
    expect(find.bySemanticsLabel('Map content'), findsNothing);
    expect(find.bySemanticsLabel('Count 0'), findsOneWidget);
    expect(p, greaterThan(70 / _w));
    expect(p, lessThan(100 / _w + 1e-9));
    expect(tester.getTopLeft(_mapRoot()).dx, closeTo(_w - p * _w, 0.5));
    // Back past the start: no overscroll before the first screen.
    for (var i = 0; i < 30; i++) {
      await g.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    expect(h.key.currentState!.position, 0);
    await g.up();
    await _settle(tester);
    expect(h.key.currentState!.index, 0);
    sem.dispose();
  });

  testWidgets('a drag from the first screen\'s leading edge is left to the app (its drawer)', (tester) async {
    final h = await _pump(tester);
    await tester.timedDragFrom(const Offset(10, 400), const Offset(200, 0), const Duration(milliseconds: 600));
    await _settle(tester);
    expect(h.drawerDrags, 1);
    await tester.timedDragFrom(const Offset(10, 400), const Offset(-250, 0), const Duration(milliseconds: 600));
    await _settle(tester);
    expect(h.key.currentState!.index, 0);
    expect(h.changes, isEmpty);
    // Without the app's own edge detector the band is still left alone.
    h.set(() => h.drawer = false);
    await tester.pump();
    await tester.timedDragFrom(const Offset(10, 400), const Offset(-250, 0), const Duration(milliseconds: 600));
    await _settle(tester);
    expect(h.key.currentState!.index, 0);
    expect(h.changes, isEmpty);
    // Just past the band, the same drag swipes.
    await tester.timedDragFrom(const Offset(40, 400), const Offset(-250, 0), const Duration(milliseconds: 600));
    await _settle(tester);
    expect(h.key.currentState!.index, 1);
  });

  testWidgets('vertical (and mostly vertical) drags scroll the screen\'s content, not the screens', (tester) async {
    final h = await _pump(tester);
    await tester.timedDragFrom(const Offset(250, 600), const Offset(-40, -300), const Duration(milliseconds: 500));
    await _settle(tester);
    expect(h.scroll.offset, greaterThan(200));
    expect(h.key.currentState!.index, 0);
    expect(h.key.currentState!.position, 0);
    // Over content that doesn't scroll, a mostly vertical drag doesn't move the screens either,
    // though it passes the horizontal slop first.
    final g = await tester.startGesture(const Offset(250, 30));
    for (var i = 0; i < 12; i++) {
      await g.moveBy(const Offset(-5, 8));
      await tester.pump();
      expect(h.key.currentState!.position, 0);
    }
    await g.up();
    await _settle(tester);
    // A clearly sideways drag still swipes even a little off level.
    await tester.timedDragFrom(const Offset(300, 600), const Offset(-250, 60), const Duration(milliseconds: 600));
    await _settle(tester);
    expect(h.key.currentState!.index, 1);
  });

  testWidgets('edgeSwipeOnly: drags go to the content, only a drag from its leading edge swipes back', (tester) async {
    final h = await _pump(tester);
    h.set(() => h.index = 1);
    await _settle(tester);
    expect(h.key.currentState!.index, 1);
    await tester.timedDragFrom(const Offset(150, 400), const Offset(250, 0), const Duration(milliseconds: 500));
    await _settle(tester);
    expect(h.mapPans, 1);
    expect(h.key.currentState!.index, 1);
    // From the edge, the other way: nothing (only back).
    await tester.timedDragFrom(const Offset(10, 400), const Offset(-200, 0), const Duration(milliseconds: 500));
    await _settle(tester);
    expect(h.key.currentState!.index, 1);
    expect(h.mapPans, 1);
    await tester.timedDragFrom(const Offset(10, 400), const Offset(250, 0), const Duration(milliseconds: 500));
    await _settle(tester);
    expect(h.key.currentState!.index, 0);
    expect(h.changes, [0]);
    expect(h.mapPans, 1);
  });

  testWidgets('RTL: the next screen is on the left and a rightward drag goes to it; its edge strip is on the right', (tester) async {
    final h = await _pump(tester, dir: TextDirection.rtl);
    final g = await tester.startGesture(const Offset(100, 400));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    expect(tester.getTopRight(_mapRoot()).dx, closeTo(h.key.currentState!.position * _w, 0.5));
    await g.up();
    await _settle(tester);
    expect(h.key.currentState!.index, 0);
    // The leading edge is the right one.
    await tester.timedDragFrom(const Offset(_w - 10, 400), const Offset(-200, 0), const Duration(milliseconds: 500));
    await _settle(tester);
    expect(h.drawerDrags, 1);
    expect(h.key.currentState!.index, 0);
    await tester.timedDragFrom(const Offset(100, 400), const Offset(250, 0), const Duration(milliseconds: 600));
    await _settle(tester);
    expect(h.key.currentState!.index, 1);
    await tester.timedDragFrom(const Offset(_w - 10, 400), const Offset(-250, 0), const Duration(milliseconds: 500));
    await _settle(tester);
    expect(h.key.currentState!.index, 0);
  });

  testWidgets('a new index animates there without calling onIndexChanged; reduced motion jumps', (tester) async {
    final h = await _pump(tester, animate: true);
    h.set(() => h.index = 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final mid = h.key.currentState!.position;
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));
    await _settle(tester);
    expect(h.key.currentState!.position, 1);
    expect(h.changes, isEmpty);
    h.set(() {
      h.animate = false;
      h.index = 0;
    });
    await tester.pump();
    expect(h.key.currentState!.position, 0);
  });

  testWidgets('off-screen screens stay alive but are hidden from screen readers, focus and tickers; the change is announced', (tester) async {
    final sem = tester.ensureSemantics();
    final h = await _pump(tester);
    expect(find.bySemanticsLabel('Map content'), findsNothing);
    expect(find.bySemanticsLabel('Count 0'), findsOneWidget);
    expect(h.mapTickers, isFalse);
    h.mapFocus.requestFocus();
    await tester.pump();
    expect(h.mapFocus.hasFocus, isFalse);
    await tester.tap(find.text('Count 0'));
    await tester.pump();

    await tester.timedDragFrom(const Offset(300, 400), const Offset(-300, 0), const Duration(milliseconds: 800));
    await _settle(tester);
    expect(h.announced, ['Map']);
    expect(find.bySemanticsLabel('Map content'), findsOneWidget);
    expect(find.bySemanticsLabel('Count 1'), findsNothing);
    expect(h.mapTickers, isTrue);
    h.mapFocus.requestFocus();
    await tester.pump();
    expect(h.mapFocus.hasFocus, isTrue);

    await tester.timedDragFrom(const Offset(10, 400), const Offset(300, 0), const Duration(milliseconds: 800));
    await _settle(tester);
    expect(h.announced, ['Map', 'Chat']);
    expect(h.mapFocus.hasFocus, isFalse);
    // The chat kept its state.
    expect(find.text('Count 1'), findsOneWidget);
    sem.dispose();
  });

  testWidgets('without the parent following, the swiped-to screen stays', (tester) async {
    final h = await _pump(tester);
    h.follow = false;
    await tester.timedDragFrom(const Offset(300, 400), const Offset(-300, 0), const Duration(milliseconds: 800));
    await _settle(tester);
    expect(h.changes, [1]);
    expect(h.key.currentState!.index, 1);
    expect(find.text('Map content').hitTestable(), findsOneWidget);
  });
  testWidgets('with a real UiMap on an edgeSwipeOnly screen: a drag pans the map, the edge swipes back', (tester) async {
    tester.view.physicalSize = const Size(_w, _h) * tester.view.devicePixelRatio;
    tester.view.gestureSettings = GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
    addTearDown(tester.view.reset);
    final map = GlobalKey<UiMapState>();
    final key = GlobalKey<UiSwipeScreensState>();
    await tester.pumpWidget(UiApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: UiSwipeScreens(key: key, index: 1, screens: [
            const UiSwipeScreen(label: 'Chat', child: Text('Chat')),
            UiSwipeScreen(label: 'Map', edgeSwipeOnly: true, child: UiMap(key: map, fill: true, tileProvider: UiMapBlankTiles())),
          ]),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    final before = map.currentState!.controller.camera.center;
    await tester.timedDragFrom(const Offset(200, 500), const Offset(150, 0), const Duration(milliseconds: 500));
    await _settle(tester);
    expect(map.currentState!.controller.camera.center, isNot(before));
    expect(key.currentState!.index, 1);
    final moved = map.currentState!.controller.camera.center;
    await tester.timedDragFrom(const Offset(8, 500), const Offset(250, 0), const Duration(milliseconds: 500));
    await _settle(tester);
    expect(key.currentState!.index, 0);
    expect(map.currentState!.controller.camera.center, moved);
  });
  testWidgets('edgeSwipeOnly with a screen after it: an edge drag only goes back, never on', (tester) async {
    final h = await _pump(tester, third: true);
    h.set(() => h.index = 1);
    await _settle(tester);
    final g = await tester.startGesture(const Offset(10, 400));
    for (var i = 0; i < 20; i++) {
      await g.moveBy(const Offset(-12, 0));
      await tester.pump();
    }
    expect(h.key.currentState!.position, 1);
    await g.up();
    await _settle(tester);
    expect(h.key.currentState!.index, 1);
    await tester.flingFrom(const Offset(10, 400), const Offset(-100, 0), 1500);
    await _settle(tester);
    expect(h.key.currentState!.index, 1);
    expect(h.changes, isEmpty);
    expect(h.mapPans, 0);
  });
}
