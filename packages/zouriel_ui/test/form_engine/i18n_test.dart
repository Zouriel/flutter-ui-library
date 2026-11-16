// Multilingual forms (English + Dhivehi, right to left): the Dart port of the web `localize.spec.ts`.
// The shared JSON fixtures (localize, migrate, submission-fields, engine-locale) run in
// shared_fixtures_test.dart; these cover what they can't say: widgets and the helper edge cases.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

void expectJson(Object? actual, Object? expected, String reason) => expect(jsonEquals(actual, expected), isTrue, reason: '$reason\n  got:  $actual\n  want: $expected');

UiFbText t(String en, String dv) => UiFbText.localized({'en': en, 'dv': dv});

UiFormDefinition bilingual() => UiFormDefinition.fromJson({
  'schemaVersion': 2,
  'id': 'bi',
  'title': {'en': 'Application', 'dv': 'ފޯމް'},
  'description': {'en': 'Tell us about you', 'dv': 'ތިބާގެ ބަޔާން'},
  'defaultLocale': 'en',
  'supportedLocales': [
    {'code': 'en'},
    {'code': 'dv'},
  ],
  'revision': 5,
  'settings': {
    'submitLabel': {'en': 'Send', 'dv': 'ފޮނުވާ'},
  },
  'pages': [
    {
      'id': 'p1',
      'elements': [
        {
          'kind': 'field', 'id': 'name', 'type': 'text', 'key': 'name', 'required': true,
          'label': {'en': 'Full name', 'dv': 'ފުރިހަމަ ނަން'},
          'help': {'en': 'As on your ID', 'dv': 'ކާޑުގައިވާ ގޮތަށް'},
          'placeholder': {'en': 'Your name', 'dv': 'ނަން'},
        },
        {
          'kind': 'field', 'id': 'city', 'type': 'select', 'key': 'city',
          'label': {'en': 'City', 'dv': 'ސިޓީ'},
          'options': [
            {'id': 'o1', 'value': 'male', 'label': {'en': 'Malé', 'dv': 'މާލެ'}},
            {'id': 'o2', 'value': 'addu', 'label': 'Addu'},
          ],
        },
        {'kind': 'static', 'id': 'st', 'type': 'paragraph', 'text': {'en': 'Thank you', 'dv': 'ޝުކުރިއްޔާ'}},
      ],
    },
  ],
});

UiFormEngine engine(UiFormDefinition d, {String? locale, UiFbSubmissionLink? link}) => UiFormEngine(definition: d, locale: locale, link: link, today: () => '2027-01-01');

void main() {
  group('migrateDefinition v1 to v2', () {
    final v1 = {
      'schemaVersion': 1,
      'id': 'a',
      'title': 'Old',
      'pages': [
        {
          'id': 'p',
          'title': 'One',
          'elements': [
            {'kind': 'field', 'id': 'f', 'type': 'text', 'key': 'k', 'label': 'K', 'custom': 1},
          ],
        },
      ],
      'extra': {'keep': true},
    };

    test('keeps plain strings, adds English and the version', () {
      final d = migrateDefinition(v1);
      expect(d.schemaVersion, 2);
      expect(d.title, const UiFbText('Old'));
      expect(d.pages[0].title, const UiFbText('One'));
      expect(d.defaultLocale, 'en');
      expect([for (final l in d.supportedLocales!) l.toJson()], [{'code': 'en'}]);
      expect(d.toJson()['extra'], {'keep': true});
      expect((d.pages[0].elements[0] as UiFbField).toJson()['custom'], 1);
    });

    test('is idempotent', () {
      final once = migrateDefinition(v1);
      expectJson(migrateDefinition(once).toJson(), once.toJson(), 'twice');
    });

    test('accepts plain language codes and adds the default language', () {
      final d = migrateDefinition({...v1, 'defaultLocale': 'dv', 'supportedLocales': ['en']});
      expect([for (final l in d.supportedLocales!) l.toJson()], [{'code': 'dv'}, {'code': 'en'}]);
    });

    test('new forms start with English', () {
      final d = createDefinition();
      expect(d.schemaVersion, 2);
      expect(d.defaultLocale, 'en');
      expect([for (final l in d.supportedLocales!) l.toJson()], [{'code': 'en'}]);
    });
  });

  group('UiFormEngine languages', () {
    test('words labels, messages and repeat entries in the active language and falls back to the default', () {
      final e = engine(bilingual());
      expect(e.locale, 'en');
      expect(e.dir, UiFbDir.ltr);
      expect(e.text(t('A', 'B')), 'A');
      expect(e.instanceState('name', null).errors, ['Full name is required.']);
      e.setLocale('dv');
      expect(e.locale, 'dv');
      expect(e.dir, UiFbDir.rtl);
      expect(e.text(t('A', 'B')), 'B');
      expect(e.instanceState('name', null).errors, ['ފުރިހަމަ ނަން ފުރިހަމަ ކުރަންޖެހެއެވެ.']);
      e.setLocale('xx');
      expect(e.locale, 'en');
      expect(e.text(UiFbText.localized({'fr': 'Seulement'})), 'Seulement');
      e.dispose();
    });

    test('tells listeners when the language changes, and keeps the answers', () {
      final e = engine(bilingual());
      var heard = 0;
      e.addListener(() => heard++);
      e.setValue('name', null, 'Aisha');
      final before = heard;
      e.setLocale('dv');
      expect(heard, before + 1);
      e.setLocale('dv');
      expect(heard, before + 1, reason: 'no change, no notification');
      expect(e.data['name'], 'Aisha');
      expect(e.instanceState('name', null).errors, isEmpty);
      e.dispose();
    });

    test('submits the language, the field descriptions and the link', () {
      final e = engine(bilingual(), locale: 'dv', link: const UiFbSubmissionLink(workflowId: 'wf', serviceCode: 'S1'));
      e.setValue('name', null, 'Aisha');
      final s = e.submit()!;
      expect((s.formId, s.revision, s.locale, s.workflowId, s.serviceCode), ('bi', 5, 'dv', 'wf', 'S1'));
      expectJson([for (final f in s.fields) f.toJson()], [
        {'path': 'name', 'key': 'name', 'label': 'ފުރިހަމަ ނަން', 'type': 'text'},
        {'path': 'city', 'key': 'city', 'label': 'ސިޓީ', 'type': 'select'},
      ], 'fields');
      expect(s.toJson().keys.toList(), ['formId', 'revision', 'locale', 'values', 'submittedAt', 'workflowId', 'serviceCode', 'fields']);
      e.dispose();
    });

    test('leaves the link keys out when there is no link', () {
      final e = engine(bilingual());
      e.setValue('name', null, 'x');
      final s = e.submit()!;
      expect(s.toJson().containsKey('workflowId'), isFalse);
      expect(s.toJson().containsKey('serviceCode'), isFalse);
      expect(s.locale, 'en');
      e.setLink(const UiFbSubmissionLink(workflowId: 'w'));
      final s2 = e.submit()!;
      expect(s2.workflowId, 'w');
      expect(s2.toJson().containsKey('serviceCode'), isFalse);
      e.dispose();
    });

    test('a failed async check is worded again in the language then in use', () async {
      final taken = UiFbValidatorDef(type: 'free', label: 'Free', defaultMessage: '{label} is taken.', debounceMs: 10, validate: (v, p, c) => Future.value(v != 'admin'));
      final d = bilingual();
      ((d.pages[0].elements[0] as UiFbField).validators = [
        UiFbValidatorRule(id: 'v', type: 'free', message: t('{label} is used', '{label} ބޭނުންކުރެވިފައި')),
      ]);
      final e = UiFormEngine(definition: d, validators: [taken], today: () => '2027-01-01');
      e.setValue('name', null, 'admin');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(e.instanceState('name', null).errors, ['Full name is used']);
      e.setLocale('dv');
      expect(e.instanceState('name', null).errors, ['ފުރިހަމަ ނަން ބޭނުންކުރެވިފައި']);
      e.dispose();
    });
  });

  group('form language tools', () {
    test('lists data paths with [] for repeating sections', () {
      final d = bilingual();
      d.pages[0].elements.add(UiFbGroup(id: 'g', key: 'kids', repeat: UiFbRepeat(), elements: [
        UiFbField(id: 'age', type: UiFbFieldType.number, key: 'age', label: t('Age', 'އުމުރު')),
      ]));
      expectJson(fbSubmissionFields(d, 'dv').last.toJson(), {'path': 'kids[].age', 'key': 'age', 'label': 'އުމުރު', 'type': 'number'}, 'last');
    });

    test('warns once per element and language about missing translations, skipping archived ones', () {
      final d = bilingual();
      d.pages[0].elements.add(UiFbField(id: 'gone', type: UiFbFieldType.text, key: 'gone', label: const UiFbText('Old'), archived: true));
      final w = lintDefinition(d).where((p) => p.message.contains('translation')).toList();
      expect(w.map((p) => p.targetId), ['city']);
      expect(w[0].message, contains('(dv)'));
      expect(w[0].message, contains('option 2'));
    });

    test('notes added and removed languages and changed wording when comparing versions', () {
      final before = bilingual();
      final after = before.clone();
      after.supportedLocales = [UiFbLocale(code: 'en')];
      (after.pages[0].elements[0] as UiFbField).label = t('Full name', 'ނަން');
      final diff = diffDefinitions(before, after);
      expect(diff.localesRemoved, ['dv']);
      expect(diff.textChanged, ['name']);
      expect(diff.summary.any((l) => l.contains('Removed the language')), isTrue);
      expect(diffDefinitions(after, before).localesAdded, ['dv']);
    });

    test('names elements in the language asked for', () {
      final d = bilingual();
      final name = d.pages[0].elements[0];
      expect(elementName(name, d), 'Full name');
      expect(elementName(name, d, 'dv'), 'ފުރިހަމަ ނަން');
    });
  });

  group('UiFormRenderer languages', () {

    Directionality dirOf(WidgetTester tester) => tester.widget<Directionality>(find.descendant(of: find.byType(UiFormRenderer), matching: find.byType(Directionality)).first);

    testWidgets('switches words and direction without losing answers', (tester) async {
      final host = _Host(bilingual());
      await _pumpHost(tester, host);
      expect(dirOf(tester).textDirection, TextDirection.ltr);
      expect(find.textContaining('Full name'), findsWidgets);
      expect(find.text('Thank you'), findsOneWidget);
      expect(find.text('Application'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).first, 'Aisha');
      await tester.pump();

      host.locale.value = 'dv';
      await tester.pumpAndSettle();
      expect(dirOf(tester).textDirection, TextDirection.rtl);
      expect(find.textContaining('ފުރިހަމަ ނަން'), findsWidgets);
      expect(find.text('ޝުކުރިއްޔާ'), findsOneWidget);
      expect(find.text('Thank you'), findsNothing);
      expect(find.text('ފޯމް'), findsOneWidget);
      expect(find.text('ފޮނުވާ'), findsOneWidget);
      expect(find.text('ކާޑުގައިވާ ގޮތަށް'), findsOneWidget);
      expect(host.key.currentState!.engine.data['name'], 'Aisha');
      expect(tester.widget<EditableText>(find.byType(EditableText).first).controller.text, 'Aisha');

      host.locale.value = null;
      await tester.pumpAndSettle();
      expect(dirOf(tester).textDirection, TextDirection.ltr);
      expect(find.textContaining('Full name'), findsWidgets);
      expect(find.text('Send'), findsOneWidget);
      expect(host.key.currentState!.engine.data['name'], 'Aisha');
    });

    testWidgets('lays out right to left: the first control sits at the right edge', (tester) async {
      final host = _Host(bilingual(), locale: 'dv');
      await _pumpHost(tester, host);
      final box = tester.getRect(find.byType(EditableText).first);
      final form = tester.getRect(find.byType(UiFormRenderer));
      expect(form.right - box.right, lessThan(box.left - form.left + 1), reason: 'the box ends at the right edge in a right-to-left form');
      final label = tester.getTopRight(find.textContaining('ފުރިހަމަ ނަން').first);
      expect(form.right - label.dx, lessThan(form.width / 2), reason: 'the label starts at the right');
    });

    testWidgets('falls back to the default language for one it does not offer, and submits the language and link', (tester) async {
      final got = <UiFormSubmission>[];
      final host = _Host(bilingual(), locale: 'fr', link: const UiFbSubmissionLink(workflowId: 'wf', serviceCode: 'S'), onSubmitted: got.add);
      await _pumpHost(tester, host);
      expect(host.key.currentState!.engine.locale, 'en');
      expect(dirOf(tester).textDirection, TextDirection.ltr);
      host.locale.value = 'dv';
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, 'Aisha');
      await tester.pump();
      await tester.tap(find.widgetWithText(UiButton, 'ފޮނުވާ'));
      await tester.pumpAndSettle();
      expect(got.length, 1);
      expect((got[0].locale, got[0].workflowId, got[0].serviceCode), ('dv', 'wf', 'S'));
      expect(got[0].fields.map((f) => f.path), ['name', 'city']);
    });
  });
}

String _today() => '2027-01-01';

class _Host {
  _Host(this.def, {String? locale, this.link, this.onSubmitted}) : locale = ValueNotifier(locale);
  final UiFormDefinition def;
  final ValueNotifier<String?> locale;
  final UiFbSubmissionLink? link;
  final ValueChanged<UiFormSubmission>? onSubmitted;
  final key = GlobalKey<UiFormRendererState>();
}

Future<void> _pumpHost(WidgetTester tester, _Host h) async {
  await pumpUi(
    tester,
    ValueListenableBuilder<String?>(
      valueListenable: h.locale,
      builder: (context, locale, _) => SizedBox(
        width: 390,
        height: 844,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: UiFormRenderer(key: h.key, definition: h.def, locale: locale, link: h.link, onSubmitted: h.onSubmitted, today: _today),
        ),
      ),
    ),
    size: const Size(390, 844),
  );
}
