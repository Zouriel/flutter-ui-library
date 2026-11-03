import 'dart:ui' show GestureSettings;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

const _shapes = [1.0, 1.5, 0.66, 1.2, 0.8, 1.33, 0.75];
double ratioAt(int i) => _shapes[(i * 5 + i ~/ 7) % _shapes.length];
List<double> ratios(int n) => [for (var i = 0; i < n; i++) ratioAt(i)];

Finder tile(int i) => find.byKey(ValueKey('tile$i'));

void expectRect(Rect actual, Rect expected, {double within = 0.01, String? reason}) {
  expect(actual.left, closeTo(expected.left, within), reason: '$reason left: $actual vs $expected');
  expect(actual.top, closeTo(expected.top, within), reason: '$reason top: $actual vs $expected');
  expect(actual.width, closeTo(expected.width, within), reason: '$reason width: $actual vs $expected');
  expect(actual.height, closeTo(expected.height, within), reason: '$reason height: $actual vs $expected');
}

bool between(double v, double a, double b) => v > (a < b ? a : b) && v < (a < b ? b : a);

void main() {
  group('uiMasonryLayout', () {
    const fixture = [1.0, 1.5, 0.66, 1.0, 1.2];

    test('two columns: each item goes to the shortest column', () {
      final r = uiMasonryLayout(300, fixture, 2, 4);
      final want = [
        const Rect.fromLTWH(0, 0, 148, 148),
        const Rect.fromLTWH(152, 0, 148, 222),
        const Rect.fromLTWH(0, 152, 148, 97.68),
        const Rect.fromLTWH(152, 226, 148, 148),
        const Rect.fromLTWH(0, 253.68, 148, 177.6),
      ];
      for (var i = 0; i < want.length; i++) {
        expectRect(r[i], want[i], within: 1e-9, reason: 'item $i');
      }
      expect(uiMasonryHeight(r), closeTo(431.28, 1e-9));
    });

    test('three columns', () {
      final r = uiMasonryLayout(300, fixture, 3, 4);
      const w = 292 / 3;
      final want = [
        const Rect.fromLTWH(0, 0, w, w),
        const Rect.fromLTWH(w + 4, 0, w, w * 1.5),
        const Rect.fromLTWH(2 * (w + 4), 0, w, w * 0.66),
        const Rect.fromLTWH(2 * (w + 4), w * 0.66 + 4, w, w),
        const Rect.fromLTWH(0, w + 4, w, w * 1.2),
      ];
      for (var i = 0; i < want.length; i++) {
        expectRect(r[i], want[i], within: 1e-9, reason: 'item $i');
      }
      expect(uiMasonryHeight(r), closeTo(w + 4 + w * 1.2, 1e-9));
    });

    test('ties go to the leftmost column, and heights within 0.001 count as tied', () {
      expect(uiMasonryLayout(300, [1, 1, 1], 2, 4).map((r) => r.left).toList(), [0, 152, 0]);
      // Column 0 is 0.00074 taller than column 1: still a tie, so the third item goes left.
      expect(uiMasonryLayout(300, [1.000005, 1, 1], 2, 4)[2].left, 0);
      // 0.0148 taller is not a tie.
      expect(uiMasonryLayout(300, [1.0001, 1, 1], 2, 4)[2].left, 152);
    });

    test('columns clamp to at least one; empty is zero high', () {
      final r = uiMasonryLayout(300, [1, 2], 0, 4);
      expectRect(r[0], const Rect.fromLTWH(0, 0, 300, 300));
      expectRect(r[1], const Rect.fromLTWH(0, 304, 300, 600));
      expect(uiMasonryLayout(300, [1], -3, 4).single.width, 300);
      expect(uiMasonryHeight(uiMasonryLayout(300, const [], 3, 4)), 0);
    });
  });

  group('UiMasonryGrid', () {
    const n = 60;
    late int columns;
    late List<int> changes;
    late ScrollController scroll;

    setUp(() {
      changes = [];
    });

    Widget grid({bool disableAnimations = false}) => StatefulBuilder(
          builder: (context, setState) {
            final body = SingleChildScrollView(
              controller: scroll,
              child: UiMasonryGrid(
                itemCount: n,
                ratioOf: ratioAt,
                columns: columns,
                onColumnsChanged: (c) {
                  changes.add(c);
                  setState(() => columns = c);
                },
                itemBuilder: (context, i) => SizedBox.expand(key: ValueKey('tile$i')),
              ),
            );
            return disableAnimations ? MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: body) : body;
          },
        );

    Future<void> start(WidgetTester tester, int cols, {bool disableAnimations = false}) async {
      columns = cols;
      scroll = ScrollController();
      addTearDown(scroll.dispose);
      await pumpUi(tester, SizedBox(width: 390, height: 844, child: grid(disableAnimations: disableAnimations)));
    }

    /// Changes the column count from outside (the parent), as a button would.
    Future<void> setColumns(WidgetTester tester, int cols) async {
      columns = cols;
      await tester.pumpWidget(UiApp(home: Align(alignment: Alignment.topLeft, child: SizedBox(width: 390, height: 844, child: grid()))));
    }

    /// Grid layout on screen (the grid starts at the top-left and is scrolled by [offset]).
    Rect laid(int cols, int i, {double offset = 0}) => uiMasonryLayout(390, ratios(n), cols, 4)[i].shift(Offset(0, -offset));

    testWidgets('lays tiles out exactly where uiMasonryLayout puts them', (tester) async {
      await start(tester, 3);
      for (final i in [0, 1, 2, 5, 9]) {
        expectRect(tester.getRect(tile(i)), laid(3, i));
      }
      final h = uiMasonryHeight(uiMasonryLayout(390, ratios(n), 3, 4));
      expect(tester.getSize(find.byType(UiMasonryGrid)).height, closeTo(h, 0.01));
    });

    testWidgets('mid-animation a tile is between its old and new place and size; then exactly at the new one', (tester) async {
      await start(tester, 3);
      const i = 4;
      final a = laid(3, i);
      final b = laid(2, i);
      expect(a.left != b.left && a.width != b.width, isTrue, reason: 'the tile must move and resize');
      await setColumns(tester, 2);
      await tester.pump(const Duration(milliseconds: 140));
      final mid = tester.getRect(tile(i));
      expect(between(mid.left, a.left, b.left), isTrue, reason: '$mid between $a and $b');
      expect(between(mid.width, a.width, b.width), isTrue, reason: '$mid between $a and $b');
      expect(between(mid.top, a.top, b.top) || a.top == b.top, isTrue);
      await tester.pumpAndSettle();
      expectRect(tester.getRect(tile(i)), b);
      expect(tester.hasRunningAnimations, isFalse, reason: 'no ticker while idle');
    });

    testWidgets('a change mid-animation carries on from where the tiles are, with no jump', (tester) async {
      await start(tester, 3);
      const i = 7;
      await setColumns(tester, 2);
      await tester.pump(const Duration(milliseconds: 112));
      final before = tester.getRect(tile(i));
      await setColumns(tester, 1);
      final next = tester.getRect(tile(i));
      expect((next.topLeft - before.topLeft).distance, lessThan(2), reason: '$before then $next');
      expect((next.size.width - before.size.width).abs(), lessThan(2));
      await tester.pumpAndSettle();
      expectRect(tester.getRect(tile(i)), laid(1, i, offset: scroll.offset));
    });

    testWidgets('with animations off it changes at once', (tester) async {
      await start(tester, 3, disableAnimations: true);
      columns = 2;
      await tester.pumpWidget(UiApp(home: Align(alignment: Alignment.topLeft, child: SizedBox(width: 390, height: 844, child: grid(disableAnimations: true)))));
      expectRect(tester.getRect(tile(4)), laid(2, 4));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a tile far below the screen goes straight to its new place; one on screen does not', (tester) async {
      await start(tester, 3);
      const far = n - 1;
      expect(laid(3, far).top, greaterThan(844 * 2));
      await setColumns(tester, 2);
      expectRect(tester.getRect(tile(far)), laid(2, far));
      expect(tester.getRect(tile(4)), isNot(laid(2, 4)));
      await tester.pumpAndSettle();
    });

    testWidgets('keeps each tile\'s state across a change', (tester) async {
      await start(tester, 3);
      final before = tester.element(tile(5));
      await setColumns(tester, 2);
      await tester.pumpAndSettle();
      expect(tester.element(tile(5)), same(before));
    });

    testWidgets('a pinch inside a scroll view changes the count and keeps the point under the fingers', (tester) async {
      // A real Android device reports about 8dp, where tests default to 18 (see AGENTS.md, 2026-10-14).
      tester.view.gestureSettings = GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
      addTearDown(tester.view.resetGestureSettings);
      await start(tester, 3);
      scroll.jumpTo(600);
      await tester.pump();

      // The step fires at a midpoint of (212.5, 400): find the tile under it and the point within it.
      const focal = Offset(212.5, 400);
      var under = -1;
      for (var i = 0; i < n; i++) {
        if (tester.getRect(tile(i)).contains(focal)) under = i;
      }
      expect(under, greaterThan(0), reason: 'the focal point is over a tile mid-grid');
      final was = tester.getRect(tile(under));
      final fx = (focal.dx - was.left) / was.width;
      final fy = (focal.dy - was.top) / was.height;

      final a = await tester.startGesture(const Offset(150, 400), pointer: 41);
      final b = await tester.startGesture(const Offset(250, 400), pointer: 42);
      await tester.pump();
      await b.moveTo(const Offset(275, 400)); // 125 apart: one step apart
      await tester.pump();
      expect(changes, [2]);
      await tester.pumpAndSettle();
      final now = tester.getRect(tile(under));
      // Only the vertical can be kept: the scroll is vertical, and the tile moves to its new column.
      expect(fx, inInclusiveRange(0, 1));
      final y = now.top + fy * now.height;
      expect((y - focal.dy).abs(), lessThan(2), reason: 'tile $under: $was then $now, scrolled to ${scroll.offset}');
      expect(scroll.offset, isNot(600));

      // And together again: one more column.
      await b.moveTo(const Offset(250, 400)); // 100 of 125
      await tester.pump();
      expect(changes, [2, 3]);
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
    });

    testWidgets('fingers in the gap between tiles and on a tile edge still pinch, after the scroll view took the first', (tester) async {
      tester.view.gestureSettings = GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
      addTearDown(tester.view.resetGestureSettings);
      await start(tester, 3);
      scroll.jumpTo(300);
      await tester.pump();
      const w = (390 - 8) / 3;
      // The first finger lands in the gap between columns 0 and 1 and starts a scroll.
      final a = await tester.startGesture(const Offset(w + 2, 500), pointer: 61);
      await a.moveBy(const Offset(0, -12));
      await tester.pump();
      await a.moveBy(const Offset(0, -20));
      await tester.pump();
      final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(position.activity!.shouldIgnorePointer, isTrue, reason: 'the scroll view has the first finger');
      // The second lands exactly on the right edge of a column-1 tile.
      final b = await tester.startGesture(const Offset(2 * w + 4, 468), pointer: 62);
      await tester.pump();
      await b.moveTo(const Offset(2 * w + 4 + w * 0.3, 468)); // well past 1.25x of about 129
      await tester.pump();
      expect(changes, [2]);
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a pinch never goes past minColumns / maxColumns', (tester) async {
      columns = 5;
      scroll = ScrollController();
      addTearDown(scroll.dispose);
      await pumpUi(
        tester,
        SizedBox(
          width: 390,
          height: 844,
          child: UiMasonryGrid(itemCount: 6, ratioOf: (_) => 1, columns: 5, onColumnsChanged: changes.add, itemBuilder: (_, i) => const SizedBox()),
        ),
      );
      final a = await tester.startGesture(const Offset(100, 100), pointer: 51);
      final b = await tester.startGesture(const Offset(200, 100), pointer: 52);
      await b.moveTo(const Offset(180, 100));
      expect(changes, isEmpty);
      await a.up();
      await b.up();
    });

    testWidgets('golden', (tester) async {
      await expectThemedGolden(
        tester,
        'masonry_grid',
        (context) {
          final t = context.ui;
          return UiMasonryGrid(
            itemCount: 9,
            ratioOf: ratioAt,
            columns: 3,
            pinchable: false,
            itemBuilder: (context, i) => DecoratedBox(
              decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radiusSm)),
              child: Center(child: UiText('${i + 1}', variant: UiTextVariant.caption)),
            ),
          );
        },
        height: 500,
      );
    });
  });
}
