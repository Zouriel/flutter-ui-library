import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../theme/theme.dart';

/// `ui-splitter`: two panes with a draggable divider between them, for tablets and wide layouts.
/// [axis] horizontal puts the panes side by side (split by a vertical line); vertical stacks them.
///
/// The first pane's share is a percentage kept between 10 and 90. The divider is a focusable
/// slider for screen readers and keyboards: Left/Up shrink the first pane by 2%, Right/Down grow it.
/// Its grab area is 1px visually but 20dp wide on touch. Leave [ratio] null to keep the state here
/// (starting at [initialRatio]), or drive it with [ratio] + [onRatioChanged].
class UiSplitter extends StatefulWidget {
  const UiSplitter({
    super.key,
    required this.first,
    required this.second,
    this.axis = Axis.horizontal,
    this.ratio,
    this.initialRatio = 50,
    this.onRatioChanged,
    this.label = 'Resize panes',
  });

  final Widget first;
  final Widget second;
  final Axis axis;
  final double? ratio;
  final double initialRatio;
  final ValueChanged<double>? onRatioChanged;
  final String label;

  static const double minRatio = 10, maxRatio = 90;

  @override
  State<UiSplitter> createState() => _UiSplitterState();
}

class _UiSplitterState extends State<UiSplitter> {
  late double _own = widget.initialRatio;
  bool _hover = false, _focus = false, _drag = false;

  double get _ratio => (widget.ratio ?? _own).clamp(UiSplitter.minRatio, UiSplitter.maxRatio);

  void _set(double v) {
    final r = v.clamp(UiSplitter.minRatio, UiSplitter.maxRatio).toDouble();
    if (r == _ratio) return;
    if (widget.ratio == null) setState(() => _own = r);
    widget.onRatioChanged?.call(r);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final horizontal = widget.axis == Axis.horizontal;
    final grab = uiTouchPlatform(context) ? 20.0 : 7.0;
    return LayoutBuilder(builder: (context, box) {
      final total = horizontal ? box.maxWidth : box.maxHeight;
      final firstSize = (total - 1) * _ratio / 100;
      final lit = _hover || _focus || _drag;

      void dragTo(Offset local) {
        final pos = horizontal ? local.dx : local.dy;
        _set(pos / total * 100);
      }

      final gutter = Semantics(
        slider: true,
        label: widget.label,
        value: '${_ratio.round()}%',
        increasedValue: '${(_ratio + 2).clamp(10, 90).round()}%',
        decreasedValue: '${(_ratio - 2).clamp(10, 90).round()}%',
        onIncrease: () => _set(_ratio + 2),
        onDecrease: () => _set(_ratio - 2),
        child: FocusableActionDetector(
          mouseCursor: horizontal ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
          onShowFocusHighlight: (v) => setState(() => _focus = v),
          onShowHoverHighlight: (v) => setState(() => _hover = v),
          shortcuts: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): const _Nudge(-2),
            const SingleActivator(LogicalKeyboardKey.arrowUp): const _Nudge(-2),
            const SingleActivator(LogicalKeyboardKey.arrowRight): const _Nudge(2),
            const SingleActivator(LogicalKeyboardKey.arrowDown): const _Nudge(2),
          },
          actions: {_Nudge: CallbackAction<_Nudge>(onInvoke: (i) => _set(_ratio + i.by))},
          child: AnimatedContainer(
            duration: context.uiAnimate ? t.motionFast : Duration.zero,
            width: horizontal ? 1 : double.infinity,
            height: horizontal ? double.infinity : 1,
            decoration: BoxDecoration(color: lit ? t.primary : t.border, boxShadow: uiFocusRing(t, show: _focus)),
          ),
        ),
      );

      // The grab area overlaps both panes by grab px either side of the 1px line.
      final handle = Positioned(
        left: horizontal ? firstSize - grab : 0,
        right: horizontal ? null : 0,
        top: horizontal ? 0 : firstSize - grab,
        bottom: horizontal ? 0 : null,
        width: horizontal ? grab * 2 + 1 : null,
        height: horizontal ? null : grab * 2 + 1,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: horizontal ? (_) => setState(() => _drag = true) : null,
          onHorizontalDragUpdate: horizontal ? (d) => dragTo(Offset(firstSize + d.localPosition.dx - grab, 0)) : null,
          onHorizontalDragEnd: horizontal ? (_) => setState(() => _drag = false) : null,
          onVerticalDragStart: horizontal ? null : (_) => setState(() => _drag = true),
          onVerticalDragUpdate: horizontal ? null : (d) => dragTo(Offset(0, firstSize + d.localPosition.dy - grab)),
          onVerticalDragEnd: horizontal ? null : (_) => setState(() => _drag = false),
          child: Center(child: gutter),
        ),
      );

      final panes = Flex(direction: widget.axis, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: horizontal ? firstSize : null, height: horizontal ? null : firstSize, child: ClipRect(child: widget.first)),
        SizedBox(width: horizontal ? 1 : null, height: horizontal ? null : 1),
        Expanded(child: ClipRect(child: widget.second)),
      ]);
      return Stack(children: [Positioned.fill(child: panes), handle]);
    });
  }
}

class _Nudge extends Intent {
  const _Nudge(this.by);
  final double by;
}

/// Which side of the panel a [UiResizeHandle] sits on.
enum UiResizeEdge { top, bottom, left, right }

/// `ui-resize-handle`: a draggable edge that sets the size (px) of the panel next to it. Put it on
/// the panel's inner edge: a bottom panel's handle is on its [UiResizeEdge.top], so dragging up
/// makes it bigger.
///
/// Letting go within [snapDistance] of one of [snaps] settles on it; a double tap cycles through the
/// snaps. Keyboard: arrows resize by 16px (Shift: 64), Home/End go to [min]/[max]. Announced as a
/// slider with the size as its value.
class UiResizeHandle extends StatefulWidget {
  const UiResizeHandle({
    super.key,
    required this.size,
    required this.onChanged,
    this.min = 0,
    this.max = 10000,
    this.snaps = const [],
    this.edge = UiResizeEdge.top,
    this.label = 'Resize',
    this.snapDistance = 28,
    this.onResizeEnd,
  });

  final double size;
  final ValueChanged<double> onChanged;
  final double min, max;
  final List<double> snaps;
  final UiResizeEdge edge;
  final String label;
  final double snapDistance;
  final ValueChanged<double>? onResizeEnd;

  @override
  State<UiResizeHandle> createState() => _UiResizeHandleState();
}

class _UiResizeHandleState extends State<UiResizeHandle> {
  double _startSize = 0;
  double _travel = 0;
  double _last = 0;
  bool _hover = false, _focus = false;

  bool get _vertical => widget.edge == UiResizeEdge.top || widget.edge == UiResizeEdge.bottom;

  double _clamp(double v) => v.clamp(widget.min, widget.max).roundToDouble();

  void _emitEnd(double v) => widget.onResizeEnd?.call(v);

  void _key(double by) {
    final v = _clamp(widget.size + by);
    widget.onChanged(v);
    _emitEnd(v);
  }

  void _cycle() {
    final snaps = [...widget.snaps]..sort();
    if (snaps.isEmpty) return;
    final next = snaps.firstWhere((s) => s > widget.size + 1, orElse: () => snaps.first);
    final v = _clamp(next);
    widget.onChanged(v);
    _emitEnd(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    final thick = touch ? uiMinTouchTarget : 8.0;
    // Arrow keys that grow the panel: away from it.
    final grow = switch (widget.edge) {
      UiResizeEdge.top => LogicalKeyboardKey.arrowUp,
      UiResizeEdge.bottom => LogicalKeyboardKey.arrowDown,
      UiResizeEdge.left => LogicalKeyboardKey.arrowLeft,
      UiResizeEdge.right => LogicalKeyboardKey.arrowRight,
    };
    final shrink = switch (widget.edge) {
      UiResizeEdge.top => LogicalKeyboardKey.arrowDown,
      UiResizeEdge.bottom => LogicalKeyboardKey.arrowUp,
      UiResizeEdge.left => LogicalKeyboardKey.arrowRight,
      UiResizeEdge.right => LogicalKeyboardKey.arrowLeft,
    };
    final sign = widget.edge == UiResizeEdge.top || widget.edge == UiResizeEdge.left ? -1.0 : 1.0;
    final lit = _hover || _focus;

    void start(DragStartDetails _) {
      _startSize = widget.size;
      _last = widget.size;
      _travel = 0;
    }

    void update(DragUpdateDetails d) {
      _travel += _vertical ? d.delta.dy : d.delta.dx;
      // Kept here too: the parent's new size only arrives on the next build.
      _last = _clamp(_startSize + sign * _travel);
      widget.onChanged(_last);
    }

    void end(DragEndDetails _) {
      var v = _last;
      for (final s in widget.snaps) {
        if ((s - v).abs() <= widget.snapDistance) {
          v = _clamp(s);
          widget.onChanged(v);
          break;
        }
      }
      _emitEnd(v);
    }

    return Semantics(
      slider: true,
      label: widget.label,
      value: '${widget.size.round()}',
      increasedValue: '${_clamp(widget.size + 16).round()}',
      decreasedValue: '${_clamp(widget.size - 16).round()}',
      onIncrease: () => _key(16),
      onDecrease: () => _key(-16),
      child: FocusableActionDetector(
        mouseCursor: _vertical ? SystemMouseCursors.resizeRow : SystemMouseCursors.resizeColumn,
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        shortcuts: {
          SingleActivator(grow): const _Nudge(16),
          SingleActivator(grow, shift: true): const _Nudge(64),
          SingleActivator(shrink): const _Nudge(-16),
          SingleActivator(shrink, shift: true): const _Nudge(-64),
          const SingleActivator(LogicalKeyboardKey.home): _Nudge(-double.infinity),
          const SingleActivator(LogicalKeyboardKey.end): _Nudge(double.infinity),
        },
        actions: {_Nudge: CallbackAction<_Nudge>(onInvoke: (i) => _key(i.by))},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: _cycle,
          dragStartBehavior: DragStartBehavior.down,
          onVerticalDragStart: _vertical ? start : null,
          onVerticalDragUpdate: _vertical ? update : null,
          onVerticalDragEnd: _vertical ? end : null,
          onHorizontalDragStart: _vertical ? null : start,
          onHorizontalDragUpdate: _vertical ? null : update,
          onHorizontalDragEnd: _vertical ? null : end,
          child: SizedBox(
            width: _vertical ? double.infinity : thick,
            height: _vertical ? thick : double.infinity,
            child: Center(
              child: AnimatedContainer(
                duration: context.uiAnimate ? t.motionFast : Duration.zero,
                width: _vertical ? 36 : 3,
                height: _vertical ? 3 : 36,
                decoration: BoxDecoration(
                  color: lit ? t.primary : t.borderStrong,
                  borderRadius: BorderRadius.circular(t.radiusPill),
                  boxShadow: uiFocusRing(t, show: _focus),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
