import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'fakes.dart';

void main() {
  final sources = [peopleSource().def, coursesSource];

  testWidgets('golden: the sample form, first page, after a failed Continue', (tester) async {
    await expectThemedGolden(
      tester,
      'renderer_fill',
      (context) => UiFormRenderer(definition: fixture('scholarship.definition.json')!, optionSources: sources, today: () => '2026-10-13'),
      height: 1800,
    );
    // Continue with nothing filled in: the summary and the field errors.
    for (final b in find.text('Continue').evaluate().toList()) {
      await tester.tap(find.byWidget(b.widget).first);
    }
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/renderer_fill_errors.png'));
  });

  testWidgets('golden: saved answers in view mode', (tester) async {
    await expectThemedGolden(
      tester,
      'renderer_view',
      (context) => UiFormRenderer(
        definition: fixture('scholarship.definition.json')!,
        data: fixtureMap('scholarship.answers.json'),
        mode: UiFormMode.view,
        optionSources: sources,
        today: () => '2026-10-13',
      ),
      height: 1900,
    );
  });
}
