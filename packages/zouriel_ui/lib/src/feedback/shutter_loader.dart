import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// `ui-shutter-loader` (0.72.0): a camera shutter whose six blades click shut three times, then rest
/// open; the same size, colour and announcement as [UiSpinner]. With `UiConfig(spinner:
/// UiSpinnerStyle.shutter)` every [UiSpinner] in the library draws this instead of the ring.
///
/// The colour is the surrounding text colour (so in a primary button it is the button's text
/// colour), else [color]. Under reduced motion the blades stay still and the mark pulses gently;
/// it never freezes, which would read as a hang.
class UiShutterLoader extends StatefulWidget {
  const UiShutterLoader({super.key, this.size = 16, this.color, this.label, this.decorative = false});

  final double size;
  final Color? color;

  /// The name read out; [UiStrings.loading] when null.
  final String? label;

  /// Set when something nearby already announces the busy state.
  final bool decorative;

  @override
  State<UiShutterLoader> createState() => _UiShutterLoaderState();
}

class _UiShutterLoaderState extends State<UiShutterLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: uiShutterCycle)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? DefaultTextStyle.of(context).style.color ?? context.ui.primary;
    final mark = SizedBox.square(
      dimension: widget.size,
      child: UiShutterMark(color: color, time: _c, reduced: !context.uiAnimate),
    );
    if (widget.decorative) return ExcludeSemantics(child: mark);
    return Semantics(label: widget.label ?? context.uiStrings.loading, liveRegion: true, child: mark);
  }
}

/// One burst: three clicks, then a still, open rest.
const Duration uiShutterCycle = Duration(milliseconds: 2100);

const double _cycleSeconds = 2.1;
const List<double> _clicks = [0, 0.35, 0.70];
const double _closeSeconds = 0.09;
const double _openSeconds = 0.2;

/// The ring's radius, blade reach and open blade distance, in the 10-unit box.
const double _r = 3.05;
const double _mid = 5;

/// How far an open blade sits from the centre.
@visibleForTesting
const double uiShutterOpenDistance = 1.47;

double _easeOut(double x) => x <= 0 ? 0 : (x >= 1 ? 1 : 1 - math.pow(1 - x, 3).toDouble());

/// How shut the blades are [seconds] into the loop: 0 open, 1 shut. Each click shuts over 90 ms
/// (ease-out cubic) and opens over 200 ms; the strongest click wins.
@visibleForTesting
double uiShutterClosedAt(double seconds) {
  final t = seconds % _cycleSeconds;
  var v = 0.0;
  for (final s in _clicks) {
    final d = t - s;
    if (d < 0) continue;
    if (d < _closeSeconds) {
      v = math.max(v, _easeOut(d / _closeSeconds));
    } else if (d < _closeSeconds + _openSeconds) {
      v = math.max(v, 1 - _easeOut((d - _closeSeconds) / _openSeconds));
    }
  }
  return v;
}

/// The blade distance from the centre when the blades are [closed] (0..1) shut.
@visibleForTesting
double uiShutterBladeDistance(double closed) => uiShutterOpenDistance * (1 - 0.92 * closed);

/// The six blades for blade distance [a], as start and end points in the 10-unit box.
@visibleForTesting
List<(Offset, Offset)> uiShutterBlades(double a) {
  const a0 = uiShutterOpenDistance;
  final sEnd = math.sqrt(_r * _r - a * a) * 0.97;
  final sStart = -0.85 * (a / a0) - 0.15 * (1 - a / a0);
  return [
    for (var i = 0; i < 6; i++)
      () {
        final th = i * math.pi / 3 + 0.26;
        final n = Offset(math.cos(th), math.sin(th));
        final tv = Offset(-n.dy, n.dx);
        final q = const Offset(_mid, _mid) + n * a;
        return (q + tv * sStart, q + tv * sEnd);
      }(),
  ];
}

/// The reduced-motion pulse: opacity 1 -> 0.55 -> 1 over one loop.
@visibleForTesting
double uiShutterPulseAt(double seconds) {
  final p = (seconds % _cycleSeconds) / _cycleSeconds;
  return 1 - 0.45 * (0.5 - 0.5 * math.cos(2 * math.pi * p));
}

/// The shutter drawing, sized by its parent. Driven by [time] (0..1 through one [uiShutterCycle])
/// when given, else drawn still with the blades [closed] shut and turned by [turn] radians (the
/// pull-to-refresh ball follows the finger with it). Not exported: [UiShutterLoader] is the widget.
class UiShutterMark extends StatelessWidget {
  const UiShutterMark({super.key, required this.color, this.time, this.reduced = false, this.closed = 0, this.turn = 0});

  final Color color;
  final Animation<double>? time;
  final bool reduced;
  final double closed;
  final double turn;

  @override
  Widget build(BuildContext context) {
    final time = this.time;
    if (time == null) return CustomPaint(painter: _ShutterPainter(color, closed, 1, turn));
    return CustomPaint(painter: _AnimatedShutterPainter(color, time, reduced));
  }
}

class _ShutterPainter extends CustomPainter {
  _ShutterPainter(this.color, this.closed, this.opacity, this.turn);

  final Color color;
  final double closed;
  final double opacity;
  final double turn;

  @override
  void paint(Canvas canvas, Size size) => paintShutter(canvas, size, color, closed, opacity, turn);

  @override
  bool shouldRepaint(_ShutterPainter old) =>
      old.color != color || old.closed != closed || old.opacity != opacity || old.turn != turn;
}

class _AnimatedShutterPainter extends CustomPainter {
  _AnimatedShutterPainter(this.color, this.time, this.reduced) : super(repaint: time);

  final Color color;
  final Animation<double> time;
  final bool reduced;

  @override
  void paint(Canvas canvas, Size size) {
    final s = time.value * _cycleSeconds;
    if (reduced) {
      paintShutter(canvas, size, color, 0, uiShutterPulseAt(s), 0);
    } else {
      paintShutter(canvas, size, color, uiShutterClosedAt(s), 1, 0);
    }
  }

  @override
  bool shouldRepaint(_AnimatedShutterPainter old) => old.color != color || old.time != time || old.reduced != reduced;
}

/// Draws the shutter into [size] (scaled from the 10-unit box).
void paintShutter(Canvas canvas, Size size, Color color, double closed, double opacity, double turn) {
  final scale = math.min(size.width, size.height) / 10;
  if (scale <= 0) return;
  canvas.save();
  canvas.translate((size.width - 10 * scale) / 2, (size.height - 10 * scale) / 2);
  canvas.scale(scale);
  if (turn != 0) {
    canvas.translate(_mid, _mid);
    canvas.rotate(turn);
    canvas.translate(-_mid, -_mid);
  }
  // The pulse fades the mark as one, so blades crossing the ring don't show darker joins.
  final fade = opacity < 1;
  if (fade) canvas.saveLayer(null, Paint()..color = color.withValues(alpha: opacity.clamp(0.0, 1.0)));
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.1;
  canvas.drawCircle(const Offset(_mid, _mid), _r, paint);
  paint.strokeWidth = 0.75;
  for (final (a, b) in uiShutterBlades(uiShutterBladeDistance(closed))) {
    canvas.drawLine(a, b, paint);
  }
  if (fade) canvas.restore();
  canvas.restore();
}
