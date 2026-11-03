import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../behaviors/pinch.dart';
import '../theme/theme.dart';

/// Where each item of a masonry grid goes: `ui-masonry-grid`'s `uiMasonryLayout`, the same numbers
/// in both libraries.
///
/// Columns are `(width - gap * (columns - 1)) / columns` wide. Items are dealt in order, each to the
/// shortest column so far (the leftmost on a tie; heights within 0.001 count as equal), and are
/// `columnWidth * ratio` high, with [gap] between items in a column. [columns] is clamped to at
/// least 1. The grid's height is [uiMasonryHeight] of the result.
List<Rect> uiMasonryLayout(double width, List<double> ratios, int columns, double gap) {
  final cols = math.max(1, columns);
  final w = math.max(0.0, (width - gap * (cols - 1)) / cols);
  final heights = List<double>.filled(cols, 0);
  final counts = List<int>.filled(cols, 0);
  final out = <Rect>[];
  for (final ratio in ratios) {
    var shortest = 0;
    for (var c = 1; c < cols; c++) {
      if (heights[c] < heights[shortest] - 0.001) shortest = c;
    }
    final top = heights[shortest] + (counts[shortest] > 0 ? gap : 0);
    final h = w * ratio;
    out.add(Rect.fromLTWH(shortest * (w + gap), top, w, h));
    heights[shortest] = top + h;
    counts[shortest]++;
  }
  return out;
}

/// The height of a grid laid out by [uiMasonryLayout]: its tallest column (0 when empty).
double uiMasonryHeight(List<Rect> rects) => rects.fold(0.0, (m, r) => math.max(m, r.bottom));

/// A ratio the grid can use: anything not finite or not above 0 is a square.
double _safeRatio(double r) => r.isFinite && r > 0 ? r : 1;

/// `ui-masonry-grid`: columns of different heights, each item keeping its own shape, that animates
/// between column counts the way a phone's photo grid zooms.
///
/// The parent owns [columns]; a two-finger pinch on the grid (a [UiPinch]) asks for one fewer
/// (apart) or one more (together) through [onColumnsChanged], within [minColumns]..[maxColumns].
/// On every change each tile moves and resizes from where it is shown to its new place (laid out
/// at the in-between size each frame, so a `BoxFit.cover` picture never stretches). A change that
/// lands mid-animation carries on from where the tiles are. After a pinch the enclosing vertical
/// scroll view is moved so the point of the picture under the fingers stays under them. Tiles far
/// outside the screen jump straight to their new place. With animations off it changes at once.
///
/// It is not a scrollable and builds every item (put it in a scroll view). Tiles are keyed by
/// [itemKey], so they keep their state and pictures when the layout changes.
class UiMasonryGrid extends StatefulWidget {
  const UiMasonryGrid({
    super.key,
    required this.itemCount,
    required this.ratioOf,
    required this.itemBuilder,
    required this.columns,
    this.onColumnsChanged,
    this.itemKey,
    this.gap = 4,
    this.minColumns = 1,
    this.maxColumns = 5,
    this.pinchable = true,
    this.duration = const Duration(milliseconds: 280),
    this.curve = Curves.easeOutCubic,
  });

  final int itemCount;

  /// Height / width of item `index`; used as given (not finite or not above 0 counts as 1).
  final double Function(int index) ratioOf;

  /// Builds item `index`, laid out at exactly its tile's size.
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// The column count now shown (clamped to at least 1).
  final int columns;

  /// The pinch asks for a new column count; the parent sets [columns] to it.
  final ValueChanged<int>? onColumnsChanged;

  /// A stable identity for item `index` (default: the index), so a tile keeps its state.
  final Object Function(int index)? itemKey;

  final double gap;
  final int minColumns;
  final int maxColumns;

  /// Answer a two-finger pinch.
  final bool pinchable;

  final Duration duration;
  final Curve curve;

  @override
  State<UiMasonryGrid> createState() => _UiMasonryGridState();
}

/// A pinch step waiting for the parent to apply its column count.
class _Anchor {
  _Anchor(this.key, this.fraction, this.focal, this.columns);
  final Object key;
  final Offset fraction;
  final Offset focal;
  final int columns;
}

/// A scroll move to make once, during the grid's next layout (see [_RenderMasonry.performLayout]).
class _Correction {
  _Correction(this.position, this.delta);
  final ScrollPosition position;
  final double delta;
  bool done = false;
}

class _UiMasonryGridState extends State<UiMasonryGrid> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration)
    ..addStatusListener(_onStatus);
  late CurvedAnimation _progress = CurvedAnimation(parent: _controller, curve: widget.curve);
  final GlobalKey _bodyKey = GlobalKey();

  /// Where each tile starts, by index; null when nothing animates (or for a tile that doesn't).
  List<Rect?>? _from;
  _Correction? _correction;
  _Anchor? _anchor;

  _RenderMasonry? get _render {
    final ro = _bodyKey.currentContext?.findRenderObject();
    return ro is _RenderMasonry && ro.attached && ro.laidOutSize != null ? ro : null;
  }

  Object _keyOf(UiMasonryGrid w, int i) => w.itemKey?.call(i) ?? i;

  int _cols(int c) => math.max(1, c);

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _from != null && mounted) setState(() => _from = null);
  }

  @override
  void didUpdateWidget(UiMasonryGrid old) {
    super.didUpdateWidget(old);
    if (old.duration != widget.duration) _controller.duration = widget.duration;
    if (old.curve != widget.curve) {
      _progress.dispose();
      _progress = CurvedAnimation(parent: _controller, curve: widget.curve);
    }
    if (_cols(old.columns) != _cols(widget.columns)) {
      _transition(old);
    } else if (_from != null && (old.itemCount != widget.itemCount || old.itemKey != widget.itemKey)) {
      // Items came or went mid-animation: keep each remaining tile's start by its key.
      final starts = <Object, Rect?>{for (var i = 0; i < old.itemCount && i < _from!.length; i++) _keyOf(old, i): _from![i]};
      _from = List<Rect?>.generate(widget.itemCount, (i) => starts[_keyOf(widget, i)]);
    }
  }

  /// Starts the move from what is shown now to the layout for the new column count.
  void _transition(UiMasonryGrid old) {
    final ro = _render;
    final anchor = _anchor != null && _anchor!.columns == _cols(widget.columns) ? _anchor : null;
    _anchor = null;
    if (ro == null) return;
    final size = ro.laidOutSize!;
    final ratios = _ratios(widget);
    final target = uiMasonryLayout(size.width, ratios, widget.columns, widget.gap);
    final shown = <Object, Rect>{for (var i = 0; i < old.itemCount && i < ro.itemCount; i++) _keyOf(old, i): ro.shownRect(i)};

    final scrollable = Scrollable.maybeOf(context);
    final position = scrollable != null && scrollable.axisDirection == AxisDirection.down && scrollable.position.hasContentDimensions
        ? scrollable.position
        : null;

    // Keep the point under the fingers under them: scroll by how far it moves.
    var applied = 0.0;
    if (anchor != null && position != null) {
      final i = _indexOfKey(anchor.key);
      if (i != null) {
        final r = target[i];
        final point = r.topLeft + Offset(anchor.fraction.dx * r.width, anchor.fraction.dy * r.height);
        final focal = ro.globalToLocal(anchor.focal);
        // The extent after this layout: the grid's growth moves the end by the same amount.
        final max = position.maxScrollExtent + (uiMasonryHeight(target) - size.height);
        final to = (position.pixels + point.dy - focal.dy).clamp(position.minScrollExtent, math.max(position.minScrollExtent, max));
        applied = to - position.pixels;
      }
    }
    _correction = applied != 0 && position != null ? _Correction(position, applied) : null;

    if (!context.uiAnimate) {
      _from = null;
      _controller.value = 1;
      return;
    }

    // The band worth animating: the screen (as it will be after the scroll) and a screen either side.
    final viewport = scrollable?.context.findRenderObject();
    Rect band;
    if (viewport is RenderBox && viewport.hasSize) {
      final topLeft = ro.globalToLocal(viewport.localToGlobal(Offset.zero));
      band = (topLeft & viewport.size).shift(Offset(0, applied));
    } else {
      band = ro.globalToLocal(Offset.zero) & MediaQuery.sizeOf(context);
    }
    band = Rect.fromLTRB(band.left, band.top - band.height, band.right, band.bottom + band.height);

    var any = false;
    _from = List<Rect?>.generate(widget.itemCount, (i) {
      final s = shown[_keyOf(widget, i)];
      if (s == null) return null;
      final from = s.shift(Offset(0, applied));
      final to = target[i];
      if (from == to || (!from.overlaps(band) && !to.overlaps(band))) return null;
      any = true;
      return from;
    });
    if (!any) {
      _from = null;
      _controller.value = 1;
      return;
    }
    _controller.forward(from: 0);
  }

  int? _indexOfKey(Object key) {
    if (widget.itemKey == null) return key is int && key >= 0 && key < widget.itemCount ? key : null;
    for (var i = 0; i < widget.itemCount; i++) {
      if (widget.itemKey!(i) == key) return i;
    }
    return null;
  }

  void _onPinch(UiPinchStep step) {
    final now = _cols(widget.columns);
    final next = (now + (step.apart ? -1 : 1)).clamp(widget.minColumns, widget.maxColumns);
    if (next == now || widget.onColumnsChanged == null) return;
    final ro = _render;
    if (ro != null && ro.itemCount > 0) {
      final local = ro.globalToLocal(step.focal);
      var best = 0;
      var bestDistance = double.infinity;
      for (var i = 0; i < ro.itemCount; i++) {
        final r = ro.shownRect(i);
        if (r.contains(local)) {
          best = i;
          break;
        }
        final dx = math.max(0.0, math.max(r.left - local.dx, local.dx - r.right));
        final dy = math.max(0.0, math.max(r.top - local.dy, local.dy - r.bottom));
        final d = dx * dx + dy * dy;
        if (d < bestDistance) {
          bestDistance = d;
          best = i;
        }
      }
      final r = ro.shownRect(best);
      final fraction = Offset(
        r.width > 0 ? ((local.dx - r.left) / r.width).clamp(0.0, 1.0) : 0.5,
        r.height > 0 ? ((local.dy - r.top) / r.height).clamp(0.0, 1.0) : 0.5,
      );
      _anchor = _Anchor(_keyOf(widget, best), fraction, step.focal, next);
      // Forget it after the next frame if the parent didn't take the new count.
      SchedulerBinding.instance.addPostFrameCallback((_) => _anchor = null);
      SchedulerBinding.instance.ensureVisualUpdate();
    }
    widget.onColumnsChanged!(next);
  }

  List<double> _ratios(UiMasonryGrid w) => List<double>.generate(w.itemCount, (i) => _safeRatio(w.ratioOf(i)));

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final correction = _correction;
    if (correction != null) SchedulerBinding.instance.addPostFrameCallback((_) => _correction = null);
    Widget body = _MasonryBody(
      key: _bodyKey,
      ratios: _ratios(widget),
      columns: widget.columns,
      gap: widget.gap,
      from: _from,
      progress: _from == null ? null : _progress,
      correction: correction,
      children: [
        for (var i = 0; i < widget.itemCount; i++)
          KeyedSubtree(key: ValueKey<Object>(_keyOf(widget, i)), child: widget.itemBuilder(context, i)),
      ],
    );
    if (widget.pinchable) body = UiPinch(onPinch: _onPinch, child: body);
    return body;
  }
}

class _MasonryBody extends MultiChildRenderObjectWidget {
  const _MasonryBody({
    super.key,
    required this.ratios,
    required this.columns,
    required this.gap,
    required this.from,
    required this.progress,
    required this.correction,
    required super.children,
  });

  final List<double> ratios;
  final int columns;
  final double gap;
  final List<Rect?>? from;
  final Animation<double>? progress;
  final _Correction? correction;

  @override
  _RenderMasonry createRenderObject(BuildContext context) => _RenderMasonry(ratios, columns, gap)
    ..from = from
    ..progress = progress
    ..correction = correction;

  @override
  void updateRenderObject(BuildContext context, _RenderMasonry renderObject) {
    renderObject
      ..ratios = ratios
      ..columns = columns
      ..gap = gap
      ..from = from
      ..progress = progress
      ..correction = correction;
  }
}

class _MasonryParentData extends ContainerBoxParentData<RenderBox> {}

/// Lays each child out at its tile's current rect: the target layout, or on the way to it from
/// [from] while [progress] runs. Relayout only, never a rebuild, on each animation frame; a child
/// whose size doesn't change returns from layout at once.
class _RenderMasonry extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _MasonryParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _MasonryParentData> {
  _RenderMasonry(this._ratios, this._columns, this._gap);

  List<double> _ratios;
  set ratios(List<double> v) {
    if (identical(v, _ratios)) return;
    _ratios = v;
    _target = null;
    markNeedsLayout();
  }

  int _columns;
  set columns(int v) {
    if (v == _columns) return;
    _columns = v;
    _target = null;
    markNeedsLayout();
  }

  double _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    _target = null;
    markNeedsLayout();
  }

  List<Rect?>? _from;
  set from(List<Rect?>? v) {
    if (identical(v, _from)) return;
    _from = v;
    markNeedsLayout();
  }

  Animation<double>? _progress;
  set progress(Animation<double>? v) {
    if (identical(v, _progress)) return;
    if (attached) _progress?.removeListener(markNeedsLayout);
    _progress = v;
    if (attached) _progress?.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  _Correction? _correction;
  set correction(_Correction? v) {
    if (identical(v, _correction)) return;
    _correction = v;
    if (v != null && !v.done) markNeedsLayout();
  }

  List<Rect>? _target;
  double _targetWidth = -1;
  double _height = 0;

  /// The size of the last layout, readable outside layout (the State reads it while building).
  Size? laidOutSize;

  int get itemCount => _ratios.length;

  List<Rect> _targetFor(double width) {
    if (_target == null || width != _targetWidth) {
      _target = uiMasonryLayout(width, _ratios, _columns, _gap);
      _targetWidth = width;
      _height = uiMasonryHeight(_target!);
    }
    return _target!;
  }

  /// Where tile [i] is drawn now (grid coordinates).
  Rect shownRect(int i) {
    final target = _target;
    if (target == null || i >= target.length) return Rect.zero;
    final from = _from;
    final p = _progress;
    final f = from != null && p != null && i < from.length ? from[i] : null;
    if (f == null) return target[i];
    return Rect.lerp(f, target[i], p!.value)!;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress?.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _progress?.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MasonryParentData) child.parentData = _MasonryParentData();
  }

  double _widthFor(BoxConstraints c) => c.hasBoundedWidth ? c.maxWidth : c.minWidth;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = _widthFor(constraints);
    return constraints.constrain(Size(width, uiMasonryHeight(uiMasonryLayout(width, _ratios, _columns, _gap))));
  }

  @override
  void performLayout() {
    final width = _widthFor(constraints);
    final target = _targetFor(width);
    size = constraints.constrain(Size(width, _height));
    laidOutSize = size;

    // A scroll set up by the State for this change. Applied as a layout-time correction, the way
    // slivers correct a viewport, so it lands in this same frame without notifying anyone mid-build.
    final c = _correction;
    if (c != null && !c.done) {
      c.done = true;
      if (c.position.hasPixels) c.position.correctBy(c.delta);
    }

    var i = 0;
    var child = firstChild;
    while (child != null) {
      final r = i < target.length ? shownRect(i) : Rect.zero;
      child.layout(BoxConstraints.tight(Size(math.max(0, r.width), math.max(0, r.height))));
      (child.parentData! as _MasonryParentData).offset = r.topLeft;
      child = childAfter(child);
      i++;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}
