import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../theme/theme.dart';

/// A drag in progress: the child's offset and where the pointer is (global coordinates).
@immutable
class UiDragEvent {
  const UiDragEvent({required this.position, required this.pointer});

  /// The child's offset from where it sits in layout (the web `{ x, y }`).
  final Offset position;

  /// The pointer, in global coordinates (the web `pointerX` / `pointerY`).
  final Offset pointer;
}

/// `uiDraggable`: lets the user drag [child] with a finger, mouse or pen. The child is moved by a
/// translation of [position] from where it sits in layout (the web's CSS transform), so it doesn't
/// change the layout around it.
///
/// [position] with [onPositionChanged] is two-way; leave [position] null and the widget keeps the
/// offset itself. With [handleOnly], only presses on a [UiDragHandle] inside [child] start a drag
/// (the web `uiDragHandle`). There is no keyboard move.
class UiDraggable extends StatefulWidget {
  const UiDraggable({
    super.key,
    required this.child,
    this.position,
    this.onPositionChanged,
    this.enabled = true,
    this.handleOnly = false,
    this.onDragStart,
    this.onDragMove,
    this.onDragEnd,
  });

  final Widget child;
  final Offset? position;
  final ValueChanged<Offset>? onPositionChanged;
  final bool enabled;

  /// Only a [UiDragHandle] inside [child] starts a drag.
  final bool handleOnly;
  final ValueChanged<UiDragEvent>? onDragStart;
  final ValueChanged<UiDragEvent>? onDragMove;
  final ValueChanged<UiDragEvent>? onDragEnd;

  @override
  State<UiDraggable> createState() => _UiDraggableState();
}

class _UiDraggableState extends State<UiDraggable> {
  Offset _own = Offset.zero;
  Offset _startPointer = Offset.zero;
  Offset _startPos = Offset.zero;
  Offset _lastPointer = Offset.zero;
  bool _dragging = false;

  Offset get _position => widget.position ?? _own;

  void _start(DragStartDetails d) {
    if (!widget.enabled) return;
    _dragging = true;
    _startPointer = d.globalPosition;
    _lastPointer = d.globalPosition;
    _startPos = _position;
    widget.onDragStart?.call(UiDragEvent(position: _startPos, pointer: d.globalPosition));
  }

  void _move(DragUpdateDetails d) {
    if (!_dragging) return;
    _lastPointer = d.globalPosition;
    final next = _startPos + (d.globalPosition - _startPointer);
    setState(() => _own = next);
    widget.onPositionChanged?.call(next);
    widget.onDragMove?.call(UiDragEvent(position: next, pointer: d.globalPosition));
  }

  void _end() {
    if (!_dragging) return;
    _dragging = false;
    widget.onDragEnd?.call(UiDragEvent(position: _position, pointer: _lastPointer));
  }

  Widget _detector(Widget child) => MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.grab : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: widget.enabled ? _start : null,
          onPanUpdate: widget.enabled ? _move : null,
          onPanEnd: widget.enabled ? (_) => _end() : null,
          onPanCancel: widget.enabled ? _end : null,
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final content = widget.handleOnly ? _DragScope(state: this, child: widget.child) : _detector(widget.child);
    return Transform.translate(offset: _position, child: content);
  }
}

class _DragScope extends InheritedWidget {
  const _DragScope({required this.state, required super.child});
  final _UiDraggableState state;

  @override
  bool updateShouldNotify(_DragScope oldWidget) => oldWidget.state != state;
}

/// The part of a [UiDraggable] (with `handleOnly: true`) that can be grabbed, e.g. a title bar.
class UiDragHandle extends StatelessWidget {
  const UiDragHandle({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_DragScope>();
    return scope == null ? child : scope.state._detector(child);
  }
}

/// The new size after a resize (the web `UiResizeEvent`).
typedef UiResizeEvent = Size;

/// `uiResizable`: gives [child] a right edge, bottom edge and bottom-right corner to drag, and
/// sizes it from them. [size] with [onResized] is two-way; leave [size] null and the widget keeps
/// the size itself, starting at [initialSize]. Never smaller than [minWidth] x [minHeight].
///
/// The grab zones sit inside the box. On touch screens they widen to a finger's width (24px edges,
/// a 48px corner) without changing how the box looks, and a small grip marks the corner.
class UiResizable extends StatefulWidget {
  const UiResizable({
    super.key,
    required this.child,
    this.size,
    this.initialSize = const Size(160, 90),
    this.onResized,
    this.minWidth = 80,
    this.minHeight = 48,
    this.enabled = true,
  });

  final Widget child;
  final Size? size;
  final Size initialSize;

  /// Every pointer move during a resize.
  final ValueChanged<UiResizeEvent>? onResized;
  final double minWidth;
  final double minHeight;
  final bool enabled;

  @override
  State<UiResizable> createState() => _UiResizableState();
}

class _UiResizableState extends State<UiResizable> {
  late Size _own = widget.initialSize;
  Offset _start = Offset.zero;
  Size _from = Size.zero;

  Size get _size => widget.size ?? _own;

  void _begin(DragStartDetails d) {
    _start = d.globalPosition;
    _from = _size;
  }

  void _update(DragUpdateDetails d, {required bool x, required bool y}) {
    final delta = d.globalPosition - _start;
    final next = Size(
      x ? math.max(widget.minWidth, _from.width + delta.dx) : _from.width,
      y ? math.max(widget.minHeight, _from.height + delta.dy) : _from.height,
    );
    setState(() => _own = next);
    widget.onResized?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final touch = uiTouchPlatform(context);
    final s = _size;
    final edge = touch ? 24.0 : 6.0;
    final corner = touch ? uiMinTouchTarget : 14.0;

    Widget zone(String id, MouseCursor cursor, {required bool x, required bool y}) => MouseRegion(
          cursor: cursor,
          child: GestureDetector(
            key: Key('ui-resize-$id'),
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            dragStartBehavior: DragStartBehavior.down,
            onPanStart: _begin,
            onPanUpdate: (d) => _update(d, x: x, y: y),
          ),
        );

    return SizedBox(
      width: s.width,
      height: s.height,
      child: Stack(fit: StackFit.expand, children: [
        widget.child,
        if (widget.enabled) ...[
          Positioned(top: 0, right: 0, bottom: corner, width: edge, child: zone('e', SystemMouseCursors.resizeLeftRight, x: true, y: false)),
          Positioned(left: 0, right: corner, bottom: 0, height: edge, child: zone('s', SystemMouseCursors.resizeUpDown, x: false, y: true)),
          Positioned(
            right: 0,
            bottom: 0,
            width: corner,
            height: corner,
            child: Stack(fit: StackFit.expand, children: [
              if (touch) Align(alignment: Alignment.bottomRight, child: Padding(padding: const EdgeInsets.all(4), child: CustomPaint(size: const Size(10, 10), painter: _GripPainter(context.ui.textMuted)))),
              zone('se', SystemMouseCursors.resizeUpLeftDownRight, x: true, y: true),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// Two short diagonal strokes in the corner: "this corner drags".
class _GripPainter extends CustomPainter {
  const _GripPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width, size.height * 0.2), Offset(size.width * 0.2, size.height), p);
    canvas.drawLine(Offset(size.width, size.height * 0.6), Offset(size.width * 0.6, size.height), p);
  }

  @override
  bool shouldRepaint(_GripPainter old) => old.color != color;
}
