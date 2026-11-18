import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Where a blob toast's pill sits over its card: flush with a side, or in the middle.
enum UiBlobSide { left, center, right }

/// The numbers a blob toast's outline is built from, the web `UiBlobGeometry`.
///
/// [progress] 0 is the pill alone; 1 is the pill as a tab on a [width] x [bodyHeight] card, with a
/// concave join where the tab's sides meet the card's shoulders. In between the card grows out of
/// the pill's lower half. Above 1 (a spring overshooting) only the card's bottom edge moves.
@immutable
class UiBlobGeometry {
  const UiBlobGeometry({
    required this.width,
    required this.pillWidth,
    required this.pillHeight,
    required this.bodyHeight,
    this.side = UiBlobSide.center,
    this.progress = 1,
    this.radius = 20,
    this.fillet = 14,
  });

  /// Width of the card, and of the box the pill is placed in.
  final double width;
  final double pillWidth;
  final double pillHeight;

  /// Height of the card below the pill when fully open.
  final double bodyHeight;
  final UiBlobSide side;
  final double progress;

  /// Corner radius of the card.
  final double radius;

  /// Radius of the concave join between tab and card.
  final double fillet;

  @override
  bool operator ==(Object other) =>
      other is UiBlobGeometry &&
      other.width == width &&
      other.pillWidth == pillWidth &&
      other.pillHeight == pillHeight &&
      other.bodyHeight == bodyHeight &&
      other.side == side &&
      other.progress == progress &&
      other.radius == radius &&
      other.fillet == fillet;

  @override
  int get hashCode => Object.hash(width, pillWidth, pillHeight, bodyHeight, side, progress, radius, fillet);
}

/// One closed piece of the outline, the web `UiBlobPiece`: a rounded rectangle ([radius] > 0), a
/// plain one, or (with [filletSide]) the sliver that rounds the inside corner at [rect]'s top left,
/// its size the fillet radius, with the card running left (-1) or right (1) from it.
@immutable
class UiBlobPiece {
  const UiBlobPiece.rrect(this.rect, this.radius) : filletSide = 0;
  const UiBlobPiece.rect(this.rect)
      : radius = 0,
        filletSide = 0;

  /// The inside corner at ([x], [y]), rounded with radius [r].
  UiBlobPiece.fillet(double x, double y, double r, this.filletSide)
      : rect = Rect.fromLTWH(x, y, r, r),
        radius = r;

  final Rect rect;
  final double radius;
  final int filletSide;

  bool get isFillet => filletSide != 0;

  @override
  bool operator ==(Object other) => other is UiBlobPiece && other.rect == rect && other.radius == radius && other.filletSide == filletSide;

  @override
  int get hashCode => Object.hash(rect, radius, filletSide);

  @override
  String toString() => isFillet
      ? 'fillet(${rect.left}, ${rect.top}, r $radius, side $filletSide)'
      : '${radius > 0 ? 'rrect' : 'rect'}(${rect.left}, ${rect.top}, ${rect.right}, ${rect.bottom}${radius > 0 ? ', r $radius' : ''})';
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// The pieces whose union is the blob, the web `uiBlobPieces`. The first is always the pill.
List<UiBlobPiece> uiBlobPieces(UiBlobGeometry g) {
  final w = g.width, ph = g.pillHeight, h = g.bodyHeight;
  final pw = math.min(g.pillWidth, w);
  final p = math.max(0.0, g.progress);
  final pc = math.min(1.0, p);
  final rp = ph / 2;
  final x0 = switch (g.side) { UiBlobSide.left => 0.0, UiBlobSide.right => w - pw, UiBlobSide.center => (w - pw) / 2 };
  final xr = x0 + pw;
  final pieces = [UiBlobPiece.rrect(Rect.fromLTRB(x0, 0, xr, ph), rp)];
  if (p <= 0 || h <= 0) return pieces;

  // The card: from the flat part of the pill's lower half out to the full box.
  final cx = (x0 + xr) / 2;
  final l = _lerp(math.min(x0 + rp, cx), 0, pc);
  final r = _lerp(math.max(xr - rp, cx), w, pc);
  final t = _lerp(rp, ph, pc);
  final b = ph + h * p;
  final rb = math.max(0.0, [g.radius, (b - t) / 2, (r - l) / 2].reduce(math.min));
  pieces.add(UiBlobPiece.rrect(Rect.fromLTRB(l, t, r, b), rb));

  // The neck squares off the pill's lower half down to the card, one half per side.
  for (final side in const [-1, 1]) {
    final pillEdge = side < 0 ? x0 : xr;
    final cardEdge = side < 0 ? l : r;
    final flush = side < 0 ? x0 < 0.5 : w - xr < 0.5;
    if (flush) {
      // The tab's side runs straight into the card's: cover the card's rounded corner too.
      pieces.add(UiBlobPiece.rect(Rect.fromLTRB(math.min(cx, cardEdge), rp, math.max(cx, cardEdge), t + rb)));
      continue;
    }
    final shoulder = (cardEdge - pillEdge) * side;
    // Never past the flat part of the card's top edge.
    final neckEdge = side < 0 ? math.max(pillEdge, cardEdge + rb) : math.min(pillEdge, cardEdge - rb);
    if ((neckEdge - cx) * side > 0 && t > rp) {
      pieces.add(UiBlobPiece.rect(Rect.fromLTRB(math.min(cx, neckEdge), rp, math.max(cx, neckEdge), t)));
    }
    final f = [g.fillet, t - rp, shoulder - rb].reduce(math.min);
    if (f > 0.05) pieces.add(UiBlobPiece.fillet(pillEdge, t, f, side));
  }
  return pieces;
}

/// The blob as one [Path], every piece drawn clockwise so they add up (the web `uiBlobPath`).
Path uiBlobPath(UiBlobGeometry g) {
  final path = Path();
  for (final s in uiBlobPieces(g)) {
    if (s.isFillet) {
      final x = s.rect.left, y = s.rect.top, r = s.radius;
      if (s.filletSide < 0) {
        path
          ..moveTo(x, y - r)
          ..lineTo(x, y)
          ..lineTo(x - r, y)
          ..arcToPoint(Offset(x, y - r), radius: Radius.circular(r), clockwise: false)
          ..close();
      } else {
        path
          ..moveTo(x + r, y)
          ..lineTo(x, y)
          ..lineTo(x, y - r)
          ..arcToPoint(Offset(x + r, y), radius: Radius.circular(r), clockwise: false)
          ..close();
      }
    } else if (s.radius > 0) {
      path.addRRect(RRect.fromRectAndRadius(s.rect, Radius.circular(s.radius)));
    } else {
      path.addRect(s.rect);
    }
  }
  return path;
}

/// A status colour moved to where it reads on the inverted surface a blob toast sits on: the same
/// hue and strength of colour as [tone], at a lightness 80% of the way to [page]'s (in OKLab, as the
/// web does with `oklch(from color-mix(in oklab, ...))`).
Color uiBlobTone(Color tone, Color page) {
  final a = _oklab(tone), b = _oklab(page);
  return _fromOklab(a.$1 * 0.2 + b.$1 * 0.8, a.$2, a.$3, tone.a);
}

double _toLinear(double c) => c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
double _fromLinear(double c) => c <= 0.0031308 ? c * 12.92 : 1.055 * math.pow(c, 1 / 2.4) - 0.055;
double _cbrt(double v) => v < 0 ? -math.pow(-v, 1 / 3).toDouble() : math.pow(v, 1 / 3).toDouble();

(double, double, double) _oklab(Color c) {
  final r = _toLinear(c.r), g = _toLinear(c.g), b = _toLinear(c.b);
  final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  return (
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  );
}

Color _fromOklab(double lightness, double a, double b, double alpha) {
  final l = math.pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3).toDouble();
  final m = math.pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3).toDouble();
  final s = math.pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3).toDouble();
  double ch(double v) => _fromLinear(v).clamp(0.0, 1.0);
  return Color.from(
    alpha: alpha,
    red: ch(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
    green: ch(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
    blue: ch(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s),
  );
}
