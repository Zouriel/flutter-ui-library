import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/icon.dart';
import 'definition.dart';
import 'scope.dart';
import 'store.dart';

/// What is being dragged: a new step from the picker, or a step already on the canvas.
class WfDragPayload {
  const WfDragPayload.add({required String this.type, required this.label, required this.icon}) : id = null;
  const WfDragPayload.move({required String this.id, required this.label, required this.icon}) : type = null;

  /// The step being moved; null for a new one.
  final String? id;

  /// The type of a new step.
  final String? type;
  final String label;
  final UiIconData icon;

  bool get isNew => id == null;
}

/// Where a drop would land, with the line drawn to show it (in the builder's coordinates).
class WfDropState {
  const WfDropState({this.target, this.valid = false, this.line});
  final WfDropTarget? target;
  final bool valid;
  final Rect? line;
}

/// Mouse drags start after this much movement, so clicks stay clicks.
const double _mouseSlop = 4;

/// Touch drags from a card or the picker start after holding this long (scrolling wins otherwise).
const Duration wfLongPress = Duration(milliseconds: 320);

/// Drag and drop of steps (the web `WfDnd`). Step lists register by list id and steps by id;
/// hit-testing picks the innermost list under the pointer, so steps can be dropped into branches
/// and outcomes at any depth. Scrollers scroll while the pointer is near their top or bottom.
class WfDnd extends ChangeNotifier {
  WfDnd(this.store);

  final UiWorkflowBuilderController store;

  final Map<String, GlobalKey> _lists = {};
  final Map<String, GlobalKey> _items = {};
  final Map<GlobalKey, ScrollController> _scrollers = {};

  /// The builder's root box, the coordinate space of [position] and drop lines.
  final GlobalKey rootKey = GlobalKey(debugLabel: 'wf root');

  WfDragPayload? _payload;
  Offset _global = Offset.zero;
  WfDropState? _drop;
  Timer? _ticker;

  /// Read by screen readers after a drop.
  String announcement = '';

  /// Set right after a drag ends, so the tap that follows doesn't also select or add.
  bool _justDropped = false;

  WfDragPayload? get payload => _payload;
  WfDropState? get drop => _drop;
  String? get movingId => _payload?.id;

  /// Where the ghost goes, in the builder's coordinates.
  Offset get position => _toLocal(_global);

  GlobalKey listKey(String id) => _lists.putIfAbsent(id, () => GlobalKey(debugLabel: 'wf list $id'));
  GlobalKey itemKey(String id) => _items.putIfAbsent(id, () => GlobalKey(debugLabel: 'wf item $id'));

  /// Registers a scroll view that should scroll while dragging near its edges.
  void addScroller(GlobalKey viewport, ScrollController controller) => _scrollers[viewport] = controller;
  void removeScroller(GlobalKey viewport) => _scrollers.remove(viewport);

  /// True once, right after a drag ended.
  bool consumeClick() {
    final s = _justDropped;
    _justDropped = false;
    return s;
  }

  Offset _toLocal(Offset g) {
    final box = rootKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null || !box.attached ? g : box.globalToLocal(g);
  }

  Rect? _rectOf(GlobalKey k) {
    final box = k.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void begin(WfDragPayload payload, Offset global) {
    _payload = payload;
    _global = global;
    HapticFeedback.selectionClick();
    _hitTest();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) => _autoScroll());
    notifyListeners();
  }

  void update(Offset global) {
    if (_payload == null) return;
    _global = global;
    _hitTest();
    notifyListeners();
  }

  /// Drops (when [commit] and the place is valid) and ends the drag.
  void end({bool commit = true}) {
    final p = _payload;
    final st = _drop;
    _ticker?.cancel();
    _ticker = null;
    _payload = null;
    _drop = null;
    if (p != null) {
      _justDropped = true;
      scheduleMicrotask(() => _justDropped = false);
    }
    if (commit && p != null && st?.target != null && st!.valid) {
      if (p.isNew) {
        store.addStep(p.type!, st.target!.listId, st.target!.index);
        announcement = 'Added ${p.label}';
      } else if (store.moveStep(p.id!, st.target!.listId, st.target!.index)) {
        announcement = 'Moved ${p.label}';
      }
    } else if (p != null && !commit) {
      announcement = 'Move cancelled';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Scrolls a canvas while the pointer is near its top or bottom edge.
  void _autoScroll() {
    if (_payload == null) return;
    const edge = 56.0;
    final g = _global;
    for (final MapEntry(key: key, value: sc) in _scrollers.entries) {
      final r = _rectOf(key);
      if (r == null || !sc.hasClients || g.dx < r.left || g.dx > r.right) continue;
      final y = g.dy;
      var dy = 0.0;
      if (y < r.top + edge && y > r.top - 40) dy = -((r.top + edge - y) / edge * 14).ceilToDouble();
      if (y > r.bottom - edge && y < r.bottom + 40) dy = ((y - (r.bottom - edge)) / edge * 14).ceilToDouble();
      if (dy == 0) continue;
      final pos = sc.position;
      final next = (pos.pixels + dy).clamp(pos.minScrollExtent, pos.maxScrollExtent);
      if (next == pos.pixels) continue;
      sc.jumpTo(next);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_payload == null) return;
        _hitTest();
        notifyListeners();
      });
      return;
    }
  }

  void _hitTest() {
    final def = store.def;
    final g = _global;
    final movingId = _payload?.id;
    // The innermost list under the pointer: the smallest one that contains it. Lists inside the
    // step being moved don't count (dropping it into itself means "the list it sits in").
    String? listId;
    Rect? listRect;
    for (final MapEntry(key: id, value: k) in _lists.entries) {
      if (movingId != null && isInsideStep(def, id, movingId)) continue;
      final r = _rectOf(k);
      if (r == null || !r.contains(g)) continue;
      if (listRect == null || r.width * r.height < listRect.width * listRect.height) {
        listId = id;
        listRect = r;
      }
    }
    if (listId == null || listRect == null) {
      _drop = const WfDropState();
      return;
    }
    final steps = listSteps(def, listId) ?? const [];
    final boxes = [
      for (final s in steps)
        ?_rectOf(itemKey(s.id)),
    ];
    final index = wfDropIndex([for (final b in boxes) (top: b.top, bottom: b.bottom)], g.dy);
    final lineY = boxes.isEmpty ? listRect.top + 12 : (index < boxes.length ? boxes[index].top - 6 : boxes.last.bottom + 6);
    final line = Rect.fromLTWH(listRect.left + 8, lineY - 1.5, math.max(40, listRect.width - 16), 3);
    final valid = listSteps(def, listId) != null || listId.contains(':');
    final tl = _toLocal(line.topLeft);
    _drop = WfDropState(target: WfDropTarget(listId, index), valid: valid, line: tl & line.size);
  }
}

/// Where a drop at height [y] goes among a list's steps (top to bottom): before the first step
/// whose middle is below it.
int wfDropIndex(List<({double top, double bottom})> boxes, double y) {
  for (var i = 0; i < boxes.length; i++) {
    if (y < (boxes[i].top + boxes[i].bottom) / 2) return i;
  }
  return boxes.length;
}

class _WfDrag implements Drag {
  _WfDrag(this.dnd);
  final WfDnd dnd;

  @override
  void update(DragUpdateDetails d) => dnd.update(d.globalPosition);
  @override
  void end(DragEndDetails d) => dnd.end();
  @override
  void cancel() => dnd.end(commit: false);
}

/// Makes [child] a drag source. [immediate] (a grip) drags at the first movement; otherwise a mouse
/// drags after a small move and a finger after holding still for [wfLongPress], so a swipe still
/// scrolls.
class WfDragSource extends StatelessWidget {
  const WfDragSource({super.key, required this.dnd, required this.payload, required this.child, this.immediate = false, this.enabled = true});
  final WfDnd dnd;
  final WfDragPayload Function() payload;
  final Widget child;
  final bool immediate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    Drag? onStart(Offset at) {
      if (dnd.payload != null) return null;
      dnd.begin(payload(), at);
      return _WfDrag(dnd);
    }

    const mouse = {PointerDeviceKind.mouse, PointerDeviceKind.trackpad};
    const touch = {PointerDeviceKind.touch, PointerDeviceKind.stylus, PointerDeviceKind.invertedStylus, PointerDeviceKind.unknown};
    final gestures = <Type, GestureRecognizerFactory>{
      if (immediate)
        ImmediateMultiDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<ImmediateMultiDragGestureRecognizer>(
          () => ImmediateMultiDragGestureRecognizer(),
          // The grip only drags, so it claims the finger at the first pixel of movement: with the
          // test default slop (18) a scroll view using the phone's own slop (about 8) would win.
          (r) => r
            ..onStart = onStart
            ..gestureSettings = const DeviceGestureSettings(touchSlop: 1),
        )
      else ...{
        ImmediateMultiDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<ImmediateMultiDragGestureRecognizer>(
          () => ImmediateMultiDragGestureRecognizer(supportedDevices: mouse),
          (r) => r
            ..onStart = onStart
            ..gestureSettings = const DeviceGestureSettings(touchSlop: _mouseSlop),
        ),
        DelayedMultiDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<DelayedMultiDragGestureRecognizer>(
          () => DelayedMultiDragGestureRecognizer(delay: wfLongPress, supportedDevices: touch),
          (r) => r
            ..onStart = onStart
            ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context),
        ),
      },
    };
    return RawGestureDetector(gestures: gestures, behavior: HitTestBehavior.translucent, child: child);
  }
}
