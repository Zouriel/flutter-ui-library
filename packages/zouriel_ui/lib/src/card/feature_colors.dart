import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A [UiFeatureCard]'s own colours (the web `UiFeatureCardColors`): an app's surface and accent,
/// with the dark-theme pair derived when it isn't given, and every colour contrast-checked. The same
/// sums run on the web, so both libraries pick the same colours.
@immutable
class UiFeatureCardColors {
  const UiFeatureCardColors({required this.surface, required this.accent, this.surfaceDark, this.accentDark});

  /// From colour strings (`#rgb`, `#rrggbb`, with or without alpha, `rgb()` / `rgba()`), as the web
  /// takes them. Null when one can't be read: the card then keeps its tone (and a debug build says so).
  static UiFeatureCardColors? tryParse({required String surface, required String accent, String? surfaceDark, String? accentDark}) {
    final s = uiParseColor(surface), a = uiParseColor(accent);
    final sd = surfaceDark == null ? null : uiParseColor(surfaceDark);
    final ad = accentDark == null ? null : uiParseColor(accentDark);
    if (s == null || a == null || (surfaceDark != null && sd == null) || (accentDark != null && ad == null)) {
      if (kDebugMode) debugPrint('UiFeatureCardColors: colours must be hex (#rgb, #rrggbb) or rgb() strings; using the tone instead.');
      return null;
    }
    return UiFeatureCardColors(surface: s, accent: a, surfaceDark: sd, accentDark: ad);
  }

  /// The card's background (the wash; with a tinted surface it replaces the tone's).
  final Color surface;

  /// The badge tint (14% over the surface), the icon, the trailing arrow, the hover/focus border and
  /// the action words.
  final Color accent;

  /// The surface on a dark theme. Derived when null: the accent 18% into the theme's surface.
  final Color? surfaceDark;

  /// The accent on a dark theme. Derived when null: lightened until it reads 4.5:1 on the surface.
  final Color? accentDark;

  @override
  bool operator ==(Object other) =>
      other is UiFeatureCardColors && other.surface == surface && other.accent == accent && other.surfaceDark == surfaceDark && other.accentDark == accentDark;

  @override
  int get hashCode => Object.hash(surface, accent, surfaceDark, accentDark);
}

/// What a card with custom colours draws (the web `UiFeatureResolvedColors`).
@immutable
class UiFeatureResolvedColors {
  const UiFeatureResolvedColors({required this.surface, required this.accent, required this.badge, required this.ink, required this.desc});

  /// The card's background.
  final Color surface;

  /// Icon, arrow and hover/focus border: at least 3:1 on the surface and on the badge (4.5:1 on dark).
  final Color accent;

  /// The badge fill.
  final Color badge;

  /// The action words and eyebrow: the accent moved until 4.5:1 on the surface.
  final Color ink;

  /// The description: the theme's muted text moved towards the text until 4.5:1 on the surface.
  final Color desc;
}

/// Parses `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`, `rgb(r, g, b)`, `rgba(r g b / a)` into an opaque
/// colour (alpha is ignored, as on the web); null when it isn't one.
Color? uiParseColor(String value) {
  final s = value.trim().toLowerCase();
  final hex = RegExp(r'^#([0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})$').firstMatch(s);
  if (hex != null) {
    final h = hex.group(1)!;
    int at(int i) => h.length <= 4 ? int.parse(h[i] + h[i], radix: 16) : int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
    return Color.fromARGB(255, at(0), at(1), at(2));
  }
  final rgb = RegExp(r'^rgba?\(\s*([\d.]+)[\s,]+([\d.]+)[\s,]+([\d.]+)\s*(?:[,/]\s*[\d.]+%?\s*)?\)$').firstMatch(s);
  if (rgb != null) {
    final c = [rgb.group(1), rgb.group(2), rgb.group(3)].map((x) => double.tryParse(x!)).toList();
    if (c.any((n) => n == null || n > 255)) return null;
    return Color.fromARGB(255, c[0]!.round(), c[1]!.round(), c[2]!.round());
  }
  return null;
}

/// WCAG contrast ratio of two opaque colours.
double uiContrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// [k] of [a] over `1 - k` of [b] (CSS `color-mix(in srgb, a k, b)`), in whole channel values.
Color _mix(Color a, Color b, double k) {
  int ch(double x, double y) => (x * 255 * k + y * 255 * (1 - k)).round().clamp(0, 255);
  return Color.fromARGB(255, ch(a.r, b.r), ch(a.g, b.g), ch(a.b, b.b));
}

/// A translucent colour composited over an opaque ground.
Color _over(Color c, Color ground) => _mix(c.withValues(alpha: 1), ground, c.a);

/// Moves [c] towards [to] in 2% steps until [ok] holds (or it reaches [to]).
Color _towards(Color c, Color to, bool Function(Color) ok) {
  for (var i = 0; i <= 50; i++) {
    final x = _mix(to, c, i / 50);
    if (ok(x)) return x;
  }
  return _mix(to, c, 1);
}

/// The lightening target for derived dark accents (a sum, not a colour drawn).
const Color _white = Color.fromARGB(255, 255, 255, 255);

/// The colours a card with [colors] draws on a theme (the web `uiResolveFeatureColors`).
UiFeatureResolvedColors uiResolveFeatureColors(
  UiFeatureCardColors colors, {
  required Color themeSurface,
  required Color themeText,
  required Color themeMuted,
  required bool dark,
}) {
  final surface = colors.surface.withValues(alpha: 1), accent = colors.accent.withValues(alpha: 1);
  final s = dark ? (colors.surfaceDark?.withValues(alpha: 1) ?? _mix(accent, _over(themeSurface, _white), 0.18)) : surface;
  Color badgeOf(Color a, [double k = 0.14]) => _mix(a, s, k);
  var a = dark ? (colors.accentDark?.withValues(alpha: 1) ?? accent) : accent;
  if (dark && colors.accentDark == null) {
    // Lighten until the arrow reads 4.5:1 on the card and the icon 3:1 on its badge.
    a = _towards(a, _white, (x) => uiContrast(x, s) >= 4.5 && uiContrast(x, badgeOf(x)) >= 3);
  }
  // A lighter badge tint (down to 6%) before touching the app's accent.
  var k = 0.14;
  while (k > 0.06 + 1e-9 && uiContrast(a, badgeOf(a, k)) < 3) {
    k -= 0.02;
  }
  final text = _over(themeText, s), muted = _over(themeMuted, s);
  if (uiContrast(a, badgeOf(a, k)) < 3 || uiContrast(a, s) < 3) {
    // Still too faint: move the accent towards the text (darker on light, lighter on dark).
    final kk = k;
    a = _towards(a, text, (x) => uiContrast(x, s) >= 3 && uiContrast(x, badgeOf(x, kk)) >= 3);
  }
  final ink = uiContrast(a, s) >= 4.5 ? a : _towards(a, text, (x) => uiContrast(x, s) >= 4.5);
  final desc = uiContrast(muted, s) >= 4.5 ? muted : _towards(muted, text, (x) => uiContrast(x, s) >= 4.5);
  return UiFeatureResolvedColors(surface: s, accent: a, badge: badgeOf(a, k), ink: ink, desc: desc);
}
