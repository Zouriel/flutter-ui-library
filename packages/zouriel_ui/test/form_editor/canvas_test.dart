import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import 'support.dart';

class Log {
  final opened = <String>[];
  final picked = <String?>[];
  final deleted = <String>[];
  final addAt = <UiFbDropTarget>[];
}

Future<(UiFormBuilderController, Log)> pumpCanvas(WidgetTester tester, UiFormDefinition def, {Size size = const Size(390, 844)}) async {
  final c = UiFormBuilderController(definition: def);
  final log = Log();
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(
    home: UiFbBuilderScope(
      controller: c,
      child: UiFbCanvas(onOpen: log.opened.add, onPicked: log.picked.add, onDeleteRequest: log.deleted.add, onAddAt: log.addAt.add),
    ),
  ));
  await tester.pumpAndSettle();
  return (c, log);
}

List<String> ids(UiFormBuilderController c, [int page = 0]) => [for (final e in c.def.pages[page].elements) e.id];
Finder iconButton(String label) => find.byWidgetPredicate((w) => w is UiIconButton && w.label == label);

/// Drags [id]'s grip so the finger ends at [to].
Future<void> dragGrip(WidgetTester tester, String name, Offset to) async {
  final grip = find.bySemanticsLabel('Drag $name to move it');
  final g = await tester.startGesture(tester.getCenter(grip));
  await tester.pump();
  for (var i = 1; i <= 6; i++) {
    final from = tester.getCenter(grip);
    await g.moveTo(Offset.lerp(from, to, i / 6)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await tester.pumpAndSettle();
}

void main() {
  final three = formOf([fj('a', 'text', {'label': 'First'}), fj('b', 'text', {'label': 'Second'}), fj('c', 'text', {'label': 'Third'})]);

  testWidgets('a tap only selects a card, so its toolbar can be used', (tester) async {
    final (c, log) = await pumpCanvas(tester, three);
    await tester.tap(find.text('First'));
    await tester.pump();
    expect(log.picked, ['a']);
    expect(log.opened, isEmpty);
    expect(c.selectedId, 'a');
    expect(iconButton('Settings for First'), findsOneWidget);
  });

  testWidgets('holding a card opens its settings, and the lift that follows is not a second tap', (tester) async {
    final (c, log) = await pumpCanvas(tester, three);
    final g = await tester.startGesture(tester.getCenter(find.text('Second')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(log.opened, isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    expect(log.opened, ['b']);
    await g.up();
    await tester.pump();
    expect(log.picked, isEmpty);
    expect(c.selectedId, 'b');
  });

  testWidgets('a finger that moves (a scroll) never opens settings', (tester) async {
    final (_, log) = await pumpCanvas(tester, three);
    final g = await tester.startGesture(tester.getCenter(find.text('First')));
    await g.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(seconds: 1));
    await g.up();
    await tester.pumpAndSettle();
    expect(log.opened, isEmpty);
  });

  testWidgets('opens settings from the toolbar or with Enter; Delete asks to delete; Alt+arrows move', (tester) async {
    final (c, log) = await pumpCanvas(tester, three);
    await tester.tap(find.text('First'));
    await tester.pump();
    await tester.tap(iconButton('Settings for First'));
    await tester.pump();
    expect(log.opened, ['a']);

    // Keyboard: focus the card, then Enter, Delete and Alt+Down.
    final card = find.ancestor(of: find.text('First'), matching: find.byType(Focus)).first;
    Focus.of(tester.element(find.text('First'))).requestFocus();
    await tester.pump();
    expect(card, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(log.opened, ['a', 'a']);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    expect(log.deleted, ['a']);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(ids(c), ['b', 'a', 'c']);
  });

  testWidgets('the toolbar moves, duplicates and deletes', (tester) async {
    final (c, log) = await pumpCanvas(tester, three);
    await tester.tap(find.text('Second'));
    await tester.pump();
    await tester.tap(iconButton('Move Second up'));
    await tester.pump();
    expect(ids(c), ['b', 'a', 'c']);
    await tester.tap(iconButton('Move Second down'));
    await tester.pump();
    await tester.tap(iconButton('Duplicate Second'));
    await tester.pumpAndSettle();
    expect(ids(c), hasLength(4));
    expect(ids(c)[2], c.selectedId);
    await tester.tap(iconButton('Delete Second'));
    expect(log.deleted, [c.selectedId]);
  });

  testWidgets('drags a card by its grip to reorder it', (tester) async {
    final (c, _) = await pumpCanvas(tester, three);
    // Drop "First" below the last card: the end of the page.
    await dragGrip(tester, 'First', tester.getBottomLeft(find.text('Third')) + const Offset(40, 80));
    expect(ids(c), ['b', 'c', 'a']);
    // And "Third" back above "Second".
    await dragGrip(tester, 'Third', tester.getTopLeft(find.text('Second')) + const Offset(10, -2));
    expect(ids(c), ['c', 'b', 'a']);
  });

  testWidgets('drags a card into a section and out again; onto another page’s tab', (tester) async {
    final def = formOf([
      fj('a', 'text', {'label': 'First'}),
      {'kind': 'group', 'id': 'g', 'title': 'Box', 'elements': [fj('in', 'text', {'label': 'Inside'})]},
    ]);
    def.pages.add(UiFbPage(id: 'p2', title: 'Later', elements: []));
    final (c, _) = await pumpCanvas(tester, def);
    await dragGrip(tester, 'First', tester.getBottomLeft(find.text('Inside')) + const Offset(40, 14));
    expect(ids(c), ['g']);
    // Over the left half of a card means "before it".
    expect([for (final e in c.index['g']!.asGroup!.elements) e.id], ['a', 'in']);
    // A section can't be dropped into itself: it stays where it is.
    await dragGrip(tester, 'Box', tester.getCenter(find.text('Inside')));
    expect(ids(c), ['g']);
    // Onto the page tab: to the end of that page.
    await dragGrip(tester, 'First', tester.getCenter(find.text('Later')));
    expect(ids(c, 1), ['a']);
  });

  testWidgets('More moves a card out of its section or to another page, and archives it', (tester) async {
    final def = formOf([
      {'kind': 'group', 'id': 'g', 'title': 'Box', 'elements': [fj('in', 'text', {'label': 'Inside'})]},
    ]);
    def.pages.add(UiFbPage(id: 'p2', title: 'Later', elements: []));
    final (c, _) = await pumpCanvas(tester, def);
    await tester.tap(find.text('Inside'));
    await tester.pump();
    await tester.tap(iconButton('More actions for Inside'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move out of the section'));
    await tester.pumpAndSettle();
    expect(ids(c), ['g', 'in']);
    await tester.tap(iconButton('More actions for Inside'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive (hide, keep answers)'));
    await tester.pumpAndSettle();
    expect(c.field('in')!.archived, isTrue);
    expect(find.text('Archived'), findsOneWidget);
    await tester.tap(iconButton('More actions for Inside'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to Later'));
    await tester.pumpAndSettle();
    expect(ids(c, 1), ['in']);
    expect(c.pageIndex, 1);
  });

  testWidgets('a page can be opened, moved or deleted from its menu', (tester) async {
    final def = formOf([fj('a', 'text')]);
    def.pages.add(UiFbPage(id: 'p2', title: 'Second', elements: []));
    final (c, log) = await pumpCanvas(tester, def);
    await tester.tap(iconButton('Actions for Page 1'));
    await tester.pumpAndSettle();
    final earlier = tester.widget<UiMenu>(find.byType(UiMenu).first).items.firstWhere((i) => i.value == 'earlier');
    expect(earlier.disabled, isTrue);
    await tester.tap(find.text('Delete page'));
    await tester.pumpAndSettle();
    expect(log.deleted, ['p1']);
    await tester.tap(iconButton('Actions for Page 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move later'));
    await tester.pumpAndSettle();
    expect([for (final p in c.def.pages) p.id], ['p2', 'p1']);
    expect(c.pageIndex, 1);
    await tester.tap(find.text('Page 2').last, warnIfMissed: false);
    await tester.pump();
    expect(log.opened, ['p1']);
  });

  testWidgets('page tabs switch pages; tapping the current tab opens its settings; + adds a page', (tester) async {
    final def = formOf([fj('a', 'text', {'label': 'On one'})]);
    def.pages.add(UiFbPage(id: 'p2', title: 'Second', elements: [UiFbField(id: 'z', type: UiFbFieldType.text, key: 'z', label: 'On two')]));
    final (c, log) = await pumpCanvas(tester, def);
    expect(find.text('On two'), findsNothing);
    await tester.tap(find.text('Second'));
    await tester.pump();
    expect(find.text('On two'), findsOneWidget);
    expect(log.opened, isEmpty);
    await tester.tap(find.text('Second').first);
    await tester.pump();
    expect(log.opened, ['p2']);
    await tester.tap(find.bySemanticsLabel('Add a page (a new step)'));
    await tester.pumpAndSettle();
    expect(c.def.pages, hasLength(3));
    expect(find.text('This page is empty'), findsOneWidget);
  });

  testWidgets('add buttons ask the builder to add at the right place', (tester) async {
    final (c, log) = await pumpCanvas(tester, formOf([
      {'kind': 'group', 'id': 'g', 'title': 'Box', 'elements': [fj('in', 'text')]},
    ]));
    await tester.tap(find.text('Add to section'));
    await tester.tap(find.text('Add a field'));
    expect([for (final t in log.addAt) '${t.containerId}@${t.index}'], ['g@1', 'p1@1']);
    expect(c.def.pages[0].elements, hasLength(1));
  });

  testWidgets('cards show their rules and problems as chips', (tester) async {
    await pumpCanvas(tester, formOf([
      fj('a', 'toggle', {'label': 'Student'}),
      fj('b', 'text', {
        'label': 'School',
        'required': {
          'when': {'ref': 'a', 'op': 'isTrue'},
        },
        'visibility': {
          'action': 'show',
          'when': {'ref': 'a', 'op': 'isTrue'},
        },
        'validators': [
          {'id': 'v', 'type': 'minLength', 'params': {'min': 2}},
        ],
      }),
      fj('c', 'text', {'label': 'Broken', 'key': ''}),
    ]));
    for (final chip in ['Shown when…', 'Required when…', '1 check', 'Needs attention']) {
      expect(find.text(chip), findsOneWidget, reason: chip);
    }
  });

  testWidgets('meets the tap target and label guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpCanvas(tester, three);
    await tester.tap(find.text('First'));
    await tester.pump();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
