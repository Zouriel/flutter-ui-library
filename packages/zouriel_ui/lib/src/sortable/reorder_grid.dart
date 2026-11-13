import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../theme/theme.dart';

/// One tile of a [UiReorderGrid] (the web `UiReorderGridItem`).
class UiReorderGridItem {
  const UiReorderGridItem({required this.id, required this.src, this.alt});
  final String id;

  /// The picture's address (drawn with [Image.network] unless the grid has a [UiReorderGrid.tileBuilder]).
  final String src;

  /// What the picture shows, for screen readers.
  final String? alt;
}

/// Where the tiles go: how many columns fit [width] with each at least [minTile], and each tile's size.
({int columns, double tile}) uiReorderGridMetrics(double width, double minTile, double gap) {
  final columns = math.max(1, ((width + gap) / (minTile + gap)).floor());
  return (columns: columns, tile: (width - gap * (columns - 1)) / columns);
}

/// `ui-reorder-grid`: square photo tiles the user puts in order by dragging. Made for the photos of
/// a collection.
///
/// On touch a long press picks a tile up (so a swipe still scrolls the page), then it follows the
/// finger and the others make room; letting go drops it. The page scrolls when the tile is held near
/// its top or bottom edge. With the keyboard, focus a tile and use the arrows (left/right one place,
/// up/down one row); screen readers get "Move earlier" / "Move later". A plain tap calls
/// [onTileTap] (for a menu such as Make cover / Remove). [onRemove] adds a small remove button to
/// every tile, and [coverId]'s tile carries a star. [onReorder] gets the whole new order of ids.
class UiReorderGrid extends StatefulWidget {
  const UiReorderGrid({
    super.key,
    required this.items,
    required this.onReorder,
    this.onTileTap,
    this.onRemove,
    this.coverId,
    this.minTile = 96,
    this.label = 'Photos',
    this.moveLabel = 'Hold and drag to move',
    this.removeLabel = 'Remove',
    this.coverLabel = 'Cover',
    this.tileBuilder,
  });

  final List<UiReorderGridItem> items;
  final ValueChanged<List<String>> onReorder;
  final ValueChanged<String>? onTileTap;
  final ValueChanged<String>? onRemove;
  final String? coverId;

  /// The smallest a tile may be; the columns fill the width.
  final double minTile;
  final String label, moveLabel, removeLabel, coverLabel;

  /// Draws a tile's picture (an app's own cached image); defaults to [Image.network].
  final Widget Function(BuildContext context, UiReorderGridItem item)? tileBuilder;

  @override
  State<UiReorderGrid> createState() => _UiReorderGridState();
}

class _UiReorderGridState extends State<UiReorderGrid> {
  late List<String> _order = _ids;
  final _nodes = <String, FocusNode>{};

  // The drag in progress.
  String? _dragId;
  int _dragFrom = -1;
  Offset _grab = Offset.zero; // finger position inside the tile when it was picked up
  Offset _finger = Offset.zero; // finger position in this widget
  Offset _lastGlobal = Offset.zero;
  EdgeDraggingAutoScroller? _scroller;
  ({int columns, double tile}) _m = (columns: 1, tile: 96);

  List<String> get _ids => [for (final i in widget.items) i.id];

  @override
  void didUpdateWidget(UiReorderGrid old) {
    super.didUpdateWidget(old);
    if (_dragId == null) _order = _ids;
    final live = _ids.toSet();
    _nodes.removeWhere((id, n) {
      if (live.contains(id)) return false;
      n.dispose();
      return true;
    });
  }

  @override
  void dispose() {
    _scroller?.stopAutoScroll();
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  FocusNode _node(String id) => _nodes.putIfAbsent(id, () => FocusNode(debugLabel: 'reorder tile $id'));

  UiReorderGridItem _item(String id) => widget.items.firstWhere((i) => i.id == id);

  double get _gap => context.ui.space2;

  Offset _slot(int index) {
    final step = _m.tile + _gap;
    return Offset((index % _m.columns) * step, (index ~/ _m.columns) * step);
  }

  int _indexAt(Offset center) {
    final step = _m.tile + _gap;
    final rows = (_order.length / _m.columns).ceil();
    final col = (center.dx / step).floor().clamp(0, _m.columns - 1);
    final row = (center.dy / step).floor().clamp(0, math.max(0, rows - 1));
    return (row * _m.columns + col).clamp(0, _order.length - 1).toInt();
  }

  void _announce(String id, List<String> order) {
    final view = View.maybeOf(context);
    final label = _item(id).alt ?? 'Photo';
    if (view != null) unawaited(SemanticsService.sendAnnouncement(view, '$label moved to place ${order.indexOf(id) + 1} of ${order.length}', Directionality.of(context)));
  }

  void _commit(String id) {
    final before = _ids;
    var changed = before.length != _order.length;
    for (var i = 0; !changed && i < before.length; i++) {
      changed = before[i] != _order[i];
    }
    if (changed) {
      widget.onReorder(List.of(_order));
      _announce(id, _order);
    }
  }

  // ---- dragging -------------------------------------------------------------------------------

  void _start(String id, LongPressStartDetails d) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final index = _order.indexOf(id);
    final local = box.globalToLocal(d.globalPosition);
    HapticFeedback.selectionClick();
    final scrollable = Scrollable.maybeOf(context);
    _scroller?.stopAutoScroll();
    _scroller = scrollable == null ? null : EdgeDraggingAutoScroller(scrollable, onScrollViewScrolled: _onScrolled, velocityScalar: 20);
    setState(() {
      _dragId = id;
      _dragFrom = index;
      _grab = local - _slot(index);
      _finger = local;
      _lastGlobal = d.globalPosition;
    });
  }

  void _onScrolled() {
    if (_dragId == null || !mounted) return;
    _follow(_lastGlobal);
    _scroller?.startAutoScrollIfNecessary(_dragRect());
  }

  Rect _dragRect() {
    final box = context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(_finger - _grab);
    return topLeft & Size.square(_m.tile);
  }

  void _follow(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    final id = _dragId;
    if (box == null || id == null) return;
    _lastGlobal = global;
    final local = box.globalToLocal(global);
    final center = local - _grab + Offset(_m.tile / 2, _m.tile / 2);
    final to = _indexAt(center);
    setState(() {
      _finger = local;
      if (_order.indexOf(id) != to) {
        _order = List.of(_order)
          ..remove(id)
          ..insert(to, id);
      }
    });
  }

  void _move(LongPressMoveUpdateDetails d) {
    if (_dragId == null) return;
    _follow(d.globalPosition);
    _scroller?.startAutoScrollIfNecessary(_dragRect());
  }

  void _end() {
    final id = _dragId;
    _scroller?.stopAutoScroll();
    if (id == null) return;
    setState(() => _dragId = null);
    if (_order.indexOf(id) != _dragFrom) _commit(id);
  }

  // ---- keyboard ---------------------------------------------------------------------------------

  void _step(String id, int by) {
    final from = _order.indexOf(id);
    final to = (from + by).clamp(0, _order.length - 1);
    if (to == from) return;
    setState(() {
      _order = List.of(_order)
        ..removeAt(from)
        ..insert(to, id);
    });
    _commit(id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _node(id).requestFocus();
    });
  }

  KeyEventResult _key(String id, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final k = e.logicalKey;
    final by = k == LogicalKeyboardKey.arrowLeft
        ? (rtl ? 1 : -1)
        : k == LogicalKeyboardKey.arrowRight
            ? (rtl ? -1 : 1)
            : k == LogicalKeyboardKey.arrowUp
                ? -_m.columns
                : k == LogicalKeyboardKey.arrowDown
                    ? _m.columns
                    : 0;
    if (by == 0) return KeyEventResult.ignored;
    _step(id, by);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Semantics(
      container: true,
      label: widget.label,
      child: LayoutBuilder(builder: (context, c) {
        _m = uiReorderGridMetrics(c.maxWidth, widget.minTile, t.space2);
        final rows = (_order.length / _m.columns).ceil();
        final height = rows == 0 ? 0.0 : rows * _m.tile + (rows - 1) * t.space2;
        final dragging = _dragId;
        // The held tile is painted last (on top). Keys keep every tile's State, so the long press that
        // started the drag lives on while its tile moves to the end of the list.
        final ordered = [for (final id in _order) if (id != dragging) id, ?dragging];
        return SizedBox(
          width: c.maxWidth,
          height: height,
          child: Stack(clipBehavior: Clip.none, children: [
            for (final id in ordered) _positioned(id, dragging == id),
          ]),
        );
      }),
    );
  }

  Widget _positioned(String id, bool held) {
    final t = context.ui;
    final at = held ? _finger - _grab : _slot(_order.indexOf(id));
    final index = _order.indexOf(id);
    final item = _item(id);
    return AnimatedPositioned(
      key: ValueKey(id),
      left: at.dx,
      top: at.dy,
      width: _m.tile,
      height: _m.tile,
      duration: held || !context.uiAnimate ? Duration.zero : t.motionBase,
      curve: t.easeStandard,
      child: GestureDetector(
        onLongPressStart: (d) => _start(id, d),
        onLongPressMoveUpdate: _move,
        onLongPressEnd: (_) => _end(),
        onLongPressCancel: _end,
        child: Semantics(
          customSemanticsActions: {
            if (index > 0) const CustomSemanticsAction(label: 'Move earlier'): () => _step(id, -1),
            if (index < _order.length - 1) const CustomSemanticsAction(label: 'Move later'): () => _step(id, 1),
          },
          child: _Tile(
            item: item,
            index: index,
            count: _order.length,
            held: held,
            cover: widget.coverId == id,
            focusNode: _node(id),
            owner: widget,
            onKey: (e) => _key(id, e),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item, required this.index, required this.count, required this.held, required this.cover, required this.focusNode, required this.owner, required this.onKey});
  final UiReorderGridItem item;
  final int index, count;
  final bool held, cover;
  final FocusNode focusNode;
  final UiReorderGrid owner;
  final KeyEventResult Function(KeyEvent) onKey;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final rounded = context.uiTheme.config.radius;
    final r = BorderRadius.circular(rounded ? t.radiusSm : 0);
    final name = item.alt ?? 'Photo ${index + 1} of $count';
    final picture = owner.tileBuilder?.call(context, item) ??
        Image.network(item.src, fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: t.surfaceSubtle));
    // Arrow keys reach this from the tile's own focus (inside UiInteractive) as they bubble up.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, e) => onKey(e),
      child: AnimatedScale(
        scale: held ? 1.06 : 1,
        duration: context.uiAnimate ? t.motionFast : Duration.zero,
        child: Stack(fit: StackFit.expand, children: [
          UiInteractive(
            focusNode: focusNode,
            semanticLabel: cover ? '$name, ${owner.coverLabel}' : name,
            semanticHint: owner.moveLabel,
            padTouchTarget: false,
            pressScale: false,
            onTap: owner.onTileTap == null ? null : () => owner.onTileTap!(item.id),
            builder: (context, s) => Container(
              decoration: BoxDecoration(
                borderRadius: r,
                color: t.surfaceSubtle,
                boxShadow: [if (held) ...t.shadow3, if (s.focused) ...t.focusRing],
              ),
              foregroundDecoration: s.hovered && !held ? BoxDecoration(borderRadius: r, color: t.mediaScrim.withValues(alpha: 0.15)) : null,
              child: ClipRRect(borderRadius: r, child: picture),
            ),
          ),
          if (cover)
            PositionedDirectional(
              top: t.space1,
              start: t.space1,
              child: ExcludeSemantics(
                child: Container(
                  padding: EdgeInsets.all(t.space1),
                  decoration: BoxDecoration(color: t.mediaScrim, shape: BoxShape.circle),
                  child: IconTheme.merge(data: IconThemeData(size: 14, color: t.mediaOnScrim), child: const UiIcon(HugeIcons.strokeRoundedStar)),
                ),
              ),
            ),
          if (owner.onRemove != null && !held)
            PositionedDirectional(
              top: 0,
              end: 0,
              child: UiInteractive(
                semanticLabel: '${owner.removeLabel} ${item.alt ?? 'photo ${index + 1}'}',
                minTouchSize: const Size(40, 40),
                onTap: () => owner.onRemove!(item.id),
                builder: (context, s) => Padding(
                  padding: EdgeInsets.all(t.space1),
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.hovered || s.pressed ? t.danger : t.mediaScrim,
                      shape: BoxShape.circle,
                      boxShadow: s.focused ? t.focusRing : null,
                    ),
                    child: IconTheme.merge(data: IconThemeData(size: 14, color: t.mediaOnScrim), child: const UiIcon(HugeIcons.strokeRoundedCancel01)),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
