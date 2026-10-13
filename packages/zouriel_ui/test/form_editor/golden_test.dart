import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../form_renderer/fakes.dart';
import '../helpers.dart';

void main() {
  final sources = [peopleSource().def, coursesSource];

  testWidgets('golden: phone, the sample form on the canvas with a card selected', (tester) async {
    final c = UiFormBuilderController(definition: UiFormDefinition.fromJson(fixture('scholarship.definition.json')));
    await expectThemedGolden(tester, 'builder_phone', (context) => UiFormBuilder(controller: c, optionSources: sources), height: 844);
    c.select(c.def.pages[0].elements[1].id);
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/builder_phone_selected.png'));
  });

  testWidgets('golden: tablet, palette | canvas | inspector', (tester) async {
    final c = UiFormBuilderController(definition: UiFormDefinition.fromJson(fixture('scholarship.definition.json')));
    c.select(c.def.pages[0].elements[1].id);
    await expectThemedGolden(tester, 'builder_tablet', (context) => UiFormBuilder(controller: c, optionSources: sources), width: 1180, height: 820);
  });

  testWidgets('golden: phone, settings sheet opened by holding a card; the Add sheet', (tester) async {
    final c = UiFormBuilderController(definition: UiFormDefinition.fromJson(fixture('scholarship.definition.json')));
    await expectThemedGolden(tester, 'builder_phone_start', (context) => UiFormBuilder(controller: c, optionSources: sources), height: 844);
    await tester.longPress(find.text('Preferred name').first);
    await tester.pumpAndSettle();
    await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/builder_phone_sheet.png'));
    for (final s in tester.stateList<UiFormBuilderState>(find.byType(UiFormBuilder))) {
      s.controller.select(null);
    }
    await tester.pumpAndSettle();
    for (final sheet in tester.widgetList<UiBottomSheet>(find.byType(UiBottomSheet)).where((s) => s.title != 'Add a field').toList()) {
      sheet.onSnapChanged!(0);
    }
    await tester.pumpAndSettle();
    for (final e in find.text('Add field').evaluate().toList()) {
      await tester.tap(find.byWidget(e.widget).first, warnIfMissed: false);
    }
    await tester.pumpAndSettle();
    await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/builder_phone_add.png'));
  });

  testWidgets('golden: inspector Logic and Checks tabs', (tester) async {
    final c = UiFormBuilderController(definition: UiFormDefinition.fromJson(fixture('scholarship.definition.json')))..optionSourceDefs = sources;
    final school = c.def.pages[0].elements.firstWhere((e) => e is UiFbField && e.label.startsWith('School'));
    c.select(school.id);
    await expectThemedGolden(tester, 'inspector_settings_text', (context) => UiFbBuilderScope(controller: c, child: const UiFbInspector()), height: 900);
    for (final e in find.text('Logic').evaluate().toList()) {
      await tester.tap(find.byWidget(e.widget).first, warnIfMissed: false);
    }
    await tester.pumpAndSettle();
    await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/inspector_logic.png'));
    for (final e in find.text('Checks').evaluate().toList()) {
      await tester.tap(find.byWidget(e.widget).first, warnIfMissed: false);
    }
    await tester.pumpAndSettle();
    await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/inspector_checks.png'));
  });

  testWidgets('golden: phone Logic view and Preview', (tester) async {
    final c = UiFormBuilderController(definition: UiFormDefinition.fromJson(fixture('scholarship.definition.json')));
    await expectThemedGolden(tester, 'builder_phone_build', (context) => UiFormBuilder(controller: c, optionSources: sources), height: 844);
    for (final e in find.text('Logic').evaluate().toList()) {
      await tester.tap(find.byWidget(e.widget).first, warnIfMissed: false);
    }
    await tester.pumpAndSettle();
    await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/builder_phone_logic.png'));
    for (final e in find.text('Preview').evaluate().toList()) {
      await tester.tap(find.byWidget(e.widget).first, warnIfMissed: false);
    }
    await tester.pumpAndSettle();
    await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/builder_phone_preview.png'));
  });

  for (final (name, label) in const [('options', 'Are you studying'), ('calc', 'Age'), ('source', 'Your student record')]) {
    testWidgets('golden: inspector settings, $name', (tester) async {
      final c = UiFormBuilderController(definition: UiFormDefinition.fromJson(fixture('scholarship.definition.json')))..optionSourceDefs = sources;
      final el = c.def.pages[0].elements.firstWhere((e) => e is UiFbField && e.label.startsWith(label));
      c.select(el.id);
      await expectThemedGolden(tester, 'inspector_$name', (context) => UiFbBuilderScope(controller: c, child: const UiFbInspector()), height: 1400);
    });
  }
}
