import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../overlay/anchored.dart';
import '../theme/theme.dart';
import 'button.dart';

/// One action in a [UiDropdownButton] menu.
@immutable
class UiDropdownItem<T> {
  const UiDropdownItem({required this.label, required this.value, this.icon, this.disabled = false, this.danger = false});
  final String label;
  final T value;
  final Widget? icon;

  /// Shown dimmed; never selected.
  final bool disabled;

  /// Drawn in the danger colour (delete, remove).
  final bool danger;
}

/// Owns an action menu anchored to a trigger: opening focuses the first enabled item, ArrowUp/Down
/// (wrapping), Home and End move, Enter chooses, Escape closes and returns focus to the trigger, Tab
/// or a tap outside closes. The menu flips and shifts to stay on screen ([UiAnchoredOverlay]).
///
/// [builder] draws the anchor; call `toggle` from the trigger, and give the trigger `triggerFocus` so
/// focus can go back to it. Shared by [UiDropdownButton] and [UiSplitButton].
class UiDropdownMenuAnchor<T> extends StatefulWidget {
  const UiDropdownMenuAnchor({super.key, required this.items, required this.onSelected, required this.builder, this.onOpenChanged});

  final List<UiDropdownItem<T>> items;
  final ValueChanged<UiDropdownItem<T>>? onSelected;
  final Widget Function(BuildContext context, bool open, VoidCallback toggle, FocusNode triggerFocus) builder;
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<UiDropdownMenuAnchor<T>> createState() => _UiDropdownMenuAnchorState<T>();
}

class _UiDropdownMenuAnchorState<T> extends State<UiDropdownMenuAnchor<T>> {
  final _controller = OverlayPortalController();
  final _trigger = FocusNode(debugLabel: 'dropdown trigger');
  final List<FocusNode> _nodes = [];

  @override
  void dispose() {
    _trigger.dispose();
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  List<int> get _enabled => [for (var i = 0; i < widget.items.length; i++) if (!widget.items[i].disabled) i];

  void _syncNodes() {
    while (_nodes.length < widget.items.length) {
      _nodes.add(FocusNode(debugLabel: 'menu item ${_nodes.length}'));
    }
    while (_nodes.length > widget.items.length) {
      _nodes.removeLast().dispose();
    }
  }

  void _open() {
    _controller.show();
    setState(() {});
    widget.onOpenChanged?.call(true);
    SchedulerBinding.instance.addPostFrameCallback((_) => _focusAt(0));
  }

  void _close({bool refocus = true}) {
    if (!_controller.isShowing) return;
    _controller.hide();
    if (mounted) setState(() {});
    widget.onOpenChanged?.call(false);
    if (refocus) _trigger.requestFocus();
  }

  void _toggle() => _controller.isShowing ? _close() : _open();

  /// Focuses the [k]th enabled item (negative counts from the end, wrapping).
  void _focusAt(int k) {
    final en = _enabled;
    if (en.isEmpty || !mounted) return;
    _nodes[en[(k % en.length + en.length) % en.length]].requestFocus();
  }

  void _choose(UiDropdownItem<T> item) {
    if (item.disabled) return;
    _close();
    widget.onSelected?.call(item);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final en = _enabled;
    final at = en.indexWhere((i) => _nodes[i].hasFocus);
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      _focusAt(at + 1);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _focusAt(at < 0 ? -1 : at - 1);
    } else if (k == LogicalKeyboardKey.home) {
      _focusAt(0);
    } else if (k == LogicalKeyboardKey.end) {
      _focusAt(-1);
    } else if (k == LogicalKeyboardKey.tab) {
      _close();
      return KeyEventResult.ignored;
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    _syncNodes();
    return UiAnchoredOverlay(
      controller: _controller,
      onDismiss: _close,
      panelBuilder: (context, anchor) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: _MenuPanel<T>(items: widget.items, nodes: _nodes, onChoose: _choose),
      ),
      child: widget.builder(context, _controller.isShowing, _toggle, _trigger),
    );
  }
}

class _MenuPanel<T> extends StatelessWidget {
  const _MenuPanel({required this.items, required this.nodes, required this.onChoose});
  final List<UiDropdownItem<T>> items;
  final List<FocusNode> nodes;
  final ValueChanged<UiDropdownItem<T>> onChoose;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final r = context.uiTheme.config.radius ? t.radius : 0.0;
    final touch = uiTouchPlatform(context);
    return Semantics(
      container: true,
      role: SemanticsRole.menu,
      explicitChildNodes: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 180, maxWidth: 320),
        padding: EdgeInsets.all(t.space1),
        decoration: BoxDecoration(color: t.surfaceRaised, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(r), boxShadow: t.shadow2),
        child: SingleChildScrollView(
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++)
                  UiInteractive(
                    focusNode: nodes[i],
                    enabled: !items[i].disabled,
                    onTap: items[i].disabled ? null : () => onChoose(items[i]),
                    padTouchTarget: false,
                    pressScale: false,
                    builder: (context, s) {
                      final fg = items[i].danger ? t.danger : t.text;
                      final hot = s.hovered || s.pressed || s.focused;
                      return Semantics(
                        role: SemanticsRole.menuItem,
                        child: AnimatedOpacity(
                          opacity: s.disabled ? 0.5 : 1,
                          duration: t.motionFast,
                          child: Container(
                            constraints: BoxConstraints(minHeight: touch ? uiMinTouchTarget : 0),
                            padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
                            alignment: AlignmentDirectional.centerStart,
                            decoration: BoxDecoration(color: hot ? t.elevatedHover : null, borderRadius: BorderRadius.circular(t.radiusXs)),
                            foregroundDecoration: s.focused
                                ? BoxDecoration(border: Border.all(color: t.borderFocus, width: 2), borderRadius: BorderRadius.circular(t.radiusXs))
                                : null,
                            child: IconTheme.merge(
                              data: IconThemeData(color: fg, size: 16),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: t.space2,
                                children: [
                                  ?items[i].icon,
                                  Flexible(
                                    child: Text(items[i].label, maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.35, color: fg)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `ui-dropdown-button`: a button that opens a menu of actions. Pass [items] and [onSelected]
/// (disabled items never fire). Null [onSelected] disables the trigger. The trigger is a [UiButton]
/// with a chevron, announced as expanded while the menu is open.
class UiDropdownButton<T> extends StatelessWidget {
  const UiDropdownButton({
    super.key,
    required this.label,
    required this.items,
    required this.onSelected,
    this.icon,
    this.variant = UiButtonVariant.secondary,
    this.size = UiSize.md,
    this.radius,
  });

  final String label;
  final List<UiDropdownItem<T>> items;
  final ValueChanged<UiDropdownItem<T>>? onSelected;
  final Widget? icon;

  /// Trigger style. link and brand draw as outline here, like the web's plain trigger.
  final UiButtonVariant variant;
  final UiSize size;
  final bool? radius;

  @override
  Widget build(BuildContext context) {
    final v = variant == UiButtonVariant.link || variant == UiButtonVariant.brand ? UiButtonVariant.outline : variant;
    return UiDropdownMenuAnchor<T>(
      items: items,
      onSelected: onSelected,
      builder: (context, open, toggle, focus) => UiButton(
        variant: v,
        size: size,
        radius: radius,
        icon: icon,
        focusNode: focus,
        onPressed: onSelected == null ? null : toggle,
        trailingIcon: Opacity(opacity: 0.7, child: UiIcon(HugeIcons.strokeRoundedArrowDown01, size: 14)),
        child: Semantics(expanded: open, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ),
    );
  }
}
