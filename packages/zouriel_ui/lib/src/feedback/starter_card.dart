import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';

/// `ui-starter-card`: one way to start, for [UiEmptyState.starters]: an [icon] in a tinted tile, a
/// [heading] and one line, the whole card one button ([onTap]).
class UiStarterCard extends StatelessWidget {
  const UiStarterCard({super.key, required this.heading, this.description, this.icon, this.onTap, this.enabled = true});

  final String heading;

  /// One line on what it starts.
  final String? description;

  /// Usually a `UiIcon`; drawn at 20px in the primary colour.
  final Widget? icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final ty = context.uiText;
    final on = enabled && onTap != null;
    return UiInteractive(
      onTap: onTap,
      enabled: on,
      semanticLabel: heading,
      semanticHint: description,
      excludeChildSemantics: true,
      pressScale: false,
      builder: (context, s) => AnimatedContainer(
        duration: context.uiAnimate ? t.motionFast : Duration.zero,
        curve: t.easeStandard,
        constraints: const BoxConstraints(minHeight: 64),
        padding: EdgeInsets.all(t.space3),
        decoration: BoxDecoration(
          color: on && (s.hovered || s.pressed) ? t.surfaceHover : t.surface,
          border: Border.all(color: on && s.hovered ? t.borderStrong : t.border),
          borderRadius: BorderRadius.circular(theme.radius(t.radiusLg)),
          boxShadow: s.focused ? t.focusRing : null,
        ),
        child: Row(children: [
          if (icon != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: uiMix(t.primary, 0.12, t.surface), borderRadius: BorderRadius.circular(theme.radius(t.radius))),
              child: Center(child: IconTheme.merge(data: IconThemeData(size: 20, color: t.primary), child: icon!)),
            ),
            SizedBox(width: t.space3),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(heading, style: ty.body.copyWith(fontSize: t.fontSizeMd, fontWeight: FontWeight.w600, height: 1.35, color: on ? t.text : t.textDisabled)),
              if (description != null) ...[
                const SizedBox(height: 2),
                Text(description!, style: ty.body.copyWith(fontSize: t.fontSizeSm, height: 1.35, color: on ? t.textMuted : t.textDisabled)),
              ],
            ]),
          ),
          SizedBox(width: t.space3),
          UiIcon(HugeIcons.strokeRoundedArrowRight01, size: 16, strokeWidth: 2, color: t.textMuted, matchTextDirection: true),
        ]),
      ),
    );
  }
}
