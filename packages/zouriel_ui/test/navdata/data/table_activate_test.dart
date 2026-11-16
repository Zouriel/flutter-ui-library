import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../../helpers.dart';

// 0.87.0: UiTable(onRowActivate:, rowLabel:), the web `activatable` rows.

typedef Item = Map<String, Object?>;

final Item ann = {'name': 'Aminath Ali', 'qty': 3};
final Item bob = {'name': 'Hassan Bari', 'qty': 5};

const _cols = [UiColumn<Item>(key: 'name', header: 'Name'), UiColumn<Item>(key: 'qty', header: 'Qty', align: UiColumnAlign.end)];

Widget _table(List<Item> opened, {String Function(Item)? rowLabel, List<UiRowAction<Item>> actions = const [], bool selectable = false, ValueChanged<Item>? onRowActivate}) => SizedBox(
      width: 390,
      child: UiTable<Item>(columns: _cols, data: [ann, bob], actions: actions, selectable: selectable, rowLabel: rowLabel, onRowActivate: onRowActivate ?? opened.add),
    );

void main() {
  testWidgets('a tap anywhere on the row opens it, the first cell and the others alike', (tester) async {
    final opened = <Item>[];
    await pumpUi(tester, _table(opened));
    await tester.tap(find.text('5'));
    await tester.tap(find.text('Aminath Ali'));
    expect(opened, [bob, ann]);
  });

  testWidgets('Enter and Space on the focused row open it', (tester) async {
    final opened = <Item>[];
    await pumpUi(tester, _table(opened));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened, [ann]);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(opened, [ann, bob], reason: 'one focus stop per row');
  });

  testWidgets('row actions and the selection box keep their own taps', (tester) async {
    final opened = <Item>[], edited = <Item>[];
    await pumpUi(tester, _table(opened, selectable: true, actions: [UiRowAction(label: 'Edit', run: edited.add)]));
    await tester.tap(find.text('Edit').first);
    await tester.tap(find.bySemanticsLabel(uiFormatString(const UiStrings().selectRow, {'n': 1})));
    expect(edited, [ann]);
    expect(opened, isEmpty);
    // Its twin: the same row's text does open it.
    await tester.tap(find.text('3'));
    expect(opened, [ann]);
  });

  testWidgets('semantics: one button per row, named by rowLabel or else the first cell', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, _table([], rowLabel: (r) => 'Open ${r['name']}'));
    final named = tester.getSemantics(find.bySemanticsLabel('Open Hassan Bari')).getSemanticsData();
    expect(named.flagsCollection.isButton, isTrue);
    expect(named.hasAction(SemanticsAction.tap), isTrue);
    await pumpUi(tester, _table([]));
    final plain = tester.getSemantics(find.bySemanticsLabel('Aminath Ali')).getSemanticsData();
    expect(plain.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('without onRowActivate rows are not targets: no button, no focus stop', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const SizedBox(width: 390, child: UiTable<Item>(columns: _cols, data: [])));
    await pumpUi(tester, SizedBox(width: 390, child: UiTable<Item>(columns: _cols, data: [ann])));
    expect(tester.getSemantics(find.text('Aminath Ali')).getSemanticsData().flagsCollection.isButton, isFalse);
    expect(find.ancestor(of: find.text('Aminath Ali'), matching: find.byType(UiInteractive)), findsNothing);
    await pumpUi(tester, _table([]));
    expect(find.ancestor(of: find.text('Aminath Ali'), matching: find.byType(UiInteractive)), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the focus ring sits round the first cell when the keyboard reaches the row', (tester) async {
    await pumpUi(tester, _table([]));
    BoxDecoration ring() => tester.widget<AnimatedContainer>(find.ancestor(of: find.text('Aminath Ali'), matching: find.byType(AnimatedContainer)).first).decoration! as BoxDecoration;
    expect(ring().boxShadow, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(ring().boxShadow, isNotEmpty);
  });

  testWidgets('hovering anywhere on the row underlines its first cell, as the web', (tester) async {
    await pumpUi(tester, _table([]));
    TextDecoration? line(String text) => tester.renderObject<RenderParagraph>(find.text(text)).text.style?.decoration;
    expect(line('Hassan Bari'), isNot(TextDecoration.underline));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('5')));
    addTearDown(mouse.removePointer);
    await tester.pump();
    expect(line('Hassan Bari'), TextDecoration.underline);
    expect(line('Aminath Ali'), isNot(TextDecoration.underline), reason: 'only the hovered row');
  });

  testWidgets('guidelines: tap targets and labels', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final handle = tester.ensureSemantics();
    try {
      await pumpUi(tester, _table([], selectable: true, rowLabel: (r) => 'Open ${r['name']}', actions: [UiRowAction(label: 'Edit', run: (_) {})]));
      // The row's button is 48dp tall on touch.
      expect(tester.getSize(find.ancestor(of: find.text('Aminath Ali'), matching: find.byType(UiTouchTarget)).first).height, greaterThanOrEqualTo(uiMinTouchTarget));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('golden: the first row keyboard-focused, the second hovered', (tester) async {
    // expectThemedGolden's scene, with focus and hover set before the shot.
    debugDisableShadows = false;
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390 * 2, 160) * 2;
    addTearDown(tester.view.reset);
    try {
      await tester.pumpWidget(UiApp(
        theme: UiThemeName.dark,
        home: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final th in [UiThemeName.dark, UiThemeName.light])
            SizedBox(width: 390, child: UiThemeScope(theme: th, child: Padding(padding: const EdgeInsets.all(16), child: Align(alignment: Alignment.topLeft, child: _table([]))))),
        ]),
      ));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.text('5').first));
      addTearDown(mouse.removePointer);
      await tester.pump(const Duration(milliseconds: 400));
      // The focus highlight lands a frame after the key (UiInteractive sets it after that frame), then animates.
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/table_activate.png'));
    } finally {
      debugDisableShadows = true;
    }
  });
}
