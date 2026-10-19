import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/interactive.dart';
import '../../theme/theme.dart';

class _StepIntent extends Intent {
  const _StepIntent(this.kind);

  /// -1/+1 one step, -10/+10 a tenth of the range, -100/+100 to the ends.
  final int kind;
}

/// `ui-slider`: a themed range slider. Drag or tap the track; with a keyboard the arrow keys move
/// one [step], Page Up/Down a tenth of the range, Home/End to the ends. The filled part of the track
/// follows the value, and [showValue] prints it beside the track. Null [onChanged] disables it.
///
/// On phones the track keeps its 6px look inside a 48dp-tall touch band.
class UiSlider extends StatefulWidget {
  const UiSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.label = 'Slider',
    this.showValue = true,
    this.format,
    this.focusNode,
  }) : assert(max >= min),
       assert(step > 0);

  /// A null value shows [min].
  final double? value;
  final ValueChanged<double>? onChanged;

  /// Called once when a drag or key press finishes.
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final double step;

  /// Accessible name.
  final String label;
  final bool showValue;

  /// Formats the shown and announced value; defaults to the step's precision.
  final String Function(double value)? format;
  final FocusNode? focusNode;

  @override
  State<UiSlider> createState() => _UiSliderState();
}

class _UiSliderState extends State<UiSlider> {
  bool _focused = false, _hovered = false;
  final GlobalKey _trackKey = GlobalKey();

  bool get _enabled => widget.onChanged != null;
  double get _value => (widget.value ?? widget.min).clamp(widget.min, widget.max);

  double _snap(double v) {
    final steps = ((v - widget.min) / widget.step).round();
    return (widget.min + steps * widget.step).clamp(widget.min, widget.max).toDouble();
  }

  String _fmt(double v) {
    if (widget.format != null) return widget.format!(v);
    final s = widget.step.toString();
    final decimals = s.contains('.') && !s.endsWith('.0') ? s.split('.').last.length : 0;
    return v.toStringAsFixed(decimals);
  }

  void _set(double v, {bool end = false}) {
    final next = _snap(v);
    if (next != _value) widget.onChanged?.call(next);
    if (end) widget.onChangeEnd?.call(next);
  }

  void _fromPosition(Offset global, {bool end = false}) {
    final box = _trackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(global);
    // The thumb's centre travels from 8px to width - 8px.
    final usable = math.max(1.0, box.size.width - 16);
    var f = ((local.dx - 8) / usable).clamp(0.0, 1.0);
    if (Directionality.of(context) == TextDirection.rtl) f = 1 - f;
    _set(widget.min + f * (widget.max - widget.min), end: end);
  }

  void _stepBy(int kind) {
    final range = widget.max - widget.min;
    final v = switch (kind) {
      1 => _value + widget.step,
      -1 => _value - widget.step,
      10 => _value + math.max(widget.step, range / 10),
      -10 => _value - math.max(widget.step, range / 10),
      100 => widget.max,
      _ => widget.min,
    };
    _set(v, end: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final range = widget.max - widget.min;
    final fraction = range <= 0 ? 0.0 : (_value - widget.min) / range;
    final touch = uiTouchPlatform(context);
    final backward = rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft;
    final forward = rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight;

    final track = LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final thumbX = 8 + fraction * (w - 16);
      return SizedBox(
        key: _trackKey,
        height: touch ? uiMinTouchTarget : 24,
        child: Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(t.radiusPill),
                gradient: LinearGradient(
                  begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
                  end: rtl ? Alignment.centerLeft : Alignment.centerRight,
                  colors: [t.primary, t.primary, t.track, t.track],
                  stops: [0, thumbX / w, thumbX / w, 1],
                ),
              ),
            ),
            PositionedDirectional(
              start: thumbX - 8,
              child: AnimatedScale(
                scale: _hovered && _enabled ? 1.1 : 1,
                duration: t.motionFast,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: t.sliderThumb,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.sliderThumbBorder),
                    boxShadow: [...t.shadow1, if (_focused) ...t.focusRing],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });

    final shown = _fmt(_value);
    Widget result = Row(
      spacing: t.space3,
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapUp: _enabled ? (d) => _fromPosition(d.globalPosition, end: true) : null,
            onHorizontalDragStart: _enabled ? (d) => _fromPosition(d.globalPosition) : null,
            onHorizontalDragUpdate: _enabled ? (d) => _fromPosition(d.globalPosition) : null,
            onHorizontalDragEnd: _enabled ? (_) => widget.onChangeEnd?.call(_value) : null,
            child: track,
          ),
        ),
        if (widget.showValue)
          // The slot fits the longest value this slider can show, and at least 4 characters, so it
          // doesn't change size while dragging and stacked sliders end their tracks together.
          Builder(builder: (context) {
            final style = context.uiText.code.copyWith(fontSize: t.fontSizeSm, color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()]);
            final scale = MediaQuery.textScalerOf(context);
            double widthOf(String w) => (TextPainter(text: TextSpan(text: w, style: style), textDirection: TextDirection.ltr, textScaler: scale)..layout()).width;
            final slot = [for (final w in ['0000', _fmt(widget.min), _fmt(widget.max), _fmt(widget.min + widget.step)]) widthOf(w)].reduce(math.max);
            return ConstrainedBox(
              constraints: BoxConstraints(minWidth: slot.ceilToDouble()),
              child: Text(shown, textAlign: TextAlign.end, style: style),
            );
          }),
      ],
    );

    result = FocusableActionDetector(
      enabled: _enabled,
      focusNode: widget.focusNode,
      mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      shortcuts: {
        SingleActivator(forward): const _StepIntent(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): const _StepIntent(1),
        SingleActivator(backward): const _StepIntent(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): const _StepIntent(-1),
        const SingleActivator(LogicalKeyboardKey.pageUp): const _StepIntent(10),
        const SingleActivator(LogicalKeyboardKey.pageDown): const _StepIntent(-10),
        const SingleActivator(LogicalKeyboardKey.home): const _StepIntent(-100),
        const SingleActivator(LogicalKeyboardKey.end): const _StepIntent(100),
      },
      actions: {
        _StepIntent: CallbackAction<_StepIntent>(onInvoke: (i) {
          _stepBy(i.kind);
          return null;
        }),
      },
      child: result,
    );

    return Semantics(
      container: true,
      slider: true,
      label: widget.label,
      value: shown,
      increasedValue: _fmt(_snap(_value + widget.step)),
      decreasedValue: _fmt(_snap(_value - widget.step)),
      enabled: _enabled,
      focusable: _enabled,
      onIncrease: _enabled ? () => _stepBy(1) : null,
      onDecrease: _enabled ? () => _stepBy(-1) : null,
      child: ExcludeSemantics(
        child: AnimatedOpacity(opacity: _enabled ? 1 : 0.5, duration: t.motionBase, child: result),
      ),
    );
  }
}
