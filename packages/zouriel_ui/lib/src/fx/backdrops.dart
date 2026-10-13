import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/types.dart';
import '../theme/theme.dart';
import 'motion.dart';

/// `ui-glyph-field`: a grid of flickering glyphs lit by a drifting field of light, brightest toward
/// the middle, tinted along a dim → mid → bright ramp. A backdrop: put it in a [Stack] (it fills
/// the space it is given) under the content; it ignores touches and screen readers.
///
/// The ramp defaults to the Dark Orange brand colours (ember → blood → rose) and, in themes
/// without them, a ramp built from the theme's primary and accent. Under reduced motion it draws
/// one still frame.
class UiGlyphField extends StatefulWidget {
  const UiGlyphField({super.key, this.opacity = 0.55, this.chars = '01', this.cell = 16, this.speed = 1, this.colors});

  final double opacity;
  final String chars;

  /// Grid cell size in logical px.
  final double cell;
  final double speed;

  /// Dim, mid and bright.
  final (Color, Color, Color)? colors;

  @override
  State<UiGlyphField> createState() => _UiGlyphFieldState();
}

class _UiGlyphFieldState extends State<UiGlyphField> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((d) => _time.value = d.inMicroseconds / 1e6);
  final ValueNotifier<double> _time = ValueNotifier(0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final move = uiFxMotion(context) == UiFxMotion.full;
    if (move && !_ticker.isActive) _ticker.start();
    if (!move && _ticker.isActive) {
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
    final ramp = widget.colors ??
        (
          t.ember ?? uiMix(t.primary, 0.35, t.bg),
          t.blood ?? t.primary,
          t.rose ?? t.accent,
        );
    final family = t.fontMono ?? uiDefaultMonoFamily;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Opacity(
          opacity: widget.opacity,
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: _GlyphPainter(_time, widget.chars.isEmpty ? '01' : widget.chars, widget.cell, widget.speed, ramp, family),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.time, this.chars, this.cell, this.speed, this.ramp, this.family) : super(repaint: time);

  final ValueNotifier<double> time;
  final String chars;
  final double cell, speed;
  final (Color, Color, Color) ramp;
  final String family;

  /// Paragraph cache: one per glyph per brightness step, so a frame draws, never lays out.
  static const int _steps = 24;
  final Map<int, ui.Paragraph> _cache = {};

  static double _hash(double x, double y) {
    final s = math.sin(x * 127.1 + y * 311.7) * 43758.5453;
    return s - s.floorToDouble();
  }

  ui.Paragraph _glyph(int idx, int step) => _cache.putIfAbsent(idx * 100 + step, () {
        final lum = step / (_steps - 1);
        final color = lum < 0.4 ? Color.lerp(ramp.$1, ramp.$2, lum / 0.4)! : Color.lerp(ramp.$2, ramp.$3, (lum - 0.4) / 0.6)!;
        final b = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'packages/$uiFontPackage/$family', fontSize: (cell * 0.82).roundToDouble(), fontWeight: FontWeight.w700))
          ..pushStyle(ui.TextStyle(color: color.withValues(alpha: math.min(1, lum * 1.2)), fontFamily: 'packages/$uiFontPackage/$family'))
          ..addText(chars.characters.elementAt(idx));
        return b.build()..layout(ui.ParagraphConstraints(width: cell * 2));
      });

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value * speed;
    final cols = (size.width / cell).ceil(), rows = (size.height / cell).ceil();
    final n = chars.characters.length;
    for (var gy = 0; gy < rows; gy++) {
      for (var gx = 0; gx < cols; gx++) {
        // A drifting intensity field, brightest toward the centre.
        final nx = gx / cols - 0.5, ny = gy / rows - 0.5;
        final wave = math.sin(gx * 0.18 + t * 0.9) * 0.5 + math.cos(gy * 0.21 - t * 0.7) * 0.5;
        final radial = 1 - math.min(1, math.sqrt(nx * nx + ny * ny) * 1.7);
        final lum = radial * 0.7 + wave * 0.25 + 0.05;
        if (lum < 0.12) continue;
        final h0 = _hash(gx.toDouble(), gy.toDouble());
        final phase = (t * 0.9 + h0 * 9).floorToDouble();
        final flick = _hash(gx + phase, gy + 7.0) > 0.86 ? 1 : 0;
        final idx = ((h0 * n).floor() + flick) % n;
        final step = (lum.clamp(0.0, 1.0) * (_steps - 1)).round();
        final p = _glyph(idx, step);
        canvas.drawParagraph(p, Offset(gx * cell + cell / 2 - p.maxIntrinsicWidth / 2, gy * cell + cell / 2 - p.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.chars != chars || old.cell != cell || old.speed != speed || old.ramp != ramp;
}

/// `ui-grain`: an animated film-grain overlay. Put it at the top of a [Stack] over the whole app;
/// it ignores touches and screen readers. Hidden under reduced motion.
class UiGrain extends StatefulWidget {
  const UiGrain({super.key, this.opacity = 0.06});

  final double opacity;

  @override
  State<UiGrain> createState() => _UiGrainState();
}

class _UiGrainState extends State<UiGrain> with SingleTickerProviderStateMixin {
  // The web shifts the noise in 8 steps over 8 s.
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 8));
  ui.Image? _noise;

  static const List<Offset> _steps = [Offset(0, 0), Offset(-0.02, 0.01), Offset(0.01, -0.02), Offset(-0.01, 0.02), Offset(0.02, -0.01), Offset(0, 0), Offset(-0.01, -0.01), Offset(0.01, 0.01)];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _noise ??= _makeNoise(context.ui);
    final on = uiFxMotion(context) != UiFxMotion.calm;
    if (on && uiFxMotion(context) == UiFxMotion.full && !_c.isAnimating) _c.repeat();
    if (!on) _c.stop();
  }

  /// 200×200 of random light and dark specks, made once.
  static ui.Image _makeNoise(UiTokens t) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final rnd = math.Random(3);
    final light = Paint(), dark = Paint();
    for (var i = 0; i < 14000; i++) {
      final a = rnd.nextDouble() * 0.85;
      final p = rnd.nextBool() ? (light..color = t.mediaOnScrim.withValues(alpha: a)) : (dark..color = t.mediaScrim.withValues(alpha: a));
      canvas.drawRect(Rect.fromLTWH(rnd.nextInt(200).toDouble(), rnd.nextInt(200).toDouble(), 1, 1), p);
    }
    return rec.endRecording().toImageSync(200, 200);
  }

  @override
  void dispose() {
    _c.dispose();
    _noise?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Grain is texture, not information: under reduced motion it goes entirely.
    if (uiFxMotion(context) == UiFxMotion.calm || _noise == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _GrainPainter(_noise!, _steps[(_c.value * _steps.length).floor() % _steps.length], widget.opacity, context.ui.mediaScrim),
          ),
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.noise, this.shift, this.opacity, this.tint);
  final ui.Image noise;
  final Offset shift;
  final double opacity;

  /// Any opaque token colour: only its alpha (the [opacity]) matters for the layer.
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final m = Matrix4.translationValues(shift.dx * size.width, shift.dy * size.height, 0).storage;
    // Overlay-blended onto what is underneath, like the web's mix-blend-mode: overlay.
    canvas.saveLayer(bounds, Paint()
      ..blendMode = BlendMode.overlay
      ..color = tint.withValues(alpha: opacity));
    canvas.drawRect(bounds, Paint()..shader = ImageShader(noise, TileMode.repeated, TileMode.repeated, m));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.shift != shift || old.opacity != opacity || old.noise != noise || old.tint != tint;
}
