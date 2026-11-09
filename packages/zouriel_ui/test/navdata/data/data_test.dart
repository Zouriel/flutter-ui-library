import 'dart:ui' show PointerDeviceKind, Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../../helpers.dart';

const _nodes = [
  UiTreeNode(label: 'src', value: 'src', icon: HugeIcons.strokeRoundedFolder01, children: [
    UiTreeNode(label: 'app.ts', value: 'app', icon: HugeIcons.strokeRoundedFile01),
    UiTreeNode(label: 'lib', value: 'lib', children: [UiTreeNode(label: 'util.ts', value: 'util')]),
  ]),
  UiTreeNode(label: 'docs', value: 'docs', children: [UiTreeNode(label: 'guide.md', value: 'guide')]),
  UiTreeNode(label: 'README', value: 'readme'),
];

/// A tree with its selection held by the test, like `[(selected)]`.
class _Host extends StatefulWidget {
  const _Host({this.selected, this.picked});
  final String? selected;
  final List<String>? picked;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String? sel = widget.selected;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 390,
        child: UiTree(
          label: 'Files',
          nodes: _nodes,
          selected: sel,
          onSelect: (n) {
            widget.picked?.add(n.value);
            setState(() => sel = n.value);
          },
        ),
      );
}

String? get _focused {
  final l = FocusManager.instance.primaryFocus?.debugLabel;
  return l != null && l.startsWith('tree ') ? l.substring(5) : l;
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey k, {String? character}) async {
  await tester.sendKeyEvent(k, character: character);
  await tester.pump();
}

Finder _row(String label) => find.ancestor(of: find.text(label), matching: find.byType(UiInteractive)).first;

/// Focuses a row the way a keyboard user would land on it.
Future<void> _focusRow(WidgetTester tester, String label) async {
  final node = tester.widget<UiInteractive>(_row(label)).focusNode!;
  node.requestFocus();
  await tester.pump();
}

const _layers = [
  UiTreeNode(label: 'Title', value: 'title'),
  UiTreeNode(label: 'Group', value: 'group', children: [
    UiTreeNode(label: 'Photo', value: 'photo'),
    UiTreeNode(label: 'Frame', value: 'frame', children: [UiTreeNode(label: 'Shape', value: 'shape')]),
  ]),
  UiTreeNode(label: 'Empty', value: 'empty', container: true),
  UiTreeNode(label: 'Hidden', value: 'hidden', muted: true),
];

/// A layers panel: multiple selection, open nodes and moves held by the test.
class _Layers extends StatefulWidget {
  const _Layers({required this.log, this.multiple = true, this.reorderable = true, this.renamable = true});
  final _LayersLog log;
  final bool multiple;
  final bool reorderable;
  final bool renamable;
  @override
  State<_Layers> createState() => _LayersState();
}

class _LayersLog {
  String? selected;
  List<String> values = [];
  Set<String> open = {'group'};
  final moves = <UiTreeMove>[];
  final activated = <String>[];
  final renames = <(String, String)>[];
  final eyes = <String>[];
}

class _LayersState extends State<_Layers> {
  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    return SizedBox(
      width: 390,
      child: UiTree(
        label: 'Layers',
        nodes: _layers,
        multiple: widget.multiple,
        reorderable: widget.reorderable,
        renamable: widget.renamable,
        selected: log.selected,
        onSelect: (n) => setState(() => log.selected = n.value),
        selectedValues: log.values,
        onSelectedValuesChanged: (v) => setState(() => log.values = v),
        expanded: log.open,
        onExpandedChanged: (v) => setState(() => log.open = v),
        onMove: log.moves.add,
        onActivate: (n) => log.activated.add(n.value),
        onRename: (value, label) => log.renames.add((value, label)),
        trailingBuilder: (context, n) => UiButton(size: UiSize.sm, variant: UiButtonVariant.ghost, onPressed: () => log.eyes.add(n.value), child: Text('Eye ${n.label}')),
      ),
    );
  }
}

Future<void> _tapWith(WidgetTester tester, String label, List<LogicalKeyboardKey> keys) async {
  for (final k in keys) {
    await tester.sendKeyDownEvent(k);
  }
  await tester.tap(find.text(label));
  for (final k in keys.reversed) {
    await tester.sendKeyUpEvent(k);
  }
  await tester.pump();
}

/// Drags the row [from] with a mouse to [dy] (0..1) of the row [to]'s height, checking the drop
/// indicator half way with [during].
Future<void> _mouseDrag(WidgetTester tester, String from, String to, double dy, {void Function()? during}) async {
  final start = tester.getCenter(find.text(from));
  final rect = tester.getRect(_rowBox(to));
  final g = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
  await g.moveBy(const Offset(0, 6));
  await tester.pump();
  await g.moveTo(Offset(rect.left + 60, rect.top + rect.height * dy));
  await tester.pump();
  during?.call();
  await g.up();
  await tester.pump();
}

/// The box a row draws its background in (the drop target).
Finder _rowBox(String label) => find.ancestor(of: find.text(label), matching: find.byType(AnimatedContainer)).first;

void main() {
  group('UiTree', () {
    testWidgets('rows are read with level, position, expanded and selected state', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const _Host(selected: 'readme'));
      final src = tester.getSemantics(_row('src')).getSemanticsData();
      expect(src.label, 'src');
      expect(src.hint, 'level 1, 1 of 3');
      expect(src.flagsCollection.isExpanded, Tristate.isFalse);
      expect(src.hasAction(SemanticsAction.expand), isTrue);
      expect(src.hasAction(SemanticsAction.collapse), isFalse);
      final readme = tester.getSemantics(_row('README')).getSemanticsData();
      expect(readme.flagsCollection.isSelected, Tristate.isTrue);
      expect(readme.flagsCollection.isExpanded, Tristate.none);
      expect(find.bySemanticsLabel('Files'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('one tab stop: the first item, then the selected one', (tester) async {
      await pumpUi(tester, const _Host());
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focused, 'src');
      await pumpUi(tester, const _Host(selected: 'readme'));
      await tester.pumpWidget(const SizedBox()); // fresh tree
      await pumpUi(tester, const _Host(selected: 'readme'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focused, 'readme');
    });

    testWidgets('Up/Down through visible items, Home/End to the ends', (tester) async {
      await pumpUi(tester, const _Host());
      await _focusRow(tester, 'src');
      await _press(tester, LogicalKeyboardKey.arrowRight); // open src
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused, 'app');
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused, 'lib');
      await _press(tester, LogicalKeyboardKey.arrowDown); // lib is closed: util is skipped
      expect(_focused, 'docs');
      await _press(tester, LogicalKeyboardKey.end);
      expect(_focused, 'readme');
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused, 'readme');
      await _press(tester, LogicalKeyboardKey.home);
      expect(_focused, 'src');
      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(_focused, 'src');
    });

    testWidgets('Right opens then enters; Left closes then goes to the parent', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const _Host());
      await _focusRow(tester, 'src');
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(tester.getSemantics(_row('src')).getSemanticsData().flagsCollection.isExpanded, Tristate.isTrue);
      expect(_focused, 'src');
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_focused, 'app');
      await _press(tester, LogicalKeyboardKey.arrowRight); // leaf: nothing
      expect(_focused, 'app');
      await _press(tester, LogicalKeyboardKey.arrowLeft); // leaf: to parent
      expect(_focused, 'src');
      await _press(tester, LogicalKeyboardKey.arrowLeft); // open: close
      expect(find.text('app.ts'), findsNothing);
      expect(_focused, 'src');
      await _press(tester, LogicalKeyboardKey.arrowLeft); // closed root: nothing
      expect(_focused, 'src');
      handle.dispose();
    });

    testWidgets('Enter and Space select', (tester) async {
      final picked = <String>[];
      await pumpUi(tester, _Host(picked: picked));
      await _focusRow(tester, 'README');
      await _press(tester, LogicalKeyboardKey.enter);
      await _focusRow(tester, 'docs');
      await _press(tester, LogicalKeyboardKey.space);
      expect(picked, ['readme', 'docs']);
    });

    testWidgets('type-ahead jumps by first letter, wrapping; unknown letters do nothing', (tester) async {
      await pumpUi(tester, const _Host());
      await _focusRow(tester, 'src');
      await _press(tester, LogicalKeyboardKey.keyR, character: 'r');
      expect(_focused, 'readme');
      await _press(tester, LogicalKeyboardKey.keyS, character: 'S');
      expect(_focused, 'src');
      await _press(tester, LogicalKeyboardKey.keyZ, character: 'z');
      expect(_focused, 'src');
    });

    testWidgets('* expands every sibling, one level only', (tester) async {
      await pumpUi(tester, const _Host());
      await _focusRow(tester, 'README');
      await _press(tester, LogicalKeyboardKey.digit8, character: '*'); // Shift+8
      expect(find.text('app.ts'), findsOneWidget);
      expect(find.text('guide.md'), findsOneWidget);
      expect(find.text('util.ts'), findsNothing);
    });

    testWidgets('the chevron toggles without selecting; the row selects', (tester) async {
      final picked = <String>[];
      await pumpUi(tester, _Host(picked: picked));
      final chev = find.descendant(of: _row('src'), matching: find.byType(GestureDetector)).last;
      await tester.tap(chev);
      await tester.pump();
      expect(find.text('app.ts'), findsOneWidget);
      expect(picked, isEmpty);
      await tester.tap(find.text('app.ts'));
      await tester.pump();
      expect(picked, ['app']);
      // Children are indented by 16 per level.
      expect(tester.getTopLeft(find.text('app.ts')).dx - tester.getTopLeft(find.text('src')).dx, closeTo(16, 0.5));
    });

    testWidgets('collapsing over the focused item moves focus to the collapsed parent', (tester) async {
      await pumpUi(tester, const _Host());
      await _focusRow(tester, 'src');
      await _press(tester, LogicalKeyboardKey.arrowRight);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused, 'app');
      await tester.tap(find.descendant(of: _row('src'), matching: find.byType(GestureDetector)).last);
      await tester.pump();
      expect(find.text('app.ts'), findsNothing);
      expect(_focused, 'src');
    });

    testWidgets('a screen reader can expand and collapse a row', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const _Host());
      final node = tester.getSemantics(_row('docs'));
      node.owner!.performAction(node.id, SemanticsAction.expand);
      await tester.pump();
      expect(find.text('guide.md'), findsOneWidget);
      final open = tester.getSemantics(_row('docs'));
      expect(open.getSemanticsData().hasAction(SemanticsAction.collapse), isTrue);
      open.owner!.performAction(open.id, SemanticsAction.collapse);
      await tester.pump();
      expect(find.text('guide.md'), findsNothing);
      handle.dispose();
    });
  });

  group('UiTree layers', () {
    testWidgets('muted labels are drawn dimmed', (tester) async {
      await pumpUi(tester, _Layers(log: _LayersLog()));
      final t = tester.element(find.text('Hidden')).ui;
      final muted = tester.renderObject<RenderParagraph>(find.text('Hidden')).text.style!.color;
      final plain = tester.renderObject<RenderParagraph>(find.text('Title')).text.style!.color;
      expect(muted, t.textMuted);
      expect(plain, isNot(t.textMuted));
    });

    testWidgets('multiple: tap selects one, Ctrl/Meta toggles, Shift selects the visible range', (tester) async {
      final log = _LayersLog();
      await pumpUi(tester, _Layers(log: log));
      await tester.tap(find.text('Title'));
      await tester.pump();
      expect(log.values, ['title']);
      await _tapWith(tester, 'Frame', [LogicalKeyboardKey.controlLeft]);
      expect(log.values, ['title', 'frame']);
      expect(log.selected, 'frame');
      await _tapWith(tester, 'Title', [LogicalKeyboardKey.metaLeft]);
      expect(log.values, ['frame']);
      await tester.tap(find.text('Photo'));
      await tester.pump();
      await _tapWith(tester, 'Empty', [LogicalKeyboardKey.shiftLeft]);
      // Shape sits under the closed Frame, so it's not in the range.
      expect(log.values, ['photo', 'frame', 'empty']);
      expect(log.selected, 'empty');
      expect(tester.getSemantics(_row('Frame')).getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
      expect(tester.getSemantics(_row('Title')).getSemanticsData().flagsCollection.isSelected, isNot(Tristate.isTrue));
      await tester.tap(find.text('Title'));
      await tester.pump();
      await _tapWith(tester, 'Photo', [LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.controlLeft]);
      expect(log.values, ['title', 'group', 'photo']);
    });

    testWidgets('multiple: Space toggles the focused node, Enter selects only it', (tester) async {
      final log = _LayersLog();
      await pumpUi(tester, _Layers(log: log));
      await _focusRow(tester, 'Title');
      await _press(tester, LogicalKeyboardKey.space);
      await _focusRow(tester, 'Hidden');
      await _press(tester, LogicalKeyboardKey.space);
      expect(log.values, ['title', 'hidden']);
      await _press(tester, LogicalKeyboardKey.space);
      expect(log.values, ['title']);
      await _press(tester, LogicalKeyboardKey.enter);
      expect(log.values, ['hidden']);
    });

    testWidgets('single mode: modifiers do nothing special and selectedValues is untouched', (tester) async {
      final log = _LayersLog();
      await pumpUi(tester, _Layers(log: log, multiple: false));
      await tester.tap(find.text('Title'));
      await _tapWith(tester, 'Photo', [LogicalKeyboardKey.controlLeft]);
      expect(log.selected, 'photo');
      expect(log.values, isEmpty);
    });

    testWidgets('trailing content on every row; tapping it does not select', (tester) async {
      final log = _LayersLog();
      await pumpUi(tester, _Layers(log: log));
      expect(find.textContaining('Eye '), findsNWidgets(6));
      await tester.tap(find.text('Eye Photo'));
      await tester.pump();
      expect(log.eyes, ['photo']);
      expect(log.values, isEmpty);
      expect(log.selected, isNull);
      // The button is its own control for screen readers, not merged into the row.
      expect(tester.getSemantics(_row('Photo')).getSemanticsData().label, 'Photo');
      // The trailing slot sits at the row's end.
      expect(tester.getTopRight(find.text('Eye Photo')).dx, greaterThan(300));
    });

    testWidgets('expanded is held by the app: changes come back through onExpandedChanged', (tester) async {
      final log = _LayersLog();
      await pumpUi(tester, _Layers(log: log));
      expect(find.text('Photo'), findsOneWidget);
      await tester.tap(find.descendant(of: _row('Group'), matching: find.byType(GestureDetector)).last);
      await tester.pump();
      expect(log.open, isEmpty);
      expect(find.text('Photo'), findsNothing);
    });

    testWidgets('Alt+Up/Down moves the focused node among its siblings, stopping at the ends', (tester) async {
      final log = _LayersLog();
      await pumpUi(tester, _Layers(log: log));
      await _focusRow(tester, 'Photo');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await _press(tester, LogicalKeyboardKey.arrowUp); // already first in its group
      expect(log.moves, isEmpty);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      expect(log.moves, [const UiTreeMove(value: 'photo', parent: 'group', index: 1)]);
      expect(_focused, 'photo');
    });

    testWidgets('Alt+Down is a plain Down when not reorderable', (tester) async {
      final log = _LayersLog();
      await pumpUi(tester, _Layers(log: log, reorderable: false));
      await _focusRow(tester, 'Title');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      expect(log.moves, isEmpty);
      expect(_focused, 'group');
    });

    testWidgets('mouse drag shows where the row lands and reports the move', (tester) async {
      final log = _LayersLog();
      await pumpUi(tester, _Layers(log: log));
      Finder line() => find.descendant(of: find.byType(UiTree), matching: find.byType(PositionedDirectional));
      // Top of Title: before it.
      await _mouseDrag(tester, 'Hidden', 'Title', 0.1, during: () {
        expect(line(), findsOneWidget);
        expect(tester.widget<Opacity>(find.ancestor(of: find.text('Hidden'), matching: find.byType(Opacity)).first).opacity, 0.5);
      });
      expect(log.moves.last, const UiTreeMove(value: 'hidden', parent: null, index: 0));
      expect(line(), findsNothing);
      expect(log.values, isEmpty, reason: 'a drag does not select');
      // Middle of an empty container: into it, outlined.
      await _mouseDrag(tester, 'Title', 'Empty', 0.5, during: () {
        expect(line(), findsNothing);
        expect(tester.widget<AnimatedContainer>(_rowBox('Empty')).foregroundDecoration, isNotNull);
      });
      expect(log.moves.last, const UiTreeMove(value: 'title', parent: 'empty', index: 0));
      // Lower part of an open parent: its first child.
      await _mouseDrag(tester, 'Hidden', 'Group', 0.9);
      expect(log.moves.last, const UiTreeMove(value: 'hidden', parent: 'group', index: 0));
      // A leaf has no inside: lower half of Photo is after it.
      await _mouseDrag(tester, 'Title', 'Photo', 0.7);
      expect(log.moves.last, const UiTreeMove(value: 'title', parent: 'group', index: 1));
      expect(log.moves, hasLength(4));
    });

    testWidgets('never into itself or its descendants, nor where it already is', (tester) async {
      final log = _LayersLog();
      await pumpUi(tester, _Layers(log: log));
      for (final target in ['Group', 'Photo', 'Frame']) {
        await _mouseDrag(tester, 'Group', target, 0.5, during: () {
          expect(find.descendant(of: find.byType(UiTree), matching: find.byType(PositionedDirectional)), findsNothing);
        });
      }
      await _mouseDrag(tester, 'Group', 'Title', 0.9); // just below Title is where Group is
      expect(log.moves, isEmpty);
    });

    testWidgets('a mouse press that barely moves still selects; Escape cancels a drag', (tester) async {
      final log = _LayersLog();
      await pumpUi(tester, _Layers(log: log));
      final g = await tester.startGesture(tester.getCenter(find.text('Title')), kind: PointerDeviceKind.mouse);
      // Past the pointer's pan slop but under the tree's 4px.
      await g.moveBy(const Offset(0, 3));
      await g.moveBy(const Offset(0, 0.5));
      await g.up();
      await tester.pump();
      expect(log.values, ['title']);
      expect(log.moves, isEmpty);
      final g2 = await tester.startGesture(tester.getCenter(find.text('Hidden')), kind: PointerDeviceKind.mouse);
      await g2.moveBy(const Offset(0, 6));
      await g2.moveTo(tester.getRect(_rowBox('Title')).topCenter + const Offset(0, 2));
      await tester.pump();
      Finder line() => find.descendant(of: find.byType(UiTree), matching: find.byType(PositionedDirectional));
      expect(line(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(line(), findsNothing);
      await tester.pump();
      await g2.up();
      await tester.pump();
      expect(log.moves, isEmpty);
    });

    testWidgets('touch: long-press then drag moves; a plain drag scrolls instead', (tester) async {
      final log = _LayersLog();
      await pumpUi(tester, _Layers(log: log));
      final target = tester.getRect(_rowBox('Title'));
      final g = await tester.startGesture(tester.getCenter(find.text('Hidden')));
      await tester.pump(const Duration(milliseconds: 600));
      await g.moveTo(Offset(target.left + 60, target.top + 3));
      await tester.pump();
      await g.up();
      await tester.pump();
      expect(log.moves, [const UiTreeMove(value: 'hidden', parent: null, index: 0)]);
      await tester.drag(find.text('Hidden'), Offset(0, -(tester.getCenter(find.text('Hidden')).dy - target.top)));
      await tester.pump();
      expect(log.moves, hasLength(1));
    });

    testWidgets('golden: a layers panel (muted layer, eye/lock buttons, two selected)', (tester) async {
      await expectThemedGolden(tester, 'tree_layers', height: 380, (context) => UiTree(
        label: 'Layers',
        nodes: _layers,
        multiple: true,
        reorderable: true,
        onMove: (_) {},
        selectedValues: const ['photo', 'empty'],
        expanded: const {'group', 'frame'},
        trailingBuilder: (context, n) => Row(mainAxisSize: MainAxisSize.min, children: [
          UiIconButton(size: UiSize.sm, icon: UiIcon(n.muted ? HugeIcons.strokeRoundedViewOffSlash : HugeIcons.strokeRoundedView), label: 'Hide ${n.label}', onPressed: () {}),
          UiIconButton(size: UiSize.sm, icon: const UiIcon(HugeIcons.strokeRoundedSquareUnlock02), label: 'Lock ${n.label}', onPressed: () {}),
        ]),
      ));
    });

    testWidgets('double tap on a label, or F2, activates', (tester) async {
      final log = _LayersLog();
      await pumpUi(tester, _Layers(log: log));
      await tester.tap(find.text('Photo'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Photo'));
      await tester.pump();
      expect(log.activated, ['photo']);
      // Two taps far apart in time are two single taps.
      await tester.tap(find.text('Title'));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tap(find.text('Title'));
      await tester.pump();
      expect(log.activated, ['photo']);
      await _focusRow(tester, 'Frame');
      await _press(tester, LogicalKeyboardKey.f2);
      expect(log.activated, ['photo', 'frame']);
    });

    testWidgets('F2 and double tap start a focused rename with all text selected', (tester) async {
      final log = _LayersLog();
      await pumpUi(tester, _Layers(log: log));
      await _focusRow(tester, 'Title');
      await _press(tester, LogicalKeyboardKey.f2);
      var edit = tester.widget<EditableText>(find.byType(EditableText));
      expect(edit.controller.text, 'Title');
      expect(edit.controller.selection, const TextSelection(baseOffset: 0, extentOffset: 5));
      expect(edit.focusNode.hasPrimaryFocus, isTrue);
      expect(find.bySemanticsLabel('Rename Title'), findsOneWidget);
      expect(log.activated, ['title']);
      await _press(tester, LogicalKeyboardKey.escape);
      await tester.tap(find.text('Photo'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Photo'));
      await tester.pump();
      edit = tester.widget<EditableText>(find.byType(EditableText));
      expect(edit.controller.text, 'Photo');
      expect(log.activated, ['title', 'photo']);
    });

    testWidgets('Enter commits once with a trimmed label; unchanged and empty emit nothing', (tester) async {
      final log = _LayersLog();
      await pumpUi(tester, _Layers(log: log));
      Future<void> edit(String label, String text) async {
        await _focusRow(tester, label);
        await _press(tester, LogicalKeyboardKey.f2);
        await tester.enterText(find.byType(EditableText), text);
        await _press(tester, LogicalKeyboardKey.enter);
      }

      await edit('Title', '  New title  ');
      expect(log.renames, [('title', 'New title')]);
      await edit('Photo', ' Photo ');
      await edit('Hidden', '   ');
      expect(log.renames, [('title', 'New title')]);
    });

    testWidgets('blur commits a changed label', (tester) async {
      final log = _LayersLog();
      await pumpUi(tester, _Layers(log: log));
      await _focusRow(tester, 'Title');
      await _press(tester, LogicalKeyboardKey.f2);
      await tester.enterText(find.byType(EditableText), '  Heading  ');
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump();
      expect(log.renames, [('title', 'Heading')]);
      expect(find.byType(EditableText), findsNothing);
    });

    testWidgets('Escape cancels and refocuses the row', (tester) async {
      final log = _LayersLog();
      await pumpUi(tester, _Layers(log: log));
      await _focusRow(tester, 'Title');
      await _press(tester, LogicalKeyboardKey.f2);
      await tester.enterText(find.byType(EditableText), 'Changed');
      await _press(tester, LogicalKeyboardKey.escape);
      await tester.pump();
      expect(log.renames, isEmpty);
      expect(find.byType(EditableText), findsNothing);
      expect(_focused, 'title');
    });

    testWidgets('editing owns Space and arrows, and tapping it does not select or drag', (tester) async {
      final log = _LayersLog();
      await pumpUi(tester, _Layers(log: log));
      await _focusRow(tester, 'Title');
      await _press(tester, LogicalKeyboardKey.f2);
      await tester.tap(find.byType(EditableText));
      await _press(tester, LogicalKeyboardKey.space);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(log.values, isEmpty);
      expect(log.selected, isNull);
      expect(log.moves, isEmpty);
      expect(find.byType(EditableText), findsOneWidget);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'tree rename');
    });

    testWidgets('renamable false never shows an editor but still activates', (tester) async {
      final log = _LayersLog();
      await pumpUi(tester, _Layers(log: log, renamable: false));
      await _focusRow(tester, 'Title');
      await _press(tester, LogicalKeyboardKey.f2);
      await tester.tap(find.text('Photo'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Photo'));
      await tester.pump();
      expect(find.byType(EditableText), findsNothing);
      expect(log.activated, ['title', 'photo']);
    });
  });

  group('UiTimeline / UiDescriptionList / UiCodeBlock', () {
    testWidgets('timeline is a list; the connector stops at the last event', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const SizedBox(width: 390, child: UiTimeline(items: [
        UiTimelineItem(title: 'Created', meta: '09:00'),
        UiTimelineItem(title: 'Paid', tone: UiStatus.success, icon: HugeIcons.strokeRoundedTick02),
        UiTimelineItem(title: 'Shipped', description: 'Courier picked it up'),
      ])));
      expect(tester.getSemantics(find.byType(UiTimeline)).getSemanticsData().role, SemanticsRole.list);
      // Two connectors for three events.
      final lines = find.descendant(of: find.byType(UiTimeline), matching: find.byWidgetPredicate((w) => w is ColoredBox));
      expect(lines, findsNWidgets(2));
      // With an icon marker the marker column is 20 wide, so titles line up at 20 + 12.
      expect(tester.getTopLeft(find.text('Shipped')).dx, 32);
      handle.dispose();
    });

    testWidgets('description list: row layout beside, stacked below; narrow rows stack', (tester) async {
      const items = [UiDescriptionItem(term: 'Status', detail: 'Active'), UiDescriptionItem(term: 'Plan', detail: 'Studio')];
      await pumpUi(tester, const SizedBox(width: 390, child: UiDescriptionList(items: items)));
      expect(tester.getTopLeft(find.text('Active')).dx, 140 + 16);
      await pumpUi(tester, const SizedBox(width: 390, child: UiDescriptionList(items: items, layout: UiDescriptionLayout.stacked)));
      expect(tester.getTopLeft(find.text('Active')).dy, greaterThan(tester.getBottomLeft(find.text('Status')).dy - 1));
      await pumpUi(tester, const SizedBox(width: 250, child: UiDescriptionList(items: items)));
      expect(tester.getTopLeft(find.text('Active')).dx, 0);
    });

    testWidgets('description list pairs are read together', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const SizedBox(width: 390, child: UiDescriptionList(items: [UiDescriptionItem(term: 'Status', detail: 'Active')])));
      expect(find.bySemanticsLabel('Status\nActive'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('code block copies, says so, and resets; a refused clipboard says it failed', (tester) async {
      String? copied;
      var fail = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          if (fail) throw PlatformException(code: 'denied');
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pumpUi(tester, const SizedBox(width: 390, child: UiCodeBlock(code: 'final x = 1;\n\tprint(x);', language: 'dart')));
      expect(find.text('DART'), findsOneWidget);
      // Icon plus label, like the other copy buttons; the icon follows the state.
      expect(find.byWidgetPredicate((w) => w is UiIcon && w.icon == HugeIcons.strokeRoundedCopy01), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(copied, 'final x = 1;\n\tprint(x);');
      expect(find.text('Copied'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is UiIcon && w.icon == HugeIcons.strokeRoundedTick02), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.text('Copy'), findsOneWidget);
      fail = true;
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(find.text('Copy failed'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1600));
    });

    testWidgets('long code lines scroll instead of wrapping', (tester) async {
      await pumpUi(tester, SizedBox(width: 300, child: UiCodeBlock(code: 'x' * 200)));
      expect(tester.getSize(find.byType(UiCodeBlock)).width, 300);
      expect(tester.getSize(find.textContaining('xxxx')).height, lessThan(30));
      expect(tester.takeException(), isNull);
      // The cut-off right edge fades out.
      expect(find.descendant(of: find.byType(UiScrollFade), matching: find.byType(ShaderMask)), findsOneWidget);
    });
  });

  testWidgets('guidelines: tap targets, labels, contrast', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final handle = tester.ensureSemantics();
    try {
      await pumpUi(tester, Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: [
          const UiTimeline(items: [UiTimelineItem(title: 'Created', meta: 'Monday'), UiTimelineItem(title: 'Shipped', description: 'Courier picked it up')]),
          const UiDescriptionList(items: [UiDescriptionItem(term: 'Status', detail: 'Active')]),
          const UiCodeBlock(code: 'final answer = 42;', language: 'dart'),
        ]),
      ));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      // Tree rows: short labels beside muted icons fool the pixel sampler (it picks the icon's
      // antialiased edge as the text colour), so targets are checked on screen, colours on tokens.
      await pumpUi(tester, UiTree(nodes: _nodes, selected: 'readme', onSelect: (_) {}));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      for (final th in UiThemeName.values) {
        final t = uiThemeTokens[th]!;
        double ratio(Color x, Color y) {
          final lx = x.computeLuminance(), ly = y.computeLuminance();
          return ((lx > ly ? lx : ly) + 0.05) / ((lx > ly ? ly : lx) + 0.05);
        }
        expect(ratio(t.text, t.bg), greaterThanOrEqualTo(4.5), reason: '$th row');
        expect(ratio(t.text, uiMix(t.selected, t.selected.a, t.bg).withValues(alpha: 1)), greaterThanOrEqualTo(4.5), reason: '$th selected row');
      }
    } finally {
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('golden: tree, timeline, description list, code block', (tester) async {
    await expectThemedGolden(tester, 'data', height: 900, (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        UiTree(nodes: _nodes, selected: 'app', initiallyExpanded: const {'src', 'lib'}, onSelect: (_) {}),
        const UiTimeline(items: [
          UiTimelineItem(title: 'Order placed', meta: '09:12', description: 'Two items, paid by card'),
          UiTimelineItem(title: 'Payment confirmed', meta: '09:13', tone: UiStatus.success),
          UiTimelineItem(title: 'Address check', meta: '10:40', tone: UiStatus.warning, description: 'Waiting on the courier'),
          UiTimelineItem(title: 'Cancelled item', tone: UiStatus.danger),
        ]),
        const UiTimeline(items: [
          UiTimelineItem(title: 'Draft', icon: HugeIcons.strokeRoundedFile01, tone: UiStatus.neutral),
          UiTimelineItem(title: 'Published', icon: HugeIcons.strokeRoundedTick02, tone: UiStatus.success, meta: 'Today'),
        ]),
        const UiDescriptionList(items: [
          UiDescriptionItem(term: 'Status', detail: 'Active'),
          UiDescriptionItem(term: 'Plan', detail: 'Studio, billed yearly with a long description that wraps'),
        ]),
        const UiCodeBlock(language: 'dart', code: "UiButton(\n  label: 'Save',\n  onPressed: save,\n)"),
      ],
    ));
  });
}
