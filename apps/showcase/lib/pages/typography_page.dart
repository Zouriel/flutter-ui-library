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
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
            const UiText('Heading 1', variant: UiTextVariant.h1, heading: false),
            const UiText('Heading 2', variant: UiTextVariant.h2, heading: false),
            const UiText('Heading 3', variant: UiTextVariant.h3, heading: false),
            const UiText('Heading 4', variant: UiTextVariant.h4, heading: false),
            const UiText('Heading 5', variant: UiTextVariant.h5, heading: false),
            const UiText('Heading 6', variant: UiTextVariant.h6, heading: false),
            const UiText('Body — the default paragraph style.'),
            const UiText('A small muted caption.', variant: UiTextVariant.caption),
            const UiText('Label', variant: UiTextVariant.label),
            const UiText('inline code', variant: UiTextVariant.code),
            const UiText('A blockquote variant for pull quotes.', variant: UiTextVariant.quote),
            const SizedBox(width: 200, child: UiText('A long label that truncates cleanly with an ellipsis', variant: UiTextVariant.label, truncate: true)),
            const SizedBox(width: double.infinity, child: UiText('Centered muted body copy.', tone: UiTextTone.muted, textAlign: TextAlign.center)),
            Container(
              padding: EdgeInsets.all(t.space3),
              decoration: BoxDecoration(color: t.mediaBg, borderRadius: BorderRadius.circular(t.radius)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: [
                UiText('On-media heading', variant: UiTextVariant.h4, heading: false, tone: UiTextTone.onMedia),
                UiText('On-media caption over dark photography', variant: UiTextVariant.caption, tone: UiTextTone.onMedia),
              ]),
            ),
          ]),
          code: "UiText('Title', variant: UiTextVariant.h1)\nUiText('Clipped', variant: UiTextVariant.label, truncate: true)\nUiText('Hero', variant: UiTextVariant.h2, tone: UiTextTone.onMedia)",
          api: const [
            ApiRow('text', 'String', 'The text.'),
            ApiRow('variant', 'UiTextVariant', 'h1–h6, body, caption, label, code, quote.', def: 'body'),
            ApiRow('heading', 'bool?', 'Override the heading role (defaults to h1–h6).'),
            ApiRow('truncate', 'bool', 'Clip to one line with ellipsis.', def: 'false'),
            ApiRow('tone', 'UiTextTone', 'standard, muted, or onMedia.', def: 'standard'),
            ApiRow('textAlign', 'TextAlign?', 'Logical text alignment.'),
            ApiRow('fontFamily', 'String?', 'Font override.'),
            ApiRow('color', 'Color?', 'Colour override.'),
          ],
          shapes: 'enum UiTextVariant { h1, h2, h3, h4, h5, h6, body, caption, label, code, quote }',
        ),
      ],
    );
  }
}
