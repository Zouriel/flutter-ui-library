import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';

/// The colour family of a [UiFeatureCard] (the web `tone`).
enum UiFeatureTone { primary, accent, brand, neutral }

/// How a [UiFeatureCard] lays out its icon badge and text (the web `layout`).
enum UiFeatureLayout { vertical, horizontal }

/// `ui-feature-card`: a product or service card for a landing page. An [icon] in a tinted badge,
/// an optional [eyebrow], a [title], a [description] and an action ([actionLabel] with an arrow).
///
/// With [onPressed] the whole card is one button (named "title, action label", described by the
/// description); the action is drawn inside it but is not a separate target. [tone] tints the
/// badge and washes the surface ([UiFeatureTone.brand] also draws the theme's brand gradient
/// around the card and the badge); [size] md or lg (sm counts as md, xl as lg). `enabled: false`
/// dims it and makes it untappable. In a stretched grid row the action sits at the bottom so the
/// actions of neighbouring cards line up.
class UiFeatureCard extends StatelessWidget {
  const UiFeatureCard({
    super.key,
    required this.title,
    this.description,
    this.eyebrow,
    this.icon,
    this.actionLabel,
    this.onPressed,
    this.tone = UiFeatureTone.primary,
    this.layout = UiFeatureLayout.vertical,
    this.size = UiSize.md,
    this.enabled = true,
    this.glass,
    this.radius,
    this.semanticLabel,
  });

  final String title;
  final String? description;

  /// A short tag above the title ("New", "For clinics"); shown in capitals.
  final String? eyebrow;

  /// Usually a `UiIcon`; sized and coloured by the badge.
  final Widget? icon;
  final String? actionLabel;
  final VoidCallback? onPressed;
  final UiFeatureTone tone;
  final UiFeatureLayout layout;
  final UiSize size;
  final bool enabled;
  final bool? glass;
  final bool? radius;

  /// Replaces the spoken name ("title, action label").
  final String? semanticLabel;

  bool get _large => size == UiSize.lg || size == UiSize.xl;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final isGlass = glass ?? theme.config.glass;
    final r = (radius ?? theme.config.radius) ? t.radiusLg : 0.0;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final interactive = onPressed != null && enabled;
    final brand = tone == UiFeatureTone.brand;
    final toneColor = tone == UiFeatureTone.accent ? t.accent : t.primary;
    final strong = tone == UiFeatureTone.primary || brand; // eyebrow and action in primary
    final surface = isGlass ? t.glassBg : t.surface;
    // The web linear-gradient(160deg, color-mix(tone 3%, surface) 0%, surface 55%): at 6% primary text
    // fell below 4.5:1 in lightOrange / lightPurple.
    final wash = tone == UiFeatureTone.neutral || isGlass
        ? null
        : UiGradientSpec(angle: 160, colors: [Color.lerp(surface, toneColor, 0.03)!, surface], stops: const [0, 0.55]).toGradient();
    final pad = _large ? t.space8 : t.space6;
    final anim = context.uiAnimate;

    Widget? badge() {
      if (icon == null) return null;
      final d = _large ? t.sizeXl : 48.0;
      final br = BorderRadius.circular(r);
      final tint = Color.lerp(t.surface, t.primary, 0.14)!;
      final (Color bg, Color fg) = switch (tone) {
        UiFeatureTone.primary => (tint, t.primary),
        UiFeatureTone.accent => (t.accent, t.accentContrast),
        UiFeatureTone.brand => (tint, t.primary),
        UiFeatureTone.neutral => (t.surfaceRaised, t.text),
      };
      final glyph = IconTheme.merge(data: IconThemeData(size: _large ? 28 : 24, color: fg), child: icon!);
      if (brand) {
        // A 2px ring of the brand gradient around the tinted square.
        return Container(
          width: d,
          height: d,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(gradient: t.gradientBrand.toGradient(), borderRadius: br),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(r > 2 ? r - 2 : 0)),
            child: glyph,
          ),
        );
      }
      return Container(
        width: d,
        height: d,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: br,
          border: tone == UiFeatureTone.neutral ? Border.all(color: t.border) : null,
        ),
        child: glyph,
      );
    }

    Widget content(UiStates s, {required bool bounded}) {
      final lifted = interactive && (s.hovered || s.pressed);
      final text = context.uiText;
      final titleStyle = _large
          ? text.h3.copyWith(fontWeight: FontWeight.w700, color: t.text)
          : text.body.copyWith(fontSize: t.fontSizeLg, fontWeight: FontWeight.w600, height: 1.3, color: t.text);
      final action = actionLabel == null
          ? null
          : Padding(
              padding: EdgeInsets.only(top: t.space4),
              child: Row(mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
                Flexible(
                  child: Text(
                    actionLabel!,
                    style: text.body.copyWith(fontSize: t.fontSizeMd, fontWeight: FontWeight.w600, height: 1.35, color: strong ? t.primary : t.text),
                  ),
                ),
                AnimatedSlide(
                  // 3px towards the end on hover / press.
                  offset: Offset(lifted ? (rtl ? -3 : 3) / 16 : 0, 0),
                  duration: anim ? t.motionFast : Duration.zero,
                  curve: t.easeStandard,
                  child: UiIcon(rtl ? HugeIcons.strokeRoundedArrowLeft02 : HugeIcons.strokeRoundedArrowRight02, size: 16, color: strong ? t.primary : t.text),
                ),
              ]),
            );
      final column = Column(
        mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null)
            Padding(
              padding: EdgeInsets.only(bottom: t.space1),
              child: Text(
                eyebrow!.toUpperCase(),
                style: text.body.copyWith(
                  fontSize: t.fontSizeSm,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  letterSpacing: 0.04 * t.fontSizeSm,
                  color: strong ? t.primary : t.textMuted,
                ),
              ),
            ),
          Semantics(header: !interactive, child: Text(title, style: titleStyle)),
          if (description != null)
            Padding(
              padding: EdgeInsets.only(top: t.space2),
              child: Text(
                description!,
                style: text.body.copyWith(fontSize: _large ? 16 : t.fontSizeMd, height: 1.5, color: t.textMuted),
              ),
            ),
          // In a stretched grid row the action keeps to the bottom edge.
          if (action != null && bounded) const Spacer(),
          ?action,
        ],
      );
      final b = badge();
      if (b == null) return column;
      if (layout == UiFeatureLayout.horizontal) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space4, children: [b, Expanded(child: column)]);
      }
      return Column(
        mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          b,
          SizedBox(height: t.space4),
          if (bounded) Expanded(child: column) else column,
        ],
      );
    }

    Widget body(UiStates s) {
      final lifted = interactive && (s.hovered || s.pressed);
      final shadows = [...(lifted ? t.shadow2 : t.shadow1), if (s.focused) ...t.focusRing];
      final borderColor = isGlass ? t.glassBorder : (lifted ? t.borderStrong : t.border);
      Widget inner = LayoutBuilder(
        builder: (context, box) => Padding(padding: EdgeInsets.all(pad), child: content(s, bounded: box.hasTightHeight)),
      );
      Widget card = AnimatedContainer(
        duration: anim ? t.motionBase : Duration.zero,
        curve: t.easeStandard,
        transform: anim && lifted ? Matrix4.translationValues(0, s.pressed ? -1 : -2, 0) : Matrix4.identity(),
        padding: brand ? const EdgeInsets.all(1) : EdgeInsets.zero,
        decoration: brand
            // The brand gradient as a 1px border: the gradient box, with the surface inset by 1.
            ? BoxDecoration(gradient: t.gradientBrand.toGradient(), borderRadius: BorderRadius.circular(r), boxShadow: shadows)
            : BoxDecoration(
                color: surface,
                gradient: wash,
                borderRadius: BorderRadius.circular(r),
                border: Border.all(color: borderColor),
                boxShadow: shadows,
              ),
        child: brand
            ? DecoratedBox(
                decoration: BoxDecoration(color: surface, gradient: wash, borderRadius: BorderRadius.circular(r > 1 ? r - 1 : 0)),
                child: inner,
              )
            : inner,
      );
      if (isGlass) {
        card = ClipRRect(
          borderRadius: BorderRadius.circular(r),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: t.glassBlur / 2, sigmaY: t.glassBlur / 2), child: card),
        );
      }
      if (!enabled) card = Opacity(opacity: 0.5, child: card);
      return card;
    }

    final label = semanticLabel ?? (actionLabel != null ? '$title, $actionLabel' : title);
    // No handler and no action: a static card (dimmed when disabled), like the web's card without
    // actionLabel / href. A disabled card with an action stays a (disabled) button.
    if (onPressed == null && (enabled || actionLabel == null)) {
      return Semantics(container: true, child: body(const UiStates()));
    }
    return UiInteractive(
      onTap: onPressed,
      enabled: enabled,
      button: true,
      semanticLabel: label,
      semanticHint: description,
      excludeChildSemantics: true,
      padTouchTarget: false,
      pressScale: true,
      builder: (context, s) => body(s),
    );
  }
}
