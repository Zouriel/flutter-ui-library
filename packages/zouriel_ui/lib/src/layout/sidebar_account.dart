import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../badge/badge.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../overlay/tooltip.dart';
import '../theme/theme.dart';

/// `ui-sidebar-account`: the signed-in person at the bottom of a sidebar ([UiSidebarLayout]'s
/// `sidebarFooter`): avatar, name, a [subtitle] (job title · section), an optional [badge]
/// ("Read-only") and [hint] ("Switch test account"), and an unfold chevron saying it opens something.
///
/// It is one button the full width of the footer: focusable, pressed with Enter or Space, with
/// hover, pressed and focus-ring states. Screen readers hear the name, subtitle and badge as its
/// label and the hint as its hint. [onPressed] opens a switcher or drawer; to open a [UiMenu], use it
/// as the menu's trigger and pass the menu's open state as [expanded]:
///
/// ```dart
/// UiMenu(
///   items: accountItems,
///   onSelect: onAccount,
///   builder: (context, toggle, open) => UiSidebarAccount(name: name, subtitle: role, expanded: open, onPressed: toggle),
/// )
/// ```
///
/// [collapsed] shows only the avatar, with the label as a tooltip, for a sidebar narrowed to an icon
/// rail. [UiSidebarLayout] has no rail mode of its own, so the app sets it.
class UiSidebarAccount extends StatelessWidget {
  const UiSidebarAccount({
    super.key,
    required this.name,
    required this.onPressed,
    this.subtitle,
    this.image,
    this.badge,
    this.badgeTone = UiStatus.neutral,
    this.hint,
    this.showChevron = true,
    this.disabled = false,
    this.collapsed = false,
    this.expanded,
    this.focusNode,
  });

  /// The person's name; also the avatar's initials when there is no [image].
  final String name;

  /// A second line, e.g. job title · section.
  final String? subtitle;

  /// Profile photo (the web `src`); without one, or if it fails to load, the avatar shows initials.
  final ImageProvider? image;

  /// A short label after the name, e.g. "Read-only".
  final String? badge;
  final UiStatus badgeTone;

  /// A small third line saying what the button does, e.g. "Switch test account".
  final String? hint;

  /// The unfold chevron at the end.
  final bool showChevron;

  /// Dimmed and not pressable (as is a null [onPressed]).
  final bool disabled;

  /// Only the avatar, with the label in a tooltip: for a sidebar narrowed to a rail.
  final bool collapsed;

  /// Whether the menu or switcher it opens is showing (the web gets `aria-expanded` from `ui-menu`):
  /// announced to screen readers, and the button is tinted while true. Null when it opens nothing
  /// that stays open.
  final bool? expanded;

  /// Pressed: tap, click, Enter or Space. Null disables it.
  final VoidCallback? onPressed;
  final FocusNode? focusNode;

  /// The accessible name and the collapsed tooltip: name, subtitle and badge.
  String get label => [name, subtitle, badge].map((s) => s?.trim() ?? '').where((s) => s.isNotEmpty).join(', ');

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final hintText = collapsed ? null : hint?.trim();
    final button = UiInteractive(
      onTap: disabled ? null : onPressed,
      enabled: !disabled && onPressed != null,
      focusNode: focusNode,
      semanticLabel: label,
      semanticHint: hintText == null || hintText.isEmpty ? null : hintText,
      excludeChildSemantics: true,
      padTouchTarget: false,
      builder: (context, s) {
        final open = expanded ?? false;
        final bg = open ? t.selected : (s.hovered || s.pressed ? t.surfaceHover : null);
        final animate = context.uiAnimate;
        return Opacity(
          opacity: s.disabled ? 0.5 : 1,
          child: AnimatedScale(
            scale: s.pressed && animate ? t.scalePress : 1,
            duration: animate ? t.motionFast : Duration.zero,
            curve: t.easeStandard,
            child: AnimatedContainer(
              duration: animate ? t.motionFast : Duration.zero,
              curve: t.easeStandard,
              constraints: BoxConstraints(minHeight: uiTouchPlatform(context) ? uiMinTouchTarget : t.sizeTouch),
              padding: EdgeInsets.all(t.space2),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(context.uiTheme.radius()),
                boxShadow: s.focused ? t.focusRing : const [],
              ),
              child: collapsed ? Center(widthFactor: 1, child: _avatar()) : _row(context),
            ),
          ),
        );
      },
    );
    final annotated = expanded == null ? button : MergeSemantics(child: Semantics(expanded: expanded, child: button));
    if (!collapsed) return annotated;
    return Align(widthFactor: 1, child: UiTooltip(message: label, position: UiTooltipPosition.right, child: annotated));
  }

  Widget _avatar() => UiAvatar(image: image, name: name, alt: '');

  Widget _row(BuildContext context) {
    final t = context.ui;
    final muted = context.uiText.body.copyWith(fontSize: 12, height: 1.3, color: t.textMuted);
    Widget line(String text, TextStyle style) => Text(text, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: style);
    final sub = subtitle?.trim() ?? '';
    final tip = hint?.trim() ?? '';
    final tag = badge?.trim() ?? '';
    return Row(spacing: t.space2, children: [
      _avatar(),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(spacing: t.space2, children: [
            Flexible(child: line(name, context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.3, fontWeight: FontWeight.w600, color: t.text))),
            if (tag.isNotEmpty) UiBadge(label: tag, tone: badgeTone),
          ]),
          if (sub.isNotEmpty) line(sub, muted),
          if (tip.isNotEmpty) line(tip, muted),
        ]),
      ),
      if (showChevron) UiIcon(HugeIcons.strokeRoundedUnfoldMore, size: 16, color: t.textMuted),
    ]);
  }
}
