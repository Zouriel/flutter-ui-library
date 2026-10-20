import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Control size, the web `UiSize`.
/// Control sizes (the web `UiSize`); [xl] (56) is for buttons, icon buttons, the hold button and
/// avatars: the one big action on a phone screen. Other controls take its height with lg text.
enum UiSize { sm, md, lg, xl }

/// Status tones shared by badges, chips and progress (the web `UiStatus`).
enum UiStatus { neutral, primary, success, warning, danger }

extension UiSizeTokens on UiSize {
  /// Control height for this size: 26 / 30 / 38 / 56.
  double height(UiTokens t) => switch (this) { UiSize.sm => t.sizeSm, UiSize.md => t.sizeMd, UiSize.lg => t.sizeLg, UiSize.xl => t.sizeXl };
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
