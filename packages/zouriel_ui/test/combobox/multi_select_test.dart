import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../forms_text/overlay_helpers.dart';
import '../helpers.dart';

const _tags = [
  UiComboboxOption(label: 'Design', value: 'design'),
  UiComboboxOption(label: 'Engineering', value: 'eng'),
  UiComboboxOption(label: 'Marketing', value: 'mkt'),
  UiComboboxOption(label: 'Sales', value: 'sales'),
];

class _Multi extends StatefulWidget {
  const _Multi({this.initial = const [], this.enabled = true, required this.log});
  final List<String> initial;
  final bool enabled;
  final List<List<String>> log;
  @override
  State<_Multi> createState() => _MultiState();
}

class _MultiState extends State<_Multi> {
  late List<String> v = widget.initial;
  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
          width: 320,
          child: UiMultiSelect(
            options: _tags,
            value: v,
            label: 'Teams',
            enabled: widget.enabled,
            onChanged: (x) => setState(() {
              v = x;
              widget.log.add(x);
            }),
          ),
        ),
        const SizedBox(width: 300, child: UiInput(semanticLabel: 'Other')),
      ]);
}

void main() {
  testWidgets('chips show the chosen labels; tapping options toggles them and the list stays open', (tester) async {
    final log = <List<String>>[];
    await pumpUi(tester, _Multi(initial: const ['eng'], log: log));
    expect(find.text('Engineering'), findsOneWidget);
    await tester.tap(find.byType(UiMultiSelect));
    await tester.pumpAndSettle();
    final panel = find.byType(UiListboxPanel);
    await tester.tap(find.descendant(of: panel, matching: find.text('Sales')));
    await tester.pump();
    expect(log.last, ['eng', 'sales'], reason: 'in the order chosen');
    expect(panel, findsOneWidget);
    await tester.tap(find.descendant(of: panel, matching: find.text('Engineering')));
    await tester.pump();
    expect(log.last, ['sales']);
  });

  testWidgets('type to filter; Enter toggles the active option; Backspace removes the last chip; Escape closes', (tester) async {
    final log = <List<String>>[];
    await pumpUi(tester, _Multi(log: log));
    await tester.tap(find.byType(EditableText).first);
    await tester.enterText(find.byType(EditableText).first, 'ing');
    await tester.pump();
    expect(tester.widget<UiListboxPanel>(find.byType(UiListboxPanel)).items.map((i) => i.label), ['Engineering', 'Marketing']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(log.last, ['mkt']);
    await tester.enterText(find.byType(EditableText).first, '');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(log.last, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(UiListboxPanel), findsNothing);
  });

  testWidgets('chip remove buttons and Clear all; checked semantics in the list', (tester) async {
    final handle = tester.ensureSemantics();
    final log = <List<String>>[];
    await pumpUi(tester, _Multi(initial: const ['design', 'eng'], log: log));
    await tester.tap(find.bySemanticsLabel('Remove Design'));
    await tester.pump();
    expect(log.last, ['eng']);
    await tester.tap(find.bySemanticsLabel('Clear all'));
    await tester.pumpAndSettle();
    expect(log.last, isEmpty);
    expect(find.bySemanticsLabel('Clear all'), findsNothing);
    expect(find.byType(UiListboxPanel), findsNothing, reason: 'clearing leaves the list closed');
    await tester.tap(find.byType(UiMultiSelect));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(UiListboxPanel), matching: find.text('Sales')));
    await tester.pump();
    final row = tester.getSemantics(find.descendant(of: find.byType(UiListboxPanel), matching: find.text('Sales'))).getSemanticsData();
    expect(row.flagsCollection.isChecked.toString(), contains('isTrue'));
    handle.dispose();
  });

  testWidgets('full touch targets for chips, rows and the field', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, _Multi(initial: const ['design', 'eng'], log: []));
    await tester.tap(find.byType(EditableText).first);
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('disabled: no list, no remove', (tester) async {
    final log = <List<String>>[];
    await pumpUi(tester, _Multi(initial: const ['design'], enabled: false, log: log));
    await tester.tap(find.byType(UiMultiSelect));
    await tester.pumpAndSettle();
    expect(find.byType(UiListboxPanel), findsNothing);
    expect(find.bySemanticsLabel('Clear all'), findsNothing);
  });

  testWidgets('golden: multi-select open', (tester) async {
    await expectOverlayGolden(tester, 'multi_select', height: 330, (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiFormField(label: 'Teams', child: UiMultiSelect(options: _tags, value: const ['design', 'mkt'], onChanged: (_) {})),
      ],
    ), open: () async {
      await tester.tap(find.byType(EditableText));
      await tester.pump();
    });
  });
}
