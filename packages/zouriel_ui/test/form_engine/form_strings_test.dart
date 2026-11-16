// The renderer's and engine's own words in the form's language (the web form-strings.spec.ts).
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/areas/form_engine.dart';

Map<String, Object?> f(String id, String type, [Map<String, Object?> extra = const {}]) => {'kind': 'field', 'id': id, 'type': type, 'key': id, 'label': id.toUpperCase(), ...extra};

Map<String, Object?> def(List<Map<String, Object?>> elements) => {
  'schemaVersion': 2, 'id': 'f', 'title': 'T', 'defaultLocale': 'en', 'revision': 1,
  'supportedLocales': [{'code': 'en'}, {'code': 'dv'}],
  'pages': [{'id': 'p1', 'elements': elements}],
};

UiFormEngine engine(Map<String, Object?> d, {UiJson? data, String? locale, UiFbStringOverrides? strings, List<UiFbValidatorDef> validators = const []}) =>
    UiFormEngine.fromJson(d, data: data, locale: locale, strings: strings, validators: validators, today: () => '2026-10-11');

void main() {
  group('fbStrings', () {
    test('picks by code, then base language, then English, and lays overrides on top', () {
      expect(fbStrings('dv').submit, uiFbStringsDv.submit);
      expect(fbStrings('dv-MV').submit, uiFbStringsDv.submit);
      expect(fbStrings('fr').submit, 'Submit');
      expect(fbStrings('fr', {'fr': {'submit': 'Envoyer'}}), uiFbStringsEn.merge({'submit': 'Envoyer'}));
      expect(fbStrings('dv-MV', {'dv': {'back': 'X'}}).back, 'X');
      expect(fbStrings(null), uiFbStringsEn);
    });

    test('ignores unknown keys and merges two sets per key', () {
      expect(fbStrings('en', {'en': {'nope': 'x'}}), uiFbStringsEn);
      final m = mergeFbStringOverrides({'dv': {'submit': 'A', 'back': 'B'}}, {'dv': {'submit': 'C'}, 'fr': {'back': 'R'}})!;
      expect(m, {'dv': {'submit': 'C', 'back': 'B'}, 'fr': {'back': 'R'}});
      expect(mergeFbStringOverrides(null, null), isNull);
      expect(fbStringOverridesEqual(m, {'dv': {'submit': 'C', 'back': 'B'}, 'fr': {'back': 'R'}}), isTrue);
      expect(fbStringOverridesEqual(m, {'dv': {'submit': 'C'}}), isFalse);
    });

    test('fills placeholders and leaves unknown ones', () {
      expect(fbFormat('{a} and {b} and {c}', {'a': 1, 'b': 'x', 'c': null}), '1 and x and {c}');
    });
  });

  group('UiFormEngine strings', () {
    final required = def([f('name', 'text', {'label': {'en': 'Name', 'dv': 'ނަން'}, 'required': true, 'validators': [{'id': 'v', 'type': 'minLength', 'params': {'min': 5}}]})]);

    test('keeps English wording unchanged', () {
      final e = engine(required);
      expect(e.instanceState('name', null).errors, ['Name is required.']);
      e.setValue('name', null, 'ab');
      expect(e.instanceState('name', null).errors, ['Name must be at least 5 characters.']);
      expect(e.strings, uiFbStringsEn);
    });

    test('words required and length messages in Dhivehi, and again when the language changes', () {
      final e = engine(required, locale: 'dv');
      expect(e.instanceState('name', null).errors, ['ނަން ފުރިހަމަ ކުރަންޖެހެއެވެ.']);
      e.setValue('name', null, 'ab');
      expect(e.instanceState('name', null).errors, ['ނަން ގައި މަދުވެގެން 5 އަކުރު ހުންނަންޖެހެއެވެ.']);
      e.setLocale('en');
      expect(e.instanceState('name', null).errors, ['Name must be at least 5 characters.']);
    });

    test('lets a message written on the form win, and overrides win over the built-in words', () {
      final d = def([f('a', 'text', {'label': 'A', 'required': true, 'requiredMessage': {'en': 'Fill A', 'dv': 'ފުރާ'}})]);
      expect(engine(d, locale: 'dv').instanceState('a', null).errors, ['ފުރާ']);
      final e = engine(def([f('a', 'text', {'label': 'A', 'required': true})]), strings: {'en': {'requiredField': 'Need {label}!'}});
      expect(e.instanceState('a', null).errors, ['Need A!']);
      var notified = 0;
      e.addListener(() => notified++);
      e.setStrings({'en': {'requiredField': 'Please give {label}'}});
      expect(notified, greaterThan(0));
      expect(e.instanceState('a', null).errors, ['Please give A']);
    });

    test('says Yes/No in the form language', () {
      final c = UiFbField.fromJson(f('c', 'checkbox'));
      expect(formatValue(c, true, textLocale: 'dv', defaultLocale: 'en', strings: uiFbStringsDv), 'އާނ');
      expect(formatValue(c, false, textLocale: 'dv', defaultLocale: 'en', strings: uiFbStringsDv), 'ނޫން');
      expect(formatValue(c, true), 'Yes');
    });

    test('marks an option that is gone in the form language', () {
      final s = UiFbField.fromJson(f('s', 'select', {'options': [{'id': 'o', 'value': 'x', 'label': 'X'}]}));
      expect(optionLabel(s, 'gone'), 'gone (no longer an option)');
      expect(optionLabel(s, 'gone', strings: uiFbStringsDv), fbFormat(uiFbStringsDv.noLongerOption, {'value': 'gone'}));
    });

    test('words comparison and relative date messages', () {
      final d = def([
        f('a', 'number', {'label': 'A'}),
        f('b', 'number', {'label': 'B', 'validators': [{'id': 'c', 'type': 'compareField', 'params': {'comparison': 'gt', 'field': 'a'}}]}),
      ]);
      expect(engine(d, data: {'a': 5, 'b': 1}).instanceState('b', null).errors, ['B must be more than “A”.']);
      expect(engine(d, data: {'a': 5, 'b': 1}, locale: 'dv').instanceState('b', null).errors.first, contains(uiFbStringsDv.compareGt));
      expect(describeDateParam('today+3'), '3 days from today');
      expect(describeDateParam('today-2', uiFbStringsDv), fbFormat(uiFbStringsDv.dateDaysAgo, {'n': 2}));
      expect(describeDateParam('today', uiFbStringsDv), uiFbStringsDv.dateToday);
    });

    test('takes a message by language from a registered check', () {
      final check = UiFbValidatorDef(type: 'taken', label: 'Taken', defaultMessage: const {'en': 'Taken.', 'dv': 'ނެގިފައި.'}, validate: (v, p, c) => false);
      final d = def([f('a', 'text', {'validators': [{'id': 'r', 'type': 'taken'}]})]);
      final e = engine(d, validators: [check], data: {'a': 'x'});
      expect(e.instanceState('a', null).errors, ['Taken.']);
      e.setLocale('dv');
      expect(e.instanceState('a', null).errors, ['ނެގިފައި.']);
      expect(validatorMessageFor('zzz', null, uiFbStringsEn), '{label} is not valid.');
      expect(validatorMessage(check, uiFbStringsEn, 'dv-MV'), 'ނެގިފައި.');
    });

    test('names repeat entries in the form language', () {
      final g = {'kind': 'group', 'id': 'g', 'key': 'g', 'repeat': {'min': 1}, 'elements': [f('n', 'text', {'required': true})]};
      final e = engine(def([g]), locale: 'dv');
      expect(e.instanceLabel('n', e.rows('g').first), contains('އެންޓްރީ 1'));
    });
  });
}
