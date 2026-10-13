import 'dart:ui' show Tristate;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

void main() {
  testWidgets('the label names the control, and is not announced twice', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const SizedBox(width: 300, child: UiFormField(label: 'Email', hint: 'We never share it', child: UiInput())));
    await tester.pump();
    final data = tester.getSemantics(find.byType(EditableText)).getSemanticsData();
    expect(data.label, 'Email');
    expect(data.flagsCollection.isTextField, isTrue);
    // Only the control carries "Email".
    expect(find.bySemanticsLabel('Email'), findsOneWidget);
    expect(find.text('We never share it'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('tapping the label focuses the control', (tester) async {
    await pumpUi(tester, const SizedBox(width: 300, child: UiFormField(label: 'Name', child: UiInput())));
    await tester.pump();
    await tester.tap(find.text('Name'));
    await tester.pump();
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);
  });

  testWidgets('a label with no text control to name stays readable', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const SizedBox(width: 300, child: UiFormField(label: 'Rating', child: SizedBox(height: 20))));
    await tester.pump();
    expect(find.bySemanticsLabel('Rating'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('error replaces the hint, is a live region and turns the border red', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const SizedBox(width: 300, child: UiFormField(label: 'Email', hint: 'Hint', error: 'Enter an email', required: true, child: UiInput())));
    await tester.pump();
    expect(find.text('Hint'), findsNothing);
    final err = tester.getSemantics(find.text('Enter an email')).getSemanticsData();
    expect(err.flagsCollection.isLiveRegion, isTrue);
    final frame = tester.widget<UiFieldFrame>(find.byType(UiFieldFrame));
    expect(frame.invalid, isTrue);
    // The * marker is drawn, and the control is marked required for assistive tech.
    expect(find.byWidgetPredicate((w) => w is Text && w.textSpan?.toPlainText(includeSemanticsLabels: false) == 'Email *'), findsOneWidget);
    expect(tester.getSemantics(find.byType(EditableText)).getSemanticsData().flagsCollection.isRequired, Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('validated fields run inside a Form: required, then the validator', (tester) async {
    final form = GlobalKey<FormState>();
    String? saved;
    await pumpUi(
      tester,
      SizedBox(
        width: 300,
        child: Form(
          key: form,
          child: UiFormField<String>.validated(
            label: 'Email',
            required: true,
            validator: (v) => v!.contains('@') ? null : 'Enter an email address',
            onSaved: (v) => saved = v,
            builder: (field) => UiInput(value: field.value, onChanged: field.didChange),
          ),
        ),
      ),
    );
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Email is required'), findsOneWidget);
    expect(tester.widget<UiFieldFrame>(find.byType(UiFieldFrame)).invalid, isTrue);

    await tester.enterText(find.byType(EditableText), 'ada');
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Enter an email address'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'ada@example.com');
    expect(form.currentState!.validate(), isTrue);
    await tester.pump();
    expect(find.text('Enter an email address'), findsNothing);
    form.currentState!.save();
    expect(saved, 'ada@example.com');
  });

  testWidgets('required treats empty lists as empty (multi-select)', (tester) async {
    final form = GlobalKey<FormState>();
    await pumpUi(
      tester,
      SizedBox(
        width: 300,
        child: Form(
          key: form,
          child: UiFormField<List<String>>.validated(
            label: 'Tags',
            required: true,
            initialValue: const [],
            builder: (field) => UiMultiSelect(options: const [UiComboboxOption(label: 'A', value: 'a')], value: field.value ?? const [], onChanged: field.didChange),
          ),
        ),
      ),
    );
    expect(form.currentState!.validate(), isFalse);
  });
}
