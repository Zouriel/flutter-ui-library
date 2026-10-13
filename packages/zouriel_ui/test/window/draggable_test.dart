import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

Widget _box(String text) => SizedBox(width: 90, height: 50, child: Center(child: Text(text)));

void main() {
  testWidgets('UiDraggable follows the pointer and reports start, move and end', (tester) async {
    final starts = <UiDragEvent>[], moves = <UiDragEvent>[], ends = <UiDragEvent>[];
    Offset? reported;
    await pumpUi(tester, Padding(
      padding: const EdgeInsets.all(20),
      child: UiDraggable(
        onPositionChanged: (p) => reported = p,
        onDragStart: starts.add,
        onDragMove: moves.add,
        onDragEnd: ends.add,
        child: _box('Drag me'),
      ),
    ));
    final before = tester.getTopLeft(find.text('Drag me'));
    await tester.drag(find.text('Drag me'), const Offset(60, 30));
    await tester.pumpAndSettle();
    expect(reported, const Offset(60, 30));
    expect(tester.getTopLeft(find.text('Drag me')), before + const Offset(60, 30));
    expect(starts.single.position, Offset.zero);
    expect(moves, isNotEmpty);
    expect(ends.single.position, const Offset(60, 30));
  });

  testWidgets('a controlled UiDraggable shows the position it is given', (tester) async {
    await pumpUi(tester, const UiDraggable(position: Offset(40, 10), child: SizedBox(width: 20, height: 20, child: Text('x'))));
    expect(tester.getTopLeft(find.text('x')), const Offset(40, 10));
  });

  testWidgets('with handleOnly, only the handle starts a drag; disabled never drags', (tester) async {
    Offset? reported;
    await pumpUi(tester, UiDraggable(
      handleOnly: true,
      onPositionChanged: (p) => reported = p,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const UiDragHandle(child: SizedBox(width: 100, height: 30, child: Text('Grip'))),
        _box('Body'),
      ]),
    ));
    await tester.drag(find.text('Body'), const Offset(50, 0));
    expect(reported, isNull);
    await tester.drag(find.text('Grip'), const Offset(50, 0));
    expect(reported, const Offset(50, 0));

    reported = null;
    await pumpUi(tester, UiDraggable(enabled: false, onPositionChanged: (p) => reported = p, child: _box('Off')));
    await tester.drag(find.text('Off'), const Offset(50, 0));
    expect(reported, isNull);
  });

  testWidgets('UiResizable grows from its right edge, bottom edge and corner, never below the minimum', (tester) async {
    final sizes = <Size>[];
    await pumpUi(tester, UiResizable(initialSize: const Size(160, 90), minWidth: 120, minHeight: 70, onResized: sizes.add, child: const ColoredBox(color: Color(0x00000000))));
    final box = find.byType(UiResizable);
    expect(tester.getSize(box), const Size(160, 90));
    await tester.drag(find.byKey(const Key('ui-resize-se')), const Offset(40, 30));
    await tester.pumpAndSettle();
    expect(tester.getSize(box), const Size(200, 120));
    await tester.drag(find.byKey(const Key('ui-resize-e')), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(box), const Size(120, 120));
    await tester.drag(find.byKey(const Key('ui-resize-s')), const Offset(0, 20));
    await tester.pumpAndSettle();
    expect(tester.getSize(box), const Size(120, 140));
    expect(sizes.last, const Size(120, 140));
  });

  testWidgets('UiResizable touch zones are finger-sized but stay inside the box', (tester) async {
    await pumpUi(tester, const UiResizable(initialSize: Size(160, 90), child: SizedBox.expand()));
    expect(tester.getSize(find.byKey(const Key('ui-resize-se'))), const Size(48, 48));
    expect(tester.getSize(find.byKey(const Key('ui-resize-e'))).width, 24);
    expect(tester.getRect(find.byKey(const Key('ui-resize-se'))).bottomRight, tester.getRect(find.byType(UiResizable)).bottomRight);
  });

  testWidgets('golden: a resizable panel with its corner grip', (tester) async {
    await expectThemedGolden(tester, 'resizable', height: 140, (context) {
      final t = context.ui;
      return Align(
        alignment: Alignment.topLeft,
        child: UiResizable(
          initialSize: const Size(200, 100),
          child: DecoratedBox(
            decoration: BoxDecoration(color: t.surfaceRaised, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
            child: Padding(padding: EdgeInsets.all(t.space2), child: const Align(alignment: Alignment.bottomLeft, child: UiText('200 x 100', variant: UiTextVariant.caption))),
          ),
        ),
      );
    });
  });
}
