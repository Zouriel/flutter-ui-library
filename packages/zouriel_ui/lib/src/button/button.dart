import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../core/types.dart';
import '../feedback/spinner.dart';
import '../theme/theme.dart';

/// Where a button sits in a joined row ([UiButtonGroup], [UiSplitButton]): only the outer corners
/// stay rounded. Buttons read it from their context; you rarely need it directly.
class UiButtonJoin extends InheritedWidget {
  const UiButtonJoin({super.key, required this.first, required this.last, required super.child});

  /// Keeps its start corners.
  final bool first;

  /// Keeps its end corners.
  final bool last;

  static UiButtonJoin? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<UiButtonJoin>();

  /// Corners of radius [r], squared where the button meets a neighbour.
  static BorderRadiusGeometry shape(BuildContext context, double r) {
    final j = maybeOf(context);
    if (j == null) return BorderRadius.circular(r);
    final start = Radius.circular(j.first ? r : 0), end = Radius.circular(j.last ? r : 0);
    return BorderRadiusDirectional.horizontal(start: start, end: end);
  }

  @override
  bool updateShouldNotify(UiButtonJoin old) => old.first != first || old.last != last;
}

/// Button styles, the web `UiButtonVariant`.
enum UiButtonVariant { primary, secondary, outline, ghost, link, destructive, brand, accent }

/// The resolved look of a button variant in a given state.
class _Look {
  const _Look({this.fill, this.gradient, required this.fg, this.border, this.shadow = const []});
  final Color? fill;
  final Gradient? gradient;
  final Color fg;
  final Color? border;
  final List<BoxShadow> shadow;
}

/// Ghost and outline buttons sit on the page, so their icons take the theme's icon colour.
bool _neutral(UiButtonVariant v) => v == UiButtonVariant.ghost || v == UiButtonVariant.outline;

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
    case UiButtonVariant.accent:
      // The theme's accent (maldives: the coral call to action); hover mixes in 12% of its contrast.
      return _Look(fill: hover ? Color.lerp(t.accent, t.accentContrast, 0.12) : t.accent, fg: t.accentContrast);
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
    this.minWidth,
    this.padding,
  }) : assert(label != null || child != null || (icon != null && semanticLabel != null), 'Give the button a label, a child, or an icon and a semanticLabel.');

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

  /// Minimum visual width (e.g. 48 so a narrow joined button needs no touch padding sideways).
  final double? minWidth;

  /// Horizontal padding instead of the size's default.
  final double? padding;

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
    final shape = UiButtonJoin.shape(context, r);

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
          if (!loading) ?icon,
          if (child != null) Flexible(child: child!) else if (label != null) Flexible(child: Text(label!, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ?trailingIcon,
        ];
        final row = IconTheme.merge(
          // Icons follow the label on filled and link buttons; ghost and outline ones take the theme's
          // icon colour (the web's --ui-color-icon).
          data: IconThemeData(color: _neutral(variant) ? (t.icon ?? look.fg) : look.fg, size: iconSize),
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
          constraints: BoxConstraints(minHeight: isLink ? 24 : size.height(t), minWidth: isLink ? 24 : minWidth ?? 0),
          height: isLink ? null : size.height(t),
          padding: EdgeInsets.symmetric(horizontal: isLink ? 0 : padding ?? padX),
          decoration: BoxDecoration(
            color: glass && !isBrand && !isLink ? t.glassBg : look.fill,
            gradient: look.gradient,
            borderRadius: shape,
            border: isBrand || isLink
                ? null
                : Border.all(color: glass ? t.glassBorder : (look.border ?? (look.fill == null && variant == UiButtonVariant.ghost ? const Color(0x00000000) : look.fill ?? t.border))),
            boxShadow: shadows,
          ),
          foregroundDecoration: brandWash
              ? BoxDecoration(color: t.primaryContrast.withValues(alpha: 0.12), borderRadius: shape)
              : null,
          child: Center(widthFactor: 1, heightFactor: 1, child: row),
        );
        if (glass && !isBrand && !isLink) {
          box = ClipRRect(
            borderRadius: shape,
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
    this.iconColor,
  });

  final Widget icon;

  /// Icon colour override (e.g. muted for a close button); defaults to the variant's text colour.
  final Color? iconColor;
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
    final shape = UiButtonJoin.shape(context, r);
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
              borderRadius: shape,
              border: Border.all(color: glass ? t.glassBorder : transparentBorder ? const Color(0x00000000) : t.border),
              boxShadow: s.focused ? t.focusRing : const [],
            ),
            foregroundDecoration: v == UiButtonVariant.brand && (s.hovered || s.pressed)
                ? BoxDecoration(color: t.primaryContrast.withValues(alpha: 0.12), borderRadius: shape)
                : null,
            child: Center(child: IconTheme.merge(data: IconThemeData(color: iconColor != null ? (s.hovered || s.pressed ? look.fg : iconColor!) : _neutral(v) ? (t.icon ?? look.fg) : look.fg, size: iconSize), child: icon)),
          ),
        );
      },
    );
  }
}
