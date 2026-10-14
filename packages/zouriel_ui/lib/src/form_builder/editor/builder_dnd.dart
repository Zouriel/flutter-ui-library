import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/icon.dart';
import '../engine/definition.dart';
import '../engine/schema.dart';
import 'builder_store.dart';

/// What is being dragged: a new element from the palette, or one already on the canvas.
class FbDragPayload {
  FbDragPayload.add({required this.label, required this.icon, required UiFbElement Function() this._create}) : id = null;
  FbDragPayload.move({required String this.id, required this.label, required this.icon}) : _create = null;

  /// The element being moved; null for a new one.
  final String? id;
  final String label;
  final UiIconData icon;
  final UiFbElement Function()? _create;

  bool get isNew => id == null;
}

/// Where a drop would land, with the line drawn to show it (in the builder's coordinates).
class FbDropState {
  const FbDropState({this.target, this.valid = false, this.line, this.over});
  final UiFbDropTarget? target;
  final bool valid;

  /// A thin rect: horizontal between rows, vertical between side-by-side cards.
  final Rect? line;

  /// The list or page tab (`tab:<id>`) under the finger, for highlighting.
  final String? over;
}

/// Mouse and finger drags (the web `FbDnd`). The canvas registers its lists, cards and page tabs
/// by key; hit-testing finds the innermost list under the pointer, so nested sections just work.
/// The page scrolls while the pointer is near its top or bottom edge.
class FbDnd extends ChangeNotifier {
  FbDnd(this.store);

  final UiFormBuilderController store;

  final Map<String, GlobalKey> _lists = {};
  final Map<String, GlobalKey> _items = {};
  final Map<String, GlobalKey> _tabs = {};

  /// The builder's root box, the coordinate space of [position] and [drop] lines.
  final GlobalKey rootKey = GlobalKey(debugLabel: 'fb root');

  /// The canvas viewport, for scrolling near its edges.
  final GlobalKey viewportKey = GlobalKey(debugLabel: 'fb viewport');
  ScrollController? scroller;

  FbDragPayload? _payload;
  UiFbElement? _element;
  Offset _global = Offset.zero;
  FbDropState? _drop;
  Timer? _ticker;

  /// Read by screen readers after a move.
  String announcement = '';

  FbDragPayload? get payload => _payload;
  FbDropState? get drop => _drop;

  /// Id of the element being moved (dimmed on the canvas).
  String? get movingId => _payload?.id;

  /// Where the ghost goes, in the builder's coordinates.
  Offset get position => _toLocal(_global);

  GlobalKey listKey(String id) => _lists.putIfAbsent(id, () => GlobalKey(debugLabel: 'fb list $id'));
  GlobalKey itemKey(String id) => _items.putIfAbsent(id, () => GlobalKey(debugLabel: 'fb item $id'));
  GlobalKey tabKey(String id) => _tabs.putIfAbsent(id, () => GlobalKey(debugLabel: 'fb tab $id'));

  Offset _toLocal(Offset g) {
    final box = rootKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null || !box.attached ? g : box.globalToLocal(g);
  }

  Rect? _rectOf(GlobalKey k) {
    final box = k.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Starts a drag at [global].
  void begin(FbDragPayload payload, Offset global) {
    _payload = payload;
    _element = payload.isNew ? payload._create!() : store.index[payload.id]?.asElement;
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
    final el = _element;
    _ticker?.cancel();
    _ticker = null;
    _payload = null;
    _element = null;
    _drop = null;
    if (commit && p != null && st?.target != null && st!.valid && el != null) {
      if (p.isNew) {
        store.add(el, st.target);
        announcement = 'Added ${p.label}';
      } else if (store.move(p.id!, st.target!)) {
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

  /// Scrolls the canvas while the pointer is near its top or bottom edge.
  void _autoScroll() {
    final sc = scroller;
    final r = _rectOf(viewportKey);
    if (_payload == null || sc == null || !sc.hasClients || r == null) return;
    const edge = 56.0;
    final y = _global.dy;
    var dy = 0.0;
    if (y < r.top + edge && y > r.top - 40) dy = -((r.top + edge - y) / edge * 14).ceilToDouble();
    if (y > r.bottom - edge && y < r.bottom + 40) dy = ((y - (r.bottom - edge)) / edge * 14).ceilToDouble();
    if (dy == 0) return;
    final pos = sc.position;
    final next = (pos.pixels + dy).clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if (next == pos.pixels) return;
    sc.jumpTo(next);
    // Boxes move with the scroll: hit-test again after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_payload == null) return;
      _hitTest();
      notifyListeners();
    });
  }

  List<UiFbElement> _children(String containerId) {
    final e = store.index[containerId];
    if (e == null) return const [];
    if (e.kind == 'page') return (e.element as UiFbPage).elements;
    return e.asGroup?.elements ?? const [];
  }

  void _hitTest() {
    final el = _element;
    final def = store.def;
    final g = _global;
    if (el == null) {
      _drop = const FbDropState();
      return;
    }
    final movingId = _payload?.id;

    for (final MapEntry(key: pageId, value: k) in _tabs.entries) {
      final r = _rectOf(k);
      if (r == null || !r.contains(g) || !def.pages.any((p) => p.id == pageId)) continue;
      final page = def.pages.firstWhere((p) => p.id == pageId);
      _drop = FbDropState(target: UiFbDropTarget(containerId: pageId, index: page.elements.length), valid: canDrop(def, el, pageId), over: 'tab:$pageId');
      return;
    }

    // The innermost list under the pointer: the smallest one that contains it. Lists inside the
    // element being moved don't count (dropping it into itself means "leave it where it is").
    String? listId;
    Rect? listRect;
    for (final MapEntry(key: id, value: k) in _lists.entries) {
      if (!store.index.containsKey(id)) continue;
      if (movingId != null && isInside(def, id, movingId)) continue;
      final r = _rectOf(k);
      if (r == null || !r.contains(g)) continue;
      if (listRect == null || r.width * r.height < listRect.width * listRect.height) {
        listId = id;
        listRect = r;
      }
    }
    if (listId == null) {
      // Anywhere else on the canvas: the end of the page.
      final vp = _rectOf(viewportKey);
      final pageId = store.page.id;
      final pr = _rectOf(listKey(pageId));
      if (vp != null && vp.contains(g) && pr != null) {
        listId = pageId;
        listRect = pr;
      }
    }
    if (listId == null || listRect == null) {
      _drop = const FbDropState();
      return;
    }

    final items = [
      for (final c in _children(listId))
        ?_rectOf(itemKey(c.id)),
    ];
    final index = fbDropIndex(items, g);
    final line = _toLocalRect(_lineFor(items, index, listRect));
    final valid = canDrop(def, el, listId) && !(movingId != null && isInside(def, listId, movingId));
    _drop = FbDropState(target: UiFbDropTarget(containerId: listId, index: index), valid: valid, line: line, over: listId);
  }

  Rect _toLocalRect(Rect r) {
    final tl = _toLocal(r.topLeft);
    return tl & r.size;
  }

  Rect _lineFor(List<Rect> items, int index, Rect lr) {
    const pad = 6.0, w = 3.0;
    Rect h(double x, double y, double len) => Rect.fromLTWH(x, y - w / 2, len, w);
    Rect v(double x, double y, double len) => Rect.fromLTWH(x - w / 2, y, w, len);
    if (items.isEmpty) return h(lr.left + pad, lr.top + pad, math.max(0, lr.width - pad * 2));
    if (index < items.length) {
      final r = items[index];
      final p = index > 0 ? items[index - 1] : null;
      if (p != null && (p.top - r.top).abs() < 4) return v((p.right + r.left) / 2, r.top, r.height);
      if (r.width < lr.width - 24 && (p == null || p.bottom <= r.top + 2)) return v(r.left - 5, r.top, r.height);
      return h(lr.left, r.top - 5, lr.width);
    }
    final l = items.last;
    if (l.right < lr.right - 24) return v(l.right + 5, l.top, l.height);
    return h(lr.left, l.bottom + 5, lr.width);
  }
}

/// A drag in progress, fed by a multi-drag recognizer.
class _FbDrag implements Drag {
  _FbDrag(this.dnd);
  final FbDnd dnd;
  Offset _at = Offset.zero;

  void start(Offset at) => _at = at;

  @override
  void update(DragUpdateDetails d) {
    _at = d.globalPosition;
    dnd.update(_at);
  }

  @override
  void end(DragEndDetails d) => dnd.end();

  @override
  void cancel() => dnd.end(commit: false);
}

/// Makes [child] a drag source: at once (the grip) or after a hold ([delay], palette items on a
/// touch screen, so a swipe still scrolls).
class FbDragSource extends StatelessWidget {
  const FbDragSource({super.key, required this.dnd, required this.payload, required this.child, this.delay});
  final FbDnd dnd;
  final FbDragPayload Function() payload;
  final Widget child;
  final Duration? delay;

  @override
  Widget build(BuildContext context) {
    Drag? onStart(Offset at) {
      if (dnd.payload != null) return null;
      final d = _FbDrag(dnd)..start(at);
      dnd.begin(payload(), at);
      return d;
    }

    final gestures = <Type, GestureRecognizerFactory>{
      if (delay == null)
        ImmediateMultiDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<ImmediateMultiDragGestureRecognizer>(
          () => ImmediateMultiDragGestureRecognizer(),
          (r) => r.onStart = onStart,
        )
      else
        DelayedMultiDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<DelayedMultiDragGestureRecognizer>(
          () => DelayedMultiDragGestureRecognizer(delay: delay!),
          (r) => r.onStart = onStart,
        ),
    };
    return RawGestureDetector(gestures: gestures, behavior: HitTestBehavior.opaque, child: child);
  }
}

/// Where a drop at [at] goes among a list's cards (in order): before the first card the pointer is
/// above, or over. Over a card that shares its row with others, its left half means "before it";
/// over a card alone on its row (every card on a phone), its top half does. Halving by x there
/// would put a card dragged by its grip, at the left edge, back where it started.
int fbDropIndex(List<Rect> boxes, Offset at) {
  for (var i = 0; i < boxes.length; i++) {
    final r = boxes[i];
    if (at.dy < r.top) return i;
    if (at.dy > r.bottom) continue;
    var shared = false;
    for (var j = 0; j < boxes.length; j++) {
      if (j != i && boxes[j].top < r.bottom - 1 && boxes[j].bottom > r.top + 1) shared = true;
    }
    if (shared ? at.dx < r.left + r.width / 2 : at.dy < r.top + r.height / 2) return i;
  }
  return boxes.length;
}
