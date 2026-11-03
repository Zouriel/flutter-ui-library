import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Control size, the web `UiSize`.
/// Control sizes (the web `UiSize`); [xl] (56) is for buttons, icon buttons, the hold button and
/// avatars: the one big action on a phone screen. Other controls take its height with lg text.
enum UiSize { sm, md, lg, xl }

/// Status tones shared by badges, chips and progress (the web `UiStatus`).
enum UiStatus { neutral, primary, success, warning, danger }

/// A premium tier on [UiBadge] (the web `UiBadgeTier`): not a status, so it stays out of [UiStatus]
/// and everything that switches on it.
enum UiBadgeTier { gold, platinum, premium }

/// A plan tier (the web `UiTier`): the same metals as [UiBadgeTier], for buttons, plan cards and the
/// plan comparison as well as badges.
typedef UiTier = UiBadgeTier;

extension UiSizeTokens on UiSize {
  /// Control height for this size: 26 / 30 / 38 / 56.
  double height(UiTokens t) => switch (this) { UiSize.sm => t.sizeSm, UiSize.md => t.sizeMd, UiSize.lg => t.sizeLg, UiSize.xl => t.sizeXl };
}

extension UiBadgeTierColors on UiBadgeTier {
  /// The metal's sheen (`--ui-gradient-tier-*`).
  UiGradientSpec gradient(UiTokens t) => switch (this) { UiBadgeTier.gold => t.gradientTierGold, UiBadgeTier.platinum => t.gradientTierPlatinum, UiBadgeTier.premium => t.gradientTierPremium };

  /// The metal's base colour, the ends of the sheen (`--ui-tier-*`).
  Color base(UiTokens t) => switch (this) { UiBadgeTier.gold => t.tierGold, UiBadgeTier.platinum => t.tierPlatinum, UiBadgeTier.premium => t.tierPremium };

  /// The sheen's light middle stop (`--ui-tier-*-light`).
  Color light(UiTokens t) => switch (this) { UiBadgeTier.gold => t.tierGoldLight, UiBadgeTier.platinum => t.tierPlatinumLight, UiBadgeTier.premium => t.tierPremiumLight };

  /// Text on the metal.
  Color contrast(UiTokens t) => switch (this) { UiBadgeTier.gold => t.tierGoldContrast, UiBadgeTier.platinum => t.tierPlatinumContrast, UiBadgeTier.premium => t.tierPremiumContrast };

  /// The edge that keeps the pill visible on any page (darker for gold and platinum, lighter for
  /// premium); also a tier button's focus ring.
  Color border(UiTokens t) => switch (this) { UiBadgeTier.gold => t.tierGoldBorder, UiBadgeTier.platinum => t.tierPlatinumBorder, UiBadgeTier.premium => t.tierPremiumBorder };
}

extension UiStatusColors on UiStatus {
  /// The tone's colour (neutral uses muted text).
  Color color(UiTokens t) => switch (this) {
        UiStatus.neutral => t.textMuted,
        UiStatus.primary => t.primary,
        UiStatus.success => t.success,
        UiStatus.warning => t.warning,
        UiStatus.danger => t.danger,
      };

  /// Text colour on a solid fill of [color].
  Color contrast(UiTokens t) => switch (this) {
        UiStatus.neutral => t.bg,
        UiStatus.primary => t.primaryContrast,
        UiStatus.success => t.successContrast,
        UiStatus.warning => t.warningContrast,
        UiStatus.danger => t.dangerContrast,
      };
}

/// `color-mix(in srgb, a p%, b)`: the CSS mixing the web tokens use, for tints built in code.
Color uiMix(Color a, double p, Color b) => Color.lerp(b, a, p)!;
