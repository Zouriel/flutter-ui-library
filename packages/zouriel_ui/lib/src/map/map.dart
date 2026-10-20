import 'dart:convert' show base64Decode;

import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../button/button.dart';
import '../core/icon.dart';
import '../core/types.dart';
import '../fx/motion.dart';
import '../theme/theme.dart';

/// A point on the map (the web `UiLatLng`).
@immutable
class UiLatLng {
  const UiLatLng(this.lat, this.lng);
  final double lat;
  final double lng;

  LatLng get _ll => LatLng(lat, lng);

  @override
  bool operator ==(Object other) => other is UiLatLng && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'UiLatLng($lat, $lng)';
}

/// A marker: a tone-coloured dot with an optional label beside it (the web `UiMapMarker`).
@immutable
class UiMapMarker {
  const UiMapMarker({required this.id, required this.lat, required this.lng, this.tone = UiStatus.primary, this.label, this.semanticLabel});
  final String id;
  final double lat;
  final double lng;
  final UiStatus tone;
  final String? label;

  /// The marker's accessible name when the label doesn't say enough, or there is no label (the id
  /// is never read out).
  final String? semanticLabel;
}

/// Tiles without the network: every tile a transparent pixel. For widget tests of screens with a
/// map, and for a map that only shows markers: `UiMap(tileProvider: UiMapBlankTiles())`.
class UiMapBlankTiles extends TileProvider {
  UiMapBlankTiles();

  static final MemoryImage _pixel = MemoryImage(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='));

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => _pixel;
}

/// Where the map is looking (the web `UiMapView`).
@immutable
class UiMapView {
  const UiMapView(this.lat, this.lng, this.zoom);
  final double lat;
  final double lng;
  final double zoom;
}

/// OpenStreetMap's standard tiles; use them within the OSM tile usage policy, or pass your own.
const String uiMapOsmTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// `ui-map`: an OpenStreetMap map (flutter_map 8.3.2) with markers and an optional draggable pin.
/// Import it from `package:zouriel_ui/map.dart`; it isn't part of the main library export.
///
/// - [markers]: dots in their tone with a label; tapping one calls [onMarkerSelected].
/// - [pin] / [onPinChanged] with [pinMode]: a draggable pin, and a tap on the map moves it there.
///   For screen readers the map has a "Place the pin at the centre" action, and with a keyboard
///   Enter on the focused map does the same.
/// - [center] / [zoom] move the map; [onCenterChanged] reports where the person moved it.
/// - Theme-aware: themed zoom buttons, and on a dark theme the tiles are dimmed.
/// - The zoom buttons sit at the inline start and the attribution at the inline end, so they swap
///   in RTL; under reduced motion there is no fling.
///
/// [userAgentPackageName] is sent with tile requests (the OSM policy asks for it); [tileProvider]
/// replaces network tiles (offline tiles, tests).
class UiMap extends StatefulWidget {
  const UiMap({
    super.key,
    this.center = const UiLatLng(4.1755, 73.5093),
    this.zoom = 13,
    this.markers = const [],
    this.onMarkerSelected,
    this.onCenterChanged,
    this.pin,
    this.onPinChanged,
    this.pinMode = false,
    this.pinLabel = 'Chosen location',
    this.pinDraggable = true,
    this.tileHeaders,
    this.tileUrl = uiMapOsmTiles,
    this.attribution = '© OpenStreetMap contributors',
    this.onAttributionTap,
    this.semanticLabel = 'Map',
    this.userAgentPackageName = 'com.zouriel.ui',
    this.tileProvider,
  });

  final UiLatLng center;
  final double zoom;
  final List<UiMapMarker> markers;
  final ValueChanged<UiMapMarker>? onMarkerSelected;
  final ValueChanged<UiMapView>? onCenterChanged;

  /// The chosen point; shown as a draggable pin when set.
  final UiLatLng? pin;
  final ValueChanged<UiLatLng>? onPinChanged;

  /// A tap on the map moves the pin there.
  final bool pinMode;
  final String pinLabel;

  /// Whether the pin can be dragged; false shows a fixed location with the pin's look.
  final bool pinDraggable;

  /// Extra HTTP headers for tile requests (the User-Agent from [userAgentPackageName] is always sent).
  final Map<String, String>? tileHeaders;
  final String tileUrl;
  final String attribution;

  /// Open the attribution's source (e.g. the OSM copyright page with url_launcher).
  final VoidCallback? onAttributionTap;
  final String semanticLabel;
  final String userAgentPackageName;
  final TileProvider? tileProvider;

  @override
  State<UiMap> createState() => UiMapState();
}

class UiMapState extends State<UiMap> {
  final MapController _controller = MapController();
  final GlobalKey _box = GlobalKey();

  /// The pin while a finger drags it.
  UiLatLng? _dragging;
  bool _ready = false;

  /// The map controller, to move the map from code.
  MapController get controller => _controller;

  @override
  void didUpdateWidget(UiMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready) return;
    if (oldWidget.center != widget.center || oldWidget.zoom != widget.zoom) {
      final c = _controller.camera;
      if (c.center.latitude != widget.center.lat || c.center.longitude != widget.center.lng || c.zoom != widget.zoom) {
        _controller.move(widget.center._ll, widget.zoom);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _placeAtCentre() {
    final c = _controller.camera.center;
    widget.onPinChanged?.call(UiLatLng(c.latitude, c.longitude));
  }

  void _zoomBy(double d) {
    final c = _controller.camera;
    _controller.move(c.center, (c.zoom + d).clamp(1, 19));
    widget.onCenterChanged?.call(UiMapView(c.center.latitude, c.center.longitude, _controller.camera.zoom));
  }

  void _onEvent(MapEvent e) {
    if (e.source == MapEventSource.mapController) return;
    if (e is MapEventMoveEnd || e is MapEventFlingAnimationEnd || e is MapEventDoubleTapZoomEnd || e is MapEventScrollWheelZoom) {
      final c = e.camera;
      widget.onCenterChanged?.call(UiMapView(c.center.latitude, c.center.longitude, c.zoom));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final dark = context.uiTheme.brightness == Brightness.dark;
    final motion = uiFxMotion(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final pin = _dragging ?? widget.pin;
    final tileProvider = widget.tileProvider ?? NetworkTileProvider(headers: {...?widget.tileHeaders});
    if (widget.tileHeaders != null) tileProvider.headers.addAll(widget.tileHeaders!);

    final map = FlutterMap(
      key: _box,
      mapController: _controller,
      options: MapOptions(
        initialCenter: widget.center._ll,
        initialZoom: widget.zoom,
        backgroundColor: t.surfaceSubtle,
        onMapReady: () => _ready = true,
        onMapEvent: _onEvent,
        onTap: (_, ll) {
          if (widget.pinMode) widget.onPinChanged?.call(UiLatLng(ll.latitude, ll.longitude));
        },
        interactionOptions: InteractionOptions(
          flags: motion == UiFxMotion.full ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.all & ~InteractiveFlag.rotate & ~InteractiveFlag.flingAnimation,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: widget.tileUrl,
          userAgentPackageName: widget.userAgentPackageName,
          tileProvider: tileProvider,
          tileBuilder: dark ? _dim : null,
        ),
        MarkerLayer(markers: [
          for (final m in widget.markers)
            Marker(
              point: LatLng(m.lat, m.lng),
              width: 248,
              height: 48,
              alignment: Alignment.centerRight,
              child: _MarkerChip(marker: m, onTap: widget.onMarkerSelected == null ? null : () => widget.onMarkerSelected!(m)),
            ),
        ]),
        if (pin != null)
          MarkerLayer(markers: [
            Marker(
              point: pin._ll,
              width: 48,
              height: 48,
              alignment: Alignment.topCenter,
              child: _Pin(
                label: widget.pinLabel,
                draggable: widget.pinDraggable,
                onDrag: (global) {
                  final box = _box.currentContext?.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  // The pin's tip is at the bottom of its 48px box: aim the tip at the finger's point.
                  final ll = _controller.camera.screenOffsetToLatLng(box.globalToLocal(global));
                  setState(() => _dragging = UiLatLng(ll.latitude, ll.longitude));
                },
                onDragEnd: () {
                  final d = _dragging;
                  setState(() => _dragging = null);
                  if (d != null) widget.onPinChanged?.call(d);
                },
              ),
            ),
          ]),
      ],
    );

    final zoom = Column(mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
      UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedAdd01), label: context.uiStrings.zoomIn, variant: UiButtonVariant.outline, onPressed: () => _zoomBy(1)),
      UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedMinusSign), label: context.uiStrings.zoomOut, variant: UiButtonVariant.outline, onPressed: () => _zoomBy(-1)),
    ]);
    final attribution = GestureDetector(
      onTap: widget.onAttributionTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: t.space1, vertical: 2),
        color: t.surfaceRaised.withValues(alpha: 0.85),
        child: Text(widget.attribution, style: context.uiText.caption.copyWith(fontSize: 11, color: t.textMuted)),
      ),
    );

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      customSemanticsActions: widget.pinMode ? {CustomSemanticsAction(label: context.uiStrings.placePinAtCentre): _placeAtCentre} : null,
      // Not focusable itself: flutter_map's own surface takes focus (and the arrow keys); Enter
      // bubbles up to here. A second focusable node would split the map in two for screen readers,
      // leaving the tappable surface unnamed.
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: (node, e) {
          if (widget.pinMode && e is KeyDownEvent && (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter)) {
            _placeAtCentre();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(context.uiTheme.radius(t.radius)),
          child: ColoredBox(
            color: t.surfaceSubtle,
            child: Stack(children: [
              // Leaflet and flutter_map lay out in screen terms; keep the map itself LTR.
              Positioned.fill(child: Directionality(textDirection: TextDirection.ltr, child: map)),
              PositionedDirectional(top: t.space2, start: t.space2, child: zoom),
              Positioned(bottom: 0, right: rtl ? null : 0, left: rtl ? 0 : null, child: attribution),
            ]),
          ),
        ),
      ),
    );
  }

  /// Dark themes: dim and desaturate the tiles rather than shine a white street map.
  static Widget _dim(BuildContext context, Widget tile, TileImage _) => ColorFiltered(colorFilter: const ColorFilter.matrix(_dimMatrix), child: tile);
}

// brightness 0.62, saturation 0.6.
const List<double> _dimMatrix = [
  0.62 * (0.4 + 0.6 * 0.2126), 0.62 * 0.4 * 0.7152, 0.62 * 0.4 * 0.0722, 0, 0, //
  0.62 * 0.4 * 0.2126, 0.62 * (0.4 + 0.6 * 0.7152), 0.62 * 0.4 * 0.0722, 0, 0, //
  0.62 * 0.4 * 0.2126, 0.62 * 0.4 * 0.7152, 0.62 * (0.4 + 0.6 * 0.0722), 0, 0, //
  0, 0, 0, 1, 0,
];

class _MarkerChip extends StatelessWidget {
  const _MarkerChip({required this.marker, this.onTap});
  final UiMapMarker marker;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final color = marker.tone == UiStatus.neutral ? t.textMuted : marker.tone.color(t);
    return Align(
      alignment: Alignment.centerLeft,
      child: Transform.translate(
        // A 48dp square around the dot is the tap target; its centre (the dot) on the point.
        offset: const Offset(-24, 0),
        child: Semantics(
          container: true,
          button: onTap != null,
          label: marker.semanticLabel ?? marker.label,
          onTap: onTap,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              height: 48,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 48,
                  child: Center(
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: t.surfaceRaised, width: 3), boxShadow: t.shadow2),
                    ),
                  ),
                ),
                if (marker.label != null)
                  Transform.translate(
                    offset: Offset(-t.space3, 0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 196),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: 2),
                        decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: BorderRadius.circular(t.radiusPill), border: Border.all(color: t.border), boxShadow: t.shadow1),
                        child: Text(marker.label!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.label.copyWith(fontSize: 12)),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.label, required this.onDrag, required this.onDragEnd, this.draggable = true});
  final String label;
  final bool draggable;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final pin = Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 28,
            height: 36,
            child: CustomPaint(painter: _PinPainter(fill: t.accent, ring: t.surfaceRaised, shadow: t.shadow2)),
          ),
        );
    // A fixed pin is an image with a name; a draggable one also takes the drag.
    if (!draggable) return Semantics(container: true, label: label, image: true, child: IgnorePointer(child: pin));
    return Semantics(
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => onDrag(d.globalPosition + const Offset(0, 24)),
        onPanEnd: (_) => onDragEnd(),
        onPanCancel: onDragEnd,
        child: pin,
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  _PinPainter({required this.fill, required this.ring, required this.shadow});
  final Color fill, ring;
  final List<BoxShadow> shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = w / 2 - 2;
    final path = Path()
      ..moveTo(w / 2, h - 1)
      ..quadraticBezierTo(2, h * 0.5, 2, r + 2)
      ..arcToPoint(Offset(w - 2, r + 2), radius: Radius.circular(r))
      ..quadraticBezierTo(w - 2, h * 0.5, w / 2, h - 1)
      ..close();
    for (final s in shadow) {
      canvas.drawPath(path.shift(s.offset), Paint()..color = s.color..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blurRadius / 2));
    }
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(path, Paint()..color = ring..style = PaintingStyle.stroke..strokeWidth = 3);
    canvas.drawCircle(Offset(w / 2, r + 2), 4, Paint()..color = ring);
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.fill != fill || old.ring != ring;
}
