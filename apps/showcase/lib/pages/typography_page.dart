import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

class TypographyPage extends StatelessWidget {
  const TypographyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return DocPage(
      eyebrow: 'Getting started',
      title: 'Typography',
      lead: 'The type scale. Headings use the theme\'s display font; everything else the UI font.',
      children: [
        DocSection(
          name: 'Text',
          widget: 'UiText',
          summary: 'Themed text in one of eleven variants. h1–h6 are announced as headings with their level; heading: false keeps the look without the heading role (used here so this page keeps one h1), and heading: true makes any variant a heading. h6 renders upper-case.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: const [
            UiText('Heading 1', variant: UiTextVariant.h1, heading: false),
            UiText('Heading 2', variant: UiTextVariant.h2, heading: false),
            UiText('Heading 3', variant: UiTextVariant.h3, heading: false),
            UiText('Heading 4', variant: UiTextVariant.h4, heading: false),
            UiText('Heading 5', variant: UiTextVariant.h5, heading: false),
            UiText('Heading 6', variant: UiTextVariant.h6, heading: false),
            UiText('Body — the default paragraph style.'),
            UiText('A small muted caption.', variant: UiTextVariant.caption),
            UiText('Label', variant: UiTextVariant.label),
            UiText('inline code', variant: UiTextVariant.code),
            UiText('A blockquote variant for pull quotes.', variant: UiTextVariant.quote),
          ]),
          code: "UiText('Title', variant: UiTextVariant.h1)\nUiText('Big but not a heading', variant: UiTextVariant.h1, heading: false)\nUiText('Muted', variant: UiTextVariant.caption)",
          api: const [
            ApiRow('text', 'String', 'The text.'),
            ApiRow('variant', 'UiTextVariant', 'h1–h6, body, caption, label, code, quote.', def: 'body'),
            ApiRow('heading', 'bool?', 'Override the heading role (defaults to h1–h6).'),
            ApiRow('fontFamily', 'String?', 'Font override.'),
            ApiRow('color', 'Color?', 'Colour override.'),
          ],
          shapes: 'enum UiTextVariant { h1, h2, h3, h4, h5, h6, body, caption, label, code, quote }',
        ),
      ],
    );
  }
}
