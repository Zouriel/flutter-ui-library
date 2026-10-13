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

  testWidgets('golden: tablet width, edit mode on the household page (grid columns, a repeat entry)', (tester) async {
    await expectThemedGolden(
      tester,
      'renderer_edit_tablet',
      (context) => UiFormRenderer(
        definition: fixture('scholarship.definition.json')!,
        data: fixtureMap('scholarship.answers.json'),
        optionSources: sources,
        today: () => '2026-10-13',
      ),
      width: 720,
      height: 1000,
    );
    for (final b in find.text('Continue').evaluate().toList()) {
      await tester.tap(find.byWidget(b.widget).first);
    }
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/renderer_edit_tablet_household.png'));
  });

  testWidgets('golden: label inside, error inside, label left, and the change list', (tester) async {
    final def = form([
      f('a', 'text', {'label': 'Given name', 'layout': {'labelPlacement': 'inside'}}),
      f('b', 'text', {'label': 'Family name', 'required': true, 'layout': {'labelPlacement': 'inside', 'errorPlacement': 'inside'}}),
      f('c', 'textarea', {'label': 'Notes', 'layout': {'labelPlacement': 'inside'}}),
      f('d', 'email', {'label': 'Email', 'help': 'We reply here.', 'layout': {'labelPlacement': 'left'}}),
    ], settings: {'requiredMarker': 'optional'});
    await expectThemedGolden(
      tester,
      'renderer_placements',
      (context) => UiFormRenderer(definition: def, data: const {'a': 'Aminath', 'd': 'a@b.mv'}),
      width: 600,
      height: 640,
    );
    for (final r in tester.stateList<UiFormRendererState>(find.byType(UiFormRenderer))) {
      r.engine.setValue('d', null, 'new@b.mv');
      r.submit();
    }
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('1 change').first);
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(UiApp), matchesGoldenFile('goldens/renderer_placements_errors.png'));
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
