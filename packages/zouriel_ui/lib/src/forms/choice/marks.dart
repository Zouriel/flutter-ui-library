import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

import '../../core/interactive.dart';
import '../../theme/theme.dart';

/// The 18px checkbox square (16px when [small]): empty, ticked (the tick draws itself in), or mixed (a dash).
/// [value] null is the mixed state. Shared by checkbox and checkbox group.
class UiCheckMark extends StatelessWidget {
  const UiCheckMark({super.key, required this.value, this.states = const UiStates(), this.invalid = false, this.small = false});

  final bool? value;
  final UiStates states;
  final bool invalid;

  /// The sm checkbox's 16px square.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final on = value != false;
    final animate = context.uiAnimate;
    final border = on ? t.primary : invalid ? t.danger : states.hovered ? t.primary : t.controlBorder;
    // Compact density draws the mark 10% smaller (the web zoom: var(--ui-density-scale)).
    final z = t.densityScale;
    return AnimatedContainer(
      duration: animate ? t.motionFast : Duration.zero,
      curve: t.easeStandard,
      width: (small ? 16 : 18) * z,
      height: (small ? 16 : 18) * z,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: on ? t.primary : t.surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(t.radiusXs),
        boxShadow: states.focused ? t.focusRing : const [],
      ),
      alignment: Alignment.center,
      child: value == null
          ? Container(width: 9 * z, height: 2 * z, decoration: BoxDecoration(color: t.primaryContrast, borderRadius: BorderRadius.circular(1)))
          : TweenAnimationBuilder<double>(
              tween: Tween(end: value! ? 1 : 0),
              duration: animate ? t.motionBase : Duration.zero,
              curve: t.easeStandard,
              builder: (context, p, _) => CustomPaint(size: Size.square((small ? 11 : 12) * z), painter: _TickPainter(p, t.primaryContrast)),
            ),
    );
  }
}

/// The web tick (`M3 8.5l3 3 7-7` in a 16 box) drawn up to [progress] of its length.
class _TickPainter extends CustomPainter {
  _TickPainter(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final s = size.width / 16;
    final path = Path()
      ..moveTo(3 * s, 8.5 * s)
      ..lineTo(6 * s, 11.5 * s)
      ..lineTo(13 * s, 4.5 * s);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (progress >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    final PathMetric m = path.computeMetrics().first;
    canvas.drawPath(m.extractPath(0, m.length * progress), paint);
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.progress != progress || old.color != color;
}

/// The 18px radio circle; the inner dot springs in when [selected].
class UiRadioMark extends StatelessWidget {
  const UiRadioMark({super.key, required this.selected, this.states = const UiStates()});

  final bool selected;
  final UiStates states;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final animate = context.uiAnimate;
    final z = t.densityScale;
    return AnimatedContainer(
      duration: animate ? t.motionFast : Duration.zero,
      curve: t.easeStandard,
      width: 18 * z,
      height: 18 * z,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: t.surface,
        shape: BoxShape.circle,
        border: Border.all(color: selected || states.hovered ? t.primary : t.controlBorder),
        boxShadow: states.focused ? t.focusRing : const [],
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: animate ? t.motionFast : Duration.zero,
        // The spring overshoots; reduced motion has no animation at all.
        curve: t.easeSpring,
        child: Container(width: 8 * z, height: 8 * z, decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle)),
      ),
    );
  }
}

/// A mark (checkbox, radio, switch) beside its label: the label's first line lines up with the
/// mark, longer labels wrap under themselves. Dimmed when disabled.
class UiMarkRow extends StatelessWidget {
  const UiMarkRow({super.key, required this.mark, this.label, this.child, this.disabled = false, this.center = false, this.bold = false, this.fontSize});

  final Widget mark;
  final String? label;
  final Widget? child;
  final bool disabled;

  /// Centre the label on the mark (the switch) instead of top-aligning it.
  final bool center;
  final bool bold;

  /// Label size; defaults to the md font size.
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final style = context.uiText.body.copyWith(fontSize: fontSize ?? t.fontSizeMd, height: 1.35, color: t.text, fontWeight: bold ? FontWeight.w600 : null);
    final text = child ?? (label == null ? null : Text(label!));
    return AnimatedOpacity(
      opacity: disabled ? 0.5 : 1,
      duration: t.motionBase,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        spacing: t.space2,
        children: [
          mark,
          if (text != null) Flexible(child: DefaultTextStyle.merge(style: style, child: text)),
        ],
      ),
    );
  }
}
