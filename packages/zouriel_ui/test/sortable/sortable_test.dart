import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/src/sortable/section_list.dart' show uiSortableMove;
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// A phone's touch slop (about 8dp), not flutter_test's 18: scroll views pick it up from MediaQuery,
/// so a recognizer that kept 18 would lose every drag to the page's scroll (mistake log 2026-10-14).
void phoneSlop(WidgetTester tester) {
  tester.view.gestureSettings = ui.GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
  addTearDown(tester.view.resetGestureSettings);
}

const _sections = [
  UiSectionListItem(id: 'cover', label: 'Cover', locked: true, hideable: false, removable: false),
  UiSectionListItem(id: 'a', label: 'Weddings', description: '24 photos', icon: HugeIcons.strokeRoundedAlbum02),
  UiSectionListItem(id: 'b', label: 'About', hidden: true),
  UiSectionListItem(id: 'c', label: 'Contact'),
];

Widget _list(List<UiSectionListItem> items, {ValueChanged<List<String>>? onReorder, void Function(String, bool)? onHide, ValueChanged<String>? onEdit, ValueChanged<String>? onRemove}) =>
    _Holder(items: items, onReorder: onReorder, onHide: onHide, onEdit: onEdit, onRemove: onRemove);

/// Keeps the order like an app would, inside a page that scrolls.
class _Holder extends StatefulWidget {
  const _Holder({required this.items, this.onReorder, this.onHide, this.onEdit, this.onRemove});
  final List<UiSectionListItem> items;
  final ValueChanged<List<String>>? onReorder;
  final void Function(String, bool)? onHide;
  final ValueChanged<String>? onEdit, onRemove;
  @override
  State<_Holder> createState() => _HolderState();
}

class _HolderState extends State<_Holder> {
  late var items = widget.items;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 390,
        height: 844,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const SizedBox(height: 40),
          UiSectionList(
            items: items,
            onReorder: (ids) {
              setState(() => items = [for (final id in ids) items.firstWhere((i) => i.id == id)]);
              widget.onReorder?.call(ids);
            },
            onToggleHidden: widget.onHide,
            onEdit: widget.onEdit,
            onRemove: widget.onRemove,
          ),
          const SizedBox(height: 1200),
        ]),
      );
}

void main() {
  group('uiSortableMove', () {
    test('moves among free items and keeps locked ones in place', () {
      expect(uiSortableMove(['cover', 'a', 'b', 'c'], {'cover'}, 3, 1), ['cover', 'c', 'a', 'b']);
      expect(uiSortableMove(['cover', 'a', 'b', 'c'], {'cover'}, 1, 3), ['cover', 'b', 'c', 'a']);
      // Dropping above a locked first item still leaves it first.
      expect(uiSortableMove(['cover', 'a', 'b', 'c'], {'cover'}, 2, 0), ['cover', 'b', 'a', 'c']);
      // A locked item in the middle keeps its index.
      expect(uiSortableMove(['a', 'x', 'b', 'c'], {'x'}, 0, 3), ['b', 'x', 'c', 'a']);
    });
    test('null when nothing changes or the item is locked', () {
      expect(uiSortableMove(['a', 'b'], {}, 1, 1), isNull);
      expect(uiSortableMove(['cover', 'a'], {'cover'}, 0, 1), isNull);
      expect(uiSortableMove(['cover', 'a'], {'cover'}, 1, 0), isNull);
    });
  });

  group('UiSectionList', () {
    testWidgets('dragging a handle with a phone touch slop reorders inside a scrolling page', (tester) async {
      phoneSlop(tester);
      List<String>? got;
      await pumpUi(tester, _list(_sections, onReorder: (ids) => got = ids));
      final handle = find.bySemanticsLabel('Drag to move Contact');
      expect(handle, findsOneWidget);
      final start = tester.getCenter(handle);
      final g = await tester.startGesture(start, kind: ui.PointerDeviceKind.touch);
      for (var i = 1; i <= 10; i++) {
        await g.moveTo(start - Offset(0, i * 7.0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(got, ['cover', 'a', 'c', 'b']);
      // The page did not scroll instead.
      expect(tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels, 0);
    });

    testWidgets('a swipe on a row (not the handle) scrolls the page', (tester) async {
      phoneSlop(tester);
      List<String>? got;
      await pumpUi(tester, _list(_sections, onReorder: (ids) => got = ids));
      await tester.drag(find.text('Weddings'), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(got, isNull);
      expect(tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels, greaterThan(0));
    });

    testWidgets('eye, pencil and bin call back with the row', (tester) async {
      final calls = <String>[];
      await pumpUi(tester, _list(_sections, onHide: (id, h) => calls.add('hide $id $h'), onEdit: (id) => calls.add('edit $id'), onRemove: (id) => calls.add('remove $id')));
      await tester.tap(find.bySemanticsLabel('Hide Weddings'));
      await tester.tap(find.bySemanticsLabel('Show About'));
      await tester.tap(find.bySemanticsLabel('Edit Contact'));
      await tester.tap(find.bySemanticsLabel('Remove Contact'));
      expect(calls, ['hide a true', 'hide b false', 'edit c', 'remove c']);
      // The locked cover has no handle, eye or bin.
      expect(find.bySemanticsLabel('Drag to move Cover'), findsNothing);
      expect(find.bySemanticsLabel('Hide Cover'), findsNothing);
      expect(find.bySemanticsLabel('Remove Cover'), findsNothing);
      expect(find.text('Hidden'), findsOneWidget);
    });

    testWidgets('arrow keys on a focused handle move the row, never above a locked one', (tester) async {
      final orders = <List<String>>[];
      await pumpUi(tester, _list(_sections, onReorder: orders.add));
      final focus = tester.widget<Focus>(find.descendant(of: find.bySemanticsLabel('Drag to move Weddings'), matching: find.byType(Focus)).first).focusNode!;
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // already first after the cover: nothing
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(orders, [
        ['cover', 'b', 'a', 'c'],
      ]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(orders.last, ['cover', 'b', 'c', 'a']);
    });

    testWidgets('meets tap target and label guidelines; long labels do not overflow at 320', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(
        tester,
        SizedBox(
          width: 320,
          child: UiSectionList(
            items: const [UiSectionListItem(id: 'x', label: 'A very long collection name that will not fit on a small phone', description: 'and a long description too')],
            onReorder: (_) {},
            onToggleHidden: (_, _) {},
            onEdit: (_) {},
            onRemove: (_) {},
          ),
        ),
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('golden', (tester) async {
      await expectThemedGolden(
        tester,
        'section_list',
        (_) => UiSectionList(items: _sections, onReorder: (_) {}, onToggleHidden: (_, _) {}, onEdit: (_) {}, onRemove: (_) {}),
        height: 330,
      );
    });
  });

  group('UiReorderGrid', () {
    final photos = [for (var i = 0; i < 9; i++) UiReorderGridItem(id: 'p$i', src: 'https://example.invalid/$i.jpg', alt: 'Photo $i')];
    Widget tile(BuildContext context, UiReorderGridItem item) => ColoredBox(color: context.ui.surfaceRaised, child: Center(child: Text(item.id)));

    Widget grid({ValueChanged<List<String>>? onReorder, ValueChanged<String>? onTap, ValueChanged<String>? onRemove}) => SizedBox(
          width: 390,
          height: 844,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            _GridHolder(items: photos, onReorder: onReorder, onTap: onTap, onRemove: onRemove, tile: tile),
            const SizedBox(height: 1200),
          ]),
        );

    test('columns fill the width at no less than minTile', () {
      final m = uiReorderGridMetrics(358, 96, 8);
      expect(m.columns, 3);
      expect(m.tile * 3 + 16, closeTo(358, 0.001));
      expect(uiReorderGridMetrics(50, 96, 8).columns, 1);
    });

    testWidgets('long press then drag moves a tile (phone slop, inside a scroll view)', (tester) async {
      phoneSlop(tester);
      List<String>? got;
      await pumpUi(tester, grid(onReorder: (ids) => got = ids));
      final from = tester.getCenter(find.text('p0'));
      final to = tester.getCenter(find.text('p4'));
      final g = await tester.startGesture(from, kind: ui.PointerDeviceKind.touch);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (var i = 1; i <= 10; i++) {
        await g.moveTo(Offset.lerp(from, to, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(got, ['p1', 'p2', 'p3', 'p4', 'p0', 'p5', 'p6', 'p7', 'p8']);
      expect(tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels, 0);
    });

    testWidgets('a quick swipe scrolls instead of moving a tile; a tap is a tap', (tester) async {
      phoneSlop(tester);
      List<String>? got;
      final taps = <String>[];
      await pumpUi(tester, grid(onReorder: (ids) => got = ids, onTap: taps.add));
      await tester.drag(find.text('p4'), const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(got, isNull);
      expect(tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels, greaterThan(0));
      await tester.tap(find.text('p5'));
      expect(taps, ['p5']);
    });

    testWidgets('remove fires remove, not tap', (tester) async {
      final taps = <String>[], removed = <String>[];
      await pumpUi(tester, grid(onTap: taps.add, onRemove: removed.add));
      await tester.tap(find.bySemanticsLabel('Remove Photo 2'));
      expect(removed, ['p2']);
      expect(taps, isEmpty);
    });

    testWidgets('arrow keys move a focused tile', (tester) async {
      final orders = <List<String>>[];
      await pumpUi(tester, grid(onReorder: orders.add, onTap: (_) {}));
      final node = tester.widget<UiInteractive>(find.ancestor(of: find.text('p0'), matching: find.byType(UiInteractive)).first).focusNode!;
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(orders, [
        ['p1', 'p0', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8'],
        ['p1', 'p2', 'p3', 'p4', 'p0', 'p5', 'p6', 'p7', 'p8'],
      ]);
    });

    testWidgets('golden', (tester) async {
      await expectThemedGolden(
        tester,
        'reorder_grid',
        (_) => UiReorderGrid(items: photos.take(5).toList(), coverId: 'p1', onReorder: (_) {}, onRemove: (_) {}, tileBuilder: tile),
        height: 300,
      );
    });
  });

  group('UiHandleField', () {
    Widget field(Future<UiHandleCheck> Function(String) check, {String value = '', String? suggestion, ValueChanged<String>? onChanged}) =>
        SizedBox(width: 358, child: UiHandleField(value: value, onChanged: onChanged ?? (_) {}, check: check, suggestion: suggestion, hint: 'invites.blog/@yourname'));

    testWidgets('lowercases and keeps only a-z 0-9 . _', (tester) async {
      String? last;
      await pumpUi(tester, field((h) async => const UiHandleCheck(UiHandleState.available), onChanged: (v) => last = v));
      await tester.enterText(find.byType(EditableText), 'My Studio!_2.0');
      await tester.pump();
      expect(last, 'mystudio_2.0');
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('too short says so without asking; then asks once after the pause', (tester) async {
      final asked = <String>[];
      await pumpUi(tester, field((h) async {
        asked.add(h);
        return const UiHandleCheck(UiHandleState.available);
      }));
      await tester.enterText(find.byType(EditableText), 'ab');
      await tester.pump(const Duration(milliseconds: 500));
      expect(asked, isEmpty);
      expect(find.text('At least 3 letters or numbers'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'abc');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(EditableText), 'abcd');
      await tester.pump(const Duration(milliseconds: 450));
      expect(asked, ['abcd']);
      expect(find.text('@abcd is free'), findsOneWidget);
    });

    testWidgets('an older answer never replaces a newer one', (tester) async {
      final slow = Completer<UiHandleCheck>();
      await pumpUi(tester, field((h) => h == 'first' ? slow.future : Future.value(const UiHandleCheck(UiHandleState.available))));
      await tester.enterText(find.byType(EditableText), 'first');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.enterText(find.byType(EditableText), 'second');
      await tester.pump(const Duration(milliseconds: 450));
      slow.complete(const UiHandleCheck(UiHandleState.taken));
      await tester.pump();
      expect(find.text('@second is free'), findsOneWidget);
      expect(find.textContaining('taken'), findsNothing);
    });

    testWidgets('taken shows the suggestion, and the chip fills it in', (tester) async {
      String? last;
      await pumpUi(tester, field((h) async => h == 'studio' ? const UiHandleCheck(UiHandleState.taken, suggestion: 'studio.mv') : const UiHandleCheck(UiHandleState.available), onChanged: (v) => last = v));
      await tester.enterText(find.byType(EditableText), 'studio');
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('@studio is taken'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Use @studio.mv'));
      await tester.pump();
      expect(last, 'studio.mv');
      expect(find.text('@studio.mv is free'), findsOneWidget);
    });

    testWidgets('a failed check says try again', (tester) async {
      await pumpUi(tester, field((h) => Future.error(StateError('offline'))));
      await tester.enterText(find.byType(EditableText), 'studio');
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text("Couldn't check. Try again."), findsOneWidget);
    });

    testWidgets('golden', (tester) async {
      await expectThemedGolden(
        tester,
        'handle_field',
        (_) => Column(mainAxisSize: MainAxisSize.min, children: [
          UiHandleField(value: '', onChanged: (_) {}, check: (_) async => const UiHandleCheck(UiHandleState.available), suggestion: 'lagoon.studio', hint: 'invites.blog/@yourname'),
        ]),
        height: 200,
      );
    });
  });

  group('UiThemeSwatch', () {
    test('reads CSS hex colours', () {
      expect(UiThemeSwatchColors.parse('#fff'), const Color.fromARGB(255, 255, 255, 255));
      expect(UiThemeSwatchColors.parse('#7a1f2b'), const Color.fromARGB(255, 0x7a, 0x1f, 0x2b));
      expect(UiThemeSwatchColors.parse('#7a1f2b80'), const Color.fromARGB(0x80, 0x7a, 0x1f, 0x2b));
      expect(UiThemeSwatchColors.parse('red'), isNull);
      expect(UiThemeSwatchColors.fromCss(bg: '#fff', surface: '#eee', text: '#111', muted: '#777', accent: null), isNull);
    });

    testWidgets('golden: a light and a dark set, and an accent override', (tester) async {
      final light = UiThemeSwatchColors.fromCss(bg: '#f6efe9', surface: '#ffffff', text: '#2a1215', muted: '#7d6a6c', accent: '#7a1f2b')!;
      final dark = UiThemeSwatchColors.fromCss(bg: '#160b0d', surface: '#221316', text: '#f3e6e7', muted: '#a58f92', accent: '#c9a45c')!;
      await expectThemedGolden(
        tester,
        'theme_swatch',
        (_) => Row(children: [
          Expanded(child: UiThemeSwatch(colors: light)),
          const SizedBox(width: 8),
          Expanded(child: UiThemeSwatch(colors: dark)),
          const SizedBox(width: 8),
          Expanded(child: UiThemeSwatch(colors: light, accent: UiThemeSwatchColors.parse('#2f6f5e'), label: 'Oxblood with green')),
        ]),
        height: 130,
      );
    });
  });
}

class _GridHolder extends StatefulWidget {
  const _GridHolder({required this.items, required this.tile, this.onReorder, this.onTap, this.onRemove});
  final List<UiReorderGridItem> items;
  final Widget Function(BuildContext, UiReorderGridItem) tile;
  final ValueChanged<List<String>>? onReorder;
  final ValueChanged<String>? onTap, onRemove;
  @override
  State<_GridHolder> createState() => _GridHolderState();
}

class _GridHolderState extends State<_GridHolder> {
  late var items = widget.items;
  @override
  Widget build(BuildContext context) => UiReorderGrid(
        items: items,
        tileBuilder: widget.tile,
        onTileTap: widget.onTap,
        onRemove: widget.onRemove,
        onReorder: (ids) {
          setState(() => items = [for (final id in ids) items.firstWhere((i) => i.id == id)]);
          widget.onReorder?.call(ids);
        },
      );
}
