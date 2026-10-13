import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/canvas/ink.dart';
import 'package:zouriel_ui/src/canvas/path.dart';
import 'package:zouriel_ui/src/canvas/snap.dart';

void main() {
  group('path', () {
    test('writes straight and curved segments, and closes', () {
      final tri = polygonContour(0, 0, 100, 100, 3);
      expect(pathD([tri]), matches(RegExp(r'^M50 0 L.* Z$')));
      expect(pathD([ellipseContour(50, 50, 50, 50)]), contains('C'));
    });

    test('the Flutter path covers the same outline as the SVG', () {
      final b = uiContoursPath([rectContour(10, 20, 30, 40)]).getBounds();
      expect(b, const Rect.fromLTWH(10, 20, 30, 40));
      final e = uiContoursPath([ellipseContour(50, 50, 20, 10)]).getBounds();
      expect(e.width, closeTo(40, 0.01));
      expect(e.height, closeTo(20, 0.01));
    });

    test('inserting a point keeps the outline where it was', () {
      final circle = ellipseContour(50, 50, 50, 50);
      final before = pathBounds([circle])!;
      final r = insertPoint([circle], 0, 0, 0.5);
      expect(r.contours[0].points, hasLength(5));
      expect(r.point, const UiPointRef(0, 1));
      final after = pathBounds(r.contours)!;
      expect(after.width, closeTo(before.width, 0.1));
      expect(after.height, closeTo(before.height, 0.1));
    });

    test('inserting on a straight edge puts the point on the line', () {
      final r = insertPoint([rectContour(0, 0, 10, 10)], 0, 0, 0.25);
      expect(r.contours[0].points[1].offset, const Offset(2.5, 0));
      expect(r.contours[0].points[1].smooth, isFalse);
    });

    test('breaks a closed outline open at a point, and closes it again', () {
      final box = [rectContour(0, 0, 10, 10)];
      final open = breakAt(box, const UiPointRef(0, 2));
      expect(open[0].closed, isFalse);
      expect(open[0].points, hasLength(5));
      expect(open[0].points[0].offset, const Offset(10, 10));
      expect(toggleClosed(open, 0)[0].closed, isTrue);
    });

    test('splits an open line in two at a middle point, and joins two lines end to end', () {
      const line = UiPathContour(points: [UiPathPoint(0, 0), UiPathPoint(5, 0), UiPathPoint(10, 0)]);
      final parts = breakAt([line], const UiPointRef(0, 1));
      expect(parts, hasLength(2));
      final joined = joinEnds(parts, const UiPointRef(0, 1), const UiPointRef(1, 0));
      expect(joined, hasLength(1));
      expect(joined[0].points.map((p) => p.x), [0, 5, 10]);
    });

    test('joining the two ends of one line closes it; joining a middle point does nothing', () {
      const line = UiPathContour(points: [UiPathPoint(0, 0), UiPathPoint(5, 5), UiPathPoint(10, 0)]);
      expect(joinEnds([line], const UiPointRef(0, 0), const UiPointRef(0, 2))[0].closed, isTrue);
      expect(joinEnds([line], const UiPointRef(0, 1), const UiPointRef(0, 2)), [line]);
    });

    test('makes a corner smooth and back, and deleting points drops a contour that is too small', () {
      final tri = [polygonContour(0, 0, 100, 100, 3)];
      final smooth = toggleSmooth(tri, const UiPointRef(0, 0));
      expect(smooth[0].points[0].handleIn, isNotNull);
      expect(toggleSmooth(smooth, const UiPointRef(0, 0))[0].points[0].handleIn, isNull);
      const line = [UiPathContour(points: [UiPathPoint(0, 0), UiPathPoint(1, 1)])];
      expect(deletePoint(line, const UiPointRef(0, 0)), isEmpty);
    });

    test('moves and deletes several points at once', () {
      final box = [rectContour(0, 0, 10, 10)];
      final moved = movePoints(box, const [UiPointRef(0, 0), UiPointRef(0, 1)], 0, -5);
      expect(moved[0].points.map((p) => p.y), [-5, -5, 10, 10]);
      final two = deletePoints(box, const [UiPointRef(0, 0), UiPointRef(0, 2)]);
      expect(two[0].points, hasLength(2));
      expect(two[0].closed, isFalse);
      expect(deletePoints(box, [for (var p = 0; p < 3; p++) UiPointRef(0, p)]), isEmpty);
    });

    test('moving a point carries its handles', () {
      final c = [ellipseContour(0, 0, 10, 10)];
      final moved = movePoint(c, const UiPointRef(0, 0), const Offset(5, -5));
      final p = moved[0].points[0];
      expect(p.offset, const Offset(5, -5));
      expect(p.handleIn! - p.offset, c[0].points[0].handleIn! - c[0].points[0].offset);
    });

    test('pulls curve handles out of a corner, in line with the drag', () {
      final c = pullHandles([rectContour(0, 0, 10, 10)], const UiPointRef(0, 1), const Offset(14, -2))[0];
      expect(c.points[1].handleOut, const Offset(14, -2));
      expect(c.points[1].handleIn, const Offset(6, 2));
    });

    test('moving one handle turns the other to stay in line, unless free', () {
      final c = [ellipseContour(0, 0, 10, 10)];
      final top = c[0].points[0]; // (0,-10), handles along x
      final turned = moveHandle(c, const UiPointRef(0, 0), UiHandleSide.handleOut, const Offset(0, -20))[0].points[0];
      final otherLen = (top.handleIn! - top.offset).distance;
      expect((turned.handleIn! - turned.offset).distance, closeTo(otherLen, 1e-9));
      expect(turned.handleIn!.dx, closeTo(0, 1e-9));
      expect(turned.handleIn!.dy, closeTo(-10 + otherLen, 1e-9));
      final free = moveHandle(c, const UiPointRef(0, 0), UiHandleSide.handleOut, const Offset(0, -20), free: true)[0].points[0];
      expect(free.handleIn, top.handleIn);
    });

    test('winds outlines so pieces add up and holes stay holes', () {
      final outer = rectContour(0, 0, 100, 100);
      final backwards = reverseContour(rectContour(200, 0, 50, 50));
      final hole = rectContour(25, 25, 50, 50);
      final o = orientContours([outer, backwards, hole]);
      expect(contourArea(o[0]).sign, 1);
      expect(contourArea(o[1]).sign, 1);
      expect(contourArea(o[2]).sign, -1);
    });

    test('measures and queries', () {
      final box = rectContour(0, 0, 10, 10);
      expect(insideContour(box, const Offset(5, 5)), isTrue);
      expect(insideContour(box, const Offset(15, 5)), isFalse);
      expect(segmentCount(box), 4);
      expect(segmentCount(const UiPathContour(points: [UiPathPoint(0, 0), UiPathPoint(1, 0)])), 1);
      expect(allPoints([box, box]), hasLength(8));
      final hit = nearestOnPath([box], const Offset(5, -2))!;
      expect(hit.segment, 0);
      expect(hit.distance, closeTo(2, 1e-9));
      expect(pathBounds(const []), isNull);
    });

    test('transforms return moved copies and leave the input alone', () {
      final box = [rectContour(0, 0, 10, 10)];
      expect(pathBounds(translateContours(box, 5, 5)), const Rect.fromLTWH(5, 5, 10, 10));
      expect(pathBounds(scaleContours(box, 0, 0, 2, 3)), const Rect.fromLTWH(0, 0, 20, 30));
      final turned = pathBounds(rotateContours(box, 5, 5, 90))!;
      expect(turned.left, closeTo(0, 1e-9));
      expect(turned.width, closeTo(10, 1e-9));
      expect(pathBounds(box), const Rect.fromLTWH(0, 0, 10, 10));
    });

    test('starting shapes fit their boxes', () {
      expect(pathBounds([rectContour(0, 0, 100, 80, 14)])!.size, const Size(100, 80));
      final star = pathBounds([starContour(0, 0, 100, 100)])!;
      expect(star.top, closeTo(0, 1e-9));
      expect(starContour(0, 0, 10, 10, 6).points, hasLength(12));
      expect(polygonContour(0, 0, 10, 10, 1).points, hasLength(3));
      final arch = pathBounds([archContour(0, 0, 60, 100)])!;
      expect(arch.width, closeTo(60, 0.01));
      expect(arch.height, closeTo(100, 0.01));
      expect(itemOp(const UiPathItem(id: 'a', contours: [], cut: true)), UiPathOp.cut);
      expect(itemOp(const UiPathItem(id: 'a', contours: [])), UiPathOp.add);
    });

    test('points round-trip through the web JSON shape', () {
      final c = ellipseContour(1, 2, 3, 4);
      expect(UiPathContour.fromJson(c.toJson()), c);
      expect(c.points[0].toJson().keys, containsAll(['x', 'y', 'in', 'out']));
    });
  });

  group('ink', () {
    List<UiInkSample> line(Offset from, Offset to, {int n = 20, double pressure = 0.5}) =>
        [for (var i = 0; i <= n; i++) UiInkSample(from.dx + (to.dx - from.dx) * i / n, from.dy + (to.dy - from.dy) * i / n, pressure)];
    Rect bounds(List<List<Offset>> pieces) {
      final pts = pieces.expand((p) => p);
      return Rect.fromLTRB(pts.map((p) => p.dx).reduce(math.min), pts.map((p) => p.dy).reduce(math.min), pts.map((p) => p.dx).reduce(math.max), pts.map((p) => p.dy).reduce(math.max));
    }

    double signedArea(List<Offset> poly) {
      var s = 0.0;
      for (var i = 0; i < poly.length; i++) {
        final p = poly[i], q = poly[(i + 1) % poly.length];
        s += p.dx * q.dy - q.dx * p.dy;
      }
      return s;
    }

    test('a pen stroke paints its length plus a round cap at each end, its width wide', () {
      final b = bounds(inkArea(line(const Offset(10, 50), const Offset(90, 50)), const UiBrush(kind: UiBrushKind.pen, size: 6)));
      expect(b.width, closeTo(86, 0.5));
      expect(b.height, closeTo(6, 0.5));
    });

    test('every painted piece winds the same way, so the non-zero rule shows their union', () {
      final scribble = [for (var i = 0; i < 60; i++) UiInkSample(50 + 30 * math.cos(i / 5), 50 + 20 * math.sin(i / 3))];
      final signs = inkArea(scribble, const UiBrush(kind: UiBrushKind.brush, size: 5)).map((p) => signedArea(p).sign).toSet();
      expect(signs, {1});
    });

    test('pressure changes a pencil, not a marker', () {
      final light = line(Offset.zero, const Offset(100, 0), pressure: 0.1);
      final hard = line(Offset.zero, const Offset(100, 0), pressure: 0.9);
      expect(inkRadii(hard, const UiBrush(kind: UiBrushKind.pencil))[10], greaterThan(inkRadii(light, const UiBrush(kind: UiBrushKind.pencil))[10] * 3));
      expect(inkRadii(hard, const UiBrush(kind: UiBrushKind.marker))[10], closeTo(inkRadii(light, const UiBrush(kind: UiBrushKind.marker))[10], 1e-6));
      expect(brushUsesPressure(UiBrushKind.pencil), isTrue);
      expect(brushUsesPressure(UiBrushKind.marker), isFalse);
    });

    test('a brush comes to a point at both ends once finished, only at the start while drawing', () {
      final s = line(Offset.zero, const Offset(200, 0), n: 40);
      final done = inkRadii(s, const UiBrush(kind: UiBrushKind.brush, size: 8));
      expect(done[0], lessThan(done[20] * 0.3));
      expect(done[40], lessThan(done[20] * 0.3));
      final drawing = inkRadii(s, const UiBrush(kind: UiBrushKind.brush, size: 8), finished: false);
      expect(drawing[40], closeTo(drawing[20], 1e-6));
      expect(inkRadiusAt(s[40], 200, const UiBrush(kind: UiBrushKind.brush, size: 8)), closeTo(drawing[40], 1e-6));
    });

    test('a broad-edge nib is thick across its angle and a hairline along it', () {
      double thickness(double dx, double dy) {
        final pieces = inkArea(line(Offset.zero, Offset(dx, dy)), const UiBrush(kind: UiBrushKind.calligraphy, size: 10));
        final len = math.sqrt(dx * dx + dy * dy);
        final across = pieces.expand((p) => p).map((p) => (p.dx * -dy + p.dy * dx) / len);
        return across.reduce(math.max) - across.reduce(math.min);
      }

      expect(thickness(60, 60), lessThan(2));
      expect(thickness(60, -60), greaterThan(9));
    });

    test('a single touch is a dot', () {
      final pieces = inkArea(const [UiInkSample(5, 5)], const UiBrush(kind: UiBrushKind.pen, size: 4));
      expect(pieces, hasLength(1));
      expect(bounds(pieces).width, closeTo(4, 0.5));
    });

    test('samples too close together merge, keeping the end', () {
      final s = thinSamples(const [UiInkSample(0, 0, 0.3), UiInkSample(0.1, 0, 0.8), UiInkSample(5, 0), UiInkSample(5.2, 0)], 1);
      expect(s.map((p) => p.x), [0, 5, 5.2]);
      expect(s[0].pressure, 0.8);
    });

    test('a convex hull drops the points inside', () {
      expect(convexHull(const [Offset(0, 0), Offset(10, 0), Offset(5, 3), Offset(10, 10), Offset(0, 10)]), hasLength(4));
    });

    test('slow is firm and fast is light for a finger with the brush', () {
      expect(simulatedPressure(UiBrushKind.brush, 0.5, 0, 5), greaterThan(simulatedPressure(UiBrushKind.brush, 0.5, 50, 5)));
      expect(simulatedPressure(UiBrushKind.pen, 0.5, 50, 5), 0.5);
      expect(inkD(const [[Offset(0, 0), Offset(1, 0), Offset(1, 1)]]), 'M0 0L1 0L1 1Z');
    });

    group('snap to shape', () {
      double wobble(int i) => math.sin(i * 1.7) * 0.6;

      test('a nearly straight stroke is a line', () {
        expect(recognizeShape([for (var i = 0; i < 30; i++) Offset(i * 3.0, i * 1.5 + wobble(i))]), isA<UiInkLine>());
      });

      test('a round loop is a circle, a flat one an ellipse', () {
        List<Offset> loop(double rx, double ry) => [
              for (var i = 0; i < 50; i++) Offset(50 + rx * math.cos(i / 49 * math.pi * 2) + wobble(i), 50 + ry * math.sin(i / 49 * math.pi * 2) + wobble(i + 3)),
            ];
        final circle = recognizeShape(loop(20, 19));
        expect(circle, isA<UiInkEllipse>());
        expect((circle! as UiInkEllipse).rx, (circle as UiInkEllipse).ry);
        final ellipse = recognizeShape(loop(30, 12));
        expect(ellipse, isA<UiInkEllipse>());
        expect((ellipse! as UiInkEllipse).rx, greaterThan((ellipse as UiInkEllipse).ry * 2));
      });

      List<Offset> polyline(List<Offset> corners) => [
            for (var k = 0; k < corners.length; k++)
              for (var i = 0; i < 12; i++)
                Offset(corners[k].dx + (corners[(k + 1) % corners.length].dx - corners[k].dx) * i / 12 + wobble(i + k),
                    corners[k].dy + (corners[(k + 1) % corners.length].dy - corners[k].dy) * i / 12 + wobble(i + k + 5)),
          ];

      test('four corners make an upright rectangle', () {
        final shape = recognizeShape(polyline(const [Offset(0, 0), Offset(60, 1), Offset(61, 40), Offset(1, 39)]));
        expect(shape, isA<UiInkPolygon>());
        final pts = (shape! as UiInkPolygon).points;
        expect(pts, hasLength(4));
        expect(pts.map((p) => p.dx.round()).toSet(), hasLength(2));
      });

      test('three corners make a triangle', () {
        final shape = recognizeShape(polyline(const [Offset(0, 50), Offset(30, 0), Offset(60, 50)]));
        expect(shape, isA<UiInkPolygon>());
        expect((shape! as UiInkPolygon).points, hasLength(3));
      });

      test('a squiggle is left as it is', () {
        expect(recognizeShape([for (var i = 0; i < 60; i++) Offset(i.toDouble(), 10 * math.sin(i / 5))]), isNull);
      });

      test('a snapped shape is redrawn along its outline, closed', () {
        final s = shapeSamples(const UiInkPolygon([Offset(0, 0), Offset(10, 0), Offset(10, 10)]), 0.5, 1);
        expect(s.first.offset, Offset.zero);
        expect(s.last.offset, Offset.zero);
        final e = shapeSamples(const UiInkEllipse(0, 0, 10, 10), 0.4, 1);
        expect(e.first.offset.dy, closeTo(-10, 1e-9));
        expect(e.every((p) => p.pressure == 0.4), isTrue);
      });
    });
  });

  group('snap', () {
    const target = Rect.fromLTWH(100, 100, 50, 50);

    test('snaps the nearest edge within the threshold and reports a guide', () {
      final r = uiSnap(const Rect.fromLTWH(153, 300, 20, 20), [target], 5);
      expect(r.dx, -3);
      expect(r.dy, 0);
      expect(r.guides, [const UiGuide(UiGuideOrientation.vertical, 150, 100, 320)]);
    });

    test('snaps centres to centres', () {
      final r = uiSnap(const Rect.fromLTWH(116, 116, 20, 20), [target], 2);
      expect(r.dx, -1);
      expect(r.dy, -1);
    });

    test('leaves things alone outside the threshold', () {
      final r = uiSnap(const Rect.fromLTWH(400, 400, 20, 20), [target], 5);
      expect(r.offset, Offset.zero);
      expect(r.guides, isEmpty);
    });

    test('snaps to extra lines such as the stage centre', () {
      expect(uiSnap(const Rect.fromLTWH(182, 0, 20, 20), const [], 4, vertical: [195]).dx, 3);
    });

    test('rotated bounds: the box itself unrotated, width and height swapped at 90 degrees', () {
      expect(uiRotatedBounds(const Rect.fromLTWH(1, 2, 3, 4)), const Rect.fromLTWH(1, 2, 3, 4));
      final b = uiRotatedBounds(const Rect.fromLTWH(0, 0, 100, 20), 90);
      expect(b.width, closeTo(20, 1e-9));
      expect(b.height, closeTo(100, 1e-9));
      expect(b.center.dx, closeTo(50, 1e-9));
      expect(b.center.dy, closeTo(10, 1e-9));
    });
  });
}
