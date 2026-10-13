import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'overlay_helpers.dart';

void main() {
  testWidgets('golden: text fields', (tester) async {
    await expectThemedGolden(tester, 'text_fields', height: 800, (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        const UiFormField(label: 'Full name', hint: 'As on your passport', required: true, child: UiInput(value: 'Ada Lovelace')),
        const UiFormField(label: 'Email', error: 'Enter an email address', child: UiInput(value: 'ada@', type: UiInputType.email)),
        const UiInput(placeholder: 'Placeholder text', semanticLabel: 'Empty'),
        const Row(spacing: 8, children: [
          Expanded(child: UiInput(value: 'Small', size: UiSize.sm, semanticLabel: 's')),
          Expanded(child: UiInput(value: 'Large', size: UiSize.lg, semanticLabel: 'l')),
        ]),
        const UiPasswordInput(value: 'hunter2', semanticLabel: 'Password'),
        const UiSearchInput(value: 'grid layout', label: 'Search'),
        const UiTextarea(value: 'A multi-line field\nwith two lines of text.', rows: 3, semanticLabel: 'Bio'),
        const UiNumberInput(value: 24, label: 'W', suffix: 'px'),
        const UiOtpInput(value: '12 4'),
        const Row(spacing: 8, children: [
          Expanded(child: UiTimePicker(value: '14:30', label: 'Time')),
          Expanded(child: UiInput(value: 'Disabled', enabled: false, semanticLabel: 'd')),
        ]),
        UiEditableText(value: 'Click to edit', semanticLabel: 'Title', onChanged: (_) {}),
      ],
    ));
  });

  testWidgets('golden: select open as a font picker', (tester) async {
    await expectOverlayGolden(tester, 'select_font_picker', height: 360, (context) => const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiFormField(
          label: 'Heading font',
          child: UiSelect(
            value: 'Bricolage Grotesque',
            fontPreview: true,
            fontPackage: 'zouriel_ui',
            options: [
              UiSelectOption(label: 'Roboto', value: 'Roboto'),
              UiSelectOption(label: 'Space Grotesk', value: 'Space Grotesk'),
              UiSelectOption(label: 'Bricolage Grotesque', value: 'Bricolage Grotesque'),
              UiSelectOption(label: 'JetBrains Mono', value: 'JetBrains Mono'),
              UiSelectOption(label: 'Unavailable', value: 'Roboto', disabled: true),
            ],
          ),
        ),
      ],
    ), open: () async {
      await tester.tap(find.byType(UiSelect));
      await tester.pump();
    });
  });
}
