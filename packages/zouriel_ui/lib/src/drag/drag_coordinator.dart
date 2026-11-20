import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// How long a touch finger must stay still before a drag begins (matches Angular `UI_LONG_PRESS_MS`).
const Duration uiLongPressDuration = Duration(milliseconds: 500);

/// Distance in logical pixels a mouse pointer moves before a drag starts.
const double uiDragMouseSlop = 6.0;

/// Internal handle implemented by `UiDragItem` state.
abstract class UiDragItemHandle {
  Object get payload;
  String get itemLabel;
  void setDragging(bool dragging);
  void notifyStart();
  void notifyCancel();
  void notifyEnd();
}

/// Internal handle implemented by `UiDropTarget` state.
abstract class UiDropTargetHandle {
  bool get isMounted;
  bool get isEnabled;
  String get targetLabel;
  Rect? globalRect();
  bool canAccept(Object payload);
  void setOver(bool over);
  void receiveDrop(Object payload);
}

/// Coordinates drag-and-drop sessions between [UiDragItem] and [UiDropTarget] widgets inside an
/// [Overlay]. Manages the floating ghost, edge auto-scrolling, keyboard target selection, Escape
/// cancellation, and screen-reader announcements.
class UiDragCoordinator extends ChangeNotifier {
  static final Expando<UiDragCoordinator> _byOverlay = Expando<UiDragCoordinator>('UiDragCoordinator');

  /// Returns the coordinator bound to the root [Overlay] of [context].
  static UiDragCoordinator of(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);
    return _byOverlay[overlay] ??= UiDragCoordinator._(overlay);
  }

  UiDragCoordinator._(this._overlay);

  final OverlayState _overlay;
  final Set<UiDropTargetHandle> _targets = <UiDropTargetHandle>{};

  UiDragItemHandle? _source;
  Object? _payload;
  String _label = '';
  bool _keyboard = false;
  UiDropTargetHandle? _hovered;
  Offset _globalPosition = Offset.zero;
  Offset _grabOffset = Offset.zero;
  Size _itemSize = Size.zero;
  WidgetBuilder? _ghostBuilder;
  OverlayEntry? _ghostEntry;
  EdgeDraggingAutoScroller? _scroller;
  bool _keyHandlerAttached = false;
  int _keyboardIndex = -1;
  BuildContext? _announceContext;
  String _lastAnnouncement = '';

  /// Whether a drag session is currently active.
  bool get isActive => _source != null;

  /// Whether a keyboard drag session is currently active.
  bool get isKeyboardActive => _source != null && _keyboard;

  /// The active drag payload, or null when idle.
  Object? get activePayload => _payload;

  /// The currently hovered valid drop target, or null.
  UiDropTargetHandle? get hoveredTarget => _hovered;

  /// The most recent accessibility announcement.
  String get lastAnnouncement => _lastAnnouncement;

  void registerTarget(UiDropTargetHandle target) {
    _targets.add(target);
  }

  void unregisterTarget(UiDropTargetHandle target) {
    _targets.remove(target);
    if (_hovered == target) {
      target.setOver(false);
      _hovered = null;
      notifyListeners();
    }
  }

  /// All currently mounted, enabled targets that accept [payload].
  List<UiDropTargetHandle> validTargetsFor(Object payload) {
    return [
      for (final t in _targets)
        if (t.isMounted && t.isEnabled && t.canAccept(payload)) t,
    ];
  }

  /// Starts a pointer drag (mouse after movement, or touch after long press).
  void startPointerDrag({
    required BuildContext context,
    required UiDragItemHandle source,
    required Offset globalPosition,
    required Offset grabOffset,
    required Size itemSize,
    required WidgetBuilder ghostBuilder,
  }) {
    if (_source != null) cancel();
    _source = source;
    _payload = source.payload;
    _label = source.itemLabel;
    _keyboard = false;
    _globalPosition = globalPosition;
    _grabOffset = grabOffset;
    _itemSize = itemSize;
    _ghostBuilder = ghostBuilder;
    _announceContext = context;

    source.setDragging(true);
    _attachKeyHandler();
    final scrollable = Scrollable.maybeOf(context);
    _scroller?.stopAutoScroll();
    _scroller = scrollable == null
        ? null
        : EdgeDraggingAutoScroller(scrollable, onScrollViewScrolled: _onScrolled, velocityScalar: 20);

    _insertGhost();
    _updateHoverAt(globalPosition);
    source.notifyStart();
    notifyListeners();
  }

  /// Updates pointer position during an active pointer drag.
  void updatePointerDrag(Offset globalPosition) {
    if (_source == null || _keyboard) return;
    _globalPosition = globalPosition;
    _ghostEntry?.markNeedsBuild();
    _updateHoverAt(globalPosition);
    _scroller?.startAutoScrollIfNecessary(_dragRect());
  }

  /// Starts a keyboard drag from a focused [UiDragItem].
  bool startKeyboardDrag({
    required BuildContext context,
    required UiDragItemHandle source,
  }) {
    if (_source != null) cancel();
    _announceContext = context;
    final payload = source.payload;
    final label = source.itemLabel;
    final valid = validTargetsFor(payload);
    if (valid.isEmpty) {
      _announce('No valid drop targets for $label.');
      return false;
    }

    _source = source;
    _payload = payload;
    _label = label;
    _keyboard = true;
    _keyboardIndex = 0;

    source.setDragging(true);
    _attachKeyHandler();
    _setHovered(valid.first, announceChange: false);
    source.notifyStart();
    final targetLabel = valid.first.targetLabel;
    _announce(
      'Picked up $label. ${valid.length} drop ${valid.length == 1 ? 'target' : 'targets'} available. '
      'Over $targetLabel. Use arrow keys to choose a target, Enter or Space to drop, Escape to cancel.',
    );
    notifyListeners();
    return true;
  }

  /// Commits the active drag onto the currently hovered valid target, or cancels if none.
  void commit() {
    final source = _source;
    final payload = _payload;
    final label = _label;
    final target = _hovered;
    if (source == null || payload == null) return;

    _teardown();
    if (target != null && target.isMounted && target.isEnabled && target.canAccept(payload)) {
      target.receiveDrop(payload);
      _announce('Dropped $label on ${target.targetLabel}');
      source.notifyEnd();
    } else {
      source.notifyCancel();
      source.notifyEnd();
      _announce('Cancelled dragging $label');
    }
    notifyListeners();
  }

  /// Cancels the active drag without dropping.
  void cancel() {
    final source = _source;
    final label = _label;
    if (source == null) return;

    _teardown();
    source.notifyCancel();
    source.notifyEnd();
    _announce('Cancelled dragging $label');
    notifyListeners();
  }

  void _onScrolled() {
    if (_source == null || _keyboard) return;
    _updateHoverAt(_globalPosition);
    _scroller?.startAutoScrollIfNecessary(_dragRect());
  }

  Rect _dragRect() => (_globalPosition - _grabOffset) & _itemSize;

  void _updateHoverAt(Offset global) {
    final payload = _payload;
    if (payload == null) return;
    UiDropTargetHandle? best;
    var bestArea = double.infinity;
    for (final target in _targets) {
      if (!target.isMounted || !target.isEnabled || !target.canAccept(payload)) continue;
      final rect = target.globalRect();
      if (rect == null || rect.isEmpty) continue;
      if (rect.contains(global)) {
        final area = rect.width * rect.height;
        if (area <= bestArea) {
          bestArea = area;
          best = target;
        }
      }
    }
    _setHovered(best, announceChange: true);
  }

  void _setHovered(UiDropTargetHandle? target, {required bool announceChange}) {
    if (_hovered == target) return;
    _hovered?.setOver(false);
    _hovered = target;
    target?.setOver(true);
    if (announceChange && target != null) {
      _announce('Over ${target.targetLabel}');
    }
    notifyListeners();
  }

  void _insertGhost() {
    _ghostEntry?.remove();
    _ghostEntry = OverlayEntry(
      builder: (context) {
        final builder = _ghostBuilder;
        if (builder == null) return const SizedBox.shrink();
        final topLeft = _globalPosition - _grabOffset;
        return Positioned(
          left: topLeft.dx,
          top: topLeft.dy,
          width: _itemSize.width,
          height: _itemSize.height,
          child: IgnorePointer(
            child: _DragGhost(
              key: const ValueKey('ui-drag-ghost'),
              child: builder(context),
            ),
          ),
        );
      },
    );
    _overlay.insert(_ghostEntry!);
  }

  /// Handles a key event during keyboard drag mode. Returns true if consumed.
  bool handleKeyboardKey(KeyEvent event) {
    if (_source == null || !_keyboard) return false;
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      cancel();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowRight) {
      _stepKeyboardTarget(1);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowLeft) {
      _stepKeyboardTarget(-1);
      return true;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      commit();
      return true;
    }
    return false;
  }

  bool _onHardwareKey(KeyEvent event) {
    if (_source == null || _keyboard) return false;
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      cancel();
      return true;
    }
    return false;
  }

  void _stepKeyboardTarget(int delta) {
    final payload = _payload;
    if (payload == null) return;
    final valid = validTargetsFor(payload);
    if (valid.isEmpty) {
      cancel();
      return;
    }
    _keyboardIndex = (_keyboardIndex + delta) % valid.length;
    if (_keyboardIndex < 0) _keyboardIndex += valid.length;
    _setHovered(valid[_keyboardIndex], announceChange: true);
  }

  void _attachKeyHandler() {
    if (_keyHandlerAttached) return;
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    _keyHandlerAttached = true;
  }

  void _detachKeyHandler() {
    if (!_keyHandlerAttached) return;
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _keyHandlerAttached = false;
  }

  void _announce(String message) {
    _lastAnnouncement = message;
    final ctx = _announceContext;
    if (ctx == null || !ctx.mounted) return;
    final view = View.maybeOf(ctx);
    if (view != null) {
      unawaited(SemanticsService.sendAnnouncement(view, message, Directionality.of(ctx)));
    }
  }

  void _teardown() {
    _scroller?.stopAutoScroll();
    _scroller = null;
    _detachKeyHandler();
    _ghostEntry?.remove();
    _ghostEntry = null;
    _ghostBuilder = null;
    _hovered?.setOver(false);
    _hovered = null;
    _source?.setDragging(false);
    _source = null;
    _payload = null;
    _label = '';
    _keyboard = false;
    _keyboardIndex = -1;
  }
}

/// Lifted copy of the dragged item shown in the overlay while dragging.
class _DragGhost extends StatelessWidget {
  const _DragGhost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final rounded = context.uiTheme.config.radius;
    final animate = context.uiAnimate;
    final radius = BorderRadius.circular(rounded ? t.radius : 0);

    final lifted = Opacity(
      opacity: 0.96,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: t.shadow2),
        child: ClipRRect(borderRadius: radius, child: child),
      ),
    );

    if (!animate) {
      return Transform.scale(scale: 1.0, child: lifted);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: 1.04),
      duration: t.motionFast,
      curve: t.easeDecelerate,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: lifted,
    );
  }
}
