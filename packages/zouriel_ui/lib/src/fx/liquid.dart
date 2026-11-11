import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'motion.dart';

/// `ui-liquid-backdrop`: the liquid themes' backdrop, a slow, flowing satin surface behind glass
/// panels. The main brand colour is the ground; blurred pools of the second and accent colours drift
/// over it, and a soft sheen of the theme's glass highlight slides across.
///
/// Decorative only: ignores touches and screen readers. It fills the space it is given (in a
/// [Stack], `Positioned.fill` behind the content). It paints from [UiTokens.liquidMain],
/// [UiTokens.liquidSecond], [UiTokens.liquidAccent] and their strengths (set by the liquid themes and
/// Navy); in other themes it pools the secondary and primary colours over the background, as on the
/// web. Only position, scale and opacity move, and only at full motion; under reduced motion or with
/// the library's animations off it stands still, a still gradient.
class UiLiquidBackdrop extends StatefulWidget {
  const UiLiquidBackdrop({super.key, this.opacity = 1});

  /// Opacity of the whole backdrop, 0-1.
  final double opacity;

  @override
  State<UiLiquidBackdrop> createState() => _UiLiquidBackdropState();
}

class _UiLiquidBackdropState extends State<UiLiquidBackdrop> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((d) => _time.value = d.inMicroseconds / 1e6);
  final ValueNotifier<double> _time = ValueNotifier(0);
  bool _moving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _moving = uiFxMotion(context) == UiFxMotion.full;
    if (_moving && !_ticker.isActive) _ticker.start();
    if (!_moving && _ticker.isActive) {
      _ticker.stop();
      _time.value = 0;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final main = t.liquidMain ?? t.bg;
    // color-mix(in srgb, colour strength, main), as the web pools are mixed.
    final second = Color.lerp(main, t.liquidSecond ?? t.secondary, t.liquidSecondStrength ?? 0.18)!;
    final accent = Color.lerp(main, t.liquidAccent ?? t.primary, t.liquidAccentStrength ?? 0.14)!;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Opacity(
          opacity: widget.opacity,
          child: ClipRect(
            child: SizedBox.expand(
              child: CustomPaint(
                key: const ValueKey('ui-liquid-backdrop'),
                painter: UiLiquidPainter(time: _time, moving: _moving, main: main, second: second, accent: accent, sheen: t.glassHighlightTop),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One pool: a soft disc placed like the web element (offsets and size in vmax), and its drift.
class _Pool {
  const _Pool({required this.size, this.left, this.right, this.top, this.bottom, required this.seconds, required this.to, this.scaleFrom = 1, this.scaleTo = 1, this.opacity = 1, this.opacityFrom, this.opacityTo, required this.accent});
  final double size;
  final double? left, right, top, bottom;
  final double seconds;
  final Offset to; // translate at the end of the drift, in vmax
  final double scaleFrom, scaleTo;
  final double opacity; // at rest (no animation)
  final double? opacityFrom, opacityTo;
  final bool accent;
}

// The web keyframes ui-liquid-flow-a/b/c (rotation is left out: a disc looks the same turned).
const List<_Pool> _pools = [
  _Pool(size: 90, top: -45, left: -30, seconds: 26, to: Offset(18, 12), scaleTo: 1.15, accent: false),
  _Pool(size: 90, bottom: -50, right: -35, seconds: 32, to: Offset(-20, -10), scaleFrom: 1.1, scaleTo: 0.95, accent: true),
  _Pool(size: 70, bottom: -60, left: -10, seconds: 38, to: Offset(24, -14), scaleTo: 1.2, opacity: 0.7, opacityFrom: 0.5, opacityTo: 0.8, accent: false),
];

/// Paints [UiLiquidBackdrop]. Public so tests can read what it paints with.
class UiLiquidPainter extends CustomPainter {
  UiLiquidPainter({required this.time, required this.moving, required this.main, required this.second, required this.accent, required this.sheen}) : super(repaint: time);

  final ValueListenable<double> time;

  /// Whether the drift runs; standing still paints the rest positions (the still gradient).
  final bool moving;
  final Color main, second, accent, sheen;

  /// A 0-1-0 ease-in-out over [seconds] each way: CSS `ease-in-out infinite alternate`.
  static double _phase(double t, double seconds) => 0.5 - 0.5 * math.cos(math.pi * t / seconds);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = main);
    final vmax = math.max(size.width, size.height) / 100;
    final now = time.value;
    for (final p in _pools) {
      final e = moving ? _phase(now, p.seconds) : 0.0;
      final d = p.size * vmax;
      final x = p.left != null ? p.left! * vmax : size.width - p.right! * vmax - d;
      final y = p.top != null ? p.top! * vmax : size.height - p.bottom! * vmax - d;
      final scale = moving ? p.scaleFrom + (p.scaleTo - p.scaleFrom) * e : 1.0;
      final opacity = moving && p.opacityFrom != null ? p.opacityFrom! + (p.opacityTo! - p.opacityFrom!) * e : p.opacity;
      final centre = Offset(x + d / 2 + p.to.dx * vmax * e, y + d / 2 + p.to.dy * vmax * e);
      final radius = d / 2 * scale;
      final colour = p.accent ? accent : second;
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [colour.withValues(alpha: colour.a * opacity), colour.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: centre, radius: radius))
          // The web blur(48px), as a Gaussian sigma.
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
      );
    }
    if (sheen.a > 0) {
      // The satin: a broad diagonal band of the glass highlight (web ui-liquid-sheen).
      final e = moving ? _phase(now, 30) : 0.0;
      final opacity = moving ? 0.12 + 0.16 * e : 0.22;
      canvas.save();
      final c = size.center(Offset.zero);
      canvas.translate(c.dx + (moving ? (-0.12 + 0.24 * e) * size.width * 2 : 0), c.dy + (moving ? (-0.06 + 0.12 * e) * size.height * 2 : 0));
      canvas.rotate((moving ? 8 * e : 0) * math.pi / 180);
      final box = Rect.fromCenter(center: Offset.zero, width: size.width * 2, height: size.height * 2);
      final band = sheen.withValues(alpha: sheen.a * opacity);
      final transparent = sheen.withValues(alpha: 0);
      // CSS 115deg: the gradient runs towards the lower right; its stripes lean the other way.
      final dir = Offset(math.sin(115 * math.pi / 180), -math.cos(115 * math.pi / 180));
      final half = (box.width * dir.dx.abs() + box.height * dir.dy.abs()) / 2;
      canvas.drawRect(
        box,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(-dir.dx * half / (box.width / 2), -dir.dy * half / (box.height / 2)),
            end: Alignment(dir.dx * half / (box.width / 2), dir.dy * half / (box.height / 2)),
            colors: [transparent, band, transparent],
            stops: const [0.38, 0.5, 0.62],
          ).createShader(box),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(UiLiquidPainter old) =>
      old.moving != moving || old.main != main || old.second != second || old.accent != accent || old.sheen != sheen;
}
