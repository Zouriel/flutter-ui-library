import 'dart:ui' show PointerDeviceKind, SemanticsRole;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';
import 'anchored.dart';
import 'panel.dart';

/// One entry in a [UiMenu] or [UiContextMenu], the web `UiMenuItem`.
@immutable
class UiMenuItem {
  const UiMenuItem({required this.label, required this.value, this.disabled = false, this.danger = false, this.icon});

  final String label;

  /// Identifies the item to your handler.
  final String value;

  /// Shown dimmed, can't be chosen, and skipped by the arrow keys.
  final bool disabled;

  /// Destructive action: drawn in the danger colour.
  final bool danger;

  /// Optional leading icon (Flutter extra; the web items are text only).
  final UiIconData? icon;
}

/// Builds the widget that opens a menu or popover: call [toggle] from its `onPressed`.
typedef UiOverlayTriggerBuilder = Widget Function(BuildContext context, VoidCallback toggle, bool open);

/// `ui-menu`: a dropdown menu of actions anchored to a trigger.
///
/// [builder] draws the trigger and gets a `toggle` callback for it. Opening moves focus to the
/// first enabled item; ArrowUp/Down (wrapping), Home and End move between items, Enter or Space
/// chooses one. Choosing an item or pressing Escape closes the menu and gives focus back to the
/// trigger; Tab closes it and moves on from the trigger; a tap outside closes it. It opens below
/// the trigger, flips above when there is no room, and lines up with the trigger's other edge (or
/// shifts) to stay on screen.
///
/// Uncontrolled by default; pass [open] and [onOpenChanged] to control it.
class UiMenu extends StatefulWidget {
  const UiMenu({
    super.key,
    required this.items,
    required this.onSelect,
    required this.builder,
    this.open,
    this.onOpenChanged,
    this.placement = UiPlacement.bottomStart,
    this.glass,
    this.radius,
  });

  final List<UiMenuItem> items;
  final ValueChanged<UiMenuItem> onSelect;
  final UiOverlayTriggerBuilder builder;
  final bool? open;
  final ValueChanged<bool>? onOpenChanged;
  final UiPlacement placement;
  final bool? glass;
  final bool? radius;

  @override
  State<UiMenu> createState() => _UiMenuState();
}

/// Open state shared by the trigger-anchored overlays: uncontrolled, or driven by `open`.
mixin _AnchoredOpenState<W extends StatefulWidget> on State<W> {
  final OverlayPortalController portal = OverlayPortalController();
  bool _open = false;

  /// What had focus when it opened: where Escape (or choosing) sends focus back.
  FocusNode? returnTo;

  bool? get controlledOpen;
  ValueChanged<bool>? get openChanged;

  bool get isOpen => controlledOpen ?? _open;

  void setOpen(bool v) {
    if (v == isOpen) return;
    if (v) returnTo = FocusManager.instance.primaryFocus;
    // Rebuild either way, so the portal follows a controlled value that didn't change.
    setState(() => _open = v);
    openChanged?.call(v);
  }

  void restoreFocus() {
    final n = returnTo;
    returnTo = null;
    if (n != null && n.context != null && n.canRequestFocus) n.requestFocus();
  }

  /// Keeps the portal in step with [isOpen] after every build.
  void syncPortal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (isOpen && !portal.isShowing) {
        returnTo ??= FocusManager.instance.primaryFocus;
        portal.show();
      } else if (!isOpen && portal.isShowing) {
        portal.hide();
      }
    });
  }
}

class _UiMenuState extends State<UiMenu> with _AnchoredOpenState<UiMenu> {
  @override
  bool? get controlledOpen => widget.open;
  @override
  ValueChanged<bool>? get openChanged => widget.onOpenChanged;

  void _close({bool restore = true}) {
    // Take the items out now, so focus moves (Tab, restore) never land back on them.
    if (portal.isShowing) portal.hide();
    setOpen(false);
    if (restore) restoreFocus();
  }

  @override
  Widget build(BuildContext context) {
    syncPortal();
    return UiAnchoredOverlay(
      controller: portal,
      placement: widget.placement,
      minWidth: 180,
      onDismiss: () => _close(restore: false),
      panelBuilder: (context, anchor) => UiMenuPanel(
        items: widget.items,
        glass: widget.glass,
        radius: widget.radius,
        onSelect: (item) {
          _close();
          widget.onSelect(item);
        },
        onClose: _close,
        onTab: (backwards) {
          final n = returnTo;
          _close();
          // Like the browser's own Tab from the trigger: move on from there, once the items are gone.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (n != null && n.context != null) backwards ? n.previousFocus() : n.nextFocus();
          });
        },
      ),
      child: widget.builder(context, () => setOpen(!isOpen), isOpen),
    );
  }
}

/// The list of items inside a menu (the web `.ui-menu` and `ui-context-menu-panel`). Focuses the
/// first enabled item when it appears; handles the arrow keys, Home, End, Escape and Tab.
class UiMenuPanel extends StatefulWidget {
  const UiMenuPanel({
    super.key,
    required this.items,
    required this.onSelect,
    required this.onClose,
    this.onTab,
    this.glass,
    this.radius,
    this.autofocus = true,
    this.origin = Alignment.topLeft,
  });

  final List<UiMenuItem> items;
  final ValueChanged<UiMenuItem> onSelect;

  /// Escape: close and give focus back.
  final VoidCallback onClose;

  /// Tab (false) or Shift+Tab (true). Defaults to [onClose].
  final ValueChanged<bool>? onTab;
  final bool? glass;
  final bool? radius;
  final bool autofocus;
  final Alignment origin;

  @override
  State<UiMenuPanel> createState() => UiMenuPanelState();
}

class UiMenuPanelState extends State<UiMenuPanel> {
  final List<FocusNode> _nodes = [];

  void _syncNodes() {
    while (_nodes.length < widget.items.length) {
      _nodes.add(FocusNode(debugLabel: 'UiMenuItem ${_nodes.length}'));
    }
    while (_nodes.length > widget.items.length) {
      _nodes.removeLast().dispose();
    }
  }

  List<int> get _enabled => [for (var i = 0; i < widget.items.length; i++) if (!widget.items[i].disabled) i];

  /// Puts focus on the first enabled item.
  void focusFirst() {
    final e = _enabled;
    if (e.isNotEmpty) _nodes[e.first].requestFocus();
  }

  @override
  void initState() {
    super.initState();
    _syncNodes();
    if (widget.autofocus) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? focusFirst() : null);
  }

  @override
  void didUpdateWidget(UiMenuPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncNodes();
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
    if (k == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.tab) {
      final back = HardwareKeyboard.instance.isShiftPressed;
      (widget.onTab ?? (_) => widget.onClose())(back);
      return KeyEventResult.handled;
    }
    final e2 = _enabled;
    if (e2.isEmpty) return KeyEventResult.ignored;
    final cur = e2.indexWhere((i) => _nodes[i].hasPrimaryFocus);
    int? next;
    if (k == LogicalKeyboardKey.arrowDown) {
      next = (cur + 1) % e2.length;
    } else if (k == LogicalKeyboardKey.arrowUp) {
      next = cur < 0 ? e2.length - 1 : (cur - 1 + e2.length) % e2.length;
    } else if (k == LogicalKeyboardKey.home) {
      next = 0;
    } else if (k == LogicalKeyboardKey.end) {
      next = e2.length - 1;
    }
    if (next == null) return KeyEventResult.ignored;
    _nodes[e2[next]].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.menu,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 180),
          child: UiFloatingPanel(
            glass: widget.glass,
            radius: widget.radius,
            origin: widget.origin,
            padding: EdgeInsets.all(t.space1),
            child: SingleChildScrollView(
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.items.length; i++)
                      _MenuItemTile(item: widget.items[i], focusNode: _nodes[i], onTap: () => widget.onSelect(widget.items[i])),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  const _MenuItemTile({required this.item, required this.focusNode, required this.onTap});

  final UiMenuItem item;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final touch = uiTouchPlatform(context);
    return UiInteractive(
      onTap: onTap,
      enabled: !item.disabled,
      focusNode: focusNode,
      padTouchTarget: false,
      pressScale: false,
      builder: (context, s) {
        final fg = item.danger ? t.danger : t.text;
        final lit = s.hovered || s.focused || s.pressed;
        final fill = !lit ? null : item.danger ? uiMix(t.danger, 0.12, const Color(0x00000000)) : t.elevatedHover;
        return AnimatedOpacity(
          opacity: s.disabled ? 0.5 : 1,
          duration: t.motionFast,
          child: AnimatedContainer(
            duration: context.uiAnimate ? t.motionFast : Duration.zero,
            curve: t.easeStandard,
            constraints: BoxConstraints(minHeight: touch ? uiMinTouchTarget : 0),
            padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(theme.radius(t.radiusXs)),
              // Keyboard focus also gets an inset ring, so it never reads like a hover.
              border: Border.all(color: s.focused ? t.borderFocus : const Color(0x00000000), width: 2),
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: fg, size: 16),
              child: DefaultTextStyle.merge(
                style: theme.typography.body.copyWith(fontSize: t.fontSizeSm, height: 1.35, color: fg),
                child: Row(
                  spacing: t.space2,
                  children: [
                    if (item.icon != null) UiIcon(item.icon!),
                    Flexible(child: Text(item.label)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// `uiContextMenu`: a menu opened at the pointer over [child]. Right-click (secondary tap) opens
/// it on devices with a mouse; long-press opens it on touch screens; the keyboard's Menu key or
/// Shift+F10 opens it at the centre of [child]. It flips and shifts so it never runs off screen.
/// The first item gets focus; Escape or choosing gives focus back to what had it before; a tap
/// outside or scrolling closes it. Screen readers get it as the long-press action ("Show menu").
class UiContextMenu extends StatefulWidget {
  const UiContextMenu({super.key, required this.items, required this.onSelect, required this.child, this.enabled = true, this.semanticHint = 'Show menu'});

  final List<UiMenuItem> items;
  final ValueChanged<UiMenuItem> onSelect;
  final Widget child;
  final bool enabled;
  final String semanticHint;

  @override
  State<UiContextMenu> createState() => _UiContextMenuState();
}

class _UiContextMenuState extends State<UiContextMenu> {
  final OverlayPortalController _portal = OverlayPortalController();
  Offset _at = Offset.zero;
  FocusNode? _returnTo;
  ScrollPosition? _scroll;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = Scrollable.maybeOf(context)?.position;
    if (s != _scroll) {
      _scroll?.removeListener(_onScroll);
      _scroll = s?..addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scroll?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (_portal.isShowing) _close();
  }

  void _openAt(Offset local) {
    if (!widget.enabled || widget.items.isEmpty) return;
    _returnTo = _portal.isShowing ? _returnTo : FocusManager.instance.primaryFocus;
    setState(() {
      _at = local;
      if (_portal.isShowing) _portal.hide();
      _portal.show();
    });
  }

  void _openCentered() {
    final box = context.findRenderObject() as RenderBox?;
    _openAt(box == null ? Offset.zero : box.size.center(Offset.zero));
  }

  void _close({bool restore = false}) {
    if (_portal.isShowing) setState(_portal.hide);
    final n = _returnTo;
    _returnTo = null;
    if (restore && n != null && n.context != null && n.canRequestFocus) n.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final child = Semantics(
      container: true,
      onLongPressHint: widget.enabled ? widget.semanticHint : null,
      onLongPress: widget.enabled ? _openCentered : null,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.contextMenu): _openCentered,
          const SingleActivator(LogicalKeyboardKey.f10, shift: true): _openCentered,
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          excludeFromSemantics: true,
          onSecondaryTapUp: (d) => _openAt(d.localPosition),
          // Long-press is the touch gesture; a mouse has the right button.
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            excludeFromSemantics: true,
            supportedDevices: const {PointerDeviceKind.touch, PointerDeviceKind.stylus, PointerDeviceKind.invertedStylus, PointerDeviceKind.unknown},
            onLongPressStart: (d) {
              HapticFeedback.vibrate();
              _openAt(d.localPosition);
            },
            child: widget.child,
          ),
        ),
      ),
    );
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      child: child,
      overlayChildBuilder: (context, info) {
        final p = MatrixUtils.transformPoint(info.childPaintTransform, _at);
        final mq = MediaQuery.of(context);
        final safe = EdgeInsets.fromLTRB(mq.padding.left + 8, mq.padding.top + 8, mq.padding.right + 8, mq.padding.bottom + mq.viewInsets.bottom + 8);
        return Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: UiAnchorLayout(anchor: Rect.fromLTWH(p.dx, p.dy, 0, 0), placement: UiPlacement.bottomStart, gap: 0, safe: safe, textDirection: Directionality.of(context)),
            child: TapRegion(
              onTapOutside: (_) => _close(),
              child: UiMenuPanel(
                items: widget.items,
                onSelect: (item) {
                  _close(restore: true);
                  widget.onSelect(item);
                },
                onClose: () => _close(restore: true),
              ),
            ),
          ),
        );
      },
    );
  }
}
