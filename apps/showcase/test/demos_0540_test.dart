import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';
import 'package:zouriel_ui_showcase/pages/media_page.dart';

/// 0.54.0 showcase demo: the masonry grid changes its column count from the buttons and a pinch.

void main() {
  testWidgets('media page: the masonry grid demo glides to a picked count and answers a pinch', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const UiApp(home: MediaPage()));
    await tester.pump(const Duration(milliseconds: 300));

    final grid = find.byType(UiMasonryGrid);
    await tester.ensureVisible(grid);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(UiSegmented<int>));
    await tester.pumpAndSettle();
    expect(tester.widget<UiMasonryGrid>(grid).columns, 3);
    final one = find.descendant(of: grid, matching: find.text('1'));
    Rect first() => tester.getRect(find.ancestor(of: one, matching: find.byType(DecoratedBox)).first);
    final before = first();

    await tester.tap(find.descendant(of: find.byType(UiSegmented<int>), matching: find.text('2')));
    await tester.pump(); // the frame that starts the glide
    await tester.pump(const Duration(milliseconds: 140));
    final mid = first();
    expect(mid.width, greaterThan(before.width));
    await tester.pumpAndSettle();
    expect(tester.widget<UiMasonryGrid>(grid).columns, 2);
    expect(first().width, greaterThan(mid.width));

    // The middle of the demo's scroll box, which is on screen.
    final c = tester.getCenter(find.ancestor(of: grid, matching: find.byType(SingleChildScrollView)).first).dy;
    final a = await tester.startGesture(Offset(145, c), pointer: 41);
    final b = await tester.startGesture(Offset(245, c), pointer: 42);
    await b.moveBy(const Offset(-25, 0)); // 75 of 100: together, one more column
    await tester.pump();
    expect(tester.widget<UiMasonryGrid>(grid).columns, 3);
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
