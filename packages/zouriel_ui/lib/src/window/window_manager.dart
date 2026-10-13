import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Where a window docks: a half of the viewport, or all of it (the web `UiDockSide`; the web's
/// `null`, which restores, is `null` here too).
enum UiDockSide { left, right, top, bottom, maximize }

/// A window's imperative surface, registered with [UiWindowManager] for coordination. Bounds are
/// a [Rect] in the window's viewport (the web `UiWindowBounds` `{ x, y, width, height }`).
abstract interface class UiWindowHandle {
  String get id;
  void minimize();
  void restore();

  /// Docks to [side]; `null` restores.
  void dock(UiDockSide? side);

  /// Brings the window to the front.
  void focus();
  void setBounds(Rect bounds);

  /// The area the window lives in (its overlay), once laid out.
  Size? get viewport;
}

/// The bounds a window takes when docked to [side] in a [viewport] (the web `dockBounds`).
Rect uiDockBounds(UiDockSide side, Size viewport) {
  final vw = viewport.width, vh = viewport.height;
  final half = (vw / 2).floorToDouble(), halfH = (vh / 2).floorToDouble();
  return switch (side) {
    UiDockSide.left => Rect.fromLTWH(0, 0, half, vh),
    UiDockSide.right => Rect.fromLTWH((vw / 2).ceilToDouble(), 0, half, vh),
    UiDockSide.top => Rect.fromLTWH(0, 0, vw, halfH),
    UiDockSide.bottom => Rect.fromLTWH(0, (vh / 2).ceilToDouble(), vw, halfH),
    UiDockSide.maximize => Rect.fromLTWH(0, 0, vw, vh),
  };
}

/// `UiWindowManager`: tracks open windows, which is in front, and the stacking order, and runs bulk
/// operations (minimize all, restore all, tile). Every open [UiWindow] registers itself.
///
/// Windows use the manager from the nearest [UiWindowScope], or [instance] when there is none.
class UiWindowManager extends ChangeNotifier {
  UiWindowManager();

  /// The shared manager windows use outside any [UiWindowScope] (the web's root injectable).
  static final UiWindowManager instance = UiWindowManager();

  final Map<String, UiWindowHandle> _registry = {};
  final List<String> _order = [];
  int _seq = 0;
  String? _focusedId;

  /// The front-most window, or null.
  String? get focusedId => _focusedId;

  /// How many windows are open.
  int get count => _registry.length;

  /// Open window ids from back to front.
  List<String> get order => List.unmodifiable(_order);

  /// The handle registered under [id].
  UiWindowHandle? handle(String id) => _registry[id];

  String nextId() => 'ui-window-${_seq++}';

  void register(UiWindowHandle handle) {
    _registry[handle.id] = handle;
    _order
      ..remove(handle.id)
      ..add(handle.id);
    _focusedId = handle.id;
    _notify();
  }

  void unregister(String id) {
    if (_registry.remove(id) == null) return;
    _order.remove(id);
    if (_focusedId == id) _focusedId = _order.isEmpty ? null : _order.last;
    _notify();
  }

  /// Moves [id] to the front of the stacking order and marks it focused. Returns its stacking
  /// position (higher is nearer the front).
  int bringToFront(String id) {
    if (_order.isNotEmpty && _order.last == id && _focusedId == id) return _order.length - 1;
    _order
      ..remove(id)
      ..add(id);
    _focusedId = id;
    _notify();
    return _order.length - 1;
  }

  void focus(String id) => _registry[id]?.focus();

  void dock(String id, UiDockSide? side) => _registry[id]?.dock(side);

  void minimizeAll() {
    for (final h in [..._registry.values]) {
      h.minimize();
    }
  }

  void restoreAll() {
    for (final h in [..._registry.values]) {
      h.restore();
    }
  }

  /// Arranges every open window in a grid covering [viewport] (by default the viewport of the
  /// first window).
  void tile([Size? viewport]) {
    final handles = [..._registry.values];
    if (handles.isEmpty) return;
    final area = viewport ?? handles.map((h) => h.viewport).whereType<Size>().firstOrNull;
    if (area == null) return;
    final n = handles.length;
    var cols = 1;
    while (cols * cols < n) {
      cols++;
    }
    final rows = (n / cols).ceil();
    final w = (area.width / cols).floorToDouble();
    final h = (area.height / rows).floorToDouble();
    for (var i = 0; i < n; i++) {
      handles[i].setBounds(Rect.fromLTWH((i % cols) * w, (i ~/ cols) * h, w, h));
    }
  }

  // Windows register while they build; tell listeners after the frame rather than mid-build.
  void _notify() {
    if (_disposed) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    // Windows closing as their page goes away still unregister after this.
    _disposed = true;
    super.dispose();
  }
}

/// Provides a [UiWindowManager] to the windows below it (and rebuilds dependants when it changes),
/// so an app or a test can keep its own set of windows.
class UiWindowScope extends InheritedNotifier<UiWindowManager> {
  const UiWindowScope({super.key, required UiWindowManager manager, required super.child}) : super(notifier: manager);

  /// The nearest manager, or [UiWindowManager.instance]. Rebuilds [context] when it changes.
  static UiWindowManager of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UiWindowScope>()?.notifier ?? UiWindowManager.instance;

  /// The nearest manager without listening to it.
  static UiWindowManager read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<UiWindowScope>()?.notifier ?? UiWindowManager.instance;
}
