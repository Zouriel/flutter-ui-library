import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import 'support.dart';

Future<UiFormBuilderController> pumpInspector(WidgetTester tester, UiFormDefinition def, {String? select, List<UiFbOptionSourceDef> sources = const []}) async {
  final c = UiFormBuilderController(definition: def)..optionSourceDefs = sources;
  if (select != null) c.select(select);
  tester.view.physicalSize = const Size(390, 2400) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(home: UiFbBuilderScope(controller: c, child: const UiFbInspector())));
  await tester.pumpAndSettle();
  return c;
}

UiJson el(UiFormBuilderController c, String id) => (c.index[id]!.element as UiFbElement).toJson();

void main() {
  group('field settings', () {
    testWidgets('the key follows the label until the form has answers', (tester) async {
      final c = await pumpInspector(tester, formOf([createField(UiFbFieldType.text).toJson()..['id'] = 'a']), select: 'a');
      await type(tester, 'Question', 'Full name');
      await type(tester, 'Help text', 'As on your passport');
      await type(tester, 'Placeholder', 'Aminath');
      expect(el(c, 'a'), {'kind': 'field', 'id': 'a', 'type': 'text', 'key': 'full_name', 'label': 'Full name', 'help': 'As on your passport', 'placeholder': 'Aminath'});
      c.published = c.def;
      c.submissionCount = 2;
      await tester.pumpAndSettle();
      await type(tester, 'Question', 'Legal name');
      expect(c.field('a')!.key, 'full_name');
    });

    testWidgets('changing the type to a dropdown adds options; back to text drops them', (tester) async {
      final c = await pumpInspector(tester, formOf([fj('a', 'text', {'label': 'Pick'})]), select: 'a');
      await choose(tester, select('Type'), 'Dropdown');
      final j = el(c, 'a');
      expect(j['type'], 'select');
      expect(j['props'], <String, Object?>{});
      expect([for (final o in j['options']! as List) (o as Map)['label']], ['Option 1', 'Option 2', 'Option 3']);
      expect(find.text('Options'), findsOneWidget);
      // Typing an option label moves its saved value along.
      await type(tester, 'Option 1', 'Maldives');
      expect(c.field('a')!.options!.first.value, 'maldives');
      await choose(tester, select('Type'), 'Short text');
      expect(el(c, 'a').containsKey('options'), isFalse);
    });

    testWidgets('number settings write props, and empty ones are removed', (tester) async {
      final c = await pumpInspector(tester, formOf([fj('a', 'number')]), select: 'a');
      final lowest = find.descendant(of: find.byWidgetPredicate((w) => w is UiNumberInput && w.semanticLabel == 'Lowest'), matching: find.byType(EditableText));
      await tester.enterText(lowest, '5');
      await tester.pumpAndSettle();
      await type(tester, 'Unit', 'kg');
      expect(el(c, 'a')['props'], {'min': 5, 'suffix': 'kg'});
      await type(tester, 'Unit', '');
      expect(el(c, 'a')['props'], {'min': 5});
    });

    testWidgets('a default answer, the width and the label placement', (tester) async {
      final c = await pumpInspector(tester, formOf([fj('a', 'text')]), select: 'a');
      final starts = find.descendant(of: find.byWidgetPredicate((w) => w is UiFbValueInput), matching: find.byType(EditableText));
      await tester.ensureVisible(starts);
      await tester.enterText(starts, 'Hello');
      await tester.pumpAndSettle();
      await segment(tester, 'Width', '1/2');
      await choose(tester, select('Question text'), 'Inside the box');
      final j = el(c, 'a');
      expect(j['defaultValue'], 'Hello');
      expect(j['layout'], {'width': 'half', 'labelPlacement': 'inside'});
      await segment(tester, 'Width', 'Full');
      expect(el(c, 'a')['layout'], {'labelPlacement': 'inside'});
    });

    testWidgets('the data key is checked, and saved on Enter', (tester) async {
      final c = await pumpInspector(tester, formOf([fj('a', 'text'), fj('b', 'text')]), select: 'a');
      await type(tester, 'Saved as', '9lives');
      expect(find.text('Use letters, numbers and _ only, starting with a letter.'), findsOneWidget);
      await type(tester, 'Saved as', 'b');
      expect(find.text('Another question in the same place is already saved as “b”.'), findsOneWidget);
      await type(tester, 'Saved as', 'given_name');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(c.field('a')!.key, 'given_name');
      expect(c.field('a')!.keyHistory, isNull, reason: 'no answers yet, so no history');
    });
  });

  group('checks', () {
    testWidgets('required with a message, and a check with its setting', (tester) async {
      final c = await pumpInspector(tester, formOf([fj('a', 'text', {'label': 'Name'})]), select: 'a');
      await tapText(tester, 'Checks');
      await segment(tester, 'Answer needed', 'Required');
      await type(tester, 'Message when it’s left empty', 'Tell us your name');
      await tapText(tester, 'Add a check');
      await tapText(tester, 'Minimum length');
      final atLeast = find.descendant(of: find.byWidgetPredicate((w) => w is UiNumberInput && w.semanticLabel == 'At least'), matching: find.byType(EditableText));
      await tester.enterText(atLeast, '2');
      await tester.pumpAndSettle();
      final j = el(c, 'a');
      expect(j['required'], true);
      expect(j['requiredMessage'], 'Tell us your name');
      final v = (j['validators']! as List).single as Map;
      expect(v['type'], 'minLength');
      expect(v['params'], {'min': 2});
      expect(find.text('Checks'), findsOneWidget);
      expect(find.text('2'), findsWidgets, reason: 'the tab counts required + the check');
      await segment(tester, 'Answer needed', 'Optional');
      expect(el(c, 'a').containsKey('required'), isFalse);
      expect(el(c, 'a').containsKey('requiredMessage'), isFalse);
    });

    testWidgets('email fields show their automatic check, and its message can be changed', (tester) async {
      final c = await pumpInspector(tester, formOf([fj('a', 'email')]), select: 'a');
      await tapText(tester, 'Checks');
      expect(find.text('Automatic'), findsOneWidget);
      await tapText(tester, 'Change its message');
      expect(((el(c, 'a')['validators']! as List).single as Map)['type'], 'email');
      expect(find.text('Change its message'), findsNothing);
    });
  });

  group('logic', () {
    testWidgets('“Only when…” starts an empty rule; adding a rule writes the plain rule (no group)', (tester) async {
      final c = await pumpInspector(tester, formOf([fj('s', 'toggle', {'label': 'Student'}), fj('a', 'text', {'label': 'School'})]), select: 'a');
      await tapText(tester, 'Logic');
      await segment(tester, 'When to show it', 'Only when…');
      expect(el(c, 'a')['visibility'], {
        'action': 'show',
        'when': {'match': 'all', 'conditions': <Object?>[]},
      });
      expect(find.text('Add a rule to say when.'), findsOneWidget);
      await tapText(tester, 'Add rule');
      expect(el(c, 'a')['visibility'], {
        'action': 'show',
        'when': {'ref': 's', 'op': 'isTrue'},
      });
      expect(find.text('Shown only when “Student” is ticked.'), findsOneWidget);
      // The chip count on the tab.
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('read-only when…, fill in automatically, and who uses it', (tester) async {
      final c = await pumpInspector(tester, formOf([
        fj('s', 'toggle', {'label': 'Student'}),
        fj('a', 'text', {'label': 'School'}),
        fj('b', 'text', {
          'label': 'Campus',
          'visibility': {
            'action': 'show',
            'when': {'ref': 'a', 'op': 'notEmpty'},
          },
        }),
      ]), select: 'a');
      await tapText(tester, 'Logic');
      await segment(tester, 'Can people change it', 'Read-only');
      expect(el(c, 'a')['disabled'], true);
      await tapText(tester, 'Add a rule');
      final sv = (el(c, 'a')['setValue']! as List).single as Map;
      expect(sv['value'], {'const': ''});
      expect(sv['when'], {'match': 'all', 'conditions': <Object?>[]});
      expect(find.text('“Campus” when it shows'), findsOneWidget);
      await tapText(tester, '“Campus” when it shows');
      expect(c.selectedId, 'b');
    });
  });

  group('sections, text and pages', () {
    testWidgets('a section can repeat, which gives it a key', (tester) async {
      final c = await pumpInspector(tester, formOf([
        {'kind': 'group', 'id': 'g', 'title': 'Children', 'elements': <Object?>[]},
      ]), select: 'g');
      await tapText(tester, 'People can add this section more than once');
      expect(el(c, 'g'), {
        'kind': 'group',
        'id': 'g',
        'title': 'Children',
        'key': 'children',
        'repeat': {'min': 1, 'addLabel': 'Add another', 'itemLabel': 'Entry {n}'},
        'elements': <Object?>[],
      });
      await segment(tester, 'Columns', 'Two');
      expect(el(c, 'g')['columns'], 2);
    });

    testWidgets('a heading becomes a text block', (tester) async {
      final c = await pumpInspector(tester, formOf([createStatic('heading').toJson()..['id'] = 's']), select: 's');
      await segment(tester, 'Kind', 'Text');
      await type(tester, 'Text', 'Read this first.');
      expect(el(c, 's'), {'kind': 'static', 'id': 's', 'type': 'paragraph', 'text': 'Read this first.'});
    });

    testWidgets('a page jump goes to a later page or the end', (tester) async {
      final def = formOf([fj('s', 'toggle', {'label': 'Student'})]);
      def.pages
        ..add(UiFbPage(id: 'p2', title: 'Two', elements: []))
        ..add(UiFbPage(id: 'p3', title: 'Three', elements: []));
      final c = await pumpInspector(tester, def, select: 'p1');
      await type(tester, 'Page title', 'About you');
      await tapText(tester, 'Logic');
      await tapText(tester, 'Add a jump');
      final jump = c.def.pages[0].jumps!.single;
      expect(jump.to, 'p3');
      await choose(tester, select('go to'), 'The end (submit)');
      expect(c.def.pages[0].toJson()['jumps'], [
        {'id': jump.id, 'when': {'match': 'all', 'conditions': <Object?>[]}, 'to': 'end'},
      ]);
      expect(c.def.pages[0].title, 'About you');
    });

    testWidgets('with nothing selected it edits the form and its settings', (tester) async {
      final c = await pumpInspector(tester, createDefinition());
      expect(find.text('Form settings'), findsOneWidget);
      await type(tester, 'Form title', 'Enrolment');
      await type(tester, 'Submit button', 'Send');
      await choose(tester, select('Show problems'), 'Only when they continue or submit');
      expect(c.def.title, 'Enrolment');
      expect(c.def.settings!.toJson(), {'validateOn': 'submit', 'submitLabel': 'Send'});
    });
  });

  group('data source', () {
    testWidgets('switches a dropdown to a data source, sets a setting from another answer, and tests the list', (tester) async {
      final courses = UiFbOptionSource(
        type: 'courses',
        label: 'Courses',
        params: const [UiFbSourceParamSpec(key: 'programme', label: 'Programme', required: true)],
        search: (q) => UiFbSourcePage(items: [UiFbSourceItem(value: 'c1', label: 'Anatomy (${q.params['programme']})'), const UiFbSourceItem(value: 'c2', label: 'Biology')], total: 2),
      );
      final c = await pumpInspector(tester, formOf([fj('p', 'text', {'label': 'Programme'}), fj('a', 'select', {'label': 'Course', 'options': <Object?>[]})]), select: 'a', sources: [courses]);
      await segment(tester, 'Where the options come from', 'Data source');
      expect(el(c, 'a')['source'], {'type': 'courses', 'params': <String, Object?>{}});
      expect(c.problems.single.message, '“Course” needs “Programme” set for its Courses list.');
      await tapText(tester, 'Test the list');
      expect(find.text('Choose programme to test with first.'), findsOneWidget);
      await choose(tester, select('Programme: where the value comes from'), 'is the answer to');
      await choose(tester, select('Programme: question'), 'Programme');
      expect(el(c, 'a')['source'], {
        'type': 'courses',
        'params': {
          'programme': {'ref': 'p'},
        },
      });
      expect(c.problems, isEmpty);
      await type(tester, 'Try with Programme', 'health');
      await tapText(tester, 'Test the list');
      expect(find.text('Works: 2 courses, e.g. Anatomy (health), Biology.'), findsOneWidget);
    });
  });
}
