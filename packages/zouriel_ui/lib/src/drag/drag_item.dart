import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'drag_coordinator.dart';

/// `uiDragItem`: makes [child] draggable with a typed [data] payload onto any matching
/// [UiDropTarget].
///
/// - Mouse / trackpad / stylus: drags after a small movement so clicks still work.
/// - Touch: waits for a long press ([uiLongPressDuration]) before dragging, so swiping a
///   [Scrollable] scrolls the list instead of starting a drag.
/// - Keyboard: focus the item and press Space or Enter to pick it up, Arrow keys to choose a valid
///   target, Enter or Space to drop, and Escape to cancel.
class UiDragItem<T extends Object> extends StatefulWidget {
  const UiDragItem({
    super.key,
    required this.data,
    required this.child,
    this.label = '',
    this.enabled = true,
    this.description = 'Long press and drag to drop onto a target, or press Space or Enter to pick up with keyboard.',
    this.feedbackBuilder,
    this.onDragStart,
    this.onDragCancel,
    this.onDragEnd,
    this.focusNode,
    this.focusable = true,
  });

  /// Payload carried to the receiving [UiDropTarget].
  final T data;

  /// Human-readable name announced by screen readers ("Dropped X on Y").
  final String label;

  /// Whether dragging is enabled.
  final bool enabled;

  /// Semantic hint describing how to drag or pick up this item.
  final String description;

  /// Optional custom widget for the floating drag ghost; defaults to [child].
  final Widget Function(BuildContext context, T data)? feedbackBuilder;

  /// Called when a pointer or keyboard drag begins.
  final ValueChanged<T>? onDragStart;

  /// Called when a drag is cancelled (Escape, pointer cancel, or off-target drop).
  final ValueChanged<T>? onDragCancel;

  /// Called when a drag ends (whether dropped or cancelled).
  final ValueChanged<T>? onDragEnd;

  /// Optional focus node for keyboard drag support.
  final FocusNode? focusNode;

  /// Whether the item takes keyboard focus itself. Turn it off when [child] is already a focus stop
  /// (a tile, a button): key presses it leaves unhandled still reach this item, so Space or Enter
  /// can pick it up without a second tab stop.
  final bool focusable;

  final Widget child;

  @override
  State<UiDragItem<T>> createState() => _UiDragItemState<T>();
}

class _UiDragItemState<T extends Object> extends State<UiDragItem<T>> implements UiDragItemHandle {
  FocusNode? _ownFocus;
  bool _dragging = false;
  bool _disposing = false;
  UiDragCoordinator? _coordinator;

  FocusNode get _focusNode => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'UiDragItem'));

  @override
  Object get payload => widget.data;

  @override
  String get itemLabel => widget.label.isNotEmpty ? widget.label : 'item';

  @override
  void setDragging(bool dragging) {
    if (_dragging == dragging) return;
    if (mounted && !_disposing) {
      setState(() => _dragging = dragging);
    } else {
      _dragging = dragging;
    }
  }

  @override
  void notifyStart() => widget.onDragStart?.call(widget.data);

  @override
  void notifyCancel() => widget.onDragCancel?.call(widget.data);

  @override
  void notifyEnd() => widget.onDragEnd?.call(widget.data);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _coordinator = UiDragCoordinator.of(context);
  }

  @override
  void dispose() {
    _disposing = true;
    if (_dragging) {
      _coordinator?.cancel();
    }
    _ownFocus?.dispose();
    super.dispose();
  }

  void _startAt(Offset globalPosition, {required bool haptic}) {
    if (!widget.enabled) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if (haptic) HapticFeedback.selectionClick();
    final grabOffset = box.globalToLocal(globalPosition);
    final size = box.size;
    final coordinator = UiDragCoordinator.of(context);
    _coordinator = coordinator;
    coordinator.startPointerDrag(
      context: context,
      source: this,
      globalPosition: globalPosition,
      grabOffset: grabOffset,
      itemSize: size,
      ghostBuilder: (ctx) => widget.feedbackBuilder?.call(ctx, widget.data) ?? widget.child,
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final coordinator = UiDragCoordinator.of(context);
    if (coordinator.isKeyboardActive) {
      return coordinator.handleKeyboardKey(event) ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (coordinator.isActive) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.enter) {
      _coordinator = coordinator;
      coordinator.startKeyboardDrag(context: context, source: this);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    final gestures = <Type, GestureRecognizerFactory>{
      if (widget.enabled) ...{
        LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
            duration: uiLongPressDuration,
            supportedDevices: const {PointerDeviceKind.touch},
          ),
          (LongPressGestureRecognizer r) {
            r.gestureSettings = gestureSettings;
            r.onLongPressStart = (d) => _startAt(d.globalPosition, haptic: true);
            r.onLongPressMoveUpdate = (d) => _coordinator?.updatePointerDrag(d.globalPosition);
            r.onLongPressEnd = (_) => _coordinator?.commit();
            r.onLongPressCancel = () => _coordinator?.cancel();
          },
        ),
        PanGestureRecognizer: GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
          () => PanGestureRecognizer(
            supportedDevices: const {
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
              PointerDeviceKind.invertedStylus,
            },
          ),
          (PanGestureRecognizer r) {
            r.gestureSettings = gestureSettings;
            r.onStart = (d) => _startAt(d.globalPosition, haptic: false);
            r.onUpdate = (d) => _coordinator?.updatePointerDrag(d.globalPosition);
            r.onEnd = (_) => _coordinator?.commit();
            r.onCancel = () => _coordinator?.cancel();
          },
        ),
      },
    };

    return Semantics(
      label: widget.label.isNotEmpty ? widget.label : null,
      hint: widget.enabled ? widget.description : null,
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: widget.enabled && widget.focusable,
        onKeyEvent: _onKeyEvent,
        child: RawGestureDetector(
          gestures: gestures,
          child: Opacity(
            opacity: _dragging ? 0.4 : 1.0,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
