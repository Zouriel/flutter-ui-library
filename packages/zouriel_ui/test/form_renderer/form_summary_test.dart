import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

UiFormDefinition _sampleDef() {
  return UiFormDefinition.fromJson({
    'id': 'form_1',
    'schemaVersion': 2,
    'title': {'en': 'Planning Application', 'dv': 'ޕްލޭނިންގ އެޕްލިކޭޝަން'},
    'defaultLocale': 'en',
    'supportedLocales': [
      {'code': 'en', 'label': 'English', 'dir': 'ltr'},
      {'code': 'dv', 'label': 'Dhivehi', 'dir': 'rtl'},
    ],
    'pages': [
      {
        'id': 'p1',
        'title': 'Step 1',
        'elements': [
          {
            'id': 'sec1',
            'kind': 'group',
            'key': 'personal',
            'title': {'en': 'Personal details', 'dv': 'އަމިއްލަ މަޢުލޫމާތު'},
            'elements': [
              {
                'id': 'f_name',
                'kind': 'field',
                'type': 'text',
                'key': 'full_name',
                'label': {'en': 'Full name', 'dv': 'ފުރިހަމަ ނަން'},
              },
              {
                'id': 'f_empty',
                'kind': 'field',
                'type': 'text',
                'key': 'nickname',
                'label': 'Nickname',
              },
              {
                'id': 'f_hidden',
                'kind': 'field',
                'type': 'hidden',
                'key': 'secret',
                'label': 'Secret',
              },
            ],
          },
          {
            'id': 'f_has_exp',
            'kind': 'field',
            'type': 'toggle',
            'key': 'has_exp',
            'label': 'Has experience',
          },
          {
            'id': 'f_years',
            'kind': 'field',
            'type': 'number',
            'key': 'years',
            'label': 'Years of experience',
            'visibility': {
              'action': 'show',
              'when': {
                'match': 'all',
                'conditions': [
                  {'ref': 'f_has_exp', 'op': 'isTrue'},
                ],
              },
            },
          },
        ],
      },
    ],
  });
}

void main() {
  testWidgets('UiFormSummary shows answered visible fields, keeps sections, skips hidden, marks assistant', (tester) async {
    final def = _sampleDef();
    await pumpUi(
      tester,
      SizedBox(
        width: 360,
        child: UiFormSummary(
          definition: def,
          answers: const {
            'personal': {'full_name': 'Aishath Ali', 'secret': 'xyz'},
            'has_exp': false,
            'years': 5,
          },
          language: 'en',
          marked: const ['personal.full_name'],
          subtitle: 'Ref 001',
          footer: const Text('Confirm & Submit'),
        ),
      ),
    );

    expect(find.text('Planning Application'), findsOneWidget);
    expect(find.text('Ref 001'), findsOneWidget);
    expect(find.text('PERSONAL DETAILS'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Aishath Ali'), findsOneWidget);
    expect(find.text('Has experience'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
    expect(find.text('Nickname'), findsNothing);
    expect(find.text('Secret'), findsNothing);
    expect(find.text('Years of experience'), findsNothing);
    expect(find.text('Filled in by the assistant'), findsOneWidget);
    expect(find.text('Confirm & Submit'), findsOneWidget);
  });

  testWidgets('UiFormSummary switches language and direction for Dhivehi', (tester) async {
    final def = _sampleDef();
    await pumpUi(
      tester,
      SizedBox(
        width: 360,
        child: UiFormSummary(
          definition: def,
          answers: const {
            'personal': {'full_name': 'ޢާއިޝަތު ޢަލީ'},
          },
          language: 'dv',
        ),
      ),
    );

    expect(find.text('ޕްލޭނިންގ އެޕްލިކޭޝަން'), findsOneWidget);
    expect(find.text('ފުރިހަމަ ނަން'), findsOneWidget);
    final dir = tester.widget<Directionality>(
      find.descendant(of: find.byType(UiFormSummary), matching: find.byType(Directionality)).first,
    );
    expect(dir.textDirection, TextDirection.rtl);
  });

  testWidgets('UiFormBuilder exposes agentInteractable switch without storing in definition JSON', (tester) async {
    bool agent = false;
    UiFormDefinition def = createDefinition(title: 'Test Form');

    await pumpUi(
      tester,
      size: const Size(1200, 800),
      StatefulBuilder(
        builder: (context, setState) => SizedBox(
          width: 1200,
          height: 800,
          child: UiFormBuilder(
            definition: def,
            onChanged: (d) => def = d,
            agentInteractable: agent,
            onAgentInteractableChanged: (v) => setState(() => agent = v),
          ),
        ),
      ),
    );

    expect(find.text('Available to the assistant'), findsOneWidget);
    await tester.ensureVisible(find.text('Available to the assistant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Available to the assistant'));
    await tester.pumpAndSettle();
    expect(agent, isTrue);
    expect(def.toJson().containsKey('agentInteractable'), isFalse);
  });

  testWidgets('UiFormSummary golden', (tester) async {
    final def = _sampleDef();
    await expectThemedGolden(
      tester,
      'form_summary',
      width: 380,
      height: 320,
      (context) => UiFormSummary(
        definition: def,
        answers: const {
          'personal': {'full_name': 'Aishath Ali'},
          'has_exp': true,
          'years': 4,
        },
        marked: const ['personal.full_name'],
        subtitle: 'Check every answer before you confirm.',
      ),
    );
  });
}
