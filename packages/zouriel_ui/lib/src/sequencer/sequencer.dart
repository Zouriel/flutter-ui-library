import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';

/// A keyframe on a [UiSequencerRow]'s bar.
@immutable
class UiSequencerKeyframe {
  const UiSequencerKeyframe({required this.id, required this.at, this.label});
  final String id;

  /// Position within the row's bar: 0 is its start, 1 its end.
  final double at;
  final String? label;

  UiSequencerKeyframe copyWith({double? at, String? label}) => UiSequencerKeyframe(id: id, at: at ?? this.at, label: label ?? this.label);
}

/// One layer of a [UiSequencer]: a bar from [start] to [end] (timeline units) and its keyframes.
@immutable
class UiSequencerRow {
  const UiSequencerRow({
    required this.id,
    required this.label,
    required this.start,
    required this.end,
    this.keyframes = const [],
    this.depth = 0,
    this.muted = false,
    this.locked = false,
    this.kind,
    this.fixed = false,
  });

  final String id;
  final String label;
  final double start;
  final double end;
  final List<UiSequencerKeyframe> keyframes;

  /// Nesting level, for rows inside a group.
  final int depth;
  final bool muted;
  final bool locked;

  /// A short type label shown before the name.
  final String? kind;

  /// Its length can't be trimmed: the bar only moves, and has no edges to drag.
  final bool fixed;

  UiSequencerRow copyWith({String? label, double? start, double? end, List<UiSequencerKeyframe>? keyframes, int? depth, bool? muted, bool? locked, String? kind, bool? fixed}) =>
      UiSequencerRow(
        id: id,
        label: label ?? this.label,
        start: start ?? this.start,
        end: end ?? this.end,
        keyframes: keyframes ?? this.keyframes,
        depth: depth ?? this.depth,
        muted: muted ?? this.muted,
        locked: locked ?? this.locked,
        kind: kind ?? this.kind,
        fixed: fixed ?? this.fixed,
      );
}

/// A labelled marker on the ruler; also a snap target.
@immutable
class UiSequencerMarker {
  const UiSequencerMarker({required this.at, required this.label});
  final double at;
  final String label;
}

/// A bar was moved or trimmed.
@immutable
class UiSequencerRangeChange {
  const UiSequencerRangeChange({required this.rowId, required this.start, required this.end, required this.isFinal});
  final String rowId;
  final double start;
  final double end;

  /// False while dragging, true once on release: commit on true.
  final bool isFinal;

  @override
  bool operator ==(Object other) => other is UiSequencerRangeChange && other.rowId == rowId && other.start == start && other.end == end && other.isFinal == isFinal;
  @override
  int get hashCode => Object.hash(rowId, start, end, isFinal);
  @override
  String toString() => 'UiSequencerRangeChange($rowId, $start, $end, final: $isFinal)';
}

/// A keyframe was retimed.
@immutable
class UiSequencerKeyframeChange {
  const UiSequencerKeyframeChange({required this.rowId, required this.keyframeId, required this.at, required this.isFinal});
  final String rowId;
  final String keyframeId;
  final double at;
  final bool isFinal;
}

/// A keyframe whose menu was asked for, and where (global coordinates) to open it.
@immutable
class UiSequencerKeyframeRef {
  const UiSequencerKeyframeRef({required this.rowId, required this.keyframeId, required this.position});
  final String rowId;
  final String keyframeId;
  final Offset position;
}

enum _Kind { move, start, end, keyframe, playhead, reorder, pageEnd }

/// How long a bar is held before it lifts and can go anywhere.
const Duration _liftDelay = Duration(milliseconds: 380);

/// The shortest row: every bar keeps a box at least 24px tall (WCAG 2.5.8 target size).
const double _minRowHeight = 25;

/// How long the name shown after a tap stays up.
const Duration _tipTime = Duration(milliseconds: 2600);

/// `ui-sequencer`: a timeline editor. One row per layer, a bar for the range each is active,
/// diamonds for its keyframes, a draggable playhead and labelled markers along a ruler.
///
/// Drag a bar to move it, its edges to trim it, a diamond to retime it (clamped to its bar). Bars,
/// edges and diamonds snap to markers, the playhead and other bars' edges; hold Alt to place
/// freely. Drag a row's grip to reorder. Everything is reported, nothing is mutated: the host owns
/// the rows.
///
/// Without labels ([showLabels] false) the rows are bars only, the way phone video editors show
/// clips: a tap on a bar selects it and shows its name for a moment; holding a bar lifts it, and
/// then it follows the finger both ways, along the timeline to move it and up or down to reorder. A
/// plain swipe scrolls, two fingers pinch to zoom (Ctrl + wheel with a mouse), and the edges still
/// trim.
///
/// Keyboard: a focused bar moves with the arrows (Shift for a larger step) and trims with `[` and
/// `]`; a focused diamond retimes with the arrows, Delete removes it, and the context-menu key (or
/// Shift+F10) asks for its menu. A long press on a diamond, or a right-click, does too.
class UiSequencer extends StatefulWidget {
  const UiSequencer({
    super.key,
    this.rows = const [],
    this.length = 100,
    this.markers = const [],
    this.title = 'Layers',
    this.emptyText = 'Nothing here yet',
    this.labelWidth = 200,
    this.rowHeight = 30,
    this.snapPixels = 6,
    this.keyStep = 0.01,
    this.endDraggable = false,
    this.endLabel = 'Drag to change where it ends',
    this.reorderable = true,
    this.zoom = 1,
    this.onZoomChanged,
    this.maxZoom = 16,
    this.showLabels = true,
    this.end,
    this.compact = false,
    this.playhead = 0,
    this.onPlayheadChanged,
    this.selectedRowId,
    this.onSelectedRowIdChanged,
    this.selectedKeyframeId,
    this.onSelectedKeyframeIdChanged,
    this.onRangeChange,
    this.onKeyframeChange,
    this.onKeyframeDelete,
    this.onKeyframeMenu,
    this.onRowReorder,
    this.onMuteToggle,
    this.onLockToggle,
    this.onScrub,
    this.onEndChange,
  });

  final List<UiSequencerRow> rows;

  /// The timeline's length in units.
  final double length;
  final List<UiSequencerMarker> markers;

  /// Label column heading.
  final String title;
  final String emptyText;
  final double labelWidth;

  /// Row height in px; never less than 25, so every bar stays a 24px-tall target.
  final double rowHeight;

  /// Snap distance in screen pixels.
  final double snapPixels;

  /// Keyboard step as a fraction of the length.
  final double keyStep;

  /// The End (see [end]) has a grip, to make the timeline's content longer or shorter.
  final bool endDraggable;
  final String endLabel;
  final bool reorderable;

  /// 1 fits the width; larger values zoom in and scroll horizontally.
  final double zoom;
  final ValueChanged<double>? onZoomChanged;
  final double maxZoom;

  /// Show the label column (name, grip, toggles). Off: bars only, names on tap.
  final bool showLabels;

  /// Where the content ends, if the timeline runs on past it; what's beyond is shaded.
  final double? end;

  /// Narrow screens: the label column shows the grip, name and visibility toggle only.
  final bool compact;

  final double playhead;
  final ValueChanged<double>? onPlayheadChanged;
  final String? selectedRowId;
  final ValueChanged<String?>? onSelectedRowIdChanged;
  final String? selectedKeyframeId;
  final ValueChanged<String?>? onSelectedKeyframeIdChanged;

  final ValueChanged<UiSequencerRangeChange>? onRangeChange;
  final ValueChanged<UiSequencerKeyframeChange>? onKeyframeChange;
  final void Function(String rowId, String keyframeId)? onKeyframeDelete;
  final ValueChanged<UiSequencerKeyframeRef>? onKeyframeMenu;
  final void Function(String rowId, int toIndex)? onRowReorder;
  final ValueChanged<String>? onMuteToggle;
  final ValueChanged<String>? onLockToggle;

  /// A tap on an empty part of a lane or the ruler (or the end of a playhead drag), after the
  /// playhead moved there.
  final ValueChanged<double>? onScrub;

  /// The End was dragged (not clamped to [length], so the host can grow the timeline) or moved with
  /// the keys; [isFinal] once the gesture is done.
  final void Function(double end, bool isFinal)? onEndChange;

  @override
  State<UiSequencer> createState() => _UiSequencerState();
}

class _Drag {
  _Drag({required this.kind, required this.startX, required this.unitsPerPx, this.row, this.keyframe, this.index = 0, this.origStart = 0, this.origEnd = 0, this.origAt = 0});
  final _Kind kind;
  final double startX;
  final double unitsPerPx;
  final UiSequencerRow? row;
  final UiSequencerKeyframe? keyframe;
  final int index;
  final double origStart, origEnd, origAt;
  bool moved = false;
  ({double start, double end, double at})? last;
}

class _Lift {
  _Lift({required this.row, required this.index, required this.startLocal, required this.unitsPerPx});
  final UiSequencerRow row;
  final int index;
  final Offset startLocal;
  final double unitsPerPx;
  late double start = row.start;
  bool moved = false;
}

class _Tip {
  const _Tip(this.id, this.x, this.edge);
  final String id;

  /// Across the grid, in px; null centres it on the bar.
  final double? x;

  /// -1 near the left edge of the view, 1 near the right, 0 neither.
  final int edge;
}

class _UiSequencerState extends State<UiSequencer> {
  late double _zoom = widget.zoom;
  late double _playhead = widget.playhead;
  late String? _row = widget.selectedRowId;
  late String? _keyframe = widget.selectedKeyframeId;

  final ScrollController _h = ScrollController();
  final ScrollController _hRuler = ScrollController();
  final ScrollController _v = ScrollController();
  final GlobalKey _gridKey = GlobalKey();
  final GlobalKey _rulerKey = GlobalKey();
  final GlobalKey _labelsKey = GlobalKey();
  final GlobalKey _viewKey = GlobalKey();

  int? _dropIndex;
  _Tip? _tip;
  String? _liftedId;
  Timer? _tipTimer;
  _Drag? _drag;
  _Lift? _lift;
  ({double zoom, double frac, double anchorX})? _pinch;
  double _gridW = 1;

  /// The timeline runs this far in from both ends (half a keyframe's 24px target), so diamonds and
  /// grips at 0 or the end aren't cut in half.
  double _inset = 12;
  double get _trackW => math.max(1, _gridW - 2 * _inset);

  @override
  void initState() {
    super.initState();
    _h.addListener(() {
      if (_hRuler.hasClients) _hRuler.jumpTo(_h.offset.clamp(0.0, _hRuler.position.maxScrollExtent));
    });
  }

  @override
  void didUpdateWidget(UiSequencer old) {
    super.didUpdateWidget(old);
    if (widget.zoom != old.zoom) _zoom = widget.zoom;
    if (widget.playhead != old.playhead) _playhead = widget.playhead;
    if (widget.selectedRowId != old.selectedRowId) _row = widget.selectedRowId;
    if (widget.selectedKeyframeId != old.selectedKeyframeId) _keyframe = widget.selectedKeyframeId;
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    _h.dispose();
    _hRuler.dispose();
    _v.dispose();
    super.dispose();
  }

  double get _rowH => math.max(_minRowHeight, widget.rowHeight);
  double get _len => widget.length <= 0 ? 1 : widget.length;
  double _x(double units) => _inset + _w(units);
  double _w(double units) => units / _len * _trackW;
  double get _unitsPerPx => _len / _trackW;
  bool get _free => HardwareKeyboard.instance.isAltPressed;

  // ----- Controlled values ------------------------------------------------------------------------

  void _selectRow(String id) {
    if (_row == id) return;
    setState(() => _row = id);
    widget.onSelectedRowIdChanged?.call(id);
  }

  void _selectKeyframe(String id) {
    if (_keyframe == id) return;
    setState(() => _keyframe = id);
    widget.onSelectedKeyframeIdChanged?.call(id);
  }

  void _setPlayhead(double v) {
    final next = v.clamp(0.0, widget.length).toDouble();
    if (next == _playhead) return;
    setState(() => _playhead = next);
    widget.onPlayheadChanged?.call(next);
  }

  void _setZoom(double z) {
    final next = z.clamp(1.0, math.max(1.0, widget.maxZoom)).toDouble();
    if (next == _zoom) return;
    setState(() => _zoom = next);
    widget.onZoomChanged?.call(next);
  }

  /// Pointer x (global) as a position on the grid, in px from its start.
  double _gridX(Offset global) {
    final box = (_gridKey.currentContext ?? _rulerKey.currentContext)?.findRenderObject() as RenderBox?;
    return box == null ? 0 : box.globalToLocal(global).dx;
  }

  void _setPlayheadFromPointer(Offset global) => _setPlayhead((_gridX(global) - _inset) / _trackW * _len);

  /// Snaps a position to markers, the playhead, the end and other rows' edges within [UiSequencer.snapPixels].
  double _snap(double units, String? excludeRow, double unitsPerPx) {
    final threshold = widget.snapPixels * unitsPerPx;
    final candidates = <double>[0, widget.length, _playhead, for (final m in widget.markers) m.at];
    if (widget.end != null) candidates.add(widget.end!);
    for (final r in widget.rows) {
      if (r.id != excludeRow) candidates.addAll([r.start, r.end]);
    }
    var best = units;
    var bestDist = threshold;
    for (final c in candidates) {
      final dist = (c - units).abs();
      if (dist <= bestDist) {
        best = c;
        bestDist = dist;
      }
    }
    return best;
  }

  // ----- Drags ------------------------------------------------------------------------------------

  void _begin(_Drag d) {
    _hideTip();
    _drag = d;
  }

  void _update(Offset global) {
    final d = _drag;
    if (d == null) return;
    d.moved = true;
    final du = (global.dx - d.startX) * d.unitsPerPx;
    final len = widget.length;
    final free = _free;
    switch (d.kind) {
      case _Kind.playhead:
        _setPlayheadFromPointer(global);
      case _Kind.move:
        final span = d.origEnd - d.origStart;
        var start = (d.origStart + du).clamp(0.0, math.max(0.0, len - span)).toDouble();
        if (!free) {
          final ss = _snap(start, d.row!.id, d.unitsPerPx);
          final se = _snap(start + span, d.row!.id, d.unitsPerPx);
          if (ss != start) {
            start = ss;
          } else if (se != start + span) {
            start = se - span;
          }
          start = start.clamp(0.0, math.max(0.0, len - span)).toDouble();
        }
        d.last = (start: start, end: start + span, at: 0);
        widget.onRangeChange?.call(UiSequencerRangeChange(rowId: d.row!.id, start: start, end: start + span, isFinal: false));
      case _Kind.start:
        final limit = d.origEnd - d.unitsPerPx * 8;
        var start = math.min(math.max(0.0, d.origStart + du), limit);
        if (!free) start = math.min(_snap(start, d.row!.id, d.unitsPerPx), limit);
        d.last = (start: start, end: d.origEnd, at: 0);
        widget.onRangeChange?.call(UiSequencerRangeChange(rowId: d.row!.id, start: start, end: d.origEnd, isFinal: false));
      case _Kind.end:
        final limit = d.origStart + d.unitsPerPx * 8;
        var end = math.max(math.min(len, d.origEnd + du), limit);
        if (!free) end = math.max(_snap(end, d.row!.id, d.unitsPerPx), limit);
        d.last = (start: d.origStart, end: end, at: 0);
        widget.onRangeChange?.call(UiSequencerRangeChange(rowId: d.row!.id, start: d.origStart, end: end, isFinal: false));
      case _Kind.pageEnd:
        // Under the pointer at the timeline's current scale, and not clamped to its length: the host
        // can grow the timeline while the End is pulled past its edge.
        var end = math.max(0.0, (_gridX(global) - _inset) / _trackW * _len);
        if (!free) end = _snap(end, null, d.unitsPerPx);
        d.last = (start: 0, end: end, at: end);
        widget.onEndChange?.call(end, false);
      case _Kind.keyframe:
        final span = d.origEnd - d.origStart == 0 ? 1.0 : d.origEnd - d.origStart;
        var units = d.origStart + d.origAt * span + du;
        if (!free) units = _snap(units, null, d.unitsPerPx);
        final at = ((units - d.origStart) / span).clamp(0.0, 1.0).toDouble();
        d.last = (start: d.origStart, end: d.origEnd, at: at);
        widget.onKeyframeChange?.call(UiSequencerKeyframeChange(rowId: d.row!.id, keyframeId: d.keyframe!.id, at: at, isFinal: false));
      case _Kind.reorder:
        final box = _labelsKey.currentContext?.findRenderObject() as RenderBox?;
        final y = box?.globalToLocal(global).dy ?? 0;
        setState(() => _dropIndex = (y / _rowH).round().clamp(0, widget.rows.length));
    }
  }

  void _finish({bool cancelled = false}) {
    final d = _drag;
    _drag = null;
    if (d == null) return;
    if (d.kind == _Kind.reorder) {
      final to = _dropIndex;
      setState(() => _dropIndex = null);
      if (!cancelled && to != null && to != d.index && to != d.index + 1) widget.onRowReorder?.call(d.row!.id, to > d.index ? to - 1 : to);
      return;
    }
    if (!d.moved) return;
    // The gesture was taken away: put back whatever was being dragged.
    final last = cancelled && d.last != null ? (start: d.origStart, end: d.origEnd, at: d.origAt) : d.last;
    switch (d.kind) {
      case _Kind.pageEnd:
        if (last != null) widget.onEndChange?.call(last.end, true);
      case _Kind.move || _Kind.start || _Kind.end:
        if (last != null) widget.onRangeChange?.call(UiSequencerRangeChange(rowId: d.row!.id, start: last.start, end: last.end, isFinal: true));
      case _Kind.keyframe:
        if (last != null) widget.onKeyframeChange?.call(UiSequencerKeyframeChange(rowId: d.row!.id, keyframeId: d.keyframe!.id, at: last.at, isFinal: true));
      case _Kind.playhead:
        widget.onScrub?.call(_playhead);
      case _Kind.reorder:
        break;
    }
  }

  void _startBar(UiSequencerRow row, _Kind kind, Offset global) {
    _selectRow(row.id);
    if (row.locked) return;
    _begin(_Drag(kind: kind, row: row, startX: global.dx, unitsPerPx: _unitsPerPx, origStart: row.start, origEnd: row.end));
  }

  void _startKeyframe(UiSequencerRow row, UiSequencerKeyframe k, Offset global) {
    _selectRow(row.id);
    _selectKeyframe(k.id);
    if (row.locked) return;
    _begin(_Drag(kind: _Kind.keyframe, row: row, keyframe: k, startX: global.dx, unitsPerPx: _unitsPerPx, origStart: row.start, origEnd: row.end, origAt: k.at));
  }

  // ----- Bars only: tap for the name, hold to lift ------------------------------------------------

  void _showTip(String rowId, [Offset? global]) {
    final view = _viewKey.currentContext?.findRenderObject() as RenderBox?;
    if (global == null || view == null || !view.hasSize) {
      setState(() => _tip = _Tip(rowId, null, 0));
    } else {
      final left = view.localToGlobal(Offset.zero).dx;
      final right = left + view.size.width;
      final x = global.dx.clamp(left, right).toDouble();
      const room = 120.0;
      final edge = x - left < room ? -1 : right - x < room ? 1 : 0;
      setState(() => _tip = _Tip(rowId, _gridX(Offset(x, global.dy)), edge));
    }
    _keepTip();
  }

  void _keepTip() {
    _tipTimer?.cancel();
    _tipTimer = Timer(_tipTime, () {
      if (mounted) setState(() => _tip = null);
    });
  }

  void _hideTip() {
    _tipTimer?.cancel();
    if (_tip != null) setState(() => _tip = null);
  }

  Offset _gridLocal(Offset global) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global) ?? global;
  }

  void _startLift(UiSequencerRow row, Offset global) {
    if (row.locked) {
      _selectRow(row.id);
      _showTip(row.id, global);
      return;
    }
    final index = widget.rows.indexWhere((r) => r.id == row.id);
    _drag = null;
    _lift = _Lift(row: row, index: index, startLocal: _gridLocal(global), unitsPerPx: _unitsPerPx);
    _hideTip();
    _selectRow(row.id);
    setState(() => _liftedId = row.id);
    HapticFeedback.selectionClick();
  }

  void _moveLift(Offset global) {
    final l = _lift;
    if (l == null) return;
    // Near an edge, the timeline scrolls under the lifted bar.
    final view = _viewKey.currentContext?.findRenderObject() as RenderBox?;
    if (view != null && view.hasSize) {
      final p = view.globalToLocal(global);
      const edge = 28.0;
      if (_h.hasClients) {
        if (p.dx < edge) _h.jumpTo(math.max(0, _h.offset - 12));
        if (p.dx > view.size.width - edge) _h.jumpTo(math.min(_h.position.maxScrollExtent, _h.offset + 12));
      }
      if (_v.hasClients) {
        if (p.dy < edge) _v.jumpTo(math.max(0, _v.offset - 8));
        if (p.dy > view.size.height - edge) _v.jumpTo(math.min(_v.position.maxScrollExtent, _v.offset + 8));
      }
    }
    final local = _gridLocal(global);
    final span = l.row.end - l.row.start;
    final len = widget.length;
    var start = (l.row.start + (local.dx - l.startLocal.dx) * l.unitsPerPx).clamp(0.0, math.max(0.0, len - span)).toDouble();
    if (!_free) {
      final ss = _snap(start, l.row.id, l.unitsPerPx);
      final se = _snap(start + span, l.row.id, l.unitsPerPx);
      if (ss != start) {
        start = ss;
      } else if (se != start + span) {
        start = se - span;
      }
      start = start.clamp(0.0, math.max(0.0, len - span)).toDouble();
    }
    if (start != l.start) {
      l.start = start;
      l.moved = true;
      widget.onRangeChange?.call(UiSequencerRangeChange(rowId: l.row.id, start: start, end: start + span, isFinal: false));
    }
    // Up or down: only once the bar has left its own row, so a sideways move never reorders by accident.
    final drop = (local.dy - l.startLocal.dy).abs() < _rowH * 0.6 ? null : (local.dy / _rowH).round().clamp(0, widget.rows.length);
    if (drop != _dropIndex) setState(() => _dropIndex = drop);
  }

  void _endLift() {
    final l = _lift;
    _lift = null;
    final to = _dropIndex;
    setState(() {
      _liftedId = null;
      _dropIndex = null;
    });
    if (l == null) return;
    final span = l.row.end - l.row.start;
    if (l.moved) widget.onRangeChange?.call(UiSequencerRangeChange(rowId: l.row.id, start: l.start, end: l.start + span, isFinal: true));
    if (to != null && to != l.index && to != l.index + 1) widget.onRowReorder?.call(l.row.id, to > l.index ? to - 1 : to);
  }

  // ----- Zoom -------------------------------------------------------------------------------------

  void _beginPinch(Offset focal) {
    final view = _viewKey.currentContext?.findRenderObject() as RenderBox?;
    final anchorX = view == null ? 0.0 : view.globalToLocal(focal).dx;
    final offset = _h.hasClients ? _h.offset : 0.0;
    _pinch = (zoom: _zoom, frac: (offset + anchorX) / math.max(1, _gridW), anchorX: anchorX);
    _hideTip();
  }

  /// Zooms about the pinch's focal point, so what's under the fingers stays under them.
  void _movePinch(double ratio) {
    final p = _pinch;
    if (p == null) return;
    final before = _zoom;
    _setZoom(p.zoom * ratio);
    if (_zoom == before) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_h.hasClients) return;
      final target = p.frac * _gridW - p.anchorX;
      _h.jumpTo(target.clamp(0.0, _h.position.maxScrollExtent));
    });
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final k = HardwareKeyboard.instance;
    if (!k.isControlPressed && !k.isMetaPressed) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (event) {
      final s = event as PointerScrollEvent;
      _beginPinch(s.position);
      _movePinch(math.exp(-s.scrollDelta.dy * 0.01));
      _pinch = null;
    });
  }

  // ----- Keyboard ---------------------------------------------------------------------------------

  bool get _shift => HardwareKeyboard.instance.isShiftPressed;

  KeyEventResult _playheadKey(KeyEvent e) {
    final step = widget.length * widget.keyStep * (_shift ? 10 : 1);
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      _setPlayhead(_playhead + (key == LogicalKeyboardKey.arrowLeft ? -step : step));
    } else if (key == LogicalKeyboardKey.home || key == LogicalKeyboardKey.end) {
      _setPlayhead(key == LogicalKeyboardKey.home ? 0 : widget.length);
    } else {
      return KeyEventResult.ignored;
    }
    widget.onScrub?.call(_playhead);
    return KeyEventResult.handled;
  }

  KeyEventResult _endKey(KeyEvent e) {
    final end = widget.end;
    final key = e.logicalKey;
    if (end == null || (key != LogicalKeyboardKey.arrowLeft && key != LogicalKeyboardKey.arrowRight)) return KeyEventResult.ignored;
    final step = widget.length * widget.keyStep * (_shift ? 10 : 1);
    widget.onEndChange?.call(math.max(0, end + (key == LogicalKeyboardKey.arrowRight ? step : -step)), true);
    return KeyEventResult.handled;
  }

  KeyEventResult _barKey(KeyEvent e, UiSequencerRow row) {
    if (row.locked) return KeyEventResult.ignored;
    final len = widget.length;
    final shift = _shift;
    final step = len * widget.keyStep * (shift ? 10 : 1);
    var start = row.start;
    var end = row.end;
    final key = e.logicalKey;
    final ch = e.character;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      final span = end - start;
      start = (start + (key == LogicalKeyboardKey.arrowLeft ? -step : step)).clamp(0.0, math.max(0.0, len - span)).toDouble();
      end = start + span;
    } else if (ch == '{' || (key == LogicalKeyboardKey.bracketLeft && shift)) {
      start = math.min(start + step, end - step);
    } else if (ch == '}' || (key == LogicalKeyboardKey.bracketRight && shift)) {
      end = math.max(end - step, start + step);
    } else if (ch == '[' || key == LogicalKeyboardKey.bracketLeft) {
      start = math.min(math.max(0.0, start - step), end - step);
    } else if (ch == ']' || key == LogicalKeyboardKey.bracketRight) {
      end = math.max(math.min(len, end + step), start + step);
    } else {
      return KeyEventResult.ignored;
    }
    widget.onRangeChange?.call(UiSequencerRangeChange(rowId: row.id, start: start, end: end, isFinal: true));
    return KeyEventResult.handled;
  }

  KeyEventResult _keyframeKey(KeyEvent e, UiSequencerRow row, UiSequencerKeyframe k, BuildContext context) {
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
      if (!row.locked) widget.onKeyframeDelete?.call(row.id, k.id);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.contextMenu || (_shift && key == LogicalKeyboardKey.f10)) {
      final box = context.findRenderObject() as RenderBox?;
      final at = box == null ? Offset.zero : box.localToGlobal(box.size.bottomRight(Offset.zero));
      widget.onKeyframeMenu?.call(UiSequencerKeyframeRef(rowId: row.id, keyframeId: k.id, position: at));
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) && !row.locked) {
      final delta = (_shift ? 0.1 : 0.01) * (key == LogicalKeyboardKey.arrowLeft ? -1 : 1);
      widget.onKeyframeChange?.call(UiSequencerKeyframeChange(rowId: row.id, keyframeId: k.id, at: (k.at + delta).clamp(0.0, 1.0).toDouble(), isFinal: true));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _openMenu(UiSequencerRow row, UiSequencerKeyframe k, Offset global) {
    _selectRow(row.id);
    _selectKeyframe(k.id);
    widget.onKeyframeMenu?.call(UiSequencerKeyframeRef(rowId: row.id, keyframeId: k.id, position: global));
  }

  // ----- Build ------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    final base = context.uiText.body.copyWith(fontSize: 12, height: 1.35, fontFeatures: const [FontFeature.tabularFigures()]);
    return DefaultTextStyle.merge(
      style: base,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth.isFinite ? c.maxWidth : 600.0;
        final h = c.maxHeight.isFinite ? c.maxHeight : _rowH * (widget.rows.length + 3);
        final labelW = widget.showLabels ? math.min(widget.labelWidth, w * 0.7) : 0.0;
        final viewW = math.max(1.0, w - labelW);
        _gridW = viewW * _zoom;
        _inset = t.space3;
        final rowH = _rowH;
        final rowsH = widget.rows.isEmpty ? rowH * 2 : rowH * widget.rows.length;
        final bodyH = math.max(rowsH, h - rowH);

        final ruler = SizedBox(
          height: rowH,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (widget.showLabels) _corner(t, labelW),
            Expanded(
              child: SingleChildScrollView(
                controller: _hRuler,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(key: _rulerKey, width: _gridW, height: rowH, child: _ruler(t, touch, rowH)),
              ),
            ),
          ]),
        );

        final body = Stack(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.showLabels) SizedBox(key: _labelsKey, width: labelW, height: bodyH, child: _labels(t, touch, rowH)),
            Expanded(
              child: SizedBox(
                key: _viewKey,
                height: bodyH,
                child: SingleChildScrollView(
                  controller: _h,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(key: _gridKey, width: _gridW, height: bodyH, child: _grid(t, touch, rowH, viewW)),
                ),
              ),
            ),
          ]),
          if (widget.rows.isEmpty)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: rowH * 2,
              child: IgnorePointer(child: Center(child: Text(widget.emptyText, style: TextStyle(color: t.textMuted)))),
            ),
        ]);

        return Listener(
          onPointerSignal: _onSignal,
          child: RawGestureDetector(
            gestures: {
              _PinchRecognizer: GestureRecognizerFactoryWithHandlers<_PinchRecognizer>(_PinchRecognizer.new, (r) {
                r
                  ..onStart = (focal) {
                    _lift = null;
                    _drag = null;
                    if (_liftedId != null) setState(() => _liftedId = null);
                    _beginPinch(focal);
                  }
                  ..onUpdate = _movePinch
                  ..onEnd = () => _pinch = null;
              }),
            },
            child: ColoredBox(
              color: t.surface,
              child: SizedBox(
                width: w,
                height: h,
                child: Column(children: [
                  ruler,
                  Expanded(child: SingleChildScrollView(controller: _v, child: body)),
                ]),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _corner(UiTokens t, double width) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 8 : t.space3),
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(right: BorderSide(color: t.border), bottom: BorderSide(color: t.border)),
      ),
      child: Semantics(
        header: true,
        child: Text(
          widget.title.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 11 * 0.04, color: t.textMuted),
        ),
      ),
    );
  }

  /// How a marker's name fits its stretch of the ruler: whole ('label'), as its number when the
  /// stretch is too narrow, or not at all ('none') when the End grip sits on it.
  String _labelFit(int i, TextStyle style, double endW) {
    final markers = widget.markers;
    final m = markers[i];
    final room = _w(math.max(0, (i + 1 < markers.length ? markers[i + 1].at : widget.length) - m.at)) - 8;
    double widthOf(String s) {
      final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout();
      final w = tp.width;
      tp.dispose();
      return w;
    }
    final need = widthOf(m.label);
    final num = widthOf('${i + 1}');
    final fit = need <= room ? 'label' : num <= room ? 'number' : 'none';
    final end = widget.endDraggable ? widget.end : null;
    if (end != null && fit != 'none') {
      final x = _x(end) - _x(m.at);
      final textW = fit == 'label' ? need : num;
      if (x > -endW / 2 - 2 && x < 4 + textW + endW / 2 + 2) return 'none';
    }
    return fit;
  }

  Widget _ruler(UiTokens t, bool touch, double rowH) {
    final markers = widget.markers;
    final labelStyle = context.uiText.code.copyWith(fontSize: 11, color: t.textMuted, height: 1.2);
    final knob = touch ? 18.0 : 12.0;
    final knobBox = touch ? 38.0 : 24.0;
    final end = widget.end;
    final endW = (touch || widget.compact || !widget.showLabels) ? 26.0 : 14.0;
    return _gestures(
      cursor: SystemMouseCursors.resizeLeftRight,
      onTapUp: (d) {
        _setPlayheadFromPointer(d.globalPosition);
        widget.onScrub?.call(_playhead);
      },
      onDragStart: (d) {
        _setPlayheadFromPointer(d.globalPosition);
        _begin(_Drag(kind: _Kind.playhead, startX: d.globalPosition.dx, unitsPerPx: _unitsPerPx));
      },
      onDragUpdate: (d) => _update(d.globalPosition),
      onDragEnd: (_) => _finish(),
      onDragCancel: () => _finish(cancelled: true),
      child: DecoratedBox(
        decoration: BoxDecoration(color: t.surfaceSubtle, border: Border(bottom: BorderSide(color: t.border))),
        child: Stack(clipBehavior: Clip.none, children: [
          for (var i = 0; i < markers.length; i++)
            Positioned(
              left: _x(markers[i].at),
              width: _w(math.max(0, (i + 1 < markers.length ? markers[i + 1].at : widget.length) - markers[i].at)),
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border(left: BorderSide(color: t.borderStrong))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Align(
                      alignment: markers[i].at / _len > 0.88 ? Alignment.centerRight : Alignment.centerLeft,
                      child: switch (_labelFit(i, labelStyle, endW)) {
                        // Too narrow for the name: its number. Under the End grip: nothing, rather than a name with a bar through it.
                        'label' => Text(markers[i].label, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, style: labelStyle),
                        'number' => Semantics(label: markers[i].label, excludeSemantics: true, child: Text('${i + 1}', maxLines: 1, softWrap: false, style: labelStyle)),
                        _ => const SizedBox.shrink(),
                      },
                    ),
                  ),
                ),
              ),
            ),
          if (widget.endDraggable && end != null)
            Positioned(
              // Never closer to the left edge than half its width, so an End at 0 can still be grabbed.
              left: math.max(13, _x(end)) - endW / 2,
              width: endW,
              top: 0,
              bottom: 0,
              child: _EndHandle(
                label: widget.endLabel,
                value: end.round(),
                onKey: _endKey,
                gestures: (child) => _gestures(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  onDragStart: (d) => _begin(_Drag(kind: _Kind.pageEnd, startX: d.globalPosition.dx, unitsPerPx: _unitsPerPx, origAt: end)),
                  onDragUpdate: (d) => _update(d.globalPosition),
                  onDragEnd: (_) => _finish(),
                  onDragCancel: () => _finish(cancelled: true),
                  child: child,
                ),
              ),
            ),
          Positioned(
            left: _x(_playhead) - knobBox / 2,
            width: knobBox,
            top: 0,
            bottom: 0,
            child: _Focusable(
              onKey: _playheadKey,
              builder: (context, ring) {
                final step = widget.length * widget.keyStep;
                return Semantics(
                  slider: true,
                  label: 'Playhead',
                  value: _playhead.round().toString(),
                  increasedValue: math.min(widget.length, _playhead + step).round().toString(),
                  decreasedValue: math.max(0, _playhead - step).round().toString(),
                  onIncrease: () {
                    _setPlayhead(_playhead + step);
                    widget.onScrub?.call(_playhead);
                  },
                  onDecrease: () {
                    _setPlayhead(_playhead - step);
                    widget.onScrub?.call(_playhead);
                  },
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: knob,
                      height: knob,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), boxShadow: ring ? t.focusRing : null),
                      child: CustomPaint(painter: _KnobPainter(t.primary)),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _labels(UiTokens t, bool touch, double rowH) {
    final rows = widget.rows;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.surface, border: Border(right: BorderSide(color: t.border))),
      child: Stack(clipBehavior: Clip.none, children: [
        for (var i = 0; i < rows.length; i++)
          Positioned(left: 0, right: 0, top: i * rowH, height: rowH, child: _label(t, touch, rows[i], i)),
        if (_dropIndex != null && _dropIndex == rows.length)
          Positioned(left: 0, right: 0, top: rows.length * rowH - 1, height: 2, child: ColoredBox(color: t.primary)),
      ]),
    );
  }

  Widget _label(UiTokens t, bool touch, UiSequencerRow row, int index) {
    final selected = row.id == _row;
    return _HoverBuilder(builder: (context, hovered) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: () => _selectRow(row.id),
        child: Container(
          padding: EdgeInsetsDirectional.only(start: t.space2 + row.depth * 16, end: t.space1),
          decoration: BoxDecoration(
            color: selected ? t.selected : (hovered ? t.surfaceHover : null),
            border: Border(
              bottom: BorderSide(color: t.borderSubtle),
              top: _dropIndex == index ? BorderSide(color: t.primary, width: 2) : BorderSide.none,
            ),
          ),
          child: Row(spacing: t.space1, children: [
            if (widget.reorderable) _grip(t, touch, row, index),
            // On touch the toggles are 44px wide: the badge shows only where it leaves the name room.
            if (row.kind != null && !widget.compact && (!touch || widget.labelWidth >= 240))
              Opacity(opacity: row.muted ? 0.5 : 1, child: _KindBadge(row.kind!)),
            Expanded(
              child: Opacity(
                opacity: row.muted ? 0.5 : 1,
                child: Text(row.label, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false),
              ),
            ),
            ..._toggles(t, touch, row, showLock: !widget.compact, dim: !(hovered || touch)),
          ]),
        ),
      );
    });
  }

  Widget _grip(UiTokens t, bool touch, UiSequencerRow row, int index) {
    return _gestures(
      axis: Axis.vertical,
      cursor: SystemMouseCursors.grab,
      onDragStart: (d) => _begin(_Drag(kind: _Kind.reorder, row: row, index: index, startX: d.globalPosition.dx, unitsPerPx: _unitsPerPx)),
      onDragUpdate: (d) => _update(d.globalPosition),
      onDragEnd: (_) => _finish(),
      onDragCancel: () => _finish(cancelled: true),
      child: _HoverBuilder(
        builder: (context, hovered) => Padding(
          padding: EdgeInsets.symmetric(horizontal: touch ? 6 : (widget.compact ? 0 : 2)),
          child: SizedBox(
            width: 10,
            height: double.infinity,
            child: CustomPaint(painter: _GripPainter(hovered ? t.text : t.textMuted)),
          ),
        ),
      ),
    );
  }

  List<Widget> _toggles(UiTokens t, bool touch, UiSequencerRow row, {required bool showLock, required bool dim}) {
    final size = touch ? 32.0 : t.sizeSm;
    Widget toggle(bool on, UiIconData icon, String label, VoidCallback onTap) => UiInteractive(
          onTap: () {
            onTap();
            if (_tip != null) _keepTip();
          },
          toggled: on,
          semanticLabel: label,
          minTouchSize: const Size(44, uiMinTouchTarget),
          builder: (context, s) => Opacity(
            opacity: on || !dim || s.hovered || s.focused ? 1 : 0.7,
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.hovered ? t.surfaceHover : null,
                borderRadius: BorderRadius.circular(t.radiusXs),
                boxShadow: s.focused ? t.focusRing : null,
              ),
              child: UiIcon(icon, size: 14, color: s.hovered ? t.text : t.textMuted),
            ),
          ),
        );
    return [
      toggle(row.muted, row.muted ? HugeIcons.strokeRoundedViewOff : HugeIcons.strokeRoundedView, '${row.muted ? 'Show' : 'Hide'} ${row.label}', () => widget.onMuteToggle?.call(row.id)),
      if (showLock)
        toggle(row.locked, row.locked ? HugeIcons.strokeRoundedSquareLock02 : HugeIcons.strokeRoundedSquareUnlock02, '${row.locked ? 'Unlock' : 'Lock'} ${row.label}',
            () => widget.onLockToggle?.call(row.id)),
    ];
  }

  Widget _grid(UiTokens t, bool touch, double rowH, double viewW) {
    final rows = widget.rows;
    final end = widget.end;
    final tip = _tip;
    final tipIndex = tip == null ? -1 : rows.indexWhere((r) => r.id == tip.id);
    return Stack(clipBehavior: Clip.none, children: [
      for (var i = 0; i < rows.length; i++)
        Positioned(left: 0, width: _gridW, top: i * rowH, height: rowH, child: _lane(t, touch, rows[i], i, rowH)),
      if (rows.isEmpty)
        Positioned.fill(
          child: _gestures(
            onTapUp: (d) {
              _setPlayheadFromPointer(d.globalPosition);
              widget.onScrub?.call(_playhead);
            },
            child: const SizedBox.expand(),
          ),
        ),
      if (end != null && end < widget.length)
        Positioned(
          left: _x(end),
          right: 0,
          top: 0,
          bottom: 0,
          child: IgnorePointer(child: CustomPaint(painter: _BeyondPainter(stripe: t.text.withValues(alpha: 0.05), edge: t.borderStrong))),
        ),
      if (widget.endDraggable && end != null)
        Positioned(
          left: _x(end) - 5,
          width: 10,
          top: 0,
          bottom: 0,
          child: _gestures(
            cursor: SystemMouseCursors.resizeLeftRight,
            onDragStart: (d) => _begin(_Drag(kind: _Kind.pageEnd, startX: d.globalPosition.dx, unitsPerPx: _unitsPerPx, origAt: end)),
            onDragUpdate: (d) => _update(d.globalPosition),
            onDragEnd: (_) => _finish(),
            onDragCancel: () => _finish(cancelled: true),
            child: _HoverBuilder(
              builder: (context, hovered) => Center(
                child: Container(width: 2, color: hovered ? t.primary : t.textMuted.withValues(alpha: t.textMuted.a * 0.45)),
              ),
            ),
          ),
        ),
      Positioned(
        left: _x(_playhead) - 0.75,
        width: 1.5,
        top: 0,
        bottom: 0,
        child: IgnorePointer(child: ColoredBox(color: t.primary)),
      ),
      if (!widget.showLabels && _dropIndex != null && _dropIndex == rows.length)
        Positioned(left: 0, width: _gridW, top: rows.length * rowH - 1, height: 2, child: ColoredBox(color: t.primary)),
      if (tip != null && tipIndex >= 0) _tipWidget(t, touch, rows[tipIndex], tipIndex, rowH, viewW),
    ]);
  }

  Widget _tipWidget(UiTokens t, bool touch, UiSequencerRow row, int index, double rowH, double viewW) {
    final tip = _tip!;
    final below = index == 0;
    final x = tip.x ?? _x((row.start + row.end) / 2);
    final top = below ? rowH : index * rowH;
    final fx = tip.edge < 0 ? 0.0 : tip.edge > 0 ? -1.0 : -0.5;
    final px = tip.edge < 0 ? -12.0 : tip.edge > 0 ? 12.0 : 0.0;
    Widget bubble = Container(
      constraints: BoxConstraints(maxWidth: math.min(260, viewW * 0.8)),
      padding: EdgeInsetsDirectional.only(start: t.space3, end: 2, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(t.radiusPill),
        border: Border.all(color: t.border),
        boxShadow: t.shadow2,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
        if (row.kind != null) _KindBadge(row.kind!),
        Flexible(child: Text(row.label, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, style: const TextStyle(fontWeight: FontWeight.w600))),
        ..._toggles(t, touch, row, showLock: true, dim: false),
      ]),
    );
    if (context.uiAnimate) {
      bubble = TweenAnimationBuilder<double>(
        key: ValueKey(tip),
        tween: Tween(begin: 0, end: 1),
        duration: t.motionFast,
        curve: t.easeDecelerate,
        builder: (context, v, child) => Opacity(opacity: v, child: Transform.scale(scale: 0.92 + 0.08 * v, child: child)),
        child: bubble,
      );
    }
    return Positioned(
      left: x,
      top: top,
      child: Transform.translate(
        offset: Offset(px, below ? 2 : -2),
        child: FractionalTranslation(
          translation: Offset(fx, below ? 0 : -1),
          child: Semantics(liveRegion: true, container: true, child: bubble),
        ),
      ),
    );
  }

  Widget _lane(UiTokens t, bool touch, UiSequencerRow row, int index, double rowH) {
    final selected = row.id == _row;
    final left = _x(row.start);
    final width = math.max(6.0, _x(row.end) - _x(row.start));
    final barH = rowH - 1;
    final edgeW = touch ? 22.0 : 16.0;
    final edgeOut = touch ? 22.0 : 14.0;
    final diamondW = touch ? uiMinTouchTarget : 24.0;
    final diamondH = touch ? math.min(uiMinTouchTarget, rowH) : 24.0;
    final lifted = _liftedId == row.id;
    final barsOnly = !widget.showLabels;
    final showEdges = !row.fixed && !row.locked;

    Widget edge(bool start) => Positioned(
          left: start ? left - edgeOut : left + width - (edgeW - edgeOut),
          width: edgeW,
          top: 0,
          height: barH,
          child: _gestures(
            cursor: SystemMouseCursors.resizeLeftRight,
            onDragStart: (d) => _startBar(row, start ? _Kind.start : _Kind.end, d.globalPosition),
            onDragUpdate: (d) => _update(d.globalPosition),
            onDragEnd: (_) => _finish(),
            onDragCancel: () => _finish(cancelled: true),
            child: touch && selected
                ? Align(
                    alignment: start ? Alignment.centerRight : Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3, vertical: barH * 0.2),
                      child: Container(width: 4, decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(2))),
                    ),
                  )
                : const SizedBox.expand(),
          ),
        );

    final bar = Positioned(
      left: left,
      width: width,
      top: 0,
      height: barH,
      child: _Focusable(
        onFocus: () => _selectRow(row.id),
        onKey: (e) => _barKey(e, row),
        builder: (context, ring) => Semantics(
          button: true,
          selected: selected,
          label: '${row.label}: ${row.start.round()} to ${row.end.round()}',
          onTap: () => _selectRow(row.id),
          child: _gestures(
            cursor: row.locked ? SystemMouseCursors.forbidden : SystemMouseCursors.grab,
            onTapDown: barsOnly ? null : (_) => _selectRow(row.id),
            onTapUp: barsOnly
                ? (d) {
                    _selectRow(row.id);
                    _showTip(row.id, d.globalPosition);
                  }
                : null,
            longPress: barsOnly ? _liftDelay : null,
            onLongPressStart: barsOnly ? (d) => _startLift(row, d.globalPosition) : null,
            onLongPressMoveUpdate: barsOnly ? (d) => _moveLift(d.globalPosition) : null,
            onLongPressEnd: barsOnly ? (_) => _endLift() : null,
            // Bars-only: a finger's swipe scrolls; the mouse and pen still drag.
            dragDevices: barsOnly ? const {PointerDeviceKind.mouse, PointerDeviceKind.stylus, PointerDeviceKind.invertedStylus, PointerDeviceKind.trackpad} : null,
            onDragStart: row.locked ? null : (d) => _startBar(row, _Kind.move, d.globalPosition),
            onDragUpdate: (d) => _update(d.globalPosition),
            onDragEnd: (_) => _finish(),
            onDragCancel: () => _finish(cancelled: true),
            child: _HoverBuilder(
              builder: (context, hovered) => _BarVisual(
                selected: selected,
                hovered: hovered && !row.locked,
                muted: row.muted,
                locked: row.locked,
                lifted: lifted,
                ring: ring,
                animate: context.uiAnimate,
              ),
            ),
          ),
        ),
      ),
    );

    return Stack(clipBehavior: Clip.none, children: [
      Positioned.fill(
        child: _gestures(
          onTapUp: (d) {
            _hideTip();
            _setPlayheadFromPointer(d.globalPosition);
            widget.onScrub?.call(_playhead);
          },
          dragDevices: const {PointerDeviceKind.mouse, PointerDeviceKind.stylus, PointerDeviceKind.invertedStylus},
          onDragStart: (d) {
            _setPlayheadFromPointer(d.globalPosition);
            _begin(_Drag(kind: _Kind.playhead, startX: d.globalPosition.dx, unitsPerPx: _unitsPerPx));
          },
          onDragUpdate: (d) => _update(d.globalPosition),
          onDragEnd: (_) => _finish(),
          onDragCancel: () => _finish(cancelled: true),
          child: CustomPaint(
            painter: _LanePainter(
              fill: selected ? t.selected.withValues(alpha: t.selected.a * 0.6) : null,
              divider: t.borderSubtle,
              gridline: t.borderSubtle,
              gridlines: [for (final m in widget.markers) _x(m.at)],
              dropBefore: barsOnly && _dropIndex == index ? t.primary : null,
            ),
          ),
        ),
      ),
      if (lifted) ...[bar] else bar,
      if (showEdges) ...[edge(true), edge(false)],
      for (final k in row.keyframes)
        Positioned(
          left: left + k.at * width - diamondW / 2,
          width: diamondW,
          top: (barH - diamondH) / 2,
          height: diamondH,
          child: _Focusable(
            onFocus: () {
              _selectRow(row.id);
              _selectKeyframe(k.id);
            },
            onKey: (e) => _keyframeKey(e, row, k, context),
            builder: (fctx, ring) => Semantics(
              button: true,
              selected: k.id == _keyframe,
              label: k.label == null || k.label!.isEmpty ? 'Keyframe at ${(k.at * 100).round()}%' : 'Keyframe ${k.label} at ${(k.at * 100).round()}%',
              onTap: () {
                _selectRow(row.id);
                _selectKeyframe(k.id);
              },
              child: _gestures(
                cursor: SystemMouseCursors.resizeLeftRight,
                onTapDown: (_) {
                  _selectRow(row.id);
                  _selectKeyframe(k.id);
                },
                onTapUp: barsOnly ? (d) => _showTip(row.id, d.globalPosition) : null,
                onSecondaryTapUp: (d) => _openMenu(row, k, d.globalPosition),
                longPress: kLongPressTimeout,
                onLongPressStart: (d) => _openMenu(row, k, d.globalPosition),
                onDragStart: row.locked ? null : (d) => _startKeyframe(row, k, d.globalPosition),
                onDragUpdate: (d) => _update(d.globalPosition),
                onDragEnd: (_) => _finish(),
                onDragCancel: () => _finish(cancelled: true),
                child: Center(
                  child: _Diamond(size: touch ? 14 : 10, selected: k.id == _keyframe, ring: ring),
                ),
              ),
            ),
          ),
        ),
    ]);
  }

  /// One gesture detector per part, with the drag limited to [dragDevices] when given.
  Widget _gestures({
    required Widget child,
    MouseCursor cursor = MouseCursor.defer,
    Axis axis = Axis.horizontal,
    GestureTapDownCallback? onTapDown,
    GestureTapUpCallback? onTapUp,
    GestureTapUpCallback? onSecondaryTapUp,
    Duration? longPress,
    GestureLongPressStartCallback? onLongPressStart,
    GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate,
    GestureLongPressEndCallback? onLongPressEnd,
    Set<PointerDeviceKind>? dragDevices,
    GestureDragStartCallback? onDragStart,
    GestureDragUpdateCallback? onDragUpdate,
    GestureDragEndCallback? onDragEnd,
    GestureDragCancelCallback? onDragCancel,
  }) {
    // The device's own slop, as GestureDetector applies it: hand-built recognizers default to 18,
    // so on a phone (about 8) the scroll view around would claim every drag first.
    final settings = MediaQuery.maybeGestureSettingsOf(context);
    final gestures = <Type, GestureRecognizerFactory>{};
    if (onTapDown != null || onTapUp != null || onSecondaryTapUp != null) {
      gestures[TapGestureRecognizer] = GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(TapGestureRecognizer.new, (r) {
        r
          ..gestureSettings = settings
          ..onTapDown = onTapDown
          ..onTapUp = onTapUp
          ..onSecondaryTapUp = onSecondaryTapUp;
      });
    }
    if (onLongPressStart != null) {
      gestures[LongPressGestureRecognizer] = GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
        () => LongPressGestureRecognizer(duration: longPress ?? kLongPressTimeout),
        (r) {
          r
            ..gestureSettings = settings
            ..onLongPressStart = onLongPressStart
            ..onLongPressMoveUpdate = onLongPressMoveUpdate
            ..onLongPressEnd = onLongPressEnd;
        },
      );
    }
    if (onDragStart != null) {
      void setup(DragGestureRecognizer r) {
        r
          ..gestureSettings = settings
          ..dragStartBehavior = DragStartBehavior.down
          ..onStart = onDragStart
          ..onUpdate = onDragUpdate
          ..onEnd = onDragEnd
          ..onCancel = onDragCancel;
      }

      if (axis == Axis.horizontal) {
        gestures[HorizontalDragGestureRecognizer] =
            GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(() => HorizontalDragGestureRecognizer(supportedDevices: dragDevices), setup);
      } else {
        gestures[VerticalDragGestureRecognizer] =
            GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer(supportedDevices: dragDevices), setup);
      }
    }
    return MouseRegion(
      cursor: cursor,
      child: RawGestureDetector(behavior: HitTestBehavior.opaque, excludeFromSemantics: true, gestures: gestures, child: child),
    );
  }
}

/// Two fingers that spread or pinch: claims the gesture only once there are two and their spread
/// has changed, so a single finger is left to scroll, tap, drag or hold.
class _PinchRecognizer extends OneSequenceGestureRecognizer {
  void Function(Offset focal)? onStart;
  void Function(double ratio)? onUpdate;
  VoidCallback? onEnd;

  final Map<int, Offset> _points = {};
  double? _startSpan;
  bool _active = false;

  double get _span {
    final p = _points.values.take(2).toList();
    return (p[0] - p[1]).distance;
  }

  Offset get _focal {
    final p = _points.values.take(2).toList();
    return (p[0] + p[1]) / 2;
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _points[event.pointer] = event.position;
    if (_points.length == 2) _startSpan = math.max(1, _span);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _points[event.pointer] = event.position;
      final start = _startSpan;
      if (_points.length >= 2 && start != null) {
        final span = _span;
        if (!_active && (span - start).abs() > 8) {
          _active = true;
          resolve(GestureDisposition.accepted);
          onStart?.call(_focal);
        }
        if (_active) onUpdate?.call(span / start);
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _points.remove(event.pointer);
      stopTrackingPointer(event.pointer);
      if (_points.length < 2) {
        _startSpan = null;
        if (_active) {
          _active = false;
          onEnd?.call();
        }
      }
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    if (!_active) resolve(GestureDisposition.rejected);
    _points.clear();
    _startSpan = null;
  }

  @override
  String get debugDescription => 'sequencer pinch';
}

/// Focus + key handling with a ring only for keyboard users.
class _Focusable extends StatefulWidget {
  const _Focusable({required this.builder, this.onKey, this.onFocus});
  final Widget Function(BuildContext context, bool ring) builder;
  final KeyEventResult Function(KeyEvent e)? onKey;
  final VoidCallback? onFocus;

  @override
  State<_Focusable> createState() => _FocusableState();
}

class _FocusableState extends State<_Focusable> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onMode);
    super.dispose();
  }

  void _onMode(FocusHighlightMode _) {
    if (_focused) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) {
        setState(() => _focused = v);
        if (v) widget.onFocus?.call();
      },
      onKeyEvent: (node, e) => e is KeyUpEvent || widget.onKey == null ? KeyEventResult.ignored : widget.onKey!(e),
      child: Builder(builder: (context) => widget.builder(context, _focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional)),
    );
  }
}

class _HoverBuilder extends StatefulWidget {
  const _HoverBuilder({required this.builder});
  final Widget Function(BuildContext context, bool hovered) builder;

  @override
  State<_HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<_HoverBuilder> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        opaque: false,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: widget.builder(context, _hovered),
      );
}

class _KindBadge extends StatelessWidget {
  const _KindBadge(this.kind);
  final String kind;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    // One width for every badge (SVG, TEXT, RSVP…), so the names after them start in one column.
    return Container(
      constraints: const BoxConstraints(minWidth: 11 * 4.5),
      padding: EdgeInsets.symmetric(horizontal: t.space1),
      decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radiusXs)),
      child: Text(kind.toUpperCase(), maxLines: 1, overflow: TextOverflow.clip, softWrap: false, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, height: 14 / 11, letterSpacing: 11 * 0.04, color: t.textMuted)),
    );
  }
}

/// The bar's box fills the lane; the visible bar is inset 5px top and bottom, so short rows don't
/// shrink what has to be hit.
class _BarVisual extends StatelessWidget {
  const _BarVisual({required this.selected, required this.hovered, required this.muted, required this.locked, required this.lifted, required this.ring, required this.animate});
  final bool selected, hovered, muted, locked, lifted, ring, animate;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final r = BorderRadius.circular(context.uiTheme.radius(t.radiusSm));
    final fill = uiMix(t.primary, lifted ? 0.48 : selected ? 0.38 : 0.22, t.surface);
    final border = selected || hovered ? t.primary : t.primary.withValues(alpha: 0.55);
    Widget bar = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: r,
          border: Border.all(color: border),
          boxShadow: [if (lifted) ...t.shadow2, if (ring) ...t.focusRing],
        ),
        foregroundDecoration: null,
        child: locked ? ClipRRect(borderRadius: r, child: CustomPaint(painter: _StripePainter(t.text.withValues(alpha: 0.08), 7, 2), child: const SizedBox.expand())) : null,
      ),
    );
    if (muted) bar = Opacity(opacity: 0.45, child: bar);
    if (lifted && animate) bar = Transform(alignment: Alignment.center, transform: Matrix4.diagonal3Values(1.04, 1.25, 1), child: bar);
    return bar;
  }
}

class _Diamond extends StatelessWidget {
  const _Diamond({required this.size, required this.selected, required this.ring});
  final double size;
  final bool selected, ring;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: selected ? t.primary : t.surface,
          border: Border.all(color: t.primary, width: 1.5),
          boxShadow: ring ? t.focusRing : null,
        ),
      ),
    );
  }
}

class _EndHandle extends StatelessWidget {
  const _EndHandle({required this.label, required this.value, required this.onKey, required this.gestures});
  final String label;
  final int value;
  final KeyEventResult Function(KeyEvent e) onKey;
  final Widget Function(Widget child) gestures;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return _Focusable(
      onKey: onKey,
      builder: (context, ring) => Semantics(
        slider: true,
        label: label,
        value: '$value',
        child: gestures(
          _HoverBuilder(
            builder: (context, hovered) {
              final on = hovered || ring;
              return Center(
                child: FractionallySizedBox(
                  heightFactor: 0.7,
                  child: Transform.scale(
                    scaleX: on ? 1.3 : 1,
                    child: Container(
                      width: 6,
                      decoration: BoxDecoration(
                        color: on ? t.primary : t.textMuted,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: ring ? t.focusRing : null,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The playhead's pointer: a pentagon pointing down.
class _KnobPainter extends CustomPainter {
  const _KnobPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(s.width, 0)
        ..lineTo(s.width, s.height * 0.55)
        ..lineTo(s.width / 2, s.height)
        ..lineTo(0, s.height * 0.55)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_KnobPainter old) => old.color != color;
}

/// Six dots: the reorder grip.
class _GripPainter extends CustomPainter {
  const _GripPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color;
    final cy = s.height / 2;
    for (final dx in [-2.5, 2.5]) {
      for (final dy in [-4.0, 0.0, 4.0]) {
        canvas.drawCircle(Offset(s.width / 2 + dx, cy + dy), 1.1, p);
      }
    }
  }

  @override
  bool shouldRepaint(_GripPainter old) => old.color != color;
}

class _LanePainter extends CustomPainter {
  const _LanePainter({required this.fill, required this.divider, required this.gridline, required this.gridlines, required this.dropBefore});
  final Color? fill;
  final Color divider, gridline;
  final List<double> gridlines;
  final Color? dropBefore;

  @override
  void paint(Canvas canvas, Size s) {
    if (fill != null) canvas.drawRect(Offset.zero & s, Paint()..color = fill!);
    final dash = Paint()..color = gridline;
    for (final x in gridlines) {
      for (var y = 0.0; y < s.height; y += 4) {
        canvas.drawRect(Rect.fromLTWH(x, y, 1, math.min(2, s.height - y)), dash);
      }
    }
    canvas.drawRect(Rect.fromLTWH(0, s.height - 1, s.width, 1), Paint()..color = divider);
    if (dropBefore != null) canvas.drawRect(Rect.fromLTWH(0, 0, s.width, 2), Paint()..color = dropBefore!);
  }

  @override
  bool shouldRepaint(_LanePainter old) =>
      old.fill != fill || old.divider != divider || old.gridline != gridline || !listEquals(old.gridlines, gridlines) || old.dropBefore != dropBefore;
}

/// Diagonal stripes (135°), for locked bars and what lies past the end.
class _StripePainter extends CustomPainter {
  const _StripePainter(this.color, this.period, this.width);
  final Color color;
  final double period, width;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = width;
    canvas.save();
    canvas.clipRect(Offset.zero & s);
    for (var x = -s.height; x < s.width; x += period) {
      canvas.drawLine(Offset(x, s.height), Offset(x + s.height, 0), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.color != color || old.period != period || old.width != width;
}

class _BeyondPainter extends CustomPainter {
  const _BeyondPainter({required this.stripe, required this.edge});
  final Color stripe, edge;

  @override
  void paint(Canvas canvas, Size s) {
    _StripePainter(stripe, 12, 4.2).paint(canvas, s);
    final p = Paint()..color = edge;
    for (var y = 0.0; y < s.height; y += 6) {
      canvas.drawRect(Rect.fromLTWH(0, y, 1.5, math.min(3, s.height - y)), p);
    }
  }

  @override
  bool shouldRepaint(_BeyondPainter old) => old.stripe != stripe || old.edge != edge;
}
