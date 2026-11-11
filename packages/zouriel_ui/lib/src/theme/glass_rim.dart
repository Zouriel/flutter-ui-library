import 'package:flutter/widgets.dart';

import 'theme.dart';

/// The rim of a glass surface, the web `--ui-glass-highlight`: a 1px inner highlight in
/// [UiTokens.glassHighlightEdge] all round, brightest along the top edge in
/// [UiTokens.glassHighlightTop] (CSS `inset 0 1px 0 0 top, inset 0 0 0 1px edge`).
///
/// Only the liquid themes light it; elsewhere both colours are transparent and this returns [child]
/// untouched, so glass looks as it always has. Put it around the glass box: [inset] is the box's
/// border width, so the rim sits inside the border as CSS inset shadows do (use 0 inside a
/// container whose child already sits within its border).
class UiGlassRim extends StatelessWidget {
  const UiGlassRim({super.key, required this.borderRadius, required this.child, this.enabled = true, this.inset = 1});

  /// The glass box's corners.
  final BorderRadiusGeometry borderRadius;

  /// Draw the rim only when the surface is glass.
  final bool enabled;

  /// How far inside the box's edge the rim starts (its border width).
  final double inset;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    if (!enabled || (t.glassHighlightTop.a == 0 && t.glassHighlightEdge.a == 0)) return child;
    return CustomPaint(
      foregroundPainter: UiGlassRimPainter(
        top: t.glassHighlightTop,
        edge: t.glassHighlightEdge,
        borderRadius: borderRadius.resolve(Directionality.maybeOf(context) ?? TextDirection.ltr),
        inset: inset,
      ),
      child: child,
    );
  }
}

/// Paints [UiGlassRim]: the edge band (the box minus itself 1px smaller), then the top band (the box
/// minus itself moved 1px down), as CSS paints the second inset shadow first.
class UiGlassRimPainter extends CustomPainter {
  const UiGlassRimPainter({required this.top, required this.edge, required this.borderRadius, this.inset = 1});

  final Color top;
  final Color edge;
  final BorderRadius borderRadius;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final box = borderRadius.toRRect(Offset.zero & size).deflate(inset);
    if (box.width <= 2 || box.height <= 2) return;
    final outer = Path()..addRRect(box);
    if (edge.a > 0) {
      canvas.drawPath(Path.combine(PathOperation.difference, outer, Path()..addRRect(box.deflate(1))), Paint()..color = edge);
    }
    if (top.a > 0) {
      canvas.drawPath(Path.combine(PathOperation.difference, outer, Path()..addRRect(box.shift(const Offset(0, 1)))), Paint()..color = top);
    }
  }

  @override
  bool shouldRepaint(UiGlassRimPainter old) => old.top != top || old.edge != edge || old.borderRadius != borderRadius || old.inset != inset;
}
