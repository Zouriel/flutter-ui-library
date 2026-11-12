import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../button/button.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';

/// [UiOfferCard.variant] (the web `UiOfferVariant`): [standard] (the web `default`) shows a small
/// icon or picture by the text; [role] a bigger avatar or cover picture, for "X added you to their
/// event".
enum UiOfferVariant { standard, role }

/// `ui-offer-card`: a card that offers help ("New here? Take a quick tour."), made to sit at the top
/// of a feed or list. [art] is an icon (or, with [UiOfferVariant.role], an avatar or cover picture).
/// Its look is the coach-mark tint, so it doesn't pass for content. It fits a 360px phone: the
/// buttons wrap under the text.
class UiOfferCard extends StatelessWidget {
  const UiOfferCard({
    super.key,
    required this.heading,
    this.body,
    this.variant = UiOfferVariant.standard,
    this.art,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.onDismiss,
    this.onTipsOff,
    this.tipsOffLabel,
    this.child,
  });

  final String heading;
  final String? body;
  final UiOfferVariant variant;

  /// Usually a `UiIcon` (standard) or an image (role), clipped to its frame.
  final Widget? art;

  /// The main button; shown when [primaryLabel] is set.
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  /// The quieter button ("Not now"); shown when [secondaryLabel] is set.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Shows the × ("Dismiss") when set.
  final VoidCallback? onDismiss;

  /// Shows the small "Turn off tips" link when set.
  final VoidCallback? onTipsOff;

  /// [UiStrings.tipsOff] when null.
  final String? tipsOffLabel;

  /// Anything else under the body (the web default slot).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final ty = context.uiText;
    final strings = context.uiStrings;
    final role = variant == UiOfferVariant.role;
    Widget? artBox;
    if (art != null) {
      artBox = role
          ? ClipRRect(
              borderRadius: BorderRadius.circular(theme.radius(t.radius)),
              child: SizedBox(width: 56, height: 56, child: ColoredBox(color: t.surfaceSubtle, child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: art))),
            )
          : Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: uiMix(t.primary, 0.16, t.surface), borderRadius: BorderRadius.circular(t.radiusPill)),
              child: IconTheme.merge(data: IconThemeData(size: 20, color: t.primary), child: art!),
            );
      artBox = ExcludeSemantics(child: artBox);
    }
    final actions = <Widget>[
      if (primaryLabel != null) UiButton(label: primaryLabel, onPressed: onPrimary, size: UiSize.sm),
      if (secondaryLabel != null) UiButton(label: secondaryLabel, onPressed: onSecondary, size: UiSize.sm, variant: UiButtonVariant.ghost),
    ];
    final main = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Padding(
        // Room for the × beside the heading.
        padding: EdgeInsetsDirectional.only(end: onDismiss != null ? t.space6 : 0),
        child: Semantics(header: true, child: Text(heading, style: ty.body.copyWith(fontSize: t.fontSizeMd, fontWeight: FontWeight.w600, color: t.text, height: 1.4))),
      ),
      if (body != null) ...[
        SizedBox(height: t.space1),
        Text(body!, style: ty.body.copyWith(fontSize: t.fontSizeSm, color: t.textSecondary, height: 1.4)),
      ],
      if (child != null) ...[SizedBox(height: t.space1), child!],
      if (actions.isNotEmpty) ...[
        SizedBox(height: t.space1 + t.space2),
        Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
      ],
      if (onTipsOff != null) ...[
        // On touch screens the link's 48px tap area already leaves room above it.
        SizedBox(height: uiTouchPlatform(context) ? 0 : t.space2),
        UiInteractive(
          onTap: onTipsOff,
          semanticLabel: tipsOffLabel ?? strings.tipsOff,
          excludeChildSemantics: true,
          pressScale: false,
          builder: (context, s) => DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(theme.radius(t.radiusXs)), boxShadow: s.focused ? t.focusRing : null),
            child: Text(
              tipsOffLabel ?? strings.tipsOff,
              style: ty.body.copyWith(
                fontSize: t.fontSizeSm,
                color: s.hovered ? t.text : t.textMuted,
                decoration: TextDecoration.underline,
                decorationColor: s.hovered ? t.text : t.textMuted,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    ]);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: heading,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space3),
        decoration: BoxDecoration(
          color: uiMix(t.primary, 0.08, t.surface),
          border: Border.all(color: uiMix(t.primary, 0.28, t.border)),
          borderRadius: BorderRadius.circular(theme.radius(t.radiusLg)),
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (artBox != null) ...[artBox, SizedBox(width: t.space3)],
            Expanded(child: main),
          ]),
          if (onDismiss != null)
            PositionedDirectional(
              // The × is drawn 28px; on touch screens its tap area (48px) is centred on it.
              top: -t.space1 - _xPad(context),
              end: -t.space2 - _xPad(context),
              child: UiInteractive(
                onTap: onDismiss,
                semanticLabel: strings.dismiss,
                excludeChildSemantics: true,
                builder: (context, s) => Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: s.hovered || s.pressed ? t.surfaceHover : null,
                    borderRadius: BorderRadius.circular(t.radiusPill),
                    boxShadow: s.focused ? t.focusRing : null,
                  ),
                  child: Center(child: UiIcon(HugeIcons.strokeRoundedCancel01, size: 16, strokeWidth: 2, color: s.hovered ? t.text : t.textMuted)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// How far a 28px button's touch padding reaches past it on each side.
double _xPad(BuildContext context) => uiTouchPlatform(context) ? (uiMinTouchTarget - 28) / 2 : 0;
