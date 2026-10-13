import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../core/types.dart';
import '../feedback/spinner.dart';
import '../theme/theme.dart';

/// Button styles, the web `UiButtonVariant`.
enum UiButtonVariant { primary, secondary, outline, ghost, link, destructive, brand }

/// The resolved look of a button variant in a given state.
class _Look {
  const _Look({this.fill, this.gradient, required this.fg, this.border, this.shadow = const []});
  final Color? fill;
  final Gradient? gradient;
  final Color fg;
  final Color? border;
  final List<BoxShadow> shadow;
}

_Look _look(UiButtonVariant v, UiTokens t, UiStates s) {
  final hover = s.hovered || s.pressed;
  switch (v) {
    case UiButtonVariant.primary:
      return _Look(fill: s.pressed ? t.primaryActive : hover ? t.primaryHover : t.primary, fg: t.primaryContrast);
    case UiButtonVariant.secondary:
      return _Look(fill: hover ? t.secondaryHover : t.secondary, fg: t.secondaryContrast);
    case UiButtonVariant.destructive:
      return _Look(fill: hover ? t.dangerHover : t.danger, fg: t.dangerContrast);
    case UiButtonVariant.outline:
      return _Look(fill: hover ? t.surfaceHover : null, fg: t.text, border: t.border);
    case UiButtonVariant.ghost:
      return _Look(fill: hover ? t.surfaceHover : null, fg: t.text);
    case UiButtonVariant.link:
      return _Look(fg: hover ? t.primaryHover : t.primary);
    case UiButtonVariant.brand:
      final g = t.gradientBrand.toGradient();
      return _Look(gradient: g, fg: t.primaryContrast, shadow: t.glowAmber);
  }
}

/// `ui-button`: the action primitive.
///
/// Pass a [label] (or any [child]) and optional [icon] / [trailingIcon]. While [loading] it shows a
/// spinner, is announced as busy, and ignores taps. Leave [onPressed] null to disable it.
class UiButton extends StatelessWidget {
  const UiButton({
    super.key,
    this.label,
    this.child,
    this.icon,
    this.trailingIcon,
    required this.onPressed,
    this.variant = UiButtonVariant.primary,
    this.size = UiSize.md,
    this.loading = false,
    this.block = false,
    this.glass = false,
    this.radius,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  }) : assert(label != null || child != null, 'Give the button a label or a child.');

  final String? label;
  final Widget? child;
  final Widget? icon;
  final Widget? trailingIcon;
  final VoidCallback? onPressed;
  final UiButtonVariant variant;
  final UiSize size;
  final bool loading;

  /// Full width.
  final bool block;

  /// Frosted, translucent fill (opt-in; buttons are solid by default).
  final bool glass;

  /// Rounded corners; defaults to the library config.
  final bool? radius;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final rounded = radius ?? theme.config.radius;
    final isLink = variant == UiButtonVariant.link;
    final isBrand = variant == UiButtonVariant.brand;
    final fontSize = switch (size) { UiSize.sm => 13.0, UiSize.md => 14.0, UiSize.lg => 15.0 };
    final padX = switch (size) { UiSize.sm => t.space3, UiSize.md => t.space4, UiSize.lg => t.space6 };
    final r = !rounded ? 0.0 : isBrand ? t.radiusPill : t.radius;

    return UiInteractive(
      onTap: loading ? null : onPressed,
      enabled: onPressed != null && !loading,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: semanticLabel ?? (loading ? '${label ?? ''} (busy)'.trim() : null),
      builder: (context, s) {
        final look = _look(variant, t, s);
        final style = theme.typography.body.copyWith(
          fontSize: fontSize,
          fontWeight: isBrand ? FontWeight.w600 : FontWeight.w500,
          letterSpacing: t.trackingTight * fontSize,
          height: 1.2,
          color: look.fg,
          decoration: isLink ? TextDecoration.underline : TextDecoration.none,
          decorationColor: look.fg,
        );
        final iconSize = switch (size) { UiSize.sm => 14.0, UiSize.md => 16.0, UiSize.lg => 18.0 };
        final content = <Widget>[
          if (loading) UiSpinner(size: fontSize, color: look.fg, decorative: true),
          if (icon != null && !loading) icon!,
          if (child != null) Flexible(child: child!) else Flexible(child: Text(label!, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (trailingIcon != null) trailingIcon!,
        ];
        final row = IconTheme.merge(
          data: IconThemeData(color: look.fg, size: iconSize),
          child: DefaultTextStyle(
            style: style,
            child: Row(
              mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: t.space2,
              children: content,
            ),
          ),
        );

        final shadows = [...look.shadow, if (s.focused) ...t.focusRing];
        final brandWash = isBrand && (s.hovered || s.pressed);
        Widget box = AnimatedContainer(
          duration: context.uiAnimate ? t.motionBase : Duration.zero,
          curve: t.easeStandard,
          constraints: BoxConstraints(minHeight: isLink ? 24 : size.height(t), minWidth: isLink ? 24 : 0),
          height: isLink ? null : size.height(t),
          padding: EdgeInsets.symmetric(horizontal: isLink ? 0 : padX),
          decoration: BoxDecoration(
            color: glass && !isBrand && !isLink ? t.glassBg : look.fill,
            gradient: look.gradient,
            borderRadius: BorderRadius.circular(r),
            border: isBrand || isLink
                ? null
                : Border.all(color: glass ? t.glassBorder : (look.border ?? (look.fill == null && variant == UiButtonVariant.ghost ? const Color(0x00000000) : look.fill ?? t.border))),
            boxShadow: shadows,
          ),
          foregroundDecoration: brandWash
              ? BoxDecoration(color: t.primaryContrast.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(r))
              : null,
          child: Center(widthFactor: 1, heightFactor: 1, child: row),
        );
        if (glass && !isBrand && !isLink) {
          box = ClipRRect(
            borderRadius: BorderRadius.circular(r),
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: t.glassBlur / 2, sigmaY: t.glassBlur / 2), child: box),
          );
        }
        return AnimatedOpacity(
          opacity: s.disabled && !loading ? 0.5 : 1,
          duration: t.motionBase,
          child: block ? SizedBox(width: double.infinity, child: box) : box,
        );
      },
    );
  }
}

/// `ui-icon-button`: a square, icon-only action. [label] is required: it is the accessible name
/// (and the tooltip on platforms with hover).
class UiIconButton extends StatelessWidget {
  const UiIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.variant = UiButtonVariant.ghost,
    this.size = UiSize.md,
    this.round = false,
    this.glass = false,
    this.radius,
    this.focusNode,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  final UiButtonVariant variant;
  final UiSize size;
  final bool round;
  final bool glass;
  final bool? radius;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final rounded = radius ?? theme.config.radius;
    final dim = size.height(t);
    final r = round ? t.radiusPill : rounded ? t.radius : 0.0;
    final iconSize = switch (size) { UiSize.sm => 14.0, UiSize.md => 16.0, UiSize.lg => 18.0 };
    return UiInteractive(
      onTap: onPressed,
      enabled: onPressed != null,
      focusNode: focusNode,
      semanticLabel: label,
      excludeChildSemantics: true,
      builder: (context, s) {
        // Link has no fill of its own as an icon button; it behaves like ghost.
        final v = variant == UiButtonVariant.link ? UiButtonVariant.ghost : variant;
        final look = _look(v, t, s);
        final transparentBorder = v == UiButtonVariant.ghost || look.fill != null && v != UiButtonVariant.outline;
        return AnimatedOpacity(
          opacity: s.disabled ? 0.5 : 1,
          duration: t.motionBase,
          child: AnimatedContainer(
            duration: context.uiAnimate ? t.motionBase : Duration.zero,
            curve: t.easeStandard,
            width: dim,
            height: dim,
            decoration: BoxDecoration(
              color: glass ? t.glassBg : (look.fill ?? (v == UiButtonVariant.outline || v == UiButtonVariant.ghost ? null : t.surface)),
              gradient: look.gradient,
              borderRadius: BorderRadius.circular(r),
              border: Border.all(color: glass ? t.glassBorder : transparentBorder ? const Color(0x00000000) : t.border),
              boxShadow: s.focused ? t.focusRing : const [],
            ),
            foregroundDecoration: v == UiButtonVariant.brand && (s.hovered || s.pressed)
                ? BoxDecoration(color: t.primaryContrast.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(r))
                : null,
            child: Center(child: IconTheme.merge(data: IconThemeData(color: look.fg, size: iconSize), child: icon)),
          ),
        );
      },
    );
  }
}
