import 'package:flutter/widgets.dart';

import '../docs/doc.dart';
import 'forms_choice_sections.dart';
import 'forms_text_sections.dart';

/// Form controls: text-entry and picker sections, then choice controls (two ports share this page).
class FormsPage extends StatelessWidget {
  const FormsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocPage(
      eyebrow: 'Components',
      title: 'Form controls',
      lead: 'Inputs, pickers and choice controls. Each control takes a value and onChanged, can be disabled, and works inside a form with validation.',
      children: [FormsTextSections(), FormsChoiceSections()],
    );
  }
}
