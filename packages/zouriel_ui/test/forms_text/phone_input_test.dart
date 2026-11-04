import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'overlay_helpers.dart';

Finder get _number => find.descendant(of: find.byKey(const ValueKey('ui-phone-number')), matching: find.byType(EditableText));
Finder get _search => find.descendant(of: find.byKey(const ValueKey('ui-phone-search')), matching: find.byType(EditableText));
Finder get _trigger => find.byKey(const ValueKey('ui-phone-trigger'));
String _dial(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('ui-phone-dial'))).data!;

/// A controlled phone input that records what it sends.
class _Host extends StatefulWidget {
  const _Host({this.initial, this.defaultCountry, required this.log, this.countries});
  final String? initial;
  final String? defaultCountry;
  final List<String?> log;
  final List<String>? countries;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String? value = widget.initial;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 340,
        child: UiPhoneInput(
          value: value,
          defaultCountry: widget.defaultCountry,
          onChanged: (v) {
            widget.log.add(v);
            setState(() => value = v);
          },
          onCountryChanged: widget.countries?.add,
        ),
      );
}

void main() {
  group('country from a value', () {
    ({String iso, String national})? split(String v, [String? def]) {
      final r = uiPhoneSplit(uiPhoneInternationalDigits(v), defaultCountry: def);
      return r == null ? null : (iso: r.country.iso2, national: r.national);
    }

    test('longest dial code, leading digits, default country, main country', () {
      expect(split('+447700900123'), (iso: 'GB', national: '7700900123'));
      expect(split('+12684641234'), (iso: 'AG', national: '2684641234'));
      expect(split('+14165550123', 'CA'), (iso: 'CA', national: '4165550123'));
      expect(split('+14165550123'), (iso: 'US', national: '4165550123'));
      expect(split('+79161234567'), (iso: 'RU', national: '9161234567'));
      expect(split('+77012345678'), (iso: 'KZ', national: '7012345678'));
      expect(split('+9607771234'), (iso: 'MV', national: '7771234'));
      expect(split('+0044 1'), isNull);
      expect(split('0044 7700 900123'), (iso: 'GB', national: '7700900123'));
    });

    test('the data: 245 countries, one main per shared code, names intact', () {
      expect(uiPhoneCountries, hasLength(245));
      final mains = <String, int>{};
      for (final c in uiPhoneCountries) {
        if (c.main) mains[c.dial] = (mains[c.dial] ?? 0) + 1;
      }
      expect(mains.values.every((n) => n == 1), isTrue);
      expect({for (final c in uiPhoneCountries) c.dial}.length, mains.length);
      // CLDR names keep their accents and typographic apostrophe.
      expect(uiPhoneCountry('CI')!.name, 'C\u00f4te d\u2019Ivoire');
      expect(uiPhoneCountry('gb')!.name, 'United Kingdom');
      expect(uiPhoneCountry('XX'), isNull);
    });

    test('the flag is built from regional indicators', () {
      expect(uiPhoneFlag('GB').runes.toList(), [0x1F1EC, 0x1F1E7]);
      expect(uiPhoneCountry('mv')!.flag.runes.toList(), [0x1F1F2, 0x1F1FB]);
    });
  });

  group('output', () {
    String? e164(String iso, String text) => uiPhoneE164(uiPhoneCountry(iso)!, text);

    test('punctuation dropped, trunk stripped, Italy keeps its 0', () {
      expect(e164('GB', '07700 900-123'), '+447700900123');
      expect(e164('GB', '(7700) 900.123'), '+447700900123');
      expect(e164('HU', '(06) 1 234 5678'), '+3612345678');
      expect(e164('IT', '06 1234 5678'), '+390612345678');
      expect(e164('US', '1 212 555 0123'), '+12125550123');
      expect(e164('US', '1 (212) 555-0123'), '+12125550123');
      expect(e164('US', '212/555/0123'), '+12125550123');
      expect(e164('RU', '8 916 123 45 67'), '+79161234567');
      // A non-0 trunk stays unless a full 10 digits follow it.
      expect(e164('RU', '800 123 45 67'), '+78001234567');
      expect(e164('MV', '777 1234'), '+9607771234');
      expect(e164('GB', ''), isNull);
      expect(e164('GB', ' - '), isNull);
    });

    test('search matches name, ISO code and dial code with or without +', () {
      List<String> isos(String q) => [for (final c in uiPhoneSearch(q)) c.iso2];
      expect(isos('kingdom'), ['GB']);
      expect(isos('United K'), ['GB']);
      expect(isos('mv'), ['MV']);
      expect(isos('+960'), ['MV']);
      expect(isos('960'), ['MV']);
      expect(isos('+44'), containsAll(['GB', 'GG', 'IM', 'JE']));
      expect(isos('44'), isos('+44'));
      expect(isos(''), hasLength(245));
      expect(isos('zzzz'), isEmpty);
    });
  });

  group('widget', () {
    testWidgets('a value shows its country and the national digits as stored', (tester) async {
      final log = <String?>[];
      await pumpUi(tester, _Host(initial: '+447700900123', log: log));
      expect(_dial(tester), '+44');
      expect(tester.widget<EditableText>(_number).controller.text, '7700900123');
      expect(log, isEmpty);
    });

    testWidgets('typing sends E.164; clearing sends null', (tester) async {
      final log = <String?>[];
      await pumpUi(tester, _Host(defaultCountry: 'GB', log: log));
      expect(_dial(tester), '+44');
      await tester.enterText(_number, '07700 900-123');
      expect(log.last, '+447700900123');
      // What was typed stays as typed.
      expect(tester.widget<EditableText>(_number).controller.text, '07700 900-123');
      await tester.enterText(_number, '');
      expect(log.last, isNull);
    });

    testWidgets('typing +44… or 0044… switches the country and keeps the national part', (tester) async {
      final log = <String?>[];
      final countries = <String>[];
      await pumpUi(tester, _Host(defaultCountry: 'US', log: log, countries: countries));
      expect(_dial(tester), '+1');
      await tester.enterText(_number, '+44 7700 900123');
      await tester.pump();
      expect(_dial(tester), '+44');
      expect(countries, ['GB']);
      expect(log.last, '+447700900123');
      expect(tester.widget<EditableText>(_number).controller.text, '7700900123');
      await tester.enterText(_number, '00960 777 1234');
      await tester.pump();
      expect(_dial(tester), '+960');
      expect(log.last, '+9607771234');
    });

    testWidgets('no default country: a globe and "+", and null whatever is typed', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <String?>[];
      await pumpUi(tester, _Host(log: log));
      expect(find.byKey(const ValueKey('ui-phone-globe')), findsOneWidget);
      expect(find.byKey(const ValueKey('ui-phone-flag')), findsNothing);
      expect(_dial(tester), '+');
      expect(find.bySemanticsLabel('Country'), findsOneWidget);
      await tester.enterText(_number, '7700 900123');
      expect(log.last, isNull);
      handle.dispose();
    });

    testWidgets('names: "Country: United Kingdom +44" and "Phone number"', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, _Host(defaultCountry: 'GB', log: []));
      expect(find.bySemanticsLabel('Country: United Kingdom +44'), findsOneWidget);
      expect(find.bySemanticsLabel('Phone number'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('the list: search by name, ISO and dial; choosing sets the country, emits, focuses the number', (tester) async {
      final log = <String?>[];
      final countries = <String>[];
      await pumpUi(tester, _Host(initial: '+447700900123', log: log, countries: countries));
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      expect(_search, findsOneWidget);
      expect(tester.widget<EditableText>(_search).focusNode.hasFocus, isTrue);
      // Opens on the chosen country.
      expect(find.byKey(const ValueKey('ui-phone-option-GB')), findsOneWidget);
      await tester.enterText(_search, '+960');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ui-phone-option-MV')), findsOneWidget);
      expect(find.byKey(const ValueKey('ui-phone-option-GB')), findsNothing);
      await tester.enterText(_search, 'maldiv');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ui-phone-option-MV')));
      await tester.pumpAndSettle();
      expect(_search, findsNothing);
      expect(_dial(tester), '+960');
      expect(countries, ['MV']);
      expect(log.last, '+9607700900123');
      expect(tester.widget<EditableText>(_number).focusNode.hasFocus, isTrue);
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      await tester.enterText(_search, 'gb');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ui-phone-option-GB')), findsOneWidget);
      expect(find.byKey(const ValueKey('ui-phone-option-MV')), findsNothing);
    });

    testWidgets('keyboard: arrows move, Enter chooses, Escape closes back to the button', (tester) async {
      final log = <String?>[];
      final countries = <String>[];
      await pumpUi(tester, _Host(defaultCountry: 'GB', log: log, countries: countries));
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      await tester.enterText(_search, '+44');
      await tester.pumpAndSettle();
      // Guernsey, Isle of Man, Jersey, United Kingdom: the second is the Isle of Man.
      expect([for (final c in uiPhoneSearch('+44')) c.iso2], ['GG', 'IM', 'JE', 'GB']);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_search, findsNothing);
      expect(_dial(tester), '+44');
      await tester.enterText(_number, '1624 123456');
      expect(log.last, '+441624123456');
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      expect(_search, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_search, findsNothing);
      expect(countries, ['IM']);
      expect(tester.widget<EditableText>(_number).focusNode.hasFocus, isFalse);
    });

    testWidgets('inside a UiFormField: the label names the number; the error turns it red', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, SizedBox(width: 340, child: UiFormField(label: 'Mobile', error: 'Check the number', child: UiPhoneInput(defaultCountry: 'GB', onChanged: (_) {}))));
      expect(find.bySemanticsLabel(RegExp(r'^Mobile')), findsWidgets);
      expect(find.bySemanticsLabel('Phone number'), findsNothing);
      final frame = tester.widget<UiFieldFrame>(find.byType(UiFieldFrame).first);
      expect(frame.invalid, isTrue);
      handle.dispose();
    });

    testWidgets('validated in a Form', (tester) async {
      final form = GlobalKey<FormState>();
      await pumpUi(
        tester,
        SizedBox(
          width: 340,
          child: Form(
            key: form,
            child: UiFormField<String>.validated(
              label: 'Mobile',
              required: true,
              builder: (field) => UiPhoneInput(value: field.value, defaultCountry: 'GB', onChanged: field.didChange),
            ),
          ),
        ),
      );
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Mobile is required'), findsOneWidget);
      await tester.enterText(_number, '07700900123');
      expect(form.currentState!.validate(), isTrue);
    });

    testWidgets('disabled: no list, no typing, half opacity', (tester) async {
      await pumpUi(tester, const SizedBox(width: 340, child: UiPhoneInput(defaultCountry: 'GB', enabled: false)));
      await tester.tap(_trigger, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_search, findsNothing);
      expect(tester.widget<UiFieldFrame>(find.byType(UiFieldFrame)).enabled, isFalse);
    });

    testWidgets('a new value from outside replaces the field; the default only moves an empty field', (tester) async {
      Widget build(String? v, String? def) => SizedBox(width: 340, child: UiPhoneInput(value: v, defaultCountry: def, onChanged: (_) {}));
      await pumpUi(tester, build(null, 'GB'));
      expect(_dial(tester), '+44');
      await pumpUi(tester, build(null, 'MV'));
      expect(_dial(tester), '+960');
      await pumpUi(tester, build('+12684641234', 'MV'));
      expect(_dial(tester), '+1');
      expect(tester.widget<EditableText>(_number).controller.text, '2684641234');
    });

    testWidgets('golden: collapsed with a country, without one, invalid', (tester) async {
      await expectThemedGolden(tester, 'phone_input', height: 200, (context) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: const [
          UiPhoneInput(value: '+447700900123'),
          UiPhoneInput(placeholder: 'Phone number'),
          UiPhoneInput(defaultCountry: 'MV', invalid: true, value: '+9607771234'),
        ]);
      });
    });

    testWidgets('golden: the open list', (tester) async {
      await expectOverlayGolden(
        tester,
        'phone_input_open',
        (context) => const Align(alignment: Alignment.topLeft, child: SizedBox(width: 358, child: UiPhoneInput(defaultCountry: 'GB'))),
        open: () async {
          await tester.tap(_trigger);
          await tester.pumpAndSettle();
        },
      );
    });
  });
}
