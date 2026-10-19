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
  String? _view = 'week';
  String? _align = 'left';
  bool _bold = true, _italic = false;
  String _log = 'Nothing yet';

  static const _menu = [
    UiDropdownItem(label: 'Edit', value: 'edit', icon: UiIcon(HugeIcons.strokeRoundedEdit02)),
    UiDropdownItem(label: 'Duplicate', value: 'duplicate', icon: UiIcon(HugeIcons.strokeRoundedCopy01)),
    UiDropdownItem(label: 'Archive', value: 'archive', disabled: true),
    UiDropdownItem(label: 'Delete', value: 'delete', danger: true, icon: UiIcon(HugeIcons.strokeRoundedDelete02)),
  ];

  void _did(String what) => setState(() => _log = what);

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
          summary: 'The action primitive. Eight variants: primary for the main action, secondary, outline, ghost, link, destructive, brand (the theme\'s gradient, pill-shaped) for the one hero action per screen, and accent, filled with the theme\'s accent (the coral call to action in Maldives; secondary in themes without an accent of their own). Leave onPressed null to disable it. While loading it shows a spinner, is announced as busy and ignores taps. Enter and Space activate it when focused.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
            Wrap(spacing: t.space2, runSpacing: t.space2, children: [
              UiButton(label: 'Primary', onPressed: () => setState(() => _count++)),
              UiButton(label: 'Secondary', variant: UiButtonVariant.secondary, onPressed: () {}),
              UiButton(label: 'Outline', variant: UiButtonVariant.outline, onPressed: () {}),
              UiButton(label: 'Delete', variant: UiButtonVariant.destructive, onPressed: () {}),
              UiButton(label: 'Get started', variant: UiButtonVariant.brand, onPressed: () {}),
              UiButton(label: 'Get guidance', variant: UiButtonVariant.accent, onPressed: () {}),
            ]),
            // The borderless variants get their own row: wrapped to the start of a line they read as stray text.
            Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              UiButton(label: 'Ghost', variant: UiButtonVariant.ghost, onPressed: () {}),
              UiButton(label: 'Link', variant: UiButtonVariant.link, onPressed: () {}),
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
            ApiRow('variant', 'UiButtonVariant', 'primary, secondary, outline, ghost, link, destructive, brand, accent.', def: 'primary'),
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
          demo: Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final v in [UiButtonVariant.ghost, UiButtonVariant.outline, UiButtonVariant.primary, UiButtonVariant.secondary, UiButtonVariant.destructive])
              UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedSettings01), label: 'Settings (${v.name})', variant: v, onPressed: () {}),
            UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedFavourite), label: 'Like', round: true, variant: UiButtonVariant.outline, onPressed: () {}),
            UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedDelete02), label: 'Delete', size: UiSize.lg, onPressed: () {}),
            const UiIconButton(icon: UiIcon(HugeIcons.strokeRoundedLockKeyhole), label: 'Locked', onPressed: null),
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
        DocSection(
          name: 'Button group',
          widget: 'UiButtonGroup',
          summary: 'Joins a row of buttons: inner corners go square and neighbouring borders overlap into one line; the hovered or focused button is drawn on top so its ring is never cut. Named by label for screen readers. It does not manage selection; use Segmented for one-of-many.',
          demo: UiButtonGroup(label: 'History', children: [
            UiButton(label: 'Undo', variant: UiButtonVariant.outline, onPressed: () => _did('Undo')),
            UiButton(label: 'Redo', variant: UiButtonVariant.outline, onPressed: () => _did('Redo')),
            UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedSettings01), label: 'History settings', variant: UiButtonVariant.outline, onPressed: () => _did('Settings')),
          ]),
          code: "UiButtonGroup(label: 'History', children: [\n  UiButton(label: 'Undo', variant: UiButtonVariant.outline, onPressed: undo),\n  UiButton(label: 'Redo', variant: UiButtonVariant.outline, onPressed: redo),\n  UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedSettings01), label: 'History settings', variant: UiButtonVariant.outline, onPressed: openSettings),\n])",
          api: const [
            ApiRow('children', 'List<Widget>', 'The buttons (UiButton or UiIconButton).'),
            ApiRow('label', 'String?', 'Accessible name of the group.'),
          ],
        ),
        DocSection(
          name: 'Segmented',
          widget: 'UiSegmented<T>',
          summary: 'Pick one of a few options, joined into one control. A radio group: arrow keys move the choice (wrapping, skipping disabled options), only the chosen option is in the tab order. An option can show a short glyph or an icon instead of its label; the label stays the accessible name. Scrolls sideways when it does not fit. On phones each option gets a 48dp touch area while the track stays compact.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
            UiSegmented<String>(
              label: 'View',
              value: _view,
              onChanged: (v) => setState(() => _view = v),
              options: const [
                UiSegmentedOption(value: 'day', label: 'Day'),
                UiSegmentedOption(value: 'week', label: 'Week'),
                UiSegmentedOption(value: 'month', label: 'Month'),
                UiSegmentedOption(value: 'year', label: 'Year', disabled: true),
              ],
            ),
            UiSegmented<String>(
              label: 'Alignment',
              size: UiSize.sm,
              value: _align,
              onChanged: (v) => setState(() => _align = v),
              options: const [
                UiSegmentedOption(value: 'left', label: 'Align left', icon: UiIcon(HugeIcons.strokeRoundedTextAlignLeft)),
                UiSegmentedOption(value: 'center', label: 'Align centre', icon: UiIcon(HugeIcons.strokeRoundedTextAlignCenter)),
                UiSegmentedOption(value: 'right', label: 'Align right', icon: UiIcon(HugeIcons.strokeRoundedTextAlignRight)),
              ],
            ),
            UiText('View: $_view, alignment: $_align', variant: UiTextVariant.caption),
          ]),
          code: "UiSegmented<String>(\n  label: 'View',\n  value: view,\n  options: const [UiSegmentedOption(value: 'day', label: 'Day'), UiSegmentedOption(value: 'week', label: 'Week')],\n  onChanged: (v) => setState(() => view = v),\n)",
          api: const [
            ApiRow('options', 'List<UiSegmentedOption<T>>', 'The choices, in order.'),
            ApiRow('value', 'T?', 'The chosen option.'),
            ApiRow('onChanged', 'ValueChanged<T>?', 'New choice. Null disables it.'),
            ApiRow('label', 'String', 'Accessible name of the group.', def: "'Options'"),
            ApiRow('size', 'UiSize', 'Track height: options are 24 / 24 / 32 tall.', def: 'md'),
          ],
          shapes: 'class UiSegmentedOption<T> { T value; String label; String? glyph; Widget? icon; bool disabled = false; }',
        ),
        DocSection(
          name: 'Toggle button',
          widget: 'UiToggleButton',
          summary: 'A two-state button, announced with its on/off state (the web aria-pressed). When pressed it takes a primary tint and border. Use it when several can be on at once, like text formatting; for one-of-many use Segmented.',
          demo: Wrap(spacing: t.space2, runSpacing: t.space2, children: [
            UiToggleButton(pressed: _bold, label: 'Bold', icon: const UiIcon(HugeIcons.strokeRoundedTextBold), onChanged: (v) => setState(() => _bold = v)),
            UiToggleButton(pressed: _italic, icon: const UiIcon(HugeIcons.strokeRoundedTextItalic), semanticLabel: 'Italic', onChanged: (v) => setState(() => _italic = v)),
            const UiToggleButton(pressed: true, label: 'Locked', onChanged: null),
          ]),
          code: "UiToggleButton(pressed: bold, label: 'Bold', onChanged: (v) => setState(() => bold = v))",
          api: const [
            ApiRow('pressed', 'bool', 'On or off.'),
            ApiRow('onChanged', 'ValueChanged<bool>?', 'New state. Null disables it.'),
            ApiRow('label / child / icon', 'String? / Widget? / Widget?', 'Content; give an icon-only toggle a semanticLabel.'),
            ApiRow('size', 'UiSize', 'Control height.', def: 'md'),
            ApiRow('radius', 'bool?', 'Rounded corners; defaults to UiConfig.radius.'),
          ],
        ),
        DocSection(
          name: 'Split button',
          widget: 'UiSplitButton<T>',
          summary: 'A main action plus a caret ("More actions") joined into one shape. onPressed runs the main action. The caret either calls onMenu so you can open your own menu, or, given items, opens the built-in action menu and reports the choice to onSelected. Filled variants draw a thin divider between the halves; link, brand and accent draw as outline.',
          demo: Wrap(spacing: t.space2, runSpacing: t.space2, children: [
            UiSplitButton<String>(label: 'Save', onPressed: () => _did('Save'), items: const [
              UiDropdownItem(label: 'Save as draft', value: 'draft'),
              UiDropdownItem(label: 'Save and close', value: 'close'),
            ], onSelected: (i) => _did(i.label)),
            UiSplitButton<String>(label: 'Publish', variant: UiButtonVariant.outline, onPressed: () => _did('Publish'), onMenu: () => _did('Caret pressed')),
          ]),
          code: "UiSplitButton<String>(\n  label: 'Save',\n  onPressed: save,\n  items: const [UiDropdownItem(label: 'Save as draft', value: 'draft')],\n  onSelected: (item) => saveAs(item.value),\n)",
          api: const [
            ApiRow('label', 'String', 'Main button text.'),
            ApiRow('onPressed', 'VoidCallback?', 'Main action. Null disables that half.'),
            ApiRow('onMenu', 'VoidCallback?', 'Caret pressed, when there are no items.'),
            ApiRow('items / onSelected', 'List<UiDropdownItem<T>>? / ValueChanged', 'Built-in menu on the caret.'),
            ApiRow('variant', 'UiButtonVariant', 'Style of both halves.', def: 'primary'),
            ApiRow('size', 'UiSize', 'Control height.', def: 'md'),
            ApiRow('menuLabel', 'String', 'The caret\'s accessible name.', def: "'More actions'"),
          ],
        ),
        DocSection(
          name: 'Dropdown button',
          widget: 'UiDropdownButton<T>',
          summary: 'A button that opens a menu of actions next to it, flipping and shifting to stay on screen. Opening focuses the first enabled item; ArrowUp/Down (wrapping), Home and End move, Enter chooses, Escape closes and returns focus to the trigger, Tab or a tap outside closes. Disabled items never fire; danger items are drawn in red. The trigger is announced as expanded while open.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
            Wrap(spacing: t.space2, runSpacing: t.space2, children: [
              UiDropdownButton<String>(label: 'Actions', items: _menu, onSelected: (i) => _did('Chose ${i.label}')),
              UiDropdownButton<String>(label: 'Primary', variant: UiButtonVariant.primary, items: _menu, onSelected: (i) => _did('Chose ${i.label}')),
              const UiDropdownButton<String>(label: 'Disabled', items: _menu, onSelected: null),
            ]),
          ]),
          code: "UiDropdownButton<String>(\n  label: 'Actions',\n  items: const [UiDropdownItem(label: 'Edit', value: 'edit'), UiDropdownItem(label: 'Delete', value: 'delete', danger: true)],\n  onSelected: (item) => run(item.value),\n)",
          api: const [
            ApiRow('label', 'String', 'Trigger text (a chevron follows it).'),
            ApiRow('items', 'List<UiDropdownItem<T>>', 'Menu actions.'),
            ApiRow('onSelected', 'ValueChanged<UiDropdownItem<T>>?', 'Chosen item. Null disables the trigger.'),
            ApiRow('icon', 'Widget?', 'Icon before the label.'),
            ApiRow('variant', 'UiButtonVariant', 'Trigger style; link and brand draw as outline.', def: 'secondary'),
            ApiRow('size', 'UiSize', 'Trigger height.', def: 'md'),
          ],
          callbacks: const [
            ApiRow('UiDropdownMenuAnchor<T>', 'widget', 'The same menu on any trigger: builder gets (open, toggle, triggerFocus).'),
          ],
          shapes: 'class UiDropdownItem<T> { String label; T value; Widget? icon; bool disabled = false; bool danger = false; }',
        ),
        DocSection(
          name: 'FAB',
          widget: 'UiFab · UiFabHost',
          summary: 'The floating action button: round, primary, with a shadow; it grows a little on hover and shrinks when pressed. label is required and is its accessible name. UiFabHost pins it to a corner over your content, offset by the safe area. The sm size grows to 48dp on phones. The demo frame below is its own host, so the button sits in the frame\'s corner.',
          demo: SizedBox(
            height: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(t.radius),
              child: UiFabHost(
                fab: UiFab(icon: const UiIcon(HugeIcons.strokeRoundedAdd01), label: 'New note', onPressed: () => _did('New note')),
                child: Container(
                  color: t.surface,
                  padding: EdgeInsets.all(t.space4),
                  child: UiText('Last action: $_log', color: t.textMuted),
                ),
              ),
            ),
          ),
          code: "UiFabHost(\n  fab: UiFab(icon: UiIcon(HugeIcons.strokeRoundedAdd01), label: 'New note', onPressed: create),\n  child: notesList,\n)",
          api: const [
            ApiRow('icon', 'Widget', 'The icon.'),
            ApiRow('label', 'String', 'Required accessible name.'),
            ApiRow('onPressed', 'VoidCallback?', 'Null disables it.'),
            ApiRow('size', 'UiFabSize', 'sm (40, 48 on phones) or md (52).', def: 'md'),
            ApiRow('UiFabHost.position', 'UiFabPosition', 'bottomEnd, bottomStart, topEnd, topStart.', def: 'bottomEnd'),
          ],
        ),
      ],
    );
  }
}
