import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Which way a [UiStatCard] delta went.
enum UiTrend { up, down }

/// `ui-stat-card`: a KPI tile: [label], a large [value], an optional [delta] with a drawn up/down
/// marker (green up, red down; the direction is also spoken, so colour isn't the only signal), and
/// an optional [icon] in the corner. Read by screen readers as one sentence.
class UiStatCard extends StatelessWidget {
  const UiStatCard({super.key, required this.label, required this.value, this.delta, this.trend = UiTrend.up, this.icon, this.glass, this.radius});

  final String label;
  final String value;
  final String? delta;
  final UiTrend trend;
  final Widget? icon;
  final bool? glass;
  final bool? radius;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final ty = theme.typography;
    final isGlass = glass ?? theme.config.glass;
    final r = (radius ?? theme.config.radius) ? t.radiusLg : 0.0;
    final deltaColor = trend == UiTrend.up ? t.success : t.danger;
    final small = ty.body.copyWith(fontSize: t.fontSizeSm, height: 1.35);

    Widget card = Container(
      padding: EdgeInsets.symmetric(vertical: t.space3, horizontal: t.space4),
      decoration: BoxDecoration(
        color: isGlass ? t.glassBg : t.surface,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: isGlass ? t.glassBorder : t.border),
        boxShadow: t.shadow1,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: t.space1,
        children: [
          Row(spacing: t.space2, children: [
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: small.copyWith(color: t.textMuted))),
            if (icon != null) IconTheme.merge(data: IconThemeData(size: 18, color: t.icon ?? t.textMuted), child: icon!),
          ]),
          Text(
            value,
            style: ty.h2.copyWith(
              fontSize: 25.6 * context.ui.fontScale,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: t.trackingTight * 25.6,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (delta != null)
            Row(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
              CustomPaint(size: const Size.square(10), painter: _TrianglePainter(trend, deltaColor)),
              Text(delta!, style: small.copyWith(color: deltaColor, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
        ],
      ),
    );
    if (isGlass) {
      card = ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: t.glassBlur / 2, sigmaY: t.glassBlur / 2), child: card),
      );
    }
    final spoken = delta == null ? '$label, $value' : '$label, $value, ${trend == UiTrend.up ? 'up' : 'down'} $delta';
    return Semantics(container: true, label: spoken, child: ExcludeSemantics(child: card));
  }
}

/// The web delta marker: a small solid triangle, pointing up or down (12-unit paths).
class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.trend, this.color);
  final UiTrend trend;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 12);
    final path = trend == UiTrend.down
        ? (Path()..moveTo(2, 4)..lineTo(10, 4)..lineTo(6, 9)..close())
        : (Path()..moveTo(2, 8)..lineTo(10, 8)..lineTo(6, 3)..close());
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.trend != trend || old.color != color;
}
