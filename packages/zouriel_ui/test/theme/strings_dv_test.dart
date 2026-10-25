import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

// 0.46.0: built-in Dhivehi strings, a runtime language switch, Dhivehi date names and the app's
// Thaana font reaching every library text.

final _thaana = RegExp('[\u0780-\u07BF]');

Set<String> _placeholders(String s) => {for (final m in RegExp(r'\{(\w+)\}').allMatches(s)) m[1]!};

void main() {
  group('UiStrings.dv', () {
    test('has every key, in Thaana, with the same placeholders as English', () {
      const en = UiStrings();
      final dv = UiStrings.dv.toMap();
      expect(dv.keys, en.toMap().keys);
      for (final MapEntry(:key, :value) in en.toMap().entries) {
        final d = dv[key]!;
        expect(d.trim(), isNotEmpty, reason: key);
        expect(d, isNot(value), reason: '$key is still English');
        expect(_thaana.hasMatch(d), isTrue, reason: '$key has no Thaana');
        expect(_placeholders(d), _placeholders(value), reason: '$key placeholders');
      }
    });

    test('has Dhivehi dates: 12 months, 7 days Sunday first, Sunday first column, day-month-year', () {
      const dv = UiStrings.dv;
      expect(dv.locale, 'dv');
      expect(dv.months, hasLength(12));
      expect(dv.monthsShort, hasLength(12));
      expect(dv.weekdays, hasLength(7));
      expect(dv.weekdaysShort, hasLength(7));
      expect(dv.months.first, 'ޖަނަވަރީ');
      expect(dv.months.last, 'ޑިސެމްބަރު');
      expect(dv.weekdays.first, 'އާދިއްތަ');
      expect(dv.weekdays.last, 'ހޮނިހިރު');
      expect([...dv.months, ...dv.weekdays, ...dv.weekdaysShort].every(_thaana.hasMatch), isTrue);
      expect(dv.firstDayOfWeek, 0);
      expect(_placeholders(dv.dateFormat), {'d', 'month', 'y'});
      expect(_placeholders(dv.monthYearFormat), {'month', 'y'});
    });

    test('copyWith replaces only what it is given; == compares contents', () {
      final custom = UiStrings.dv.copyWith(close: 'X');
      expect(custom.close, 'X');
      expect(custom.dismiss, UiStrings.dv.dismiss);
      expect(custom.months, UiStrings.dv.months);
      expect(UiStrings.dv.copyWith(), UiStrings.dv);
      expect(custom == UiStrings.dv, isFalse);
    });

    test('uiFormatString fills placeholders and leaves unknown ones', () {
      expect(uiFormatString('Page {n} of {total}', {'n': 2, 'total': 9}), 'Page 2 of 9');
      expect(uiFormatString('{label} ނައްތާލާ', {'label': 'މާލެ'}), 'މާލެ ނައްތާލާ');
      expect(uiFormatString('{n} {missing}', {'n': 1}), '1 {missing}');
    });
  });

  testWidgets('the language switches at runtime: UiThemeController.setStrings rebuilds what reads uiStrings', (tester) async {
    final c = UiThemeController();
    addTearDown(c.dispose);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(UiApp(
      controller: c,
      home: const Column(mainAxisSize: MainAxisSize.min, children: [
        UiSpinner(),
        UiEmptyState(),
        SizedBox(width: 300, child: UiSearchInput()),
      ]),
    ));
    expect(find.bySemanticsLabel('Loading…'), findsOneWidget);
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('Search…'), findsOneWidget);

    c.setStrings(UiStrings.dv);
    await tester.pump();
    expect(find.bySemanticsLabel(UiStrings.dv.loading), findsOneWidget);
    expect(find.text(UiStrings.dv.emptyHeading), findsOneWidget);
    expect(find.text(UiStrings.dv.searchPlaceholder), findsOneWidget);
    expect(find.text('Nothing here yet'), findsNothing);

    c.setStrings(const UiStrings());
    await tester.pump();
    expect(find.text('Nothing here yet'), findsOneWidget);
    handle.dispose();
  });

  group('date names', () {
    Future<void> calendar(WidgetTester tester, UiStrings strings, {String value = '2026-10-14'}) async {
      tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UiApp(
        textDirection: TextDirection.ltr,
        config: UiConfig(strings: strings),
        home: Align(alignment: Alignment.topLeft, child: UiCalendar(value: value, onChanged: (_) {})),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('Dhivehi month heading and weekday columns, Sunday first', (tester) async {
      await calendar(tester, UiStrings.dv);
      expect(find.text('އޮކްޓޫބަރު'), findsOneWidget);
      final heads = UiStrings.dv.weekdaysShort;
      final xs = [for (final h in heads) tester.getRect(find.text(h)).left];
      for (var i = 1; i < 7; i++) {
        expect(xs[i], greaterThan(xs[i - 1]), reason: 'column ${heads[i]} after ${heads[i - 1]}');
      }
      // 1 October 2026 was a Thursday: column 4 from Sunday.
      final cell = tester.getRect(find.text(heads[1])).left - tester.getRect(find.text(heads[0])).left;
      expect(tester.getRect(find.text('1')).center.dx, moreOrLessEquals(tester.getRect(find.text(heads[0])).center.dx + 4 * cell, epsilon: 1));
    });

    testWidgets('firstDayOfWeek moves the columns and the first day', (tester) async {
      await calendar(tester, UiStrings.dv.copyWith(firstDayOfWeek: 6));
      final heads = UiStrings.dv.weekdaysShort;
      final sat = tester.getRect(find.text(heads[6]));
      final sun = tester.getRect(find.text(heads[0]));
      expect(sat.left, lessThan(sun.left), reason: 'Saturday is the first column');
      final cell = sun.left - sat.left;
      // Thursday is five columns from Saturday.
      expect(tester.getRect(find.text('1')).center.dx, moreOrLessEquals(sat.center.dx + 5 * cell, epsilon: 1));
    });

    testWidgets('locale from UiStrings.locale: en_GB starts on Monday', (tester) async {
      await initializeDateFormatting('en_GB');
      await calendar(tester, const UiStrings(locale: 'en_GB'));
      expect(tester.getRect(find.text('Mon')).left, lessThan(tester.getRect(find.text('Sun')).left));
      await calendar(tester, const UiStrings());
      expect(tester.getRect(find.text('Sun')).left, lessThan(tester.getRect(find.text('Mon')).left), reason: 'en_US default: Sunday');
    });

    testWidgets('UiDatePicker shows a Dhivehi date in the field', (tester) async {
      await tester.pumpWidget(UiApp(
        config: const UiConfig(strings: UiStrings.dv),
        home: Align(alignment: Alignment.topLeft, child: SizedBox(width: 300, child: UiDatePicker(value: '2026-01-13', onChanged: (_) {}))),
      ));
      expect(find.text('13 ޖަނަވަރީ 2026'), findsOneWidget);
    });
  });

  group('UiConfig.fontFamilyFallback', () {
    List<String>? fallbackOf(WidgetTester tester, Finder text) {
      final p = tester.renderObject<RenderParagraph>(find.descendant(of: text, matching: find.byType(RichText)).first);
      final styles = <TextStyle>[];
      p.text.visitChildren((span) {
        if (span.style != null) styles.add(span.style!);
        return true;
      });
      return styles.map((s) => s.fontFamilyFallback).firstWhere((f) => f != null, orElse: () => null);
    }

    testWidgets('reaches buttons, inputs, toasts, dialogs, tabs and chips, unprefixed', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      final toasts = UiToastController();
      addTearDown(toasts.dispose);
      const font = ['Faruma', 'Noto Sans Thaana'];
      await tester.pumpWidget(UiApp(
        config: const UiConfig(fontFamilyFallback: font, strings: UiStrings.dv),
        builder: (context, child) => UiToastHost(controller: toasts, child: child!),
        home: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            UiButton(label: 'ބަލާ', onPressed: () {}),
            const SizedBox(width: 300, child: UiInput(value: 'ޢާއިޝާ')),
            const UiChip(label: 'މާލެ'),
            const SizedBox(width: 360, height: 80, child: UiTabs(tabs: [UiTab(label: 'ޑޮކްޓަރުން', child: SizedBox()), UiTab(label: 'ނަރުހުން', child: SizedBox())])),
            const SizedBox(width: 340, child: UiModal(title: 'ބުކިންގ', child: Text('ބުކިންގ ކަށަވަރުކުރޭ'))),
            UiGoogleSignInButton(onPressed: () {}),
          ]),
        ),
      ));
      toasts.info('ބުކިންގ ބަލައިގަނެވިއްޖެ', duration: Duration.zero);
      await tester.pumpAndSettle();

      for (final label in ['ބަލާ', 'މާލެ', 'ޑޮކްޓަރުން', 'ބުކިންގ', 'ބުކިންގ ކަށަވަރުކުރޭ', 'ބުކިންގ ބަލައިގަނެވިއްޖެ', UiStrings.dv.googleSignIn]) {
        final f = fallbackOf(tester, find.text(label).first);
        expect(f, isNotNull, reason: label);
        expect(f, containsAllInOrder(font), reason: '$label: $f');
      }
      final editable = tester.state<EditableTextState>(find.descendant(of: find.byType(UiInput), matching: find.byType(EditableText))).renderEditable;
      expect(editable.text?.style?.fontFamilyFallback, containsAllInOrder(font), reason: 'input text');
    });

    testWidgets('the theme font keeps its bundled family', (tester) async {
      await tester.pumpWidget(UiApp(config: const UiConfig(fontFamilyFallback: ['Faruma']), home: const Text('Hi')));
      final style = UiTheme.of(tester.element(find.text('Hi'))).typography.body;
      expect(style.fontFamily, 'packages/zouriel_ui/Roboto');
      expect(style.fontFamilyFallback, ['Faruma']);
    });
  });
}
