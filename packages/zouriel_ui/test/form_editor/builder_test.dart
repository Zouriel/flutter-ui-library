import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import 'support.dart';

/// Hosts a builder the way an app does: the definition lives in the host and goes round-trip.
class Host extends StatefulWidget {
  const Host({super.key, required this.initial, this.controller});
  final UiFormDefinition initial;
  final UiFormBuilderController? controller;

  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  late UiFormDefinition def = widget.initial;
  UiFormDefinition? published;
  int count = 0;
  int changes = 0;

  void set(void Function() fn) => setState(fn);

  @override
  Widget build(BuildContext context) => UiFormBuilder(
    definition: def,
    controller: widget.controller,
    published: published,
    submissionCount: count,
    onChanged: (d) => setState(() {
      changes++;
      def = d;
    }),
  );
}

UiFormDefinition twoFields() => formOf([fj('a', 'text', {'label': 'First'}), fj('b', 'text', {'label': 'Second'})]);

Future<HostState> pumpBuilder(WidgetTester tester, UiFormDefinition def, {Size size = const Size(390, 844), UiFormBuilderController? controller}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(home: Host(initial: def, controller: controller)));
  await tester.pumpAndSettle();
  return tester.state<HostState>(find.byType(Host));
}

Finder iconButton(String label) => find.byWidgetPredicate((w) => w is UiIconButton && w.label == label);
List<String> labels(HostState h, [int page = 0]) => [for (final e in h.def.pages[page].elements) e is UiFbField ? e.label : e.id];

// Palette tiles pad their touch area and hit-test at the tile's centre, so a tap on a label inside
// one lands on the tile rather than the text: those taps pass `warnIfMissed: false`.

/// The settings sheet (the one that isn't "Add a field").
int sheetSnap(WidgetTester tester) => tester.widgetList<UiBottomSheet>(find.byType(UiBottomSheet)).firstWhere((s) => s.title != 'Add a field').snap;

void main() {
  group('phone', () {
    testWidgets('a tap selects a card and shows its toolbar; it does not open settings', (tester) async {
      final h = await pumpBuilder(tester, twoFields());
      expect(iconButton('Delete First'), findsNothing);
      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      expect(iconButton('Delete First'), findsOneWidget);
      expect(sheetSnap(tester), 0);
      expect(h.def.pages[0].elements.length, 2);
    });

    testWidgets('holding a card opens its settings in the sheet; the toolbar settings button does too', (tester) async {
      await pumpBuilder(tester, twoFields());
      await tester.longPress(find.text('Second'));
      await tester.pumpAndSettle();
      expect(sheetSnap(tester), 1);
      expect(find.widgetWithText(UiBottomSheet, 'Second'), findsWidgets);
      // Closing and reopening from the toolbar.
      final sheet = tester.widgetList<UiBottomSheet>(find.byType(UiBottomSheet)).first;
      sheet.onSnapChanged!(0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      await tester.tap(iconButton('Settings for First'));
      await tester.pumpAndSettle();
      expect(sheetSnap(tester), 1);
    });

    testWidgets('a moving finger is a scroll: it never opens settings', (tester) async {
      await pumpBuilder(tester, twoFields());
      final g = await tester.startGesture(tester.getCenter(find.text('First')));
      await tester.pump(const Duration(milliseconds: 100));
      await g.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 800));
      await g.up();
      await tester.pumpAndSettle();
      expect(sheetSnap(tester), 0);
    });

    testWidgets('adds a field from the Add sheet after the selected one, and writes it back', (tester) async {
      final h = await pumpBuilder(tester, twoFields());
      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add field'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Email'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(labels(h), ['First', 'Email address', 'Second']);
      expect((h.def.pages[0].elements[1] as UiFbField).key, 'email_address');
      expect(find.text('Add field'), findsOneWidget, reason: 'the sheet closed and the button is back');
    });

    testWidgets('deletes from the toolbar, then undoes from the toast', (tester) async {
      final h = await pumpBuilder(tester, twoFields());
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      await tester.tap(iconButton('Delete Second'));
      await tester.pumpAndSettle();
      expect(labels(h), ['First']);
      expect(find.text('Deleted “Second”'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(labels(h), ['First', 'Second']);
      expect(find.text('Deleted “Second”'), findsNothing);
    });

    testWidgets('asks before deleting a question other rules use, and removes those rules', (tester) async {
      final h = await pumpBuilder(tester, formOf([
        fj('a', 'toggle', {'label': 'Student'}),
        fj('b', 'text', {
          'label': 'School',
          'visibility': {
            'action': 'show',
            'when': {'ref': 'a', 'op': 'isTrue'},
          },
        }),
      ]));
      await tester.tap(find.text('Student'));
      await tester.pumpAndSettle();
      await tester.tap(iconButton('Delete Student'));
      await tester.pumpAndSettle();
      expect(find.text('Delete “Student”?'), findsOneWidget);
      expect(find.text('•  “School” decides when it shows'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(UiModal), matching: find.widgetWithText(UiButton, 'Delete')));
      await tester.pumpAndSettle();
      expect(labels(h), ['School']);
      expect((h.def.pages[0].elements[0] as UiFbField).visibility, isNull);
    });

    testWidgets('offers archiving when the question has answers', (tester) async {
      final h = await pumpBuilder(tester, twoFields());
      h.set(() {
        h.published = h.def;
        h.count = 4;
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      await tester.tap(iconButton('Delete First'));
      await tester.pumpAndSettle();
      expect(find.text('“First” has answers'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(UiModal), matching: find.widgetWithText(UiButton, 'Archive')));
      await tester.pumpAndSettle();
      expect(h.def.pages[0].elements.first.archived, isTrue);
      expect(find.text('Archived'), findsOneWidget);
    });

    testWidgets('keeps undo after the host stores a published copy back into the definition', (tester) async {
      final h = await pumpBuilder(tester, twoFields());
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      await tester.tap(iconButton('Delete Second'));
      await tester.pumpAndSettle();
      // Publish, the way the docs show it.
      h.set(() {
        h.def = h.def.clone()..revision = 1;
        h.published = h.def.clone();
      });
      await tester.pumpAndSettle();
      final undo = tester.widget<UiIconButton>(iconButton('Undo'));
      expect(undo.onPressed, isNotNull);
      await tester.tap(iconButton('Undo'));
      await tester.pumpAndSettle();
      expect(labels(h), ['First', 'Second']);
      expect(h.def.revision, 1);
      // The undone delete is now an unpublished change.
      expect(find.text('1 change'), findsOneWidget);
    });

    testWidgets('loads a different form the host sets, and starts its history fresh', (tester) async {
      final h = await pumpBuilder(tester, twoFields());
      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      await tester.tap(iconButton('Duplicate First'));
      await tester.pumpAndSettle();
      expect(tester.widget<UiIconButton>(iconButton('Undo')).onPressed, isNotNull);
      h.set(() => h.def = formOf([fj('z', 'number', {'label': 'Only one'})], id: 'other', title: 'Another'));
      await tester.pumpAndSettle();
      expect(find.text('Another'), findsWidgets);
      expect(find.text('Only one'), findsOneWidget);
      expect(tester.widget<UiIconButton>(iconButton('Undo')).onPressed, isNull);
    });

    testWidgets('starts empty forms with a friendly way in', (tester) async {
      final h = await pumpBuilder(tester, createDefinition(title: 'Blank'));
      expect(find.text('Start your form'), findsOneWidget);
      await tester.tap(find.text('Section'));
      await tester.pumpAndSettle();
      expect(h.def.pages[0].elements.single, isA<UiFbGroup>());
      expect(find.text('Start your form'), findsNothing);
    });

    testWidgets('Ctrl+Z and Ctrl+Shift+Z undo and redo', (tester) async {
      final h = await pumpBuilder(tester, twoFields());
      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      await tester.tap(iconButton('Duplicate First'));
      await tester.pumpAndSettle();
      expect(h.def.pages[0].elements.length, 3);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(h.def.pages[0].elements.length, 2);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(h.def.pages[0].elements.length, 3);
    });

    testWidgets('the problem pill goes to Logic, and a problem there goes back to its question', (tester) async {
      await pumpBuilder(tester, formOf([fj('a', 'text', {'label': 'Name', 'key': ''})]));
      await tester.tap(find.bySemanticsLabel('1 problem to fix'));
      await tester.pumpAndSettle();
      expect(find.text('Needs attention'), findsOneWidget);
      await tester.tap(find.textContaining('needs a data key'));
      await tester.pumpAndSettle();
      expect(find.text('Needs attention'), findsOneWidget, reason: 'the card shows its chip');
      expect(sheetSnap(tester), 1);
    });
  });

  group('tablet', () {
    testWidgets('palette, canvas and inspector side by side; tapping a palette item adds after the selection', (tester) async {
      final h = await pumpBuilder(tester, twoFields(), size: const Size(1280, 800));
      expect(find.byType(UiFbPalette), findsOneWidget);
      expect(find.byType(UiFbInspector), findsOneWidget);
      expect(find.byType(UiBottomSheet), findsNothing);
      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      expect(find.text('Short text'), findsWidgets, reason: 'the inspector names the type');
      await tester.tap(find.descendant(of: find.byType(UiFbPalette), matching: find.text('Number')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(labels(h), ['First', 'Number', 'Second']);
    });

    testWidgets('a palette item held and dragged onto the canvas lands where it was dropped', (tester) async {
      final h = await pumpBuilder(tester, twoFields(), size: const Size(1280, 800));
      final from = tester.getCenter(find.descendant(of: find.byType(UiFbPalette), matching: find.text('Phone')));
      final g = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 400));
      final to = tester.getTopLeft(find.text('Second')) + const Offset(10, -6);
      await g.moveTo(to);
      await tester.pump();
      expect(find.text('Phone'), findsNWidgets(2), reason: 'the ghost follows the finger');
      await g.up();
      await tester.pumpAndSettle();
      expect(labels(h), ['First', 'Phone number', 'Second']);
    });

    testWidgets('the medium layout opens the palette in a dialog from Add', (tester) async {
      final h = await pumpBuilder(tester, twoFields(), size: const Size(820, 1000));
      expect(find.byType(UiFbPalette), findsNothing);
      await tester.tap(find.widgetWithText(UiButton, 'Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(UiFbPalette), matching: find.text('Long text')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(UiFbPalette), findsNothing);
      expect(labels(h).last, 'Long answer');
    });
  });
}
