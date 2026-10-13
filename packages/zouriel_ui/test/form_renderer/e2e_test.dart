// Fills in the showcase's scholarship form through the widgets, the way a person would, and checks
// the saved JSON against the answers the Angular engine produces for the same steps (the shared
// fixture engine-scholarship.json, case 1). Same JSON in, same JSON out.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import 'fakes.dart';

Future<void> _show(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String label, String text, {int at = 0}) async {
  final f = find.descendant(of: fieldView(label, at: at), matching: find.byType(EditableText));
  await _show(tester, f);
  await tester.enterText(f, text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await _show(tester, f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String label, String option) async {
  await _tap(tester, find.descendant(of: fieldView(label), matching: find.byType(UiSelect)));
  await tester.tap(find.descendant(of: find.byType(UiListboxPanel), matching: find.text(option)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the sample form filled in through the UI saves exactly what the web engine saves', (tester) async {
    final cases = fixtureMap('engine-scholarship.json')['cases'] as List;
    final steps = (cases[0] as Map)['steps'] as List;
    final want = ((steps.last as Map)['expect'] as Map)['data'];
    final got = <UiFormSubmission>[];
    final key = await pumpForm(
      tester,
      definition: fixture('scholarship.definition.json')!,
      sources: [peopleSource().def, coursesSource],
      picker: fakePicker(const [UiPickedFile(name: 'transcript.pdf', size: 184320, mimeType: 'application/pdf')]),
      onSubmitted: got.add,
      today: (cases[0] as Map)['today'] as String,
    );

    // Page 1: About you.
    await _type(tester, 'Full name', 'Aminath Shareef');
    await _type(tester, 'Email address', 'aminath@example.mv');
    await _type(tester, 'Mobile number', '+960 777 4021');
    // The calendar is tested with the date picker; set the date the way it reports one.
    final dob = find.descendant(of: fieldView('Date of birth'), matching: find.byType(UiDatePicker));
    await _show(tester, dob);
    tester.widget<UiDatePicker>(dob).onChanged!('2004-10-14');
    await tester.pumpAndSettle();
    expect(find.text('21 years'), findsOneWidget);
    await _tap(tester, find.text('Not studying'));
    await _tap(tester, find.text('Yes, I do'));
    await _tap(tester, find.widgetWithText(UiButton, 'Continue'));
    expect(find.text('Step 2 of 3: Household'), findsOneWidget);

    // Page 2: Household. Continue with the entry empty shows this page's problems only.
    await _tap(tester, find.widgetWithText(UiButton, 'Continue'));
    expect(find.text('There are 2 problems'), findsOneWidget);
    await _type(tester, 'Name', 'Ibrahim');
    await _choose(tester, 'Relationship', 'Other');
    expect(fieldView('How are you related?'), findsOneWidget);
    await _choose(tester, 'Relationship', 'Sibling');
    expect(find.byWidgetPredicate((w) => w is UiFbFieldView && w.field.label == 'How are you related?'), findsNothing);
    await _type(tester, 'Wages', '1240.5');
    await _type(tester, 'Benefits', '180');
    expect(find.text(r'$1,420.50'), findsOneWidget);
    await _tap(tester, find.widgetWithText(UiButton, 'Continue'));
    expect(find.text('Step 3 of 3: Your application'), findsOneWidget);

    // Page 3: Your application.
    await _choose(tester, 'Programme', 'Health and medicine');
    await _tap(tester, find.descendant(of: fieldView('Courses you’ll take'), matching: find.byType(EditableText)));
    await tester.tap(find.descendant(of: find.byType(ListView), matching: find.text('Anatomy')));
    await tester.pump();
    final last = find.descendant(of: find.byType(ListView), matching: find.text('health-9'));
    await tester.scrollUntilVisible(last, 48, scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)));
    await tester.ensureVisible(last);
    await tester.pump();
    await tester.tap(last);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await _type(tester, 'Personal statement', List.filled(60, 'word').join(' '));
    await _tap(tester, find.text('Tap to upload'));
    expect(find.text('transcript.pdf'), findsOneWidget);

    // Submitting without the declaration stays put and says why.
    await _tap(tester, find.widgetWithText(UiButton, 'Submit'));
    expect(got, isEmpty);
    expect(find.text('You must confirm the declaration to apply.'), findsWidgets);
    await _tap(tester, find.text('The information I have given is true and complete.'));
    await _tap(tester, find.widgetWithText(UiButton, 'Submit'));

    expect(got, hasLength(1));
    final s = got.single;
    expect(jsonEquals(s.data, want), isTrue, reason: 'got  ${jsonEncode(s.data)}\nwant ${jsonEncode(want)}');
    expect(s.formId, 'scholarship-2027');
    expect(s.revision, 4);
    expect(s.files['documents']!.single.name, 'transcript.pdf');
    expect(key.currentState!.engine.dirty, isTrue);
  });

  testWidgets('saved answers open in edit mode unchanged, and save back as the same JSON', (tester) async {
    final answers = fixtureMap('scholarship.answers.json');
    final got = <UiFormSubmission>[];
    await pumpForm(
      tester,
      definition: fixture('scholarship.definition.json')!,
      data: answers,
      sources: [peopleSource().def, coursesSource],
      onSubmitted: got.add,
    );
    expect(find.text('No changes'), findsOneWidget);
    // The sourced answer shows its saved label.
    expect(find.text('Aminath Shareef'), findsWidgets);
    for (var i = 0; i < 2; i++) {
      await _tap(tester, find.widgetWithText(UiButton, 'Continue'));
    }
    await _tap(tester, find.widgetWithText(UiButton, 'Save changes'));
    final want = (((fixtureMap('engine-scholarship.json')['cases'] as List)[1] as Map)['steps'] as List)[0]['expect']['data'];
    expect(jsonEquals(got.single.data, want), isTrue, reason: 'got  ${jsonEncode(got.single.data)}\nwant ${jsonEncode(want)}');
  });
}
