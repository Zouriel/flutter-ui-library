import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../theme/theme.dart';
import 'ink.dart';
import 'path.dart';

/// What a press does in a [UiPathEditor].
enum UiPathEditorMode { objects, points, pen, draw }

/// A finished stroke in draw mode: what was drawn, and the area it paints (see `ink.dart`).
@immutable
class UiInkStroke {
  const UiInkStroke({required this.samples, required this.brush, required this.pieces, this.shape});
  final List<UiInkSample> samples;
  final UiBrush brush;

  /// Convex pieces whose union is the painted area ([inkPath] draws them).
  final List<List<Offset>> pieces;

  /// Set when the stroke was held at the end and snapped to a shape.
  final UiInkShape? shape;
}

const Duration _longPress = Duration(milliseconds: 450);
const Duration _holdToSnap = Duration(milliseconds: 600);
const Duration _doubleTap = Duration(milliseconds: 320);
int _itemSeq = 0;

/// `ui-path-editor`: a vector editing surface. It draws [items] (outlines made of points with
/// optional curve handles, see `path.dart`) over an artboard and lets them be edited with a finger,
/// a pen or a mouse. Four modes:
///
/// - **objects**: tap an item to select it, drag to move it, the corner knobs scale it and the top
///   knob rotates it.
/// - **points** (Direct Selection): the selected item's points and handles show. Drag a point or a
///   handle; tap an edge to add a point; double-tap a point to switch it between corner and curve;
///   Shift-tap or long-press to select several and move them together; drag across empty space with
///   a mouse or pen to select a box of them. Alt-drag a handle to bend one side only (or set
///   [freeHandles]), Alt-drag a corner to pull curve handles out of it, Shift keeps to 45 degrees.
/// - **pen**: tap to place corners, drag to place a curve, tap the first point to close the shape,
///   tap the last point (or press Enter) to finish an open line. Starting on a loose end of the
///   selected item carries that line on.
/// - **draw**: paint with [brush]. Pens report pressure; a finger or mouse gets it from speed. Once
///   a pen has been used, fingers move the view instead of drawing (palm rejection, [fingerDraws]
///   null = auto). Hold still at the end of a stroke to snap it to a line, circle, ellipse,
///   rectangle or triangle. Each finished stroke is reported through [onStroke].
///
/// The view zooms with a two-finger pinch or the mouse wheel, and pans by dragging empty space (or
/// with two fingers). It never changes [items]: a finished gesture is reported once through
/// [onItemsChanged], so the host owns undo. While a gesture runs, a draft is drawn instead.
///
/// Keyboard: `]` / `[` step the selection through the items, Escape clears points then the item,
/// arrows nudge (Shift for 10), Delete removes selected points, Ctrl/Cmd+A selects every point, and
/// in pen mode Enter or Escape finishes and Backspace takes back the last point. Reach [fit],
/// [UiPathEditorState.zoomBy], [UiPathEditorState.finishPen] and friends with a
/// `GlobalKey<UiPathEditorState>`.
class UiPathEditor extends StatefulWidget {
  const UiPathEditor({
    super.key,
    required this.items,
    this.onItemsChanged,
    this.width = 100,
    this.height = 100,
    this.mode = UiPathEditorMode.objects,
    this.selectedId,
    this.onSelectedIdChanged,
    this.selectedPoint,
    this.onSelectedPointChanged,
    this.selectedPoints = const [],
    this.onSelectedPointsChanged,
    this.showArtboard = true,
    this.lockAspect = false,
    this.label = 'Shape editor',
    this.brush = const UiBrush(),
    this.fill,
    this.fingerDraws,
    this.snapToShape = true,
    this.freeHandles = false,
    this.onPointTap,
    this.onStroke,
    this.onPenDetected,
    this.onPenCountChanged,
  });

  final List<UiPathItem> items;

  /// A finished edit: the whole list, for the host to keep (and undo).
  final ValueChanged<List<UiPathItem>>? onItemsChanged;

  /// The artboard, in editor units. The view fits it on first layout and on [UiPathEditorState.fit].
  final double width;
  final double height;
  final UiPathEditorMode mode;
  final String? selectedId;
  final ValueChanged<String?>? onSelectedIdChanged;

  /// The point being worked on (the last one touched).
  final UiPointRef? selectedPoint;
  final ValueChanged<UiPointRef?>? onSelectedPointChanged;

  /// Every selected point of the selected item; [selectedPoint] is among them.
  final List<UiPointRef> selectedPoints;
  final ValueChanged<List<UiPointRef>>? onSelectedPointsChanged;
  final bool showArtboard;

  /// Keep proportions when scaling with the corner knobs (Shift does it once).
  final bool lockAspect;

  /// Accessible name.
  final String label;
  final UiBrush brush;

  /// Paint for ink as it goes down and for items the pen makes.
  final Color? fill;

  /// Whether a finger draws in draw mode; null (auto): until a pen is used, then fingers pan and
  /// zoom and a resting palm doesn't draw.
  final bool? fingerDraws;

  /// Hold at the end of a stroke to snap it to a shape.
  final bool snapToShape;

  /// Handles move independently (what Alt does once), for touch where there's no Alt key.
  final bool freeHandles;

  /// A point was tapped (not dragged), e.g. to pick ends to join.
  final ValueChanged<UiPointRef>? onPointTap;
  final ValueChanged<UiInkStroke>? onStroke;

  /// A pen touched the surface for the first time.
  final VoidCallback? onPenDetected;

  /// How many points the pen has placed on the path it is drawing (0 when none), for toolbars.
  final ValueChanged<int>? onPenCountChanged;

  @override
  State<UiPathEditor> createState() => UiPathEditorState();
}

enum _G { point, handle, convert, item, corner, rotate, segment, marquee, ink, anchor, empty }

class _Gesture {
  _Gesture(this.kind, {this.ref, this.handleSide, this.itemId, this.group = const [], this.before = const [], this.selectSingle = false, this.corner, this.box, this.contour = 0, this.segment = 0, this.additive = false, this.index = 0, this.closing = false, this.last = false});
  final _G kind;
  final UiPointRef? ref;
  final UiHandleSide? handleSide;
  final String? itemId;
  final List<UiPointRef> group;
  final List<UiPointRef> before;
  final bool selectSingle;

  /// Corner as (sx, sy): -1 left/top, 1 right/bottom.
  final (int, int)? corner;
  final Rect? box;
  final int contour;
  final int segment;
  final bool additive;
  final int index;
  final bool closing;
  final bool last;
}

class _Drag {
  _Drag({required this.gesture, required this.pointer, required this.kind, required this.startLocal, required this.startUnits, required this.startCenter, required this.origin});
  final _Gesture gesture;
  final int pointer;
  final PointerDeviceKind kind;
  final Offset startLocal;
  final Offset startUnits;
  final Offset startCenter;
  final List<UiPathItem> origin;
  bool moved = false;

  /// A long press already did something; the release shouldn't.
  bool pressed = false;
}

class _Ink {
  _Ink({required this.brush, required this.samples, required this.radii, required this.pieces, required this.raw, required this.holdFrom, required this.pen});
  final UiBrush brush;
  final List<UiInkSample> samples;
  final List<double> radii;
  final List<List<Offset>> pieces;
  double along = 0;

  /// Where the pointer really is (the samples trail it when the stroke is steadied).
  UiInkSample raw;
  UiInkShape? snapped;
  Offset holdFrom;
  final bool pen;
}

class UiPathEditorState extends State<UiPathEditor> {
  final FocusNode _focus = FocusNode(debugLabel: 'UiPathEditor');
  bool _ring = false;

  List<UiPathItem>? _draft;
  List<UiPathItem> get _view => _draft ?? widget.items;

  Size _size = Size.zero;
  double _zoom = 1;
  Offset _center = const Offset(50, 50);
  bool _fitted = false;

  late String? _selectedId = widget.selectedId;
  late UiPointRef? _selectedPoint = widget.selectedPoint;
  late List<UiPointRef> _selectedPoints = widget.selectedPoints;

  _Ink? _ink;
  List<List<Offset>>? _inkSnapPieces;
  Timer? _holdTimer;
  bool _penSeen = false;

  List<UiPathPoint> _pen = const [];
  ({String itemId, int contour})? _penTarget;
  Offset? _hover;
  String? _hoverItem;

  Rect? _marquee;
  ({String key, DateTime at})? _lastTap;
  Timer? _pressTimer;

  _Drag? _drag;
  final Map<int, Offset> _pointers = {};
  ({double dist, double zoom, Offset world})? _pinch;

  bool get _touch => uiTouchPlatform(context);
  double get _knob => _touch ? 9 : 6;

  /// Points the pen has placed on the path it is drawing.
  int get penCount => _pen.length;

  @override
  void didUpdateWidget(UiPathEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (widget.selectedId != old.selectedId) _selectedId = widget.selectedId;
    if (!listEquals(widget.selectedPoints, old.selectedPoints)) _selectedPoints = widget.selectedPoints;
    if (widget.selectedPoint != old.selectedPoint) {
      _selectedPoint = widget.selectedPoint;
      // The point the host sets (or clears) is the selection, unless it's already part of it.
      if (_selectedPoint == null) {
        _selectedPoints = const [];
      } else if (!_selectedPoints.contains(_selectedPoint)) {
        _selectedPoints = [_selectedPoint!];
      }
    }
    // A new artboard is a new drawing: frame it.
    if (widget.width != old.width || widget.height != old.height) _fitted = false;
    if (widget.mode != old.mode) {
      // Leaving the pen finishes the path it was drawing; leaving draw mode drops a stroke.
      if (old.mode == UiPathEditorMode.pen && _pen.isNotEmpty) {
        final pts = _pen;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && identical(_pen, pts)) finishPen(false);
        });
      }
      if (widget.mode != UiPathEditorMode.draw) _dropInk();
      _marquee = null;
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _pressTimer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  // ----- selection, reported ---------------------------------------------------------------------

  void _setSelectedId(String? id) {
    if (id == _selectedId) return;
    _selectedId = id;
    widget.onSelectedIdChanged?.call(id);
  }

  void _setPoint(UiPointRef? ref) {
    _selectedPoint = ref;
    widget.onSelectedPointChanged?.call(ref);
  }

  void _setPoints(List<UiPointRef> refs) {
    _selectedPoints = refs;
    widget.onSelectedPointsChanged?.call(refs);
  }

  void _clearPoint() {
    _setPoint(null);
    if (_selectedPoints.isNotEmpty) _setPoints(const []);
  }

  void _emit(List<UiPathItem> items) => widget.onItemsChanged?.call(items);

  void _setPen(List<UiPathPoint> pts) {
    final changed = pts.length != _pen.length;
    _pen = pts;
    if (changed) widget.onPenCountChanged?.call(pts.length);
  }

  // ----- view ------------------------------------------------------------------------------------

  /// Screen pixels per editor unit.
  double get _px {
    if (_size.isEmpty) return 1;
    final fit = math.min(_size.width / (widget.width * 1.35), _size.height / (widget.height * 1.35));
    return math.max(0.01, fit * _zoom);
  }

  Offset _toUnits(Offset local, {Offset? center, double? px}) {
    final c = center ?? _center, p = px ?? _px;
    return c + (local - _size.center(Offset.zero)) / p;
  }

  Offset _toLocal(Offset units) => (units - _center) * _px + _size.center(Offset.zero);

  /// Frames the artboard and everything drawn, whichever reaches further.
  void fit() => setState(_fit);

  void _fit() {
    final w = widget.width, h = widget.height;
    final drawn = pathBounds([for (final i in widget.items) ...i.contours]);
    final x0 = math.min(0.0, drawn?.left ?? 0), y0 = math.min(0.0, drawn?.top ?? 0);
    final x1 = math.max(w, drawn?.right ?? w), y1 = math.max(h, drawn?.bottom ?? h);
    if (!_size.isEmpty) {
      final base = math.min(_size.width / (w * 1.35), _size.height / (h * 1.35));
      final want = math.min(_size.width / ((x1 - x0) * 1.35), _size.height / ((y1 - y0) * 1.35));
      _zoom = (want / base).clamp(0.2, 20);
    } else {
      _zoom = 1;
    }
    _center = Offset((x0 + x1) / 2, (y0 + y1) / 2);
  }

  /// Zooms by [factor] about the middle of the view.
  void zoomBy(double factor) => setState(() => _zoom = (_zoom * factor).clamp(0.2, 20));

  /// Selects every point of the selected item.
  void selectAllPoints() {
    final it = _selectedItem;
    if (it == null) return;
    final all = allPoints(it.contours);
    setState(() {
      _setPoints(all);
      _setPoint(all.isEmpty ? null : all.last);
    });
  }

  /// Ends the path the pen is drawing: as a closed shape, or an open line. A new path becomes a
  /// new item (selected); a line that was being carried on is replaced.
  void finishPen(bool closed) {
    final pts = _pen;
    final target = _penTarget;
    setState(() {
      _setPen(const []);
      _penTarget = null;
      _hover = null;
    });
    if (pts.length < 2) return;
    final contour = UiPathContour(closed: closed, points: pts);
    final items = widget.items;
    if (target != null) {
      final owner = items.where((i) => i.id == target.itemId).firstOrNull;
      if (owner != null) {
        final contours = [for (var i = 0; i < owner.contours.length; i++) i == target.contour ? contour : owner.contours[i]];
        _emit([for (final i in items) identical(i, owner) ? i.copyWith(contours: contours) : i]);
        return;
      }
    }
    final item = UiPathItem(id: 'path${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_itemSeq++}', contours: [contour], fill: widget.fill);
    _emit([...items, item]);
    setState(() {
      _setSelectedId(item.id);
      _clearPoint();
    });
  }

  /// Takes back the pen's last point (Backspace does the same).
  void undoPenPoint() => setState(() => _setPen(_pen.isEmpty ? _pen : _pen.sublist(0, _pen.length - 1)));

  /// Throws away the path the pen is drawing.
  void cancelPen() => setState(() {
        _setPen(const []);
        _penTarget = null;
      });

  UiPathItem? get _selectedItem => _view.where((i) => i.id == _selectedId).firstOrNull;
  Rect? get _selectedBox {
    final it = _selectedItem;
    return it == null ? null : pathBounds(it.contours);
  }

  /// Handles of the selected points (the most recent few, so a big selection stays readable).
  List<({UiPointRef ref, UiHandleSide side, Offset from, Offset at})> get _handles {
    final it = _selectedItem;
    if (it == null) return const [];
    final refs = _selectedPoints.length > 8 ? _selectedPoints.sublist(_selectedPoints.length - 8) : _selectedPoints;
    return [
      for (final ref in refs)
        if (ref.contour < it.contours.length && ref.point < it.contours[ref.contour].points.length) ...() {
          final p = it.contours[ref.contour].points[ref.point];
          return [
            if (p.handleIn != null) (ref: ref, side: UiHandleSide.handleIn, from: p.offset, at: p.handleIn!),
            if (p.handleOut != null) (ref: ref, side: UiHandleSide.handleOut, from: p.offset, at: p.handleOut!),
          ];
        }(),
    ];
  }

  /// Within a finger's reach of a point, on screen.
  bool _near(Offset a, Offset b) => (a - b).distance * _px < _knob * 2.2;

  /// The hit radius for knobs, in screen pixels.
  double get _hit => _touch ? 22 : _knob + 4;

  // ----- pointer ---------------------------------------------------------------------------------

  void _down(PointerDownEvent e) {
    if (e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryButton) return;
    final mode = widget.mode;
    final stylus = e.kind == PointerDeviceKind.stylus || e.kind == PointerDeviceKind.invertedStylus;
    if (mode == UiPathEditorMode.draw && stylus && !_penSeen) {
      _penSeen = true;
      widget.onPenDetected?.call();
    }
    // A pen is drawing: anything else touching the screen is a hand resting on it.
    if (_ink?.pen == true && e.kind == PointerDeviceKind.touch) return;
    _focus.requestFocus();
    _pointers[e.pointer] = e.localPosition;

    if (_pointers.length == 2) {
      // A second finger: whatever the first one was doing becomes a pinch.
      setState(() {
        _draft = null;
        _drag = null;
        _dropInk();
        _clearPress();
        _marquee = null;
        final pts = _pointers.values.toList();
        final mid = (pts[0] + pts[1]) / 2;
        final dist = (pts[0] - pts[1]).distance;
        _pinch = (dist: dist == 0 ? 1 : dist, zoom: _zoom, world: _toUnits(mid));
      });
      return;
    }
    if (_pointers.length > 2) return;

    final units = _toUnits(e.localPosition);
    final _Gesture g;
    if (mode == UiPathEditorMode.draw) {
      g = _fingerNavigates(e) ? _Gesture(_G.empty) : _Gesture(_G.ink);
    } else if (mode == UiPathEditorMode.pen) {
      g = _penDown(units);
    } else {
      g = _editDown(e, units);
    }
    _drag = _Drag(gesture: g, pointer: e.pointer, kind: e.kind, startLocal: e.localPosition, startUnits: units, startCenter: _center, origin: widget.items);
    if (g.kind == _G.ink) _startInk(e, units);
    if (g.kind == _G.point && e.kind != PointerDeviceKind.mouse) {
      // Long press adds the point to the selection (or takes it out): the touch Shift-click.
      _pressTimer = Timer(_longPress, _longPressPoint);
    }
    setState(() {});
  }

  bool _fingerNavigates(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.touch) return false;
    final setting = widget.fingerDraws;
    return setting == null ? _penSeen : !setting;
  }

  /// What a press means in objects and points modes: the top-most thing under it.
  _Gesture _editDown(PointerDownEvent e, Offset units) {
    final selected = _selectedItem;
    final mode = widget.mode;
    final keys = HardwareKeyboard.instance;
    final local = e.localPosition;
    bool hits(Offset at) => (_toLocal(at) - local).distance <= _hit;

    if (mode == UiPathEditorMode.points && selected != null) {
      // Points sit above handles, which sit above the edges.
      for (var ci = 0; ci < selected.contours.length; ci++) {
        final pts = selected.contours[ci].points;
        for (var pi = pts.length - 1; pi >= 0; pi--) {
          if (!hits(pts[pi].offset)) continue;
          final ref = UiPointRef(ci, pi);
          final before = _selectedPoints;
          final inSelection = before.contains(ref);
          if (keys.isAltPressed) return _Gesture(_G.convert, ref: ref, itemId: selected.id);
          if (keys.isShiftPressed) {
            // Shift-tap: add it (or take it out) and carry on dragging the whole selection.
            final next = inSelection ? before.where((r) => r != ref).toList() : [...before, ref];
            _setPoints(next);
            _setPoint(inSelection ? (next.isEmpty ? null : next.last) : ref);
            return _Gesture(_G.point, ref: ref, itemId: selected.id, group: next, before: before);
          }
          if (inSelection) {
            _setPoint(ref);
            return _Gesture(_G.point, ref: ref, itemId: selected.id, group: before, before: before);
          }
          // A plain press on another point selects just it, once it's clear this isn't a long press.
          return _Gesture(_G.point, ref: ref, itemId: selected.id, group: [ref], before: before, selectSingle: true);
        }
      }
      for (final h in _handles) {
        if (hits(h.at)) {
          _setPoint(h.ref);
          return _Gesture(_G.handle, ref: h.ref, handleSide: h.side, itemId: selected.id);
        }
      }
      final near = nearestOnPath(selected.contours, units);
      if (near != null && near.distance * _px <= (_touch ? 14 : 9)) {
        return _Gesture(_G.segment, itemId: selected.id, contour: near.contour, segment: near.segment);
      }
    }
    final box = _selectedBox;
    if (mode == UiPathEditorMode.objects && selected != null && box != null) {
      if (hits(Offset(box.center.dx, box.top - 28 / _px))) return _Gesture(_G.rotate, itemId: selected.id, box: box);
      for (final c in const [(-1, -1), (1, -1), (1, 1), (-1, 1)]) {
        if (hits(Offset(c.$1 < 0 ? box.left : box.right, c.$2 < 0 ? box.top : box.bottom))) return _Gesture(_G.corner, corner: c, itemId: selected.id, box: box);
      }
    }
    final under = _itemAt(units);
    if (under != null) {
      if (under.id != _selectedId) {
        _setSelectedId(under.id);
        _clearPoint();
      }
      if (mode == UiPathEditorMode.objects) return _Gesture(_G.item, itemId: under.id);
    }
    // Empty space: a mouse or pen draws a selection box over points; a finger pans.
    if (mode == UiPathEditorMode.points && e.kind != PointerDeviceKind.touch) return _Gesture(_G.marquee, additive: keys.isShiftPressed);
    return _Gesture(_G.empty);
  }

  /// The top-most item whose filled outline (or, for lines, whose stroke) is under [units].
  UiPathItem? _itemAt(Offset units) {
    for (final item in _view.reversed) {
      if (uiContoursPath(item.contours).contains(units)) return item;
      final near = nearestOnPath(item.contours, units, 16);
      if (near != null && near.distance * _px < 6) return item;
    }
    return null;
  }

  void _move(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    final pinch = _pinch;
    if (pinch != null && _pointers.length >= 2) {
      final pts = _pointers.values.toList();
      final mid = (pts[0] + pts[1]) / 2;
      final dist = math.max(1.0, (pts[0] - pts[1]).distance);
      setState(() {
        _zoom = (pinch.zoom * dist / pinch.dist).clamp(0.2, 20);
        // Keep the spot that was between the fingers between them.
        _center = pinch.world - (mid - _size.center(Offset.zero)) / _px;
      });
      return;
    }
    final d = _drag;
    if (d == null || e.pointer != d.pointer) return;
    final g = d.gesture;
    if (g.kind == _G.ink) {
      _addInk(e);
      return;
    }
    if (!d.moved) {
      final slop = d.kind == PointerDeviceKind.touch ? 6.0 : 3.0;
      if ((e.localPosition - d.startLocal).distance < slop) return;
      d.moved = true;
      _clearPress();
      if (d.pressed) return;
      if (g.kind == _G.point && g.selectSingle) {
        _setPoints([g.ref!]);
        _setPoint(g.ref);
      }
    }
    if (d.pressed) return;
    if (g.kind == _G.empty || g.kind == _G.segment) {
      setState(() => _center = d.startCenter - (e.localPosition - d.startLocal) / _px);
      return;
    }
    final u = _toUnits(e.localPosition);
    if (g.kind == _G.marquee) {
      setState(() => _marquee = Rect.fromPoints(d.startUnits, u));
      return;
    }
    if (g.kind == _G.anchor) {
      setState(() => _dragAnchor(g, u));
      return;
    }
    setState(() => _draft = [for (final item in d.origin) item.id == g.itemId ? item.copyWith(contours: _apply(g, item.contours, d, u)) : item]);
  }

  List<UiPathContour> _apply(_Gesture g, List<UiPathContour> contours, _Drag d, Offset u) {
    final keys = HardwareKeyboard.instance;
    Offset toward(Offset p) => keys.isShiftPressed ? p + _snapAngle(u - p) : u;
    switch (g.kind) {
      case _G.point:
        final delta = keys.isShiftPressed ? _snapAngle(u - d.startUnits) : u - d.startUnits;
        return movePoints(contours, g.group, delta.dx, delta.dy);
      case _G.handle:
        final p = _pointAt(contours, g.ref!);
        if (p == null) return contours;
        return moveHandle(contours, g.ref!, g.handleSide!, toward(p.offset), free: keys.isAltPressed || widget.freeHandles);
      case _G.convert:
        final p = _pointAt(contours, g.ref!);
        if (p == null) return contours;
        return pullHandles(contours, g.ref!, toward(p.offset));
      case _G.item:
        final delta = keys.isShiftPressed ? _snapAngle(u - d.startUnits) : u - d.startUnits;
        return translateContours(contours, delta.dx, delta.dy);
      case _G.corner:
        final b = g.box!;
        final (cx, cy) = g.corner!;
        final ox = cx < 0 ? b.right : b.left, oy = cy < 0 ? b.bottom : b.top;
        final fx = cx < 0 ? b.left : b.right, fy = cy < 0 ? b.top : b.bottom;
        var sx = (fx - ox).abs() < 1e-6 ? 1.0 : (u.dx - ox) / (fx - ox);
        var sy = (fy - oy).abs() < 1e-6 ? 1.0 : (u.dy - oy) / (fy - oy);
        if (widget.lockAspect || keys.isShiftPressed) {
          final s = math.max(sx.abs(), sy.abs());
          sx = (sx == 0 ? 1 : sx.sign) * s;
          sy = (sy == 0 ? 1 : sy.sign) * s;
        }
        return scaleContours(contours, ox, oy, sx, sy);
      case _G.rotate:
        final c = g.box!.center;
        final a0 = math.atan2(d.startUnits.dy - c.dy, d.startUnits.dx - c.dx);
        final a1 = math.atan2(u.dy - c.dy, u.dx - c.dx);
        var deg = (a1 - a0) * 180 / math.pi;
        if (keys.isShiftPressed) {
          deg = (deg / 15).round() * 15.0;
        } else {
          for (final r in const [-180.0, -90.0, 0.0, 90.0, 180.0]) {
            if ((deg - r).abs() < 3) deg = r;
          }
        }
        return rotateContours(contours, c.dx, c.dy, deg);
      default:
        return contours;
    }
  }

  UiPathPoint? _pointAt(List<UiPathContour> contours, UiPointRef ref) =>
      ref.contour < contours.length && ref.point < contours[ref.contour].points.length ? contours[ref.contour].points[ref.point] : null;

  void _up(PointerEvent e, {bool cancelled = false}) {
    if (_pointers.remove(e.pointer) == null) return;
    _clearPress();
    if (_pinch != null) {
      if (_pointers.length < 2) _pinch = null;
      return;
    }
    final d = _drag;
    if (cancelled) {
      if (d?.pointer == e.pointer || _pointers.isEmpty) {
        setState(() {
          _drag = null;
          _draft = null;
          _dropInk();
          _marquee = null;
        });
      }
      return;
    }
    if (d == null || e.pointer != d.pointer) return;
    _drag = null;
    final g = d.gesture;
    if (g.kind == _G.ink) {
      _finishInk();
      return;
    }
    if (g.kind == _G.anchor) {
      if (g.closing) {
        finishPen(true);
      } else if (g.last && !d.moved) {
        finishPen(false);
      }
      return;
    }
    if (g.kind == _G.marquee) {
      setState(() => _finishMarquee(g.additive));
      if (d.moved) return;
    }
    final draft = _draft;
    setState(() => _draft = null);
    if (d.pressed) return;
    if (d.moved) {
      if (draft != null) _emit(draft);
      return;
    }
    setState(() => _tapped(g, d));
  }

  void _tapped(_Gesture g, _Drag d) {
    switch (g.kind) {
      case _G.point:
        final ref = g.ref!;
        if (g.selectSingle) {
          _setPoints([ref]);
          _setPoint(ref);
        }
        // A second tap on the same point switches it between corner and curve.
        final key = '${g.itemId}:${ref.contour}:${ref.point}';
        final now = DateTime.now();
        final last = _lastTap;
        if (last != null && last.key == key && now.difference(last.at) < _doubleTap) {
          _lastTap = null;
          _emit([for (final i in widget.items) i.id == g.itemId ? i.copyWith(contours: toggleSmooth(i.contours, ref)) : i]);
          return;
        }
        _lastTap = (key: key, at: now);
        widget.onPointTap?.call(ref);
      case _G.segment:
        final item = widget.items.where((i) => i.id == g.itemId).firstOrNull;
        if (item == null) return;
        final near = nearestOnPath(item.contours, d.startUnits);
        if (near == null) return;
        final r = insertPoint(item.contours, near.contour, near.segment, near.t);
        _emit([for (final i in widget.items) i.id == item.id ? i.copyWith(contours: r.contours) : i]);
        _setPoints([r.point]);
        _setPoint(r.point);
      case _G.empty || _G.marquee:
        if (widget.mode == UiPathEditorMode.points) {
          _clearPoint();
        } else if (widget.mode == UiPathEditorMode.objects) {
          _setSelectedId(null);
        }
      default:
        break;
    }
  }

  void _hoverAt(PointerHoverEvent e) {
    if (widget.mode == UiPathEditorMode.pen) {
      setState(() => _hover = _constrained(_toUnits(e.localPosition)));
    } else if (widget.mode == UiPathEditorMode.objects) {
      final id = _itemAt(_toUnits(e.localPosition))?.id;
      if (id != _hoverItem) setState(() => _hoverItem = id);
    }
  }

  void _wheel(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (event) {
      final s = event as PointerScrollEvent;
      final world = _toUnits(s.localPosition);
      final ctrl = HardwareKeyboard.instance.isControlPressed;
      final factor = math.exp(-s.scrollDelta.dy * (ctrl ? 0.01 : 0.0015));
      setState(() {
        _zoom = (_zoom * factor).clamp(0.2, 20);
        _center = world - (s.localPosition - _size.center(Offset.zero)) / _px;
      });
    });
  }

  // ----- points ----------------------------------------------------------------------------------

  void _longPressPoint() {
    _pressTimer = null;
    final d = _drag;
    if (d == null || d.moved || d.gesture.kind != _G.point || !mounted) return;
    final g = d.gesture;
    d.pressed = true;
    final had = g.before.contains(g.ref);
    final next = had ? g.before.where((r) => r != g.ref).toList() : [...g.before, g.ref!];
    setState(() {
      _setPoints(next);
      _setPoint(had ? (next.isEmpty ? null : next.last) : g.ref);
    });
    HapticFeedback.selectionClick();
  }

  void _clearPress() {
    _pressTimer?.cancel();
    _pressTimer = null;
  }

  void _finishMarquee(bool additive) {
    final m = _marquee;
    _marquee = null;
    if (m == null || (m.width < 1e-6 && m.height < 1e-6)) return;
    bool inside(Offset p) => p.dx >= m.left && p.dx <= m.right && p.dy >= m.top && p.dy <= m.bottom;
    List<UiPointRef> hits(UiPathItem item) => allPoints(item.contours).where((r) => inside(item.contours[r.contour].points[r.point].offset)).toList();
    // The selected item first; otherwise whichever item the box caught points of.
    var item = _selectedItem;
    var refs = item == null ? <UiPointRef>[] : hits(item);
    if (refs.isEmpty) {
      for (final other in widget.items.reversed) {
        final h = hits(other);
        if (h.isNotEmpty) {
          item = other;
          refs = h;
          break;
        }
      }
    }
    if (item == null || refs.isEmpty) {
      if (!additive) _clearPoint();
      return;
    }
    if (item.id != _selectedId) {
      _setSelectedId(item.id);
      additive = false;
    }
    final base = additive ? _selectedPoints : const <UiPointRef>[];
    final next = [...base, ...refs.where((r) => !base.contains(r))];
    _setPoints(next);
    _setPoint(next.last);
  }

  // ----- pen -------------------------------------------------------------------------------------

  _Gesture _penDown(Offset at) {
    final pts = _pen;
    final u = _constrained(at);
    if (pts.length > 1 && _near(at, pts.first.offset)) return _Gesture(_G.anchor, index: 0, closing: true);
    if (pts.isNotEmpty && _near(at, pts.last.offset)) return _Gesture(_G.anchor, index: pts.length - 1, last: true);
    if (pts.isEmpty) {
      // Starting on a loose end of the selected item carries that line on.
      final item = widget.items.where((i) => i.id == _selectedId).firstOrNull;
      if (item != null) {
        final found = item.contours.indexWhere((c) => !c.closed && c.points.length > 1 && (_near(at, c.points.first.offset) || _near(at, c.points.last.offset)));
        if (found >= 0) {
          final c = item.contours[found];
          final fromStart = _near(at, c.points.first.offset);
          _setPen(fromStart ? reverseContour(c).points : [...c.points]);
          _penTarget = (itemId: item.id, contour: found);
          return _Gesture(_G.anchor, index: c.points.length - 1);
        }
      }
    }
    _setPen([...pts, UiPathPoint.at(u)]);
    _hover = null;
    return _Gesture(_G.anchor, index: pts.length);
  }

  /// Dragging after placing a point pulls curve handles out of it, in line (Alt: the outgoing one).
  void _dragAnchor(_Gesture g, Offset u) {
    final keys = HardwareKeyboard.instance;
    _setPen([
      for (var i = 0; i < _pen.length; i++)
        if (i != g.index)
          _pen[i]
        else
          () {
            final p = _pen[i];
            final to = keys.isShiftPressed ? p.offset + _snapAngle(u - p.offset) : u;
            final mirrored = p.offset * 2 - to;
            if (g.closing) return UiPathPoint(p.x, p.y, handleIn: mirrored, handleOut: keys.isAltPressed ? p.handleOut : to);
            if (g.last) return UiPathPoint(p.x, p.y, handleIn: p.handleIn, handleOut: to);
            return UiPathPoint(p.x, p.y, handleOut: to, handleIn: keys.isAltPressed && p.handleIn != null ? p.handleIn : mirrored);
          }(),
    ]);
  }

  /// With Shift, the next point keeps to 45 degree steps from the last.
  Offset _constrained(Offset u) {
    if (!HardwareKeyboard.instance.isShiftPressed || _pen.isEmpty) return u;
    final last = _pen.last.offset;
    return last + _snapAngle(u - last);
  }

  // ----- ink -------------------------------------------------------------------------------------

  void _startInk(PointerDownEvent e, Offset u) {
    final brush = widget.brush;
    final pen = e.kind == PointerDeviceKind.stylus || e.kind == PointerDeviceKind.invertedStylus;
    final sample = UiInkSample(u.dx, u.dy, pen && e.pressure > 0 ? e.pressure.clamp(0.0, 1.0) : simulatedPressure(brush.kind, 0.5, 0, brush.size));
    final r = inkRadiusAt(sample, 0, brush);
    _ink = _Ink(brush: brush, samples: [sample], radii: [r], pieces: [inkPiece(sample.offset, r, null, 0, brush)], raw: sample, holdFrom: e.localPosition, pen: pen);
    _inkSnapPieces = null;
    _armHold();
  }

  void _addInk(PointerMoveEvent e) {
    final ink = _ink;
    if (ink == null || ink.snapped != null) return;
    final brush = ink.brush;
    final u = _toUnits(e.localPosition);
    final last = ink.samples.last;
    // Steady the line: each sample moves only part of the way to the pointer.
    final k = 1 - brushSteadiness(brush.kind);
    final at = last.offset + (u - last.offset) * k;
    final dist = (at - last.offset).distance;
    final pressure = ink.pen ? (e.pressure > 0 ? e.pressure.clamp(0.0, 1.0) : last.pressure) : simulatedPressure(brush.kind, last.pressure, dist, brush.size);
    ink.raw = UiInkSample(u.dx, u.dy, pressure);
    if ((e.localPosition - ink.holdFrom).distance > 5) {
      ink.holdFrom = e.localPosition;
      _armHold();
    }
    // Closer than a quarter of the nib (or a couple of pixels) adds nothing but work.
    if (dist < math.max(1.5 / _px, brush.size * 0.25)) return;
    final sample = UiInkSample(at.dx, at.dy, pressure);
    ink.along += dist;
    final r = inkRadiusAt(sample, ink.along, brush);
    setState(() {
      ink.pieces.add(inkPiece(last.offset, ink.radii.last, sample.offset, r, brush));
      ink.samples.add(sample);
      ink.radii.add(r);
    });
  }

  void _finishInk() {
    final ink = _ink;
    setState(_dropInk);
    if (ink == null) return;
    var samples = ink.snapped != null ? _snappedSamples(ink) : [...ink.samples];
    if (ink.snapped == null) {
      // Finish where the pointer actually lifted, not where the steadied line had got to.
      if ((ink.raw.offset - samples.last.offset).distance > ink.brush.size * 0.1) samples = [...samples, ink.raw];
    }
    widget.onStroke?.call(UiInkStroke(samples: samples, brush: ink.brush, pieces: inkArea(samples, ink.brush), shape: ink.snapped));
  }

  void _dropInk() {
    _ink = null;
    _inkSnapPieces = null;
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  void _armHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (!widget.snapToShape || widget.brush.kind == UiBrushKind.eraser) return;
    _holdTimer = Timer(_holdToSnap, _snapInk);
  }

  /// Held still: if the stroke looks like a shape, it becomes that shape.
  void _snapInk() {
    _holdTimer = null;
    final ink = _ink;
    if (ink == null || ink.snapped != null || ink.samples.length < 4 || !mounted) return;
    final shape = recognizeShape([for (final s in ink.samples) s.offset, ink.raw.offset]);
    if (shape == null) return;
    setState(() {
      ink.snapped = shape;
      _inkSnapPieces = inkArea(_snappedSamples(ink), ink.brush);
    });
    HapticFeedback.selectionClick();
  }

  List<UiInkSample> _snappedSamples(_Ink ink) {
    final pressure = ink.samples.fold(0.0, (s, p) => s + p.pressure) / ink.samples.length;
    return shapeSamples(ink.snapped!, pressure, math.max(2 / _px, ink.brush.size * 0.3));
  }

  // ----- keyboard --------------------------------------------------------------------------------

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final keys = HardwareKeyboard.instance;
    final mode = widget.mode;
    if (mode == UiPathEditorMode.pen && _pen.isNotEmpty) {
      if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.escape) {
        finishPen(false);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.backspace || k == LogicalKeyboardKey.delete) {
        undoPenPoint();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final editing = mode == UiPathEditorMode.objects || mode == UiPathEditorMode.points;
    // `]` / `[` step the selection through the items, Escape clears it: without them a keyboard
    // user could never select anything.
    if ((k == LogicalKeyboardKey.bracketRight || k == LogicalKeyboardKey.bracketLeft) && editing) {
      final list = widget.items;
      if (list.isEmpty) return KeyEventResult.ignored;
      final fwd = k == LogicalKeyboardKey.bracketRight;
      final at = list.indexWhere((i) => i.id == _selectedId);
      final next = at < 0 ? (fwd ? 0 : list.length - 1) : (at + (fwd ? 1 : -1) + list.length) % list.length;
      setState(() {
        _setSelectedId(list[next].id);
        _clearPoint();
      });
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape && _selectedId != null) {
      // Points first, then the item: one Escape per level.
      setState(() {
        if (_selectedPoints.isNotEmpty) {
          _clearPoint();
        } else {
          _setSelectedId(null);
          _clearPoint();
        }
      });
      return KeyEventResult.handled;
    }
    final item = _selectedItem;
    if (item == null) return KeyEventResult.ignored;
    final refs = _selectedPoints;
    final pointsMode = mode == UiPathEditorMode.points && refs.isNotEmpty;
    if ((k == LogicalKeyboardKey.delete || k == LogicalKeyboardKey.backspace) && pointsMode) {
      final next = deletePoints(item.contours, refs);
      setState(_clearPoint);
      _emit([for (final i in widget.items) i.id == item.id ? i.copyWith(contours: next) : i]);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyA && (keys.isControlPressed || keys.isMetaPressed) && mode == UiPathEditorMode.points) {
      selectAllPoints();
      return KeyEventResult.handled;
    }
    final step = keys.isShiftPressed ? 10.0 : 1.0;
    final m = switch (k) {
      LogicalKeyboardKey.arrowLeft => Offset(-step, 0),
      LogicalKeyboardKey.arrowRight => Offset(step, 0),
      LogicalKeyboardKey.arrowUp => Offset(0, -step),
      LogicalKeyboardKey.arrowDown => Offset(0, step),
      _ => null,
    };
    if (m == null) return KeyEventResult.ignored;
    final next = pointsMode ? movePoints(item.contours, refs, m.dx, m.dy) : translateContours(item.contours, m.dx, m.dy);
    _emit([for (final i in widget.items) i.id == item.id ? i.copyWith(contours: next) : i]);
    return KeyEventResult.handled;
  }

  // ----- build -----------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth.isFinite ? c.maxWidth : 400, c.maxHeight.isFinite ? c.maxHeight : 300);
      if (size != _size) {
        _size = size;
        if (!_fitted) {
          _fit();
          _fitted = true;
        }
      } else if (!_fitted) {
        _fit();
        _fitted = true;
      }
      final mode = widget.mode;
      final painter = _EditorPainter(
        tokens: t,
        center: _center,
        px: _px,
        size: _size,
        artboard: widget.showArtboard ? Size(widget.width, widget.height) : null,
        items: _view,
        selectedId: _selectedId,
        hoverItem: _hoverItem,
        mode: mode,
        knob: _knob,
        selectedPoints: _selectedPoints,
        handles: mode == UiPathEditorMode.points ? _handles : const [],
        pen: mode == UiPathEditorMode.pen ? _pen : const [],
        hover: _hover,
        marquee: _marquee,
        ink: _inkSnapPieces ?? _ink?.pieces,
        eraser: _ink?.brush.kind == UiBrushKind.eraser,
        inkFill: widget.fill,
        ring: _ring,
      );
      final drawing = mode == UiPathEditorMode.pen || mode == UiPathEditorMode.draw;
      return Semantics(
        container: true,
        focusable: true,
        label: widget.label,
        value: '${widget.items.length} ${widget.items.length == 1 ? 'shape' : 'shapes'}, ${mode.name} mode',
        child: Focus(
          focusNode: _focus,
          onKeyEvent: _onKey,
          onFocusChange: (v) => setState(() => _ring = v && FocusManager.instance.highlightMode == FocusHighlightMode.traditional),
          child: MouseRegion(
            cursor: drawing ? SystemMouseCursors.precise : (_hoverItem != null ? SystemMouseCursors.click : MouseCursor.defer),
            onExit: (_) => setState(() {
              _hover = null;
              _hoverItem = null;
            }),
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {_EditorClaim: GestureRecognizerFactoryWithHandlers<_EditorClaim>(_EditorClaim.new, (_) {})},
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _down,
                onPointerMove: _move,
                onPointerUp: _up,
                onPointerCancel: (e) => _up(e, cancelled: true),
                onPointerHover: _hoverAt,
                onPointerSignal: _wheel,
                child: ClipRect(child: CustomPaint(painter: painter, size: _size)),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Keeps a movement to the nearest 45 degree direction, the way Shift does in drawing apps,
/// keeping the distance along it.
Offset _snapAngle(Offset d) {
  if (d.distance == 0) return Offset.zero;
  final a = (math.atan2(d.dy, d.dx) / (math.pi / 4)).round() * (math.pi / 4);
  final along = d.dx * math.cos(a) + d.dy * math.sin(a);
  return Offset(math.cos(a) * along, math.sin(a) * along);
}

/// Claims every pointer that lands on the editor (the web `touch-action: none`), so a scrolling
/// parent never takes a stroke or a drag. The editor follows the pointers with a [Listener].
class _EditorClaim extends OneSequenceGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) stopTrackingPointer(event.pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'path editor claim';
}

class _EditorPainter extends CustomPainter {
  _EditorPainter({
    required this.tokens,
    required this.center,
    required this.px,
    required this.size,
    required this.artboard,
    required this.items,
    required this.selectedId,
    required this.hoverItem,
    required this.mode,
    required this.knob,
    required this.selectedPoints,
    required this.handles,
    required this.pen,
    required this.hover,
    required this.marquee,
    required this.ink,
    required this.eraser,
    required this.inkFill,
    required this.ring,
  });

  final UiTokens tokens;
  final Offset center;
  final double px;
  final Size size;
  final Size? artboard;
  final List<UiPathItem> items;
  final String? selectedId;
  final String? hoverItem;
  final UiPathEditorMode mode;
  final double knob;
  final List<UiPointRef> selectedPoints;
  final List<({UiPointRef ref, UiHandleSide side, Offset from, Offset at})> handles;
  final List<UiPathPoint> pen;
  final Offset? hover;
  final Rect? marquee;
  final List<List<Offset>>? ink;
  final bool eraser;
  final Color? inkFill;
  final bool ring;

  /// A stroke that looks the same width at any zoom (the web `vector-effect: non-scaling-stroke`).
  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w / px;

  Paint _fill(Color c) => Paint()..color = c;

  void _dashed(Canvas canvas, Path path, Paint paint, List<double> pattern) {
    for (final m in path.computeMetrics()) {
      var d = 0.0, i = 0;
      while (d < m.length) {
        final len = pattern[i % pattern.length] / px;
        if (i.isEven) canvas.drawPath(m.extractPath(d, math.min(d + len, m.length)), paint);
        d += len;
        i++;
      }
    }
  }

  void _knobAt(Canvas canvas, Offset at, double r, {required Color fill, required Color stroke, double width = 1.75, bool square = false}) {
    final rect = Rect.fromCircle(center: at, radius: r / px);
    if (square) {
      canvas.drawRect(rect, _fill(fill));
      canvas.drawRect(rect, _stroke(stroke, width));
    } else {
      canvas.drawOval(rect, _fill(fill));
      canvas.drawOval(rect, _stroke(stroke, width));
    }
  }

  @override
  void paint(Canvas canvas, Size s) {
    final t = tokens;
    canvas.drawRect(Offset.zero & s, _fill(t.surfaceSubtle));
    canvas.save();
    canvas.translate(s.width / 2, s.height / 2);
    canvas.scale(px);
    canvas.translate(-center.dx, -center.dy);

    if (artboard != null) {
      final r = Offset.zero & artboard!;
      canvas.drawRect(r, _fill(t.surface));
      _dashed(canvas, Path()..addRect(r), _stroke(t.borderStrong, 1), const [4, 4]);
    }

    for (final item in items) {
      final path = uiContoursPath(item.contours);
      final op = itemOp(item);
      final dim = mode == UiPathEditorMode.points && item.id != selectedId;
      if (dim) canvas.saveLayer(null, Paint()..color = t.text.withValues(alpha: 0.28));
      final base = item.fill ?? (item.id == hoverItem && mode == UiPathEditorMode.objects ? t.textSecondary : t.textMuted);
      switch (op) {
        case UiPathOp.add:
          canvas.drawPath(path, _fill(base));
        case UiPathOp.cut:
          canvas.drawPath(path, _fill(t.danger.withValues(alpha: 0.10)));
          canvas.save();
          canvas.clipPath(path);
          final b = path.getBounds();
          final line = Paint()
            ..color = t.danger.withValues(alpha: 0.55)
            ..strokeWidth = 1.5 / px;
          final step = 8 / px;
          for (var x = b.left - b.height; x < b.right; x += step) {
            canvas.drawLine(Offset(x, b.bottom), Offset(x + b.height, b.top), line);
          }
          canvas.restore();
          _dashed(canvas, path, _stroke(t.danger, 1.5), const [5, 4]);
        case UiPathOp.intersect || UiPathOp.exclude:
          canvas.drawPath(path, _fill(base.withValues(alpha: base.a * 0.45)));
          _dashed(canvas, path, _stroke(t.primary, 1.5), op == UiPathOp.intersect ? const [2, 3] : const [8, 3, 2, 3]);
      }
      if (dim) canvas.restore();
    }

    if (ink != null && ink!.isNotEmpty) {
      final p = inkPath(ink!);
      if (eraser) {
        canvas.drawPath(p, _fill(t.danger.withValues(alpha: 0.22)));
      } else {
        canvas.drawPath(p, _fill(inkFill ?? t.textMuted));
      }
    }

    final selected = items.where((i) => i.id == selectedId).firstOrNull;
    if (mode == UiPathEditorMode.objects && selected != null) {
      final b = pathBounds(selected.contours);
      if (b != null) {
        canvas.drawRect(b, _stroke(t.primary, 1.5));
        final top = Offset(b.center.dx, b.top - 28 / px);
        canvas.drawLine(Offset(b.center.dx, b.top), top, _stroke(t.primary, 1.25));
        _knobAt(canvas, top, knob, fill: t.primary, stroke: t.primary);
        for (final c in [b.topLeft, b.topRight, b.bottomRight, b.bottomLeft]) {
          _knobAt(canvas, c, knob, fill: t.surface, stroke: t.primary);
        }
      }
    }

    if (mode == UiPathEditorMode.points && selected != null) {
      canvas.drawPath(uiContoursPath(selected.contours), _stroke(t.primary, 1.5));
      for (final h in handles) {
        canvas.drawLine(h.from, h.at, _stroke(t.primary, 1.25));
        _knobAt(canvas, h.at, knob * 0.8, fill: t.primary, stroke: t.surface);
      }
      for (var ci = 0; ci < selected.contours.length; ci++) {
        final c = selected.contours[ci];
        for (var pi = 0; pi < c.points.length; pi++) {
          final p = c.points[pi];
          final on = selectedPoints.contains(UiPointRef(ci, pi));
          final end = !c.closed && (pi == 0 || pi == c.points.length - 1);
          _knobAt(canvas, p.offset, knob, fill: on ? t.primary : t.surface, stroke: t.primary, width: end ? 2.5 : 1.75, square: !p.smooth);
        }
      }
    }

    if (mode == UiPathEditorMode.pen && pen.isNotEmpty) {
      canvas.drawPath(uiContoursPath([UiPathContour(points: pen)]), _stroke(t.primary, 1.75));
      final last = pen.last;
      final closable = pen.length > 1 && hover != null && (hover! - pen.first.offset).distance * px < knob * 2.2;
      if (hover != null) {
        final to = closable ? pen.first.offset : hover!;
        final c1 = last.handleOut ?? last.offset;
        final c2 = closable ? (pen.first.handleIn ?? pen.first.offset) : to;
        final rubber = Path()
          ..moveTo(last.x, last.y)
          ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, to.dx, to.dy);
        _dashed(canvas, rubber, _stroke(t.primary.withValues(alpha: 0.8), 1.25), const [4, 4]);
      }
      for (final h in [last.handleIn, last.handleOut]) {
        if (h == null) continue;
        canvas.drawLine(last.offset, h, _stroke(t.primary, 1.25));
        _knobAt(canvas, h, knob * 0.7, fill: t.primary, stroke: t.surface);
      }
      for (var i = 0; i < pen.length; i++) {
        final isLast = i == pen.length - 1;
        final start = i == 0 && pen.length > 1;
        _knobAt(canvas, pen[i].offset, knob,
            fill: isLast || (i == 0 && closable) ? t.primary : t.surface, stroke: t.primary, width: start ? 2.5 : 1.75, square: true);
      }
    }

    if (marquee != null) {
      canvas.drawRect(marquee!, _fill(t.primary.withValues(alpha: 0.10)));
      _dashed(canvas, Path()..addRect(marquee!), _stroke(t.primary, 1), const [4, 3]);
    }
    canvas.restore();

    if (ring) {
      canvas.drawRect((Offset.zero & s).deflate(1), Paint()
        ..color = t.borderFocus
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_EditorPainter old) => true;
}
