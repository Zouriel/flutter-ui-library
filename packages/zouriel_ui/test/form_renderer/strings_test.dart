// The renderer's own words in the form's language, from the built-in tables, the `strings`
// parameter and the app-wide UiFormStringsScope (the web form-strings.spec.ts renderer cases).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fakes.dart';

Map<String, Object?> def(List<UiJson> elements, {bool twoPages = false, UiJson? settings}) => {
  'schemaVersion': 2, 'id': 'f', 'title': 'T', 'defaultLocale': 'en', 'revision': 1,
  'supportedLocales': [{'code': 'en'}, {'code': 'dv'}],
  'settings': ?settings,
  'pages': twoPages
      ? [
          {'id': 'p1', 'title': 'One', 'elements': elements},
          {'id': 'p2', 'title': 'Two', 'elements': [f('z', 'text')]},
        ]
      : [{'id': 'p1', 'elements': elements}],
};

String _today() => '2026-10-13';

class _Host extends StatefulWidget {
  const _Host({super.key, required this.definition, this.locale, this.strings, this.data, this.mode, this.scope});
  final Object definition;
  final String? locale;
  final UiFbStringOverrides? strings;
  final UiJson? data;
  final UiFormMode? mode;
  final UiFbStringOverrides? scope;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String? locale;
  UiFbStringOverrides? strings;
  UiFbStringOverrides? scope;
  @override
  void initState() {
    super.initState();
    locale = widget.locale;
    strings = widget.strings;
    scope = widget.scope;
  }

  void set({String? locale, UiFbStringOverrides? strings, UiFbStringOverrides? scope, bool clear = false}) => setState(() {
    this.locale = locale ?? (clear ? null : this.locale);
    this.strings = strings ?? this.strings;
    this.scope = scope ?? this.scope;
  });

  @override
  Widget build(BuildContext context) {
    Widget child = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: UiFormRenderer(definition: widget.definition, data: widget.data, mode: widget.mode, locale: locale, strings: strings, today: _today),
    );
    if (scope != null) child = UiFormStringsScope(strings: scope!, child: child);
    return SizedBox(width: 390, height: 844, child: child);
  }
}

Future<GlobalKey<_HostState>> _pumpHost(WidgetTester tester, Object definition, {String? locale, UiFbStringOverrides? strings, UiFbStringOverrides? scope, UiJson? data, UiFormMode? mode}) async {
  final key = GlobalKey<_HostState>();
  await pumpUi(tester, _Host(key: key, definition: definition, locale: locale, strings: strings, scope: scope, data: data, mode: mode));
  return key;
}

void main() {
  testWidgets('shows English as before', (tester) async {
    await _pumpHost(tester, def([f('a', 'text', {'required': true})], twoPages: true));
    expect(find.text('Step 1 of 2: One'), findsOneWidget);
    expect(find.widgetWithText(UiButton, 'Continue'), findsOneWidget);
  });

  testWidgets('words buttons, step text and errors in Dhivehi, and re-words a visible error on a language change', (tester) async {
    final host = await _pumpHost(tester, def([f('a', 'text', {'label': {'en': 'A', 'dv': 'އޭ'}, 'required': true})], twoPages: true), locale: 'dv');
    expect(find.text('ފިޔަވަޅު 2 އިން 1: One'), findsOneWidget);
    expect(find.widgetWithText(UiButton, uiFbStringsDv.next), findsOneWidget);
    await tester.tap(find.widgetWithText(UiButton, uiFbStringsDv.next));
    await tester.pumpAndSettle();
    expect(find.text(uiFbStringsDv.problemOne), findsOneWidget);
    expect(find.text('އޭ ފުރިހަމަ ކުރަންޖެހެއެވެ.'), findsWidgets);
    host.currentState!.set(locale: 'en');
    await tester.pumpAndSettle();
    expect(find.text('There is a problem'), findsOneWidget);
    expect(find.text('A is required.'), findsWidgets);
  });

  testWidgets('shows the last page words and Yes/No in Dhivehi', (tester) async {
    await _pumpHost(tester, def([f('c', 'checkbox', {'label': 'C'}), f('t', 'toggle', {'label': 'T'})]),
        locale: 'dv', data: {'c': true, 't': false}, mode: UiFormMode.view);
    expect(find.text(uiFbStringsDv.yes), findsOneWidget);
    expect(find.text(uiFbStringsDv.no), findsOneWidget);
    await _pumpHost(tester, def([f('a', 'text')]), locale: 'dv');
    expect(find.widgetWithText(UiButton, uiFbStringsDv.submit), findsOneWidget);
    await _pumpHost(tester, def([f('a', 'text')]), locale: 'dv', data: {'a': 'x'});
    expect(find.widgetWithText(UiButton, uiFbStringsDv.saveChanges), findsOneWidget);
    expect(find.text(uiFbStringsDv.noChanges), findsOneWidget);
  });

  testWidgets('lets a form-authored label win over the built-in word', (tester) async {
    await _pumpHost(tester, def([f('a', 'text')], settings: {'submitLabel': {'en': 'Send', 'dv': 'ފޮނުވާ'}}), locale: 'dv');
    expect(find.widgetWithText(UiButton, 'ފޮނުވާ'), findsOneWidget);
  });

  testWidgets('takes overrides from the parameter', (tester) async {
    final host = await _pumpHost(tester, def([f('a', 'text')]), strings: {'en': {'submit': 'Go'}});
    expect(find.widgetWithText(UiButton, 'Go'), findsOneWidget);
    host.currentState!.set(strings: {'en': {'submit': 'Send now'}});
    await tester.pumpAndSettle();
    expect(find.widgetWithText(UiButton, 'Send now'), findsOneWidget);
  });

  testWidgets('takes overrides from the app-wide scope, and the parameter wins key by key', (tester) async {
    final host = await _pumpHost(tester, def([f('a', 'text')], twoPages: true), scope: {'en': {'next': 'From app', 'back': 'Retour'}});
    expect(find.widgetWithText(UiButton, 'From app'), findsOneWidget);
    host.currentState!.set(strings: {'en': {'next': 'From parameter'}});
    await tester.pumpAndSettle();
    expect(find.widgetWithText(UiButton, 'From parameter'), findsOneWidget);
    host.currentState!.set(scope: {'en': {'next': 'Changed in app'}});
    await tester.pumpAndSettle();
    expect(find.widgetWithText(UiButton, 'From parameter'), findsOneWidget);
    // The scope's other key reaches the second page.
    await tester.tap(find.widgetWithText(UiButton, 'From parameter'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(UiButton, 'Back'), findsOneWidget);
  });

  testWidgets('words the placeholders of the controls and the repeat words in Dhivehi', (tester) async {
    await _pumpHost(
      tester,
      def([
        f('s', 'select', {'options': [{'id': 'o', 'value': 'x', 'label': 'X'}]}),
        {'kind': 'group', 'id': 'g', 'key': 'g', 'repeat': {'min': 0}, 'elements': [f('n', 'text')]},
      ]),
      locale: 'dv',
    );
    expect(find.text(uiFbStringsDv.choose), findsOneWidget);
    expect(find.text('އެންޓްރީ 1'), findsWidgets);
    expect(find.widgetWithText(UiButton, uiFbStringsDv.addAnother), findsOneWidget);
  });

  testWidgets('the source picker words its placeholder and status in the strings it is given', (tester) async {
    final src = peopleSource();
    await pumpUi(tester, SizedBox(width: 340, child: UiFbSourcePicker(source: src.def, label: 'Student', strings: uiFbStringsDv)));
    expect(find.text(uiFbStringsDv.search), findsOneWidget);
    await pumpUi(tester, SizedBox(width: 340, child: UiFbSourcePicker(source: src.def, label: 'Student')));
    expect(find.text('Search…'), findsOneWidget);
  });

  testWidgets('a sourced field in a Dhivehi form says "search {name}" in Dhivehi', (tester) async {
    final src = peopleSource();
    final d = def([f('s', 'select', {'source': {'type': 'students'}})]);
    await pumpUi(tester, SizedBox(width: 390, height: 844, child: UiFormRenderer(definition: d, locale: 'dv', optionSources: [src.def], today: _today)));
    expect(find.text(fbFormat(uiFbStringsDv.searchSource, {'name': 'students'})), findsOneWidget);
  });

  testWidgets('the file drop area keeps the library English words, and takes the form words in Dhivehi', (tester) async {
    final d = def([f('u', 'file')]);
    await pumpUi(tester, SizedBox(width: 390, height: 844, child: UiFormRenderer(definition: d, today: _today)));
    expect(find.textContaining(uiFbStringsEn.fileUploadLabel), findsNothing);
    await pumpUi(tester, SizedBox(width: 390, height: 844, child: UiFormRenderer(definition: d, locale: 'dv', today: _today)));
    expect(find.textContaining(uiFbStringsDv.fileUploadLabel), findsOneWidget);
  });
}
