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

/// The surface of a [UiFeatureCard] (the web `surface`; web `'default'` is [standard], as `default` is a
/// Dart keyword). [tinted]: a soft wash in the tone, no border, shadow only on hover.
enum UiFeatureSurface { standard, tinted }

/// `ui-feature-card`: a product or service card for a landing page. An [icon] in a tinted badge,
/// an optional [eyebrow], a [title], a [description] and an action ([actionLabel] with an arrow).
///
/// With [onPressed] the whole card is one button (named "title, action label", described by the
/// description); the action is drawn inside it but is not a separate target. [tone] tints the
/// badge and washes the surface ([UiFeatureTone.brand] also draws the theme's brand gradient
/// around the card and the badge); [size] sm (the compact tile: 40px badge, 16px padding,
/// body-strong title), md or lg (xl counts as lg). `enabled: false` dims it and
/// makes it untappable. In a stretched grid row the action sits at the bottom so the actions of
/// neighbouring cards line up.
///
/// [trailingArrow] without [actionLabel] makes the card itself the action: one button named
/// "title, description" with a small arrow that points the reading way, at the end of the badge row
/// in the vertical layout (the end of the title row when horizontal or without an icon). [surface],
/// [controlRadius] and [descriptionLines] make the start-screen tile (web `surface="tinted"`,
/// `radius="control"`, `descriptionLines`).
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
    this.controlRadius = false,
    this.surface = UiFeatureSurface.standard,
    this.trailingArrow = false,
    this.descriptionLines,
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

  /// Rounded corners on or off (default [UiConfig.radius]).
  final bool? radius;

  /// Use a text field's corner radius (`t.radius`, web `radius="control"`) instead of the card's
  /// (`t.radiusLg`), so a tile matches the field above it. Corners still follow [radius] /
  /// [UiConfig.radius]: square when they are off, like the field.
  final bool controlRadius;

  /// [UiFeatureSurface.tinted]: a soft wash in the tone, no border, shadow only on hover ([glass]
  /// is ignored). The muted and primary-coloured words are deepened a quarter towards the text
  /// colour so they stay AA on the wash.
  final UiFeatureSurface surface;

  /// Without [actionLabel], the whole card is one button named "title, description" with a small
  /// trailing arrow (needs [onPressed] to be tappable). Ignored when [actionLabel] is set.
  final bool trailingArrow;

  /// Clamp the description to this many lines with an ellipsis; null or 0 shows it all.
  final int? descriptionLines;

  /// Replaces the spoken name ("title, action label").
  final String? semanticLabel;

  bool get _large => size == UiSize.lg || size == UiSize.xl;
  bool get _small => size == UiSize.sm;

  /// The card itself is the action (web: trailingArrow without an action label).
  bool get _cardAction => trailingArrow && actionLabel == null;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final tinted = surface == UiFeatureSurface.tinted;
    final isGlass = !tinted && (glass ?? theme.config.glass);
    final rounded = radius ?? theme.config.radius;
    final r = rounded ? (controlRadius ? t.radius : t.radiusLg) : 0.0;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final interactive = onPressed != null && enabled;
    final brand = tone == UiFeatureTone.brand;
    final toneColor = tone == UiFeatureTone.accent ? t.accent : t.primary;
    final strong = tone == UiFeatureTone.primary || brand; // eyebrow and action in primary
    final ground = isGlass ? t.glassBg : t.surface;
    // The web linear-gradient(160deg, color-mix(tone 3%, surface) 0%, surface 55%): at 6% primary text
    // fell below 4.5:1 in lightOrange / lightPurple.
    final wash = tone == UiFeatureTone.neutral || isGlass || tinted
        ? null
        : UiGradientSpec(angle: 160, colors: [Color.lerp(ground, toneColor, 0.03)!, ground], stops: const [0, 0.55]).toGradient();
    // Tinted (web surface="tinted"): 8% of the tone over the surface with 4% of the text (so a pale
    // tone, Winter's sun accent, still shows); neutral is 5% of the text. The muted and primary words
    // are deepened 25% towards the text colour (text-muted fails 4.5:1 on an 8% wash in lightPink).
    final tintFill = !tinted
        ? null
        : tone == UiFeatureTone.neutral
            ? Color.lerp(t.surface, t.text, 0.05)!
            : Color.lerp(Color.lerp(t.surface, t.text, 0.04)!, toneColor, 0.08)!;
    final cardFill = tintFill ?? ground;
    final muted = tinted ? Color.lerp(t.textMuted, t.text, 0.25)! : t.textMuted;
    final ink = tinted ? Color.lerp(t.primary, t.text, 0.25)! : t.primary;
    final pad = _large ? t.space8 : (_small ? t.space4 : t.space6);
    final gap = _small ? t.space3 : t.space4;
    final anim = context.uiAnimate;

    Widget? badge() {
      if (icon == null) return null;
      final d = _large ? t.sizeXl : (_small ? 40.0 : 48.0);
      // sm badges are rounded less (radiusSm), so a 40px badge stays a rounded square.
      final br = BorderRadius.circular(rounded ? (controlRadius ? t.radius : (_small ? t.radiusSm : t.radiusLg)) : 0.0);
      final tint = Color.lerp(t.surface, t.primary, tinted ? 0.18 : 0.14)!;
      final (Color bg, Color fg) = switch (tone) {
        UiFeatureTone.primary => (tint, t.primary),
        UiFeatureTone.accent => (t.accent, t.accentContrast),
        UiFeatureTone.brand => (tint, t.primary),
        UiFeatureTone.neutral => (t.surfaceRaised, t.text),
      };
      final glyph = IconTheme.merge(data: IconThemeData(size: _large ? 28 : (_small ? 20 : 24), color: fg), child: icon!);
      if (brand) {
        // A 2px ring of the brand gradient around the tinted square.
        return Container(
          width: d,
          height: d,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(gradient: t.gradientBrand.toGradient(), borderRadius: br),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(br.topLeft.x > 2 ? br.topLeft.x - 2 : 0)),
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
          : _small
              ? text.body.copyWith(fontSize: t.fontSizeMd, fontWeight: FontWeight.w600, height: 1.35, color: t.text)
              : text.body.copyWith(fontSize: t.fontSizeLg, fontWeight: FontWeight.w600, height: 1.3, color: t.text);
      final b = badge();
      // The card action's arrow: subtle (muted), 3px towards the end on hover / press.
      final arrow = !_cardAction
          ? null
          : AnimatedSlide(
              key: const ValueKey('ui-feature-card-arrow'),
              offset: Offset(lifted ? (rtl ? -3 : 3) / 16 : 0, 0),
              duration: anim ? t.motionFast : Duration.zero,
              curve: t.easeStandard,
              child: UiIcon(rtl ? HugeIcons.strokeRoundedArrowLeft02 : HugeIcons.strokeRoundedArrowRight02, size: 16, color: muted),
            );
      // Vertical with an icon: the arrow ends the badge row; otherwise it ends the title row.
      final arrowInBadgeRow = arrow != null && b != null && layout == UiFeatureLayout.vertical;
      final titleText = Semantics(header: !interactive, child: Text(title, style: titleStyle));
      final titleRow = arrow == null || arrowInBadgeRow
          ? titleText
          : Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
              Expanded(child: titleText),
              // One title line tall, so the arrow centres on the first line.
              SizedBox(height: titleStyle.fontSize! * titleStyle.height!, child: Center(child: arrow)),
            ]);
      final action = actionLabel == null
          ? null
          : Padding(
              padding: EdgeInsets.only(top: _small ? t.space3 : t.space4),
              child: Row(mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
                Flexible(
                  child: Text(
                    actionLabel!,
                    style: text.body.copyWith(fontSize: t.fontSizeMd, fontWeight: FontWeight.w600, height: 1.35, color: strong ? ink : t.text),
                  ),
                ),
                AnimatedSlide(
                  // 3px towards the end on hover / press.
                  offset: Offset(lifted ? (rtl ? -3 : 3) / 16 : 0, 0),
                  duration: anim ? t.motionFast : Duration.zero,
                  curve: t.easeStandard,
                  child: UiIcon(rtl ? HugeIcons.strokeRoundedArrowLeft02 : HugeIcons.strokeRoundedArrowRight02, size: 16, color: strong ? ink : t.text),
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
                  color: strong ? ink : muted,
                ),
              ),
            ),
          titleRow,
          if (description != null)
            Padding(
              padding: EdgeInsets.only(top: _small ? t.space1 : t.space2),
              child: Text(
                description!,
                maxLines: (descriptionLines ?? 0) > 0 ? descriptionLines : null,
                overflow: (descriptionLines ?? 0) > 0 ? TextOverflow.ellipsis : null,
                style: _small
                    ? text.body.copyWith(fontSize: t.fontSizeSm, height: 1.4, color: muted)
                    : text.body.copyWith(fontSize: _large ? 16 : t.fontSizeMd, height: 1.5, color: muted),
              ),
            ),
          // In a stretched grid row the action keeps to the bottom edge.
          if (action != null && bounded) const Spacer(),
          ?action,
        ],
      );
      if (b == null) return column;
      if (layout == UiFeatureLayout.horizontal) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: gap, children: [b, Expanded(child: column)]);
      }
      return Column(
        mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (arrowInBadgeRow) Row(children: [b, const Spacer(), arrow]) else b,
          SizedBox(height: gap),
          if (bounded) Expanded(child: column) else column,
        ],
      );
    }

    Widget body(UiStates s) {
      final lifted = interactive && (s.hovered || s.pressed);
      final shadows = [...(lifted ? t.shadow2 : (tinted ? const <BoxShadow>[] : t.shadow1)), if (s.focused) ...t.focusRing];
      // Tinted keeps a transparent 1px border, so it is the same size as the standard card.
      final borderColor = tinted ? const Color(0x00000000) : (isGlass ? t.glassBorder : (lifted ? t.borderStrong : t.border));
      final brandEdge = brand && !tinted;
      // Only an action row needs to know the height (to sit at the bottom of a stretched row). Without
      // one there is no LayoutBuilder, so tiles can be made equal height with IntrinsicHeight.
      Widget inner = actionLabel == null
          ? Padding(padding: EdgeInsets.all(pad), child: content(s, bounded: false))
          : LayoutBuilder(
              builder: (context, box) => Padding(padding: EdgeInsets.all(pad), child: content(s, bounded: box.hasTightHeight)),
            );
      Widget card = AnimatedContainer(
        duration: anim ? t.motionBase : Duration.zero,
        curve: t.easeStandard,
        transform: anim && lifted ? Matrix4.translationValues(0, s.pressed ? -1 : -2, 0) : Matrix4.identity(),
        padding: brandEdge ? const EdgeInsets.all(1) : EdgeInsets.zero,
        decoration: brandEdge
            // The brand gradient as a 1px border: the gradient box, with the surface inset by 1.
            ? BoxDecoration(gradient: t.gradientBrand.toGradient(), borderRadius: BorderRadius.circular(r), boxShadow: shadows)
            : BoxDecoration(
                color: cardFill,
                gradient: wash,
                borderRadius: BorderRadius.circular(r),
                border: Border.all(color: borderColor),
                boxShadow: shadows,
              ),
        child: brandEdge
            ? DecoratedBox(
                decoration: BoxDecoration(color: cardFill, gradient: wash, borderRadius: BorderRadius.circular(r > 1 ? r - 1 : 0)),
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

    final label = semanticLabel ??
        (actionLabel != null
            ? '$title, $actionLabel'
            : (_cardAction && description != null ? '$title, $description' : title));
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
      // A card action already says the description in its name.
      semanticHint: _cardAction ? null : description,
      excludeChildSemantics: true,
      padTouchTarget: false,
      pressScale: true,
      builder: (context, s) => body(s),
    );
  }
}
