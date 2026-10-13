import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

part 'tokens.g.dart';

/// A CSS `linear-gradient` as the web library declares it: an angle in CSS degrees
/// (0 = towards the top, 90 = towards the right) plus colour stops.
@immutable
class UiGradientSpec {
  const UiGradientSpec({required this.angle, required this.colors, required this.stops});

  final double angle;
  final List<Color> colors;
  final List<double> stops;

  /// The Flutter gradient. CSS angles point the way the gradient travels, measured clockwise from
  /// the top; this maps them onto Flutter's alignment space.
  LinearGradient toGradient() {
    final rad = angle * math.pi / 180;
    final dx = math.sin(rad), dy = -math.cos(rad);
    return LinearGradient(begin: Alignment(-dx, -dy), end: Alignment(dx, dy), colors: colors, stops: stops);
  }

  static UiGradientSpec? lerp(UiGradientSpec? a, UiGradientSpec? b, double t) {
    if (a == null || b == null) return t < 0.5 ? a : b;
    if (a.colors.length != b.colors.length) return t < 0.5 ? a : b;
    return UiGradientSpec(
      angle: lerpDouble(a.angle, b.angle, t)!,
      colors: [for (var i = 0; i < a.colors.length; i++) Color.lerp(a.colors[i], b.colors[i], t)!],
      stops: [for (var i = 0; i < a.stops.length; i++) lerpDouble(a.stops[i], b.stops[i], t)!],
    );
  }
}
