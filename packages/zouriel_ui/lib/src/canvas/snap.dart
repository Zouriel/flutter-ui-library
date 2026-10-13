import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Which way a guide runs.
enum UiGuideOrientation { vertical, horizontal }

/// A guide line to draw: vertical at x = [at] spanning y from [from] to [to], or horizontal at
/// y = [at] spanning x.
@immutable
class UiGuide {
  const UiGuide(this.orientation, this.at, this.from, this.to);
  final UiGuideOrientation orientation;
  final double at;
  final double from;
  final double to;

  @override
  bool operator ==(Object other) => other is UiGuide && other.orientation == orientation && other.at == at && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(orientation, at, from, to);

  @override
  String toString() => 'UiGuide(${orientation.name}, $at, $from..$to)';
}

/// What [uiSnap] found: the offset to add to the moving rect, and the guides to show.
@immutable
class UiSnapResult {
  const UiSnapResult(this.dx, this.dy, this.guides);
  final double dx;
  final double dy;
  final List<UiGuide> guides;

  Offset get offset => Offset(dx, dy);
}

class _Candidate {
  const _Candidate(this.line, this.from, this.to);
  final double line;
  final double from;
  final double to;
  bool get infinite => from < -1e8;
}

/// Snaps a moving rectangle's edges and centre to those of other rectangles (and any extra lines,
/// such as the stage's own centre). Each axis snaps independently to its closest candidate within
/// [threshold] stage units. Pure: rects in stage units in, an offset and guides out.
UiSnapResult uiSnap(Rect moving, List<Rect> targets, double threshold, {List<double> vertical = const [], List<double> horizontal = const []}) {
  final xs = [moving.left, moving.center.dx, moving.right];
  final ys = [moving.top, moving.center.dy, moving.bottom];
  final v = [for (final line in vertical) _Candidate(line, -1e9, 1e9)];
  final h = [for (final line in horizontal) _Candidate(line, -1e9, 1e9)];
  for (final t in targets) {
    for (final line in [t.left, t.center.dx, t.right]) {
      v.add(_Candidate(line, t.top, t.bottom));
    }
    for (final line in [t.top, t.center.dy, t.bottom]) {
      h.add(_Candidate(line, t.left, t.right));
    }
  }

  (double, _Candidate)? best(List<double> values, List<_Candidate> candidates) {
    (double, _Candidate)? result;
    for (final value in values) {
      for (final c in candidates) {
        final delta = c.line - value;
        if (delta.abs() <= threshold && (result == null || delta.abs() < result.$1.abs())) result = (delta, c);
      }
    }
    return result;
  }

  final bx = best(xs, v);
  final by = best(ys, h);
  final dx = bx?.$1 ?? 0.0;
  final dy = by?.$1 ?? 0.0;
  final snapped = moving.shift(Offset(dx, dy));
  final guides = <UiGuide>[];
  // A guide spans the moving rect and the rect it snapped to, so you can see what lined up.
  if (bx != null) {
    final c = bx.$2;
    guides.add(UiGuide(UiGuideOrientation.vertical, c.line, c.infinite ? snapped.top : math.min(snapped.top, c.from), c.infinite ? snapped.bottom : math.max(snapped.bottom, c.to)));
  }
  if (by != null) {
    final c = by.$2;
    guides.add(UiGuide(UiGuideOrientation.horizontal, c.line, c.infinite ? snapped.left : math.min(snapped.left, c.from), c.infinite ? snapped.right : math.max(snapped.right, c.to)));
  }
  return UiSnapResult(dx, dy, guides);
}

/// The axis-aligned bounds of a box of [rect]'s size rotated by [degrees] about its centre.
Rect uiRotatedBounds(Rect rect, [double degrees = 0]) {
  final rad = degrees * math.pi / 180;
  if (rad == 0) return rect;
  final cos = math.cos(rad).abs(), sin = math.sin(rad).abs();
  final w = rect.width * cos + rect.height * sin;
  final h = rect.width * sin + rect.height * cos;
  return Rect.fromCenter(center: rect.center, width: w, height: h);
}

/// `ui-snap-guides`: draws the guide lines from [uiSnap] over a stage. Put it in the stage's
/// [Stack] (it fills it and ignores pointers); [scale] is screen pixels per stage unit.
class UiSnapGuides extends StatelessWidget {
  const UiSnapGuides({super.key, this.guides = const [], this.scale = 1, this.color});

  final List<UiGuide> guides;
  final double scale;

  /// Defaults to the accent colour, like the web.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: CustomPaint(painter: _GuidesPainter(guides, scale, color ?? context.ui.accent)),
        ),
      ),
    );
  }
}

class _GuidesPainter extends CustomPainter {
  _GuidesPainter(this.guides, this.scale, this.color);
  final List<UiGuide> guides;
  final double scale;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final g in guides) {
      if (g.orientation == UiGuideOrientation.vertical) {
        canvas.drawLine(Offset(g.at * scale, g.from * scale), Offset(g.at * scale, g.to * scale), paint);
      } else {
        canvas.drawLine(Offset(g.from * scale, g.at * scale), Offset(g.to * scale, g.at * scale), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GuidesPainter old) => !listEquals(old.guides, guides) || old.scale != scale || old.color != color;
}
