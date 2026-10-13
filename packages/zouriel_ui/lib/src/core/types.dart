import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Control size, the web `UiSize`.
enum UiSize { sm, md, lg }

/// Status tones shared by badges, chips and progress (the web `UiStatus`).
enum UiStatus { neutral, primary, success, warning, danger }

extension UiSizeTokens on UiSize {
  /// Control height for this size: 26 / 30 / 38.
  double height(UiTokens t) => switch (this) { UiSize.sm => t.sizeSm, UiSize.md => t.sizeMd, UiSize.lg => t.sizeLg };
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
