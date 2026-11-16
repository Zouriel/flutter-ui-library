import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import 'support.dart';

UiFormDefinition bilingualForm() => formOf(
  [
    fj('a', 'select', {
      'label': {'en': 'Island', 'dv': 'ރަށް'},
      'options': [
        {'id': 'o1', 'value': 'male', 'label': {'en': 'Male', 'dv': 'މާލެ'}},
      ],
    }),
    fj('b', 'text', {'label': 'Name'}),
  ],
  extra: {
    'title': {'en': 'Survey', 'dv': 'ސާވޭ'},
  },
);

UiFormBuilderController bilingual() {
  final s = UiFormBuilderController(definition: bilingualForm());
  s.addLocale('dv');
  return s;
}

Future<UiFormBuilderController> pumpScope(WidgetTester tester, UiFormBuilderController c, Widget child, {Size size = const Size(390, 2400)}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(home: UiFbBuilderScope(controller: c, child: child)));
  await tester.pumpAndSettle();
  return c;
}

void main() {
  group('UiFormBuilderController languages', () {
    test('starts with one language and adds Dhivehi as right to left', () {
      final s = UiFormBuilderController(definition: formOf([fj('a', 'text')]));
      expect(s.multilingual, isFalse);
      expect(s.editLocale, 'en');
      expect(s.addLocale('dv'), isTrue);
      expect(s.addLocale('dv'), isFalse);
      expect([for (final l in s.locales) (l.code, l.dir)], [('en', UiFbDir.ltr), ('dv', UiFbDir.rtl)]);
      expect(s.def.defaultLocale, 'en');
      s.undo();
      expect(s.multilingual, isFalse);
    });

    test('reads with no fallback for editors and with fallback for display', () {
      final s = bilingual();
      final b = s.field('b')!;
      s.setEditLocale('dv');
      expect(s.editDir, UiFbDir.rtl);
      expect(s.defaultDir, UiFbDir.ltr);
      expect(s.translating, isTrue);
      expect(s.text(b.label), '');
      expect(s.shown(b.label), 'Name');
      expect(s.defaultText(b.label), 'Name');
      expect(s.text(s.field('a')!.label), 'ރަށް');
      s.setEditLocale('en');
      expect(s.defaultText(b.label), '');
    });

    test('editing another language writes that translation and leaves the default intact', () {
      final s = bilingual();
      s.setEditLocale('dv');
      s.updateField('b', (f) => f.label = s.setText(f.label, 'ނަން'));
      expect(s.field('b')!.label, UiFbText.localized({'en': 'Name', 'dv': 'ނަން'}));
      s.setEditLocale('en');
      s.updateField('b', (f) => f.label = s.setText(f.label, 'Full name'));
      expect(s.field('b')!.label, UiFbText.localized({'en': 'Full name', 'dv': 'ނަން'}));
      // Clearing a translation goes back to a plain string.
      s.setEditLocale('dv');
      s.updateField('b', (f) => f.label = s.setText(f.label, ''));
      expect(s.field('b')!.label, const UiFbText('Full name'));
    });

    test('keeps a section key when only a translation changes', () {
      final g = createGroup(repeat: true).toJson()..['id'] = 'g'..['title'] = 'Dependants';
      final s = UiFormBuilderController(definition: formOf([g]));
      s.addLocale('dv');
      s.setGroupTitle('g', 'Dependants');
      final key = s.index['g']!.asGroup!.key;
      s.setEditLocale('dv');
      s.setGroupTitle('g', 'ބެލެނިވެރިން');
      expect(s.index['g']!.asGroup!.key, key);
      expect(s.index['g']!.asGroup!.title, UiFbText.localized({'en': 'Dependants', 'dv': 'ބެލެނިވެރިން'}));
    });

    test('removing a language drops its text everywhere and is one undo', () {
      final s = bilingual();
      s.removeLocale('en');
      expect(s.locales.length, 2, reason: 'the default language can not be removed');
      s.removeLocale('dv');
      expect(s.field('a')!.label, const UiFbText('Island'));
      expect(s.field('a')!.options!.first.label, const UiFbText('Male'));
      expect(s.def.title, const UiFbText('Survey'));
      expect([for (final l in s.def.supportedLocales ?? const <UiFbLocale>[]) l.code], ['en']);
      s.undo();
      expect(s.field('a')!.label, UiFbText.localized({'en': 'Island', 'dv': 'ރަށް'}));
    });

    test('falls back to the default language when the edit language is removed', () {
      final s = bilingual();
      s.setEditLocale('dv');
      s.removeLocale('dv');
      expect(s.editLocale, 'en');
    });

    test('changes the default language and a language direction', () {
      final s = bilingual();
      s.setDefaultLocale('dv');
      expect(s.defaultLocale, 'dv');
      expect(s.locales.first.code, 'dv');
      s.setLocaleDir('en', UiFbDir.rtl);
      expect(s.locales.firstWhere((l) => l.code == 'en').dir, UiFbDir.rtl);
    });

    test('replaces the whole definition as one undoable edit and keeps the revision', () {
      final c = UiFormBuilderController(definition: UiFormDefinition.fromJson(formOf([fj('a', 'text')]).toJson()..['revision'] = 3));
      c.replace(formOf([fj('z', 'text')]).toJson());
      expect(c.index.containsKey('z'), isTrue);
      expect(c.def.revision, 3);
      c.undo();
      expect(c.index.containsKey('a'), isTrue);
      expect(c.canUndo, isFalse);
    });
  });

  group('languages in the builder', () {
    testWidgets('the canvas lays out right to left when editing Dhivehi', (tester) async {
      final c = UiFormBuilderController(definition: formOf([fj('a', 'text', {'label': {'en': 'Name', 'dv': 'ނަން'}})]))..addLocale('dv');
      await pumpScope(tester, c, const UiFbCanvas(), size: const Size(390, 844));
      TextDirection dir() => Directionality.of(tester.element(find.text('Name')));
      expect(dir(), TextDirection.ltr);
      c.setEditLocale('dv');
      await tester.pumpAndSettle();
      expect(find.text('ނަން'), findsWidgets);
      expect(Directionality.of(tester.element(find.text('ނަން').first)), TextDirection.rtl);
    });

    testWidgets('the inspector writes the translation, shows the default text as a hint and keeps the key', (tester) async {
      final c = UiFormBuilderController(definition: formOf([createField(UiFbFieldType.text).toJson()..['id'] = 'a']))..addLocale('dv');
      c.select('a');
      await pumpScope(tester, c, const UiFbInspector());
      await type(tester, 'Question', 'Full name');
      expect(c.field('a')!.key, 'full_name');
      c.setEditLocale('dv');
      await tester.pumpAndSettle();
      expect(find.text('Full name'), findsOneWidget, reason: 'the default-language hint under the box');
      await type(tester, 'Question', 'ފުރިހަމަ ނަން');
      expect(c.field('a')!.label, UiFbText.localized({'en': 'Full name', 'dv': 'ފުރިހަމަ ނަން'}));
      expect(c.field('a')!.key, 'full_name');
      final box = tester.widget<UiInput>(find.byWidgetPredicate((w) => w is UiInput && w.semanticLabel == 'Question'));
      expect(box.dir, UiTextDir.rtl);
    });

    testWidgets('a missing-translation problem switches the edit language', (tester) async {
      final def = formOf([fj('a', 'text', {'label': 'Name'})], extra: {
        'defaultLocale': 'en',
        'supportedLocales': [
          {'code': 'en'},
          {'code': 'dv'},
        ],
      });
      final c = UiFormBuilderController(definition: def);
      expect(c.problems.any((p) => p.message.contains('translation for:')), isTrue);
      String? opened;
      await pumpScope(tester, c, UiFbLogicOverview(onOpen: (id) => opened = id), size: const Size(900, 900));
      await tester.tap(find.textContaining('“Name” has no'));
      await tester.pumpAndSettle();
      expect(c.editLocale, 'dv');
      expect(opened, 'a');
    });

    testWidgets('the Languages dialog adds, sets the direction of and removes a language', (tester) async {
      final c = UiFormBuilderController(definition: formOf([fj('a', 'text', {'label': 'Name'})]));
      tester.view.physicalSize = const Size(1280, 800) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UiApp(home: UiFormBuilder(controller: c)));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is UiSegmented && w.label == 'Language you are editing'), findsNothing);
      await tester.tap(find.text('Languages'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ދިވެހި (dv)'));
      await tester.pumpAndSettle();
      expect(c.locales.map((l) => l.code), ['en', 'dv']);
      expect(c.locales.last.dir, UiFbDir.rtl);
      await segment(tester, 'Direction of ދިވެހި', 'Left to right');
      expect(c.locales.last.dir, UiFbDir.ltr);
      await tester.tap(find.bySemanticsLabel('Remove ދިވެހި'));
      await tester.pumpAndSettle();
      expect(c.locales.length, 2, reason: 'asks first');
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(c.locales.length, 1);
      // A bad code is refused, a good one added.
      await tester.enterText(input('Language code'), 'x');
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Use a language code'), findsOneWidget);
      await tester.enterText(input('Language code'), 'pt-BR');
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();
      expect(c.locales.map((l) => l.code), ['en', 'pt-BR']);
    });

    testWidgets('the toolbar switches the edit language, and the preview gets its own language switcher', (tester) async {
      final c = UiFormBuilderController(definition: bilingualForm())..addLocale('dv');
      tester.view.physicalSize = const Size(1280, 800) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UiApp(home: UiFormBuilder(controller: c)));
      await tester.pumpAndSettle();
      await segment(tester, 'Language you are editing', 'ދިވެހި');
      expect(c.editLocale, 'dv');
      await segment(tester, 'View', 'Preview');
      expect(find.byWidgetPredicate((w) => w is UiSegmented && w.label == 'Language'), findsOneWidget);
      expect(find.text('ރަށް'), findsWidgets, reason: 'the preview starts in the language being edited');
      await segment(tester, 'Language', 'English');
      expect(find.text('Island'), findsWidgets);
    });
  });
}
