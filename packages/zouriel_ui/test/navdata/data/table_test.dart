import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../../helpers.dart';

typedef Item = Map<String, Object?>;

final Item a = {'name': 'item 10', 'qty': 3};
final Item b = {'name': 'Apple', 'qty': 5};
final Item c = {'name': 'banana', 'qty': null};
final Item d = {'name': 'item 9', 'qty': 1};

const _cols = [UiColumn<Item>(key: 'name', header: 'Name', sortable: true), UiColumn<Item>(key: 'qty', header: 'Qty', sortable: true, align: UiColumnAlign.end)];

List<String> _names(WidgetTester tester) {
  final texts = tester.widgetList<Text>(find.descendant(of: find.byType(Table), matching: find.byType(Text))).map((t) => t.data).toList();
  return texts.where((s) => s != null && ['item 10', 'Apple', 'banana', 'item 9'].contains(s)).cast<String>().toList();
}

Finder _sort(String header) => find.ancestor(of: find.text(header), matching: find.byType(UiInteractive)).first;

void main() {
  test('natural, case-insensitive compare', () {
    final list = ['item 10', 'Item 2', 'apple', 'Banana', 'item 02b', 'item 2a'];
    list.sort(uiNaturalCompare);
    expect(list, ['apple', 'Banana', 'Item 2', 'item 2a', 'item 02b', 'item 10']);
  });

  testWidgets('sorts text case-insensitively and numbers inside text in numeric order', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, SizedBox(width: 390, child: UiTable<Item>(columns: _cols, data: [a, b, c, d])));
    expect(_names(tester), ['item 10', 'Apple', 'banana', 'item 9']);
    await tester.tap(_sort('Name'));
    await tester.pump();
    expect(_names(tester), ['Apple', 'banana', 'item 9', 'item 10']);
    final name = tester.getSemantics(find.text('Name'));
    expect(name.getSemanticsData().value, 'sorted ascending');
    expect(name.parent!.role, SemanticsRole.columnHeader);
    handle.dispose();
  });

  testWidgets('cycles ascending, descending, unsorted; numbers compare as numbers and empties go last', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, SizedBox(width: 390, child: UiTable<Item>(columns: _cols, data: [a, b, c, d])));
    await tester.tap(_sort('Qty'));
    await tester.pump();
    expect(_names(tester), ['item 9', 'item 10', 'Apple', 'banana']);
    await tester.tap(_sort('Qty'));
    await tester.pump();
    expect(_names(tester), ['Apple', 'item 10', 'item 9', 'banana']);
    expect(tester.getSemantics(find.text('Qty')).getSemanticsData().value, 'sorted descending');
    await tester.tap(_sort('Qty'));
    await tester.pump();
    expect(_names(tester), ['item 10', 'Apple', 'banana', 'item 9']);
    expect(tester.getSemantics(find.text('Qty')).getSemanticsData().value, '');
    handle.dispose();
  });

  testWidgets('selection: select all, forget rows that leave, partial shows mixed', (tester) async {
    final handle = tester.ensureSemantics();
    final emitted = <List<Item>>[];
    var data = [a, b, c, d];
    late StateSetter set;
    await pumpUi(tester, StatefulBuilder(builder: (context, s) {
      set = s;
      return SizedBox(width: 390, child: UiTable<Item>(columns: _cols, data: data, selectable: true, onSelectionChanged: emitted.add));
    }));
    final all = find.bySemanticsLabel('Select all rows');
    await tester.tap(all);
    await tester.pump();
    expect(emitted.last, hasLength(4));
    set(() => data = [a, b]);
    await tester.pump();
    var d0 = tester.getSemantics(all).getSemanticsData();
    expect(d0.flagsCollection.isChecked, CheckedState.isTrue);
    await tester.tap(find.bySemanticsLabel('Select row 1'));
    await tester.pump();
    expect(emitted.last, [b]);
    d0 = tester.getSemantics(all).getSemanticsData();
    expect(d0.flagsCollection.isChecked, CheckedState.mixed);
    // A selected row is tinted.
    final t = uiThemeTokens[UiThemeName.dark]!;
    final table = tester.widget<Table>(find.byType(Table));
    expect((table.children[2].decoration! as BoxDecoration).color, t.selected);
    handle.dispose();
  });

  testWidgets('row actions: one button per row, handed its row, disabled per row, named per row', (tester) async {
    final handle = tester.ensureSemantics();
    final ran = <Object?>[];
    await pumpUi(tester, SizedBox(width: 390, child: UiTable<Item>(columns: _cols, data: [a, b], actions: [
      UiRowAction(label: 'Edit', run: (r) => ran.add(r['name']), semanticLabel: (r) => 'Edit ${r['name']}'),
      UiRowAction(label: 'Remove', run: (r) => ran.add('rm ${r['name']}'), disabled: (r) => r == b),
    ])));
    await tester.tap(find.bySemanticsLabel('Edit Apple'));
    await tester.tap(find.text('Remove').last);
    await tester.tap(find.text('Remove').first);
    expect(ran, ['Apple', 'rm item 10']);
    expect(find.bySemanticsLabel('Actions'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('row actions: the web spacing, space2 apart and space2 clear of the row lines', (tester) async {
    await pumpUi(tester, SizedBox(width: 600, child: UiTable<Item>(columns: _cols, data: [a], actions: [
      UiRowAction(label: 'Edit', run: (_) {}),
      UiRowAction(label: 'Remove', run: (_) {}),
    ])));
    final t = tester.element(find.byType(UiTable<Item>)).ui;
    Rect box(String label) => tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(UiInteractive)).first);
    final edit = box('Edit'), remove = box('Remove');
    expect(remove.left - edit.right, t.space2);
    expect(edit.height, t.sizeSm);
    // The row is the button plus space2 above and below, as tall as a web row (42px plus its line).
    final pad = EdgeInsets.symmetric(vertical: t.space2, horizontal: t.space3);
    final cell = tester.getRect(find.ancestor(of: find.text('Edit'), matching: find.byWidgetPredicate((w) => w is Padding && w.padding == pad)).first);
    expect(edit.top - cell.top, t.space2);
    expect(cell.bottom - edit.bottom, t.space2);
    expect(cell.height, t.sizeSm + 2 * t.space2);
    // The data cells sit on the same middle line as the buttons.
    expect(tester.getCenter(find.text('item 10')).dy, moreOrLessEquals(edit.center.dy, epsilon: 0.5));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('row actions on touch: the 48px hit areas set the row height, no padding on top', (tester) async {
    await pumpUi(tester, SizedBox(width: 600, child: UiTable<Item>(columns: _cols, data: [a], actions: [UiRowAction(label: 'Edit', run: (_) {})])));
    final t = tester.element(find.byType(UiTable<Item>)).ui;
    final cell = tester.getRect(find.ancestor(of: find.text('Edit'), matching: find.byType(MouseRegion)).last);
    expect(cell.height, uiMinTouchTarget);
    final visual = tester.getRect(find.ancestor(of: find.text('Edit'), matching: find.byType(AnimatedContainer)).first);
    expect(visual.height, t.sizeSm);
    expect(visual.top - cell.top, greaterThan(t.space2));
  });

  testWidgets('empty: shows the empty text under the headers', (tester) async {
    await pumpUi(tester, const SizedBox(width: 390, child: UiTable<Item>(columns: _cols, data: [], emptyText: 'No items yet')));
    expect(find.text('No items yet'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
  });

  testWidgets('fills the width when it fits; scrolls sideways when it does not', (tester) async {
    await pumpUi(tester, SizedBox(width: 390, child: UiTable<Item>(columns: _cols, data: [a, b])));
    expect(tester.getSize(find.byType(Table)).width, 388);
    final wide = [for (var i = 0; i < 8; i++) UiColumn<Item>(key: 'name', header: 'A long column header $i')];
    await pumpUi(tester, SizedBox(width: 390, child: UiTable<Item>(columns: wide, data: [a, b])));
    expect(tester.getSize(find.byType(Table)).width, greaterThan(1000));
    expect(tester.getSize(find.byType(UiTable<Item>)).width, 390);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide: long text wraps inside the width instead of scrolling', (tester) async {
    final long = {'name': 'A long description of what this option does, written out the way docs tables have it, and then some more words so it cannot fit on one line', 'qty': 1};
    await pumpUi(tester, SizedBox(width: 900, child: UiTable<Item>(columns: _cols, data: [long])), size: const Size(1000, 800));
    expect(tester.getSize(find.byType(Table)).width, lessThanOrEqualTo(900));
    expect(find.descendant(of: find.byType(UiTable<Item>), matching: find.byType(SingleChildScrollView)), findsNothing);
    expect(tester.getSize(find.text(long['name']! as String)).height, greaterThan(30), reason: 'the text wraps onto more lines');
    expect(tester.takeException(), isNull);
  });

  testWidgets('semantics: a table of rows and cells with column headers', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, SizedBox(width: 390, child: UiTable<Item>(columns: _cols, data: [a, b], selectable: true)));
    final table = tester.getSemantics(find.byType(Table)).getSemanticsData();
    expect(table.role, SemanticsRole.table);
    expect(tester.getSemantics(find.text('Name')).parent!.role, SemanticsRole.columnHeader);
    expect(tester.getSemantics(find.text('Name')).parent!.parent!.role, SemanticsRole.row);
    final apple = tester.getSemantics(find.text('Apple'));
    expect([apple.role, apple.parent!.role], contains(SemanticsRole.cell));
    handle.dispose();
  });

  testWidgets('tree table: chevron buttons expand rows and say so', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const SizedBox(width: 390, child: UiTreeTable(
      columns: [UiTreeTableColumn(key: 'amount', header: 'Amount', align: UiColumnAlign.end)],
      rows: [
        UiTreeTableRow(label: 'Q1', value: 'q1', data: {'amount': '3,200'}, children: [
          UiTreeTableRow(label: 'January', value: 'jan', data: {'amount': '1,000'}),
        ]),
        UiTreeTableRow(label: 'Q2', value: 'q2', data: {'amount': '4,100'}),
      ],
    )));
    expect(find.text('January'), findsNothing);
    final chev = find.bySemanticsLabel('Expand Q1');
    expect(tester.getSemantics(chev).getSemanticsData().flagsCollection.isExpanded, Tristate.isFalse);
    await tester.tap(chev);
    await tester.pump();
    expect(find.text('January'), findsOneWidget);
    expect(find.bySemanticsLabel('Collapse Q1'), findsOneWidget);
    // Children are indented.
    expect(tester.getTopLeft(find.text('January')).dx, greaterThan(tester.getTopLeft(find.text('Q1')).dx + 8));
    handle.dispose();
  });

  testWidgets('guidelines: tap targets, labels, contrast', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final handle = tester.ensureSemantics();
    try {
      await pumpUi(tester, Padding(
        padding: const EdgeInsets.all(16),
        child: Column(spacing: 16, children: [
          UiTable<Item>(columns: _cols, data: [a, b], selectable: true, actions: [UiRowAction(label: 'Edit', run: (_) {})]),
          const UiTreeTable(columns: [UiTreeTableColumn(key: 'n', header: 'N')], rows: [
            UiTreeTableRow(label: 'Parent', value: 'p', data: {'n': 1}, children: [UiTreeTableRow(label: 'Child', value: 'c')]),
          ]),
        ]),
      ));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      // The pixel-sampling contrast check misreads one-digit cells (antialiasing outnumbers the
      // glyph) and the bordered action buttons (border pixels outnumber the label), so the table's
      // colours are checked on the tokens; the tree table's text is sampled on screen.
      for (final th in UiThemeName.values) {
        final t = uiThemeTokens[th]!;
        double ratio(Color x, Color y) {
          final lx = x.computeLuminance(), ly = y.computeLuminance();
          return ((lx > ly ? lx : ly) + 0.05) / ((lx > ly ? ly : lx) + 0.05);
        }
        for (final bg in [t.bg, t.surface, t.surfaceHover, uiMix(t.selected, t.selected.a, t.bg).withValues(alpha: 1)]) {
          expect(ratio(t.text, bg), greaterThanOrEqualTo(4.5), reason: '$th cell text');
        }
        expect(ratio(t.textMuted, t.surfaceRaised), greaterThanOrEqualTo(4.5), reason: '$th header');
      }
      await pumpUi(tester, const Padding(
        padding: EdgeInsets.all(16),
        child: UiTreeTable(columns: [UiTreeTableColumn(key: 'n', header: 'Count')], rows: [
          UiTreeTableRow(label: 'Parent row', value: 'p', data: {'n': 'Twelve'}, children: [UiTreeTableRow(label: 'Child', value: 'c')]),
        ]),
      ));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('golden: table and tree table', (tester) async {
    final rows = <Item>[
      {'name': 'Aminath Shareef', 'role': 'Owner', 'seats': 12},
      {'name': 'Ali Zahir', 'role': 'Editor', 'seats': 3},
      {'name': 'Hawwa Nashidha', 'role': 'Viewer', 'seats': null},
    ];
    await expectThemedGolden(tester, 'table', height: 600, (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        _SelectedTable(rows: rows),
        const UiTable<Item>(columns: [UiColumn(key: 'name', header: 'Name'), UiColumn(key: 'role', header: 'Role')], data: [], emptyText: 'No members yet'),
        const UiTreeTable(
          initiallyExpanded: {'q1'},
          columns: [UiTreeTableColumn(key: 'amount', header: 'Amount', align: UiColumnAlign.end)],
          rows: [
            UiTreeTableRow(label: 'Q1', value: 'q1', data: {'amount': '3,200'}, children: [
              UiTreeTableRow(label: 'January', value: 'jan', data: {'amount': '1,000'}),
              UiTreeTableRow(label: 'February', value: 'feb', data: {'amount': '2,200'}),
            ]),
            UiTreeTableRow(label: 'Q2', value: 'q2', data: {'amount': '4,100'}, children: [UiTreeTableRow(label: 'April', value: 'apr')]),
          ],
        ),
      ],
    ));
  });
}

/// A table sorted by name with the first row selected, for the golden.
class _SelectedTable extends StatelessWidget {
  const _SelectedTable({required this.rows});
  final List<Item> rows;

  @override
  Widget build(BuildContext context) => UiTable<Item>(
        selectable: true,
        columns: const [
          UiColumn(key: 'name', header: 'Name', sortable: true),
          UiColumn(key: 'seats', header: 'Seats', sortable: true, align: UiColumnAlign.end),
        ],
        data: rows,
        actions: [UiRowAction(label: 'Edit', run: (_) {}), UiRowAction(label: 'Remove', run: (_) {}, disabled: (r) => r['role'] == 'Owner')],
      );
}
