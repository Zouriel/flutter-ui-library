import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

const _menuItems = [
  UiMenuItem(label: 'Edit', value: 'edit', icon: HugeIcons.strokeRoundedEdit02),
  UiMenuItem(label: 'Duplicate', value: 'duplicate', icon: HugeIcons.strokeRoundedCopy01),
  UiMenuItem(label: 'Archive', value: 'archive', disabled: true),
  UiMenuItem(label: 'Delete', value: 'delete', danger: true, icon: HugeIcons.strokeRoundedDelete02),
];

const _commands = [
  UiCommand(label: 'New file', value: 'new', group: 'File', icon: UiIcon(HugeIcons.strokeRoundedFileAdd), shortcut: 'Ctrl+N'),
  UiCommand(label: 'Open recent', value: 'recent', group: 'File', icon: UiIcon(HugeIcons.strokeRoundedClock01)),
  UiCommand(label: 'Toggle dark mode', value: 'theme', group: 'View', keywords: 'theme night light', icon: UiIcon(HugeIcons.strokeRoundedMoon02)),
  UiCommand(label: 'Search docs', value: 'docs', group: 'Help', icon: UiIcon(HugeIcons.strokeRoundedSearch01), shortcut: 'Ctrl+K'),
  UiCommand(label: 'Settings', value: 'settings', icon: Text('S'), shortcut: 'Ctrl+,'),
];

/// Overlays & dialogs: tooltip, popover, menu, context menu, modal, drawer, confirm, backdrop,
/// bottom sheet, toasts and the command palette.
class OverlaysPage extends StatefulWidget {
  const OverlaysPage({super.key});

  @override
  State<OverlaysPage> createState() => _OverlaysPageState();
}

class _OverlaysPageState extends State<OverlaysPage> {
  final UiToastController _toasts = UiToastController();
  final UiSnackbarController _snacks = UiSnackbarController();
  final OverlayPortalController _toastLayer = OverlayPortalController();
  UiToastPosition _toastPos = UiToastPosition.bottomRight;
  String _menuChoice = 'nothing yet';
  String _contextChoice = 'nothing yet';
  String _modalResult = 'not opened';
  String _confirmResult = 'not asked';
  String _paletteResult = 'nothing run yet';
  bool _backdrop = false;
  int _sheetSnap = 0;
  bool _sheetModal = false;

  @override
  void initState() {
    super.initState();
    // The showcase app has no toast host of its own, so this page floats one over the screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _toastLayer.show() : null);
  }

  @override
  void dispose() {
    _toasts.dispose();
    _snacks.dispose();
    super.dispose();
  }

  Future<void> _openPalette() async {
    final c = await showUiCommandPalette(context: context, commands: _commands);
    if (mounted) setState(() => _paletteResult = c == null ? 'closed without running' : 'ran "${c.label}"');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    Widget row(List<Widget> children) => Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: children);
    Widget note(String s) => UiText(s, variant: UiTextVariant.caption);

    final page = DocPage(
      eyebrow: 'Components',
      title: 'Overlays & dialogs',
      lead: 'Tooltips, popovers, menus, dialogs, sheets, toasts and the command palette. Dialogs open on their own route, so the back button closes them, focus stays inside while they are open and goes back where it was afterwards, and screen readers cannot wander into the page beneath.',
      children: [
        DocSection(
          name: 'Tooltip',
          widget: 'UiTooltip',
          summary: 'A short description beside its child. With a mouse it shows on hover; with a keyboard on focus; on a phone on long-press, hiding 1.5 s after the finger lifts. Escape hides it. It opens on the chosen side, flips to the opposite one when there is no room, tries the other two after that, and never covers the thing it describes; it is kept 8px inside the screen. Screen readers get the text as the child\'s tooltip, so wrap a single control. An empty message shows nothing.',
          demo: row([
            for (final p in UiTooltipPosition.values)
              UiTooltip(message: 'Tooltip on the ${p.name}', position: p, child: UiButton(label: p.name[0].toUpperCase() + p.name.substring(1), variant: UiButtonVariant.outline, onPressed: () {})),
            UiTooltip(message: 'Delete forever', child: UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedDelete02), label: 'Delete', onPressed: () {})),
            note('Long-press (touch) or hover (mouse).'),
          ]),
          code: '''UiTooltip(
  message: 'Delete forever',
  position: UiTooltipPosition.top,
  child: UiIconButton(icon: UiIcon(HugeIcons.strokeRoundedDelete02), label: 'Delete', onPressed: delete),
)''',
          api: const [
            ApiRow('message', 'String', 'The text. Empty shows nothing.'),
            ApiRow('position', 'UiTooltipPosition', 'Preferred side: top, bottom, left, right. The opposite side is used when this one has no room.', def: 'top'),
            ApiRow('touchDuration', 'Duration', 'How long it stays after a long-press ends.', def: '1500ms'),
            ApiRow('child', 'Widget', 'What it describes; a single control.'),
          ],
        ),
        DocSection(
          name: 'Popover',
          widget: 'UiPopover',
          summary: 'A floating panel a trigger toggles. builder draws the trigger and gets a toggle callback for it; content is the panel. A tap outside or Escape closes it. Focus is not moved into the panel (Tab reaches it after the trigger); when Escape closes it from inside, focus goes back to the trigger. The panel is a dialog named by label. It falls back to above the trigger when there is no room below and shifts sideways to stay on screen. Uncontrolled by default; pass open and onOpenChanged to control it.',
          demo: row([
            UiPopover(
              label: 'Filters',
              builder: (context, toggle, open) => UiButton(label: open ? 'Close filters' : 'Filters', icon: const UiIcon(HugeIcons.strokeRoundedFilter), variant: UiButtonVariant.outline, onPressed: toggle),
              content: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
                UiText('Filters', variant: UiTextVariant.label),
                UiText('Panel content can be anything: text, a form, a list of choices.', variant: UiTextVariant.caption),
                UiButton(label: 'Apply', size: UiSize.sm, onPressed: () {}),
              ]),
            ),
            UiPopover(
              label: 'About',
              placement: UiPopoverPlacement.top,
              builder: (context, toggle, open) => UiButton(label: 'Opens above', variant: UiButtonVariant.ghost, onPressed: toggle),
              content: UiText('Placement top, centred on the trigger.', variant: UiTextVariant.caption),
            ),
          ]),
          code: '''UiPopover(
  label: 'Filters',
  builder: (context, toggle, open) => UiButton(label: 'Filters', onPressed: toggle),
  content: FiltersForm(),
)''',
          api: const [
            ApiRow('builder', '(context, toggle, open) => Widget', 'The trigger. Call toggle from its onPressed.'),
            ApiRow('content', 'Widget', 'The panel body.'),
            ApiRow('label', 'String?', 'The panel\'s accessible name (it is a dialog).'),
            ApiRow('placement', 'UiPopoverPlacement', 'bottom, top, bottomStart, bottomEnd. Falls back to the other side when it does not fit.', def: 'bottomStart'),
            ApiRow('open / onOpenChanged', 'bool? / ValueChanged<bool>?', 'Control it from outside.'),
            ApiRow('glass / radius', 'bool?', 'Frosted panel / rounded corners; default to UiConfig.'),
          ],
        ),
        DocSection(
          name: 'Menu',
          widget: 'UiMenu · UiMenuItem',
          summary: 'A dropdown menu of actions. Opening focuses the first enabled item; ArrowUp/Down (wrapping), Home and End move between items and Enter chooses one. Choosing an item or pressing Escape closes it and puts focus back on the trigger; Tab closes it and moves on. Disabled items are dimmed and skipped. It flips above, or lines up with the trigger\'s right edge, to stay on screen. Items are 48dp tall on touch screens.',
          demo: row([
            UiMenu(
              items: _menuItems,
              onSelect: (i) => setState(() => _menuChoice = i.label),
              builder: (context, toggle, open) => UiButton(label: 'Actions', trailingIcon: const UiIcon(HugeIcons.strokeRoundedArrowDown01), variant: UiButtonVariant.outline, onPressed: toggle),
            ),
            note('Chosen: $_menuChoice'),
          ]),
          code: '''UiMenu(
  items: const [
    UiMenuItem(label: 'Edit', value: 'edit', icon: HugeIcons.strokeRoundedEdit02),
    UiMenuItem(label: 'Delete', value: 'delete', danger: true),
  ],
  onSelect: (item) => run(item.value),
  builder: (context, toggle, open) => UiButton(label: 'Actions', onPressed: toggle),
)''',
          api: const [
            ApiRow('items', 'List<UiMenuItem>', 'The entries. Disabled ones are skipped by the arrow keys.'),
            ApiRow('onSelect', 'ValueChanged<UiMenuItem>', 'Chosen item; the menu has already closed.'),
            ApiRow('builder', '(context, toggle, open) => Widget', 'The trigger; focus returns to it on close.'),
            ApiRow('open / onOpenChanged', 'bool? / ValueChanged<bool>?', 'Control it from outside.'),
            ApiRow('placement', 'UiPlacement', 'Preferred position.', def: 'bottomStart'),
            ApiRow('glass / radius', 'bool?', 'Frosted panel / rounded corners; default to UiConfig.'),
          ],
          shapes: 'UiMenuItem({required String label, required String value, bool disabled = false, bool danger = false, UiIconData? icon})',
        ),
        DocSection(
          name: 'Context menu',
          widget: 'UiContextMenu',
          summary: 'A menu opened where you press: long-press on a touch screen (with a little haptic tick), right-click with a mouse, or the Menu key / Shift+F10 on a keyboard. It flips and shifts so it never runs off the edge. The first item gets focus; ArrowUp/Down, Home and End move between items. Escape or choosing an item closes it and gives focus back to what had it before; a tap outside or scrolling the page also closes it. Screen readers get it as the long-press action.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            UiContextMenu(
              items: _menuItems,
              onSelect: (i) => setState(() => _contextChoice = i.label),
              child: Container(
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(border: Border.all(color: t.borderStrong), borderRadius: BorderRadius.circular(t.radius), color: t.surface),
                child: UiText('Long-press or right-click here', variant: UiTextVariant.caption),
              ),
            ),
            note('Chosen: $_contextChoice'),
          ]),
          code: '''UiContextMenu(
  items: items,
  onSelect: (item) => run(item.value),
  child: PhotoTile(photo),
)''',
          api: const [
            ApiRow('items', 'List<UiMenuItem>', 'The entries.'),
            ApiRow('onSelect', 'ValueChanged<UiMenuItem>', 'Chosen item.'),
            ApiRow('child', 'Widget', 'The area that opens it.'),
            ApiRow('enabled', 'bool', 'Off: the gestures do nothing.', def: 'true'),
            ApiRow('semanticHint', 'String', 'What the long-press action is called for screen readers.', def: "'Show menu'"),
          ],
        ),
        DocSection(
          name: 'Modal',
          widget: 'showUiModal · UiModal',
          summary: 'A centred dialog on its own route. The page dims and stops scrolling, focus moves into the dialog and Tab stays there, screen readers cannot reach the page, and when it closes focus goes back to what had it. It closes on the back button, on Escape and on a backdrop tap (each can be turned off except back), and completes with whatever it is popped with. Only the body scrolls; the header and footer stay put. size full fills the screen with no padding, for editors.',
          demo: row([
            for (final s in [UiModalSize.sm, UiModalSize.md, UiModalSize.lg, UiModalSize.full])
              UiButton(
                label: 'Open ${s.name}',
                variant: s == UiModalSize.md ? UiButtonVariant.primary : UiButtonVariant.outline,
                onPressed: () async {
                  final r = await showUiModal<String>(
                    context: context,
                    title: s == UiModalSize.full ? 'Full-screen editor' : 'Rename project',
                    size: s,
                    builder: (context) => s == UiModalSize.full
                        ? Center(child: UiText('The whole screen is yours.', variant: UiTextVariant.caption))
                        : Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
                            UiText('The new name shows everywhere the project is linked.', variant: UiTextVariant.caption),
                            UiText('Body text sits on the surface colour. Long content scrolls here while the header and footer stay put.'),
                          ]),
                    footerBuilder: (context) => Row(mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
                      UiButton(label: 'Cancel', variant: UiButtonVariant.outline, size: UiSize.sm, onPressed: () => Navigator.pop(context)),
                      UiButton(label: 'Save', size: UiSize.sm, onPressed: () => Navigator.pop(context, 'saved')),
                    ]),
                  );
                  if (mounted) setState(() => _modalResult = r ?? 'dismissed');
                },
              ),
            note('Result: $_modalResult'),
          ]),
          code: '''final result = await showUiModal<String>(
  context: context,
  title: 'Rename project',
  builder: (context) => RenameForm(),
  footerBuilder: (context) => UiButton(label: 'Save', onPressed: () => Navigator.pop(context, 'saved')),
);''',
          api: const [
            ApiRow('builder', 'WidgetBuilder', 'The body; scrolls when it is taller than the dialog.'),
            ApiRow('title', 'String?', 'Header title, also the dialog\'s accessible name. Without it there is no header or close button, so give the dialog a way out in its content.'),
            ApiRow('footerBuilder', 'WidgetBuilder?', 'Actions, right-aligned under a divider.'),
            ApiRow('size', 'UiModalSize', 'Max width: sm 360, md 480, lg 720; full fills the screen.', def: 'md'),
            ApiRow('closeOnBackdrop', 'bool', 'A tap on the dimmed page closes it.', def: 'true'),
            ApiRow('closeOnEscape', 'bool', 'Escape closes it.', def: 'true'),
            ApiRow('glass / radius', 'bool?', 'Frosted panel / rounded corners; default to UiConfig.'),
            ApiRow('useRootNavigator', 'bool', 'Open over everything (true) or in the nearest navigator.', def: 'true'),
          ],
          callbacks: const [
            ApiRow('returns', 'Future<T?>', 'What Navigator.pop(context, value) passed, or null when dismissed.'),
            ApiRow('UiModal', 'widget', 'The dialog itself, for your own routes. UiDialogRoute is the route these functions use.'),
          ],
        ),
        DocSection(
          name: 'Drawer',
          widget: 'showUiDrawer · UiDrawer',
          summary: 'An edge-anchored panel that slides in from side. Like the modal it is its own route: it traps and returns focus, blocks the page, and closes on the back button, Escape or a backdrop tap. On a touch screen it follows a swipe toward its edge and closes when flung or let go past half way. Left and right drawers are up to 360px wide (90% of a phone); top and bottom ones up to 320px tall.',
          demo: row([
            for (final side in UiDrawerSide.values)
              UiButton(
                label: side.name[0].toUpperCase() + side.name.substring(1),
                variant: UiButtonVariant.outline,
                onPressed: () => showUiDrawer<void>(
                  context: context,
                  side: side,
                  title: 'Drawer',
                  builder: (context) => UiText('Slides in from the ${side.name}. Swipe it back toward its edge to close it.'),
                ),
              ),
          ]),
          code: '''showUiDrawer<void>(
  context: context,
  side: UiDrawerSide.right,
  title: 'Filters',
  builder: (context) => FiltersForm(),
);''',
          api: const [
            ApiRow('builder', 'WidgetBuilder', 'The body; scrolls when it is taller than the drawer.'),
            ApiRow('side', 'UiDrawerSide', 'left, right, top, bottom.', def: 'right'),
            ApiRow('title', 'String?', 'Header title, also the accessible name. Without it there is no header or close button.'),
            ApiRow('closeOnBackdrop / closeOnEscape', 'bool', 'As for the modal.', def: 'true'),
            ApiRow('glass / radius', 'bool?', 'Frosted surface / rounded inner corners; default to UiConfig.'),
            ApiRow('UiDrawer.onPointerEnter / onPointerExit', 'VoidCallback?', 'The pointer entered or left the panel (for drawers that close when it leaves).'),
            ApiRow('UiDrawerPeek', 'widget', 'The web modal=false drawer: open, child, drawer, side, title, onClose. Slides over the page without blocking it (no barrier, no route, no focus grab); a hover peek.'),
          ],
        ),
        DocSection(
          name: 'Confirm dialog',
          widget: 'showUiConfirm · UiConfirmDialog',
          summary: 'A yes/no prompt on a small modal, so it traps and returns focus the same way. It completes with true for the confirm button, false for Cancel, and null when dismissed another way (Escape, the backdrop, the close button, back). Normally both buttons sit right-aligned; with destructive the confirm button turns red and Cancel moves to the far left, away from it.',
          demo: row([
            UiButton(
              label: 'Publish',
              variant: UiButtonVariant.outline,
              onPressed: () async {
                final ok = await showUiConfirm(context: context, title: 'Publish now?', message: 'Everyone with the link will see it.', confirmLabel: 'Publish');
                if (mounted) setState(() => _confirmResult = '$ok');
              },
            ),
            UiButton(
              label: 'Delete item',
              variant: UiButtonVariant.destructive,
              onPressed: () async {
                final ok = await showUiConfirm(context: context, title: 'Delete item?', message: 'This cannot be undone.', confirmLabel: 'Delete', destructive: true);
                if (!mounted) return;
                setState(() => _confirmResult = '$ok');
                if (ok ?? false) _toasts.warning('Deleted');
              },
            ),
            note('Answer: $_confirmResult'),
          ]),
          code: '''final ok = await showUiConfirm(
  context: context,
  title: 'Delete item?',
  message: 'This cannot be undone.',
  confirmLabel: 'Delete',
  destructive: true,
);
if (ok == true) delete();''',
          api: const [
            ApiRow('title', 'String', 'Prompt title.', def: "'Are you sure?'"),
            ApiRow('message', 'String', 'Body text.', def: "''"),
            ApiRow('confirmLabel / cancelLabel', 'String', 'Button text.', def: "'Confirm' / 'Cancel'"),
            ApiRow('destructive', 'bool', 'Red confirm button, with Cancel moved to the far left.', def: 'false'),
          ],
          callbacks: const [ApiRow('returns', 'Future<bool?>', 'true: confirmed. false: Cancel pressed. null: dismissed another way.')],
        ),
        DocSection(
          name: 'Backdrop',
          widget: 'UiBackdrop',
          summary: 'The dimmed layer behind an overlay of your own. It fills its parent, fades in, and reports taps so you can close what it sits behind. It does nothing else: focus, Escape and the back button are up to you (the dialogs here use routes, which handle all that). blur also blurs what is behind it.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            SizedBox(
              height: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(t.radius),
                child: Stack(children: [
                  Positioned.fill(
                    child: Container(
                      color: t.surface,
                      padding: EdgeInsets.all(t.space3),
                      child: UiText('Some page content under the backdrop. Tap the backdrop to remove it.', variant: UiTextVariant.caption),
                    ),
                  ),
                  if (_backdrop) Positioned.fill(child: UiBackdrop(blur: true, onTap: () => setState(() => _backdrop = false))),
                ]),
              ),
            ),
            row([UiButton(label: 'Show backdrop', variant: UiButtonVariant.outline, onPressed: () => setState(() => _backdrop = true))]),
          ]),
          code: '''Stack(children: [
  page,
  if (open) Positioned.fill(child: UiBackdrop(blur: true, onTap: close)),
  if (open) MyPanel(),
])''',
          api: const [
            ApiRow('onTap', 'VoidCallback?', 'The backdrop itself was tapped.'),
            ApiRow('blur', 'bool', 'Blur what is behind it as well as dimming it.', def: 'false'),
            ApiRow('semanticLabel', 'String?', 'Set it (e.g. "Close") to expose the backdrop to screen readers as a dismiss control.'),
            ApiRow('opacity', 'Animation<double>?', 'Drive the fade yourself; otherwise it fades in once.'),
          ],
        ),
        DocSection(
          name: 'Bottom sheet',
          widget: 'UiBottomSheet',
          summary: 'A panel resting at the bottom of the screen that is dragged between heights: the mobile stand-in for a sidebar. Put it last in a Stack over the page. Drag or flick the header; dragging the body moves the sheet when the content can\'t use the drag (pulling down at its top, or pushing up while there\'s a taller snap). The handle is a button that steps through the snaps, and ArrowUp/Down on it do the same. Non-modal by default: opening it does not move focus and Tab can leave it. With backdrop it is modal while open: the page dims and a tap on it closes the sheet, focus moves to the handle and stays inside, and screen readers can\'t reach the page. Escape (focus inside) and the back button close it; closing sends focus back where it came from. Focusing a text field inside raises it to its tallest snap on a phone, and while the keyboard is up it rests on top of it.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            row([
              UiButton(label: 'Open half', variant: UiButtonVariant.secondary, onPressed: () => setState(() => _sheetSnap = 1)),
              UiButton(label: 'Open full', variant: UiButtonVariant.ghost, onPressed: () => setState(() => _sheetSnap = 2)),
              UiButton(label: 'With backdrop', variant: UiButtonVariant.outline, onPressed: () => setState(() {
                    _sheetModal = true;
                    _sheetSnap = 1;
                  })),
              note('snap: $_sheetSnap'),
            ]),
            SizedBox(
              height: 420,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(t.radius),
                child: Stack(children: [
                  Positioned.fill(
                    child: Container(
                      color: t.bg,
                      padding: EdgeInsets.all(t.space4),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
                        UiText('Editor', variant: UiTextVariant.h4),
                        UiText('A stand-in page. The sheet rests over its bottom edge.', variant: UiTextVariant.caption),
                      ]),
                    ),
                  ),
                  UiBottomSheet(
                    snaps: const [0, 0.4, 0.9],
                    snap: _sheetSnap,
                    title: 'Layers',
                    backdrop: _sheetModal,
                    actions: UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedAdd01), label: 'Add layer', size: UiSize.sm, onPressed: () => _toasts.info('Layer added')),
                    onSnapChanged: (i) => setState(() {
                      _sheetSnap = i;
                      if (i == 0) _sheetModal = false;
                    }),
                    builder: (context, scroll) => ListView.builder(
                      controller: scroll,
                      padding: EdgeInsets.symmetric(vertical: t.space2),
                      itemCount: 30,
                      itemBuilder: (context, i) => Padding(
                        padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space2),
                        child: UiText('Layer ${i + 1}'),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
          code: '''Stack(children: [
  page,
  UiBottomSheet(
    snaps: const [0, 0.4, 0.9],
    snap: snap,
    onSnapChanged: (i) => setState(() => snap = i),
    title: 'Layers',
    offset: 56, // a toolbar it rests on
    child: LayersList(),
  ),
])''',
          api: const [
            ApiRow('snaps', 'List<double>', 'Resting heights as fractions of the room it has, ascending. A first snap of 0 is closed.', def: '[0, 0.5, 1]'),
            ApiRow('snap / onSnapChanged', 'int / ValueChanged<int>?', 'The index it rests at, and where it came to rest after a drag, the handle, Escape, back or a backdrop tap.', def: '0'),
            ApiRow('child / builder', 'Widget? / (context, ScrollController) => Widget', 'Content in a scroll view the sheet provides, or your own scroll view on the given controller (so a list takes part in dragging).'),
            ApiRow('title', 'String', 'Header title and accessible name. A title, or hasHeader, shows the header row.', def: "''"),
            ApiRow('offset', 'double', 'Px kept free below it, for a toolbar it sits on.', def: '0'),
            ApiRow('topInset', 'double', 'Px kept free above its tallest snap.', def: '0'),
            ApiRow('backdrop', 'bool', 'Modal while open: dims the page, closes on a backdrop tap, moves focus in and traps Tab.', def: 'false'),
            ApiRow('closable', 'bool', 'Close button in the header.', def: 'true'),
            ApiRow('hasHeader', 'bool', 'Show the header row without a title, for the close button and actions.', def: 'false'),
            ApiRow('actions', 'Widget?', 'Header controls.'),
            ApiRow('expandOnFocus', 'bool', 'Rise to the tallest snap when a text field inside gains focus on a touch screen.', def: 'true'),
          ],
          callbacks: const [
            ApiRow('onHeightChanged', 'ValueChanged<double>?', 'Px height once it settles.'),
            ApiRow('onCoverChanged', 'ValueChanged<double>?', 'Px of the screen it takes from the bottom once settled, including what it rests on (offset or the keyboard).'),
            ApiRow('UiBottomSheetState.close()', 'method', 'Close it (snap 0), sending focus back first if it is inside.'),
          ],
        ),
        DocSection(
          name: 'Toast',
          widget: 'UiToastController · UiToastHost',
          summary: 'Transient notifications. Create a UiToastController, put one UiToastHost near the app root (UiApp.builder) so toasts float over every route, then call show(message) or info/success/warning/danger(message, title:) from anywhere; UiToastController.of(context) finds it. Each returns an id; dismiss(id) removes it. Toasts stack at the host\'s position (a corner, or centred on the top or bottom edge), newest last, slide in from that side and back out toward it, can be swiped away sideways, and leave on their own after duration (4 s by default; zero keeps them). The countdown pauses while a finger, the pointer or focus is on a toast and resumes with the time left, at least one more second. Each toast is a live region, so screen readers announce it. For a quick note about something the person just did, like Deleted with Undo, use the snackbar below.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
            row([
              UiButton(label: 'Success', variant: UiButtonVariant.secondary, onPressed: () => _toasts.success('Changes saved', title: 'Success')),
              UiButton(label: 'Error', variant: UiButtonVariant.ghost, onPressed: () => _toasts.danger('Could not connect', title: 'Error')),
              UiButton(
                label: 'With action',
                variant: UiButtonVariant.outline,
                onPressed: () => _toasts.show('Layer deleted', duration: const Duration(seconds: 6), action: UiToastAction(label: 'Undo', run: () => _toasts.success('Restored'))),
              ),
            ]),
            row([
              for (final p in UiToastPosition.values)
                UiButton(
                  label: p.name,
                  size: UiSize.sm,
                  variant: p == _toastPos ? UiButtonVariant.primary : UiButtonVariant.ghost,
                  onPressed: () => setState(() => _toastPos = p),
                ),
            ]),
          ]),
          code: '''final toasts = UiToastController();

UiApp(
  builder: (context, child) => UiToastHost(controller: toasts, position: UiToastPosition.bottomCenter, child: child!),
  home: HomePage(),
);

toasts.success('Saved', title: 'Done');
toasts.show('Hi', duration: Duration.zero); // stays until dismissed
toasts.show('Layer deleted', action: UiToastAction(label: 'Undo', run: undo));''',
          api: const [
            ApiRow('host: controller', 'UiToastController', 'The queue it shows.'),
            ApiRow('host: position', 'UiToastPosition', 'topRight, topLeft, topCenter, bottomRight, bottomLeft, bottomCenter. Toasts slide in from that side.', def: 'bottomRight'),
            ApiRow('host: child', 'Widget?', 'What the toasts float over. Without it the host is just the toast layer.'),
          ],
          callbacks: const [
            ApiRow('show(message, {title, tone, duration, action})', 'int', 'Enqueue; returns the id.'),
            ApiRow('info / success / warning / danger', 'int', 'Shorthands for show() with a tone.'),
            ApiRow('dismiss(id)', 'void', 'Remove a toast.'),
            ApiRow('act(id)', 'void', 'Dismiss the toast and run its action. The action button calls this.'),
            ApiRow('pause(id) / resume(id)', 'void', 'Hold or restart the countdown. The host calls these for fingers, hover and focus.'),
            ApiRow('toasts', 'List<UiToast>', 'The live queue (listen to the controller).'),
            ApiRow('UiToastController.of(context)', 'static', 'The controller of the nearest host.'),
          ],
          shapes: '''enum UiToastTone { info, success, warning, danger }
UiToastAction({required String label, required VoidCallback run})''',
        ),
        DocSection(
          name: 'Snackbar',
          widget: 'UiSnackbarController · UiSnackbarHost · UiSnackbar',
          summary: 'A short note about something the person just did, with at most one action: Deleted with Undo, Grouped, Keyframe added. It is a compact inverted bar centred at the bottom of the screen, the one the form builder uses. Only one shows at a time; a new one replaces it. Put one UiSnackbarHost near the app root (UiApp.builder) and call show(message) on its controller; UiSnackbarController.of(context) finds it. It leaves after 4 s, or 10 s when it has an action so there is time to reach Undo, and holds while a finger, the pointer or focus is on it. offset lifts it above a bottom bar; it also stays above the keyboard. On touch it is one touch target (48dp) tall. Each notice is a live region, so screen readers announce it. Use toasts instead for messages that should stack or carry a tone, such as errors. Editors that place it themselves (the form builder does) can use the bare UiSnackbar.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
            row([
              UiButton(label: 'Simple', variant: UiButtonVariant.secondary, onPressed: () => _snacks.show('Grouped')),
              UiButton(
                label: 'Deleted, with Undo',
                variant: UiButtonVariant.outline,
                onPressed: () => _snacks.show('Deleted “Title”', action: UiSnackbarAction(label: 'Undo', run: () => _snacks.show('Restored “Title”'))),
              ),
              UiButton(
                label: 'With a title',
                variant: UiButtonVariant.ghost,
                onPressed: () => _snacks.show('Move or delete that keyframe to trim further.', title: 'Stopped at a keyframe'),
              ),
            ]),
            UiSnackbar(message: 'Deleted “Title”', actionLabel: 'Undo', onAction: () {}),
          ]),
          code: '''final snackbar = UiSnackbarController();

UiApp(
  builder: (context, child) => UiSnackbarHost(controller: snackbar, offset: dockHeight, child: child!),
  home: HomePage(),
);

snackbar.show('Grouped');
snackbar.show('Deleted “Title”', action: UiSnackbarAction(label: 'Undo', run: store.undo));

// or just the bar, positioned by you:
UiSnackbar(message: 'Deleted “Title”', actionLabel: 'Undo', onAction: undo)''',
          api: const [
            ApiRow('host: controller', 'UiSnackbarController', 'The notice it shows.'),
            ApiRow('host: offset', 'double', 'Extra space below it, e.g. a bottom bar\'s height. The safe area and keyboard are added for you.', def: '0'),
            ApiRow('host: child', 'Widget?', 'What it floats over. Without it the host is just the layer.'),
            ApiRow('UiSnackbar: message / title', 'String / String?', 'The text, with an optional bold first line.'),
            ApiRow('UiSnackbar: actionLabel / onAction', 'String? / VoidCallback?', 'Shows the link-style action button.'),
          ],
          callbacks: const [
            ApiRow('show(message, {title, action, duration})', 'int', 'Show a notice, replacing any current one; returns its id. duration defaults to 4 s, or 10 s with an action; zero keeps it.'),
            ApiRow('dismiss([id])', 'void', 'Hide it; with an id, only if that notice is still the one showing.'),
            ApiRow('act()', 'void', 'Dismiss and run the action. The action button calls this.'),
            ApiRow('pause() / resume()', 'void', 'Hold or restart the countdown. The host calls these for fingers, hover and focus.'),
            ApiRow('current', 'UiSnack?', 'The notice showing now (listen to the controller).'),
            ApiRow('UiSnackbarController.of(context)', 'static', 'The controller of the nearest host.'),
          ],
          shapes: 'UiSnackbarAction({required String label, required VoidCallback run})',
        ),
        DocSection(
          name: 'Command palette',
          widget: 'showUiCommandPalette · UiCommand',
          summary: 'A search-and-run list of commands. On a phone it is a full-screen search page with the keyboard up; on a tablet or desktop the web\'s centred dialog near the top. Typing filters by case-insensitive substring over label, group and keywords. ArrowUp/Down move the highlight while the field keeps focus, Enter (or the keyboard\'s search key) runs it, and so does a tap; running closes it. Escape, the back button, the back arrow or a backdrop tap close it. Focus is trapped while it is open and goes back where it was afterwards. It binds no shortcut of its own: open it from a button, or from a Ctrl/Cmd+K handler on hardware keyboards.',
          demo: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyK, control: true): _openPalette,
              const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _openPalette,
            },
            child: row([
              UiButton(label: 'Open command palette', icon: const UiIcon(HugeIcons.strokeRoundedSearch01), variant: UiButtonVariant.outline, onPressed: _openPalette),
              note(_paletteResult),
            ]),
          ),
          code: '''final command = await showUiCommandPalette(
  context: context,
  commands: const [
    UiCommand(label: 'New file', value: 'new', group: 'File', icon: UiIcon(HugeIcons.strokeRoundedFileAdd), shortcut: 'Ctrl+N'),
    UiCommand(label: 'Toggle dark mode', value: 'theme', group: 'View', keywords: 'theme night'),
  ],
);
if (command != null) run(command.value);''',
          api: const [
            ApiRow('commands', 'List<UiCommand>', 'Everything it can run.'),
            ApiRow('onRun', 'ValueChanged<UiCommand>?', 'A command was chosen; it closes after this.'),
            ApiRow('placeholder', 'String', 'Search field placeholder.', def: "'Type a command or search…'"),
            ApiRow('fullScreenBelow', 'double', 'Screens narrower than this get the full-screen search page.', def: '600'),
            ApiRow('glass / radius', 'bool?', 'Frosted panel / rounded corners (dialog form); default to UiConfig.'),
          ],
          callbacks: const [ApiRow('returns', 'Future<UiCommand?>', 'The command that ran, or null when it was closed.')],
          shapes: 'UiCommand({required String label, required String value, String? group, Widget? icon, String? shortcut, String? keywords})',
        ),
      ],
    );

    return OverlayPortal(
      controller: _toastLayer,
      overlayChildBuilder: (context) => Stack(children: [
        Positioned.fill(child: UiToastHost(controller: _toasts, position: _toastPos)),
        Positioned.fill(child: UiSnackbarHost(controller: _snacks)),
      ]),
      child: page,
    );
  }
}
