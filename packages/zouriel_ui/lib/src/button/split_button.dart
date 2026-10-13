import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';
import 'button.dart';
import 'button_group.dart';
import 'dropdown_button.dart';

/// `ui-split-button`: a main action plus a caret button ("More actions") joined into one shape.
/// [onPressed] runs the main action. The caret either calls [onMenu] (open your own menu) or, when
/// [items] are given, opens the built-in action menu and reports the choice to [onSelected].
/// Filled variants draw a thin divider between the halves.
class UiSplitButton<T> extends StatelessWidget {
  const UiSplitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.onMenu,
    this.items,
    this.onSelected,
    this.icon,
    this.variant = UiButtonVariant.primary,
    this.size = UiSize.md,
    this.radius,
    this.menuLabel = 'More actions',
  });

  final String label;

  /// Main action; null disables the main half.
  final VoidCallback? onPressed;

  /// Caret pressed (when there are no [items]); null with no [items] disables the caret.
  final VoidCallback? onMenu;
  final List<UiDropdownItem<T>>? items;
  final ValueChanged<UiDropdownItem<T>>? onSelected;
  final Widget? icon;

  /// link and brand draw as outline here, like the web's plain surface button.
  final UiButtonVariant variant;
  final UiSize size;
  final bool? radius;

  /// The caret's accessible name.
  final String menuLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final v = variant == UiButtonVariant.link || variant == UiButtonVariant.brand ? UiButtonVariant.outline : variant;
    final filled = v == UiButtonVariant.primary || v == UiButtonVariant.secondary || v == UiButtonVariant.destructive;
    final fg = switch (v) {
      UiButtonVariant.primary => t.primaryContrast,
      UiButtonVariant.secondary => t.secondaryContrast,
      UiButtonVariant.destructive => t.dangerContrast,
      _ => t.text,
    };

    Widget caret(VoidCallback? onTap, FocusNode? focus) {
      // A UiButton rather than an icon button: on phones it is drawn 48 wide, so its touch area
      // needs no sideways padding that would open a gap between the halves.
      final button = UiButton(
        icon: UiIcon(HugeIcons.strokeRoundedArrowDown01, size: 14),
        semanticLabel: menuLabel,
        variant: v,
        size: size,
        radius: radius,
        padding: t.space2,
        minWidth: uiTouchPlatform(context) ? uiMinTouchTarget : null,
        focusNode: focus,
        onPressed: onTap,
      );
      if (!filled) return button;
      // Filled halves have no visible border, so draw the divider between them.
      return Stack(children: [
        button,
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Center(child: Container(width: 1, height: size.height(t) - 2, color: fg.withValues(alpha: 0.28))),
          ),
        ),
      ]);
    }

    Widget row(Widget caretButton) => UiJoinedRow(children: [
          UiButton(label: label, icon: icon, variant: v, size: size, radius: radius, onPressed: onPressed),
          caretButton,
        ]);

    final menu = items;
    if (menu == null) return row(caret(onMenu, null));
    return UiDropdownMenuAnchor<T>(
      items: menu,
      onSelected: onSelected,
      builder: (context, open, toggle, focus) => row(caret(onSelected == null ? null : toggle, focus)),
    );
  }
}
