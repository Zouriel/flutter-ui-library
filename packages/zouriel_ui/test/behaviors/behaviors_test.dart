import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import '../media/media_helpers.dart';

void main() {
  group('UiGestures', () {
    test('isSwipe: distance scales with width, flicks count, vertical never does', () {
      expect(UiGestures.isSwipe(40, 5, 1000, 100), isTrue); // floor 32
      expect(UiGestures.isSwipe(30, 5, 1000, 100), isFalse);
      expect(UiGestures.isSwipe(-72, 5, 1000, 1000), isTrue); // capped at 72
      expect(UiGestures.isSwipe(25, 5, 50, 1000), isTrue); // 0.5 px/ms flick
      expect(UiGestures.isSwipe(60, 61, 50, 100), isFalse);
    });

    test('resist and clampOffset', () {
      expect(UiGestures.resist(100, 300, blocked: false), 100);
      expect(UiGestures.resist(100, 300, blocked: true), 25);
      expect(UiGestures.resist(500, 300, blocked: false), 300);
      expect(UiGestures.clampOffset(const Offset(500, -500), const Size(100, 100), const Size(100, 100), 2), const Offset(50, -50));
      expect(UiGestures.clampOffset(const Offset(10, 10), const Size(100, 100), const Size(200, 200), 1), Offset.zero);
    });
  });

  group('UiSwipe', () {
    late List<String> got;
    Widget host({Widget? child, bool mouse = false}) => UiSwipe(
          mouse: mouse,
          onSwipeLeft: () => got.add('left'),
          onSwipeRight: () => got.add('right'),
          child: SizedBox(width: 390, height: 400, child: child ?? const ColoredBox(color: Color(0x00000000))),
        );
    setUp(() => got = []);

    testWidgets('a sideways drag fires once, while the finger is still moving', (tester) async {
      await pumpUi(tester, host());
      final g = await tester.startGesture(const Offset(200, 200));
      for (var i = 0; i < 6; i++) {
        await g.moveBy(const Offset(-15, 0), timeStamp: Duration(milliseconds: 100 * (i + 1)));
      }
      expect(got, ['left']);
      await g.up();
      await tester.dragFrom(const Offset(150, 200), const Offset(120, 4));
      expect(got, ['left', 'right']);
    });

    testWidgets('declines vertical drags, edge starts, a second finger and the mouse', (tester) async {
      await pumpUi(tester, host());
      await tester.dragFrom(const Offset(200, 100), const Offset(40, 200));
      await tester.dragFrom(const Offset(10, 200), const Offset(200, 0));
      final a = await tester.startGesture(const Offset(200, 200));
      final b = await tester.startGesture(const Offset(250, 250), pointer: 9);
      await a.moveBy(const Offset(-150, 0));
      await a.up();
      await b.up();
      await tester.dragFrom(const Offset(200, 200), const Offset(-150, 0), kind: PointerDeviceKind.mouse);
      expect(got, isEmpty);
      await pumpUi(tester, host(mouse: true));
      await tester.dragFrom(const Offset(200, 200), const Offset(-150, 0), kind: PointerDeviceKind.mouse);
      expect(got, ['left']);
    });

    testWidgets('a sideways scroller under the finger and UiNoSwipe keep their drags', (tester) async {
      await pumpUi(tester, host(child: Column(children: [
        SizedBox(height: 100, child: ListView(scrollDirection: Axis.horizontal, children: [for (var i = 0; i < 20; i++) SizedBox(width: 80, child: Text('$i'))])),
        const UiNoSwipe(child: SizedBox(height: 100, width: 390)),
      ])));
      await tester.dragFrom(const Offset(200, 50), const Offset(-150, 0));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(200, 150), const Offset(-150, 0));
      expect(got, isEmpty);
    });
  });

  testWidgets('UiInfiniteScroll fires near the end and re-arms above the line', (tester) async {
    var hits = 0;
    final c = ScrollController();
    addTearDown(c.dispose);
    await pumpUi(tester, SizedBox(height: 300, width: 200, child: UiInfiniteScroll(
      threshold: 100,
      onScrolledToEnd: () => hits++,
      child: ListView(controller: c, children: [for (var i = 0; i < 30; i++) SizedBox(height: 50, child: Text('$i'))]),
    )));
    c.jumpTo(1000); // extentAfter = 1500 - 300 - 1000 = 200
    await tester.pump();
    expect(hits, 0);
    c.jumpTo(1150);
    c.jumpTo(1180);
    await tester.pump();
    expect(hits, 1, reason: 'once, not on every scroll inside the threshold');
    c.jumpTo(500);
    c.jumpTo(1200);
    expect(hits, 2);
  });

  testWidgets('UiInfiniteScroll re-arms when new rows arrive, so a jump to the new end loads again', (tester) async {
    var hits = 0;
    var count = 30;
    final c = ScrollController();
    addTearDown(c.dispose);
    late StateSetter set;
    await pumpUi(tester, SizedBox(height: 300, width: 200, child: StatefulBuilder(builder: (context, s) {
      set = s;
      return UiInfiniteScroll(
        threshold: 100,
        onScrolledToEnd: () => hits++,
        child: ListView(controller: c, children: [for (var i = 0; i < count; i++) SizedBox(height: 50, child: Text('$i'))]),
      );
    })));
    c.jumpTo(1200); // the end
    await tester.pump();
    expect(hits, 1);
    // The load adds ten rows while the reader is still at the old end (now 500px from the bottom).
    set(() => count = 40);
    await tester.pumpAndSettle();
    expect(hits, 1);
    // One big step lands right at the new end, never passing above the line in between.
    c.jumpTo(1700);
    await tester.pump();
    expect(hits, 2);
    // Rows that still leave the reader at the end load again at once.
    set(() => count = 41);
    await tester.pumpAndSettle();
    expect(hits, 3);
  });

  testWidgets('UiScrollFade fades only the edges with more content past them', (tester) async {
    final c = ScrollController();
    addTearDown(c.dispose);
    Widget strip(double w) => SizedBox(width: 200, height: 40, child: UiScrollFade(
          child: SingleChildScrollView(controller: c, scrollDirection: Axis.horizontal, child: SizedBox(width: w, height: 40)),
        ));
    await pumpUi(tester, strip(150));
    await tester.pumpAndSettle();
    expect(find.byType(ShaderMask), findsNothing, reason: 'fits: no fade');
    await pumpUi(tester, strip(600));
    await tester.pumpAndSettle();
    expect(find.byType(ShaderMask), findsOneWidget, reason: 'more to the right');
    c.jumpTo(400);
    await tester.pumpAndSettle();
    expect(find.byType(ShaderMask), findsOneWidget, reason: 'more to the left');
    expect(c.offset, 400, reason: 'the mask coming and going keeps the scroll position');
  });

  testWidgets('UiVirtualList builds only the rows in view', (tester) async {
    await pumpUi(tester, SizedBox(width: 200, child: UiVirtualList<int>(
      items: List.generate(10000, (i) => i),
      itemExtent: 32,
      height: 320,
      itemBuilder: (context, item, i) => Text('Row $item'),
    )));
    expect(tester.getSize(find.byType(UiVirtualList<int>)).height, 320);
    expect(find.text('Row 0'), findsOneWidget);
    expect(find.text('Row 9999'), findsNothing);
    expect(find.byType(Text).evaluate().length, lessThan(30));
  });

  testWidgets('UiIntersect reports the first state, then changes; once stops', (tester) async {
    final seen = <bool>[], onceSeen = <bool>[];
    final c = ScrollController();
    addTearDown(c.dispose);
    await pumpUi(tester, SizedBox(height: 400, width: 200, child: SingleChildScrollView(controller: c, child: Column(children: [
      const SizedBox(height: 600),
      UiIntersect(onChange: seen.add, child: const SizedBox(height: 50)),
      UiIntersect(once: true, onChange: onceSeen.add, child: const SizedBox(height: 50)),
      const SizedBox(height: 800),
    ]))));
    expect(seen, [false]);
    c.jumpTo(300);
    await tester.pump();
    expect(seen, [false, true]);
    expect(onceSeen, [false, true]);
    c.jumpTo(0);
    await tester.pump();
    c.jumpTo(300);
    await tester.pump();
    expect(seen, [false, true, false, true]);
    expect(onceSeen, [false, true]);
  });

  testWidgets('UiIntersect threshold needs that share visible', (tester) async {
    final seen = <bool>[];
    final c = ScrollController();
    addTearDown(c.dispose);
    await pumpUi(tester, SizedBox(height: 400, width: 200, child: ListView(controller: c, children: [
      const SizedBox(height: 400),
      UiIntersect(threshold: 0.5, onChange: seen.add, child: const SizedBox(height: 100)),
      const SizedBox(height: 800),
    ])));
    c.jumpTo(40); // 40% in view
    await tester.pump();
    expect(seen, [false]);
    c.jumpTo(60);
    await tester.pump();
    expect(seen, [false, true]);
  });

  testWidgets('UiCopyToClipboard copies, flips copied for 1.5s and announces', (tester) async {
    String? clip;
    final announced = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clip = (call.arguments as Map)['text'] as String;
      return null;
    });
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (msg) async {
      announced.add(((msg as Map)['data'] as Map)['message'] as String);
      return null;
    });
    final copied = <String>[];
    await pumpUi(tester, UiCopyToClipboard(
      text: 'npm i @zouriel/ui',
      onCopied: copied.add,
      builder: (context, isCopied, copy) => UiButton(label: isCopied ? 'Copied' : 'Copy', onPressed: copy),
    ));
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(clip, 'npm i @zouriel/ui');
    expect(copied, ['npm i @zouriel/ui']);
    expect(find.text('Copied'), findsOneWidget);
    expect(announced, ['Copied to clipboard']);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('UiResizeObserver reports the first size and changes', (tester) async {
    final sizes = <Size>[];
    var w = 100.0;
    late StateSetter set;
    await pumpUi(tester, StatefulBuilder(builder: (context, s) {
      set = s;
      return UiResizeObserver(onResize: sizes.add, child: SizedBox(width: w, height: 40));
    }));
    expect(sizes, [const Size(100, 40)]);
    set(() => w = 150);
    await tester.pump();
    await tester.pump();
    expect(sizes, [const Size(100, 40), const Size(150, 40)]);
  });

  testWidgets('UiRipple spreads on press and is skipped under reduced motion', (tester) async {
    await pumpUi(tester, const UiRipple(child: SizedBox(width: 100, height: 40)));
    await tester.tap(find.byType(UiRipple), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(UiRipple), paints..circle());
    await tester.pumpAndSettle();
    expect(find.byType(UiRipple), isNot(paints..circle()));

    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: UiApp(home: const Align(alignment: Alignment.topLeft, child: UiRipple(child: SizedBox(width: 100, height: 40)))),
    ));
    await tester.tap(find.byType(UiRipple), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(UiRipple), isNot(paints..circle()));
  });

  testWidgets('UiDragMove moves by drag and keys, inside its bounds', (tester) async {
    var at = Offset.zero;
    await pumpUi(tester, StatefulBuilder(builder: (context, set) => UiDragMove(
      offset: at,
      bounds: const Rect.fromLTWH(0, 0, 200, 100),
      onChanged: (o) => set(() => at = o),
      child: const SizedBox(width: 50, height: 50),
    )));
    await tester.drag(find.byType(UiDragMove), const Offset(60, 30));
    await tester.pump();
    expect(at.dx, greaterThan(30));
    await tester.drag(find.descendant(of: find.byType(UiDragMove), matching: find.byType(SizedBox)), const Offset(500, 500));
    await tester.pump();
    expect(at, const Offset(200, 100));
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(at, const Offset(192, 100));
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  testWidgets('golden: ripple mid-press, focused draggable', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await expectThemedGoldenAfter(tester, 'behaviors', height: 150, (context) {
      final t = context.ui;
      return Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 24, children: [
        UiRipple(
          borderRadius: BorderRadius.circular(t.radius),
          color: t.primary,
          child: Container(
            width: 160,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
            child: const UiText('Press me'),
          ),
        ),
        UiDragMove(
          offset: const Offset(10, 20),
          onChanged: (_) {},
          child: Container(
            padding: EdgeInsets.all(t.space3),
            decoration: BoxDecoration(color: t.surfaceRaised, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
            child: const UiText('Drag me'),
          ),
        ),
      ]);
    }, before: (tester) async {
      await tester.tapAt(const Offset(16 + 50, 16 + 30));
      await tester.tapAt(const Offset(390 + 16 + 110, 16 + 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
    });
  });
}
