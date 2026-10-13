/// Vector outlines for [UiPathEditor] (the web `canvas/path.ts`): points with optional curve
/// handles, grouped into contours, grouped into items. Every function here is pure: it returns new
/// values and never mutates, so a host can keep its own history of edits.
///
/// Coordinates are absolute in the editor's units, handles included. A point with neither handle is
/// a corner; one with handles is smooth, and the segment on either side of it is a cubic Bézier.
library;

import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Path, Rect;

import 'package:flutter/foundation.dart';

/// A point of an outline (the web `UiPathPoint`). [handleIn] is the curve handle on the side of the
/// previous point, [handleOut] on the side of the next (`in` / `out` on the web; `in` is a Dart
/// keyword).
@immutable
class UiPathPoint {
  const UiPathPoint(this.x, this.y, {this.handleIn, this.handleOut});

  UiPathPoint.at(Offset p, {this.handleIn, this.handleOut})
      : x = p.dx,
        y = p.dy;

  final double x;
  final double y;
  final Offset? handleIn;
  final Offset? handleOut;

  Offset get offset => Offset(x, y);

  /// A smooth point has at least one handle.
  bool get smooth => handleIn != null || handleOut != null;

  /// A copy; pass [clearIn] / [clearOut] to drop a handle.
  UiPathPoint copyWith({double? x, double? y, Offset? handleIn, Offset? handleOut, bool clearIn = false, bool clearOut = false}) => UiPathPoint(
        x ?? this.x,
        y ?? this.y,
        handleIn: clearIn ? null : (handleIn ?? this.handleIn),
        handleOut: clearOut ? null : (handleOut ?? this.handleOut),
      );

  /// The web JSON shape: `{ x, y, in?, out? }`.
  Map<String, Object?> toJson() => {
        'x': x,
        'y': y,
        'in': handleIn == null ? null : {'x': handleIn!.dx, 'y': handleIn!.dy},
        'out': handleOut == null ? null : {'x': handleOut!.dx, 'y': handleOut!.dy},
      };

  factory UiPathPoint.fromJson(Map<String, Object?> json) {
    Offset? xy(Object? v) => v is Map ? Offset((v['x'] as num).toDouble(), (v['y'] as num).toDouble()) : null;
    return UiPathPoint((json['x'] as num).toDouble(), (json['y'] as num).toDouble(), handleIn: xy(json['in']), handleOut: xy(json['out']));
  }

  @override
  bool operator ==(Object other) => other is UiPathPoint && other.x == x && other.y == y && other.handleIn == handleIn && other.handleOut == handleOut;

  @override
  int get hashCode => Object.hash(x, y, handleIn, handleOut);

  @override
  String toString() => 'UiPathPoint($x, $y${handleIn != null ? ', in: $handleIn' : ''}${handleOut != null ? ', out: $handleOut' : ''})';
}

/// One outline. Closed outlines are filled; open ones are lines.
@immutable
class UiPathContour {
  const UiPathContour({required this.points, this.closed = false});

  final List<UiPathPoint> points;
  final bool closed;

  Map<String, Object?> toJson() => {'points': [for (final p in points) p.toJson()], 'closed': closed};

  factory UiPathContour.fromJson(Map<String, Object?> json) => UiPathContour(
        points: [for (final p in json['points']! as List) UiPathPoint.fromJson((p as Map).cast<String, Object?>())],
        closed: json['closed'] == true,
      );

  @override
  bool operator ==(Object other) => other is UiPathContour && other.closed == closed && listEquals(other.points, points);

  @override
  int get hashCode => Object.hash(closed, Object.hashAll(points));
}

/// How an item combines with the items below it, as in Photoshop's path operations.
enum UiPathOp { add, cut, intersect, exclude }

/// A shape on the editor: one or more contours, plus how it combines and how it is filled.
@immutable
class UiPathItem {
  const UiPathItem({required this.id, required this.contours, this.cut = false, this.op, this.fill, this.name});

  final String id;
  final List<UiPathContour> contours;

  /// Cut this out of the items below it (the older form of `op: cut`).
  final bool cut;
  final UiPathOp? op;

  /// Paint for the item's fill preview in the editor.
  final Color? fill;
  final String? name;

  UiPathItem copyWith({List<UiPathContour>? contours, String? name, Color? fill, UiPathOp? op}) =>
      UiPathItem(id: id, contours: contours ?? this.contours, cut: cut, op: op ?? this.op, fill: fill ?? this.fill, name: name ?? this.name);

  @override
  bool operator ==(Object other) =>
      other is UiPathItem && other.id == id && other.cut == cut && other.op == op && other.fill == fill && other.name == name && listEquals(other.contours, contours);

  @override
  int get hashCode => Object.hash(id, cut, op, fill, name, Object.hashAll(contours));
}

/// An item's operation, reading the older [UiPathItem.cut] flag too.
UiPathOp itemOp(UiPathItem item) => item.op ?? (item.cut ? UiPathOp.cut : UiPathOp.add);

/// A point of an item: which contour, which point in it.
@immutable
class UiPointRef {
  const UiPointRef(this.contour, this.point);
  final int contour;
  final int point;

  @override
  bool operator ==(Object other) => other is UiPointRef && other.contour == contour && other.point == point;

  @override
  int get hashCode => Object.hash(contour, point);

  @override
  String toString() => 'UiPointRef($contour, $point)';
}

String _r(double n) {
  final v = (n * 100).round() / 100;
  return v == v.roundToDouble() ? v.round().toString() : v.toString();
}

/// The SVG `d` for a set of contours (for export; draw on a canvas with [uiContoursPath]).
String pathD(List<UiPathContour> contours) {
  final parts = <String>[];
  for (final c in contours) {
    final pts = c.points;
    if (pts.isEmpty) continue;
    parts.add('M${_r(pts[0].x)} ${_r(pts[0].y)}');
    final count = c.closed ? pts.length : pts.length - 1;
    for (var i = 0; i < count; i++) {
      parts.add(_segmentD(pts[i], pts[(i + 1) % pts.length]));
    }
    if (c.closed) parts.add('Z');
  }
  return parts.join(' ');
}

String _segmentD(UiPathPoint a, UiPathPoint b) {
  if (a.handleOut == null && b.handleIn == null) return 'L${_r(b.x)} ${_r(b.y)}';
  final c1 = a.handleOut ?? a.offset;
  final c2 = b.handleIn ?? b.offset;
  return 'C${_r(c1.dx)} ${_r(c1.dy)} ${_r(c2.dx)} ${_r(c2.dy)} ${_r(b.x)} ${_r(b.y)}';
}

/// The `d` for one segment on its own (from point [index] to the next).
String segmentPathD(UiPathContour contour, int index) {
  final a = contour.points[index];
  final b = contour.points[(index + 1) % contour.points.length];
  return 'M${_r(a.x)} ${_r(a.y)} ${_segmentD(a, b)}';
}

/// The contours as a Flutter [Path] (the canvas twin of [pathD]).
Path uiContoursPath(List<UiPathContour> contours) {
  final path = Path();
  for (final c in contours) {
    final pts = c.points;
    if (pts.isEmpty) continue;
    path.moveTo(pts[0].x, pts[0].y);
    final count = c.closed ? pts.length : pts.length - 1;
    for (var i = 0; i < count; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      if (a.handleOut == null && b.handleIn == null) {
        path.lineTo(b.x, b.y);
      } else {
        final c1 = a.handleOut ?? a.offset;
        final c2 = b.handleIn ?? b.offset;
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, b.x, b.y);
      }
    }
    if (c.closed) path.close();
  }
  return path;
}

/// One segment as a [Path].
Path uiSegmentPath(UiPathContour contour, int index) {
  final a = contour.points[index];
  final b = contour.points[(index + 1) % contour.points.length];
  final p = Path()..moveTo(a.x, a.y);
  if (a.handleOut == null && b.handleIn == null) {
    p.lineTo(b.x, b.y);
  } else {
    final c1 = a.handleOut ?? a.offset;
    final c2 = b.handleIn ?? b.offset;
    p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, b.x, b.y);
  }
  return p;
}

/// How many segments a contour has.
int segmentCount(UiPathContour contour) {
  final n = contour.points.length;
  return n < 2 ? 0 : (contour.closed ? n : n - 1);
}

double _cubic(double p0, double p1, double p2, double p3, double t) {
  final u = 1 - t;
  return u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3;
}

/// A point along segment [index] at [t] (0…1).
Offset pointOnSegment(UiPathContour contour, int index, double t) {
  final a = contour.points[index];
  final b = contour.points[(index + 1) % contour.points.length];
  final c1 = a.handleOut ?? a.offset;
  final c2 = b.handleIn ?? b.offset;
  return Offset(_cubic(a.x, c1.dx, c2.dx, b.x, t), _cubic(a.y, c1.dy, c2.dy, b.y, t));
}

/// The contour as a polyline: curves sampled, straight segments kept as their two ends.
List<Offset> flattenContour(UiPathContour contour, [int stepsPerCurve = 16]) {
  final out = <Offset>[];
  final pts = contour.points;
  if (pts.isEmpty) return out;
  out.add(pts[0].offset);
  for (var i = 0; i < segmentCount(contour); i++) {
    final a = pts[i];
    final b = pts[(i + 1) % pts.length];
    if (a.handleOut == null && b.handleIn == null) {
      out.add(b.offset);
      continue;
    }
    for (var s = 1; s <= stepsPerCurve; s++) {
      out.add(pointOnSegment(contour, i, s / stepsPerCurve));
    }
  }
  if (contour.closed && out.length > 1) {
    final first = out.first, last = out.last;
    if ((first.dx - last.dx).abs() < 1e-6 && (first.dy - last.dy).abs() < 1e-6) out.removeLast();
  }
  return out;
}

/// Bounds of the drawn outline (curves sampled, not their handles), or null when empty.
Rect? pathBounds(List<UiPathContour> contours) {
  var minX = double.infinity, minY = double.infinity, maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (final c in contours) {
    for (final p in flattenContour(c, 24)) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
  }
  return minX.isFinite ? Rect.fromLTRB(minX, minY, maxX, maxY) : null;
}

/// Applies a mapping to every point and handle.
List<UiPathContour> mapContours(List<UiPathContour> contours, Offset Function(Offset p) f) => [
      for (final c in contours)
        UiPathContour(closed: c.closed, points: [
          for (final p in c.points)
            UiPathPoint.at(f(p.offset), handleIn: p.handleIn == null ? null : f(p.handleIn!), handleOut: p.handleOut == null ? null : f(p.handleOut!)),
        ]),
    ];

List<UiPathContour> translateContours(List<UiPathContour> contours, double dx, double dy) => mapContours(contours, (p) => p.translate(dx, dy));

/// Scales about an origin.
List<UiPathContour> scaleContours(List<UiPathContour> contours, double ox, double oy, double sx, double sy) =>
    mapContours(contours, (p) => Offset(ox + (p.dx - ox) * sx, oy + (p.dy - oy) * sy));

/// Rotates about a centre, in degrees.
List<UiPathContour> rotateContours(List<UiPathContour> contours, double cx, double cy, double degrees) {
  final r = degrees * math.pi / 180;
  final cos = math.cos(r), sin = math.sin(r);
  return mapContours(contours, (p) => Offset(cx + (p.dx - cx) * cos - (p.dy - cy) * sin, cy + (p.dx - cx) * sin + (p.dy - cy) * cos));
}

/// The nearest spot on a path, from [nearestOnPath].
@immutable
class UiPathHit {
  const UiPathHit({required this.contour, required this.segment, required this.t, required this.distance, required this.point});
  final int contour;
  final int segment;
  final double t;
  final double distance;
  final Offset point;
}

/// The nearest spot on any segment to [at]: which segment, where along it, and how far away.
UiPathHit? nearestOnPath(List<UiPathContour> contours, Offset at, [int samples = 32]) {
  UiPathHit? best;
  for (var ci = 0; ci < contours.length; ci++) {
    final c = contours[ci];
    for (var s = 0; s < segmentCount(c); s++) {
      for (var k = 0; k <= samples; k++) {
        final t = k / samples;
        final p = pointOnSegment(c, s, t);
        final d = (p - at).distance;
        if (best == null || d < best.distance) best = UiPathHit(contour: ci, segment: s, t: t, distance: d, point: p);
      }
    }
  }
  return best;
}

Offset _lerp(Offset a, Offset b, double t) => Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);

List<UiPathContour> _replace(List<UiPathContour> contours, int index, List<UiPathContour> next) =>
    [...contours.sublist(0, index), ...next, ...contours.sublist(index + 1)];

List<UiPathPoint> _withPoint(List<UiPathPoint> pts, int index, UiPathPoint p) => [for (var i = 0; i < pts.length; i++) i == index ? p : pts[i]];

/// Adds a point on [segment] at [t], keeping the curve exactly as it was.
({List<UiPathContour> contours, UiPointRef point}) insertPoint(List<UiPathContour> contours, int contour, int segment, double t) {
  final c = contours[contour];
  final pts = [...c.points];
  final i = segment;
  final j = (segment + 1) % pts.length;
  final a = pts[i], b = pts[j];
  UiPathPoint added;
  if (a.handleOut == null && b.handleIn == null) {
    added = UiPathPoint.at(_lerp(a.offset, b.offset, t));
  } else {
    // de Casteljau: the two halves of the curve share the new point.
    final p0 = a.offset, p1 = a.handleOut ?? a.offset, p2 = b.handleIn ?? b.offset, p3 = b.offset;
    final q0 = _lerp(p0, p1, t), q1 = _lerp(p1, p2, t), q2 = _lerp(p2, p3, t);
    final r0 = _lerp(q0, q1, t), r1 = _lerp(q1, q2, t);
    final s = _lerp(r0, r1, t);
    pts[i] = a.copyWith(handleOut: q0);
    pts[j] = b.copyWith(handleIn: q2);
    added = UiPathPoint.at(s, handleIn: r0, handleOut: r1);
  }
  pts.insert(i + 1, added);
  return (contours: _replace(contours, contour, [UiPathContour(closed: c.closed, points: pts)]), point: UiPointRef(contour, i + 1));
}

/// Removes a point. A contour left with fewer than two points goes too.
List<UiPathContour> deletePoint(List<UiPathContour> contours, UiPointRef ref) {
  final c = contours[ref.contour];
  final pts = [for (var i = 0; i < c.points.length; i++) if (i != ref.point) c.points[i]];
  if (pts.length < 2) return [for (var i = 0; i < contours.length; i++) if (i != ref.contour) contours[i]];
  return _replace(contours, ref.contour, [UiPathContour(closed: c.closed && pts.length > 2, points: pts)]);
}

/// Breaks the outline at a point. A closed outline opens there (the point becomes both of its
/// ends); an open one splits into two lines that each keep a copy of the point.
List<UiPathContour> breakAt(List<UiPathContour> contours, UiPointRef ref) {
  final c = contours[ref.contour];
  final pts = c.points;
  final at = pts[ref.point];
  if (c.closed) {
    final rotated = [...pts.sublist(ref.point), ...pts.sublist(0, ref.point)];
    final end = at.copyWith(clearOut: true);
    final start = at.copyWith(clearIn: true);
    return _replace(contours, ref.contour, [UiPathContour(points: [start, ...rotated.sublist(1), end])]);
  }
  if (ref.point == 0 || ref.point == pts.length - 1) return [...contours];
  final first = [...pts.sublist(0, ref.point), at.copyWith(clearOut: true)];
  final second = [at.copyWith(clearIn: true), ...pts.sublist(ref.point + 1)];
  return _replace(contours, ref.contour, [UiPathContour(points: first), UiPathContour(points: second)]);
}

/// Closes an open outline, or reopens a closed one at its first point.
List<UiPathContour> toggleClosed(List<UiPathContour> contours, int contour) {
  final c = contours[contour];
  if (c.closed) return breakAt(contours, UiPointRef(contour, 0));
  return _replace(contours, contour, [UiPathContour(closed: c.points.length > 2, points: c.points)]);
}

UiPathPoint _swapHandles(UiPathPoint p) => UiPathPoint(p.x, p.y, handleIn: p.handleOut, handleOut: p.handleIn);

/// Joins the ends of two open outlines (or closes one onto itself) where the two given end points
/// are. Ends that sit on top of each other become one point.
List<UiPathContour> joinEnds(List<UiPathContour> contours, UiPointRef a, UiPointRef b) {
  final ca = contours[a.contour], cb = contours[b.contour];
  bool isEnd(UiPathContour c, int i) => !c.closed && (i == 0 || i == c.points.length - 1);
  if (!isEnd(ca, a.point) || !isEnd(cb, b.point)) return [...contours];
  if (a.contour == b.contour) return toggleClosed(contours, a.contour);
  // Orient so A ends at the joining point and B starts at it.
  final aPts = a.point == 0 ? ca.points.reversed.map(_swapHandles).toList() : ca.points;
  final bPts = b.point == 0 ? cb.points : cb.points.reversed.map(_swapHandles).toList();
  final last = aPts.last, first = bPts.first;
  final same = (last.offset - first.offset).distance < 0.5;
  final merged = same
      ? [...aPts.sublist(0, aPts.length - 1), UiPathPoint(last.x, last.y, handleIn: last.handleIn, handleOut: first.handleOut), ...bPts.sublist(1)]
      : [...aPts, ...bPts];
  final rest = [for (var i = 0; i < contours.length; i++) if (i != a.contour && i != b.contour) contours[i]];
  return [...rest, UiPathContour(points: merged)];
}

/// Makes a corner smooth (handles along the line between its neighbours, a third of the way to
/// each) or a smooth point a corner (handles removed).
List<UiPathContour> toggleSmooth(List<UiPathContour> contours, UiPointRef ref) {
  final c = contours[ref.contour];
  final pts = c.points;
  final p = pts[ref.point];
  UiPathPoint next;
  if (p.smooth) {
    next = UiPathPoint(p.x, p.y);
  } else {
    final n = pts.length;
    final prev = ref.point > 0 ? pts[ref.point - 1] : (c.closed ? pts[n - 1] : null);
    final after = ref.point < n - 1 ? pts[ref.point + 1] : (c.closed ? pts[0] : null);
    final dirFrom = prev ?? p, dirTo = after ?? p;
    var dx = dirTo.x - dirFrom.x, dy = dirTo.y - dirFrom.y;
    var len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) len = 1;
    dx /= len;
    dy /= len;
    final back = prev != null ? (p.offset - prev.offset).distance / 3 : 0.0;
    final fwd = after != null ? (after.offset - p.offset).distance / 3 : 0.0;
    next = UiPathPoint(p.x, p.y,
        handleIn: prev != null ? Offset(p.x - dx * back, p.y - dy * back) : null,
        handleOut: after != null ? Offset(p.x + dx * fwd, p.y + dy * fwd) : null);
  }
  return _replace(contours, ref.contour, [UiPathContour(closed: c.closed, points: _withPoint(pts, ref.point, next))]);
}

UiPathPoint _shift(UiPathPoint p, double dx, double dy) =>
    UiPathPoint(p.x + dx, p.y + dy, handleIn: p.handleIn?.translate(dx, dy), handleOut: p.handleOut?.translate(dx, dy));

/// Moves a point and its handles together.
List<UiPathContour> movePoint(List<UiPathContour> contours, UiPointRef ref, Offset to) {
  final c = contours[ref.contour];
  final p = c.points[ref.point];
  return _replace(contours, ref.contour, [UiPathContour(closed: c.closed, points: _withPoint(c.points, ref.point, _shift(p, to.dx - p.x, to.dy - p.y)))]);
}

/// Moves several points (and their handles) by the same amount.
List<UiPathContour> movePoints(List<UiPathContour> contours, List<UiPointRef> refs, double dx, double dy) {
  final moving = refs.toSet();
  return [
    for (var ci = 0; ci < contours.length; ci++)
      UiPathContour(closed: contours[ci].closed, points: [
        for (var pi = 0; pi < contours[ci].points.length; pi++)
          moving.contains(UiPointRef(ci, pi)) ? _shift(contours[ci].points[pi], dx, dy) : contours[ci].points[pi],
      ]),
  ];
}

/// Removes several points at once (see [deletePoint] for what happens to a contour left too short).
List<UiPathContour> deletePoints(List<UiPathContour> contours, List<UiPointRef> refs) {
  final doomed = refs.toSet();
  final out = <UiPathContour>[];
  for (var ci = 0; ci < contours.length; ci++) {
    final c = contours[ci];
    final pts = [for (var pi = 0; pi < c.points.length; pi++) if (!doomed.contains(UiPointRef(ci, pi))) c.points[pi]];
    if (pts.length == c.points.length) {
      out.add(c);
    } else if (pts.length >= 2) {
      out.add(UiPathContour(closed: c.closed && pts.length > 2, points: pts));
    }
  }
  return out;
}

/// Every point of every contour.
List<UiPointRef> allPoints(List<UiPathContour> contours) => [
      for (var c = 0; c < contours.length; c++)
        for (var p = 0; p < contours[c].points.length; p++) UiPointRef(c, p),
    ];

/// Pulls handles out of a point, both in line with the drag (the Convert Point tool): the handle on
/// the next segment follows the pointer, the other mirrors it.
List<UiPathContour> pullHandles(List<UiPathContour> contours, UiPointRef ref, Offset to) {
  final c = contours[ref.contour];
  final p = c.points[ref.point];
  final next = UiPathPoint(p.x, p.y, handleOut: to, handleIn: Offset(2 * p.x - to.dx, 2 * p.y - to.dy));
  return _replace(contours, ref.contour, [UiPathContour(closed: c.closed, points: _withPoint(c.points, ref.point, next))]);
}

/// The same outline traced the other way round.
UiPathContour reverseContour(UiPathContour c) => UiPathContour(closed: c.closed, points: c.points.reversed.map(_swapHandles).toList());

/// Twice the signed area of a contour's outline: positive runs clockwise on screen.
double contourArea(UiPathContour c) {
  final pts = flattenContour(c, 12);
  var s = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i], b = pts[(i + 1) % pts.length];
    s += a.dx * b.dy - b.dx * a.dy;
  }
  return s;
}

/// Whether a point is inside a closed contour (even-odd, curves sampled).
bool insideContour(UiPathContour c, Offset at) {
  final pts = flattenContour(c, 12);
  var inside = false;
  for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    final a = pts[i], b = pts[j];
    if ((a.dy > at.dy) != (b.dy > at.dy) && at.dx < (b.dx - a.dx) * (at.dy - a.dy) / (b.dy - a.dy) + a.dx) inside = !inside;
  }
  return inside;
}

/// Winds an item's closed outlines consistently (outer outlines clockwise, holes the other way) so
/// that under the non-zero rule pieces add up instead of cancelling where they overlap.
List<UiPathContour> orientContours(List<UiPathContour> contours) {
  final closed = contours.where((c) => c.closed && c.points.length > 2).toList();
  return [
    for (final c in contours)
      if (!c.closed || c.points.length < 3)
        c
      else
        () {
          final probe = c.points[0].offset;
          final depth = closed.where((o) => !identical(o, c) && insideContour(o, probe)).length;
          final clockwise = contourArea(c) > 0;
          return clockwise == (depth % 2 == 0) ? c : reverseContour(c);
        }(),
  ];
}

/// Which handle of a point.
enum UiHandleSide { handleIn, handleOut }

/// Moves one handle of a point. The opposite handle turns to stay in line (keeping its own length),
/// so a smooth point stays smooth; pass [free] to bend just the one side.
List<UiPathContour> moveHandle(List<UiPathContour> contours, UiPointRef ref, UiHandleSide side, Offset to, {bool free = false}) {
  final c = contours[ref.contour];
  final p = c.points[ref.point];
  final other = side == UiHandleSide.handleIn ? p.handleOut : p.handleIn;
  var mirrored = other;
  if (other != null && !free) {
    final len = (other - p.offset).distance;
    final d = p.offset - to;
    final dl = d.distance == 0 ? 1.0 : d.distance;
    mirrored = p.offset + d / dl * len;
  }
  final next = side == UiHandleSide.handleIn ? UiPathPoint(p.x, p.y, handleIn: to, handleOut: mirrored) : UiPathPoint(p.x, p.y, handleOut: to, handleIn: mirrored);
  return _replace(contours, ref.contour, [UiPathContour(closed: c.closed, points: _withPoint(c.points, ref.point, next))]);
}

// ----- Starting shapes ---------------------------------------------------------------------------

const double _kappa = 0.5522847498;

/// A rectangle, with rounded corners when [radius] > 0.
UiPathContour rectContour(double x, double y, double w, double h, [double radius = 0]) {
  final r = math.max(0.0, math.min(radius, math.min(w / 2, h / 2)));
  if (r <= 0) {
    return UiPathContour(closed: true, points: [UiPathPoint(x, y), UiPathPoint(x + w, y), UiPathPoint(x + w, y + h), UiPathPoint(x, y + h)]);
  }
  final k = r * _kappa;
  return UiPathContour(closed: true, points: [
    UiPathPoint(x + r, y, handleIn: Offset(x + r - k, y)),
    UiPathPoint(x + w - r, y, handleOut: Offset(x + w - r + k, y)),
    UiPathPoint(x + w, y + r, handleIn: Offset(x + w, y + r - k)),
    UiPathPoint(x + w, y + h - r, handleOut: Offset(x + w, y + h - r + k)),
    UiPathPoint(x + w - r, y + h, handleIn: Offset(x + w - r + k, y + h)),
    UiPathPoint(x + r, y + h, handleOut: Offset(x + r - k, y + h)),
    UiPathPoint(x, y + h - r, handleIn: Offset(x, y + h - r + k)),
    UiPathPoint(x, y + r, handleOut: Offset(x, y + r - k)),
  ]);
}

/// An ellipse from its centre and radii.
UiPathContour ellipseContour(double cx, double cy, double rx, double ry) {
  final kx = rx * _kappa, ky = ry * _kappa;
  return UiPathContour(closed: true, points: [
    UiPathPoint(cx, cy - ry, handleIn: Offset(cx - kx, cy - ry), handleOut: Offset(cx + kx, cy - ry)),
    UiPathPoint(cx + rx, cy, handleIn: Offset(cx + rx, cy - ky), handleOut: Offset(cx + rx, cy + ky)),
    UiPathPoint(cx, cy + ry, handleIn: Offset(cx + kx, cy + ry), handleOut: Offset(cx - kx, cy + ry)),
    UiPathPoint(cx - rx, cy, handleIn: Offset(cx - rx, cy + ky), handleOut: Offset(cx - rx, cy - ky)),
  ]);
}

/// A regular polygon (3 sides is a triangle), pointing up, fitting the box.
UiPathContour polygonContour(double x, double y, double w, double h, int sides) {
  final n = sides.clamp(3, 64);
  return UiPathContour(closed: true, points: [
    for (var i = 0; i < n; i++)
      () {
        final a = -math.pi / 2 + i * 2 * math.pi / n;
        return UiPathPoint(x + w / 2 + w / 2 * math.cos(a), y + h / 2 + h / 2 * math.sin(a));
      }(),
  ]);
}

/// A star with [spikes] points; [inner] is the inner radius as a fraction of the outer.
UiPathContour starContour(double x, double y, double w, double h, [int spikes = 5, double inner = 0.45]) {
  final n = spikes.clamp(3, 24);
  return UiPathContour(closed: true, points: [
    for (var i = 0; i < n * 2; i++)
      () {
        final a = -math.pi / 2 + i * math.pi / n;
        final r = i.isEven ? 1.0 : inner;
        return UiPathPoint(x + w / 2 + w / 2 * r * math.cos(a), y + h / 2 + h / 2 * r * math.sin(a));
      }(),
  ]);
}

/// A door or window: straight sides and bottom, a round top.
UiPathContour archContour(double x, double y, double w, double h) {
  final r = math.min(w / 2, h);
  final k = r * _kappa;
  final top = y + r;
  return UiPathContour(closed: true, points: [
    UiPathPoint(x, y + h),
    UiPathPoint(x, top, handleOut: Offset(x, top - k)),
    UiPathPoint(x + w / 2, y, handleIn: Offset(x + w / 2 - k, y), handleOut: Offset(x + w / 2 + k, y)),
    UiPathPoint(x + w, top, handleIn: Offset(x + w, top - k)),
    UiPathPoint(x + w, y + h),
  ]);
}
