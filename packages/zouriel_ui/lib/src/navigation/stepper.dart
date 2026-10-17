import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Where a step stands relative to the active one (the web `UiStepState`).
enum UiStepState { done, active, todo }

/// The colour of finished and active steps (the web `tone`).
enum UiStepperTone { primary, success }

/// How a [UiStepper] draws its steps (the web `variant`): numbered markers with labels, or a
/// compact strip of small dots (labels kept for screen readers).
enum UiStepperVariant { standard, dots }

/// One step of a [UiStepper].
@immutable
class UiStep {
  const UiStep({required this.label, this.description});
  final String label;
  final String? description;
}

/// `ui-stepper`: progress through ordered steps. Steps before [active] are done (a filled marker with
/// a check that draws itself in), [active] is current, the rest are to do.
///
/// Horizontal when the labels fit, otherwise vertical (markers in a column joined by a line), so no
/// label is ever cut or hidden on a phone. Each step is read as "Step 2 of 4, Shipping, current".
///
/// A vertical stepper shows [body] under each step's label (the web `uiStepBody` template). The
/// [UiStepperVariant.dots] variant is a strip of 10px dots: finished and active steps in the [tone]
/// (the active one ringed), steps not reached solid in the text colour.
class UiStepper extends StatelessWidget {
  const UiStepper({
    super.key,
    required this.steps,
    this.active = 0,
    this.axis,
    this.tone = UiStepperTone.primary,
    this.variant = UiStepperVariant.standard,
    this.body,
    this.label,
  });

  final List<UiStep> steps;
  final int active;

  /// Force a direction; by default horizontal when it fits.
  final Axis? axis;
  final UiStepperTone tone;
  final UiStepperVariant variant;

  /// Content under each step's label in a vertical stepper (details, history, actions).
  final Widget? Function(BuildContext context, int index, UiStepState state)? body;

  /// An accessible name for the list of steps.
  final String? label;

  static const double _marker = 24;
  static const double _dot = 10;

  UiStepState _stateOf(int i) => i < active ? UiStepState.done : i == active ? UiStepState.active : UiStepState.todo;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final toneColor = tone == UiStepperTone.success ? t.success : t.primary;
    final toneContrast = tone == UiStepperTone.success ? t.successContrast : t.primaryContrast;
    final named = label;
    Widget labelled(Widget child) => named == null ? child : Semantics(container: true, label: named, child: child);
    if (variant == UiStepperVariant.dots) return labelled(_dots(context, toneColor));
    final labelStyle = context.uiText.body.copyWith(fontSize: t.fontSizeSm, fontWeight: FontWeight.w500, height: 1.35);
    final desc = context.uiText.caption.copyWith(height: 1.35);
    final scale = MediaQuery.textScalerOf(context);

    double textWidth(UiStep s) {
      double w(String v, TextStyle st) {
        final p = TextPainter(text: TextSpan(text: v, style: st), textDirection: TextDirection.ltr, textScaler: scale, maxLines: 1)..layout();
        final r = p.width;
        p.dispose();
        return r;
      }

      return math.max(w(s.label, labelStyle), s.description == null ? 0 : w(s.description!, desc));
    }

    return LayoutBuilder(builder: (context, box) {
      var horizontal = axis != Axis.vertical;
      if (axis == null && box.maxWidth.isFinite) {
        var need = 0.0;
        for (var i = 0; i < steps.length; i++) {
          need += _marker + t.space2 + textWidth(steps[i]);
          if (i < steps.length - 1) need += t.space2 + t.space4 + t.space2; // gap + min bar + margins
        }
        horizontal = need <= box.maxWidth;
      }

      Widget text(int i) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(steps[i].label, style: labelStyle.copyWith(color: i <= active ? t.text : t.textSecondary)),
              if (steps[i].description != null) Text(steps[i].description!, style: desc),
            ],
          );

      Widget step(int i, Widget child) {
        final state = i < active ? 'completed' : i == active ? 'current' : 'not started';
        return Semantics(
          container: true,
          label: 'Step ${i + 1} of ${steps.length}, ${steps[i].label}${steps[i].description == null ? '' : ', ${steps[i].description}'}, $state',
          selected: i == active,
          child: ExcludeSemantics(child: child),
        );
      }

      if (horizontal) {
        return labelled(Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          for (var i = 0; i < steps.length; i++)
            if (i < steps.length - 1)
              Expanded(
                child: step(i, Row(children: [
                  _Marker(index: i, active: active, tone: toneColor, toneContrast: toneContrast),
                  SizedBox(width: t.space2),
                  text(i),
                  Expanded(
                    child: Container(
                      height: 1,
                      constraints: BoxConstraints(minWidth: t.space4),
                      margin: EdgeInsets.symmetric(horizontal: t.space2),
                      color: i < active ? toneColor : t.border,
                    ),
                  ),
                ])),
              )
            else
              step(i, Row(mainAxisSize: MainAxisSize.min, children: [_Marker(index: i, active: active, tone: toneColor, toneContrast: toneContrast), SizedBox(width: t.space2), text(i)])),
        ]));
      }

      return labelled(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < steps.length; i++)
          Stack(children: [
            // The line to the next step runs down the marker column, beside any body.
            if (i < steps.length - 1)
              Positioned(
                left: _marker / 2 - 0.5,
                top: _marker + t.space1,
                bottom: t.space1,
                child: Container(width: 1, color: i < active ? toneColor : t.border),
              ),
            Padding(
              padding: EdgeInsets.only(bottom: i < steps.length - 1 ? t.space3 + t.space1 : 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                step(i, _Marker(index: i, active: active, tone: toneColor, toneContrast: toneContrast)),
                SizedBox(width: t.space3),
                Expanded(
                  child: Padding(
                    // Centre the first line on the marker.
                    padding: EdgeInsets.only(top: (_marker - labelStyle.fontSize! * 1.35) / 2),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                      ExcludeSemantics(child: text(i)),
                      if (body?.call(context, i, _stateOf(i)) case final b?) Padding(padding: EdgeInsets.only(top: t.space2), child: b),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
      ]));
    });
  }
}

extension on UiStepper {
  /// The dots variant: one 10px dot per step joined by short lines, along [UiStepper.axis]
  /// (horizontal unless vertical is asked for). Each dot is read as "Shipping, done".
  Widget _dots(BuildContext context, Color toneColor) {
    final t = context.ui;
    final vertical = axis == Axis.vertical;
    Widget dot(int i) {
      final st = _stateOf(i);
      final reached = st != UiStepState.todo;
      final word = switch (st) { UiStepState.done => 'done', UiStepState.active => 'current', UiStepState.todo => 'not reached' };
      return Semantics(
        label: '${steps[i].label}, $word',
        selected: st == UiStepState.active,
        child: Container(
          width: UiStepper._dot,
          height: UiStepper._dot,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: reached ? toneColor : t.text,
            // The current step: a ring in the tone, with a gap in the surface colour.
            boxShadow: st == UiStepState.active ? [BoxShadow(color: t.surface, spreadRadius: 2), BoxShadow(color: toneColor, spreadRadius: 4)] : null,
          ),
        ),
      );
    }

    Widget line(int i) => Container(
          width: vertical ? 1 : 8,
          height: vertical ? 8 : 1,
          margin: vertical ? const EdgeInsets.symmetric(vertical: 2) : const EdgeInsets.symmetric(horizontal: 2),
          color: i < active ? toneColor : t.border,
        );

    final children = <Widget>[
      for (var i = 0; i < steps.length; i++) ...[dot(i), if (i < steps.length - 1) line(i)],
    ];
    return vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: children)
        : Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.index, required this.active, required this.tone, required this.toneContrast});
  final int index;
  final int active;
  final Color tone;
  final Color toneContrast;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final done = index < active;
    final current = index == active;
    return AnimatedContainer(
      duration: context.uiAnimate ? t.motionBase : Duration.zero,
      curve: t.easeStandard,
      width: UiStepper._marker,
      height: UiStepper._marker,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? tone : t.surface,
        border: Border.all(color: done ? tone : current ? tone : t.border),
      ),
      alignment: Alignment.center,
      child: done
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: context.uiAnimate ? 0 : 1, end: 1),
              duration: context.uiAnimate ? t.motionSlow : Duration.zero,
              curve: t.easeDecelerate,
              builder: (context, p, _) => CustomPaint(size: const Size.square(14), painter: _CheckPainter(toneContrast, p)),
            )
          : Text(
              '${index + 1}',
              style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, fontWeight: FontWeight.w600, height: 1, color: current ? tone : t.textMuted),
            ),
    );
  }
}

/// The web stepper's check (`M5 12.5l4.5 4.5L19 7` on a 24 grid), drawn up to [progress].
class _CheckPainter extends CustomPainter {
  _CheckPainter(this.color, this.progress);
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final full = Path()
      ..moveTo(5, 12.5)
      ..lineTo(9.5, 17)
      ..lineTo(19, 7);
    final partial = Path();
    var remaining = 0.0;
    for (final m in full.computeMetrics()) {
      remaining = m.length * progress;
      partial.addPath(m.extractPath(0, remaining), Offset.zero);
    }
    canvas.drawPath(
      partial,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.color != color || old.progress != progress;
}
