import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';

/// `ui-toggle-button`: a two-state button, announced with its on/off state (the web
/// `aria-pressed`). Controlled: [pressed] + [onChanged]; null [onChanged] disables it. When pressed it
/// takes a solid primary fill. Use it when several can be on; for one-of-many use [UiSegmented].
class UiToggleButton extends StatelessWidget {
  const UiToggleButton({
    super.key,
    required this.pressed,
    required this.onChanged,
    this.label,
    this.child,
    this.icon,
    this.size = UiSize.md,
    this.radius,
    this.focusNode,
    this.semanticLabel,
  }) : assert(label != null || child != null || icon != null, 'Give the toggle a label, child or icon.');

  final bool pressed;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final Widget? child;
  final Widget? icon;
  final UiSize size;

  /// Rounded corners; defaults to the library config.
  final bool? radius;
  final FocusNode? focusNode;

  /// Accessible name, required in practice for an icon-only toggle.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final r = (radius ?? theme.config.radius) ? t.radius : 0.0;
    final fontSize = switch (size) { UiSize.sm => 13.0, UiSize.md => 14.0, UiSize.lg => 15.0 };
    final padX = switch (size) { UiSize.sm => t.space3, UiSize.md => t.space4, UiSize.lg => t.space6 };
    final iconOnly = label == null && child == null;
    return UiInteractive(
      onTap: onChanged == null ? null : () => onChanged!(!pressed),
      enabled: onChanged != null,
      focusNode: focusNode,
      toggled: pressed,
      semanticLabel: semanticLabel,
      builder: (context, s) {
        final fg = pressed ? t.primaryContrast : t.text;
        final style = theme.typography.body.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          letterSpacing: t.trackingTight * fontSize,
          height: 1.2,
          color: fg,
        );
        return AnimatedOpacity(
          opacity: s.disabled ? 0.5 : 1,
          duration: t.motionBase,
          child: AnimatedContainer(
            duration: context.uiAnimate ? t.motionBase : Duration.zero,
            curve: t.easeStandard,
            height: size.height(t),
            width: iconOnly ? size.height(t) : null,
            padding: EdgeInsets.symmetric(horizontal: iconOnly ? 0 : padX),
            decoration: BoxDecoration(
              // On: a solid primary fill, so it can't be mistaken for the off state in any theme.
              color: pressed ? (s.hovered || s.pressed ? t.primaryHover : t.primary) : s.hovered || s.pressed ? t.surfaceHover : t.surface,
              border: Border.all(color: pressed ? t.primary.withValues(alpha: 0) : t.border),
              borderRadius: BorderRadius.circular(r),
              boxShadow: s.focused ? t.focusRing : const [],
            ),
            child: Center(
              widthFactor: iconOnly ? null : 1,
              child: IconTheme.merge(
                data: IconThemeData(color: pressed ? fg : (t.icon ?? fg), size: switch (size) { UiSize.sm => 14.0, UiSize.md => 16.0, UiSize.lg => 18.0 }),
                child: DefaultTextStyle(
                  style: style,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: t.space2,
                    children: [
                      ?icon,
                      if (child != null) Flexible(child: child!) else if (label != null) Flexible(child: Text(label!, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
