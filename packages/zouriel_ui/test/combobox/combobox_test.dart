import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../forms_text/overlay_helpers.dart';
import '../helpers.dart';

const _countries = [
  UiComboboxOption(label: 'Maldives', value: 'mv'),
  UiComboboxOption(label: 'Malaysia', value: 'my'),
  UiComboboxOption(label: 'Mali', value: 'ml'),
  UiComboboxOption(label: 'Norway', value: 'no'),
  UiComboboxOption(label: 'Portugal', value: 'pt'),
];

class _Combo extends StatefulWidget {
  const _Combo({this.initial, this.options = _countries, this.fontPreview = false, this.clearable = true, required this.log});
  final String? initial;
  final List<UiComboboxOption> options;
  final bool fontPreview;
  final bool clearable;
  final List<String?> log;
  @override
  State<_Combo> createState() => _ComboState();
}

class _ComboState extends State<_Combo> {
  late String? v = widget.initial;
  @override
  Widget build(BuildContext context) => Column(children: [
        // Above the combobox, so the open list doesn't cover it.
        const SizedBox(width: 300, child: UiInput(semanticLabel: 'Other')),
        SizedBox(
          width: 300,
          child: UiCombobox(
            options: widget.options,
            value: v,
            label: 'Country',
            clearable: widget.clearable,
            fontPreview: widget.fontPreview,
            fontPackage: 'zouriel_ui',
            onChanged: (x) => setState(() {
              v = x;
              widget.log.add(x);
            }),
          ),
        ),
      ]);
}

EditableText _field(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText).last);
List<String> _rows(WidgetTester tester) =>
    tester.widget<UiListboxPanel>(find.byType(UiListboxPanel)).items.map((i) => i.label).toList();
int _active(WidgetTester tester) => tester.widget<UiListboxPanel>(find.byType(UiListboxPanel)).activeIndex;

void main() {
  testWidgets('opening lists every option with the chosen one active; typing filters', (tester) async {
    await pumpUi(tester, _Combo(initial: 'no', log: []));
    expect(_field(tester).controller.text, 'Norway');
    await tester.tap(find.byType(EditableText).last);
    await tester.pumpAndSettle();
    expect(_rows(tester), ['Maldives', 'Malaysia', 'Mali', 'Norway', 'Portugal'], reason: 'the label in the field does not filter on open');
    expect(_active(tester), 3);
    await tester.enterText(find.byType(EditableText).last, 'mal');
    await tester.pump();
    expect(_rows(tester), ['Maldives', 'Malaysia', 'Mali']);
    expect(_active(tester), 0);
    await tester.enterText(find.byType(EditableText).last, 'zz');
    await tester.pump();
    expect(find.text('No results'), findsOneWidget);
  });

  testWidgets('arrow keys move, Enter chooses, Escape closes', (tester) async {
    final log = <String?>[];
    await pumpUi(tester, _Combo(log: log));
    await tester.tap(find.byType(EditableText).last);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_active(tester), 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(_active(tester), 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log, ['my']);
    expect(_field(tester).controller.text, 'Malaysia');
    expect(find.byType(UiListboxPanel), findsNothing);
    // ArrowDown reopens; Escape closes without choosing.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.byType(UiListboxPanel), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(UiListboxPanel), findsNothing);
    expect(log, ['my']);
  });

  testWidgets('tapping an option chooses it (the tap does not blur the field first)', (tester) async {
    final log = <String?>[];
    await pumpUi(tester, _Combo(log: log));
    await tester.tap(find.byType(EditableText).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();
    expect(log, ['pt']);
    expect(_field(tester).controller.text, 'Portugal');
  });

  testWidgets('leaving puts the chosen label back; typed text never becomes the value', (tester) async {
    final log = <String?>[];
    await pumpUi(tester, _Combo(initial: 'mv', log: log));
    await tester.tap(find.byType(EditableText).last);
    await tester.enterText(find.byType(EditableText).last, 'Nor');
    await tester.tap(find.byType(EditableText).first);
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(_field(tester).controller.text, 'Maldives');
    expect(find.byType(UiListboxPanel), findsNothing);
  });

  testWidgets('emptying the text and leaving clears the value (clearable)', (tester) async {
    final log = <String?>[];
    await pumpUi(tester, _Combo(initial: 'mv', log: log));
    await tester.tap(find.byType(EditableText).last);
    await tester.enterText(find.byType(EditableText).last, '');
    await tester.tap(find.byType(EditableText).first);
    await tester.pumpAndSettle();
    expect(log, [null]);
  });

  testWidgets('not clearable: an emptied field snaps back to the label', (tester) async {
    final log = <String?>[];
    await pumpUi(tester, _Combo(initial: 'mv', clearable: false, log: log));
    expect(find.bySemanticsLabel('Clear'), findsNothing);
    await tester.tap(find.byType(EditableText).last);
    await tester.enterText(find.byType(EditableText).last, '');
    await tester.tap(find.byType(EditableText).first);
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(_field(tester).controller.text, 'Maldives');
  });

  testWidgets('the Clear button clears, keeps focus in the field and leaves the list closed', (tester) async {
    final handle = tester.ensureSemantics();
    final log = <String?>[];
    await pumpUi(tester, _Combo(initial: 'mv', log: log));
    await tester.tap(find.bySemanticsLabel('Clear'));
    await tester.pumpAndSettle();
    expect(log, [null]);
    expect(_field(tester).controller.text, '');
    expect(_field(tester).focusNode.hasFocus, isTrue);
    expect(find.byType(UiListboxPanel), findsNothing);
    expect(find.bySemanticsLabel('Clear'), findsNothing);
    handle.dispose();
  });

  testWidgets('a value set from outside, and options that arrive late, show the label', (tester) async {
    var options = <UiComboboxOption>[];
    var value = 'pt';
    late StateSetter set;
    await pumpUi(tester, StatefulBuilder(builder: (context, s) {
      set = s;
      return SizedBox(width: 300, child: UiCombobox(options: options, value: value, label: 'Country'));
    }));
    expect(_field(tester).controller.text, '');
    set(() => options = _countries);
    await tester.pump();
    expect(_field(tester).controller.text, 'Portugal');
    set(() => value = 'no');
    await tester.pump();
    expect(_field(tester).controller.text, 'Norway');
  });

  testWidgets('named, full touch targets, readable', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, _Combo(initial: 'mv', log: []));
    expect(tester.getSemantics(find.byType(EditableText).last).getSemanticsData().label, 'Country');
    await tester.tap(find.byType(EditableText).last);
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    expect(tester.getSize(find.byType(UiListboxPanel)).width, 300);
    handle.dispose();
  });

  testWidgets('fontPreview draws options and the chosen value in their fonts', (tester) async {
    const fonts = [
      UiComboboxOption(label: 'Roboto', value: 'Roboto'),
      UiComboboxOption(label: 'Space Grotesk', value: 'Space Grotesk'),
      UiComboboxOption(label: 'Code', value: 'code', fontFamily: 'JetBrains Mono'),
    ];
    await pumpUi(tester, _Combo(options: fonts, initial: 'Space Grotesk', fontPreview: true, log: []));
    expect(_field(tester).style.fontFamily, 'packages/zouriel_ui/Space Grotesk');
    await tester.tap(find.byType(EditableText).last);
    await tester.pumpAndSettle();
    final items = tester.widget<UiListboxPanel>(find.byType(UiListboxPanel)).items;
    expect(items.map((i) => i.style?.fontFamily), ['packages/zouriel_ui/Roboto', 'packages/zouriel_ui/Space Grotesk', 'packages/zouriel_ui/JetBrains Mono']);
    final rendered = tester.widget<RichText>(find.descendant(of: find.byType(UiListboxPanel), matching: find.text('Code')).evaluate().isEmpty
        ? find.byType(RichText).last
        : find.descendant(of: find.descendant(of: find.byType(UiListboxPanel), matching: find.text('Code')), matching: find.byType(RichText)));
    expect(rendered.text.style?.fontFamily, 'packages/zouriel_ui/JetBrains Mono');
  });

  testWidgets('golden: combobox open as a font picker', (tester) async {
    await expectOverlayGolden(tester, 'combobox_font_picker', height: 330, (context) => const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiFormField(
          label: 'Body font',
          child: UiCombobox(
            value: 'Space Grotesk',
            fontPreview: true,
            fontPackage: 'zouriel_ui',
            options: [
              UiComboboxOption(label: 'Roboto', value: 'Roboto'),
              UiComboboxOption(label: 'Space Grotesk', value: 'Space Grotesk'),
              UiComboboxOption(label: 'Bricolage Grotesque', value: 'Bricolage Grotesque'),
              UiComboboxOption(label: 'JetBrains Mono', value: 'JetBrains Mono'),
            ],
          ),
        ),
      ],
    ), open: () async {
      await tester.tap(find.byType(EditableText));
      await tester.pump();
    });
  });
}
