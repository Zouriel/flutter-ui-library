import 'dart:ui' show ImageFilter;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../theme/theme.dart';

/// One destination in a [UiBottomNav].
@immutable
class UiBottomNavItem {
  const UiBottomNavItem({required this.label, required this.value, this.icon, this.badge});

  final String label;
  final String value;

  /// A Hugeicons icon.
  final UiIconData? icon;

  /// A count or short tag shown on the icon in the danger colour ("3", "New").
  final String? badge;
}

/// `ui-bottom-nav`: the mobile bottom navigation bar: equal-width destinations with an icon over a
/// short label, the [active] one in the primary colour. A tap reports the value through [onChanged].
///
/// It is a set of buttons, not tabs (the web dropped `role="tablist"` for the same reason): the active
/// one is announced as selected (the web `aria-current="page"`), and a badge is read after the label.
/// The bar adds the bottom safe-area inset under its 56px row, so it can sit at the screen's edge.
class UiBottomNav extends StatelessWidget {
  const UiBottomNav({
    super.key,
    required this.items,
    this.active,
    this.onChanged,
    this.label,
    this.glass,
    this.radius,
    this.iconSize = 22,
    this.safeArea = true,
  });

  final List<UiBottomNavItem> items;
  final String? active;
  final ValueChanged<String>? onChanged;

  /// Accessible name; set it when a screen has more than one navigation.
  final String? label;
  final bool? glass;
  final bool? radius;
  final double iconSize;

  /// Pad the bottom by the system gesture/navigation bar height.
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final isGlass = glass ?? theme.config.glass;
    final r = (radius ?? theme.config.radius) ? t.radius : 0.0;
    final bottom = safeArea ? MediaQuery.paddingOf(context).bottom : 0.0;
    Widget bar = Container(
      decoration: BoxDecoration(
        color: isGlass ? t.glassBg : t.surface,
        border: Border.all(color: isGlass ? t.glassBorder : t.border),
        borderRadius: BorderRadius.circular(r),
      ),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: 56,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final item in items)
            Expanded(child: _BottomNavTile(item: item, active: item.value == active, iconSize: iconSize, onTap: () => onChanged?.call(item.value))),
        ]),
      ),
    );
    if (isGlass) {
      bar = ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: t.glassBlur / 2, sigmaY: t.glassBlur / 2), child: bar),
      );
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: label == null ? null : SemanticsRole.navigation,
      label: label,
      child: bar,
    );
  }
}

class _BottomNavTile extends StatelessWidget {
  const _BottomNavTile({required this.item, required this.active, required this.iconSize, required this.onTap});
  final UiBottomNavItem item;
  final bool active;
  final double iconSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      selected: active,
      padTouchTarget: false,
      semanticLabel: item.badge == null ? item.label : '${item.label}, ${item.badge}',
      excludeChildSemantics: true,
      builder: (context, s) {
        final fg = active ? t.primary : (s.hovered || s.pressed ? t.text : t.textMuted);
        return AnimatedContainer(
          duration: context.uiAnimate ? t.motionFast : Duration.zero,
          curve: t.easeStandard,
          // The bar clips its corners, so the focus ring sits inside the item.
          decoration: BoxDecoration(color: s.hovered || s.pressed ? t.surfaceHover : null),
          foregroundDecoration: s.focused ? BoxDecoration(border: Border.all(color: t.borderFocus, width: 2)) : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 2,
            children: [
              if (item.icon != null)
                Stack(clipBehavior: Clip.none, children: [
                  UiIcon(item.icon!, size: iconSize, color: active ? fg : (t.icon ?? fg)),
                  if (item.badge != null)
                    PositionedDirectional(
                      top: -6,
                      end: -10,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16),
                        height: 16,
                        padding: EdgeInsets.symmetric(horizontal: t.space1),
                        decoration: BoxDecoration(color: t.danger, borderRadius: BorderRadius.circular(t.radiusPill)),
                        alignment: Alignment.center,
                        child: Text(
                          item.badge!,
                          style: context.uiText.body.copyWith(fontSize: 11, fontWeight: FontWeight.w600, height: 16 / 11, color: t.dangerContrast, fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      ),
                    ),
                ]),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: t.space1),
                child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.body.copyWith(fontSize: 11, color: fg, height: 1.35)),
              ),
            ],
          ),
        );
      },
    );
  }
}
