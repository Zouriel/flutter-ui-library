import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'drag_coordinator.dart';

/// `uiDropTarget`: receives drops from [UiDragItem] widgets whose payload passes [accepts].
///
/// Highlights with an accent ring while a valid dragged item hovers over it; ignores items for which
/// [accepts] returns false. Calls [onDropped] with the dragged payload on drop.
class UiDropTarget<T extends Object> extends StatefulWidget {
  const UiDropTarget({
    super.key,
    required this.child,
    this.label = '',
    this.accepts,
    this.enabled = true,
    this.onDropped,
    this.onHoverChanged,
  });

  /// Human-readable target name used in screen-reader announcements ("Dropped X on Y").
  final String label;

  /// Predicate deciding whether a dragged payload may be dropped here. Defaults to accepting all [T].
  final bool Function(T payload)? accepts;

  /// Whether this target currently accepts drops.
  final bool enabled;

  /// Called with the dragged payload when a valid item is dropped here.
  final ValueChanged<T>? onDropped;

  /// Called when a valid dragged item enters (`true`) or leaves (`false`) this target.
  final ValueChanged<bool>? onHoverChanged;

  final Widget child;

  @override
  State<UiDropTarget<T>> createState() => _UiDropTargetState<T>();
}

class _UiDropTargetState<T extends Object> extends State<UiDropTarget<T>> implements UiDropTargetHandle {
  UiDragCoordinator? _coordinator;
  bool _isOver = false;
  bool _disposing = false;

  @override
  bool get isMounted => mounted;

  @override
  bool get isEnabled => widget.enabled;

  @override
  String get targetLabel => widget.label.isNotEmpty ? widget.label : 'target';

  @override
  Rect? globalRect() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  bool canAccept(Object payload) {
    if (!widget.enabled || payload is! T) return false;
    final predicate = widget.accepts;
    return predicate == null ? true : predicate(payload);
  }

  @override
  void setOver(bool over) {
    if (_isOver == over) return;
    if (mounted && !_disposing) {
      setState(() => _isOver = over);
    } else {
      _isOver = over;
    }
    widget.onHoverChanged?.call(over);
  }

  @override
  void receiveDrop(Object payload) {
    if (payload is T) {
      widget.onDropped?.call(payload);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = UiDragCoordinator.of(context);
    if (_coordinator != next) {
      _coordinator?.unregisterTarget(this);
      _coordinator = next;
      next.registerTarget(this);
    }
  }

  @override
  void dispose() {
    _disposing = true;
    _coordinator?.unregisterTarget(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final rounded = context.uiTheme.config.radius;
    final radius = BorderRadius.circular(rounded ? t.radius : 0);

    return DecoratedBox(
      decoration: _isOver
          ? BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(color: t.bg, spreadRadius: 2, blurRadius: 0),
                BoxShadow(color: t.accent, spreadRadius: 4, blurRadius: 0),
              ],
            )
          : const BoxDecoration(),
      child: widget.child,
    );
  }
}
