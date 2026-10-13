import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../theme/theme.dart';

/// One destination in a [UiSideNav].
@immutable
class UiSideNavItem {
  const UiSideNavItem({required this.label, required this.value, this.icon, this.badge, this.disabled = false});

  final String label;
  final String value;

  /// A Hugeicons icon, drawn at 16px.
  final UiIconData? icon;

  /// A short count or tag after the label ("3", "New").
  final String? badge;
  final bool disabled;
}

/// A titled group of [UiSideNavItem]s.
@immutable
class UiSideNavGroup {
  const UiSideNavGroup({this.label, required this.items});
  final String? label;
  final List<UiSideNavItem> items;
}

/// `ui-side-nav`: a vertical, grouped navigation list (an app sidebar, or the content of a drawer
/// on phones). [active] is the selected value; a tap reports the item through [onNavigate] (and its
/// value through [onChanged]). Router-agnostic: map the item to a route yourself.
///
/// The active item is marked selected for screen readers (the web `aria-current="page"`). On touch
/// screens every row is at least 48dp tall. It sizes to its content; wrap it in a scroll view (or set
/// [scrollable]) when it can be taller than the screen.
class UiSideNav extends StatelessWidget {
  const UiSideNav({
    super.key,
    required this.groups,
    this.active,
    this.onChanged,
    this.onNavigate,
    this.label = 'Sidebar',
    this.scrollable = false,
    this.padding = EdgeInsets.zero,
  });

  final List<UiSideNavGroup> groups;
  final String? active;
  final ValueChanged<String>? onChanged;
  final ValueChanged<UiSideNavItem>? onNavigate;

  /// Accessible name of the navigation landmark.
  final String label;
  final bool scrollable;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final groupLabel = context.uiText.code.copyWith(fontSize: 11, letterSpacing: 11 * 0.16, color: t.textMuted, height: 1.35);
    Widget list = Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: t.space4,
        children: [
          for (final g in groups)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (g.label != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(t.space2, 0, t.space2, t.space1 + 2),
                    child: Text(g.label!.toUpperCase(), style: groupLabel),
                  ),
                for (var i = 0; i < g.items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 1),
                  _SideNavTile(
                    item: g.items[i],
                    active: g.items[i].value == active,
                    onTap: () {
                      onChanged?.call(g.items[i].value);
                      onNavigate?.call(g.items[i]);
                    },
                  ),
                ],
              ],
            ),
        ],
      ),
    );
    if (scrollable) list = SingleChildScrollView(child: list);
    return Semantics(container: true, explicitChildNodes: true, role: SemanticsRole.navigation, label: label, child: list);
  }
}

class _SideNavTile extends StatelessWidget {
  const _SideNavTile({required this.item, required this.active, required this.onTap});
  final UiSideNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    return UiInteractive(
      onTap: item.disabled ? null : onTap,
      enabled: !item.disabled,
      selected: active,
      padTouchTarget: false,
      pressScale: false,
      builder: (context, s) {
        final fg = active || s.hovered || s.pressed ? t.text : t.textMuted;
        final bg = active ? t.selected : (s.hovered || s.pressed ? t.surfaceHover : null);
        return Opacity(
          opacity: s.disabled ? 0.5 : 1,
          child: AnimatedContainer(
            duration: context.uiAnimate ? t.motionFast : Duration.zero,
            curve: t.easeStandard,
            constraints: BoxConstraints(minHeight: touch ? uiMinTouchTarget : 0),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(context.uiTheme.radius()),
              boxShadow: s.focused ? t.focusRing : const [],
            ),
            child: Stack(alignment: AlignmentDirectional.centerStart, children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: t.space1, horizontal: t.space3),
                child: Row(spacing: t.space2, children: [
                  if (item.icon != null) SizedBox(width: 18, child: Center(child: UiIcon(item.icon!, size: 16, color: fg))),
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, color: fg, height: 1.35, fontWeight: active ? FontWeight.w600 : FontWeight.w400),
                    ),
                  ),
                  if (item.badge != null)
                    Container(
                      height: 16,
                      padding: EdgeInsets.symmetric(horizontal: t.space1),
                      decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: BorderRadius.circular(t.radiusPill)),
                      child: Align(
                        widthFactor: 1,
                        child: Text(
                          item.badge!,
                          style: context.uiText.body.copyWith(fontSize: 11, fontWeight: FontWeight.w600, height: 16 / 11, color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      ),
                    ),
                ]),
              ),
              if (active)
                PositionedDirectional(
                  start: 0,
                  top: t.space1,
                  bottom: t.space1,
                  width: 2,
                  child: DecoratedBox(decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(t.radiusPill))),
                ),
            ]),
          ),
        );
      },
    );
  }
}
