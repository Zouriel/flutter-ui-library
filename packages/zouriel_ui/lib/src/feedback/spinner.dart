import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// `ui-spinner`: an indeterminate loading ring. Announced as "Loading" unless [label] says otherwise;
/// set [decorative] when something nearby already announces the busy state.
class UiSpinner extends StatefulWidget {
  const UiSpinner({super.key, this.size = 16, this.strokeWidth = 2, this.color, this.label, this.decorative = false});

  final double size;
  final double strokeWidth;
  final Color? color;
  /// The name read out; [UiStrings.loading] when null.
  final String? label;
  final bool decorative;

  @override
  State<UiSpinner> createState() => _UiSpinnerState();
}

class _UiSpinnerState extends State<UiSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A spinner is the one animation that keeps going under reduced motion, just slower:
    // a frozen spinner reads as a hang.
    final reduced = !context.uiAnimate;
    _c.duration = Duration(milliseconds: reduced ? 1600 : 800);
    if (!_c.isAnimating) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? DefaultTextStyle.of(context).style.color ?? context.ui.primary;
    final ring = SizedBox.square(
      dimension: widget.size,
      child: RotationTransition(
        turns: _c,
        child: CustomPaint(painter: _RingPainter(color, widget.strokeWidth)),
      ),
    );
    if (widget.decorative) return ExcludeSemantics(child: ring);
    return Semantics(label: widget.label ?? context.uiStrings.loading, liveRegion: true, child: ring);
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.color, this.stroke);
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    // Three quarters of a circle: the web spinner is a ring with one transparent side.
    canvas.drawArc(rect.deflate(stroke / 2), -math.pi / 2, math.pi * 1.5, false, p);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color || old.stroke != stroke;
}
