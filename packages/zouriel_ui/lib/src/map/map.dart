import 'dart:convert' show base64Decode;
import 'dart:math' as math;

import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../button/button.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../feedback/spinner.dart';
import '../overlay/tooltip.dart';
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

  // A grey-and-alpha pixel at alpha 0. (Until 0.39 this was a half-transparent blue pixel, which
  // tinted every "blank" map.)
  static final MemoryImage _pixel = MemoryImage(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='));

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

/// The "searching" animation (the web `UiMapPulse`): soft rings radiating from a point on the map
/// while [active]. Under reduced motion, one still halo instead.
@immutable
class UiMapPulse {
  const UiMapPulse({required this.lat, required this.lng, this.tone = UiStatus.primary, this.active = true});
  final double lat;
  final double lng;

  /// The rings' colour.
  final UiStatus tone;

  /// False shows nothing and runs nothing.
  final bool active;

  @override
  bool operator ==(Object other) => other is UiMapPulse && other.lat == lat && other.lng == lng && other.tone == tone && other.active == active;

  @override
  int get hashCode => Object.hash(lat, lng, tone, active);
}

/// Where the person is, from the app's own geolocation: the "you are here" dot (the web
/// `UiMapUserLocation`). [accuracy] is in metres, drawn as a soft halo of that radius.
@immutable
class UiMapUserLocation {
  const UiMapUserLocation(this.lat, this.lng, {this.accuracy});
  final double lat;
  final double lng;
  final double? accuracy;

  @override
  bool operator ==(Object other) => other is UiMapUserLocation && other.lat == lat && other.lng == lng && other.accuracy == accuracy;

  @override
  int get hashCode => Object.hash(lat, lng, accuracy);
}

/// The smallest and largest the accuracy halo is drawn, in px across.
const double uiMapAccuracyMin = 28, uiMapAccuracyMax = 240;

/// How many px across the accuracy halo is (the web `uiMapAccuracyPx`): twice [accuracy] metres at
/// [zoom] and [lat] (Web Mercator, 256 px per tile at zoom 0), rounded and clamped to 28..240. 0
/// without an accuracy.
double uiMapAccuracyPx(double? accuracy, double lat, double zoom) {
  if (accuracy == null || !(accuracy > 0)) return 0;
  final metresPerPx = 40075016.686 * math.cos(lat * math.pi / 180) / math.pow(2, zoom + 8);
  return (2 * accuracy / metresPerPx).roundToDouble().clamp(uiMapAccuracyMin, uiMapAccuracyMax);
}

/// The tile URL a map shows (the web `uiMapTileUrl`): the dark one on a dark theme when given.
String uiMapTileUrl(String tileUrl, String? tileUrlDark, bool dark) => dark && tileUrlDark != null && tileUrlDark.isNotEmpty ? tileUrlDark : tileUrl;

/// The shift, in px from the map's middle, of the middle of the part between [insets] (the web
/// `uiMapInsetShift`).
Offset uiMapInsetShift(EdgeInsetsDirectional insets, TextDirection direction) {
  final r = insets.resolve(direction);
  return Offset((r.left - r.right) / 2, (r.top - r.bottom) / 2);
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
/// - [pulse]: the "searching" rings around a point, geo-anchored (they move with the map), drawn
///   above the tiles and below markers and the pin. A still halo under reduced motion. Silent: the
///   page's own status text announces the search.
/// - [viewInsets]: for a full-screen map with a sheet or card floating over it. The map still draws
///   edge to edge, but [center], the pin's "centre", [onCenterChanged], the zoom buttons and the
///   attribution use the part between the insets. When the insets change, the map pans so the
///   point that was in the middle of the visible part stays in the middle of the new one.
/// - [fill]: square corners, for a full-screen map page.
/// - [tileUrlDark]: tiles drawn for dark themes, shown undimmed on a dark theme and swapped live
///   when the theme changes; without it the light tiles are dimmed. `{r}` in a URL is `@2x` on a
///   high-density screen and empty otherwise; [tileSize] / [zoomOffset] are for 512 px tiles (512,
///   -1). [tileHeaders] go with both the light and the dark tiles.
/// - [locateControl]: a round "Show my location" button at the bottom-end corner of the visible
///   part (it follows [viewInsets], so it floats just above a bottom sheet); it calls [onLocate].
///   [locating] shows a spinner (presses do nothing), [locateOff] a struck-through icon with the
///   tooltip "Location is off" (presses still call [onLocate], to ask again).
/// - [userLocation]: the "you are here" dot with a white ring and an accuracy halo sized in metres;
///   above the tiles and pulse, below the markers and the pin; read out as "Your location". Move the
///   map to it with [UiMapState.flyTo].
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
    this.pulse,
    this.viewInsets = EdgeInsetsDirectional.zero,
    this.fill = false,
    this.tileUrlDark,
    this.tileSize = 256,
    this.zoomOffset = 0,
    this.locateControl = false,
    this.locating = false,
    this.locateOff = false,
    this.onLocate,
    this.userLocation,
  });

  /// Tiles for dark themes, shown undimmed; null dims the light tiles instead.
  final String? tileUrlDark;

  /// The tiles' size in px: 512 for 512 px tiles (with [zoomOffset] -1).
  final int tileSize;

  /// Added to the zoom in tile URLs: -1 for 512 px tiles.
  final double zoomOffset;

  /// A "Show my location" button at the bottom-end of the visible part; it calls [onLocate].
  final bool locateControl;

  /// The app is finding the position: a spinner, and presses do nothing.
  final bool locating;

  /// Location is off or denied: the icon struck through, "Location is off". Still pressable.
  final bool locateOff;
  final VoidCallback? onLocate;

  /// The "you are here" dot, with an accuracy halo; null for none.
  final UiMapUserLocation? userLocation;

  /// The "searching" rings around a point; null or `active: false` for none.
  final UiMapPulse? pulse;

  /// Px covered by panels over each edge; centring and the controls use the part between them.
  final EdgeInsetsDirectional viewInsets;

  /// Square corners (the map fills whatever box it is given), for a full-screen map page.
  final bool fill;

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

class UiMapState extends State<UiMap> with SingleTickerProviderStateMixin {
  final MapController _controller = MapController();

  /// Pans the map when the insets change (the sheet moved to another snap).
  late final AnimationController _pan = AnimationController(vsync: this)..addListener(_onPan);
  Offset _panFrom = Offset.zero, _panTo = Offset.zero;
  Curve _panCurve = Curves.linear;

  /// The inset shift the view is laid out for.
  Offset _shift = Offset.zero;
  final GlobalKey _box = GlobalKey();

  /// The pin while a finger drags it.
  UiLatLng? _dragging;
  bool _ready = false;

  /// The map controller, to move the map from code.
  MapController get controller => _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The direction decides which side start/end are on.
    final next = uiMapInsetShift(widget.viewInsets, Directionality.of(context));
    if (next != _shift) _shiftTo(next, animate: false);
  }

  @override
  void didUpdateWidget(UiMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = uiMapInsetShift(widget.viewInsets, Directionality.of(context));
    if (next != _shift) _shiftTo(next, animate: uiFxMotion(context) == UiFxMotion.full);
    if (!_ready) return;
    if (oldWidget.center != widget.center || oldWidget.zoom != widget.zoom) {
      final c = _visibleCenter(_controller.camera);
      if ((c.latitude - widget.center.lat).abs() > 1e-9 || (c.longitude - widget.center.lng).abs() > 1e-9 || _controller.camera.zoom != widget.zoom) {
        _pan.stop();
        _controller.move(widget.center._ll, widget.zoom, offset: _shift);
      }
    }
  }

  @override
  void dispose() {
    _pan.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// The point in the middle of the part of the map between the insets.
  LatLng _visibleCenter(MapCamera c) => _shift == Offset.zero ? c.center : c.unprojectAtZoom(c.projectAtZoom(c.center) + _shift);

  /// Lays the view out for a new inset shift: the point in the middle of the old visible part pans
  /// to the middle of the new one (the map's own centre moves by the difference).
  void _shiftTo(Offset next, {required bool animate}) {
    final old = _shift;
    _shift = next;
    if (!_ready) return;
    final c = _controller.camera;
    final from = c.projectAtZoom(c.center);
    final to = from + (old - next);
    if (!animate) {
      _pan.stop();
      _controller.move(c.unprojectAtZoom(to), c.zoom);
      return;
    }
    final t = context.ui;
    _panFrom = from;
    _panTo = to;
    _panCurve = t.easeStandard;
    _pan
      ..duration = t.motionSlow
      ..forward(from: 0);
  }

  void _onPan() {
    final c = _controller.camera;
    final p = Offset.lerp(_panFrom, _panTo, _panCurve.transform(_pan.value))!;
    _controller.move(c.unprojectAtZoom(p), c.zoom);
  }

  void _onReady() {
    _ready = true;
    // Built centred on the middle of the whole map: centre the input in the visible part instead.
    if (_shift != Offset.zero) _controller.move(widget.center._ll, widget.zoom, offset: _shift);
  }

  /// Moves the map so [c] sits in the middle of the visible part (between the insets), at [zoom] or
  /// the current zoom. For "my location": call it with the position the app found.
  void flyTo(UiLatLng c, {double? zoom}) {
    if (!_ready) return;
    _pan.stop();
    _controller.move(c._ll, zoom ?? _controller.camera.zoom, offset: _shift);
    final v = _visibleCenter(_controller.camera);
    widget.onCenterChanged?.call(UiMapView(v.latitude, v.longitude, _controller.camera.zoom));
  }

  void _placeAtCentre() {
    final c = _visibleCenter(_controller.camera);
    widget.onPinChanged?.call(UiLatLng(c.latitude, c.longitude));
  }

  void _zoomBy(double d) {
    // Around the middle of the visible part, so what the person looks at stays put.
    final v = _visibleCenter(_controller.camera);
    _pan.stop();
    _controller.move(v, (_controller.camera.zoom + d).clamp(1, 19), offset: _shift);
    widget.onCenterChanged?.call(UiMapView(v.latitude, v.longitude, _controller.camera.zoom));
  }

  void _onEvent(MapEvent e) {
    if (e.source == MapEventSource.mapController) return;
    if (e is MapEventMoveEnd || e is MapEventFlingAnimationEnd || e is MapEventDoubleTapZoomEnd || e is MapEventScrollWheelZoom) {
      final c = _visibleCenter(e.camera);
      widget.onCenterChanged?.call(UiMapView(c.latitude, c.longitude, e.camera.zoom));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final dark = context.uiTheme.brightness == Brightness.dark;
    final motion = uiFxMotion(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final pin = _dragging ?? widget.pin;
    // One provider for the light and the dark tiles alike, so tileHeaders (a Referer for a key
    // restricted to a web origin, say) go with both.
    final tileProvider = widget.tileProvider ?? NetworkTileProvider(headers: {...?widget.tileHeaders});
    if (widget.tileHeaders != null) tileProvider.headers.addAll(widget.tileHeaders!);
    final tileUrl = uiMapTileUrl(widget.tileUrl, widget.tileUrlDark, dark);
    final darkTiles = dark && tileUrl != widget.tileUrl;
    final user = widget.userLocation;

    final map = FlutterMap(
      key: _box,
      mapController: _controller,
      options: MapOptions(
        initialCenter: widget.center._ll,
        initialZoom: widget.zoom,
        backgroundColor: t.surfaceSubtle,
        onMapReady: _onReady,
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
          urlTemplate: tileUrl,
          userAgentPackageName: widget.userAgentPackageName,
          tileProvider: tileProvider,
          tileDimension: widget.tileSize,
          zoomOffset: widget.zoomOffset,
          // `{r}`: '@2x' from the server on a high-density screen, '' otherwise.
          retinaMode: tileUrl.contains('{r}') && RetinaMode.isHighDensity(context),
          // Dark tiles are drawn for the dark; only the light ones are dimmed.
          tileBuilder: dark && !darkTiles ? _dim : null,
        ),
        // The pulse: geo-anchored like a marker, under the markers and pin, never hit or read out.
        if (widget.pulse case final p? when p.active)
          MarkerLayer(markers: [
            Marker(
              point: LatLng(p.lat, p.lng),
              width: uiMapPulseSize,
              height: uiMapPulseSize,
              child: IgnorePointer(child: ExcludeSemantics(child: UiMapPulseRings(tone: p.tone))),
            ),
          ]),
        // The "you are here" dot: above the pulse, below the markers and the pin.
        if (user != null) _UserLayer(location: user),
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
    // The credits are English ("© MapTiler © OpenStreetMap contributors"): set them LTR in their own
    // run so an RTL layout doesn't move the © signs; only the corner they sit in is mirrored.
    final attribution = GestureDetector(
      onTap: widget.onAttributionTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: t.space1, vertical: 2),
        color: t.surfaceRaised.withValues(alpha: 0.85),
        child: Text(widget.attribution, textDirection: TextDirection.ltr, style: context.uiText.caption.copyWith(fontSize: 11, color: t.textMuted)),
      ),
    );
    // On touch the locate button's hit area is padded to 48dp around its circle; pull the box out
    // by that padding so the circle stays where it was.
    final locateSlop = UiMapLocateButton.touchSlop(context);

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
          borderRadius: BorderRadius.circular(widget.fill ? 0 : context.uiTheme.radius(t.radius)),
          child: ColoredBox(
            color: t.surfaceSubtle,
            child: Stack(children: [
              // Leaflet and flutter_map lay out in screen terms; keep the map itself LTR.
              Positioned.fill(child: Directionality(textDirection: TextDirection.ltr, child: map)),
              // The controls sit inside the part the insets leave visible.
              AnimatedPositionedDirectional(
                duration: context.uiAnimate ? t.motionBase : Duration.zero,
                curve: t.easeStandard,
                top: t.space2 + widget.viewInsets.top,
                start: t.space2 + widget.viewInsets.start,
                child: zoom,
              ),
              AnimatedPositioned(
                duration: context.uiAnimate ? t.motionBase : Duration.zero,
                curve: t.easeStandard,
                bottom: widget.viewInsets.bottom,
                right: rtl ? null : widget.viewInsets.end,
                left: rtl ? widget.viewInsets.end : null,
                child: attribution,
              ),
              // The "my location" button: bottom-end of the visible part, above the attribution.
              if (widget.locateControl)
                AnimatedPositionedDirectional(
                  duration: context.uiAnimate ? t.motionBase : Duration.zero,
                  curve: t.easeStandard,
                  bottom: widget.viewInsets.bottom + t.space8 - locateSlop,
                  end: widget.viewInsets.end + t.space3 - locateSlop,
                  child: UiMapLocateButton(locating: widget.locating, off: widget.locateOff, onPressed: widget.onLocate),
                ),
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

/// The "my location" button (exported for tests): round, raised, 38px (44px on touch screens,
/// where its hit area is padded to [uiMinTouchTarget], 48dp, around the circle).
class UiMapLocateButton extends StatelessWidget {
  const UiMapLocateButton({super.key, this.locating = false, this.off = false, this.onPressed});
  final bool locating, off;
  final VoidCallback? onPressed;

  /// How far the padded hit area reaches past the circle on each side (0 off touch screens).
  static double touchSlop(BuildContext context) => uiTouchPlatform(context) ? math.max(0, (uiMinTouchTarget - context.ui.sizeTouch) / 2) : 0;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final strings = context.uiStrings;
    final dim = uiTouchPlatform(context) ? t.sizeTouch : t.sizeLg;
    return UiTooltip(
      message: off ? strings.mapLocationOff : '',
      position: UiTooltipPosition.left,
      child: UiInteractive(
        onTap: () {
          if (!locating) onPressed?.call();
        },
        semanticLabel: strings.mapLocate,
        excludeChildSemantics: true,
        builder: (context, s) => AnimatedContainer(
          duration: context.uiAnimate ? t.motionFast : Duration.zero,
          width: dim,
          height: dim,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: s.hovered || s.pressed ? t.surfaceHover : t.surfaceRaised,
            border: Border.all(color: t.border),
            boxShadow: s.focused ? [...t.shadow2, ...t.focusRing] : t.shadow2,
          ),
          child: Center(
            child: locating
                ? const UiSpinner(size: 18, decorative: true)
                : UiIcon(off ? HugeIcons.strokeRoundedGpsOff01 : HugeIcons.strokeRoundedGps01, size: 20, color: off ? t.textMuted : t.text),
          ),
        ),
      ),
    );
  }
}

/// The "you are here" layer: a geo-anchored marker whose halo follows the zoom.
class _UserLayer extends StatelessWidget {
  const _UserLayer({required this.location});
  final UiMapUserLocation location;

  @override
  Widget build(BuildContext context) {
    final halo = uiMapAccuracyPx(location.accuracy, location.lat, MapCamera.of(context).zoom);
    final box = math.max(halo, 16.0);
    return MarkerLayer(markers: [
      Marker(
        point: LatLng(location.lat, location.lng),
        width: box,
        height: box,
        child: IgnorePointer(
          child: Semantics(container: true, image: true, label: context.uiStrings.mapYourLocation, child: UiMapUserDot(halo: halo)),
        ),
      ),
    ]);
  }
}

/// The "you are here" dot (exported for tests and goldens): 16px in the location blue with a 3px
/// white ring and a shadow, over a soft halo [halo] px across (none at 0).
class UiMapUserDot extends StatelessWidget {
  const UiMapUserDot({super.key, this.halo = 0});
  final double halo;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
      if (halo > 0)
        Container(
          width: halo,
          height: halo,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.location.withValues(alpha: 0.16),
            border: Border.all(color: t.location.withValues(alpha: 0.40)),
          ),
        ),
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(shape: BoxShape.circle, color: t.location, border: Border.all(color: t.locationRing, width: 3), boxShadow: t.shadow2),
      ),
    ]);
  }
}

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

/// How wide the pulse is at its widest, in px.
const double uiMapPulseSize = 120;

/// The pulse rings (exported for tests and goldens): three staggered rings, 2.4s, growing from 15%
/// to 100% of [uiMapPulseSize] on an ease-out while fading in over the first 12% and out after; one
/// still 72px halo when animations are off ([BuildContext.uiAnimate] false, e.g. reduced motion).
class UiMapPulseRings extends StatefulWidget {
  const UiMapPulseRings({super.key, this.tone = UiStatus.primary});
  final UiStatus tone;

  /// One loop.
  static const Duration period = Duration(milliseconds: 2400);

  @override
  State<UiMapPulseRings> createState() => _UiMapPulseRingsState();
}

class _UiMapPulseRingsState extends State<UiMapPulseRings> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: UiMapPulseRings.period);

  /// Whether the loop is running (for tests: stopped under reduced motion).
  bool get running => _loop.isAnimating;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Runs only while it animates: under reduced motion the controller stays stopped.
    if (context.uiAnimate) {
      if (!_loop.isAnimating) _loop.repeat();
    } else {
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final color = widget.tone.color(t);
    final still = !context.uiAnimate;
    return SizedBox.square(
      dimension: uiMapPulseSize,
      child: CustomPaint(painter: _PulsePainter(color: color, loop: still ? null : _loop, elapsed: () => _loop.lastElapsedDuration ?? Duration.zero)),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.color, this.loop, this.elapsed}) : super(repaint: loop);
  final Color color;

  /// Time since the loop started: ring i starts i/3 of a loop late, as the web's animation-delay.
  final Duration Function()? elapsed;

  /// Null: the still halo.
  final Animation<double>? loop;

  static const Cubic _grow = Cubic(0.2, 0.6, 0.35, 1);

  void _ring(Canvas canvas, Offset c, double diameter, double opacity) {
    if (opacity <= 0) return;
    final r = diameter / 2;
    canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: 0.20 * opacity));
    // The web's 2px border sits inside the ring's box: its centre line is 1px in.
    canvas.drawCircle(c, math.max(0, r - 1), Paint()
      ..color = color.withValues(alpha: 0.75 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final l = loop;
    if (l == null) {
      _ring(canvas, c, 72, 1);
      return;
    }
    final since = elapsed?.call().inMicroseconds ?? UiMapPulseRings.period.inMicroseconds;
    for (var i = 0; i < 3; i++) {
      if (since < UiMapPulseRings.period.inMicroseconds * i / 3) continue;
      final p = (l.value - i / 3) % 1.0;
      final opacity = p < 0.12 ? p / 0.12 : (1 - p) / 0.88;
      _ring(canvas, c, uiMapPulseSize * (0.15 + 0.85 * _grow.transform(p)), opacity);
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.color != color || old.loop != loop;
}
