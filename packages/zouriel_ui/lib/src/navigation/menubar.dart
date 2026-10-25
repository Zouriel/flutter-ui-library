import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../overlay/anchored.dart';
import '../theme/theme.dart';

/// A command in a [UiMenubarMenu].
@immutable
class UiMenubarItem {
  const UiMenubarItem({required this.label, required this.value, this.disabled = false});
  final String label;
  final String value;
  final bool disabled;
}

/// A top-level menu of a [UiMenubar].
@immutable
class UiMenubarMenu {
  const UiMenubarMenu({required this.label, required this.items});
  final String label;
  final List<UiMenubarItem> items;
}

/// `ui-menubar`: an application menu bar ("File  Edit  View") with one dropdown open at a time.
/// [onSelect] reports the chosen item.
///
/// Narrower than [breakpoint] (a phone) the bar becomes a single overflow button for an app bar's
/// actions: it opens one panel with every menu as a titled group. The width is the space it is given,
/// or the screen's when that is unbounded (inside a `Row`).
///
/// Keyboard, as on the web: Left/Right move between the top items (and between open menus); Down,
/// Enter or Space open a menu and focus its first item; inside a menu Up/Down, Home and End move,
/// Escape closes it and returns focus to its top item, and Tab closes it.
class UiMenubar extends StatefulWidget {
  const UiMenubar({super.key, required this.menus, this.onSelect, this.breakpoint = 600, this.overflowLabel});

  final List<UiMenubarMenu> menus;
  final ValueChanged<UiMenubarItem>? onSelect;

  /// Width below which the bar collapses into an overflow button.
  final double breakpoint;

  /// Accessible name of the overflow button.
  /// [UiStrings.menu] when null.
  final String? overflowLabel;

  @override
  State<UiMenubar> createState() => _UiMenubarState();
}

class _UiMenubarState extends State<UiMenubar> {
  int? _open;
  bool _overflowOpen = false;
  final List<FocusNode> _tops = [];
  final List<OverlayPortalController> _controllers = [];
  final OverlayPortalController _overflow = OverlayPortalController();
  final FocusNode _overflowNode = FocusNode(debugLabel: 'menubar overflow');

  void _sync() {
    while (_tops.length < widget.menus.length) {
      _tops.add(FocusNode(debugLabel: 'menubar top ${_tops.length}'));
      _controllers.add(OverlayPortalController());
    }
  }

  @override
  void dispose() {
    for (final n in _tops) {
      n.dispose();
    }
    _overflowNode.dispose();
    super.dispose();
  }

  void _setOpen(int? i) {
    if (i == _open) return;
    if (_open != null) _controllers[_open!].hide();
    setState(() => _open = i);
    if (i != null) _controllers[i].show();
  }

  void _closeTo(int i) {
    _setOpen(null);
    _tops[i].requestFocus();
  }

  int _step(int i, int delta) => (i + delta + widget.menus.length) % widget.menus.length;

  KeyEventResult _onTopKey(int i, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.arrowLeft) {
      final next = _step(i, k == LogicalKeyboardKey.arrowRight ? 1 : -1);
      _tops[next].requestFocus();
      if (_open != null) _setOpen(next);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown) {
      if (_open != i) _setOpen(i);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _choose(UiMenubarItem item, {int? from}) {
    widget.onSelect?.call(item);
    if (from != null) {
      _closeTo(from);
    } else {
      _closeOverflow();
    }
  }

  void _closeOverflow({bool refocus = true}) {
    _overflow.hide();
    setState(() => _overflowOpen = false);
    if (refocus) _overflowNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    final t = context.ui;
    return LayoutBuilder(builder: (context, box) {
      // In a Row (an app bar's actions) the width is unbounded: decide by the screen instead.
      final width = box.maxWidth.isFinite ? box.maxWidth : MediaQuery.sizeOf(context).width;
      if (width < widget.breakpoint) return _buildOverflow(context);
      return Semantics(
        container: true,
        explicitChildNodes: true,
        role: SemanticsRole.menuBar,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(context.uiTheme.radius())),
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 2, children: [
            for (var i = 0; i < widget.menus.length; i++)
              UiAnchoredOverlay(
                controller: _controllers[i],
                placement: UiPlacement.bottomStart,
                onDismiss: () {
                  if (_open == i) _setOpen(null);
                },
                panelBuilder: (context, anchor) => _MenuPanel(
                  label: widget.menus[i].label,
                  entries: [for (final it in widget.menus[i].items) _Entry.item(it)],
                  onChoose: (it) => _choose(it, from: i),
                  onClose: () => _closeTo(i),
                  onSide: (delta) {
                    final next = _step(i, delta);
                    _tops[next].requestFocus();
                    _setOpen(next);
                  },
                ),
                child: MouseRegion(
                  onEnter: (_) {
                    if (_open != null && _open != i) _setOpen(i);
                  },
                  child: Focus(
                    canRequestFocus: false,
                    includeSemantics: false,
                    skipTraversal: true,
                    onKeyEvent: (node, e) => _onTopKey(i, e),
                    child: _TopItem(
                      label: widget.menus[i].label,
                      open: _open == i,
                      focusNode: _tops[i],
                      onTap: () => _setOpen(_open == i ? null : i),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );
    });
  }

  Widget _buildOverflow(BuildContext context) {
    final t = context.ui;
    return UiAnchoredOverlay(
      controller: _overflow,
      placement: UiPlacement.bottomEnd,
      onDismiss: () => _closeOverflow(refocus: false),
      panelBuilder: (context, anchor) => _MenuPanel(
        label: widget.overflowLabel ?? context.uiStrings.menu,
        entries: [
          for (final m in widget.menus) ...[
            _Entry.header(m.label),
            for (final it in m.items) _Entry.item(it),
          ],
        ],
        onChoose: _choose,
        onClose: _closeOverflow,
      ),
      child: UiInteractive(
        focusNode: _overflowNode,
        onTap: () {
          if (_overflowOpen) {
            _closeOverflow(refocus: false);
          } else {
            _overflow.show();
            setState(() => _overflowOpen = true);
          }
        },
        builder: (context, s) => Semantics(
          label: widget.overflowLabel ?? context.uiStrings.menu,
          expanded: _overflowOpen,
          child: ExcludeSemantics(
            child: AnimatedContainer(
              duration: t.motionFast,
              width: t.sizeMd,
              height: t.sizeMd,
              decoration: BoxDecoration(
                color: s.hovered || s.pressed || _overflowOpen ? t.surfaceHover : null,
                borderRadius: BorderRadius.circular(context.uiTheme.radius()),
                boxShadow: s.focused ? t.focusRing : const [],
              ),
              child: Center(child: UiIcon(HugeIcons.strokeRoundedMoreVertical, size: 18, color: t.text)),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopItem extends StatelessWidget {
  const _TopItem({required this.label, required this.open, required this.focusNode, required this.onTap});
  final String label;
  final bool open;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    return UiInteractive(
      onTap: onTap,
      focusNode: focusNode,
      button: false,
      pressScale: false,
      padTouchTarget: false,
      builder: (context, s) => Semantics(
        role: SemanticsRole.menuItem,
        expanded: open,
        child: AnimatedContainer(
          duration: context.uiAnimate ? t.motionFast : Duration.zero,
          curve: t.easeStandard,
          constraints: BoxConstraints(minHeight: touch ? uiMinTouchTarget : 0),
          padding: EdgeInsets.symmetric(vertical: t.space1, horizontal: t.space3),
          decoration: BoxDecoration(
            color: s.hovered || s.pressed || open ? t.surfaceHover : null,
            borderRadius: BorderRadius.circular(t.radiusXs),
            boxShadow: s.focused ? t.focusRing : const [],
          ),
          // Factors of 1: centred within the min height, never stretched to the parent's size.
          child: Align(widthFactor: 1, heightFactor: 1, child: Text(label, style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.35))),
        ),
      ),
    );
  }
}

/// A row in a menu panel: a command, or (in the overflow panel) a menu's title.
class _Entry {
  const _Entry.item(UiMenubarItem this.item) : header = null;
  const _Entry.header(String this.header) : item = null;
  final UiMenubarItem? item;
  final String? header;
}

class _MenuPanel extends StatefulWidget {
  const _MenuPanel({required this.label, required this.entries, required this.onChoose, required this.onClose, this.onSide});
  final String label;
  final List<_Entry> entries;
  final ValueChanged<UiMenubarItem> onChoose;
  final VoidCallback onClose;

  /// Left/Right: move to the neighbouring menu (menubar only).
  final ValueChanged<int>? onSide;

  @override
  State<_MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<_MenuPanel> {
  late final List<FocusNode> _nodes = [for (final e in widget.entries) if (e.item != null) FocusNode(debugLabel: 'menu ${e.item!.label}')];

  List<FocusNode> get _enabled {
    final out = <FocusNode>[];
    var n = 0;
    for (final e in widget.entries) {
      if (e.item == null) continue;
      if (!e.item!.disabled) out.add(_nodes[n]);
      n++;
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _enabled.isNotEmpty) _enabled.first.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.tab) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (widget.onSide != null && (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.arrowLeft)) {
      widget.onSide!(k == LogicalKeyboardKey.arrowRight ? 1 : -1);
      return KeyEventResult.handled;
    }
    final els = _enabled;
    if (els.isEmpty) return KeyEventResult.ignored;
    final at = els.indexWhere((n) => n.hasFocus);
    int? to;
    if (k == LogicalKeyboardKey.arrowDown) to = (at + 1) % els.length;
    if (k == LogicalKeyboardKey.arrowUp) to = at < 0 ? els.length - 1 : (at - 1 + els.length) % els.length;
    if (k == LogicalKeyboardKey.home) to = 0;
    if (k == LogicalKeyboardKey.end) to = els.length - 1;
    if (to == null) return KeyEventResult.ignored;
    els[to].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final rows = <Widget>[];
    var n = 0;
    for (var i = 0; i < widget.entries.length; i++) {
      final e = widget.entries[i];
      if (e.header != null) {
        rows.add(Padding(
          padding: EdgeInsets.fromLTRB(t.space3, i == 0 ? t.space1 : t.space3, t.space3, t.space1),
          child: Semantics(
            header: true,
            child: Text(e.header!.toUpperCase(), style: context.uiText.code.copyWith(fontSize: 11, letterSpacing: 11 * 0.16, color: t.textMuted, height: 1.35)),
          ),
        ));
      } else {
        final item = e.item!;
        rows.add(_MenuItem(item: item, focusNode: _nodes[n++], onTap: () => widget.onChoose(item)));
      }
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.menu,
      label: widget.label,
      child: Focus(
        canRequestFocus: false,
        includeSemantics: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: Container(
          constraints: const BoxConstraints(minWidth: 180),
          decoration: BoxDecoration(
            color: t.surfaceRaised,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(context.uiTheme.radius()),
            boxShadow: t.shadow2,
          ),
          child: IntrinsicWidth(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(t.space1),
              child: DefaultTextStyle(
                style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.35),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.item, required this.focusNode, required this.onTap});
  final UiMenubarItem item;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    return UiInteractive(
      onTap: onTap,
      enabled: !item.disabled,
      focusNode: focusNode,
      button: false,
      pressScale: false,
      padTouchTarget: false,
      builder: (context, s) => Semantics(
        role: SemanticsRole.menuItem,
        child: Opacity(
          opacity: s.disabled ? 0.5 : 1,
          child: AnimatedContainer(
            duration: context.uiAnimate ? t.motionFast : Duration.zero,
            curve: t.easeStandard,
            constraints: BoxConstraints(minHeight: touch ? uiMinTouchTarget : 0),
            padding: EdgeInsets.symmetric(vertical: t.space2, horizontal: t.space3),
            decoration: BoxDecoration(
              color: s.hovered || s.pressed || s.focused ? t.elevatedHover : null,
              borderRadius: BorderRadius.circular(t.radiusXs),
            ),
            foregroundDecoration: s.focused
                ? BoxDecoration(border: Border.all(color: t.borderFocus, width: 2), borderRadius: BorderRadius.circular(t.radiusXs))
                : null,
            child: Align(alignment: AlignmentDirectional.centerStart, widthFactor: 1, heightFactor: 1, child: Text(item.label, style: TextStyle(color: t.text))),
          ),
        ),
      ),
    );
  }
}
