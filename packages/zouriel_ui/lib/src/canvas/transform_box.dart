import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../theme/theme.dart';

/// A box in stage units, rotated about its centre by [rotate] degrees.
@immutable
class UiBox {
  const UiBox({required this.x, required this.y, required this.w, required this.h, this.rotate = 0});

  final double x, y, w, h, rotate;

  Rect get rect => Rect.fromLTWH(x, y, w, h);
  Offset get center => Offset(x + w / 2, y + h / 2);

  UiBox copyWith({double? x, double? y, double? w, double? h, double? rotate}) =>
      UiBox(x: x ?? this.x, y: y ?? this.y, w: w ?? this.w, h: h ?? this.h, rotate: rotate ?? this.rotate);

  @override
  bool operator ==(Object other) => other is UiBox && other.x == x && other.y == y && other.w == w && other.h == h && other.rotate == rotate;

  @override
  int get hashCode => Object.hash(x, y, w, h, rotate);

  @override
  String toString() => 'UiBox($x, $y, $w x $h, ${rotate}deg)';
}

/// What a drag on the transform box does.
enum UiTransformMode { move, resize, rotate }

/// The body was pressed and released without moving.
@immutable
class UiTransformTap {
  const UiTransformTap({required this.globalPosition, required this.shift, required this.kind});
  final Offset globalPosition;
  final bool shift;
  final PointerDeviceKind kind;
}

/// Which edges a resize handle drags: -1 left/top, 1 right/bottom, 0 untouched.
enum _Handle {
  nw(-1, -1), n(0, -1), ne(1, -1), e(1, 0), se(1, 1), s(0, 1), sw(-1, 1), w(-1, 0);

  const _Handle(this.sx, this.sy);
  final int sx, sy;
  bool get corner => sx != 0 && sy != 0;

  MouseCursor get cursor => switch (this) {
        _Handle.n || _Handle.s => SystemMouseCursors.resizeUpDown,
        _Handle.e || _Handle.w => SystemMouseCursors.resizeLeftRight,
        _Handle.ne || _Handle.sw => SystemMouseCursors.resizeUpRightDownLeft,
        _Handle.nw || _Handle.se => SystemMouseCursors.resizeUpLeftDownRight,
      };
}

/// `ui-transform-box`: selection handles for an element on a design stage. Drag the body to move,
/// a handle to resize, the top knob to rotate. Put it in the stage's [Stack]: it lays itself out
/// from [box] (stage units) times [scale] (layout pixels per unit). Pointer movement is measured in
/// the stage's own coordinates, so a stage that is itself scaled (a zoomed canvas) needs no extra
/// setting (the web `pointerScale`).
///
/// It never changes [box]: it reports [onTransform] on every move and [onTransformEnd] once on
/// release, so the host decides what a change means (live preview or an undo step). Resizing
/// respects rotation: the opposite edge stays put on screen.
///
/// Modifiers: Shift keeps proportions while resizing and snaps rotation to 15 degrees; Alt resizes
/// from the centre. Keyboard (when focused): arrows nudge by one unit, Shift+arrow by ten,
/// Alt+arrow resizes (width with left/right, height with up/down), `[` / `]` rotate by 1 degree
/// (15 with Shift). Screen readers get the same as actions.
///
/// Touch: handles keep a 48dp target, the knob sits further out, and two fingers pinch: the box
/// grows or shrinks toward the point between them, proportions kept, and moves with them. A second
/// finger landing anywhere while one drags the box turns the drag into a pinch; a host that sees two
/// fingers land beside a small element can start one with [UiTransformBoxState.startPinch]. A pinch
/// reports as a resize. Edge handles hide when the box is too small on screen to fit them between
/// the corners.
class UiTransformBox extends StatefulWidget {
  const UiTransformBox({
    super.key,
    required this.box,
    this.scale = 1,
    this.resizable = true,
    this.rotatable = true,
    this.lockAspect = false,
    this.minSize = 4,
    this.disabled = false,
    this.label = '',
    this.showSize = false,
    this.cornersOnly = false,
    this.onTransformStart,
    this.onTransform,
    this.onTransformEnd,
    this.onActivate,
    this.onTap,
  });

  final UiBox box;

  /// Layout pixels per stage unit.
  final double scale;
  final bool resizable;
  final bool rotatable;

  /// Keep proportions on every resize, not only with Shift.
  final bool lockAspect;

  /// Smallest width and height, in stage units.
  final double minSize;

  /// Hide the handles and ignore pointer, pinch and keys (drawn dashed).
  final bool disabled;

  /// Accessible name; "Selected element" when empty.
  final String label;

  /// Show a W x H readout under the box.
  final bool showSize;

  /// Only the four corner handles.
  final bool cornersOnly;

  final ValueChanged<UiTransformMode>? onTransformStart;
  final ValueChanged<UiBox>? onTransform;
  final ValueChanged<UiBox>? onTransformEnd;

  /// Double-tap (e.g. start editing text).
  final VoidCallback? onActivate;

  /// The body was pressed and released without moving: the box covers what is beneath, so this is
  /// how a host lets a tap reach it.
  final ValueChanged<UiTransformTap>? onTap;

  @override
  State<UiTransformBox> createState() => UiTransformBoxState();
}

class _DragState {
  _DragState({required this.mode, required this.handle, required this.pointer, required this.kind, required this.start, required this.origin, required this.startAngle});
  final UiTransformMode mode;
  final _Handle? handle;
  final int pointer;
  final PointerDeviceKind kind;

  /// Stage-local pixels.
  final Offset start;
  final UiBox origin;
  final double startAngle;
  late UiBox last = origin;
  Offset latest = Offset.zero;
  bool moved = false;
}

class _PinchState {
  _PinchState({required this.points, required this.spread, required this.mid, required this.centre, required this.origin, required this.moved});
  final Map<int, Offset> points;
  final double spread;
  final Offset mid;
  final Offset centre;
  final UiBox origin;
  late UiBox last = origin;
  bool moved;
}

class UiTransformBoxState extends State<UiTransformBox> {
  final FocusNode _focus = FocusNode(debugLabel: 'UiTransformBox');
  bool _focusRing = false;
  _DragState? _drag;
  _PinchState? _pinch;
  bool _routed = false;
  UiBox? _nudged, _nudgedFrom;
  DateTime? _lastTap;
  Offset? _lastTapAt;

  /// Whether two fingers are pinching the box now.
  bool get pinching => _pinch != null;

  @override
  void dispose() {
    _unroute();
    _focus.dispose();
    super.dispose();
  }

  RenderBox? get _stage {
    final self = context.findRenderObject();
    final parent = self?.parent;
    return parent is RenderBox ? parent : null;
  }

  Offset _local(Offset global) => _stage?.globalToLocal(global) ?? global;

  double get _px => widget.scale == 0 ? 1 : widget.scale;

  void _route() {
    if (_routed) return;
    _routed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobal);
  }

  void _unroute() {
    if (!_routed) return;
    _routed = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onGlobal);
  }

  // ----- pointer ---------------------------------------------------------------------------------

  void _down(PointerDownEvent e, UiTransformMode mode, [_Handle? handle]) {
    if (widget.disabled) return;
    final d = _drag;
    if (d != null) {
      // A second finger on the box while one drags it: a pinch.
      if (d.kind == PointerDeviceKind.touch && e.kind == PointerDeviceKind.touch && e.pointer != d.pointer) {
        startPinch(d.pointer, d.moved ? d.latest : _globalOf(d.start), e.pointer, e.position);
      }
      return;
    }
    if (_pinch != null) return;
    _focus.requestFocus();
    final origin = widget.box;
    final at = _local(e.position);
    final centre = origin.center * _px;
    _drag = _DragState(
      mode: mode,
      handle: handle,
      pointer: e.pointer,
      kind: e.kind,
      start: at,
      origin: origin,
      startAngle: math.atan2(at.dy - centre.dy, at.dx - centre.dx),
    )..latest = e.position;
    _route();
    widget.onTransformStart?.call(mode);
  }

  Offset _globalOf(Offset local) => _stage?.localToGlobal(local) ?? local;

  void _onGlobal(PointerEvent e) {
    final p = _pinch;
    if (p != null) {
      if (!p.points.containsKey(e.pointer)) return;
      if (e is PointerMoveEvent) {
        _pinchMove(e.pointer, e.position);
      } else if (e is PointerUpEvent || e is PointerCancelEvent) {
        _pinchEnd();
      }
      return;
    }
    final d = _drag;
    if (d == null) {
      _unroute();
      return;
    }
    if (e is PointerDownEvent) {
      // A second finger anywhere while one drags the box turns the drag into a pinch.
      if (d.kind == PointerDeviceKind.touch && e.kind == PointerDeviceKind.touch && e.pointer != d.pointer) {
        startPinch(d.pointer, d.latest, e.pointer, e.position);
      }
      return;
    }
    if (e.pointer != d.pointer) return;
    if (e is PointerMoveEvent) {
      _move(d, e.position);
    } else if (e is PointerUpEvent) {
      _end(d, e.position, cancelled: false);
    } else if (e is PointerCancelEvent) {
      _end(d, e.position, cancelled: true);
    }
  }

  void _move(_DragState d, Offset global) {
    d.latest = global;
    final at = _local(global);
    if (!d.moved) {
      // A finger wobbles: don't let a tap become a one-pixel move.
      final slop = d.kind == PointerDeviceKind.touch ? 6.0 : 1.0;
      if ((at - d.start).distance < slop) return;
      d.moved = true;
    }
    final keys = HardwareKeyboard.instance;
    final dx = (at.dx - d.start.dx) / _px;
    final dy = (at.dy - d.start.dy) / _px;
    final o = d.origin;
    UiBox next;
    switch (d.mode) {
      case UiTransformMode.move:
        next = o.copyWith(x: o.x + dx, y: o.y + dy);
      case UiTransformMode.rotate:
        final centre = o.center * _px;
        final angle = math.atan2(at.dy - centre.dy, at.dx - centre.dx);
        var deg = o.rotate + (angle - d.startAngle) * 180 / math.pi;
        deg = ((deg % 360) + 540) % 360 - 180;
        if (keys.isShiftPressed) {
          deg = (deg / 15).round() * 15.0;
        } else {
          for (final r in const [-180.0, -90.0, 0.0, 90.0, 180.0]) {
            if ((deg - r).abs() < 3) deg = r;
          }
        }
        next = o.copyWith(rotate: (deg * 10).round() / 10);
      case UiTransformMode.resize:
        next = uiResizeBox(o, d.handle!.sx, d.handle!.sy, dx, dy,
            keepRatio: keys.isShiftPressed || widget.lockAspect, fromCenter: keys.isAltPressed, minSize: widget.minSize);
    }
    d.last = next;
    widget.onTransform?.call(next);
  }

  void _end(_DragState d, Offset global, {required bool cancelled}) {
    _drag = null;
    _unroute();
    if (d.moved && d.last != d.origin) {
      widget.onTransformEnd?.call(d.last);
    } else if (!d.moved && !cancelled && d.mode == UiTransformMode.move) {
      widget.onTap?.call(UiTransformTap(globalPosition: global, shift: HardwareKeyboard.instance.isShiftPressed, kind: d.kind));
      final now = DateTime.now();
      if (_lastTap != null && now.difference(_lastTap!) < kDoubleTapTimeout && (global - _lastTapAt!).distance < kDoubleTapSlop) {
        _lastTap = null;
        widget.onActivate?.call();
      } else {
        _lastTap = now;
        _lastTapAt = global;
      }
    }
  }

  /// Starts a pinch from two pointers (ids and global positions), for a host that sees both
  /// fingers land off the box. A drag in progress hands over to it. Does nothing while disabled.
  void startPinch(int pointerA, Offset a, int pointerB, Offset b) {
    if (widget.disabled || _pinch != null || pointerA == pointerB) return;
    final from = _drag?.moved == true ? _drag!.last : widget.box;
    // A drag that already moved has told the host it started; the pinch carries on from it.
    final carried = _drag?.moved ?? false;
    _drag = null;
    final la = _local(a), lb = _local(b);
    _pinch = _PinchState(
      points: {pointerA: la, pointerB: lb},
      spread: math.max(1, (lb - la).distance),
      mid: (la + lb) / 2,
      centre: from.center * _px,
      origin: from,
      moved: carried,
    );
    _route();
    if (carried) widget.onTransformStart?.call(UiTransformMode.resize);
  }

  void _pinchMove(int pointer, Offset global) {
    final p = _pinch!;
    p.points[pointer] = _local(global);
    final pts = p.points.values.toList();
    final a = pts[0], b = pts[1];
    final o = p.origin;
    final min = widget.minSize;
    // Equal from every side: one factor for both, never below the smallest size.
    final k = math.max((b - a).distance / p.spread, math.max(min / math.max(1e-6, o.w), min / math.max(1e-6, o.h)));
    final w = o.w * k, h = o.h * k;
    // The point between the fingers stays between them: the centre keeps its offset from it,
    // scaled, and the pair's movement carries both.
    final m = (a + b) / 2;
    final cx = o.x + o.w / 2 + (m.dx - p.mid.dx + (p.centre.dx - p.mid.dx) * (k - 1)) / _px;
    final cy = o.y + o.h / 2 + (m.dy - p.mid.dy + (p.centre.dy - p.mid.dy) * (k - 1)) / _px;
    p.last = o.copyWith(x: cx - w / 2, y: cy - h / 2, w: w, h: h);
    // Told on the first movement, so two fingers that land and lift change nothing.
    if (!p.moved) widget.onTransformStart?.call(UiTransformMode.resize);
    p.moved = true;
    widget.onTransform?.call(p.last);
  }

  void _pinchEnd() {
    final p = _pinch!;
    // Lifting either finger ends it; the other doesn't carry on as a drag, so nothing jumps.
    _pinch = null;
    _unroute();
    if (p.moved) widget.onTransformEnd?.call(p.last);
  }

  // ----- keyboard --------------------------------------------------------------------------------

  /// Builds on the last nudge when presses come faster than the host rebuilds (a held key).
  UiBox get _keyBase => _nudged != null && identical(_nudgedFrom, widget.box) ? _nudged! : widget.box;

  void _commit(UiBox next) {
    _nudgedFrom = widget.box;
    _nudged = next;
    widget.onTransformEnd?.call(next);
  }

  void _nudge(double dx, double dy) => _commit(_keyBase.copyWith(x: _keyBase.x + dx, y: _keyBase.y + dy));

  void _turn(double deg) => _commit(_keyBase.copyWith(rotate: _keyBase.rotate + deg));

  void _keyResize(double dw, double dh) {
    final base = _keyBase, min = widget.minSize;
    if (!widget.lockAspect || base.w == 0 || base.h == 0) {
      _commit(base.copyWith(w: math.max(min, base.w + dw), h: math.max(min, base.h + dh)));
      return;
    }
    final ratio = base.h / base.w;
    final w = math.max(min, dw != 0 ? base.w + dw : base.w + dh / ratio);
    _commit(base.copyWith(w: w, h: w * ratio));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (widget.disabled || e is KeyUpEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final step = keys.isShiftPressed ? 10.0 : 1.0;
    final k = e.logicalKey;
    final moves = {
      LogicalKeyboardKey.arrowLeft: Offset(-step, 0),
      LogicalKeyboardKey.arrowRight: Offset(step, 0),
      LogicalKeyboardKey.arrowUp: Offset(0, -step),
      LogicalKeyboardKey.arrowDown: Offset(0, step),
    };
    final m = moves[k];
    if (m != null) {
      if (keys.isAltPressed) {
        if (!widget.resizable) return KeyEventResult.ignored;
        _keyResize(m.dx, m.dy);
      } else {
        _nudge(m.dx, m.dy);
      }
      return KeyEventResult.handled;
    }
    final turn = k == LogicalKeyboardKey.bracketLeft || k == LogicalKeyboardKey.braceLeft
        ? -1
        : k == LogicalKeyboardKey.bracketRight || k == LogicalKeyboardKey.braceRight
            ? 1
            : 0;
    if (turn != 0 && widget.rotatable) {
      _turn(turn * (keys.isShiftPressed ? 15.0 : 1.0));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ----- build -----------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    final b = widget.box;
    final w = b.w * _px, h = b.h * _px;
    // Room around the box for handles and the knob, inside this widget so they can be hit.
    final m = touch ? 72.0 : 44.0;
    final hit = touch ? uiMinTouchTarget : 24.0;
    final stem = touch ? 34.0 : 22.0;
    final knob = touch ? 20.0 : 14.0;
    final box = Rect.fromLTWH(m, m, w, h);
    final enabled = !widget.disabled;

    // Edge handles only fit when the side is long enough to keep them clear of the corners.
    bool fits(_Handle hd) => hd.corner || (!widget.cornersOnly && (hd.sx == 0 ? w : h) >= hit * 3);

    Widget claim(UiTransformMode mode, Widget child, {_Handle? handle, MouseCursor cursor = SystemMouseCursors.basic}) => MouseRegion(
          cursor: enabled ? cursor : MouseCursor.defer,
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              _ClaimRecognizer: GestureRecognizerFactoryWithHandlers<_ClaimRecognizer>(_ClaimRecognizer.new, (r) => r.onDown = (e) => _down(e, mode, handle)),
            },
            child: child,
          ),
        );

    final children = <Widget>[
      // The outline (and the focus ring when reached by keyboard).
      Positioned.fromRect(
        rect: box,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(boxShadow: _focusRing ? t.focusRing : null),
            child: CustomPaint(painter: _OutlinePainter(t.primary, dashed: widget.disabled)),
          ),
        ),
      ),
      if (enabled) Positioned.fromRect(rect: box, child: claim(UiTransformMode.move, const SizedBox.expand(), cursor: SystemMouseCursors.move)),
      if (enabled && widget.rotatable) ...[
        Positioned(left: m + w / 2 - 0.75, top: m - stem, width: 1.5, height: stem, child: IgnorePointer(child: ColoredBox(color: t.primary))),
        Positioned(
          key: const Key('ui-transform-rotate'),
          left: m + w / 2 - hit / 2,
          top: m - stem - knob / 2 - hit / 2,
          width: hit,
          height: hit,
          child: claim(
            UiTransformMode.rotate,
            Center(
              child: Container(
                width: knob,
                height: knob,
                decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle, border: Border.all(color: t.surface, width: 2)),
              ),
            ),
            cursor: SystemMouseCursors.grab,
          ),
        ),
      ],
      if (enabled && widget.resizable)
        for (final hd in _Handle.values)
          if (fits(hd))
            Positioned(
              key: Key('ui-transform-${hd.name}'),
              left: m + (hd.sx + 1) / 2 * w - hit / 2,
              top: m + (hd.sy + 1) / 2 * h - hit / 2,
              width: hit,
              height: hit,
              child: claim(UiTransformMode.resize, Center(child: _HandleDot(touch: touch, corner: hd.corner)), handle: hd, cursor: hd.cursor),
            ),
    ];
    if (widget.showSize) {
      final style = context.uiText.code.copyWith(fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w500, color: t.primaryContrast, fontFeatures: const [FontFeature.tabularFigures()]);
      children.add(Positioned(
        left: m + w / 2 - 60,
        width: 120,
        top: m + h + 10,
        child: IgnorePointer(
          child: Center(
            child: Transform.rotate(
              angle: -b.rotate * math.pi / 180,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: t.space1),
                decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(t.radiusXs)),
                child: Text('${b.w.round()} × ${b.h.round()}', style: style),
              ),
            ),
          ),
        ),
      ));
    }

    String fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
    final content = Semantics(
      container: true,
      focusable: enabled,
      label: widget.label.isEmpty ? 'Selected element' : widget.label,
      value: '${fmt(b.x)}, ${fmt(b.y)}, ${fmt(b.w)} by ${fmt(b.h)}${b.rotate != 0 ? ', ${fmt(b.rotate)} degrees' : ''}',
      customSemanticsActions: enabled
          ? {
              const CustomSemanticsAction(label: 'Move left'): () => _nudge(-1, 0),
              const CustomSemanticsAction(label: 'Move right'): () => _nudge(1, 0),
              const CustomSemanticsAction(label: 'Move up'): () => _nudge(0, -1),
              const CustomSemanticsAction(label: 'Move down'): () => _nudge(0, 1),
              if (widget.rotatable) const CustomSemanticsAction(label: 'Rotate clockwise'): () => _turn(15),
              if (widget.rotatable) const CustomSemanticsAction(label: 'Rotate counter-clockwise'): () => _turn(-15),
            }
          : null,
      child: Focus(
        focusNode: _focus,
        canRequestFocus: enabled,
        onKeyEvent: _onKey,
        onFocusChange: (v) => setState(() => _focusRing = v && FocusManager.instance.highlightMode == FocusHighlightMode.traditional),
        child: Stack(clipBehavior: Clip.none, children: children),
      ),
    );

    return Positioned(
      left: b.x * _px - m,
      top: b.y * _px - m,
      width: w + 2 * m,
      height: h + 2 * m,
      child: Transform.rotate(angle: b.rotate * math.pi / 180, child: content),
    );
  }
}

/// Resizes [o] by a pointer delta ([dx], [dy] in units) on the handle that drags edges [sx]/[sy]
/// (-1 left/top, 1 right/bottom, 0 untouched), in the box's own rotated frame, keeping the
/// opposite edge fixed on screen (or the centre, with [fromCenter]). The resize maths of
/// [UiTransformBox], for hosts that drive it themselves.
UiBox uiResizeBox(UiBox o, int sx, int sy, double dx, double dy, {bool keepRatio = false, bool fromCenter = false, double minSize = 4}) {
  final rad = o.rotate * math.pi / 180;
  final cos = math.cos(rad), sin = math.sin(rad);
  // Pointer delta along the box's own axes.
  final lx = dx * cos + dy * sin;
  final ly = -dx * sin + dy * cos;
  final factor = fromCenter ? 2 : 1;
  var w = sx == 0 ? o.w : math.max(minSize, o.w + sx * lx * factor);
  var h = sy == 0 ? o.h : math.max(minSize, o.h + sy * ly * factor);
  if (keepRatio && o.w > 0 && o.h > 0) {
    final ratio = o.w / o.h;
    if (sx != 0 && sy != 0) {
      // Follow whichever axis moved further, relative to its size.
      if ((w / o.w - 1).abs() > (h / o.h - 1).abs()) {
        h = w / ratio;
      } else {
        w = h * ratio;
      }
    } else if (sx != 0) {
      h = w / ratio;
    } else {
      w = h * ratio;
    }
    w = math.max(minSize, w);
    h = math.max(minSize, h);
  }
  // Where the centre goes: halfway along the growth, in the box's frame, then back to the stage.
  final shiftX = fromCenter || sx == 0 ? 0.0 : sx * (w - o.w) / 2;
  final shiftY = fromCenter || sy == 0 ? 0.0 : sy * (h - o.h) / 2;
  final cx = o.x + o.w / 2 + shiftX * cos - shiftY * sin;
  final cy = o.y + o.h / 2 + shiftX * sin + shiftY * cos;
  return o.copyWith(x: cx - w / 2, y: cy - h / 2, w: w, h: h);
}

/// Claims a pointer the moment it lands (the web `touch-action: none`), so a scrolling parent
/// doesn't take a drag on a handle, and reports the down. Movement is followed by the box itself.
class _ClaimRecognizer extends OneSequenceGestureRecognizer {
  void Function(PointerDownEvent e)? onDown;

  @override
  bool isPointerAllowed(PointerDownEvent event) => (event.kind != PointerDeviceKind.mouse || event.buttons == kPrimaryButton) && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
    onDown?.call(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) stopTrackingPointer(event.pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'transform box claim';
}

class _HandleDot extends StatelessWidget {
  const _HandleDot({required this.touch, required this.corner});
  final bool touch;
  final bool corner;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final size = touch ? (corner ? 14.0 : 12.0) : 10.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.primary, width: 1.5),
        shape: touch ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: touch ? null : BorderRadius.circular(2),
      ),
    );
  }
}

class _OutlinePainter extends CustomPainter {
  const _OutlinePainter(this.color, {required this.dashed});
  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final r = Offset.zero & size;
    if (!dashed) {
      canvas.drawRect(r, p);
      return;
    }
    final path = Path()..addRect(r);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 4, metric.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_OutlinePainter old) => old.color != color || old.dashed != dashed;
}
