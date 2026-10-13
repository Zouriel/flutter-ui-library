import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

class ButtonsPage extends StatefulWidget {
  const ButtonsPage({super.key});

  @override
  State<ButtonsPage> createState() => _ButtonsPageState();
}

class _ButtonsPageState extends State<ButtonsPage> {
  bool _saving = false;
  int _count = 0;

  Future<void> _save() async {
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return DocPage(
      eyebrow: 'Components',
      title: 'Buttons & actions',
      lead: 'Buttons, icon buttons and their variants. Every button is reachable by keyboard, shows a focus ring for keyboard users only, and has at least a 48dp touch target on phones without growing its visual size.',
      children: [
        DocSection(
          name: 'Button',
          widget: 'UiButton',
          summary: 'The action primitive. Seven variants: primary for the main action, secondary, outline, ghost, link, destructive, and brand (the theme\'s gradient, pill-shaped) for the one hero action per screen. Leave onPressed null to disable it. While loading it shows a spinner, is announced as busy and ignores taps. Enter and Space activate it when focused.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
            Wrap(spacing: t.space2, runSpacing: t.space2, children: [
              UiButton(label: 'Primary', onPressed: () => setState(() => _count++)),
              UiButton(label: 'Secondary', variant: UiButtonVariant.secondary, onPressed: () {}),
              UiButton(label: 'Outline', variant: UiButtonVariant.outline, onPressed: () {}),
              UiButton(label: 'Ghost', variant: UiButtonVariant.ghost, onPressed: () {}),
              UiButton(label: 'Link', variant: UiButtonVariant.link, onPressed: () {}),
              UiButton(label: 'Delete', variant: UiButtonVariant.destructive, onPressed: () {}),
              UiButton(label: 'Get started', variant: UiButtonVariant.brand, onPressed: () {}),
            ]),
            Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              UiButton(label: 'Small', size: UiSize.sm, onPressed: () {}),
              UiButton(label: 'Medium', onPressed: () {}),
              UiButton(label: 'Large', size: UiSize.lg, onPressed: () {}),
            ]),
            Wrap(spacing: t.space2, runSpacing: t.space2, children: [
              UiButton(label: 'New item', icon: const UiIcon(HugeIcons.strokeRoundedAdd01), variant: UiButtonVariant.outline, onPressed: () {}),
              UiButton(label: _saving ? 'Saving' : 'Save', loading: _saving, onPressed: _save),
              const UiButton(label: 'Disabled', onPressed: null),
            ]),
            UiButton(label: 'Full width', block: true, variant: UiButtonVariant.secondary, onPressed: () {}),
            UiText('Primary pressed $_count times', variant: UiTextVariant.caption),
          ]),
          code: '''UiButton(label: 'Save', onPressed: save)
UiButton(label: 'Delete', variant: UiButtonVariant.destructive, onPressed: delete)
UiButton(label: 'New', icon: UiIcon(HugeIcons.strokeRoundedAdd01), onPressed: add)
UiButton(label: 'Saving', loading: true, onPressed: save)''',
          api: const [
            ApiRow('label', 'String?', 'Button text. Or pass any child.'),
            ApiRow('child', 'Widget?', 'Custom content instead of label.'),
            ApiRow('icon / trailingIcon', 'Widget?', 'Icons before or after the text; coloured and sized to match.'),
            ApiRow('onPressed', 'VoidCallback?', 'Tap and Enter/Space handler. Null disables the button.'),
            ApiRow('variant', 'UiButtonVariant', 'primary, secondary, outline, ghost, link, destructive, brand.', def: 'primary'),
            ApiRow('size', 'UiSize', 'sm (26), md (30), lg (38) visual height.', def: 'md'),
            ApiRow('loading', 'bool', 'Spinner, busy announcement, taps ignored.', def: 'false'),
            ApiRow('block', 'bool', 'Full width.', def: 'false'),
            ApiRow('glass', 'bool', 'Frosted translucent fill.', def: 'false'),
            ApiRow('radius', 'bool?', 'Rounded corners; defaults to UiConfig.radius.'),
          ],
          shapes: 'enum UiButtonVariant { primary, secondary, outline, ghost, link, destructive, brand }\nenum UiSize { sm, md, lg }',
        ),
        DocSection(
          name: 'Icon button',
          widget: 'UiIconButton',
          summary: 'A square, icon-only action. label is required: it is what screen readers announce. Defaults to the ghost variant; round makes it a circle.',
          demo: Wrap(spacing: t.space2, runSpacing: t.space2, children: [
            for (final v in [UiButtonVariant.ghost, UiButtonVariant.outline, UiButtonVariant.primary, UiButtonVariant.secondary, UiButtonVariant.destructive])
              UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedSettings01), label: 'Settings (${v.name})', variant: v, onPressed: () {}),
            UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedFavourite), label: 'Like', round: true, variant: UiButtonVariant.outline, onPressed: () {}),
            UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedDelete02), label: 'Delete', size: UiSize.lg, onPressed: () {}),
            const UiIconButton(icon: UiIcon(HugeIcons.strokeRoundedLock), label: 'Locked', onPressed: null),
          ]),
          code: "UiIconButton(\n  icon: UiIcon(HugeIcons.strokeRoundedSettings01),\n  label: 'Settings',\n  onPressed: openSettings,\n)",
          api: const [
            ApiRow('icon', 'Widget', 'The icon (usually a HugeIcon).'),
            ApiRow('label', 'String', 'Required accessible name.'),
            ApiRow('onPressed', 'VoidCallback?', 'Null disables it.'),
            ApiRow('variant', 'UiButtonVariant', 'As UiButton; link behaves like ghost.', def: 'ghost'),
            ApiRow('size', 'UiSize', 'Square size: 26 / 30 / 38.', def: 'md'),
            ApiRow('round', 'bool', 'Circle instead of rounded square.', def: 'false'),
          ],
        ),
      ],
    );
  }
}
