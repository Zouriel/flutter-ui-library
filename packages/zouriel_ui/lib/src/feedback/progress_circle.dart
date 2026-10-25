import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/types.dart';
import '../theme/theme.dart';

/// A circular progress indicator, the round sibling of `UiProgressBar`: determinate when [value]
/// (0–100) is set, otherwise an indeterminate turning arc. [showValue] writes the percentage in the
/// middle (give it a [size] of 40 or more). Announced with [label] and the percentage.
class UiProgressCircle extends StatefulWidget {
  const UiProgressCircle({
    super.key,
    this.value,
    this.size = 40,
    this.strokeWidth = 4,
    this.tone = UiStatus.primary,
    this.label,
    this.showValue = false,
    this.child,
  });

  /// Drawn in the middle instead of the percentage: a countdown's seconds (the web's projected content).
  final Widget? child;

  final double? value;
  final double size;
  final double strokeWidth;
  final UiStatus tone;

  /// The name read out; [UiStrings.progress] when null.
  final String? label;
  final bool showValue;

  @override
  State<UiProgressCircle> createState() => _UiProgressCircleState();
}

class _UiProgressCircleState extends State<UiProgressCircle> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(UiProgressCircle old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    // Like the spinner, the indeterminate arc keeps moving under reduced motion, only slower.
    _spin.duration = Duration(milliseconds: context.uiAnimate ? 1400 : 2800);
    if (widget.value == null) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final fill = widget.tone.color(t);
    final v = widget.value?.clamp(0, 100).toDouble();
    Widget ring;
    if (v != null) {
      ring = TweenAnimationBuilder<double>(
        tween: Tween(end: v / 100),
        duration: context.uiAnimate ? t.motionBase : Duration.zero,
        curve: t.easeStandard,
        builder: (context, p, _) => CustomPaint(painter: _ArcPainter(track: t.track, color: fill, stroke: widget.strokeWidth, start: 0, sweep: p)),
      );
    } else {
      ring = AnimatedBuilder(
        animation: _spin,
        builder: (context, _) {
          // The arc grows and shrinks while the whole ring turns.
          final x = _spin.value;
          final sweep = 0.1 + 0.25 * (1 - math.cos(x * 2 * math.pi)) / 2;
          return CustomPaint(painter: _ArcPainter(track: t.track, color: fill, stroke: widget.strokeWidth, start: x, sweep: sweep));
        },
      );
    }
    return Semantics(
      label: widget.label ?? context.uiStrings.progress,
      value: v == null ? null : '${v.round()}%',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: widget.size,
          child: Stack(fit: StackFit.expand, children: [
            ring,
            if (widget.child != null)
              Center(
                child: DefaultTextStyle.merge(
                  style: context.uiText.label.copyWith(
                    fontSize: (widget.size * 0.26).clamp(11.0, 32.0),
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  child: widget.child!,
                ),
              )
            else if (widget.showValue && v != null)
              Center(
                child: Text(
                  '${v.round()}%',
                  style: context.uiText.label.copyWith(
                    fontSize: (widget.size * 0.26).clamp(11.0, 32.0),
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.track, required this.color, required this.stroke, required this.start, required this.sweep});
  final Color track;
  final Color color;
  final double stroke;

  /// Start angle and length, in turns, from twelve o'clock.
  final double start;
  final double sweep;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, p);
    if (sweep <= 0) return;
    p
      ..color = color
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2 + start * 2 * math.pi, sweep * 2 * math.pi, false, p);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.track != track || old.color != color || old.stroke != stroke || old.start != start || old.sweep != sweep;
}
