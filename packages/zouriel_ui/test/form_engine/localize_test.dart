// The localized-text helpers of the form engine (port of the web `localize.ts`) and how
// `UiFbText` reads and writes JSON.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/form_builder/engine/localize.dart';
import 'package:zouriel_ui/src/form_builder/engine/schema.dart';

UiFbText loc(Map<String, String> m) => UiFbText.localized(m);

UiFormDefinition def({String? defaultLocale, List<UiFbLocale>? locales}) =>
    UiFormDefinition(id: 'f', title: const UiFbText('T'), defaultLocale: defaultLocale, supportedLocales: locales, pages: []);

void main() {
  group('UiFbText JSON', () {
    test('a string stays a string, a map stays a map in key order', () {
      expect(UiFbText.fromJson('Name')!.toJson(), 'Name');
      final t = UiFbText.fromJson({'dv': 'ނަން', 'en': 'Name'})!;
      expect(t.isLocalized, isTrue);
      expect(jsonEncode(t.toJson()), jsonEncode({'dv': 'ނަން', 'en': 'Name'}));
      expect(UiFbText.fromJson(null), isNull);
    });

    test('value equality; the map cannot be changed', () {
      expect(const UiFbText('a'), const UiFbText('a'));
      expect(loc({'en': 'a', 'dv': 'b'}), loc({'dv': 'b', 'en': 'a'}));
      expect(loc({'en': 'a'}) == const UiFbText('a'), isFalse);
      expect(() => loc({'en': 'a'}).map!['x'] = 'y', throwsUnsupportedError);
    });

    test('a definition round-trips plain and localized texts', () {
      final json = {
        'schemaVersion': 2,
        'id': 'f',
        'title': {'en': 'Form', 'dv': 'ފޯމް'},
        'description': 'Plain',
        'defaultLocale': 'dv',
        'supportedLocales': [
          {'code': 'dv', 'dir': 'rtl'},
          {'code': 'en', 'label': 'English'},
        ],
        'pages': <Object?>[],
      };
      final d = UiFormDefinition.fromJson(json);
      expect(d.title.isLocalized, isTrue);
      expect(d.supportedLocales!.length, 2);
      expect(jsonEncode(d.toJson()), jsonEncode(json));
    });
  });

  group('fbText', () {
    final t = loc({'en': 'Name', 'dv': 'ނަން', 'fr-CA': 'Nom'});
    test('exact', () => expect(fbText(t, 'dv'), 'ނަން'));
    test('base language', () {
      expect(fbText(loc({'dv': 'ނަން', 'en': 'Name'}), 'dv-MV'), 'ނަން');
      expect(fbText(t, 'fr'), 'Nom');
    });
    test('default locale', () {
      expect(fbText(t, 'de'), 'Name');
      expect(fbText(loc({'en': 'Name', 'dv': 'ނަން'}), 'de', 'dv'), 'ނަން');
    });
    test('first non-empty', () {
      expect(fbText(loc({'en': ' ', 'dv': '', 'ar': 'اسم'}), 'de'), 'اسم');
      expect(fbText(loc({'en': ' '}), 'de'), '');
    });
    test('blank counts as missing', () => expect(fbText(loc({'dv': '  ', 'en': 'Name'}), 'dv'), 'Name'));
    test('plain string and null', () {
      expect(fbText(const UiFbText('Hello'), 'dv'), 'Hello');
      expect(fbText(null, 'dv'), '');
    });
  });

  test('fbTextIn has no fallback', () {
    final t = loc({'en': 'Name', 'dv': 'ނަން'});
    expect(fbTextIn(t, 'dv'), 'ނަން');
    expect(fbTextIn(t, 'ar'), '');
    expect(fbTextIn(const UiFbText('Hi'), 'en'), 'Hi');
    expect(fbTextIn(const UiFbText('Hi'), 'dv'), '');
    expect(fbTextIn(const UiFbText('Hi'), 'dv', 'dv'), 'Hi');
    expect(fbTextIn(null, 'en'), '');
  });

  group('fbSetText', () {
    test('plain string stays plain while only the default is written', () {
      expect(fbSetText(const UiFbText('a'), 'en', 'b'), const UiFbText('b'));
      expect(fbSetText(null, 'en', 'b'), const UiFbText('b'));
    });
    test('first translation turns it into a map', () {
      final r = fbSetText(const UiFbText('Name'), 'dv', 'ނަން');
      expect(r.map, {'en': 'Name', 'dv': 'ނަން'});
      expect(r.map!.keys.toList(), ['en', 'dv']);
    });
    test('collapses back to a plain string', () {
      final r = fbSetText(loc({'en': 'Name', 'dv': 'ނަން'}), 'dv', '');
      expect(r, const UiFbText('Name'));
    });
    test('removes a blank translation, keeps the others', () {
      final r = fbSetText(loc({'en': 'Name', 'dv': 'ނަން', 'ar': 'اسم'}), 'dv', '  ');
      expect(r.map, {'en': 'Name', 'ar': 'اسم'});
    });
    test('an empty default stays in the map next to translations', () {
      final r = fbSetText(const UiFbText(''), 'dv', 'ނަން');
      expect(r.map, {'dv': 'ނަން'});
    });
    test('everything cleared gives an empty plain string', () {
      expect(fbSetText(loc({'dv': 'x'}), 'dv', ''), const UiFbText(''));
    });
    test('does not change its input', () {
      final t = loc({'en': 'a'});
      fbSetText(t, 'dv', 'b');
      expect(t.map, {'en': 'a'});
    });
    test('custom default locale', () {
      final r = fbSetText(const UiFbText('ނަން'), 'en', 'Name', 'dv');
      expect(r.map, {'dv': 'ނަން', 'en': 'Name'});
    });
  });

  group('locales', () {
    final d = def(defaultLocale: 'dv', locales: [UiFbLocale(code: 'en'), UiFbLocale(code: 'dv', label: 'Dhivehi'), UiFbLocale(code: 'en-GB', dir: UiFbDir.rtl)]);

    test('default locale', () {
      expect(fbDefaultLocale(null), 'en');
      expect(fbDefaultLocale(def()), 'en');
      expect(fbDefaultLocale(def(locales: [UiFbLocale(code: 'ar')])), 'ar');
      expect(fbDefaultLocale(d), 'dv');
    });

    test('fbLocales puts the default first and fills label and dir', () {
      final l = fbLocales(d);
      expect(l.map((x) => x.code), ['dv', 'en', 'en-GB']);
      expect(l[0].label, 'Dhivehi');
      expect(l[0].dir, UiFbDir.rtl);
      expect(l[1].label, 'English');
      expect(l[1].dir, UiFbDir.ltr);
      expect(l[2].dir, UiFbDir.rtl);
      expect(fbLocales(null).map((x) => x.code), ['en']);
    });

    test('resolve locale', () {
      expect(fbResolveLocale(d, 'en'), 'en');
      expect(fbResolveLocale(d, 'EN-gb'), 'en-GB');
      expect(fbResolveLocale(d, 'dv-MV'), 'dv');
      expect(fbResolveLocale(d, 'fr'), 'dv');
      expect(fbResolveLocale(d, null), 'dv');
      expect(fbResolveLocale(d, ''), 'dv');
      expect(fbResolveLocale(def(locales: [UiFbLocale(code: 'en'), UiFbLocale(code: 'en-GB')]), 'en-US'), 'en');
    });

    test('direction', () {
      expect(fbLocaleDir(d, 'dv'), UiFbDir.rtl);
      expect(fbLocaleDir(d, 'en'), UiFbDir.ltr);
      expect(fbLocaleDir(d, 'en-GB'), UiFbDir.rtl);
      expect(fbLocaleDir(null, 'dv'), UiFbDir.ltr); // unknown to the form: falls to its default (en)
      expect(fbDefaultDir('dv'), UiFbDir.rtl);
      expect(fbDefaultDir('ar-SA'), UiFbDir.rtl);
      expect(fbDefaultDir('fr'), UiFbDir.ltr);
    });

    test('names and base locale', () {
      expect(fbBaseLocale('dv-MV'), 'dv');
      expect(fbBaseLocale('EN_gb'), 'en');
      expect(fbLocaleName('dv'), 'ދިވެހި');
      expect(fbLocaleName('pt-BR'), 'Português');
      expect(fbLocaleName('xx'), 'XX');
    });

    test('fbIsLocalized', () {
      expect(fbIsLocalized(loc({'en': 'a'})), isTrue);
      expect(fbIsLocalized(const UiFbText('a')), isFalse);
      expect(fbIsLocalized(null), isFalse);
    });
  });
}
