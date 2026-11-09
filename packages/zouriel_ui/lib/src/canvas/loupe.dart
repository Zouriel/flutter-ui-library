import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

// The magnifier the editors show beside a finger that paints (UiPathEditor in draw mode,
// UiImageEditor erasing or restoring): a finger covers the very spot it works on, so a circle a
// little way off shows what's under it, magnified, with the brush in the middle.

/// The loupe's diameter in logical pixels, on a surface big enough for it.
const double uiLoupeSize = 112;

/// How much bigger the loupe shows things than the editor does.
const double uiLoupeZoom = 2;

/// Where the loupe goes for a finger at [finger] on a [surface]: up and to the left of it, clear of
/// the fingertip (and of a right hand); to its right near the left edge, below it near the top, and
/// always inside the surface. Returns its centre and diameter.
({Offset center, double size}) uiLoupePlace(Offset finger, Size surface) {
  final measured = surface.width > 0 && surface.height > 0;
  final size = measured ? math.max(64.0, math.min(uiLoupeSize, surface.shortestSide * 0.42)).roundToDouble() : uiLoupeSize;
  final r = size / 2;
  // Far enough along the diagonal that the circle stays ~40 px clear of the touch point.
  final off = (r + 40) / math.sqrt2;
  var cx = finger.dx - off, cy = finger.dy - off;
  if (!measured) return (center: Offset(cx, cy), size: size);
  if (cx - r < 0) cx = finger.dx + off;
  if (cy - r < 0) cy = finger.dy + off;
  cx = cx.clamp(r, math.max(r, surface.width - r));
  cy = cy.clamp(r, math.max(r, surface.height - r));
  return (center: Offset(cx, cy), size: size);
}

/// Paints the loupe for a finger at [finger] on a [surface]: [scene] (which paints the editor in
/// surface coordinates) again, [uiLoupeZoom] times bigger around the finger and clipped to a circle
/// placed by [uiLoupePlace], then the brush's outline ([brushRadius], in surface pixels before
/// magnifying) and a dot at the centre.
void uiPaintLoupe(
  Canvas canvas,
  UiTokens t, {
  required Offset finger,
  required Size surface,
  required void Function(Canvas canvas) scene,
  required double brushRadius,
}) {
  final place = uiLoupePlace(finger, surface);
  final c = place.center, r = place.size / 2;
  final circle = Path()..addOval(Rect.fromCircle(center: c, radius: r));
  // A soft shadow, then the picture inside, then a light rim with a fine outer edge.
  canvas.drawPath(
      circle.shift(const Offset(0, 4)),
      Paint()
        ..color = t.mediaScrim.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
  canvas.save();
  canvas.clipPath(circle);
  canvas.drawPath(circle, Paint()..color = t.surfaceSubtle);
  canvas.translate(c.dx, c.dy);
  canvas.scale(uiLoupeZoom);
  canvas.translate(-finger.dx, -finger.dy);
  scene(canvas);
  canvas.restore();
  final ring = math.max(2.0, brushRadius * uiLoupeZoom);
  canvas.drawCircle(c, ring, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = t.mediaScrim.withValues(alpha: 0.5));
  canvas.drawCircle(c, ring, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.25
    ..color = t.mediaOnScrim);
  canvas.drawCircle(c, 2, Paint()..color = t.primary);
  canvas.drawCircle(c, 2, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = t.mediaOnScrim);
  canvas.drawCircle(c, r + 1, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = t.surface);
  canvas.drawCircle(c, r + 2.5, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = t.borderStrong);
}
