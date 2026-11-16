import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fakes.dart';

/// 0.87.0: `prefill` (starting answers of a new submission) and `serverErrors` (a 422 by data path).

final _def = form([
  f('name', 'text', {'key': 'full_name', 'label': 'Full name', 'required': true}),
  f('city', 'text', {'label': 'City'}),
]);

/// A renderer whose [UiFormRenderer.serverErrors] the test changes through [errors].
Future<GlobalKey<UiFormRendererState>> _pump(
  WidgetTester tester,
  ValueNotifier<Map<String, Object>?> errors, {
  UiJson? prefill,
  UiJson? definition,
  List<List<UiFbServerErrorItem>>? unmatched,
}) async {
  final key = GlobalKey<UiFormRendererState>();
  await pumpUi(
    tester,
    SizedBox(
      width: 390,
      height: 844,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder(
          valueListenable: errors,
          builder: (context, value, _) => UiFormRenderer(
            key: key,
            definition: definition ?? _def,
            prefill: prefill,
            serverErrors: value,
            onServerErrorsUnmatched: unmatched?.add,
            today: () => '2026-11-17',
          ),
        ),
      ),
    ),
  );
  return key;
}

String? _focusedSummary() => FocusManager.instance.primaryFocus?.debugLabel;

void main() {
  testWidgets('a prefilled new form shows the answers with the Submit label and no change list', (tester) async {
    final errors = ValueNotifier<Map<String, Object>?>(null);
    addTearDown(errors.dispose);
    final key = await _pump(tester, errors, prefill: {'full_name': 'Aisha Ali', 'city': 'Addu', 'efaas_id': 'A1'});
    expect(find.descendant(of: fieldView('Full name'), matching: find.text('Aisha Ali')), findsOneWidget);
    expect(find.descendant(of: fieldView('City'), matching: find.text('Addu')), findsOneWidget);
    expect(find.widgetWithText(UiButton, 'Submit'), findsOneWidget);
    expect(find.widgetWithText(UiButton, 'Save changes'), findsNothing);
    expect(find.text('No changes'), findsNothing);
    final e = key.currentState!.engine;
    expect(e.mode, UiFormMode.create);
    expect(e.dirty, isFalse);
    expect(e.values, {'full_name': 'Aisha Ali', 'city': 'Addu'});
  });

  testWidgets('without prefill the same form opens blank', (tester) async {
    final errors = ValueNotifier<Map<String, Object>?>(null);
    addTearDown(errors.dispose);
    await _pump(tester, errors);
    expect(find.text('Aisha Ali'), findsNothing);
    expect(find.widgetWithText(UiButton, 'Submit'), findsOneWidget);
  });

  testWidgets('a server error shows under its field and in the summary, takes focus, and goes when the answer changes', (tester) async {
    final errors = ValueNotifier<Map<String, Object>?>(null);
    addTearDown(errors.dispose);
    final reported = <List<UiFbServerErrorItem>>[];
    await _pump(tester, errors, prefill: {'full_name': 'Aisha'}, unmatched: reported);
    expect(find.textContaining('There '), findsNothing);
    expect(reported, isEmpty, reason: 'nothing reported before the server answers');

    errors.value = {'full_name': ['Use the name on your ID card.']};
    await tester.pumpAndSettle();
    expect(find.text('There is a problem'), findsOneWidget);
    expect(find.text('Use the name on your ID card.'), findsNWidgets(2), reason: 'in the summary and under the field');
    expect(find.byWidgetPredicate((w) => w is UiFieldScope && w.invalid), findsOneWidget);
    expect(reported, [<UiFbServerErrorItem>[]]);
    expect(_focusedSummary(), 'fr-summary');

    final box = find.descendant(of: fieldView('Full name'), matching: find.byType(EditableText));
    await tester.enterText(box, 'Aisha Ali');
    await tester.pumpAndSettle();
    expect(find.text('Use the name on your ID card.'), findsNothing);
    expect(find.textContaining('There '), findsNothing);
  });

  testWidgets('unmatched server errors are reported and listed first, as plain text, counted in the heading', (tester) async {
    final errors = ValueNotifier<Map<String, Object>?>(null);
    addTearDown(errors.dispose);
    final reported = <List<UiFbServerErrorItem>>[];
    await _pump(tester, errors, prefill: {'full_name': 'Aisha'}, unmatched: reported);
    errors.value = {'office_note': 'Applications are closed.', 'city': 'Unknown city.'};
    await tester.pumpAndSettle();
    expect(reported, [
      [const UiFbServerErrorItem(path: 'office_note', message: 'Applications are closed.')],
    ]);
    expect(find.text('There are 2 problems'), findsOneWidget);
    expect(summaryTexts(tester), ['Applications are closed.', 'Unknown city.']);
    // Only the field error is a link: the plain one has nothing to jump to.
    expect(
      find.ancestor(of: find.text('Applications are closed.'), matching: find.byType(UiInteractive)),
      findsNothing,
    );
    expect(find.ancestor(of: find.text('Unknown city.').first, matching: find.byType(UiInteractive)), findsWidgets);
    expect(_focusedSummary(), 'fr-summary');

    // Cleared by the host: the summary goes.
    errors.value = null;
    await tester.pumpAndSettle();
    expect(find.text('Applications are closed.'), findsNothing);
    expect(reported, hasLength(1), reason: 'clearing reports nothing');
  });

  testWidgets('a form without a summary moves focus to the first field with a server error', (tester) async {
    final errors = ValueNotifier<Map<String, Object>?>(null);
    addTearDown(errors.dispose);
    await _pump(tester, errors, definition: form([f('a', 'text'), f('b', 'text')], settings: {'errorSummary': false}));
    errors.value = {'b': 'Taken.'};
    await tester.pumpAndSettle();
    expect(find.textContaining('There '), findsNothing);
    expect(find.text('Taken.'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<UiFbFieldView>()?.field.id, 'b');
  });
}

/// The summary's item texts, in order.
List<String> summaryTexts(WidgetTester tester) {
  final box = find.ancestor(of: find.textContaining(RegExp(r'^There (is|are)')), matching: find.byType(Container)).first;
  return [
    for (final e in find.descendant(of: box, matching: find.byType(Text)).evaluate())
      if (!((e.widget as Text).data ?? '').startsWith('There ')) (e.widget as Text).data ?? '',
  ];
}
