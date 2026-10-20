import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// The raised surface that menus, popovers and context menus float on: the web `.ui-menu` /
/// `.ui-popover` box (raised surface, 1px border, shadow 2), frosted when [glass], square when
/// [radius] is off. It scales and fades in like the web `ui-scale-in`, from [origin].
class UiOverlayPanel extends StatelessWidget {
  const UiOverlayPanel({
    super.key,
    required this.child,
    this.glass,
    this.radius,
    this.padding,
    this.origin = Alignment.topLeft,
    this.shadow,
    this.cornerRadius,
  });

  final Widget child;
  final bool? glass;
  final bool? radius;
  final EdgeInsetsGeometry? padding;

  /// Where the entrance scale grows from (the web `transform-origin`).
  final Alignment origin;
  final List<BoxShadow>? shadow;

  /// Corner radius when rounded; defaults to the `--ui-radius` token.
  final double? cornerRadius;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final isGlass = glass ?? theme.config.glass;
    final r = (radius ?? theme.config.radius) ? (cornerRadius ?? t.radius) : 0.0;
    Widget box = DecoratedBox(
      decoration: BoxDecoration(
        color: isGlass ? t.glassPanelBg : t.surfaceRaised,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: isGlass ? t.glassBorder : t.border),
        boxShadow: shadow ?? t.shadow2,
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
    if (isGlass) {
      box = ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: t.glassBlur / 2, sigmaY: t.glassBlur / 2), child: box),
      );
    }
    return UiScaleIn(origin: origin, child: box);
  }
}

/// The web `ui-scale-in` entrance: from 96% and transparent to full size, over the base duration
/// with the spring ease. Instant when motion is off.
class UiScaleIn extends StatelessWidget {
  const UiScaleIn({super.key, required this.child, this.origin = Alignment.center, this.duration});

  final Widget child;
  final Alignment origin;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    if (!context.uiAnimate) return child;
    final t = context.ui;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration ?? t.motionFast,
      curve: t.easeStandard,
      child: child,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.96 + 0.04 * v, alignment: origin, child: child),
      ),
    );
  }
}
