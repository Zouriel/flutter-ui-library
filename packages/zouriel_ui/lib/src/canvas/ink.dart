/// Ink for [UiPathEditor]'s draw mode (the web `canvas/ink.ts`): how a brush turns the samples of
/// a stroke (where the pen went, and how hard it pressed) into the area it paints.
///
/// A brush is a nib: a circle, or a flat ellipse held at an angle, whose size follows the pressure
/// (or, for a mouse or a finger, how fast it moves). At every sample the nib leaves a stamp; the
/// area between two stamps is their convex hull. The stroke is the union of those hulls. Every hull
/// winds the same way, so drawing them as one path with the non-zero rule shows that union without
/// computing it.
///
/// All pure: the editor collects samples, these functions shape them.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Path, PathFillType;

import 'package:flutter/foundation.dart';

enum UiBrushKind { pen, marker, pencil, brush, calligraphy, eraser }

@immutable
class UiBrush {
  const UiBrush({this.kind = UiBrushKind.pen, this.size = 4});
  final UiBrushKind kind;

  /// Nib width at normal pressure, in editor units.
  final double size;

  @override
  bool operator ==(Object other) => other is UiBrush && other.kind == kind && other.size == size;

  @override
  int get hashCode => Object.hash(kind, size);
}

/// Where the pen was and how hard it pressed (0…1). Pens report pressure; for a mouse or finger it
/// is worked out from speed.
@immutable
class UiInkSample {
  const UiInkSample(this.x, this.y, [this.pressure = 0.5]);
  final double x;
  final double y;
  final double pressure;

  Offset get offset => Offset(x, y);

  UiInkSample withPressure(double p) => UiInkSample(x, y, p);

  @override
  bool operator ==(Object other) => other is UiInkSample && other.x == x && other.y == y && other.pressure == pressure;

  @override
  int get hashCode => Object.hash(x, y, pressure);
}

class _Profile {
  const _Profile({required this.pressure, required this.speed, required this.aspect, required this.angle, required this.taperStart, required this.taperEnd, required this.steady});

  /// How much pressure changes the width (0 none, 1 from a hairline to wide).
  final double pressure;

  /// For a finger or mouse: how much speed thins the line.
  final double speed;

  /// Nib shape: aspect (1 round) and angle in degrees.
  final double aspect;
  final double angle;

  /// Taper at the start and end, in nib widths.
  final double taperStart;
  final double taperEnd;

  /// How much the input is steadied (0 raw, 0.8 very smooth).
  final double steady;
}

const Map<UiBrushKind, _Profile> _profiles = {
  // A fineliner: even, a touch of pressure so it doesn't look mechanical.
  UiBrushKind.pen: _Profile(pressure: 0.2, speed: 0, aspect: 1, angle: 0, taperStart: 0, taperEnd: 0, steady: 0.35),
  // A chisel marker: broad, flat, even.
  UiBrushKind.marker: _Profile(pressure: 0, speed: 0, aspect: 0.45, angle: -35, taperStart: 0, taperEnd: 0, steady: 0.45),
  // A pencil: thin, very pressure-sensitive.
  UiBrushKind.pencil: _Profile(pressure: 0.85, speed: 0.2, aspect: 1, angle: 0, taperStart: 0.6, taperEnd: 0.6, steady: 0.3),
  // A round brush: swells with pressure, thins when fast, comes to a point at both ends.
  UiBrushKind.brush: _Profile(pressure: 0.9, speed: 0.6, aspect: 1, angle: 0, taperStart: 3, taperEnd: 4, steady: 0.5),
  // A broad-edge pen: thick across the nib, hairline along it.
  UiBrushKind.calligraphy: _Profile(pressure: 0.45, speed: 0, aspect: 0.14, angle: 45, taperStart: 0, taperEnd: 0, steady: 0.45),
  UiBrushKind.eraser: _Profile(pressure: 0, speed: 0, aspect: 1, angle: 0, taperStart: 0, taperEnd: 0, steady: 0.3),
};

/// How much a brush smooths the pen's path as it is drawn (0 raw … 1 very smooth).
double brushSteadiness(UiBrushKind kind) => _profiles[kind]!.steady;

/// Whether a brush's width follows pressure at all (a host can show that in its brush picker).
bool brushUsesPressure(UiBrushKind kind) => _profiles[kind]!.pressure > 0;

/// Pressure for pointers that don't have any: slow is firm, fast is light. [prev] is the pressure
/// worked out for the sample before, [distance] how far the pointer went since, in editor units.
double simulatedPressure(UiBrushKind kind, double prev, double distance, double size) {
  final speed = math.min(1.0, distance / math.max(0.5, size * 1.2));
  final target = 0.5 + _profiles[kind]!.speed * (0.15 - 0.45 * speed);
  return prev + (target - prev) * 0.35;
}

double _ease(double t) => 0.15 + 0.85 * math.sin(t * math.pi / 2);

/// p = 0.5 draws at the brush's size; harder is wider, lighter is thinner.
double _pressureFactor(_Profile pr, double pressure) => 1 + pr.pressure * (pressure.clamp(0.0, 1.0) - 0.5) * 1.6;

/// The nib's half-size at each sample, pressure and tapering applied. While the stroke is still
/// being drawn ([finished] false) its end isn't known, so only the start tapers.
List<double> inkRadii(List<UiInkSample> samples, UiBrush brush, {bool finished = true}) {
  final pr = _profiles[brush.kind]!;
  final base = math.max(0.05, brush.size / 2);
  final lengths = <double>[0];
  for (var i = 1; i < samples.length; i++) {
    lengths.add(lengths[i - 1] + (samples[i].offset - samples[i - 1].offset).distance);
  }
  final total = lengths.isEmpty ? 0.0 : lengths.last;
  final startLen = pr.taperStart * brush.size;
  final endLen = pr.taperEnd * brush.size;
  return [
    for (var i = 0; i < samples.length; i++)
      () {
        var f = _pressureFactor(pr, samples[i].pressure);
        if (startLen > 0) {
          var span = finished ? math.min(startLen, total / 2) : startLen;
          if (span == 0) span = 1;
          f *= _ease(math.min(1.0, lengths[i] / span));
        }
        if (finished && endLen > 0 && total > 0) f *= _ease(math.min(1.0, (total - lengths[i]) / math.min(endLen, total / 2)));
        return base * math.max(0.08, f);
      }(),
  ];
}

/// One sample's radius while drawing, [along] being how far into the stroke it is.
double inkRadiusAt(UiInkSample sample, double along, UiBrush brush) {
  final pr = _profiles[brush.kind]!;
  var f = _pressureFactor(pr, sample.pressure);
  final startLen = pr.taperStart * brush.size;
  if (startLen > 0) f *= _ease(math.min(1.0, along / startLen));
  return math.max(0.05, brush.size / 2) * math.max(0.08, f);
}

int _stampSegments(_Profile pr, double r) => pr.aspect < 0.3 ? 12 : (8 + r * 1.5).round().clamp(10, 28);

/// The nib's outline at one sample.
List<Offset> _stamp(Offset at, double r, _Profile pr, int segments) {
  final a = pr.angle * math.pi / 180;
  final cos = math.cos(a), sin = math.sin(a);
  final ry = math.max(r * pr.aspect, 0.04);
  return [
    for (var k = 0; k < segments; k++)
      () {
        final t = k * 2 * math.pi / segments;
        final x = r * math.cos(t), y = ry * math.sin(t);
        return Offset(at.dx + x * cos - y * sin, at.dy + x * sin + y * cos);
      }(),
  ];
}

/// The painted piece between two samples (or a single dot when [b] is null).
List<Offset> inkPiece(Offset a, double ra, Offset? b, double rb, UiBrush brush) {
  final pr = _profiles[brush.kind]!;
  final sa = _stamp(a, ra, pr, _stampSegments(pr, ra));
  return convexHull(b != null ? [...sa, ..._stamp(b, rb, pr, _stampSegments(pr, rb))] : sa);
}

/// Convex hull (Andrew's monotone chain), counter-clockwise in screen terms.
List<Offset> convexHull(List<Offset> points) {
  final pts = [...points]..sort((a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy));
  if (pts.length < 3) return pts;
  double cross(Offset o, Offset a, Offset b) => (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
  final lower = <Offset>[];
  for (final p in pts) {
    while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], p) <= 0) {
      lower.removeLast();
    }
    lower.add(p);
  }
  final upper = <Offset>[];
  for (var i = pts.length - 1; i >= 0; i--) {
    final p = pts[i];
    while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], p) <= 0) {
      upper.removeLast();
    }
    upper.add(p);
  }
  upper.removeLast();
  lower.removeLast();
  return [...lower, ...upper];
}

/// The area a stroke paints, as convex pieces that all wind the same way: one per step between
/// samples (a single sample is one stamp, a dot). Their union is the stroke.
List<List<Offset>> inkArea(List<UiInkSample> samples, UiBrush brush) {
  if (samples.isEmpty) return [];
  final radii = inkRadii(samples, brush);
  if (samples.length == 1) return [inkPiece(samples[0].offset, radii[0], null, 0, brush)];
  return [for (var i = 1; i < samples.length; i++) inkPiece(samples[i - 1].offset, radii[i - 1], samples[i].offset, radii[i], brush)];
}

String _r2(double n) {
  final v = (n * 100).round() / 100;
  return v == v.roundToDouble() ? v.round().toString() : v.toString();
}

/// The pieces as one SVG path (draw it with `fill-rule: nonzero`).
String inkD(List<List<Offset>> pieces) => pieces.map(pieceD).join();

String pieceD(List<Offset> piece) {
  if (piece.isEmpty) return '';
  final b = StringBuffer('M${_r2(piece[0].dx)} ${_r2(piece[0].dy)}');
  for (var i = 1; i < piece.length; i++) {
    b.write('L${_r2(piece[i].dx)} ${_r2(piece[i].dy)}');
  }
  b.write('Z');
  return b.toString();
}

/// The pieces as one Flutter [Path] (non-zero fill), the canvas twin of [inkD].
Path inkPath(List<List<Offset>> pieces) {
  final path = Path()..fillType = PathFillType.nonZero;
  for (final piece in pieces) {
    if (piece.isNotEmpty) path.addPolygon(piece, true);
  }
  return path;
}

/// Samples closer together than [spacing] merge into one (the kept one takes the heaviest
/// pressure), so a pen resting in place doesn't pile up stamps. The last sample is always kept.
List<UiInkSample> thinSamples(List<UiInkSample> samples, double spacing) {
  final out = <UiInkSample>[];
  for (final s in samples) {
    if (out.isNotEmpty && (s.offset - out.last.offset).distance < spacing) {
      final last = out.last;
      out[out.length - 1] = last.withPressure(math.max(last.pressure, s.pressure));
      continue;
    }
    out.add(s);
  }
  if (samples.isNotEmpty && out.isNotEmpty) {
    final end = samples.last, kept = out.last;
    if (kept.x != end.x || kept.y != end.y) out.add(end);
  }
  return out;
}

// ----- Snap to shape -------------------------------------------------------------------------------
//
// Hold the pen still at the end of a stroke and it snaps to what it looked like: a straight line,
// a circle or ellipse, a rectangle, a triangle, drawn with the same brush.

/// What a stroke was recognised as.
sealed class UiInkShape {
  const UiInkShape();
}

class UiInkLine extends UiInkShape {
  const UiInkLine(this.from, this.to);
  final Offset from;
  final Offset to;
}

class UiInkEllipse extends UiInkShape {
  const UiInkEllipse(this.cx, this.cy, this.rx, this.ry);
  final double cx, cy, rx, ry;
}

class UiInkPolygon extends UiInkShape {
  const UiInkPolygon(this.points);
  final List<Offset> points;
}

/// What a stroke most looks like, or null if it's just a scribble.
UiInkShape? recognizeShape(List<Offset> samples) {
  if (samples.length < 3) return null;
  final first = samples.first, last = samples.last;
  var minX = double.infinity, minY = double.infinity, maxX = double.negativeInfinity, maxY = double.negativeInfinity, length = 0.0;
  for (var i = 0; i < samples.length; i++) {
    final p = samples[i];
    minX = math.min(minX, p.dx);
    minY = math.min(minY, p.dy);
    maxX = math.max(maxX, p.dx);
    maxY = math.max(maxY, p.dy);
    if (i > 0) length += (p - samples[i - 1]).distance;
  }
  final size = Offset(maxX - minX, maxY - minY).distance;
  if (size < 1e-6 || length < 1e-6) return null;
  final gap = (last - first).distance;

  // Straight: the ends are nearly as far apart as the stroke is long.
  if (gap / length > 0.94) return UiInkLine(first, last);
  // Anything else has to come back round to where it started.
  if (gap > math.max(size * 0.28, length * 0.12)) return null;

  final loop = [...samples];
  final corners = _cornerPoints(loop, size * 0.09);
  if (corners.length == 3 || corners.length == 4) {
    final fit = _polygonFit(loop, corners);
    if (fit < size * 0.06) return UiInkPolygon(corners.length == 4 ? _squareUp(corners) : corners);
  }
  final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2, rx = (maxX - minX) / 2, ry = (maxY - minY) / 2;
  // Ellipse: every sample is about the same normalised distance from the middle.
  var off = 0.0;
  for (final p in loop) {
    final d = Offset((p.dx - cx) / math.max(rx, 1e-6), (p.dy - cy) / math.max(ry, 1e-6)).distance;
    off = math.max(off, (d - 1).abs());
  }
  if (off < 0.3) {
    // Nearly round is round.
    final r = (rx + ry) / 2;
    return (rx - ry).abs() / r < 0.14 ? UiInkEllipse(cx, cy, r, r) : UiInkEllipse(cx, cy, rx, ry);
  }
  return null;
}

/// The corners of a closed stroke, by simplifying it until only the sharp turns are left.
List<Offset> _cornerPoints(List<Offset> loop, double tolerance) {
  final pts = _rdp([...loop, loop[0]], tolerance)..removeLast();
  // Neighbouring corners closer than a tolerance are one corner (where the stroke closed up).
  final merged = <Offset>[];
  for (final p in pts) {
    if (merged.isNotEmpty && (p - merged.last).distance < tolerance * 2.5) continue;
    merged.add(p);
  }
  if (merged.length > 2 && (merged.first - merged.last).distance < tolerance * 2.5) merged.removeLast();
  return merged;
}

List<Offset> _rdp(List<Offset> points, double tolerance) {
  if (points.length < 3) return points;
  final a = points.first, b = points.last;
  var far = -1;
  var dist = tolerance;
  for (var i = 1; i < points.length - 1; i++) {
    final d = _distanceToSegment(points[i], a, b);
    if (d > dist) {
      dist = d;
      far = i;
    }
  }
  if (far < 0) return [a, b];
  final left = _rdp(points.sublist(0, far + 1), tolerance);
  final right = _rdp(points.sublist(far), tolerance);
  return [...left.sublist(0, left.length - 1), ...right];
}

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final dx = b.dx - a.dx, dy = b.dy - a.dy;
  final len = dx * dx + dy * dy;
  final t = len != 0 ? (((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / len).clamp(0.0, 1.0) : 0.0;
  return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
}

/// How far the stroke strays from the polygon through the corners, at its worst.
double _polygonFit(List<Offset> loop, List<Offset> corners) {
  var worst = 0.0;
  for (final p in loop) {
    var best = double.infinity;
    for (var i = 0; i < corners.length; i++) {
      best = math.min(best, _distanceToSegment(p, corners[i], corners[(i + 1) % corners.length]));
    }
    worst = math.max(worst, best);
  }
  return worst;
}

/// A four-cornered stroke that's nearly a rectangle becomes one (sides square to the page if close).
List<Offset> _squareUp(List<Offset> corners) {
  final xs = corners.map((p) => p.dx), ys = corners.map((p) => p.dy);
  final minX = xs.reduce(math.min), maxX = xs.reduce(math.max), minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
  final w = maxX - minX, h = maxY - minY;
  // Each corner near a corner of the box? Then it's an upright rectangle.
  final box = [Offset(minX, minY), Offset(maxX, minY), Offset(maxX, maxY), Offset(minX, maxY)];
  final near = corners.every((p) => box.any((q) => (p - q).distance < math.max(w, h) * 0.2));
  if (!near) return corners;
  // Keep the direction it was drawn in.
  var start = 0;
  for (var i = 1; i < 4; i++) {
    if ((corners[0] - box[i]).distance < (corners[0] - box[start]).distance) start = i;
  }
  var area = 0.0;
  for (var i = 0; i < 4; i++) {
    final p = corners[i], q = corners[(i + 1) % 4];
    area += p.dx * q.dy - q.dx * p.dy;
  }
  final order = area > 0 ? [0, 1, 2, 3] : [0, 3, 2, 1];
  return [for (final k in order) box[(start + k) % 4]];
}

/// Samples along a recognised shape, at the stroke's average [pressure], so the snapped shape is
/// drawn with the same brush as the stroke it replaced.
List<UiInkSample> shapeSamples(UiInkShape shape, double pressure, double step) {
  final out = <UiInkSample>[];
  void along(Offset a, Offset b, bool withEnd) {
    final n = math.max(1, ((b - a).distance / step).ceil());
    for (var i = 0; i < n + (withEnd ? 1 : 0); i++) {
      out.add(UiInkSample(a.dx + (b.dx - a.dx) * i / n, a.dy + (b.dy - a.dy) * i / n, pressure));
    }
  }

  switch (shape) {
    case UiInkLine(:final from, :final to):
      along(from, to, true);
    case UiInkPolygon(:final points):
      for (var i = 0; i < points.length; i++) {
        along(points[i], points[(i + 1) % points.length], i == points.length - 1);
      }
    case UiInkEllipse(:final cx, :final cy, :final rx, :final ry):
      final n = math.max(24, (math.pi * 2 * math.max(rx, ry) / step).ceil());
      for (var i = 0; i <= n; i++) {
        final t = -math.pi / 2 + i * 2 * math.pi / n;
        out.add(UiInkSample(cx + rx * math.cos(t), cy + ry * math.sin(t), pressure));
      }
  }
  return out;
}
