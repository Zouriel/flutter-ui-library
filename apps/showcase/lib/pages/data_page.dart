import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';
import 'navdata_sections.dart';

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  List<String> _tags = ['angular', 'flutter', 'design'];
  int _cardTaps = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return DocPage(
      eyebrow: 'Components',
      title: 'Data display',
      lead: 'Badges, chips, avatars, cards, dividers, tables, lists, trees, timelines and more.',
      children: [
        DocSection(
          name: 'Badge',
          widget: 'UiBadge',
          summary: 'A small status or count label. Neutral is outlined; the other tones are solid. dot draws an 8px dot with no text; give it a semanticLabel.',
          demo: Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: const [
            UiBadge(label: 'Neutral'),
            UiBadge(label: 'New', tone: UiStatus.primary),
            UiBadge(label: 'Active', tone: UiStatus.success),
            UiBadge(label: 'Pending', tone: UiStatus.warning),
            UiBadge(label: '3', tone: UiStatus.danger),
            UiBadge(dot: true, tone: UiStatus.success, semanticLabel: 'Online'),
          ]),
          code: "UiBadge(label: 'Active', tone: UiStatus.success)\nUiBadge(dot: true, tone: UiStatus.success, semanticLabel: 'Online')",
          api: const [
            ApiRow('label', 'String?', 'Text; required unless dot.'),
            ApiRow('tone', 'UiStatus', 'neutral, primary, success, warning, danger.', def: 'neutral'),
            ApiRow('dot', 'bool', '8px dot, no text.', def: 'false'),
          ],
        ),
        DocSection(
          name: 'Chip',
          widget: 'UiChip',
          summary: 'A compact tag. With onRemove it shows a remove button named "Remove <label>" for screen readers; its touch target is padded to 48dp on phones.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
            Wrap(spacing: t.space2, runSpacing: t.space2, children: [
              for (final tag in _tags) UiChip(label: tag, onRemove: () => setState(() => _tags = [..._tags]..remove(tag))),
              if (_tags.isEmpty) UiButton(label: 'Reset tags', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() => _tags = ['angular', 'flutter', 'design'])),
            ]),
            Wrap(spacing: t.space2, runSpacing: t.space2, children: const [
              UiChip(label: 'Primary', tone: UiStatus.primary),
              UiChip(label: 'Success', tone: UiStatus.success),
              UiChip(label: 'Warning', tone: UiStatus.warning),
              UiChip(label: 'Danger', tone: UiStatus.danger),
              UiChip(label: 'With icon', leading: UiIcon(HugeIcons.strokeRoundedTag01)),
            ]),
          ]),
          code: "UiChip(label: 'flutter', onRemove: () => remove('flutter'))\nUiChip(label: 'Success', tone: UiStatus.success)",
          api: const [
            ApiRow('label', 'String', 'Text, also used to name the remove button.'),
            ApiRow('tone', 'UiStatus', 'Tinted fill and border.', def: 'neutral'),
            ApiRow('onRemove', 'VoidCallback?', 'Shows the remove button.'),
            ApiRow('leading', 'Widget?', 'Icon before the label.'),
          ],
        ),
        DocSection(
          name: 'Avatar',
          widget: 'UiAvatar · UiAvatarGroup',
          summary: 'An image with an initials fallback, also used when the image fails to load. Named by alt, else name. UiAvatarGroup overlaps them and shows "+N" past max.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
            Row(spacing: t.space2, children: const [
              UiAvatar(name: 'Aminath Shareef', size: UiSize.sm),
              UiAvatar(name: 'Ali Zahir'),
              UiAvatar(name: 'Mariyam', size: UiSize.lg),
              UiAvatar(name: 'Square One', square: true),
              UiAvatar(image: NetworkImage('https://invalid.example/missing.png'), name: 'Broken Image'),
            ]),
            const UiAvatarGroup(max: 3, children: [
              UiAvatar(name: 'Aminath Shareef'),
              UiAvatar(name: 'Ali Zahir'),
              UiAvatar(name: 'Hawwa Nashidha'),
              UiAvatar(name: 'Ibrahim Moosa'),
              UiAvatar(name: 'Fathimath Ali'),
            ]),
          ]),
          code: "UiAvatar(image: NetworkImage(url), name: 'Ali Zahir')\nUiAvatarGroup(max: 3, children: [...])",
          api: const [
            ApiRow('image', 'ImageProvider?', 'Photo; initials show if it is missing or fails.'),
            ApiRow('name', 'String?', 'For initials and the accessible name.'),
            ApiRow('alt', 'String?', 'Accessible name override.'),
            ApiRow('size', 'UiSize', '26 / 30 / 38.', def: 'md'),
            ApiRow('square', 'bool', 'Rounded square instead of a circle.', def: 'false'),
          ],
        ),
        DocSection(
          name: 'Card',
          widget: 'UiCard',
          summary: 'A surface with optional header and footer. With onTap the whole card is the target: it lifts on press and gets the focus ring.',
          demo: Column(spacing: t.space3, children: [
            UiCard(
              header: const UiText('Monthly report', variant: UiTextVariant.h4, heading: true),
              footer: Row(mainAxisAlignment: MainAxisAlignment.end, spacing: t.space2, children: [
                UiButton(label: 'Share', variant: UiButtonVariant.ghost, size: UiSize.sm, onPressed: () {}),
                UiButton(label: 'Open', size: UiSize.sm, onPressed: () {}),
              ]),
              child: const UiText('Revenue grew 12% on last month, led by the new subscription plans.'),
            ),
            UiCard(
              onTap: () => setState(() => _cardTaps++),
              semanticLabel: 'Template card',
              child: Row(spacing: t.space3, children: [
                UiIcon(HugeIcons.strokeRoundedFile02, color: t.primary),
                Expanded(child: UiText('Tap this card ($_cardTaps)')),
                UiIcon(HugeIcons.strokeRoundedArrowRight01, color: t.textMuted, size: 18),
              ]),
            ),
          ]),
          code: "UiCard(\n  header: UiText('Report', variant: UiTextVariant.h4),\n  footer: UiButton(label: 'Open', onPressed: open),\n  child: UiText('...'),\n)",
          api: const [
            ApiRow('child', 'Widget', 'Body.'),
            ApiRow('header / footer', 'Widget?', 'Separated by a rule.'),
            ApiRow('padding', 'UiSize', '12 / 16 / 24.', def: 'md'),
            ApiRow('onTap', 'VoidCallback?', 'Makes the whole card a button.'),
            ApiRow('glass', 'bool?', 'Frosted surface; defaults to UiConfig.glass.'),
          ],
        ),
        DocSection(
          name: 'Divider',
          widget: 'UiDivider',
          summary: 'A 1px rule, horizontal or vertical, optionally with a centred label.',
          demo: Column(children: [
            const UiDivider(),
            const UiDivider(label: 'or'),
            SizedBox(height: 32, child: Row(children: const [UiText('Left'), UiDivider(axis: Axis.vertical), UiText('Right')])),
          ]),
          code: "UiDivider()\nUiDivider(label: 'or')\nUiDivider(axis: Axis.vertical)",
        ),
        ...navdataDataSections(),
      ],
    );
  }
}
