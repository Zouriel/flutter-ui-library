import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../core/types.dart';
import '../theme/theme.dart';
import 'map.dart';

/// A search area on the map (0.44.0, the web `UiMapArea`): a circle of [radiusMeters] around
/// [center] in [tone]. [editable] adds a drag handle on its edge that changes the radius between
/// [minMeters] and [maxMeters].
@immutable
class UiMapArea {
  const UiMapArea({
    required this.center,
    required this.radiusMeters,
    this.tone = UiStatus.primary,
    this.editable = false,
    this.minMeters = uiMapAreaMinMeters,
    this.maxMeters = uiMapAreaMaxMeters,
  });

  final UiLatLng center;
  final double radiusMeters;
  final UiStatus tone;
  final bool editable;
  final double minMeters, maxMeters;

  @override
  bool operator ==(Object other) =>
      other is UiMapArea &&
      other.center == center &&
      other.radiusMeters == radiusMeters &&
      other.tone == tone &&
      other.editable == editable &&
      other.minMeters == minMeters &&
      other.maxMeters == maxMeters;

  @override
  int get hashCode => Object.hash(center, radiusMeters, tone, editable, minMeters, maxMeters);
}

/// The default smallest and largest search area radius, in metres (0.44.0).
const double uiMapAreaMinMeters = 200, uiMapAreaMaxMeters = 50000;

/// The Earth's radius the map's distances use, in metres (Leaflet's).
const double uiMapEarthRadius = 6371000;

/// Metres per px at [lat] and [zoom] (Web Mercator, 256 px tiles at zoom 0; the web
/// `uiMapMetersPerPx`).
double uiMapMetersPerPx(double lat, double zoom) => 40075016.686 * math.cos(lat * math.pi / 180) / math.pow(2, zoom + 8);

/// The step a radius of [m] metres is rounded to: 10 m under 1 km, 100 m under 10 km, else 1 km.
double uiMapRadiusUnit(double m) => m < 1000 ? 10 : (m < 10000 ? 100 : 1000);

/// [m] rounded to its [uiMapRadiusUnit] (the web `uiMapNiceRadius`).
double uiMapNiceRadius(double m) {
  final u = uiMapRadiusUnit(m);
  return (m / u).roundToDouble() * u;
}

/// One keyboard step of a search area's radius (the web `uiMapAreaStep`): 10% out ([direction] > 0)
/// or in, rounded with [uiMapNiceRadius] and at least one unit, kept to [min]..[max].
double uiMapAreaStep(double radius, int direction, double min, double max) {
  var next = uiMapNiceRadius(direction > 0 ? radius * 1.1 : radius / 1.1);
  if (direction > 0 && next <= radius) next = radius + uiMapRadiusUnit(radius);
  if (direction < 0 && next >= radius) next = radius - uiMapRadiusUnit(math.max(0, radius - 1));
  return next.clamp(min, max).toDouble();
}

/// A radius as text (the web `uiMapFormatRadius`): "800 m" under 1 km, "1.5 km" (one decimal, a
/// trailing ".0" dropped) under 10 km, else whole kilometres ("20 km"). Words from [strings]
/// ([UiStrings.mapRadiusMeters] / [UiStrings.mapRadiusKilometers]).
String uiMapFormatRadius(double meters, [UiStrings strings = const UiStrings()]) {
  if (meters < 1000) return strings.mapRadiusMeters.replaceAll('{n}', meters.round().toString());
  final km = meters / 1000;
  final n = km < 10 ? ((km * 10).round() / 10).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '') : km.round().toString();
  return strings.mapRadiusKilometers.replaceAll('{n}', n);
}

/// The points at the north, south, east and west of a search area's circle, for fitting it.
List<UiLatLng> uiMapAreaBounds(UiMapArea a) {
  final dLat = a.radiusMeters / uiMapEarthRadius * 180 / math.pi;
  final dLng = a.radiusMeters / (uiMapEarthRadius * math.cos(a.center.lat * math.pi / 180)) * 180 / math.pi;
  final c = a.center;
  return [UiLatLng(c.lat + dLat, c.lng), UiLatLng(c.lat - dLat, c.lng), UiLatLng(c.lat, c.lng + dLng), UiLatLng(c.lat, c.lng - dLng)];
}

/// How many px the circle's radius is on screen for [radius] metres around [lat] at [zoom].
double uiMapAreaRadiusPx(double radius, double lat, double zoom) => radius / uiMapMetersPerPx(lat, zoom);

/// The search area's circle (exported for tests): a soft fill in its tone and a clear outline over
/// a casing, drawn in true metres for the camera's zoom. Never hit: drags pan the map through it.
class UiMapAreaLayer extends StatelessWidget {
  const UiMapAreaLayer({super.key, required this.area, required this.radius});
  final UiMapArea area;

  /// The radius drawn (the area's, or the one being dragged).
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final cam = MapCamera.of(context);
    final color = area.tone == UiStatus.neutral ? t.textMuted : area.tone.color(t);
    // In the layer's own (unturned) pixels: MobileLayerTransformer turns the layer with the map (0.47.0).
    final c = cam.projectAtZoom(LatLng(area.center.lat, area.center.lng)) - cam.pixelOrigin;
    final r = uiMapAreaRadiusPx(radius, area.center.lat, cam.zoom);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: MobileLayerTransformer(
          child: CustomPaint(size: Size.infinite, painter: UiMapAreaPainter(center: c, radius: r, color: color, casing: t.mapRouteCasing)),
        ),
      ),
    );
  }
}

/// Paints the area's circle (exported for tests): fill at 12% of [color], a 4px [casing] at 90%
/// under a 2px [color] line.
class UiMapAreaPainter extends CustomPainter {
  UiMapAreaPainter({required this.center, required this.radius, required this.color, required this.casing});
  final Offset center;
  final double radius;
  final Color color, casing;

  @override
  void paint(Canvas canvas, Size size) {
    if (!(radius > 0)) return;
    canvas.drawCircle(center, radius, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawCircle(center, radius, Paint()
      ..color = casing.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4);
    canvas.drawCircle(center, radius, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(UiMapAreaPainter old) => old.center != center || old.radius != radius || old.color != color || old.casing != casing;
}

/// The radius handle's dot, in px across.
const double uiMapAreaHandleDot = 24;

/// The handle layer: the round handle on the circle's inline-end edge with the radius chip above it.
class UiMapAreaHandleLayer extends StatelessWidget {
  const UiMapAreaHandleLayer({
    super.key,
    required this.area,
    required this.radius,
    required this.rtl,
    required this.label,
    required this.onDragStart,
    required this.onDrag,
    required this.onDragEnd,
    required this.onStep,
  });
  final UiMapArea area;
  final double radius;
  final bool rtl;
  final String label;
  final VoidCallback onDragStart;

  /// The finger's global position.
  final ValueChanged<Offset> onDrag;
  final VoidCallback onDragEnd;

  /// A keyboard or screen reader step to the given radius.
  final ValueChanged<double> onStep;

  @override
  Widget build(BuildContext context) {
    final cam = MapCamera.of(context);
    // In the layer's own (unturned) pixels: MobileLayerTransformer turns the layer with the map (0.47.0).
    final c = cam.projectAtZoom(LatLng(area.center.lat, area.center.lng)) - cam.pixelOrigin;
    final r = uiMapAreaRadiusPx(radius, area.center.lat, cam.zoom);
    final at = c + Offset(rtl ? -r : r, 0);
    const box = uiMinTouchTargetArea;
    return MobileLayerTransformer(
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: at.dx - box / 2,
          top: at.dy - box / 2,
          width: box,
          height: box,
          // Upright on a turned map (0.47.0).
          child: Transform.rotate(
            angle: -cam.rotationRad,
            child: UiMapAreaHandle(
            key: const ValueKey('ui-map-area-handle'),
            area: area,
            radius: radius,
            rtl: rtl,
            label: label,
            onDragStart: onDragStart,
            onDrag: onDrag,
            onDragEnd: onDragEnd,
            onStep: onStep,
          ),
          ),
        ),
      ]),
    );
  }
}

/// The handle's touch box, in px (48dp on every platform: it is dragged).
const double uiMinTouchTargetArea = 48;

class _Step extends Intent {
  const _Step(this.to);

  /// 1 out, -1 in, 2 the largest, -2 the smallest.
  final int to;
}

/// The radius handle (exported for tests): a 24px round handle in the area's tone, a 48dp target
/// that a drag claims at once (the map doesn't pan under it), a slider for keyboards and screen
/// readers, and the radius chip above it.
class UiMapAreaHandle extends StatefulWidget {
  const UiMapAreaHandle({
    super.key,
    required this.area,
    required this.radius,
    required this.rtl,
    required this.label,
    required this.onDragStart,
    required this.onDrag,
    required this.onDragEnd,
    required this.onStep,
  });
  final UiMapArea area;
  final double radius;
  final bool rtl;
  final String label;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onDragEnd;
  final ValueChanged<double> onStep;

  @override
  State<UiMapAreaHandle> createState() => _UiMapAreaHandleState();
}

class _UiMapAreaHandleState extends State<UiMapAreaHandle> {
  bool _focus = false, _hasFocus = false, _active = false;

  double _next(int to) {
    final a = widget.area;
    return switch (to) {
      2 => a.maxMeters,
      -2 => a.minMeters,
      _ => uiMapAreaStep(widget.radius, to, a.minMeters, a.maxMeters),
    };
  }

  void _step(int to) {
    final n = _next(to);
    if (n != widget.radius) widget.onStep(n);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final strings = context.uiStrings;
    final a = widget.area;
    final color = a.tone == UiStatus.neutral ? t.textMuted : a.tone.color(t);
    // Out is the inline end: Right in LTR, Left in RTL.
    final out = widget.rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight;
    final inward = widget.rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft;
    final up = _next(1), down = _next(-1);
    final chip = Container(
      padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: 2),
      decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: BorderRadius.circular(t.radiusLg), border: Border.all(color: t.border), boxShadow: t.shadow1),
      child: Text(uiMapFormatRadius(widget.radius, strings), maxLines: 1, softWrap: false, style: context.uiText.label.copyWith(fontSize: 12, height: 16 / 12)),
    );
    final dot = AnimatedContainer(
      duration: context.uiAnimate ? t.motionFast : Duration.zero,
      width: _active ? uiMapAreaHandleDot * 1.15 : uiMapAreaHandleDot,
      height: _active ? uiMapAreaHandleDot * 1.15 : uiMapAreaHandleDot,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.surfaceRaised,
        border: Border.all(color: color, width: 3),
        boxShadow: _focus ? [...t.shadow2, ...t.focusRing] : t.shadow2,
      ),
    );
    return FocusableActionDetector(
      shortcuts: {
        SingleActivator(out): const _Step(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): const _Step(1),
        SingleActivator(inward): const _Step(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): const _Step(-1),
        const SingleActivator(LogicalKeyboardKey.home): const _Step(-2),
        const SingleActivator(LogicalKeyboardKey.end): const _Step(2),
      },
      actions: {_Step: CallbackAction<_Step>(onInvoke: (i) => _step(i.to))},
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      onFocusChange: (v) => setState(() => _hasFocus = v),
      // The slider below is the one node, focusable itself.
      includeFocusSemantics: false,
      mouseCursor: SystemMouseCursors.grab,
      child: Semantics(
        container: true,
        slider: true,
        focusable: true,
        focused: _hasFocus,
        label: widget.label,
        value: uiMapFormatRadius(widget.radius, strings),
        increasedValue: up != widget.radius ? uiMapFormatRadius(up, strings) : null,
        decreasedValue: down != widget.radius ? uiMapFormatRadius(down, strings) : null,
        onIncrease: up != widget.radius ? () => _step(1) : null,
        onDecrease: down != widget.radius ? () => _step(-1) : null,
        excludeSemantics: true,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            UiMapEagerDragRecognizer: GestureRecognizerFactoryWithHandlers<UiMapEagerDragRecognizer>(
              () => UiMapEagerDragRecognizer(debugOwner: this),
              (r) => r
                ..onStart = (_) {
                  setState(() => _active = true);
                  widget.onDragStart();
                }
                ..onUpdate = widget.onDrag
                ..onEnd = () {
                  if (mounted) setState(() => _active = false);
                  widget.onDragEnd();
                },
            ),
          },
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            dot,
            // The chip floats above the handle, 8px over the dot; it takes no input of its own.
            Positioned(
              bottom: uiMinTouchTargetArea / 2 + uiMapAreaHandleDot / 2 + t.space2,
              child: IgnorePointer(child: UnconstrainedBox(child: chip)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A drag that is claimed as soon as the pointer lands (exported for tests), so the map under the
/// area handle never pans with it. [onUpdate] gets the global position.
class UiMapEagerDragRecognizer extends OneSequenceGestureRecognizer {
  UiMapEagerDragRecognizer({super.debugOwner});

  ValueChanged<Offset>? onStart;
  ValueChanged<Offset>? onUpdate;
  VoidCallback? onEnd;
  int? _pointer;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
    onStart?.call(event.position);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
      onUpdate?.call(event.position);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _finish();
    }
  }

  void _finish() {
    final p = _pointer;
    if (p == null) return;
    _pointer = null;
    stopTrackingPointer(p);
    onEnd?.call();
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer == _pointer) _finish();
    super.rejectGesture(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'map area drag';
}
