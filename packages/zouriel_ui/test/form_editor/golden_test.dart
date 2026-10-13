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
}
