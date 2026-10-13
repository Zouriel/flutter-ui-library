import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

void main() {
  testWidgets('input: typing calls onChanged; a new value from outside is shown', (tester) async {
    final values = <String>[];
    var value = 'Ada';
    late StateSetter set;
    await pumpUi(tester, StatefulBuilder(builder: (context, s) {
      set = s;
      return SizedBox(width: 300, child: UiInput(value: value, semanticLabel: 'Name', onChanged: (v) => values.add(v)));
    }));
    expect(find.text('Ada'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Grace');
    expect(values, ['Grace']);
    set(() => value = 'Reset');
    await tester.pump();
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'Reset');
  });

  testWidgets('input: placeholder shows while empty and is the semantic hint', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const SizedBox(width: 300, child: UiInput(placeholder: 'you@example.com', semanticLabel: 'Email', type: UiInputType.email)));
    expect(find.text('you@example.com'), findsOneWidget);
    final data = tester.getSemantics(find.byType(EditableText)).getSemanticsData();
    expect(data.hint, 'you@example.com');
    expect(tester.widget<EditableText>(find.byType(EditableText)).keyboardType, TextInputType.emailAddress);
    await tester.enterText(find.byType(EditableText), 'a');
    await tester.pump();
    expect(find.text('you@example.com'), findsNothing);
    handle.dispose();
  });

  testWidgets('input: keeps its 30px look but a 48dp touch target, and stretches to its width', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const SizedBox(width: 300, child: UiInput(semanticLabel: 'Name')));
    expect(tester.getSize(find.byType(UiInput)), const Size(300, 48));
    final box = tester.getSize(find.descendant(of: find.byType(UiFieldFrame), matching: find.byType(AnimatedContainer)).first);
    expect(box.height, 30);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('input: focus turns the border primary with a ring', (tester) async {
    await pumpUi(tester, const SizedBox(width: 300, child: UiInput(semanticLabel: 'Name')));
    await tester.tap(find.byType(EditableText));
    await tester.pumpAndSettle();
    expect(tester.widget<UiFieldFrame>(find.byType(UiFieldFrame)).focused, isTrue);
  });

  testWidgets('input: disabled ignores taps and is half opacity', (tester) async {
    await pumpUi(tester, const SizedBox(width: 300, child: UiInput(semanticLabel: 'Name', enabled: false)));
    await tester.tap(find.byType(UiInput));
    await tester.pump();
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isFalse);
    expect(editable.readOnly, isTrue);
    expect(tester.widget<Opacity>(find.descendant(of: find.byType(UiFieldFrame), matching: find.byType(Opacity)).first).opacity, 0.5);
  });

  testWidgets('textarea: autosize grows with the text up to maxRows', (tester) async {
    await pumpUi(tester, const SizedBox(width: 300, child: UiTextarea(semanticLabel: 'Bio', rows: 2, autosize: true, maxRows: 4)));
    final h0 = tester.getSize(find.byType(UiTextarea)).height;
    await tester.enterText(find.byType(EditableText), 'one\ntwo\nthree');
    await tester.pump();
    final h1 = tester.getSize(find.byType(UiTextarea)).height;
    expect(h1, greaterThan(h0));
    await tester.enterText(find.byType(EditableText), List.generate(4, (i) => 'line $i').join('\n'));
    await tester.pump();
    final h2 = tester.getSize(find.byType(UiTextarea)).height;
    expect(h2, greaterThan(h1));
    // Past maxRows it stops growing and scrolls.
    await tester.enterText(find.byType(EditableText), List.generate(12, (i) => 'line $i').join('\n'));
    await tester.pump();
    expect(tester.getSize(find.byType(UiTextarea)).height, h2);
  });

  testWidgets('textarea: without autosize it stays rows tall', (tester) async {
    await pumpUi(tester, const SizedBox(width: 300, child: UiTextarea(semanticLabel: 'Bio', rows: 3)));
    final h0 = tester.getSize(find.byType(UiTextarea)).height;
    await tester.enterText(find.byType(EditableText), List.generate(8, (i) => 'line $i').join('\n'));
    await tester.pump();
    expect(tester.getSize(find.byType(UiTextarea)).height, h0);
    expect(tester.widget<EditableText>(find.byType(EditableText)).maxLines, 3);
  });

  testWidgets('password: hidden by default; the toggle shows and hides it', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const SizedBox(width: 300, child: UiPasswordInput(semanticLabel: 'Password', value: 'secret')));
    expect(tester.widget<EditableText>(find.byType(EditableText)).obscureText, isTrue);
    expect(tester.widget<EditableText>(find.byType(EditableText)).autofillHints, [AutofillHints.password]);
    await tester.tap(find.bySemanticsLabel('Show password'));
    await tester.pump();
    expect(tester.widget<EditableText>(find.byType(EditableText)).obscureText, isFalse);
    expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('search: the clear button appears with text, clears, and refocuses the field', (tester) async {
    final handle = tester.ensureSemantics();
    final values = <String>[];
    await pumpUi(tester, SizedBox(width: 300, child: UiSearchInput(label: 'Search docs', onChanged: values.add)));
    expect(find.bySemanticsLabel('Clear search'), findsNothing);
    await tester.enterText(find.byType(EditableText), 'grid');
    await tester.pump();
    expect(find.bySemanticsLabel('Clear search'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Clear search'));
    await tester.pump();
    expect(values.last, '');
    expect(find.bySemanticsLabel('Clear search'), findsNothing);
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
    expect(tester.getSemantics(find.byType(EditableText)).getSemanticsData().label, 'Search docs');
    handle.dispose();
  });

  testWidgets('touch selection: long-press selects and shows the themed copy menu', (tester) async {
    await pumpUi(tester, const SizedBox(width: 300, child: UiInput(semanticLabel: 'Name', value: 'hello world')));
    await tester.longPress(find.byType(EditableText));
    await tester.pumpAndSettle();
    expect(find.byType(UiTextContextMenu), findsOneWidget);
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.selection, const TextSelection(baseOffset: 0, extentOffset: 11));
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Cut'), findsOneWidget);
  });
}
