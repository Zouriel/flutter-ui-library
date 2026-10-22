import 'dart:convert' show base64Decode;
import 'dart:math' as math;

import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../core/icon.dart';
import '../core/interactive.dart';
import '../feedback/spinner.dart';
import '../overlay/tooltip.dart';
import '../core/types.dart';
import '../fx/motion.dart';
import '../theme/theme.dart';
import 'area.dart';

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

/// A route line's colour (the web `UiMapRouteTone`): the theme's `mapRoute*` token.
enum UiMapRouteTone { primary, muted, success, warning, danger }

/// A route drawn on the map (the web `UiMapRoute`): a line in its [tone] over a casing, under the
/// dots, markers and the pin. [semanticLabel] is its one accessible name ("Route, 1.2 km"), from
/// the app; without it the route is not read out.
@immutable
class UiMapRoute {
  const UiMapRoute({required this.id, required this.points, this.tone = UiMapRouteTone.primary, this.semanticLabel});
  final String id;
  final List<UiLatLng> points;
  final UiMapRouteTone tone;
  final String? semanticLabel;
}

/// An app's own button on the map (0.42.1, the web `UiMapControl`), drawn in the same stack and
/// style as the "Show my location" button: a round raised button at the bottom-end of the visible
/// part, above the locate button, 48dp targets on touch. [onPressed] null shows it disabled.
/// For "Show both": `UiMapControl(id: 'fit', icon: HugeIcons.strokeRoundedCenterFocus,
/// semanticLabel: 'Show both', onPressed: () => mapKey.currentState!.fitPoints([me, patient]))`.
@immutable
class UiMapControl {
  const UiMapControl({required this.id, required this.icon, required this.semanticLabel, this.onPressed, this.tooltip});

  /// Identifies the control (its key: keep it stable).
  final String id;
  final UiIconData icon;

  /// Its accessible name, read out for the icon.
  final String semanticLabel;
  final VoidCallback? onPressed;

  /// Shown beside it on hover and long press; null for none.
  final String? tooltip;
}

/// Which side of its dot a marker label sits on (the web `UiMapLabelSide`), on screen.
enum UiMapLabelSide { left, right }

/// Which marker labels a map shows (0.43.0, the web `markerLabels`): every one ([all], the default),
/// only the selected marker's ([selected]) or none ([none]). Hidden labels still name their markers
/// for screen readers.
enum UiMapMarkerLabels { all, selected, none }

/// How much bigger the selected marker's dot is than the others' 16px (0.43.0): 22px.
const double uiMapSelectedDot = 22;

/// The gap from a marker's point to its label (the dot's 8px radius and 4px), and the room the
/// label keeps from the map's edge.
const double uiMapLabelGap = 12, uiMapLabelEdge = 8;

/// Which side of its dot a [labelWidth] px label goes for a marker [x] px from the map's left edge
/// on a [mapWidth] map (0.42.1, the web `uiMapLabelSide`): the inline end (the right, the left in
/// RTL) unless it would run past the map's edge there (keeping [uiMapLabelEdge]); then the other
/// side; when neither fits, the side with more room.
UiMapLabelSide uiMapLabelSide(double x, double labelWidth, double mapWidth, {bool rtl = false}) {
  bool fits(UiMapLabelSide s) => s == UiMapLabelSide.right ? x + uiMapLabelGap + labelWidth <= mapWidth - uiMapLabelEdge : x - uiMapLabelGap - labelWidth >= uiMapLabelEdge;
  final first = rtl ? UiMapLabelSide.left : UiMapLabelSide.right;
  final other = rtl ? UiMapLabelSide.right : UiMapLabelSide.left;
  if (fits(first)) return first;
  if (fits(other)) return other;
  return mapWidth - x >= x ? UiMapLabelSide.right : UiMapLabelSide.left;
}

/// The theme colour of a route [tone].
Color uiMapRouteColor(UiTokens t, UiMapRouteTone tone) => switch (tone) {
      UiMapRouteTone.primary => t.mapRoutePrimary,
      UiMapRouteTone.muted => t.mapRouteMuted,
      UiMapRouteTone.success => t.mapRouteSuccess,
      UiMapRouteTone.warning => t.mapRouteWarning,
      UiMapRouteTone.danger => t.mapRouteDanger,
    };

/// The route line's width and its casing's, in px, at [zoom] (the web `uiMapRouteWidth`): 5 over a
/// 9px casing (2px each side) from zoom 14 in, thinning to 60% at zoom 10 and out.
({double line, double casing}) uiMapRouteWidth(double zoom) {
  final k = (0.6 + 0.1 * (zoom - 10)).clamp(0.6, 1.0);
  return (line: 5 * k, casing: 9 * k);
}

/// The closest [UiMapState.fitPoints] zooms by default, and the zoom it shows a single point at.
const double uiMapFitMaxZoom = 17;

/// The room [UiMapState.fitPoints] leaves around the points by default, px per side.
const double uiMapFitPadding = 24;

const double _maxLat = 85.0511287798;
double _unitX(double lng) => (lng + 180) / 360;
double _unitY(double lat) {
  final s = math.sin(lat.clamp(-_maxLat, _maxLat) * math.pi / 180);
  return 0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi);
}

double _unitLat(double y) {
  final n = math.pi * (1 - 2 * y);
  return math.atan((math.exp(n) - math.exp(-n)) / 2) * 180 / math.pi;
}

/// Where a map of [size] looks so every point fits inside the part left free by [area] (the insets
/// plus padding, px per physical side; the web `uiMapFitView`): the map's own centre and a whole
/// zoom level (Web Mercator, 256 px tiles at zoom 0), at most [maxZoom]. All the points in one place
/// (or one point): [maxZoom], the point in the middle of that part. Null without points.
UiMapView? uiMapFitView(List<UiLatLng> points, Size size, EdgeInsets area, {double maxZoom = uiMapFitMaxZoom, double minZoom = 1}) {
  if (points.isEmpty) return null;
  final xs = points.map((p) => _unitX(p.lng)).toList();
  final ys = points.map((p) => _unitY(p.lat)).toList();
  final x0 = xs.reduce(math.min), x1 = xs.reduce(math.max), y0 = ys.reduce(math.min), y1 = ys.reduce(math.max);
  final w = math.max(1.0, size.width - area.left - area.right);
  final h = math.max(1.0, size.height - area.top - area.bottom);
  final dx = (x1 - x0) * 256, dy = (y1 - y0) * 256;
  var zoom = maxZoom;
  if (dx > 1e-12 || dy > 1e-12) {
    final fit = math.log(math.min(dx > 1e-12 ? w / dx : double.infinity, dy > 1e-12 ? h / dy : double.infinity)) / math.ln2;
    zoom = math.min(maxZoom, (fit + 1e-9).floorToDouble());
  }
  zoom = math.max(minZoom, zoom);
  final scale = 256 * math.pow(2, zoom);
  // The middle of the points goes to the middle of the free part: the map's centre is that far off it.
  final cx = (x0 + x1) / 2 - (area.left - area.right) / 2 / scale;
  final cy = (y0 + y1) / 2 - (area.top - area.bottom) / 2 / scale;
  return UiMapView(_unitLat(cy), cx * 360 - 180, zoom);
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
/// - [onMapTap] (0.43.1): the point tapped on the map background (the user dot counts as
///   background). Markers, the pin, controls and attribution do not call it; neither do a drag, double-tap zoom or [preview]. In
///   [pinMode], a background tap calls [onPinChanged] and then [onMapTap].
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
/// - [routes] (0.42.0): lines along the road (from OSRM, say) in a tone over a casing, round caps and
///   joins, 5 over 9px (thinner when zoomed out), above the tiles and below the pulse, dot, markers
///   and pin. A new list redraws the lines on the same map; an empty one removes them. Each route's
///   [UiMapRoute.semanticLabel] is its one name for screen readers ("Route, 1.2 km").
/// - [UiMapState.fitPoints] (0.42.0): shows every point inside the visible part (between
///   [viewInsets]) plus padding, at a whole zoom up to maxZoom (17); one point is centred there at
///   maxZoom. Animated unless reduced motion.
/// - Marker labels size to their text, up to 320px or the map's width less 32, and wrap to a second
///   line before the ellipsis. They sit at the inline end of the dot (right; left in RTL) and flip
///   to the other side when they would run off the map there (0.42.1, [uiMapLabelSide]).
/// - [controls] (0.42.1): the app's own round buttons ([UiMapControl]) in the locate button's
///   stack and style, above it at the bottom-end of the visible part, following [viewInsets].
/// - [preview] (0.43.0): a still picture of the map that is one button. No pan, zoom, keys or
///   controls; markers drawn but not focusable; a vertical drag or the wheel over it scrolls the page
///   around it. A tap, Enter or Space calls [onPreviewPressed]; it is read out as [previewLabel]
///   ("Open map", from [UiStrings.mapOpen]) and shows a round expand badge at the top-end corner.
///   [center], [zoom] and [UiMapState.fitPoints] still place it (without animating). Turning it off
///   gives the full map back.
/// - [selectedMarkerId] (0.43.0): that marker is drawn bigger (a 22px dot) with a white ring and a
///   halo in its tone, above the others, its label shown, and read out as selected.
/// - [markerLabels] (0.43.0): [UiMapMarkerLabels.all] (the default), [UiMapMarkerLabels.selected]
///   (only the selected marker's label) or [UiMapMarkerLabels.none]. Hidden labels still name the
///   markers for screen readers.
/// - [area] (0.44.0): a search area ([UiMapArea]), a circle drawn in true metres (it scales with the
///   zoom) over the tiles and under the routes, pulse, dot, markers and pin; drags pan the map
///   through it. When editable (and not a [preview]) a round handle on its inline-end edge (east;
///   west in RTL), a 48dp target with the radius chip ("20 km", [uiMapFormatRadius]) above it,
///   changes the radius between its min and max: [onAreaChanging] each time the (rounded) radius
///   changes while dragging, [onAreaChanged] on every release. The chosen radius stays drawn until
///   the app passes a new [area]. The map doesn't pan while the handle is dragged. For keyboards and screen readers
///   the handle is a slider named [areaLabel] ([UiStrings.mapSearchArea]): Up and the outward arrow
///   step 10% out, Down and the inward arrow 10% in, Home / End the min / max, each step that
///   changes the radius calling both callbacks. [UiMapState.fitArea] shows the whole circle in the visible part.
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
    this.onMapTap,
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
    this.routes = const [],
    this.controls = const [],
    this.preview = false,
    this.onPreviewPressed,
    this.previewLabel,
    this.selectedMarkerId,
    this.markerLabels = UiMapMarkerLabels.all,
    this.area,
    this.onAreaChanging,
    this.onAreaChanged,
    this.areaLabel,
  });

  /// A search area (0.44.0): a circle in metres, with a radius handle when editable.
  final UiMapArea? area;

  /// The radius in metres while the handle is dragged (and on each keyboard step).
  final ValueChanged<double>? onAreaChanging;

  /// The radius in metres when the handle is let go (and on each keyboard step).
  final ValueChanged<double>? onAreaChanged;

  /// The radius handle's accessible name; null: [UiStrings.mapSearchArea] ("Search area").
  final String? areaLabel;

  /// A still picture of the map that is one button (0.43.0): no gestures, keys or controls, and
  /// page scrolling passes through it. A tap, Enter or Space calls [onPreviewPressed].
  final bool preview;
  final VoidCallback? onPreviewPressed;

  /// The preview button's accessible name; null: [UiStrings.mapOpen] ("Open map").
  final String? previewLabel;

  /// The selected marker (0.43.0): drawn bigger, ringed and haloed, on top, its label shown.
  final String? selectedMarkerId;

  /// Which marker labels show (0.43.0); hidden ones still name their markers.
  final UiMapMarkerLabels markerLabels;

  /// The app's own buttons (0.42.1), above the locate button at the bottom-end of the visible part.
  final List<UiMapControl> controls;

  /// Route lines (0.42.0), drawn under the dot, markers and pin; an empty list removes them.
  final List<UiMapRoute> routes;

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

  /// A map-background tap (0.43.1); in [pinMode], called after [onPinChanged].
  final ValueChanged<UiLatLng>? onMapTap;

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

class UiMapState extends State<UiMap> with TickerProviderStateMixin {
  final MapController _controller = MapController();

  /// Pans the map when the insets change (the sheet moved to another snap): [_panPoint] stays in
  /// the middle of the visible part while the shift eases from [_panFrom] to [_panTo]. Kept as a
  /// point, not px, so a zoom change while it runs can't send it to another scale (0.42.1).
  late final AnimationController _pan = AnimationController(vsync: this)..addListener(_onPan);
  Offset _panFrom = Offset.zero, _panTo = Offset.zero;
  LatLng _panPoint = const LatLng(0, 0);
  Curve _panCurve = Curves.linear;

  /// The last [fitPoints], while it owns the camera (0.42.1): an inset change works it out again
  /// for the new insets. Let go when anything else moves the map (a gesture, [flyTo], the zoom
  /// buttons, a new [UiMap.center] or [UiMap.zoom]).
  ({List<UiLatLng> points, EdgeInsets? padding, double? maxZoom, bool animate})? _fit;

  /// The inset shift the view is laid out for.
  Offset _shift = Offset.zero;
  final GlobalKey _box = GlobalKey();

  /// fitPoints' move: from one camera to another.
  late final AnimationController _fly = AnimationController(vsync: this)..addListener(_onFly);
  LatLng _flyFrom = const LatLng(0, 0), _flyTo = const LatLng(0, 0);
  double _flyZoomFrom = 0, _flyZoomTo = 0;
  Curve _flyCurve = Curves.linear;

  /// The pin while a finger drags it.
  UiLatLng? _dragging;

  /// The area's radius while its handle is dragged.
  double? _areaDrag;

  /// The radius last chosen with the handle or keys, kept until the app passes a new [UiMap.area].
  double? _areaKept;
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
    if (oldWidget.area != widget.area) _areaKept = null;
    if (oldWidget.center != widget.center || oldWidget.zoom != widget.zoom) {
      final c = _visibleCenter(_controller.camera);
      if ((c.latitude - widget.center.lat).abs() > 1e-9 || (c.longitude - widget.center.lng).abs() > 1e-9 || _controller.camera.zoom != widget.zoom) {
        _release();
        _controller.move(widget.center._ll, widget.zoom, offset: _shift);
      }
    }
  }

  @override
  void dispose() {
    _fly.dispose();
    _pan.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// The point in the middle of the part of the map between the insets.
  LatLng _visibleCenter(MapCamera c) => _shift == Offset.zero ? c.center : c.unprojectAtZoom(c.projectAtZoom(c.center) + _shift);

  /// Lays the view out for a new inset shift: the point in the middle of the old visible part pans
  /// to the middle of the new one (the map's own centre moves by the difference). While a fit owns
  /// the camera, the fit is worked out again for the new insets instead.
  void _shiftTo(Offset next, {required bool animate}) {
    final old = _shift;
    _shift = next;
    if (!_ready) return;
    if (_fit != null) {
      _pan.stop();
      _applyFit();
      return;
    }
    final c = _controller.camera;
    // A pan already on its way keeps its point, from where it has got to.
    final running = _pan.isAnimating;
    final from = running ? Offset.lerp(_panFrom, _panTo, _panCurve.transform(_pan.value))! : old;
    final point = running ? _panPoint : (old == Offset.zero ? c.center : c.unprojectAtZoom(c.projectAtZoom(c.center) + old));
    _pan.stop();
    if (!animate) {
      _controller.move(point, c.zoom, offset: next);
      return;
    }
    final t = context.ui;
    _panPoint = point;
    _panFrom = from;
    _panTo = next;
    _panCurve = t.easeStandard;
    _pan
      ..duration = t.motionSlow
      ..forward(from: 0);
  }

  void _onPan() {
    final s = Offset.lerp(_panFrom, _panTo, _panCurve.transform(_pan.value))!;
    _controller.move(_panPoint, _controller.camera.zoom, offset: s);
  }

  /// Something other than a fit moves the map: the fit lets go, and any move in flight stops.
  void _release() {
    _fit = null;
    _fly.stop();
    _pan.stop();
  }

  void _onReady() {
    _ready = true;
    // Built centred on the middle of the whole map: centre the input in the visible part instead.
    if (_shift != Offset.zero) _controller.move(widget.center._ll, widget.zoom, offset: _shift);
    // A fit asked for before the map was ready (fitPoints / fitArea on opening) runs now, without animating.
    final f = _fit;
    if (f != null) {
      _fit = (points: f.points, padding: f.padding, maxZoom: f.maxZoom, animate: false);
      _applyFit();
    }
  }

  /// Moves the map so [c] sits in the middle of the visible part (between the insets), at [zoom] or
  /// the current zoom. For "my location": call it with the position the app found.
  void flyTo(UiLatLng c, {double? zoom}) {
    if (!_ready) return;
    _release();
    _controller.move(c._ll, zoom ?? _controller.camera.zoom, offset: _shift);
    final v = _visibleCenter(_controller.camera);
    widget.onCenterChanged?.call(UiMapView(v.latitude, v.longitude, _controller.camera.zoom));
  }

  /// Shows every point inside the visible part (between [UiMap.viewInsets]) with [padding] to spare
  /// (24 on each side by default), at a whole zoom up to [maxZoom] (17); a single point is centred
  /// there at [maxZoom]. Animated unless [animate] is false or animations are off (reduced motion).
  /// For "show me and the patient": the nurse's position, the patient's and the route's points.
  ///
  /// The fit then owns the camera (0.42.1): when [UiMap.viewInsets] change while it animates or
  /// after it (a sheet growing as the route appears), it is worked out again for the new insets, so
  /// the points stay inside the visible part. It lets go when anything else moves the map: a
  /// gesture, [flyTo], the zoom buttons, a new [UiMap.center] or [UiMap.zoom].
  void fitPoints(List<UiLatLng> points, {EdgeInsets? padding, double? maxZoom, bool animate = true}) {
    if (points.isEmpty) return;
    _fit = (points: List.unmodifiable(points), padding: padding, maxZoom: maxZoom, animate: animate);
    // Asked before the map is ready (straight after it is built): held, and run once it is (0.44.2).
    if (!_ready) return;
    _pan.stop();
    _fly.stop();
    _applyFit();
  }

  /// Moves to the held fit for the current insets. A fit on its way is retargeted (it keeps its
  /// progress), so a sheet growing frame by frame doesn't restart it every frame.
  void _applyFit() {
    final f = _fit;
    if (f == null) return;
    final box = _box.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final insets = widget.viewInsets.resolve(Directionality.of(context));
    final pad = f.padding ?? const EdgeInsets.all(uiMapFitPadding);
    final v = uiMapFitView(f.points, box.size, insets + pad, maxZoom: math.min(f.maxZoom ?? uiMapFitMaxZoom, 19));
    if (v == null) return;
    final cam = _controller.camera;
    final to = LatLng(v.lat, v.lng);
    if (!f.animate || widget.preview || uiFxMotion(context) != UiFxMotion.full) {
      _fly.stop();
      _controller.move(to, v.zoom);
      _reportView();
      return;
    }
    if (_fly.isAnimating) {
      _flyTo = to;
      _flyZoomTo = v.zoom;
      return;
    }
    final t = context.ui;
    _flyFrom = cam.center;
    _flyTo = to;
    _flyZoomFrom = cam.zoom;
    _flyZoomTo = v.zoom;
    _flyCurve = t.easeStandard;
    _fly
      ..duration = t.motionSlow
      ..forward(from: 0).whenCompleteOrCancel(() {
        if (mounted && _fly.isCompleted) _reportView();
      });
  }

  /// Shows the whole search area's circle inside the visible part (between [UiMap.viewInsets]) with
  /// [padding] to spare (0.44.0), as [fitPoints] does for its north, south, east and west points.
  void fitArea({EdgeInsets? padding, double? maxZoom, bool animate = true}) {
    final a = widget.area;
    if (a == null) return;
    final r = _areaKept ?? a.radiusMeters;
    fitPoints(uiMapAreaBounds(UiMapArea(center: a.center, radiusMeters: r)), padding: padding, maxZoom: maxZoom ?? 19, animate: animate);
  }

  /// The area handle follows the finger: the radius is its distance from the centre, rounded and
  /// kept to the area's min and max.
  void _onAreaDrag(Offset global) {
    final a = widget.area;
    final box = _box.currentContext?.findRenderObject() as RenderBox?;
    if (a == null || box == null) return;
    final cam = _controller.camera;
    final c = cam.latLngToScreenOffset(a.center._ll);
    final px = (box.globalToLocal(global) - c).distance;
    final r = uiMapNiceRadius(px * uiMapMetersPerPx(a.center.lat, cam.zoom)).clamp(a.minMeters, a.maxMeters).toDouble();
    if (r == (_areaDrag ?? _areaKept ?? a.radiusMeters)) return;
    setState(() => _areaDrag = r);
    widget.onAreaChanging?.call(r);
  }

  /// Let go: the radius is kept and reported, changed or not.
  void _onAreaDragEnd() {
    final a = widget.area;
    if (a == null) return;
    final r = _areaDrag ?? _areaKept ?? a.radiusMeters;
    if (mounted) {
      setState(() {
        _areaDrag = null;
        _areaKept = r;
      });
    }
    widget.onAreaChanged?.call(r);
  }

  void _onAreaStep(double r) {
    setState(() => _areaKept = r);
    widget.onAreaChanging?.call(r);
    widget.onAreaChanged?.call(r);
  }

  void _onFly() {
    final k = _flyCurve.transform(_fly.value);
    _controller.move(
      LatLng(_flyFrom.latitude + (_flyTo.latitude - _flyFrom.latitude) * k, _flyFrom.longitude + (_flyTo.longitude - _flyFrom.longitude) * k),
      _flyZoomFrom + (_flyZoomTo - _flyZoomFrom) * k,
    );
  }

  void _reportView() {
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
    _release();
    _controller.move(v, (_controller.camera.zoom + d).clamp(1, 19), offset: _shift);
    widget.onCenterChanged?.call(UiMapView(v.latitude, v.longitude, _controller.camera.zoom));
  }

  void _onEvent(MapEvent e) {
    if (e.source == MapEventSource.mapController) return;
    // The person moves the map (drag, pinch, fling, double tap, wheel, keys): it is theirs now.
    if ((e is MapEventWithMove && e is! MapEventNonRotatedSizeChange) || e is MapEventMoveStart || e is MapEventDoubleTapZoomStart || e is MapEventRotateStart) {
      if (_fit != null || _fly.isAnimating || _pan.isAnimating) _release();
    }
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
    final selected = widget.selectedMarkerId;
    final preview = widget.preview;
    final area = widget.area;
    final areaRadius = _areaDrag ?? _areaKept ?? area?.radiusMeters;

    Widget mapFor(double labelMax) => FlutterMap(
      key: _box,
      mapController: _controller,
      options: MapOptions(
        initialCenter: widget.center._ll,
        initialZoom: widget.zoom,
        backgroundColor: t.surfaceSubtle,
        onMapReady: _onReady,
        onMapEvent: _onEvent,
        onTap: (_, ll) {
          if (widget.preview) return;
          final point = UiLatLng(ll.latitude, ll.longitude);
          if (widget.pinMode) widget.onPinChanged?.call(point);
          widget.onMapTap?.call(point);
        },
        // A preview takes no gestures or keys at all: it is a picture under one button.
        interactionOptions: widget.preview
            ? const InteractionOptions(flags: InteractiveFlag.none, keyboardOptions: KeyboardOptions.disabled())
            : InteractionOptions(
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
        // The search area: over the tiles, under everything else, never hit.
        if (area != null) UiMapAreaLayer(area: area, radius: areaRadius!),
        // Routes: over the tiles, under the pulse, the dot, the markers and the pin.
        if (widget.routes.isNotEmpty) _RouteLayer(routes: widget.routes),
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
          // The selected marker last, so it is drawn on top of the others.
          for (final m in [...widget.markers.where((m) => m.id != selected), ...widget.markers.where((m) => m.id == selected)])
            Marker(
              key: ValueKey('ui-map-marker-${m.id}'),
              point: LatLng(m.lat, m.lng),
              // Centred on the point, room for the label on either side of the dot's 48dp target.
              width: _MarkerChip.boxWidth(labelMax),
              height: 48,
              child: _MarkerChip(
                marker: m,
                labelMax: labelMax,
                rtl: rtl,
                selected: selected == null ? null : m.id == selected,
                showLabel: switch (widget.markerLabels) {
                  UiMapMarkerLabels.all => true,
                  UiMapMarkerLabels.selected => m.id == selected,
                  UiMapMarkerLabels.none => false,
                },
                onTap: widget.onMarkerSelected == null ? null : () => widget.onMarkerSelected!(m),
              ),
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
        // The radius handle: on top of everything, so it can always be grabbed.
        if (area != null && area.editable && !preview)
          UiMapAreaHandleLayer(
            area: area,
            radius: areaRadius!,
            rtl: rtl,
            label: widget.areaLabel ?? context.uiStrings.mapSearchArea,
            onDragStart: _release,
            onDrag: _onAreaDrag,
            onDragEnd: _onAreaDragEnd,
            onStep: _onAreaStep,
          ),
      ],
    );

    // The zoom buttons: the locate button's raised surface (0.42.0; outline buttons were see-through
    // and washed out over a light street map). On touch their 48dp targets touch, so the visible
    // squares keep the web's 4px gap.
    final slop = UiMapLocateButton.touchSlop(context);
    final zoom = Column(mainAxisSize: MainAxisSize.min, spacing: math.max(0, t.space1 - 2 * slop), children: [
      UiMapZoomButton(icon: HugeIcons.strokeRoundedAdd01, label: context.uiStrings.zoomIn, onPressed: () => _zoomBy(1)),
      UiMapZoomButton(icon: HugeIcons.strokeRoundedMinusSign, label: context.uiStrings.zoomOut, onPressed: () => _zoomBy(-1)),
    ]);
    // The credits are English ("© MapTiler © OpenStreetMap contributors"): set them LTR in their own
    // run so an RTL layout doesn't move the © signs; only the corner they sit in is mirrored.
    final attribution = GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: widget.onAttributionTap == null,
      // Even plain credit text is foreground, not the map background.
      onTap: widget.onAttributionTap ?? () {},
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
              // Leaflet and flutter_map lay out in screen terms; keep the map itself LTR. The marker
              // labels' widest: 320, or the map's width less 32 when that is narrower.
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final map = Directionality(textDirection: TextDirection.ltr, child: mapFor(math.max(80.0, math.min(320.0, box.maxWidth - 32))));
                    // A preview: the map takes no focus or semantics (the button over it does, and
                    // takes every pointer before the map could: only taps, so a drag or the wheel
                    // reaches the scrollable around it).
                    return ExcludeFocus(excluding: preview, child: ExcludeSemantics(excluding: preview, child: map));
                  },
                ),
              ),
              // The controls sit inside the part the insets leave visible (none on a preview).
              if (!preview)
                AnimatedPositionedDirectional(
                  duration: context.uiAnimate ? t.motionBase : Duration.zero,
                  curve: t.easeStandard,
                  top: t.space2 + widget.viewInsets.top - slop,
                  start: t.space2 + widget.viewInsets.start - slop,
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
              if (widget.locateControl && !preview)
                AnimatedPositionedDirectional(
                  duration: context.uiAnimate ? t.motionBase : Duration.zero,
                  curve: t.easeStandard,
                  bottom: widget.viewInsets.bottom + t.space8 - locateSlop,
                  end: widget.viewInsets.end + t.space3 - locateSlop,
                  child: UiMapLocateButton(locating: widget.locating, off: widget.locateOff, onPressed: widget.onLocate),
                ),
              // The app's own buttons: the same stack, above the locate button (where it would be
              // without one), 8px apart.
              if (widget.controls.isNotEmpty && !preview)
                AnimatedPositionedDirectional(
                  duration: context.uiAnimate ? t.motionBase : Duration.zero,
                  curve: t.easeStandard,
                  bottom: widget.viewInsets.bottom + t.space8 - locateSlop + (widget.locateControl ? (uiTouchPlatform(context) ? t.sizeTouch : t.sizeLg) + t.space2 : 0),
                  end: widget.viewInsets.end + t.space3 - locateSlop,
                  child: Column(mainAxisSize: MainAxisSize.min, spacing: math.max(0, t.space2 - 2 * locateSlop), children: [
                    for (final c in widget.controls) UiMapControlButton(key: ValueKey('ui-map-control-${c.id}'), control: c),
                  ]),
                ),
              // A preview: the whole map is one button, over everything: the credits show through
              // (the licence) but, like the markers, take no taps of their own.
              if (preview)
                Positioned.fill(
                  child: UiMapPreviewButton(
                    label: widget.previewLabel ?? context.uiStrings.mapOpen,
                    onPressed: widget.onPreviewPressed,
                    radius: widget.fill ? 0 : context.uiTheme.radius(t.radius),
                  ),
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
          decoration: uiMapControlDecoration(context, s),
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

/// An app's own map button (0.42.1, exported for tests): the locate button's round raised
/// surface, border and shadow, 38px (44px on touch, its hit area padded to 48dp), its tooltip
/// towards the middle of the map.
class UiMapControlButton extends StatelessWidget {
  const UiMapControlButton({super.key, required this.control});
  final UiMapControl control;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final dim = uiTouchPlatform(context) ? t.sizeTouch : t.sizeLg;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final enabled = control.onPressed != null;
    return UiTooltip(
      message: control.tooltip ?? '',
      position: rtl ? UiTooltipPosition.right : UiTooltipPosition.left,
      child: UiInteractive(
        onTap: control.onPressed,
        semanticLabel: control.semanticLabel,
        excludeChildSemantics: true,
        builder: (context, s) => AnimatedContainer(
          duration: context.uiAnimate ? t.motionFast : Duration.zero,
          width: dim,
          height: dim,
          decoration: uiMapControlDecoration(context, s),
          child: Center(child: UiIcon(control.icon, size: 20, color: enabled ? t.text : t.textMuted)),
        ),
      ),
    );
  }
}

/// The button a preview map is (0.43.0, exported for tests): the whole map, read out as [label],
/// a tap, Enter or Space calls [onPressed]. A subtle tint while pressed, the focus ring inside its
/// edge for keyboard focus, a click cursor, and the round expand badge at the top-end corner. Only
/// a tap is claimed: a drag over it goes to the scrollable around the map.
class UiMapPreviewButton extends StatelessWidget {
  const UiMapPreviewButton({super.key, required this.label, this.onPressed, this.radius = 0});
  final String label;
  final VoidCallback? onPressed;

  /// The map's corner radius, for the focus ring.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onPressed ?? () {},
      semanticLabel: label,
      excludeChildSemantics: true,
      padTouchTarget: false,
      pressScale: false,
      builder: (context, s) => Stack(fit: StackFit.expand, children: [
        // Pressed: the map darkens a little (the web's 8% text-colour wash).
        AnimatedContainer(
          duration: context.uiAnimate ? t.motionFast : Duration.zero,
          color: s.pressed ? t.text.withValues(alpha: 0.08) : t.text.withValues(alpha: 0),
        ),
        // Keyboard focus: the ring inside the edge (2px of the page colour, then 2px of the ring).
        if (s.focused)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: t.bg, width: 2), borderRadius: BorderRadius.circular(radius)),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: t.borderFocus, width: 2), borderRadius: BorderRadius.circular(math.max(0, radius - 2)))),
              ),
            ),
          ),
        PositionedDirectional(top: t.space2, end: t.space2, child: const UiMapPreviewBadge()),
      ]),
    );
  }
}

/// The preview's expand badge (0.43.0, exported for tests): a small round button-look (30px, the
/// map controls' raised surface, border and shadow) with the expand icon, at the top-end corner.
/// Not a control of its own: the whole preview is the button.
class UiMapPreviewBadge extends StatelessWidget {
  const UiMapPreviewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Container(
      width: t.sizeMd,
      height: t.sizeMd,
      decoration: uiMapControlDecoration(context, const UiStates()),
      child: Center(child: UiIcon(HugeIcons.strokeRoundedArrowExpand01, size: 16, color: t.text)),
    );
  }
}

/// A map zoom button (exported for tests): the locate button's raised surface, border and shadow
/// in a rounded square, 38px (44px on touch screens, where its hit area is padded to 48dp).
class UiMapZoomButton extends StatelessWidget {
  const UiMapZoomButton({super.key, required this.icon, required this.label, this.onPressed});
  final UiIconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final dim = uiTouchPlatform(context) ? t.sizeTouch : t.sizeLg;
    return UiInteractive(
      onTap: onPressed,
      semanticLabel: label,
      excludeChildSemantics: true,
      builder: (context, s) => AnimatedContainer(
        duration: context.uiAnimate ? t.motionFast : Duration.zero,
        width: dim,
        height: dim,
        decoration: uiMapControlDecoration(context, s, shape: BoxShape.rectangle),
        child: Center(child: UiIcon(icon, size: 20, color: t.text)),
      ),
    );
  }
}

/// The surface every map control is drawn on (the locate and zoom buttons): opaque raised surface
/// (the hover colour while hovered or pressed), the border and shadow2, plus the focus ring.
BoxDecoration uiMapControlDecoration(BuildContext context, UiStates s, {BoxShape shape = BoxShape.circle}) {
  final t = context.ui;
  return BoxDecoration(
    shape: shape,
    borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(context.uiTheme.radius(t.radius)) : null,
    color: s.hovered || s.pressed ? t.surfaceHover : t.surfaceRaised,
    border: Border.all(color: t.border),
    boxShadow: s.focused ? [...t.shadow2, ...t.focusRing] : t.shadow2,
  );
}

/// The route lines: each a casing with the tone's line over it, widths following the zoom. Never
/// hit; named once per route when the app gives a name.
class _RouteLayer extends StatelessWidget {
  const _RouteLayer({required this.routes});
  final List<UiMapRoute> routes;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final w = uiMapRouteWidth(MapCamera.of(context).zoom);
    final lines = [
      for (final r in routes)
        if (r.points.length >= 2)
          Polyline<String>(
            points: [for (final p in r.points) p._ll],
            color: uiMapRouteColor(t, r.tone),
            strokeWidth: w.line,
            // flutter_map draws the border as a stroke strokeWidth + borderStrokeWidth wide.
            borderStrokeWidth: w.casing - w.line,
            borderColor: t.mapRouteCasing,
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
            hitValue: r.id,
          ),
    ];
    final names = [for (final r in routes) if (r.points.length >= 2 && r.semanticLabel != null) r.semanticLabel!];
    final layer = IgnorePointer(child: PolylineLayer<String>(polylines: lines, simplificationTolerance: 0));
    if (names.isEmpty) return ExcludeSemantics(child: layer);
    return Semantics(container: true, image: true, label: names.join(', '), child: ExcludeSemantics(child: layer));
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
        // Not a target: its halo can be 240 px across, and a tap there still places the pin / is a map tap.
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
  const _MarkerChip({required this.marker, required this.labelMax, required this.rtl, this.onTap, this.selected, this.showLabel = true});
  final UiMapMarker marker;
  final VoidCallback? onTap;

  /// Whether this is the selected marker; null when the map has no selection.
  final bool? selected;

  /// Whether its label pill is drawn (it names the marker either way).
  final bool showLabel;

  /// The widest the label gets.
  final double labelMax;

  /// The page reads right to left: the label's first choice is the dot's left.
  final bool rtl;

  /// The marker box for a label up to [labelMax]: centred on the point, the 48dp dot target in
  /// the middle and room for the label on either side.
  static double boxWidth(double labelMax) => 2 * (labelMax + 24);

  /// The label chip's width: its text (two lines at most) with the padding and border.
  static double chipWidth(BuildContext context, String label, double labelMax) {
    final t = context.ui;
    final chrome = 2 * t.space2 + 2;
    final painter = TextPainter(
      text: TextSpan(text: label, style: context.uiText.label.copyWith(fontSize: 12, height: 16 / 12)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 2,
      ellipsis: '\u2026',
    )..layout(maxWidth: math.max(0, labelMax - chrome));
    final w = painter.width + chrome;
    painter.dispose();
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final color = marker.tone == UiStatus.neutral ? t.textMuted : marker.tone.color(t);
    final label = showLabel ? marker.label : null;
    final isSelected = selected ?? false;
    final dotSize = isSelected ? uiMapSelectedDot : 16.0;
    // The side follows where the marker is on screen: rebuilt as the map moves.
    var side = UiMapLabelSide.right;
    if (label != null) {
      final cam = MapCamera.of(context);
      final x = cam.latLngToScreenOffset(LatLng(marker.lat, marker.lng)).dx;
      side = uiMapLabelSide(x, chipWidth(context, label, labelMax), cam.nonRotatedSize.width, rtl: rtl);
    }
    final left = side == UiMapLabelSide.left;
    final dot = SizedBox(
      width: 48,
      child: Center(
        child: Container(
          width: dotSize,
          height: dotSize,
          // Selected: bigger, a white ring and a soft halo in its tone.
          decoration: isSelected
              ? BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: t.locationRing, width: 3), boxShadow: [...t.shadow2, BoxShadow(color: color.withValues(alpha: 0.30), spreadRadius: 6)])
              : BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: t.surfaceRaised, width: 3), boxShadow: t.shadow2),
        ),
      ),
    );
    final chip = label == null
        ? null
        : Transform.translate(
            // Pulled in toward the dot: 12px from the point, on either side.
            offset: Offset(left ? t.space3 : -t.space3, 0),
            // Sized to its text up to labelMax, two lines before the ellipsis. One line is a
            // pill (radiusLg clamps to half its height), two a soft rectangle, as on the web.
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: labelMax),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: 2),
                decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: BorderRadius.circular(t.radiusLg), border: Border.all(color: t.border), boxShadow: t.shadow1),
                child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.uiText.label.copyWith(fontSize: 12, height: 16 / 12)),
              ),
            ),
          );
    final half = labelMax + 24;
    return Stack(clipBehavior: Clip.none, children: [
      Positioned(
        top: 0,
        bottom: 0,
        // A 48dp square around the dot is the tap target; its centre (the dot) on the point.
        left: left ? null : half - 24,
        right: left ? half - 24 : null,
        child: Semantics(
          container: true,
          button: onTap != null,
          selected: selected,
          label: marker.semanticLabel ?? marker.label,
          onTap: onTap,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            // A marker without a selection callback is still not map background.
            onTap: onTap ?? () {},
            child: SizedBox(
              height: 48,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (left && chip != null) chip,
                dot,
                if (!left && chip != null) chip,
              ]),
            ),
          ),
        ),
      ),
    ]);
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
    if (!draggable) {
      return Semantics(
        container: true,
        label: label,
        image: true,
        child: GestureDetector(behavior: HitTestBehavior.opaque, excludeFromSemantics: true, onTap: () {}, child: pin),
      );
    }
    return Semantics(
      // Its own node: the gesture is hidden from screen readers (the map's "place at centre" action moves it).
      container: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: () {},
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
