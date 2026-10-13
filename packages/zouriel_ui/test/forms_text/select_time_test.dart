import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

const _fruit = [
  UiSelectOption(label: 'Apple', value: 'apple'),
  UiSelectOption(label: 'Banana', value: 'banana'),
  UiSelectOption(label: 'Blueberry', value: 'blueberry', disabled: true),
  UiSelectOption(label: 'Cherry', value: 'cherry'),
];

const _fonts = [
  UiSelectOption(label: 'Roboto', value: 'Roboto'),
  UiSelectOption(label: 'Space Grotesk', value: 'Space Grotesk'),
  UiSelectOption(label: 'Mono', value: 'mono', fontFamily: 'JetBrains Mono'),
];

class _Sel extends StatefulWidget {
  const _Sel({this.initial, this.options = _fruit, this.fontPreview = false, this.fontPackage, required this.log});
  final String? initial;
  final List<UiSelectOption> options;
  final bool fontPreview;
  final String? fontPackage;
  final List<String> log;
  @override
  State<_Sel> createState() => _SelState();
}

class _SelState extends State<_Sel> {
  late String? v = widget.initial;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 260,
        child: UiSelect(
          options: widget.options,
          value: v,
          label: 'Fruit',
          placeholder: 'Pick one',
          fontPreview: widget.fontPreview,
          fontPackage: widget.fontPackage,
          onChanged: (x) => setState(() {
            v = x;
            widget.log.add(x);
          }),
        ),
      );
}

String? _familyOf(WidgetTester tester, String text) {
  final rich = tester.widget<RichText>(find.descendant(of: find.text(text).last, matching: find.byType(RichText)).first);
  return rich.text.style?.fontFamily;
}

void main() {
  group('select', () {
    testWidgets('shows the placeholder, opens on tap, picks an option and closes', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      await pumpUi(tester, _Sel(log: log));
      expect(find.text('Pick one'), findsOneWidget);
      expect(find.bySemanticsLabel('Fruit'), findsOneWidget);
      await tester.tap(find.byType(UiSelect));
      await tester.pumpAndSettle();
      expect(find.byType(UiListboxPanel), findsOneWidget);
      await tester.tap(find.text('Cherry'));
      await tester.pumpAndSettle();
      expect(log, ['cherry']);
      expect(find.byType(UiListboxPanel), findsNothing);
      expect(find.text('Cherry'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Fruit')).getSemanticsData().value, 'Cherry');
      handle.dispose();
    });

    testWidgets('disabled options cannot be picked', (tester) async {
      final log = <String>[];
      await pumpUi(tester, _Sel(log: log));
      await tester.tap(find.byType(UiSelect));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blueberry'));
      await tester.pumpAndSettle();
      expect(log, isEmpty);
    });

    testWidgets('keyboard: ArrowDown opens with the chosen option active; arrows skip disabled; Enter picks; focus returns', (tester) async {
      final log = <String>[];
      await pumpUi(tester, _Sel(initial: 'banana', log: log));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final panel = tester.widget<UiListboxPanel>(find.byType(UiListboxPanel));
      expect(panel.activeIndex, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(tester.widget<UiListboxPanel>(find.byType(UiListboxPanel)).activeIndex, 3, reason: 'Blueberry is disabled');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(log, ['cherry']);
      expect(find.byType(UiListboxPanel), findsNothing);
      // Focus is back on the field: Space reopens it.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.byType(UiListboxPanel), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(UiListboxPanel), findsNothing);
      expect(log, ['cherry']);
    });

    testWidgets('typing a letter jumps to the matching option; Home/End go to the ends', (tester) async {
      await pumpUi(tester, _Sel(log: []));
      await tester.tap(find.byType(UiSelect));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC, character: 'c');
      await tester.pump();
      expect(tester.widget<UiListboxPanel>(find.byType(UiListboxPanel)).activeIndex, 3);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(tester.widget<UiListboxPanel>(find.byType(UiListboxPanel)).activeIndex, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(tester.widget<UiListboxPanel>(find.byType(UiListboxPanel)).activeIndex, 3);
    });

    testWidgets('the list matches the field width and its rows are full touch targets', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, _Sel(log: []));
      await tester.tap(find.byType(UiSelect));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(UiListboxPanel)).width, 260);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('fontPreview draws each option and the closed field in its own font', (tester) async {
      final log = <String>[];
      await pumpUi(tester, _Sel(options: _fonts, initial: 'Space Grotesk', fontPreview: true, fontPackage: 'zouriel_ui', log: log));
      // Closed field: the chosen value's font, from the package.
      expect(_familyOf(tester, 'Space Grotesk'), 'packages/zouriel_ui/Space Grotesk');
      await tester.tap(find.byType(UiSelect));
      await tester.pumpAndSettle();
      final panel = find.byType(UiListboxPanel);
      String? optionFamily(String label) => tester
          .widget<RichText>(find.descendant(of: find.descendant(of: panel, matching: find.text(label)), matching: find.byType(RichText)))
          .text
          .style
          ?.fontFamily;
      expect(optionFamily('Roboto'), 'packages/zouriel_ui/Roboto');
      expect(optionFamily('Space Grotesk'), 'packages/zouriel_ui/Space Grotesk');
      // An option's own fontFamily wins over its value.
      expect(optionFamily('Mono'), 'packages/zouriel_ui/JetBrains Mono');
      await tester.tap(find.descendant(of: panel, matching: find.text('Mono')));
      await tester.pumpAndSettle();
      expect(_familyOf(tester, 'Mono'), 'packages/zouriel_ui/JetBrains Mono');
    });

    testWidgets('without fontPreview only options with a fontFamily get a font, and the field keeps the theme font', (tester) async {
      await pumpUi(tester, _Sel(options: _fonts, initial: 'mono', log: []));
      final themeFamily = tester.widget<RichText>(find.descendant(of: find.text('Mono'), matching: find.byType(RichText))).text.style?.fontFamily;
      expect(themeFamily, 'packages/zouriel_ui/Roboto');
      await tester.tap(find.byType(UiSelect));
      await tester.pumpAndSettle();
      final panel = find.byType(UiListboxPanel);
      String? optionFamily(String label) => tester
          .widget<RichText>(find.descendant(of: find.descendant(of: panel, matching: find.text(label)), matching: find.byType(RichText)))
          .text
          .style
          ?.fontFamily;
      expect(optionFamily('Space Grotesk'), 'packages/zouriel_ui/Roboto');
      expect(optionFamily('Mono'), 'JetBrains Mono', reason: 'no package given: an app or system font');
    });
  });

  group('time picker', () {
    testWidgets('opens columns; tapping hours and minutes builds HH:MM', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      var v = '09:15';
      await pumpUi(tester, StatefulBuilder(builder: (context, set) => SizedBox(
            width: 200,
            child: UiTimePicker(value: v, label: 'Start', step: 900, onChanged: (x) => set(() {
              v = x;
              log.add(x);
            })),
          )));
      expect(tester.getSemantics(find.bySemanticsLabel('Start')).getSemanticsData().value, '09:15');
      await tester.tap(find.byType(UiTimePicker));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Hours'), findsOneWidget);
      // 15-minute steps.
      expect(find.bySemanticsLabel('45 minutes'), findsOneWidget);
      expect(find.bySemanticsLabel('10 minutes'), findsNothing);
      await tester.tap(find.bySemanticsLabel('10 hours'));
      await tester.pump();
      expect(log.last, '10:15');
      await tester.tap(find.bySemanticsLabel('45 minutes'));
      await tester.pump();
      expect(log.last, '10:45');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('keyboard: arrows change the active column, Left/Right switch, Enter closes', (tester) async {
      final log = <String>[];
      var v = '23:59';
      await pumpUi(tester, StatefulBuilder(builder: (context, set) => SizedBox(
            width: 200,
            child: UiTimePicker(value: v, label: 'Start', onChanged: (x) => set(() {
              v = x;
              log.add(x);
            })),
          )));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(log.last, '00:59', reason: 'hours wrap');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(log.last, '00:58');
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(log.last, '00:00');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Hours'), findsNothing);
    });

    testWidgets('a step under a minute adds seconds', (tester) async {
      final log = <String>[];
      await pumpUi(tester, SizedBox(width: 200, child: UiTimePicker(label: 'T', step: 1, onChanged: log.add)));
      expect(find.text('--:--:--'), findsOneWidget);
      await tester.tap(find.byType(UiTimePicker));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('05 seconds'));
      expect(log.last, '00:00:05');
    });
  });
}
