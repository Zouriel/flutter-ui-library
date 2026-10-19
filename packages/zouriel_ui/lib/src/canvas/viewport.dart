import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../button/button.dart';
import '../core/icon.dart';
import '../core/types.dart';
import '../theme/theme.dart';

/// Where the world is on screen: shifted by ([x], [y]) screen pixels and scaled by [zoom].
@immutable
class UiViewportView {
  const UiViewportView({this.x = 0, this.y = 0, this.zoom = 1});
  final double x;
  final double y;
  final double zoom;

  UiViewportView copyWith({double? x, double? y, double? zoom}) => UiViewportView(x: x ?? this.x, y: y ?? this.y, zoom: zoom ?? this.zoom);

  @override
  bool operator ==(Object other) => other is UiViewportView && other.x == x && other.y == y && other.zoom == zoom;
  @override
  int get hashCode => Object.hash(x, y, zoom);
  @override
  String toString() => 'UiViewportView($x, $y, ${zoom}x)';
}

/// A box drawn on the minimap, in world coordinates.
@immutable
class UiMinimapItem {
  const UiMinimapItem(this.rect, {this.active = false});
  final Rect rect;

  /// Highlighted (e.g. selected).
  final bool active;
}

/// Drives a [UiCanvasViewport]: its [view], fitting, zooming and turning pointer positions into
/// world coordinates. A viewport makes its own when none is given.
class UiCanvasViewportController extends ChangeNotifier {
  UiCanvasViewportController({UiViewportView view = const UiViewportView()}) : _view = view; // ignore: prefer_initializing_formals

  UiViewportView _view;
  Size _size = Size.zero;
  Size _content = const Size(800, 600);
  double _minZoom = 0.25;
  double _maxZoom = 2.5;
  double _padding = 32;
  double _fitMinZoom = 0.6;
  bool _auto = true;

  /// Fitting was asked for by name (the fit button, `0`): it shows everything, below `fitMinZoom`
  /// if it must, and keeps doing so on refits until the person pans or zooms.
  bool _all = false;

  /// Pointers down on the canvas: refits wait for them, so nothing jumps mid-gesture.
  int _held = 0;
  bool _fitWhenReleased = false;
  BuildContext? _context;

  /// The current view.
  UiViewportView get view => _view;
  set view(UiViewportView v) => _setView(v);

  /// The viewport's size on screen.
  Size get size => _size;

  /// True until someone pans or zooms: until then the view keeps fitting the content as the canvas
  /// resizes (a panel opening beside it) or the content changes. Tapping or dragging things on the
  /// canvas doesn't count; a refit that comes up mid-drag waits for the pointer to lift.
  bool get autoFit => _auto;

  void _setView(UiViewportView v, {bool notify = true}) {
    _auto = false;
    _all = false;
    if (v == _view) return;
    _view = v;
    if (notify) notifyListeners();
  }

  double _clamp(double z) => math.min(_maxZoom, math.max(_minZoom, z));

  /// Called by the viewport while laying out. Re-fits silently while [autoFit].
  void _configure(Size size, Size content, double minZoom, double maxZoom, double padding, double fitMinZoom) {
    final changed = size != _size || content != _content;
    _size = size;
    _content = content;
    _minZoom = minZoom;
    _maxZoom = maxZoom;
    _padding = padding;
    _fitMinZoom = fitMinZoom;
    if (!_auto || !changed) return;
    if (_held > 0) {
      _fitWhenReleased = true;
    } else {
      _view = _fitView() ?? _view;
    }
  }

  void _press() => _held++;

  void _release() {
    if (_held > 0) _held--;
    if (_held == 0 && _fitWhenReleased) {
      _fitWhenReleased = false;
      if (_auto) fit(all: _all);
    }
  }

  UiViewportView? _fitView() {
    final w = _size.width, h = _size.height;
    if (w <= 0 || h <= 0) return null;
    final p = _padding;
    final cw = math.max(1.0, _content.width), ch = math.max(1.0, _content.height);
    final whole = math.min(1.0, math.min((w - p * 2) / cw, (h - p * 2) / ch));
    final zoom = _clamp(_all ? whole : math.max(math.min(_fitMinZoom, 1), whole));
    // Content too big even at the smallest fit zoom starts at its top-left edge (the content brings
    // its own margin), not a padding in.
    double place(double room, double size) => size * zoom <= room - p * 2 ? (room - size * zoom) / 2 : 0;
    return UiViewportView(zoom: zoom, x: place(w, cw), y: place(h, ch));
  }

  /// Shows all the content, centred, never zooming in past 100% or out past the viewport's
  /// `fitMinZoom`; content too big for that shows from its top-left corner (the minimap shows the
  /// rest). With [all] (the fit button and `0`) it zooms out as far as `minZoom` to show everything.
  /// Turns auto-fit back on.
  void fit({bool all = false}) {
    _all = all;
    final v = _fitView();
    if (v == null) return;
    final changed = v != _view;
    _view = v;
    _auto = true;
    if (changed) notifyListeners();
  }

  /// Zooms by [factor] around a point on the viewport ([focal], local; the centre by default).
  void zoomBy(double factor, [Offset? focal]) {
    final c = focal ?? Offset(_size.width / 2, _size.height / 2);
    final v = _view;
    final zoom = _clamp(v.zoom * factor);
    final wx = (c.dx - v.x) / v.zoom, wy = (c.dy - v.y) / v.zoom;
    _setView(UiViewportView(zoom: zoom, x: c.dx - wx * zoom, y: c.dy - wy * zoom));
  }

  /// Scrolls so a world point is in the middle.
  void centerOn(Offset world) {
    final z = _view.zoom;
    _setView(UiViewportView(zoom: z, x: _size.width / 2 - world.dx * z, y: _size.height / 2 - world.dy * z));
  }

  /// Scrolls just enough to bring a world rectangle into view (with a 24px margin).
  void reveal(Rect world) {
    final v = _view;
    const m = 24.0;
    final w = _size.width, h = _size.height;
    var nx = v.x, ny = v.y;
    final sx = world.left * v.zoom + v.x, sy = world.top * v.zoom + v.y;
    final ex = world.right * v.zoom + v.x, ey = world.bottom * v.zoom + v.y;
    if (sx < m) {
      nx += m - sx;
    } else if (ex > w - m) {
      nx -= ex - (w - m);
    }
    if (sy < m) {
      ny += m - sy;
    } else if (ey > h - m) {
      ny -= ey - (h - m);
    }
    if (nx != v.x || ny != v.y) _setView(v.copyWith(x: nx, y: ny));
  }

  /// World coordinates of a point on the viewport (local coordinates).
  Offset localToWorld(Offset local) => Offset((local.dx - _view.x) / _view.zoom, (local.dy - _view.y) / _view.zoom);

  /// World coordinates of a global (screen) position, e.g. a pointer event's `position`.
  Offset toWorld(Offset global) {
    final box = _context?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return localToWorld(global);
    return localToWorld(box.globalToLocal(global));
  }

  /// A world point on the viewport (local coordinates).
  Offset worldToLocal(Offset world) => Offset(world.dx * _view.zoom + _view.x, world.dy * _view.zoom + _view.y);
}

/// Keeps the canvas from panning (or counting a tap as a background tap) when a drag or tap
/// starts on [child]: the web `data-viewport-no-pan`. Children with their own drag or tap
/// gestures already win over the canvas; wrap passive ones (a legend, a toolbar) in this.
class UiCanvasViewportNoPan extends StatelessWidget {
  const UiCanvasViewportNoPan({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(behavior: HitTestBehavior.opaque, onPanStart: (_) {}, onTap: () {}, child: child);
}

/// `ui-canvas-viewport`: a pannable, zoomable surface for diagrams. Put the diagram in [child],
/// laid out in world coordinates (0,0 at the top left, [contentWidth] × [contentHeight]).
///
/// - Pan: drag empty space (mouse or one finger), scroll with a trackpad or wheel, or arrow keys.
/// - Zoom: Ctrl/⌘ + wheel or trackpad pinch, two-finger pinch on touch, `+`/`-`, or the buttons.
/// - `0` or the fit button shows everything, zooming out past `fitMinZoom` if it must. Until someone pans or zooms (or touches the canvas
///   at all), the view keeps fitting the content as its size and the content change.
///
/// Children with their own gestures (cards being dragged, buttons) win over panning: they sit
/// deeper and claim the pointer first. Wrap passive children in [UiCanvasViewportNoPan]. Use
/// [UiCanvasViewportController.toWorld] to turn pointer positions into world coordinates.
class UiCanvasViewport extends StatefulWidget {
  const UiCanvasViewport({
    super.key,
    required this.child,
    this.controller,
    this.contentWidth = 800,
    this.contentHeight = 600,
    this.minZoom = 0.25,
    this.maxZoom = 2.5,
    this.padding = 32,
    this.fitMinZoom = 0.6,
    this.controls = true,
    this.minimap = false,
    this.minimapItems = const [],
    this.label = 'Diagram',
    this.onBackgroundTap,
  });

  final Widget child;
  final UiCanvasViewportController? controller;
  final double contentWidth;
  final double contentHeight;
  final double minZoom;
  final double maxZoom;

  /// Space kept around the content when fitting.
  final double padding;

  /// The smallest zoom fitting uses on its own (first view, refits); below it text is hard to read,
  /// so a large diagram starts at its top-left corner instead. The fit button goes further.
  final double fitMinZoom;
  final bool controls;
  final bool minimap;
  final List<UiMinimapItem> minimapItems;
  final String label;

  /// A tap on empty space (not after a pan).
  final VoidCallback? onBackgroundTap;

  @override
  State<UiCanvasViewport> createState() => _UiCanvasViewportState();
}

class _UiCanvasViewportState extends State<UiCanvasViewport> {
  UiCanvasViewportController? _own;
  final FocusNode _focus = FocusNode(debugLabel: 'canvas viewport');
  UiViewportView? _gestureStart;
  Offset _gestureFocal = Offset.zero;

  UiCanvasViewportController get _c => widget.controller ?? (_own ??= UiCanvasViewportController());

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
  }

  @override
  void didUpdateWidget(UiCanvasViewport old) {
    super.didUpdateWidget(old);
    final oldC = old.controller ?? _own;
    if (oldC != _c) {
      oldC?.removeListener(_changed);
      _c.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    _own?.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _down(PointerDownEvent e) => _c._press();
  void _up(PointerEvent e) => _c._release();

  void _signal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (ev) {
      final s = ev as PointerScrollEvent;
      final box = context.findRenderObject() as RenderBox;
      final keys = HardwareKeyboard.instance;
      if (keys.isControlPressed || keys.isMetaPressed) {
        // Trackpad pinches on the web arrive as ctrl+wheel with small deltas.
        _c.zoomBy(math.exp(-s.scrollDelta.dy * 0.0025), box.globalToLocal(s.position));
        return;
      }
      final v = _c.view;
      _c.view = v.copyWith(x: v.x - s.scrollDelta.dx, y: v.y - s.scrollDelta.dy);
    });
  }

  void _scaleStart(ScaleStartDetails d) {
    _gestureStart = _c.view;
    _gestureFocal = d.localFocalPoint;
  }

  void _scaleUpdate(ScaleUpdateDetails d) {
    final start = _gestureStart;
    if (start == null) return;
    final zoom = _c._clamp(start.zoom * d.scale);
    // The world point that was under the focal point at the start stays under the fingers.
    final wx = (_gestureFocal.dx - start.x) / start.zoom, wy = (_gestureFocal.dy - start.y) / start.zoom;
    _c.view = UiViewportView(zoom: zoom, x: d.localFocalPoint.dx - wx * zoom, y: d.localFocalPoint.dy - wy * zoom);
  }

  KeyEventResult _key(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
    final v = _c.view;
    const step = 40.0;
    final ch = e.character;
    final k = e.logicalKey;
    if (ch == '+' || ch == '=' || k == LogicalKeyboardKey.numpadAdd) {
      _c.zoomBy(1.2);
    } else if (ch == '-' || ch == '_' || k == LogicalKeyboardKey.numpadSubtract) {
      _c.zoomBy(1 / 1.2);
    } else if (ch == '0' || k == LogicalKeyboardKey.numpad0) {
      _c.fit(all: true);
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      _c.view = v.copyWith(x: v.x + step);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _c.view = v.copyWith(x: v.x - step);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _c.view = v.copyWith(y: v.y + step);
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _c.view = v.copyWith(y: v.y - step);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final c = _c;
    c._context = context;
    final settings = MediaQuery.maybeGestureSettingsOf(context);
    return LayoutBuilder(builder: (context, box) {
      final size = box.biggest;
      c._configure(size, Size(widget.contentWidth, widget.contentHeight), widget.minZoom, widget.maxZoom, widget.padding, widget.fitMinZoom);
      final v = c.view;
      final roomy = size.width >= 520 && size.height >= 340;
      return Semantics(
        container: true,
        label: widget.label,
        hint: 'canvas',
        child: Focus(
          focusNode: _focus,
          onKeyEvent: _key,
          child: Listener(
            onPointerDown: (e) {
              _down(e);
              if (!_focus.hasFocus) _focus.requestFocus();
            },
            onPointerUp: _up,
            onPointerCancel: _up,
            onPointerSignal: _signal,
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                ScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
                  () => ScaleGestureRecognizer(),
                  (r) => r
                    ..gestureSettings = settings
                    ..onStart = _scaleStart
                    ..onUpdate = _scaleUpdate
                    ..onEnd = (_) => _gestureStart = null,
                ),
                TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(),
                  (r) => r
                    ..gestureSettings = settings
                    ..onTap = widget.onBackgroundTap,
                ),
              },
              child: ClipRect(
                child: Stack(children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: t.bg,
                      child: CustomPaint(painter: _Dots(t.text.withValues(alpha: 0.10), 18 * v.zoom, Offset(v.x, v.y))),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Transform(
                      transform: Matrix4.identity()
                        ..translateByDouble(v.x, v.y, 0, 1)
                        ..scaleByDouble(v.zoom, v.zoom, 1, 1),
                      child: SizedBox(width: widget.contentWidth, height: widget.contentHeight, child: widget.child),
                    ),
                  ),
                  if (widget.controls) Positioned(right: t.space2, bottom: t.space2, child: UiCanvasViewportNoPan(child: _Controls(controller: c))),
                  if (widget.minimap && widget.minimapItems.isNotEmpty && roomy)
                    Positioned(
                      left: t.space2,
                      bottom: t.space2,
                      child: _Minimap(controller: c, items: widget.minimapItems, content: Size(widget.contentWidth, widget.contentHeight)),
                    ),
                ]),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _Dots extends CustomPainter {
  _Dots(this.color, this.spacing, this.origin);
  final Color color;
  final double spacing;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    if (spacing < 5) return;
    final paint = Paint()..color = color;
    final ox = origin.dx % spacing, oy = origin.dy % spacing;
    for (var y = oy; y < size.height; y += spacing) {
      for (var x = ox; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Dots old) => old.color != color || old.spacing != spacing || old.origin != origin;
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller});
  final UiCanvasViewportController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    Widget btn(UiIconData icon, String label, VoidCallback onTap) =>
        UiIconButton(icon: UiIcon(icon, size: 15), label: label, size: UiSize.sm, variant: UiButtonVariant.ghost, iconColor: t.textSecondary, onPressed: onTap);
    final pct = (controller.view.zoom * 100).round();
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(t.radius),
        boxShadow: t.shadow1,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, spacing: 2, children: [
        btn(HugeIcons.strokeRoundedMinusSign, 'Zoom out', () => controller.zoomBy(1 / 1.2)),
        SizedBox(
          width: 38,
          child: Semantics(
            label: 'Zoom $pct%',
            child: Text('$pct%', textAlign: TextAlign.center, style: context.uiText.label.copyWith(fontSize: 11.5, fontWeight: FontWeight.w500, color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ),
        btn(HugeIcons.strokeRoundedPlusSign, 'Zoom in', () => controller.zoomBy(1.2)),
        btn(HugeIcons.strokeRoundedFullScreen, 'Fit to view', () => controller.fit(all: true)),
      ]),
    );
  }
}

class _Minimap extends StatelessWidget {
  const _Minimap({required this.controller, required this.items, required this.content});
  final UiCanvasViewportController controller;
  final List<UiMinimapItem> items;
  final Size content;

  static const double _w = 150, _pad = 4;

  ({double s, double w, double h, double height}) _geometry() {
    final cw = math.max(1.0, content.width), ch = math.max(1.0, content.height);
    final s = 140 / math.max(cw, ch);
    final mw = cw * s, mh = ch * s;
    final height = math.min(110.0, _pad * 2 + (_w - _pad * 2) * mh / mw);
    return (s: s, w: mw, h: mh, height: height);
  }

  void _go(Offset local) {
    final g = _geometry();
    final k = math.min((_w - _pad * 2) / g.w, (g.height - _pad * 2) / g.h);
    final dx = (_w - g.w * k) / 2, dy = (g.height - g.h * k) / 2;
    final px = (local.dx - dx) / k, py = (local.dy - dy) / k;
    controller.centerOn(Offset(px / g.s, py / g.s));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final g = _geometry();
    return ExcludeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _go(d.localPosition),
        onPanStart: (d) => _go(d.localPosition),
        onPanUpdate: (d) => _go(d.localPosition),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: _w,
            height: g.height,
            decoration: BoxDecoration(color: t.surfaceRaised, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
            child: CustomPaint(
              painter: _MinimapPainter(
                items: items,
                view: controller.view,
                viewport: controller.size,
                s: g.s,
                mw: g.w,
                mh: g.h,
                item: t.text.withValues(alpha: 0.22),
                active: t.primary,
                frame: t.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  _MinimapPainter({required this.items, required this.view, required this.viewport, required this.s, required this.mw, required this.mh, required this.item, required this.active, required this.frame});
  final List<UiMinimapItem> items;
  final UiViewportView view;
  final Size viewport;
  final double s, mw, mh;
  final Color item, active, frame;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 4.0;
    final k = math.min((size.width - pad * 2) / mw, (size.height - pad * 2) / mh);
    canvas.save();
    canvas.translate((size.width - mw * k) / 2, (size.height - mh * k) / 2);
    canvas.scale(k);
    for (final it in items) {
      final r = Rect.fromLTWH(it.rect.left * s, it.rect.top * s, it.rect.width * s, it.rect.height * s);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), Paint()..color = it.active ? active : item);
    }
    final vr = Rect.fromLTWH((-view.x / view.zoom) * s, (-view.y / view.zoom) * s, (viewport.width / view.zoom) * s, (viewport.height / view.zoom) * s);
    final rr = RRect.fromRectAndRadius(vr, const Radius.circular(2));
    canvas.drawRRect(rr, Paint()..color = frame.withValues(alpha: 0.10));
    canvas.drawRRect(rr, Paint()
      ..color = frame
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / k);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MinimapPainter old) => true;
}
