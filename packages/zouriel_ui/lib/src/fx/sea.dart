import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'motion.dart';
import 'sea_shapes.dart';

export 'sea_shapes.dart' show UiSeaShape, UiSeaShapePart, UiSeaTone, uiSeaShapes, uiSeaTone;

// The maldives theme's sea backdrops (the web `@zouriel/ui/fx` sea components). Decorative only:
// they ignore touches and screen readers and paint from the theme tokens (the maldives brand
// colours, or theme roles in other themes). Continuous motion (the tide, the float, the shimmer,
// the pulse) runs only at full motion; one-shot entrances soften to a fade under reduced motion and
// are skipped when the library's animations are off. Everything moves by transform and opacity.

/// Wave bands for [UiWaveFooter], the web `UiWaveLayers`: 2 or 3.
typedef UiWaveLayers = int;

/// Which corner a [UiCoralDecor] or [UiPalmDecor] sits in, the web `UiDecorCorner`.
enum UiDecorCorner { bl, br, tl, tr }

/// `ui-wave-footer`: two or three stacked wave bands along the bottom of the space it is given (in a
/// [Stack], use it as `Positioned.fill`), in the theme's Lagoon. Each band drifts sideways on its
/// own slow loop, alternating direction (the tide: 30, 38 and 46 seconds); the drift runs only at
/// full motion.
class UiWaveFooter extends StatefulWidget {
  const UiWaveFooter({super.key, this.layers = 3, this.height = 120, this.opacity = 0.5})
      : assert(layers == 2 || layers == 3);

  /// Bands, back to front; 2 drops the middle one.
  final UiWaveLayers layers;

  /// Height of the tallest band in logical px.
  final double height;

  /// Opacity of the whole footer.
  final double opacity;

  @override
  State<UiWaveFooter> createState() => _UiWaveFooterState();
}

class _Band {
  const _Band(this.shape, this.height, this.seconds, this.alpha, {this.front = false});
  final String shape;

  /// Share of the footer's height.
  final double height;
  final double seconds;
  final double alpha;

  /// The front band mixes Lagoon into Mist instead of fading it.
  final bool front;
}

const List<_Band> _bands = [
  _Band('wave1', 1, 30, 0.35),
  _Band('wave2', 0.82, 38, 0.55),
  _Band('wave3', 0.64, 46, 1, front: true),
];

class _UiWaveFooterState extends State<UiWaveFooter> with SingleTickerProviderStateMixin {
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
    final lagoon = uiSeaTone(t, UiSeaTone.lagoon);
    final bands = widget.layers == 2 ? [_bands[0], _bands[2]] : _bands;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: Opacity(
              opacity: widget.opacity,
              child: ClipRect(
                child: CustomPaint(
                  painter: _WavePainter(
                    _time,
                    [
                      for (final b in bands)
                        (b, b.front ? Color.lerp(t.mist ?? t.bg, lagoon, 0.55)! : lagoon.withValues(alpha: b.alpha)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.time, this.bands) : super(repaint: time);
  final ValueNotifier<double> time;
  final List<(_Band, Color)> bands;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (i, (band, color)) in bands.indexed) {
      final shape = uiSeaShapes[band.shape]!;
      final h = size.height * band.height;
      final frac = (time.value / band.seconds) % 1;
      // Twice the width, repeating every half: drifting by half loops without a seam. Every other
      // band runs the other way (the web's animation-direction: reverse).
      final dx = i.isOdd ? -size.width * (1 - frac) : -size.width * frac;
      canvas.save();
      canvas.translate(dx, size.height - h);
      canvas.scale(size.width * 2 / shape.size.width, h / shape.size.height);
      final paint = Paint()..color = color;
      for (final p in shape.parts) {
        canvas.drawPath(p.toPath(), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.bands.length != bands.length || [
        for (var i = 0; i < bands.length; i++) old.bands[i].$2 != bands[i].$2,
      ].any((x) => x);
}

/// `ui-ocean-hero`: a sea backdrop behind [child]: the theme's hero gradient (in maldives a sand and
/// coral sky over the lagoon into deep teal), an optional photo under it as a wash, and a slow
/// diagonal light sweep every 8 seconds (full motion only). With [fill] it expands to the space it
/// is given instead of sizing to [child].
class UiOceanHero extends StatefulWidget {
  const UiOceanHero({super.key, this.child, this.src, this.shimmer = true, this.fill = false});

  final Widget? child;

  /// Optional photo under the gradient. Decorative.
  final ImageProvider? src;

  /// The slow light sweep.
  final bool shimmer;
  final bool fill;

  @override
  State<UiOceanHero> createState() => _UiOceanHeroState();
}

class _UiOceanHeroState extends State<UiOceanHero> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 8));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(UiOceanHero old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final move = widget.shimmer && uiFxMotion(context) == UiFxMotion.full;
    if (move && !_c.isAnimating) _c.repeat();
    if (!move) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final sky = IgnorePointer(
      child: ExcludeSemantics(
        // The gradient is the sky; over a photo it is repeated as a wash, so the picture shows through.
        child: Stack(fit: StackFit.expand, children: [
          DecoratedBox(decoration: BoxDecoration(gradient: t.gradientHero.toGradient())),
          if (widget.src != null) ...[
            Image(image: widget.src!, fit: BoxFit.cover),
            Opacity(opacity: 0.55, child: DecoratedBox(decoration: BoxDecoration(gradient: t.gradientHero.toGradient()))),
          ],
          if (widget.shimmer && uiFxMotion(context) == UiFxMotion.full)
            LayoutBuilder(builder: (context, box) => _Sweep(animation: _c, size: box.biggest, color: t.mist ?? t.surfaceRaised)),
        ]),
      ),
    );
    final stack = Stack(children: [Positioned.fill(child: sky), if (widget.child != null) widget.child!]);
    return ClipRect(child: widget.fill ? SizedBox.expand(child: stack) : stack);
  }
}

/// The hero's light sweep: a 115° band of light that crosses once per loop, fading in and out at
/// its ends (the web `ui-fx-shimmer` keyframes: 0 → 0.18 by 20%, held to 60%, gone by 80%).
class _Sweep extends AnimatedWidget {
  const _Sweep({required Animation<double> animation, required this.size, required this.color}) : super(listenable: animation);
  final Size size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final v = (listenable as Animation<double>).value;
    final e = context.ui.easeStandard.transform(math.min(1, v / 0.8));
    final o = v < 0.2 ? v / 0.2 : v < 0.6 ? 1.0 : v < 0.8 ? (0.8 - v) / 0.2 : 0.0;
    // The band is 2.2 times the hero wide (the web's inset: -20% -60%) and travels ±40% of that.
    final w = size.width * 2.2, h = size.height * 1.4;
    return OverflowBox(
      maxWidth: w,
      maxHeight: h,
      child: Transform.translate(
        offset: Offset((e * 0.8 - 0.4) * w, 0),
        child: Opacity(
          opacity: 0.18 * o,
          child: SizedBox(
            width: w,
            height: h,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  // CSS 115deg: toward the right and slightly down.
                  begin: Alignment(-math.sin(115 * math.pi / 180), math.cos(115 * math.pi / 180)),
                  end: Alignment(math.sin(115 * math.pi / 180), -math.cos(115 * math.pi / 180)),
                  colors: [color.withValues(alpha: 0), color, color.withValues(alpha: 0)],
                  stops: const [0.38, 0.5, 0.62],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The corner silhouettes' shared frame: the corner, the mirror, the float.
class _Decor extends StatefulWidget {
  const _Decor({required this.shape, required this.base, required this.corner, required this.scale, required this.opacity});
  final String shape;
  final Size base;
  final UiDecorCorner corner;
  final double scale, opacity;

  @override
  State<_Decor> createState() => _DecorState();
}

class _DecorState extends State<_Decor> with SingleTickerProviderStateMixin {
  // The web floats 4px up over 5s and back (animation-direction: alternate).
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 5));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final move = uiFxMotion(context) == UiFxMotion.full;
    if (move && !_c.isAnimating) _c.repeat(reverse: true);
    if (!move) _c.value = 0;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final c = widget.corner;
    final right = c == UiDecorCorner.br || c == UiDecorCorner.tr, top = c == UiDecorCorner.tl || c == UiDecorCorner.tr;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Align(
          alignment: Alignment(right ? 1 : -1, top ? -1 : 1),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) => Transform.translate(offset: Offset(0, -4 * t.easeStandard.transform(_c.value)), child: child),
            child: Opacity(
              opacity: widget.opacity,
              child: SizedBox.fromSize(
                size: widget.base * widget.scale,
                // Mirrored to face inward, like the web's scaleX(-1) / scaleY(-1).
                child: Transform.scale(
                  scaleX: right ? -1 : 1,
                  scaleY: top ? -1 : 1,
                  child: CustomPaint(painter: _ShapePainter(uiSeaShapes[widget.shape]!, t)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.shape, this.t);
  final UiSeaShape shape;
  final UiTokens t;

  @override
  void paint(Canvas canvas, Size size) {
    // Uniform scale, anchored at the bottom-left (the web's default preserveAspectRatio, meet).
    final s = math.min(size.width / shape.size.width, size.height / shape.size.height);
    canvas.translate(0, size.height - shape.size.height * s);
    canvas.scale(s);
    for (final p in shape.parts) {
      final color = uiSeaTone(t, p.tone);
      final paint = Paint()..color = color.withValues(alpha: color.a * (p.opacity ?? 1));
      if (p.stroke != null) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = p.stroke!
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
      }
      canvas.drawPath(p.toPath(), paint);
    }
  }

  @override
  bool shouldRepaint(_ShapePainter old) => old.shape != shape || old.t != t;
}

/// `ui-coral-decor`: branching coral on a sand mound in a [corner] of the space it is given (in a
/// [Stack], use it as `Positioned.fill`); floats gently. 160 × 128 at [scale] 1.
class UiCoralDecor extends StatelessWidget {
  const UiCoralDecor({super.key, this.corner = UiDecorCorner.bl, this.scale = 1, this.opacity = 0.9});
  final UiDecorCorner corner;
  final double scale, opacity;

  @override
  Widget build(BuildContext context) =>
      _Decor(shape: 'coral', base: const Size(160, 128), corner: corner, scale: scale, opacity: opacity);
}

/// `ui-palm-decor`: two palm silhouettes leaning out of a [corner] of the space it is given (in a
/// [Stack], use it as `Positioned.fill`); floats gently. 160 × 176 at [scale] 1.
class UiPalmDecor extends StatelessWidget {
  const UiPalmDecor({super.key, this.corner = UiDecorCorner.bl, this.scale = 1, this.opacity = 0.9});
  final UiDecorCorner corner;
  final double scale, opacity;

  @override
  Widget build(BuildContext context) =>
      _Decor(shape: 'palm', base: const Size(160, 176), corner: corner, scale: scale, opacity: opacity);
}

/// `ui-sunrise`: a Coral sun with a soft Sand glow behind [child] (a logo). It fades in and rises
/// 12px on mount over twice `motionSlow`, then idles with a slow glow pulse. Under reduced motion it
/// only fades in and does not pulse; with the library's animations off it simply shows.
class UiSunrise extends StatefulWidget {
  const UiSunrise({super.key, this.child, this.size = 120});
  final Widget? child;

  /// Diameter of the sun; the widget is 1.6 times that, for the glow.
  final double size;

  @override
  State<UiSunrise> createState() => _UiSunriseState();
}

class _UiSunriseState extends State<UiSunrise> with TickerProviderStateMixin {
  AnimationController? _rise;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = uiFxMotion(context);
    if (_rise == null) {
      _rise = AnimationController(vsync: this, duration: context.ui.motionSlow * 2);
      if (motion == UiFxMotion.none) {
        _rise!.value = 1;
      } else {
        _rise!.forward();
      }
    }
    if (motion == UiFxMotion.full && !_pulse.isAnimating) _pulse.repeat();
    if (motion != UiFxMotion.full) _pulse.value = 0;
  }

  @override
  void dispose() {
    _rise?.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final calm = uiFxMotion(context) == UiFxMotion.calm;
    final d = widget.size;
    return SizedBox.square(
      dimension: d * 1.6,
      child: Center(
        child: AnimatedBuilder(
          animation: _rise!,
          builder: (context, child) {
            final v = t.easeDecelerate.transform(_rise!.value);
            return Opacity(opacity: v, child: Transform.translate(offset: Offset(0, calm ? 0 : 12 * (1 - v)), child: child));
          },
          child: SizedBox.square(
            dimension: d,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              Positioned(
                left: -d * 0.3,
                top: -d * 0.3,
                right: -d * 0.3,
                bottom: -d * 0.3,
                child: ExcludeSemantics(child: _Pulse(animation: _pulse, child: _glow(t))),
              ),
              ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: uiSeaTone(t, UiSeaTone.coral), boxShadow: t.glowAmber),
                  child: SizedBox.square(dimension: d),
                ),
              ),
              if (widget.child != null)
                IconTheme(
                  data: IconThemeData(color: t.accentContrast, size: d * 0.4),
                  child: DefaultTextStyle.merge(style: TextStyle(color: t.accentContrast), child: widget.child!),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _glow(UiTokens t) => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [t.sand ?? t.accentSubtle, (t.sand ?? t.accentSubtle).withValues(alpha: 0)], stops: const [0, 0.7]),
        ),
      );
}

/// The shared slow glow pulse (`ui-fx-pulse`): opacity 0.75 → 1 and scale 1 → 1.06 and back.
class _Pulse extends AnimatedWidget {
  const _Pulse({required Animation<double> animation, required this.child}) : super(listenable: animation);
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final v = (listenable as Animation<double>).value;
    final k = context.ui.easeStandard.transform(v < 0.5 ? v * 2 : 2 - v * 2);
    return Opacity(opacity: 0.75 + 0.25 * k, child: Transform.scale(scale: 1 + 0.06 * k, child: child));
  }
}

/// The `.ui-pulse` class: a slow glow pulse for a "working" or "AI thinking" mark (an icon, a
/// dot), every 2.4 seconds. Still under reduced motion and with the library's animations off.
class UiPulse extends StatefulWidget {
  const UiPulse({super.key, required this.child});
  final Widget child;

  @override
  State<UiPulse> createState() => _UiPulseState();
}

class _UiPulseState extends State<UiPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (uiFxMotion(context) == UiFxMotion.full) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => uiFxMotion(context) == UiFxMotion.full ? _Pulse(animation: _c, child: widget.child) : widget.child;
}

/// `ui-sea-surface`: a whole sea-themed region in one widget. It scopes [theme] (maldives by
/// default, null keeps the surrounding theme) like [UiThemeScope], paints that theme's background,
/// and lays the wave footer and any corner decor behind [child].
class UiSeaSurface extends StatelessWidget {
  const UiSeaSurface({
    super.key,
    required this.child,
    this.theme = UiThemeName.maldives,
    this.waves = true,
    this.waveLayers = 3,
    this.waveHeight = 120,
    this.waveOpacity = 0.5,
    this.coral,
    this.palm,
    this.decorScale = 1,
  });

  final Widget child;
  final UiThemeName? theme;
  final bool waves;
  final UiWaveLayers waveLayers;
  final double waveHeight, waveOpacity;

  /// Corner for the coral, or null for none.
  final UiDecorCorner? coral;

  /// Corner for the palms, or null for none.
  final UiDecorCorner? palm;
  final double decorScale;

  @override
  Widget build(BuildContext context) {
    final region = Builder(
      builder: (context) => ColoredBox(
        color: context.ui.bg,
        child: ClipRect(
          child: Stack(children: [
            if (waves) Positioned.fill(child: UiWaveFooter(layers: waveLayers, height: waveHeight, opacity: waveOpacity)),
            if (coral != null) Positioned.fill(child: UiCoralDecor(corner: coral!, scale: decorScale)),
            if (palm != null) Positioned.fill(child: UiPalmDecor(corner: palm!, scale: decorScale)),
            child,
          ]),
        ),
      ),
    );
    return theme == null ? region : UiThemeScope(theme: theme!, child: region);
  }
}

/// `[uiTide]`: a staggered entrance for lists and cards. [child] fades in and slides up 8px over
/// `motionBase`, starting [delay] + [index] × [step] after it is first built. Under reduced motion it
/// only fades (like the web's `ui-slide-up-enter`); with the library's animations off it simply shows.
class UiTide extends StatefulWidget {
  const UiTide({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = Duration.zero,
    this.step = const Duration(milliseconds: 60),
  });

  final Widget child;

  /// The item's position in its list (the web directive's value).
  final int index;

  /// Delay before the first item (the web `tideDelay`).
  final Duration delay;

  /// Extra delay per index (the web `tideStep`).
  final Duration step;

  @override
  State<UiTide> createState() => _UiTideState();
}

class _UiTideState extends State<UiTide> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  // The wait is the front part of one controller run (no timers left pending): the item stays
  // hidden through it, then plays over motionBase.
  Curve _curve = Curves.linear;
  bool _calm = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    final t = context.ui, motion = uiFxMotion(context);
    _calm = motion == UiFxMotion.calm;
    final wait = widget.delay + widget.step * widget.index;
    final total = wait + t.motionBase;
    _c = AnimationController(vsync: this, duration: total);
    _curve = Interval(wait.inMicroseconds / total.inMicroseconds, 1, curve: t.easeDecelerate);
    if (motion == UiFxMotion.none) {
      _c!.value = 1;
    } else {
      _c!.forward();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c!,
      child: widget.child,
      builder: (context, child) {
        final v = _curve.transform(_c!.value);
        return Opacity(opacity: v, child: Transform.translate(offset: Offset(0, _calm ? 0 : 8 * (1 - v)), child: child));
      },
    );
  }
}
