import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import 'fakes.dart';

Future<void> typeInto(WidgetTester tester, String label, String text, {int at = 0}) async {
  final f = find.descendant(of: fieldView(label, at: at), matching: find.byType(EditableText));
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pump();
}

Future<void> tapIn(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String label, String option, {int at = 0}) async {
  await tapIn(tester, find.descendant(of: fieldView(label, at: at), matching: find.byType(UiSelect)));
  await tester.tap(find.descendant(of: find.byType(UiListboxPanel), matching: find.text(option)));
  await tester.pumpAndSettle();
}

Future<void> pressButton(WidgetTester tester, String text) async {
  await tapIn(tester, find.widgetWithText(UiButton, text));
}

List<String> summaryItems(WidgetTester tester) {
  final box = find.ancestor(of: find.textContaining(RegExp(r'^There (is|are)')), matching: find.byType(Container)).first;
  return [
    for (final e in find.descendant(of: box, matching: find.byType(Text)).evaluate())
      if (!((e.widget as Text).data ?? '').startsWith('There ')) (e.widget as Text).data ?? '',
  ];
}

UiFormEngine engineOf(GlobalKey<UiFormRendererState> key) => key.currentState!.engine;

void main() {
  final sources = [peopleSource().def, coursesSource];

  group('fill mode', () {
    testWidgets('labels name their controls, and tapping a label focuses its box', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpForm(tester, definition: form([f('name', 'text', {'label': 'Full name', 'help': 'As on your passport', 'required': true})]));
      expect(find.text('As on your passport'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Full name')), findsWidgets);
      await tester.tap(find.textContaining('Full name'));
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<UiFbFieldView>()?.field.label, 'Full name');
      handle.dispose();
    });

    testWidgets('on submit, lists every problem at the top, marks the fields, and submits nothing; a link focuses its field', (tester) async {
      final got = <UiFormSubmission>[];
      await pumpForm(tester, definition: form([f('a', 'text', {'required': true}), f('b', 'email', {'required': true})]), onSubmitted: got.add);
      await pressButton(tester, 'Submit');
      expect(find.text('There are 2 problems'), findsOneWidget);
      expect(summaryItems(tester), ['A is required.', 'B is required.']);
      expect(find.byWidgetPredicate((w) => w is UiFieldScope && w.invalid), findsNWidgets(2));
      expect(got, isEmpty);
      await tester.tap(find.text('B is required.').first);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<UiFbFieldView>()?.field.id, 'b');
      // Fixing them submits.
      await typeInto(tester, 'A', 'x');
      await typeInto(tester, 'B', 'b@example.com');
      await pressButton(tester, 'Submit');
      expect(got.single.data, {'a': 'x', 'b': 'b@example.com'});
      expect(find.textContaining('There '), findsNothing);
    });

    testWidgets('with validateOn blur, a field shows its error once it is left; a page reached with Continue starts clean', (tester) async {
      final def = {
        'schemaVersion': 1, 'id': 'f', 'title': 'T', 'settings': {'validateOn': 'blur'},
        'pages': [
          {'id': 'p1', 'title': 'First', 'elements': [f('a', 'text', {'required': true}), f('z', 'text')]},
          {'id': 'p2', 'title': 'Second', 'elements': [f('b', 'text', {'required': true}), f('c', 'email', {'required': true})]},
        ],
      };
      await pumpForm(tester, definition: def);
      expect(find.text('Step 1 of 2: First'), findsOneWidget);
      await tapIn(tester, find.descendant(of: fieldView('A'), matching: find.byType(EditableText)));
      await tapIn(tester, find.descendant(of: fieldView('Z'), matching: find.byType(EditableText)));
      expect(find.text('A is required.'), findsOneWidget, reason: 'shown after leaving the field');
      await typeInto(tester, 'A', 'x');
      expect(find.text('A is required.'), findsNothing);
      await pressButton(tester, 'Continue');
      expect(find.text('Step 2 of 2: Second'), findsOneWidget);
      expect(find.textContaining('There '), findsNothing);
      expect(find.byWidgetPredicate((w) => w is UiFieldScope && w.invalid), findsNothing);
      expect(find.widgetWithText(UiButton, 'Back'), findsOneWidget);
      await pressButton(tester, 'Back');
      expect(find.text('Step 1 of 2: First'), findsOneWidget);
    });

    testWidgets('validateOn submit keeps errors back until Continue', (tester) async {
      await pumpForm(tester, definition: form([f('a', 'text', {'required': true}), f('z', 'text')], settings: {'validateOn': 'submit'}));
      await tapIn(tester, find.descendant(of: fieldView('A'), matching: find.byType(EditableText)));
      await tapIn(tester, find.descendant(of: fieldView('Z'), matching: find.byType(EditableText)));
      expect(find.text('A is required.'), findsNothing);
      await pressButton(tester, 'Submit');
      expect(find.text('A is required.'), findsNWidgets(2), reason: 'in the summary and under the field');
    });

    testWidgets('floats the label inside text boxes only, and keeps the error inside when asked', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpForm(tester, definition: form([
        f('t', 'text', {'required': true, 'layout': {'labelPlacement': 'inside', 'errorPlacement': 'inside'}}),
        f('r', 'radio', {'layout': {'labelPlacement': 'inside'}, 'options': [{'id': 'o', 'value': 'x', 'label': 'X'}]}),
      ]));
      // The text box carries its label inside (as the floating label); the radio group's sits on top.
      final tState = tester.state<UiFbFieldViewState>(fieldView('T'));
      expect(find.descendant(of: fieldView('T'), matching: find.byType(AnimatedSlide)), findsOneWidget);
      expect(find.descendant(of: fieldView('R'), matching: find.byType(AnimatedSlide)), findsNothing);
      expect(tState.addr, 't');
      await pressButton(tester, 'Submit');
      // The pill shows the message; the announced copy is the full text.
      expect(find.descendant(of: fieldView('T'), matching: find.text('T is required.')), findsOneWidget);
      expect(find.bySemanticsLabel('Error: T is required.'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('rules show and hide questions as answers change, and hidden questions never block', (tester) async {
      final key = await pumpForm(tester, definition: fixture('scholarship.definition.json')!, sources: sources);
      expect(fieldView('School or university'), findsOneWidget);
      await tapIn(tester, find.text('Not studying'));
      expect(find.byWidgetPredicate((w) => w is UiFbFieldView && w.field.label == 'School or university'), findsNothing);
      expect(engineOf(key).pageErrors(0).map((e) => e.id), isNot(contains('f_inst')));
      await tapIn(tester, find.text('Part time'));
      expect(fieldView('School or university'), findsOneWidget);
      // The household page joins the route when the toggle is on.
      expect(find.text('Step 1 of 2: About you'), findsOneWidget);
      await tapIn(tester, find.text('Yes, I do'));
      expect(find.text('Step 1 of 3: About you'), findsOneWidget);
    });

    testWidgets('calculated fields work themselves out from other answers', (tester) async {
      await pumpForm(tester, definition: fixture('scholarship.definition.json')!, sources: sources);
      expect(find.text('Worked out as you answer'), findsOneWidget);
      final dob = tester.widget<UiDatePicker>(find.descendant(of: fieldView('Date of birth'), matching: find.byType(UiDatePicker)));
      dob.onChanged!('2004-10-14');
      await tester.pumpAndSettle();
      expect(find.text('21 years'), findsOneWidget);
    });

    testWidgets('repeat entries: add and remove within the limits, move, and undo a removal', (tester) async {
      final rep = {
        'kind': 'group', 'id': 'kids', 'key': 'kids', 'title': 'Children',
        'repeat': {'min': 1, 'max': 2, 'addLabel': 'Add a child', 'itemLabel': 'Child {n}'},
        'elements': [f('name', 'text')],
      };
      final key = await pumpForm(tester, definition: form([rep]));
      List<String> entries() => [for (final e in find.textContaining(RegExp(r'^Child \d$')).evaluate()) (e.widget as Text).data!];
      expect(entries(), ['Child 1']);
      expect(find.bySemanticsLabel('Remove Child 1'), findsNothing, reason: 'at the minimum');
      await pressButton(tester, 'Add a child');
      expect(entries(), ['Child 1', 'Child 2']);
      expect(find.text('2 of 2'), findsOneWidget);
      expect(tester.widget<UiButton>(find.widgetWithText(UiButton, 'Add a child')).onPressed, isNull);
      await typeInto(tester, 'NAME', 'Ali', at: 0);
      await typeInto(tester, 'NAME', 'Zara', at: 1);
      await tapIn(tester, find.bySemanticsLabel('Move Child 2 up'));
      expect(engineOf(key).data['kids'], [{'name': 'Zara'}, {'name': 'Ali'}]);
      await tapIn(tester, find.bySemanticsLabel('Remove Child 2'));
      expect(entries(), ['Child 1']);
      expect(find.text('Child 2 removed.'), findsOneWidget);
      await pressButton(tester, 'Undo');
      expect(entries(), ['Child 1', 'Child 2']);
      expect(engineOf(key).data['kids'], [{'name': 'Zara'}, {'name': 'Ali'}]);
      // The undo offer goes away on its own.
      await tapIn(tester, find.bySemanticsLabel('Remove Child 1'));
      await tester.pump(const Duration(seconds: 13));
      expect(find.text('Child 1 removed.'), findsNothing);
    });

    testWidgets('errors per page: Continue stops on the page with problems and lists only that page', (tester) async {
      final key = await pumpForm(tester, definition: fixture('scholarship.definition.json')!, sources: sources);
      await pressButton(tester, 'Continue');
      final want = (((fixtureMap('engine-scholarship.json')['cases'] as List)[0] as Map)['steps'] as List)[0]['expect']['pageErrors']['0'] as List;
      expect(summaryItems(tester), [for (final e in want) (e as Map)['message']]);
      expect(engineOf(key).pageIndex, 0);
    });

    testWidgets('files: picked files are listed with their sizes, removable, and ride along in the submission', (tester) async {
      final got = <UiFormSubmission>[];
      await pumpForm(
        tester,
        definition: form([f('docs', 'file', {'props': {'multiple': true, 'accept': '.pdf'}})]),
        picker: fakePicker(const [UiPickedFile(name: 'transcript.pdf', size: 184320, mimeType: 'application/pdf')]),
        onSubmitted: got.add,
      );
      await tapIn(tester, find.text('Tap to upload'));
      expect(find.text('transcript.pdf'), findsOneWidget);
      expect(find.text('180 kB'), findsOneWidget);
      await tapIn(tester, find.text('Tap to upload'));
      expect(find.text('transcript.pdf'), findsNWidgets(2), reason: 'multiple keeps what was picked before');
      await tapIn(tester, find.bySemanticsLabel('Remove transcript.pdf').first);
      await pressButton(tester, 'Submit');
      expect(got.single.data['docs'], [{'name': 'transcript.pdf', 'size': 184320, 'type': 'application/pdf'}]);
      expect(got.single.files['docs']!.single.name, 'transcript.pdf');
    });

    testWidgets('every field type the builder offers renders its control', (tester) async {
      final opts = [{'id': 'o1', 'value': 'a', 'label': 'Apple'}, {'id': 'o2', 'value': 'b', 'label': 'Banana'}];
      final key = await pumpForm(tester, definition: form([
        f('text', 'text'), f('textarea', 'textarea'), f('email', 'email'), f('phone', 'phone'), f('url', 'url'),
        f('number', 'number'), f('currency', 'currency', {'props': {'currency': 'USD', 'decimals': 2}}), f('date', 'date'), f('time', 'time'),
        f('select', 'select', {'options': opts}), f('radio', 'radio', {'options': opts}), f('checkboxes', 'checkboxes', {'options': opts}),
        f('multiselect', 'multiselect', {'options': opts}), f('checkbox', 'checkbox'), f('toggle', 'toggle'), f('rating', 'rating'),
        f('slider', 'slider'), f('file', 'file'), f('hidden', 'hidden', {'defaultValue': 'kept'}),
        f('calculated', 'calculated', {'calc': {'op': 'sum', 'args': [{'ref': 'number'}, {'const': 2}]}}),
        {'kind': 'static', 'id': 's1', 'type': 'heading', 'text': 'A heading'},
        {'kind': 'static', 'id': 's2', 'type': 'paragraph', 'text': 'Some words.'},
        {'kind': 'static', 'id': 's3', 'type': 'divider'},
      ]), size: const Size(390, 3000));
      for (final type in [UiInput, UiTextarea, UiNumberInput, UiDatePicker, UiTimePicker, UiSelect, UiCheckboxGroup<String>, UiMultiSelect, UiCheckbox, UiSwitch, UiRating, UiSlider, UiFileUpload]) {
        expect(find.byType(type), findsWidgets, reason: '$type');
      }
      expect(find.byType(UiRadioGroup<String>), findsOneWidget);
      expect(find.text('A heading'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is UiFbFieldView && w.field.id == 'hidden'), findsNothing);
      await typeInto(tester, 'NUMBER', '40');
      expect(find.text('42'), findsOneWidget, reason: 'the calculated field');
      await tapIn(tester, find.text('Banana').at(0)); // radio
      await tapIn(tester, find.text('Apple').at(1)); // checkboxes
      await tapIn(tester, find.descendant(of: fieldView('TOGGLE'), matching: find.byType(UiSwitch)));
      final e = engineOf(key);
      expect(e.data['radio'], 'b');
      expect(e.data['checkboxes'], ['a']);
      expect(e.data['toggle'], true);
      expect(e.data['hidden'], 'kept');
      expect(e.data['number'], 40);
    });
  });

  group('sourced fields', () {
    final cities = UiFbOptionSource(
      type: 'cities',
      label: 'Cities',
      params: const [UiFbSourceParamSpec(key: 'country', label: 'Country', required: true)],
      search: (q) => UiFbSourcePage(
        items: q.params['country'] == 'mv'
            ? const [UiFbSourceItem(value: 'mle', label: 'Malé'), UiFbSourceItem(value: 'adu', label: 'Addu')]
            : const [UiFbSourceItem(value: 'ldn', label: 'London')],
        hasMore: false,
      ),
    );
    final def = form([
      f('country', 'select', {'label': 'Country', 'options': [{'id': 'a', 'value': 'mv', 'label': 'Maldives'}, {'id': 'b', 'value': 'uk', 'label': 'UK'}]}),
      f('city', 'select', {'label': 'City', 'required': true, 'source': {'type': 'cities', 'params': {'country': {'ref': 'country'}}}}),
    ]);

    testWidgets('saves the picked value with its label, and clears a dependent answer when what it depends on changes', (tester) async {
      final got = <UiFormSubmission>[];
      final key = await pumpForm(tester, definition: def, data: {'country': 'mv'}, sources: [cities], onSubmitted: got.add);
      await tapIn(tester, find.descendant(of: fieldView('City'), matching: find.byType(EditableText)));
      final rows = find.descendant(of: find.byType(ListView), matching: find.byType(Text));
      expect([for (final e in rows.evaluate()) (e.widget as Text).data], ['Malé', 'Addu']);
      await tester.tap(find.text('Malé'));
      await tester.pumpAndSettle();
      await pressButton(tester, 'Save changes');
      expect(got.single.data['city'], {'value': 'mle', 'label': 'Malé'});
      engineOf(key).setValue('country', null, 'uk');
      await tester.pumpAndSettle();
      expect(engineOf(key).data['city'], isNull);
    });

    testWidgets('a list the app does not provide says so and keeps the saved answer readable', (tester) async {
      await pumpForm(tester, definition: def, data: {'country': 'mv', 'city': {'value': 'mle', 'label': 'Malé'}});
      expect(find.text('This list isn’t available right now. Saved answer: Malé.'), findsOneWidget);
    });
  });

  group('edit and view', () {
    testWidgets('edit mode: Save changes, a change list with old and new values', (tester) async {
      final dirty = <bool>[];
      final key = GlobalKey<UiFormRendererState>();
      await pumpForm(tester, definition: fixture('scholarship.definition.json')!, data: fixtureMap('scholarship.answers.json'), sources: sources);
      expect(find.text('No changes'), findsOneWidget);
      expect(key.currentState, isNull);
      await tapIn(tester, find.text('Full time'));
      expect(find.text('1 change'), findsOneWidget);
      await tapIn(tester, find.text('1 change'));
      expect(find.text('Are you studying at the moment?'), findsWidgets);
      expect(find.text('Part time'), findsWidgets);
      final strike = tester.widget<Text>(find.descendant(of: find.byType(SingleChildScrollView).last, matching: find.text('Part time')));
      expect(strike.style?.decoration, TextDecoration.lineThrough);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tapIn(tester, find.text('Part time').first);
      expect(find.text('No changes'), findsOneWidget);
      expect(dirty, isEmpty);
      // The last page's button reads "Save changes".
      await pressButton(tester, 'Continue');
      await pressButton(tester, 'Continue');
      expect(find.widgetWithText(UiButton, 'Save changes'), findsOneWidget);
    });

    testWidgets('reports value and dirty changes', (tester) async {
      final values = <UiJson>[];
      final dirty = <bool>[];
      tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UiApp(
        home: SingleChildScrollView(
          child: UiFormRenderer(
            definition: form([f('a', 'text')]),
            data: const {'a': 'x'},
            onValueChanged: values.add,
            onDirtyChanged: dirty.add,
          ),
        ),
      ));
      await typeInto(tester, 'A', 'y');
      await typeInto(tester, 'A', 'x');
      expect(values.map((v) => v['a']), ['y', 'x']);
      expect(dirty, [true, false]);
    });

    testWidgets('view mode: saved answers as text with option labels, no inputs or buttons', (tester) async {
      await pumpForm(
        tester,
        definition: form([f('c', 'select', {'options': [{'id': 'o1', 'value': 'mv', 'label': 'Maldives'}]}), f('n', 'text')]),
        data: {'c': 'mv', 'n': ''},
        mode: UiFormMode.view,
      );
      expect(find.text('Maldives'), findsOneWidget);
      expect(find.text('Not answered'), findsOneWidget);
      expect(find.byType(EditableText), findsNothing);
      expect(find.byType(UiButton), findsNothing);
    });

    testWidgets('view mode shows every page on the route, without steps, skipping pages that were skipped', (tester) async {
      await pumpForm(tester, definition: {
        'schemaVersion': 1, 'id': 'f', 'title': 'T',
        'pages': [
          {'id': 'p1', 'title': 'First', 'elements': [f('a', 'text')]},
          {'id': 'p2', 'title': 'Skipped', 'visibility': {'action': 'show', 'when': {'ref': 'a', 'op': 'eq', 'value': {'const': 'yes'}}}, 'elements': [f('b', 'text')]},
          {'id': 'p3', 'title': 'Last', 'elements': [f('c', 'text')]},
        ],
      }, data: {'a': 'no', 'c': 'done'}, mode: UiFormMode.view);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Last'), findsOneWidget);
      expect(find.text('Skipped'), findsNothing);
      expect(find.text('no'), findsOneWidget);
      expect(find.text('done'), findsOneWidget);
      expect(find.textContaining('Step '), findsNothing);
    });
  });

  testWidgets('accessibility guidelines on the sample form', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpForm(tester, definition: fixture('scholarship.definition.json')!, sources: sources);
    await pressButton(tester, 'Continue');
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('keyboard: the source picker swallows Enter while open', (tester) async {
    final got = <UiFormSubmission>[];
    await pumpForm(tester, definition: form([f('s', 'select', {'source': {'type': 'students'}})]), sources: sources, onSubmitted: got.add);
    await tapIn(tester, find.byType(EditableText));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(got, isEmpty);
  });
}
