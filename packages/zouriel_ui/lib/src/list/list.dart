import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';

/// `ui-list`: a list of rows, usually [UiListItem]s. Announced as a list of items. [bordered] draws
/// a rounded border with a rule between rows.
class UiList extends StatelessWidget {
  const UiList({super.key, required this.children, this.bordered = false, this.radius});

  final List<Widget> children;
  final bool bordered;
  final bool? radius;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final r = (radius ?? theme.config.radius) ? t.radius : 0.0;
    Widget list = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++)
          Semantics(
            container: true,
            role: SemanticsRole.listItem,
            child: bordered && i < children.length - 1
                ? DecoratedBox(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))), position: DecorationPosition.foreground, child: children[i])
                : children[i],
          ),
      ],
    );
    if (bordered) {
      list = Container(
        decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(r)),
        child: ClipRRect(borderRadius: BorderRadius.circular(r > 1 ? r - 1 : 0), child: list),
      );
    }
    return Semantics(container: true, explicitChildNodes: true, role: SemanticsRole.list, child: list);
  }
}

/// `ui-list-item`: a row with optional [leading] and [trailing] widgets (trailing in the muted
/// colour). With [onTap] the row is a button (48dp tall on touch) with hover, press and an inset
/// focus ring; [selected] tints it, marks its leading edge with a 2px primary bar (so it can't be
/// mistaken for a hovered row) and is announced; [enabled] false fades it and ignores taps.
class UiListItem extends StatelessWidget {
  const UiListItem({super.key, required this.child, this.leading, this.trailing, this.onTap, this.selected = false, this.enabled = true});

  final Widget child;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    Widget row(UiStates s, {bool interactive = false}) {
      final hover = s.hovered || s.pressed;
      final bg = selected ? (hover ? uiMix(t.selected, 0.5, t.surfaceHover) : t.selected) : (hover ? t.surfaceHover : null);
      return Opacity(
        opacity: s.disabled && interactive ? 0.5 : 1,
        child: AnimatedContainer(
          duration: context.uiAnimate ? t.motionFast : Duration.zero,
          curve: t.easeStandard,
          constraints: BoxConstraints(minHeight: interactive && uiTouchPlatform(context) ? uiMinTouchTarget : 0),
          // The 2px left border is the selected bar (transparent otherwise); it is part of the padding.
          padding: EdgeInsets.fromLTRB(t.space4 - 2, t.space2, t.space4, t.space2),
          decoration: BoxDecoration(color: bg, border: Border(left: BorderSide(color: selected ? t.primary : t.primary.withValues(alpha: 0), width: 2))),
          foregroundDecoration: s.focused ? BoxDecoration(border: Border.all(color: t.borderFocus, width: 2)) : null,
          child: DefaultTextStyle.merge(
            style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.35),
            child: Row(spacing: t.space3, children: [
              if (leading != null) IconTheme.merge(data: IconThemeData(color: t.icon ?? t.text, size: 20), child: leading!),
              Expanded(child: child),
              if (trailing != null) DefaultTextStyle.merge(style: TextStyle(color: t.textMuted), child: IconTheme.merge(data: IconThemeData(color: t.icon ?? t.textMuted), child: trailing!)),
            ]),
          ),
        ),
      );
    }

    if (onTap == null) return Semantics(selected: selected ? true : null, child: row(const UiStates()));
    return UiInteractive(
      onTap: onTap,
      enabled: enabled,
      selected: selected,
      pressScale: false,
      padTouchTarget: false,
      builder: (context, s) => row(s, interactive: true),
    );
  }
}
