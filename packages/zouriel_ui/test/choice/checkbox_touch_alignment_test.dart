import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

/// 0.61.0: on a card the web checkbox sits right at the card's padding (the app adds an invisible hit
/// area), while Flutter's sat 14px further in, centred in its 48dp touch cell. touchAlignment
/// centerStart keeps the box at the cell's start edge and lets the tap area reach toward the end.

Future<List<bool>> _pump(WidgetTester tester, {AlignmentDirectional? align, TextDirection dir = TextDirection.ltr}) async {
  tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final taps = <bool>[];
  await tester.pumpWidget(UiApp(
    home: Directionality(
      textDirection: dir,
      child: Center(
        child: StatefulBuilder(
          builder: (context, set) => UiCheckbox(
            key: const Key('cb'),
            value: taps.isEmpty ? false : taps.last,
            semanticLabel: 'Pick',
            touchAlignment: align ?? AlignmentDirectional.center,
            onChanged: (v) => set(() => taps.add(v)),
          ),
        ),
      ),
    ),
  ));
  return taps;
}

Rect _box(WidgetTester tester) => tester.getRect(find.descendant(of: find.byKey(const Key('cb')), matching: find.byType(UiCheckMark)));

void main() {
  testWidgets('default: the box is centred in the 48dp cell, as before', (tester) async {
    await _pump(tester);
    final cell = tester.getRect(find.byKey(const Key('cb')));
    expect(cell.size, const Size(48, 48));
    expect(_box(tester).center.dx, closeTo(cell.center.dx, 0.5));
  });

  testWidgets('centerStart (LTR): the box sits at the cell start; a tap 40px in still toggles', (tester) async {
    final taps = await _pump(tester, align: AlignmentDirectional.centerStart);
    final cell = tester.getRect(find.byKey(const Key('cb')));
    expect(cell.size, const Size(48, 48));
    expect(_box(tester).left, closeTo(cell.left, 0.5));
    await tester.tapAt(Offset(cell.left + 40, cell.center.dy));
    await tester.pump();
    expect(taps, [true]);
  });

  testWidgets('centerStart (RTL): the box sits at the cell start on the right', (tester) async {
    final taps = await _pump(tester, align: AlignmentDirectional.centerStart, dir: TextDirection.rtl);
    final cell = tester.getRect(find.byKey(const Key('cb')));
    expect(cell.size, const Size(48, 48));
    expect(_box(tester).right, closeTo(cell.right, 0.5));
    await tester.tapAt(Offset(cell.right - 40, cell.center.dy));
    await tester.pump();
    expect(taps, [true]);
  });
}
