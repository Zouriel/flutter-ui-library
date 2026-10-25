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
  int _held = 0;
  bool _googleBusy = false;
  int _googleTaps = 0;
  String? _view = 'week';
  String? _align = 'left';
  bool _bold = true, _italic = false;
  String _log = 'Nothing yet';
  UiFabPosition _sosAt = UiFabPosition.topCenter;
  double _fabPeek = 72;

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
          summary: 'The action primitive. Eight variants: primary for the main action, secondary, outline, ghost, link, destructive, brand (the theme\'s gradient, pill-shaped) for the one hero action per screen, and accent, filled with the theme\'s accent (the coral call to action in Maldives; secondary in themes without an accent of their own). Leave onPressed null to disable it. While loading it shows a spinner, is announced as busy and ignores taps. Enter and Space activate it when focused. Four sizes; xl (56) is for the one big action on a phone screen.',
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
          name: 'Hold button',
          widget: 'UiHoldButton',
          summary: 'Press and hold to confirm, for an action that shouldn\'t happen on a stray tap (start a visit, mark as arrived). A fill grows across the button while it is held; letting go early cancels it, and haptics mark the start and the confirmation. With a keyboard, Space or Enter held does the same. Holding isn\'t accessible to everyone, so a tap, a quick Enter or a screen reader\'s double-tap opens a confirm dialog instead, which confirms the same way. The button is read with holdHint.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            UiHoldButton(label: "I've arrived", size: UiSize.xl, block: true, onConfirmed: () => setState(() => _held++)),
            UiHoldButton(
              label: 'Hold to cancel the visit',
              variant: UiButtonVariant.destructive,
              hold: const Duration(milliseconds: 1500),
              destructive: true,
              confirmTitle: 'Cancel the visit?',
              onConfirmed: () => setState(() => _held++),
            ),
            UiText('Confirmed $_held times', variant: UiTextVariant.caption),
          ]),
          code: '''UiHoldButton(
  label: "I've arrived",
  size: UiSize.xl,
  block: true,
  hold: Duration(seconds: 2),
  onConfirmed: arrive,
)''',
          api: const [
            ApiRow('label / child', 'String? / Widget?', 'The button text.'),
            ApiRow('onConfirmed', 'VoidCallback?', 'Held to the end, or confirmed in the dialog; null disables it.'),
            ApiRow('hold', 'Duration', 'How long to hold.', def: '2s'),
            ApiRow('variant / size / block / icon', 'as UiButton', 'Look; size takes xl.', def: 'primary / md / false'),
            ApiRow('semanticLabel', 'String?', 'Accessible name override.'),
            ApiRow('holdHint', 'String?', 'Read with the button.', def: "strings.holdHint ('Press and hold to confirm')"),
            ApiRow('confirmTitle / confirmMessage / confirmLabel / destructive', 'String? / String / String? / bool', 'The tap fallback dialog.'),
          ],
        ),
        DocSection(
          name: 'Sign in with Google',
          widget: 'UiGoogleSignInButton',
          summary: 'Google\'s sign-in button, drawn to its branding guidelines: the official multicolour G, Google\'s light (white, grey stroke), dark and neutral (light grey, no stroke) colours, 40 high, Roboto Medium 14/20, rectangular or pill. auto picks dark on a dark theme and light otherwise. It only draws the button: pair it with the google_sign_in package (authenticate() gives the idToken; set serverClientId to the web client ID your server checks). loading swaps the G for a spinner at the same width and ignores taps. The words come from UiStrings (googleSignIn, googleSignUp, googleContinue, googleSignInShort), so translate them there; Google only allows its approved wordings. The web twin is ui-google-button; on the web, ui-google-sign-in wraps Google\'s own button instead.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
            UiGoogleSignInButton(
              loading: _googleBusy,
              onPressed: () async {
                setState(() => _googleBusy = true);
                await Future<void>.delayed(const Duration(seconds: 1));
                if (!mounted) return;
                setState(() {
                  _googleBusy = false;
                  _googleTaps++;
                });
              },
            ),
            Wrap(spacing: t.space2, runSpacing: t.space2, children: [
              UiGoogleSignInButton(onPressed: () {}, theme: UiGoogleButtonTheme.light, shape: UiGoogleButtonShape.pill, text: UiGoogleButtonText.continueWith),
              UiGoogleSignInButton(onPressed: () {}, theme: UiGoogleButtonTheme.dark, text: UiGoogleButtonText.signUp),
              UiGoogleSignInButton(onPressed: () {}, theme: UiGoogleButtonTheme.neutral, text: UiGoogleButtonText.signInShort),
              const UiGoogleSignInButton(onPressed: null),
            ]),
            UiGoogleSignInButton(onPressed: () {}, expand: true, text: UiGoogleButtonText.continueWith),
            UiText('Signed in (pretend) $_googleTaps times', variant: UiTextVariant.caption),
          ]),
          code: '''// pubspec: google_sign_in (the library doesn't depend on it)
final google = GoogleSignIn.instance;
await google.initialize(serverClientId: webClientId);

UiGoogleSignInButton(
  loading: busy,
  onPressed: () async {
    setState(() => busy = true);
    try {
      final account = await google.authenticate();
      final idToken = account.authentication.idToken; // send to your API
    } finally {
      setState(() => busy = false);
    }
  },
)''',
          api: const [
            ApiRow('onPressed', 'VoidCallback?', 'Start the app\'s sign-in. Null disables the button.'),
            ApiRow('text', 'UiGoogleButtonText', 'signIn, signUp, continueWith, signInShort ("Sign in").', def: 'signIn'),
            ApiRow('theme', 'UiGoogleButtonTheme', 'auto (dark on a dark UiApp theme, else light), light, dark, neutral.', def: 'auto'),
            ApiRow('shape', 'UiGoogleButtonShape', 'rectangular (4px corners) or pill.', def: 'rectangular'),
            ApiRow('loading', 'bool', 'Spinner in place of the G, same width, taps ignored, announced as busy.', def: 'false'),
            ApiRow('expand', 'bool', 'Full width; the G stays at the start, the words centre.', def: 'false'),
            ApiRow('semanticLabel', 'String?', 'Accessible name override.', def: 'the words'),
            ApiRow('focusNode / autofocus', 'FocusNode? / bool', 'Keyboard focus.'),
          ],
          shapes: 'enum UiGoogleButtonText { signIn, signUp, continueWith, signInShort }\nenum UiGoogleButtonTheme { auto, light, dark, neutral }\nenum UiGoogleButtonShape { rectangular, pill }',
        ),
        DocSection(
          name: 'Icon button',
          widget: 'UiIconButton',
          summary: 'A square, icon-only action. label is required: it is what screen readers announce. Defaults to the ghost variant; round makes it a circle. badge (0.44.0, on UiButton too) shows a small count bubble at the top-end corner (the top-left in right-to-left text), danger by default or primary; uiBadgeCount(n) gives "9+" past 9. The badge is read after the name: badgeLabel when given ("Chat, 2 unread"), else its text.',
          demo: Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final v in [UiButtonVariant.ghost, UiButtonVariant.outline, UiButtonVariant.primary, UiButtonVariant.secondary, UiButtonVariant.destructive])
              UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedSettings01), label: 'Settings (${v.name})', variant: v, onPressed: () {}),
            UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedFavourite), label: 'Like', round: true, variant: UiButtonVariant.outline, onPressed: () {}),
            UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedDelete02), label: 'Delete', size: UiSize.lg, onPressed: () {}),
            const UiIconButton(icon: UiIcon(HugeIcons.strokeRoundedLockKeyhole), label: 'Locked', onPressed: null),
            UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedMessage01), label: 'Chat', badge: uiBadgeCount(2), badgeLabel: '2 unread', variant: UiButtonVariant.outline, onPressed: () {}),
            UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedNotification01), label: 'Alerts', badge: uiBadgeCount(14), onPressed: () {}),
            UiButton(label: 'Chat with the nurse', icon: const UiIcon(HugeIcons.strokeRoundedMessage01), badge: '1', badgeLabel: '1 unread', variant: UiButtonVariant.secondary, onPressed: () {}),
          ]),
          code: "UiIconButton(\n  icon: UiIcon(HugeIcons.strokeRoundedSettings01),\n  label: 'Settings',\n  onPressed: openSettings,\n)",
          api: const [
            ApiRow('icon', 'Widget', 'The icon (usually a HugeIcon).'),
            ApiRow('label', 'String', 'Required accessible name.'),
            ApiRow('onPressed', 'VoidCallback?', 'Null disables it.'),
            ApiRow('variant', 'UiButtonVariant', 'As UiButton; link behaves like ghost.', def: 'ghost'),
            ApiRow('size', 'UiSize', 'Square size: 26 / 30 / 38.', def: 'md'),
            ApiRow('round', 'bool', 'Circle instead of rounded square.', def: 'false'),
            ApiRow('badge / badgeTone / badgeLabel', 'String? / UiBadgeTone / String?', 'A count bubble at the top-end corner (0.44.0, UiButton too): danger or primary, read after the name as badgeLabel or its text.', def: 'null / danger / null'),
            ApiRow('uiBadgeCount(n, {max: 9})', 'String?', 'null for 0 or less, "9+" past max, else the number.'),
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
          summary: 'The floating action button: round, primary, with a shadow; it grows a little on hover and shrinks when pressed. label is required and is its accessible name. UiFabHost pins it to a corner, or the middle of the top or bottom edge (topCenter, bottomCenter: 0.44.0), offset by the safe area, so a top button never covers the status bar. topOffset adds px above a top button for an app bar; bottomOffset (0.47.1) adds px below a bottom button so it floats above a bottom sheet\'s peek or a bottom navigation, easing when it changes. The sm size grows to 48dp on phones. tone: UiFabTone.danger (0.44.0) is for an emergency action such as SOS: the danger colour with a ring and a soft halo that stand out on any page or map; text makes it an extended pill with the word after the icon. UiFabHost draws the button above its child, so a bottom sheet or the sidebar drawer inside the page stays under it; to keep it above routes too, put the host in UiApp.builder. The demo frames are their own hosts.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            SizedBox(
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
            UiSegmented<UiFabPosition>(
              label: 'SOS position',
              size: UiSize.sm,
              options: const [
                UiSegmentedOption(value: UiFabPosition.topStart, label: 'Top start'),
                UiSegmentedOption(value: UiFabPosition.topCenter, label: 'Top centre'),
                UiSegmentedOption(value: UiFabPosition.topEnd, label: 'Top end'),
                UiSegmentedOption(value: UiFabPosition.bottomCenter, label: 'Bottom centre'),
              ],
              value: _sosAt,
              onChanged: (v) => setState(() => _sosAt = v),
            ),
            SizedBox(
              height: 260,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(t.radius),
                child: UiFabHost(
                  position: _sosAt,
                  topOffset: _sosAt == UiFabPosition.bottomCenter ? 0 : 40,
                  fab: UiFab(
                    icon: const UiIcon(HugeIcons.strokeRoundedAlert02),
                    label: 'Emergency SOS',
                    text: 'SOS',
                    tone: UiFabTone.danger,
                    hold: const Duration(seconds: 2),
                    holdHint: 'Press and hold to call for help',
                    confirmTitle: 'Send an SOS?',
                    confirmMessage: 'Your location goes to the emergency team.',
                    confirmLabel: 'Send SOS',
                    destructive: true,
                    onPressed: () => _did('SOS'),
                  ),
                  child: Stack(children: [
                    Positioned.fill(child: Container(color: t.surface, padding: EdgeInsets.fromLTRB(t.space4, 40 + t.space4, t.space4, t.space4), child: UiText('A page with a sheet over it. Hold SOS for 2 seconds, or tap it to confirm. Last action: $_log', color: t.textMuted))),
                    // The app bar the top SOS sits under (topOffset: 40).
                    Positioned(top: 0, left: 0, right: 0, height: 40, child: Container(color: t.surfaceRaised, padding: EdgeInsets.symmetric(horizontal: t.space4), alignment: AlignmentDirectional.centerStart, child: const UiText('Visit', variant: UiTextVariant.label))),
                    const UiBottomSheet(snaps: [0.2, 0.5], snap: 1, title: 'Nearby', child: UiText('The SOS button stays above the sheet.')),
                  ]),
                ),
              ),
            ),
            // 0.47.1: bottomOffset, above a sheet's peek.
            SizedBox(
              key: const ValueKey('fab-peek-frame'),
              height: 240,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(t.radius),
                child: UiFabHost(
                  bottomOffset: _fabPeek,
                  fab: UiFab(icon: const UiIcon(HugeIcons.strokeRoundedAdd01), label: 'New item, above the sheet', onPressed: () => _did('New item')),
                  child: Stack(children: [
                    Positioned.fill(child: Container(color: t.surface)),
                    AnimatedPositioned(
                      duration: context.uiAnimate ? t.motionBase : Duration.zero,
                      curve: t.easeStandard,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: _fabPeek,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space3),
                        decoration: BoxDecoration(
                            color: t.surfaceRaised, border: Border(top: BorderSide(color: t.border)), borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusLg)), boxShadow: t.shadow3),
                        child: UiText('Bottom sheet (${_fabPeek.round()} px)', color: t.textMuted, variant: UiTextVariant.caption),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            UiSegmented<double>(
              label: 'Sheet (demo)',
              size: UiSize.sm,
              options: const [UiSegmentedOption(value: 0, label: 'None'), UiSegmentedOption(value: 72, label: 'Peek'), UiSegmentedOption(value: 160, label: 'Open')],
              value: _fabPeek,
              onChanged: (v) => setState(() => _fabPeek = v),
            ),
          ]),
          code: "UiFabHost(\n  fab: UiFab(icon: UiIcon(HugeIcons.strokeRoundedAdd01), label: 'New note', onPressed: create),\n  bottomOffset: sheetVisibleHeight, // 0.47.1: above a bottom sheet's peek\n  child: notesList,\n)",
          api: const [
            ApiRow('icon', 'Widget', 'The icon.'),
            ApiRow('label', 'String', 'Required accessible name.'),
            ApiRow('onPressed', 'VoidCallback?', 'Null disables it.'),
            ApiRow('size', 'UiFabSize', 'sm (40, 48 on phones) or md (52).', def: 'md'),
            ApiRow('tone', 'UiFabTone', 'primary, or danger (0.44.0) for SOS: the danger fill with a raised-surface ring and a danger halo.', def: 'primary'),
            ApiRow('text', 'String?', 'An extended pill with the text after the icon (0.44.0); the name is still label.'),
            ApiRow('hold', 'Duration?', 'Press and hold that long to activate (0.44.0), as UiHoldButton: a tap, quick Enter / Space or a screen reader opens the confirm dialog instead.'),
            ApiRow('holdHint / confirmTitle / confirmMessage / confirmLabel / destructive', 'String? / String? / String / String? / bool', 'Read with a held button (UiStrings.holdHint), and the tap fallback dialog.'),
            ApiRow('UiFabHost.topOffset', 'double', 'Px added above a top button, for the app bar (0.44.0).', def: '0'),
            ApiRow('UiFabHost.bottomOffset', 'double', 'Px added below a bottom button, for a bottom sheet\'s peek or a bottom navigation; eased when it changes (0.47.1, the web ui-fab bottomOffset).', def: '0'),
            ApiRow('UiFabHost.position', 'UiFabPosition', 'bottomEnd, bottomStart, topEnd, topStart, topCenter, bottomCenter (0.44.0). Offset by the safe area, so top ones sit below the status bar.', def: 'bottomEnd'),
          ],
        ),
      ],
    );
  }
}
