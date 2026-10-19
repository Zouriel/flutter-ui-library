import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

part 'tokens.g.dart';

/// A CSS spread-only shadow (`0 0 0 Npx colour`), the ring the focus ring is made of. CSS never
/// paints an outer shadow under its own box, but a plain [BoxShadow] is a filled box that does: on
/// a see-through control (ghost button, calendar day) the ring's page-coloured gap layer would fill
/// the whole inside. This paints only the band from the box edge out to [spread].
@immutable
class UiRingShadow extends BoxShadow {
  const UiRingShadow({super.color, required this.spread}) : super(spreadRadius: spread / 2);

  /// How far the ring reaches out from the box edge.
  final double spread;

  // BoxDecoration paints a shadow as its box grown by spreadRadius; stroking that outline with a
  // [spread]-wide pen covers exactly the band from the edge out to [spread].
  @override
  Paint toPaint() => Paint()
    ..color = spread > 0 ? color : const Color(0x00000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = spread;

  @override
  UiRingShadow scale(double factor) => UiRingShadow(color: color, spread: spread * factor);

  /// [BoxShadow.lerpList] that keeps rings as rings (it would turn them into filled boxes).
  static List<BoxShadow>? lerpList(List<BoxShadow>? a, List<BoxShadow>? b, double t) {
    if (identical(a, b)) return a;
    if (a == null && b == null) return null;
    final x = a ?? const <BoxShadow>[], y = b ?? const <BoxShadow>[];
    return [
      for (var i = 0; i < math.max(x.length, y.length); i++)
        switch ((i < x.length ? x[i] : null, i < y.length ? y[i] : null)) {
          (final UiRingShadow p, final UiRingShadow q) => UiRingShadow(color: Color.lerp(p.color, q.color, t)!, spread: lerpDouble(p.spread, q.spread, t)!),
          (final p, final q) => BoxShadow.lerp(p, q, t)!,
        },
    ];
  }
}

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
