import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';
import 'nav_demo.dart';

/// The map: markers with a floating card, and the pin for choosing a place.
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  UiMapMarker? _picked;
  UiMapView? _view;
  UiLatLng? _pin = const UiLatLng(4.1745, 73.5085);
  // Styled tiles: URLs pasted into the demo (never stored).
  String _tileLight = '', _tileDark = '';
  // My location: a stand-in position (the showcase doesn't ask for the real one).
  final _small = GlobalKey<UiMapState>();
  UiMapUserLocation? _me;
  bool _locating = false, _off = false;

  void _findMe() {
    if (_off) return; // an app would ask for permission here
    setState(() => _locating = true);
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      const me = UiMapUserLocation(4.1768, 73.5121, accuracy: 35);
      setState(() {
        _me = me;
        _locating = false;
      });
      _small.currentState?.flyTo(const UiLatLng(4.1768, 73.5121), zoom: 16);
    });
  }

  // Routes: a real road route across Male (OSRM, 1.3 km), from the nurse to the patient.
  final _routeMap = GlobalKey<UiMapState>();
  UiMapRouteTone _tone = UiMapRouteTone.primary;
  bool _showRoute = true;
  // Draw it again bumps the route id: the old line fades and the new one draws in (0.46.2).
  int _drawRun = 0;
  bool _animateRoute = true;
  static const _routeStart = UiMapUserLocation(4.17682, 73.5121, accuracy: 20);
  static const _routePoints = [
    UiLatLng(4.17682, 73.5121), UiLatLng(4.17678, 73.51237), UiLatLng(4.17708, 73.51244), UiLatLng(4.17709, 73.51223), UiLatLng(4.17716, 73.51216),
    UiLatLng(4.17773, 73.51224), UiLatLng(4.17785, 73.51146), UiLatLng(4.1769, 73.51136), UiLatLng(4.1771, 73.50974), UiLatLng(4.17284, 73.50825),
    UiLatLng(4.17311, 73.50751), UiLatLng(4.1732, 73.50755), UiLatLng(4.17344, 73.50696), UiLatLng(4.17388, 73.50715), UiLatLng(4.17387, 73.50721),
  ];

  // Turning the map (0.47.0).
  final _turnMap = GlobalKey<UiMapState>();
  bool _rotatable = true;
  double _bearing = 0;

  // Preview (0.43.0): the still map in a list, and whether it is one (the runtime switch).
  bool _preview = true;
  int _opened = 0;
  // Selected marker (0.43.0).
  String? _selected = 'n2';
  UiMapMarkerLabels _labels = UiMapMarkerLabels.all;
  // Search area (0.44.0).
  final _areaMap = GlobalKey<UiMapState>();
  double _radius = 2000;
  double? _dragging;
  bool _areaEditable = true;
  static const _areaCenter = UiLatLng(4.1755, 73.5093);

  static const _markers = [
    UiMapMarker(id: 'n1', lat: 4.1762, lng: 73.5105, label: 'Aminath Hassan, RN', tone: UiStatus.success),
    UiMapMarker(id: 'n2', lat: 4.1738, lng: 73.5072, label: 'Ibrahim Rasheed, RN'),
    UiMapMarker(id: 'n3', lat: 4.1781, lng: 73.5068, label: 'Busy', tone: UiStatus.warning),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return DocPage(
      eyebrow: 'Components',
      title: 'Map',
      lead: 'An OpenStreetMap map on flutter_map, from package:zouriel_ui/map.dart (its own library: apps that do not import it do not build it in).',
      children: [
        DocSection(
          name: 'Map',
          widget: 'UiMap',
          summary: 'Markers are dots in their tone with a label pill; tapping one calls onMarkerSelected. center and zoom move the map; onCenterChanged reports where the person moved it. The zoom buttons sit at the inline start and the attribution at the inline end, so they swap in RTL; the attribution itself is always set left to right, so English credits keep their © signs in place. On touch screens every control has a 48dp hit area. The controls use the theme, and on a dark theme the tiles are dimmed; under reduced motion there is no fling. The Flutter widget owns its MapController and disposes it with its state. Its web twin ignores queued Leaflet events after the map host is removed. Pass userAgentPackageName (your app id) for the OSM tile policy.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            SizedBox(
              height: 360,
              child: Stack(children: [
                Positioned.fill(
                  child: UiMap(
                    zoom: 15,
                    markers: _markers,
                    userAgentPackageName: 'com.zouriel.ui.showcase',
                    onMarkerSelected: (m) => setState(() => _picked = m),
                    onMapTap: (_) => setState(() => _picked = null),
                    onCenterChanged: (v) => setState(() => _view = v),
                    semanticLabel: 'Nurses near you',
                  ),
                ),
                if (_picked != null)
                  UiFloatingPanel(
                    semanticLabel: 'Nurse',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
                      UiText(_picked!.label ?? _picked!.id, variant: UiTextVariant.label),
                      UiText('${_picked!.lat.toStringAsFixed(4)}, ${_picked!.lng.toStringAsFixed(4)}', variant: UiTextVariant.caption),
                      UiButton(label: 'Close', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() => _picked = null)),
                    ]),
                  ),
              ]),
            ),
            UiText(_view == null ? 'View: —' : 'View: ${_view!.lat.toStringAsFixed(4)}, ${_view!.lng.toStringAsFixed(4)} at zoom ${_view!.zoom.toStringAsFixed(1)}', variant: UiTextVariant.caption),
          ]),
          code: '''UiMap(
  center: UiLatLng(4.1755, 73.5093),
  zoom: 15,
  markers: nurses,
  onMarkerSelected: show,
  onMapTap: (_) => hideCard(),
  userAgentPackageName: 'mv.dhirumi.nurse',
)''',
          api: const [
            ApiRow('center / zoom', 'UiLatLng / double', 'Where it looks; changing them moves the map.', def: 'Malé / 13'),
            ApiRow('markers', 'List<UiMapMarker>', 'id, lat, lng, tone, label, semanticLabel (the id is never read out).'),
            ApiRow('onMarkerSelected / onCenterChanged', 'ValueChanged<UiMapMarker / UiMapView>?', 'A marker was tapped; the person moved the map.'),
            ApiRow('onMapTap', 'ValueChanged<UiLatLng>?', 'A background tap (0.43.1; the user dot counts as background), not a marker, pin, control, attribution, preview, drag or double-tap. Also called in pinMode.'),
            ApiRow('tileUrl / attribution / onAttributionTap', 'String / String / VoidCallback?', 'Tiles (OSM by default) and their credit.'),
            ApiRow('userAgentPackageName', 'String', 'Sent with tile requests.', def: "'com.zouriel.ui'"),
            ApiRow('tileProvider', 'TileProvider?', 'Offline or test tiles; UiMapBlankTiles() (from map.dart) draws none, for widget tests.'),
            ApiRow('tileHeaders', 'Map<String, String>?', 'Extra headers for tile requests (the User-Agent is always sent).'),
            ApiRow('semanticLabel', 'String', 'Names the map.', def: "'Map'"),
          ],
        ),
        DocSection(
          name: 'Pin',
          widget: 'UiMap pin · onPinChanged · pinMode',
          summary: 'For choosing a place: with pinMode a tap on the map moves the pin there, and the pin can be dragged. Screen readers get a "Place the pin at the centre" action on the map, and Enter on the focused map does the same.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            SizedBox(
              height: 320,
              child: UiMap(
                zoom: 16,
                pinMode: true,
                pin: _pin,
                pinLabel: 'Your home',
                onPinChanged: (p) => setState(() => _pin = p),
                userAgentPackageName: 'com.zouriel.ui.showcase',
                semanticLabel: 'Choose your home on the map',
              ),
            ),
            UiText(_pin == null ? 'Pin: tap the map' : 'Pin: ${_pin!.lat.toStringAsFixed(5)}, ${_pin!.lng.toStringAsFixed(5)}', variant: UiTextVariant.caption),
          ]),
          code: "UiMap(pinMode: true, pin: home, onPinChanged: setHome, pinLabel: 'Your home')",
          api: const [
            ApiRow('pin / onPinChanged', 'UiLatLng? / ValueChanged<UiLatLng>?', 'The chosen point, shown as a draggable pin.'),
            ApiRow('pinMode', 'bool', 'A background tap moves the pin and also calls onMapTap; Enter moves only the pin.', def: 'false'),
            ApiRow('pinLabel', 'String', 'The pin\'s accessible name.', def: "'Chosen location'"),
            ApiRow('pinDraggable', 'bool', 'false shows a fixed location with the pin\'s look.', def: 'true'),
          ],
        ),
        DocSection(
          name: 'Styled tiles',
          widget: 'UiMap tileUrl · tileUrlDark',
          summary: 'Any raster tile service: tileUrl for light themes and tileUrlDark for dark ones. On a dark theme the dark tiles are shown as they are (no dimming), and the map swaps between the two the moment the theme changes, in the same tile layer. Without tileUrlDark the light tiles are dimmed on dark themes. {r} in the URL becomes @2x on a high-density screen; for 512 px tiles pass tileSize 512 and zoomOffset -1. tileHeaders (a Referer for a key restricted to a web origin) go with both. Paste your own URLs to try a style (nothing is stored).',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            UiFormField(
              label: 'Light tile URL',
              hint: 'Empty: OpenStreetMap',
              child: UiInput(placeholder: 'https://api.maptiler.com/maps/dataviz/256/{z}/{x}/{y}{r}.png?key=YOUR_KEY', value: _tileLight, onChanged: (v) => setState(() => _tileLight = v.trim())),
            ),
            UiFormField(
              label: 'Dark tile URL',
              hint: 'Empty: the light tiles, dimmed',
              child: UiInput(placeholder: 'https://api.maptiler.com/maps/dataviz-dark/256/{z}/{x}/{y}{r}.png?key=YOUR_KEY', value: _tileDark, onChanged: (v) => setState(() => _tileDark = v.trim())),
            ),
            SizedBox(
              height: 320,
              child: UiMap(
                zoom: 15,
                markers: _markers,
                tileUrl: _tileLight.isEmpty ? uiMapOsmTiles : _tileLight,
                tileUrlDark: _tileDark.isEmpty ? null : _tileDark,
                attribution: _tileLight.isEmpty ? '© OpenStreetMap contributors' : 'Tiles from your URL © OpenStreetMap contributors',
                userAgentPackageName: 'com.zouriel.ui.showcase',
                semanticLabel: 'Styled map',
              ),
            ),
          ]),
          code: '''// MapTiler raster (256 px): {r} is @2x on high-density screens. Serve the key from your API.
UiMap(
  tileUrl: 'https://api.maptiler.com/maps/dataviz/256/{z}/{x}/{y}{r}.png?key=\$key',
  tileUrlDark: 'https://api.maptiler.com/maps/dataviz-dark/256/{z}/{x}/{y}{r}.png?key=\$key',
  attribution: '© MapTiler © OpenStreetMap contributors',
  tileHeaders: {'Referer': 'https://your.site/'}, // a key restricted to a web origin
)
// 512 px tiles: tileSize: 512, zoomOffset: -1''',
          api: const [
            ApiRow('tileUrl', 'String', 'Tile URL template for light themes. {r} is @2x on a high-density screen, empty otherwise.', def: 'OSM'),
            ApiRow('tileUrlDark', 'String?', 'Tiles for dark themes, shown undimmed; swapped live on a theme change. null: the light tiles, dimmed.'),
            ApiRow('tileSize / zoomOffset', 'int / double', 'For 512 px tiles: 512 and -1.', def: '256 / 0'),
            ApiRow('tileHeaders', 'Map<String, String>?', 'Sent with the light and the dark tiles.'),
          ],
        ),
        DocSection(
          name: 'My location',
          widget: 'UiMap locateControl · userLocation',
          summary: 'locateControl adds a round Show my location button at the bottom-end corner of the visible part: it follows viewInsets, so on a map page it floats just above the bottom sheet and moves with it. It is 38px, and on touch screens 44dp with a 48dp hit area around the circle. It calls onLocate; the app finds the position itself, sets userLocation and moves the map with UiMapState.flyTo, which centres in the visible part. locating shows a spinner and ignores taps; locateOff shows the icon struck through with the tooltip Location is off, and a tap still calls onLocate so the app can ask again. userLocation draws the you-are-here dot, blue with a white ring, over a soft halo as wide as the accuracy in metres (28 to 240 px across), above the tiles and below markers and the pin, read out as Your location.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            SizedBox(
              height: 320,
              child: UiMap(
                key: _small,
                zoom: 15,
                userLocation: _me,
                locateControl: true,
                locating: _locating,
                locateOff: _off,
                onLocate: _findMe,
                userAgentPackageName: 'com.zouriel.ui.showcase',
                semanticLabel: 'Where you are',
              ),
            ),
            UiSegmented<bool>(
              label: 'Location (demo)',
              size: UiSize.sm,
              options: const [UiSegmentedOption(value: false, label: 'On'), UiSegmentedOption(value: true, label: 'Off')],
              value: _off,
              onChanged: (v) => setState(() => _off = v),
            ),
          ]),
          code: '''UiMap(
  key: mapKey,
  viewInsets: EdgeInsetsDirectional.only(bottom: sheetCover),
  userLocation: me, // UiMapUserLocation(lat, lng, accuracy: metres)
  locateControl: true,
  locating: locating,
  locateOff: denied,
  onLocate: () async {
    setState(() => locating = true);
    final p = await Geolocator.getCurrentPosition();
    setState(() { me = UiMapUserLocation(p.latitude, p.longitude, accuracy: p.accuracy); locating = false; });
    mapKey.currentState!.flyTo(UiLatLng(p.latitude, p.longitude), zoom: 16);
  },
)''',
          api: const [
            ApiRow('locateControl', 'bool', 'A round Show my location button at the bottom-end of the visible part; follows viewInsets.', def: 'false'),
            ApiRow('locating', 'bool', 'A spinner instead of the icon; taps do nothing.', def: 'false'),
            ApiRow('locateOff', 'bool', 'Struck-through icon and the tooltip Location is off (read out too); taps still call onLocate.', def: 'false'),
            ApiRow('onLocate', 'VoidCallback?', 'The button was tapped (not while locating).'),
            ApiRow('userLocation', 'UiMapUserLocation?', 'The you-are-here dot (tokens location / locationRing) over an accuracy halo sized in metres.'),
            ApiRow('UiMapState.flyTo(point, {zoom})', 'void', 'Moves the map so the point is in the middle of the visible part.'),
            ApiRow('UiStrings mapLocate / mapLocationOff / mapYourLocation', 'String', 'The words.', def: "'Show my location' / 'Location is off' / 'Your location'"),
          ],
        ),
        DocSection(
          name: 'Routes',
          widget: 'UiMap routes · UiMapState.fitPoints',
          summary: 'routes draws lines along the road, from OSRM say: each one a line in its tone over a casing, round-capped, 5 over 9px close in and thinner zoomed out. They sit above the tiles and below the pulse, the you-are-here dot, the markers and the pin, so the dots stay on top. A new list redraws the lines on the same map, and an empty one removes them. Each tone is a theme token (mapRoutePrimary, Muted, Success, Warning, Danger over mapRouteCasing) checked at 3:1 against MapTiler\'s streets-v2 and dataviz tiles in the theme\'s own brightness. semanticLabel is the route\'s one name for screen readers, such as Route, 1.3 km. fitPoints shows every point you give it (the nurse, the patient, the route) inside the part of the map viewInsets leave visible, with 24 to spare, at a whole zoom no closer than 17; one point is centred there at 17. It animates unless reduced motion. A route draws in (0.46.2): when it appears, or its points change, the casing and line grow together from its start to its end, easing out over 250 to 900 ms by length (uiMapRouteDrawDuration: 450 ms for 1 km), while a fitPoints straight after moves the map as before. The same points again (a rebuild with the same id and geometry) don\'t replay it. Set animate: false on a route to draw it at once; under reduced motion, and on a preview, routes are always drawn at once. A removed route fades out over 150 ms. Try Draw it again (a new route id), Remove the route, or the Draw-in switch. This map uses the tile URLs pasted under Styled tiles. Marker labels size to their text, up to 320 or the map\'s width less 32, and wrap to a second line before the ellipsis; the zoom buttons share the locate button\'s raised surface and shadow. Near the map\'s edge a label flips to the other side of its dot rather than run off (0.42.1; in RTL it starts on the left). A fit owns the camera (0.42.1): if viewInsets change while it animates or after it, say a sheet grows as the route appears, the fit is worked out again for the new insets, until the person or the app moves the map. controls (0.42.1) adds the app\'s own round buttons in the locate button\'s stack and style, above it at the bottom-end of the visible part; the one here, Show the whole route, calls fitPoints.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            SizedBox(
              height: 360,
              child: UiMap(
                key: _routeMap,
                zoom: 15,
                routes: _showRoute ? [UiMapRoute(id: 'to-patient-$_drawRun', points: _routePoints, tone: _tone, semanticLabel: 'Route, 1.3 km', animate: _animateRoute)] : const [],
                userLocation: _routeStart,
                markers: const [UiMapMarker(id: 'patient', lat: 4.17387, lng: 73.50721, label: 'Lily Magu, Hiyaa Tower 4, Hulhumale', tone: UiStatus.danger)],
                locateControl: true,
                controls: [
                  UiMapControl(
                    id: 'fit',
                    icon: HugeIcons.strokeRoundedCenterFocus,
                    semanticLabel: 'Show the whole route',
                    tooltip: 'Show the whole route',
                    onPressed: () => _routeMap.currentState?.fitPoints(_routePoints),
                  ),
                ],
                tileUrl: _tileLight.isEmpty ? uiMapOsmTiles : _tileLight,
                tileUrlDark: _tileDark.isEmpty ? null : _tileDark,
                attribution: _tileLight.isEmpty ? '© OpenStreetMap contributors' : 'Tiles from your URL © OpenStreetMap contributors',
                userAgentPackageName: 'com.zouriel.ui.showcase',
                semanticLabel: 'The way to the patient',
              ),
            ),
            Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              UiSegmented<UiMapRouteTone>(
                label: 'Tone (demo)',
                size: UiSize.sm,
                options: [for (final v in UiMapRouteTone.values) UiSegmentedOption(value: v, label: v.name[0].toUpperCase() + v.name.substring(1))],
                value: _tone,
                onChanged: (v) => setState(() => _tone = v),
              ),
              UiButton(label: 'Fit the route', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => _routeMap.currentState?.fitPoints(_routePoints)),
              UiButton(label: 'Fit one point', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => _routeMap.currentState?.fitPoints(const [UiLatLng(4.17682, 73.5121)])),
              UiButton(label: _showRoute ? 'Remove the route' : 'Show the route', size: UiSize.sm, variant: UiButtonVariant.ghost, onPressed: () => setState(() => _showRoute = !_showRoute)),
              UiButton(
                label: 'Draw it again',
                size: UiSize.sm,
                variant: UiButtonVariant.outline,
                onPressed: () => setState(() {
                  _showRoute = true;
                  _drawRun++;
                }),
              ),
              UiSegmented<bool>(
                label: 'Draw-in (demo)',
                size: UiSize.sm,
                options: const [UiSegmentedOption(value: true, label: 'On'), UiSegmentedOption(value: false, label: 'Off')],
                value: _animateRoute,
                onChanged: (v) => setState(() => _animateRoute = v),
              ),
            ]),
          ]),
          code: '''UiMap(
  key: mapKey,
  fill: true,
  viewInsets: EdgeInsetsDirectional.only(top: cardCover, bottom: sheetCover),
  userLocation: me,
  markers: [patient],
  routes: [UiMapRoute(id: 'to-patient', points: route.points, semanticLabel: 'Route, \${route.km} km')],
  // Your own buttons, in the locate button's stack (0.42.1).
  controls: [
    UiMapControl(
      id: 'fit',
      icon: HugeIcons.strokeRoundedCenterFocus,
      semanticLabel: 'Show both',
      tooltip: 'Show both',
      onPressed: () => mapKey.currentState!.fitPoints([me, patient]),
    ),
  ],
)

// The moment she accepts: fetch the road route (OSRM GeoJSON is [lng, lat]: swap it) and show it all.
mapKey.currentState!.fitPoints([me, patient, ...route.points]); // inside the part between the insets
// The route draws in from the nurse to the patient (0.46.2); animate: false on a route skips it.''',
          api: const [
            ApiRow('routes', 'List<UiMapRoute>', 'Lines along the road: id, points (UiLatLng), tone, semanticLabel. Under the pulse, dot, markers and pin; redrawn on the same map; empty removes them.', def: 'const []'),
            ApiRow('UiMapRoute.tone', 'UiMapRouteTone', 'primary, muted, success, warning, danger: the theme\'s mapRoute* colour over mapRouteCasing (uiMapRouteColor).', def: 'primary'),
            ApiRow('UiMapRoute.semanticLabel', 'String?', 'The route\'s one accessible name ("Route, 1.3 km"); without it the line is not read out.'),
            ApiRow('UiMapRoute.animate', 'bool', 'Draw it in from start to end when it appears or its points change (0.46.2), ease-out over uiMapRouteDrawDuration. False draws it at once; reduced motion and preview always do. The same id and points again never replay it.', def: 'true'),
            ApiRow('uiMapRouteDrawDuration(metres)', 'Duration', 'The draw-in time for a route length (0.46.2): 450 ms for 1 km, +150 ms per doubling, within 250..900 ms.'),
            ApiRow('uiMapRouteLength(points) / uiMapRoutePartial(points, fraction)', 'double / List<UiLatLng>', 'A route\'s length in metres, and its first fraction by length (0.46.2): what the draw-in shows each frame.'),
            ApiRow('uiMapRouteFade', 'Duration', 'How long a removed route fades out (0.46.2); at once under reduced motion.', def: '150 ms'),
            ApiRow('UiMapState.fitPoints(points, {padding, maxZoom, animate})', 'void', 'Every point inside the visible part (between viewInsets) plus padding (24), at a whole zoom up to maxZoom (17); one point is centred at maxZoom. Animated unless animate is false or reduced motion. Called before the map is ready (straight after it is built), it is held and runs once it is, without animating (0.44.2).'),
            ApiRow('uiMapFitView(points, size, area, {maxZoom})', 'UiMapView?', 'The view fitPoints moves to (the map\'s own centre and zoom), for tests or a first view.'),
            ApiRow('uiMapRouteWidth(zoom)', '({double line, double casing})', 'The widths at a zoom: 5 over 9 from zoom 14, down to 60% at zoom 10.'),
            ApiRow('UiMapZoomButton', 'widget', 'The zoom buttons: the locate button\'s surface, border and shadow2, 38 (44 on touch) with a 48dp target.'),
            ApiRow('controls', 'List<UiMapControl>', 'The app\'s own round buttons (0.42.1), above the locate button at the bottom-end of the visible part (in its place without one), 8 apart, following viewInsets; the bottom-left in RTL.', def: 'const []'),
            ApiRow('UiMapControl(id, icon, semanticLabel, onPressed, tooltip)', 'class', 'One button: a stable id, a UiIconData, its accessible name, the callback (null shows it disabled) and an optional tooltip.'),
            ApiRow('UiMapControlButton', 'widget', 'How a control is drawn: the locate button\'s round raised surface, border and shadow2, 38 (44 on touch) with a 48dp target.'),
            ApiRow('uiMapLabelSide(x, labelWidth, mapWidth, {rtl})', 'UiMapLabelSide', 'Which side of its dot a label goes (0.42.1): the inline end unless it would run off the map there (8 to spare), then the other side, else the roomier one.'),
          ],
        ),
        DocSection(
          name: 'Preview',
          widget: 'UiMap preview · onPreviewPressed · previewLabel',
          summary: 'preview (0.43.0) makes the map a still picture that is one button, for a map inside a list or a chat: tapping it, or Enter or Space when it has focus, calls onPreviewPressed, and the app opens the full map. Nothing on it moves: no pan, pinch, double-tap or wheel zoom, no arrow keys, no zoom, locate or app buttons. The markers are drawn but take no taps of their own, and the attribution stays visible (the tile licence asks for it) without being a link. A vertical drag or the mouse wheel over it scrolls the page around it, as over a photo. It is read out as one button named previewLabel, Open map by default (UiStrings.mapOpen, so an app can translate it), shows a ring inside its edge for keyboard focus and darkens a little while pressed. A small round expand badge in the map controls\' raised style sits in the top-end corner (top-left in RTL). center, zoom and fitPoints still place it, without animating. Turn preview off and the full map is back on the same map. Try it: scroll the page over the map, then tap it.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            SizedBox(
              height: 200,
              child: UiMap(
                preview: _preview,
                onPreviewPressed: () {
                  setState(() => _opened++);
                  Navigator.of(context).push(UiPageRoute<void>(builder: (_) => const MapResultsDemo()));
                },
                center: const UiLatLng(4.1760, 73.5087),
                zoom: 15,
                markers: _markers,
                markerLabels: _preview ? UiMapMarkerLabels.none : UiMapMarkerLabels.all,
                userAgentPackageName: 'com.zouriel.ui.showcase',
                semanticLabel: 'Nurses near you',
              ),
            ),
            Wrap(spacing: t.space3, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              UiSegmented<bool>(
                label: 'Preview (demo)',
                size: UiSize.sm,
                options: const [UiSegmentedOption(value: true, label: 'On'), UiSegmentedOption(value: false, label: 'Off')],
                value: _preview,
                onChanged: (v) => setState(() => _preview = v),
              ),
              UiText('Opened $_opened ${_opened == 1 ? 'time' : 'times'}', variant: UiTextVariant.caption),
            ]),
          ]),
          code: '''// A result card's Map tab: a still map of the results; tapping it opens the full map.
SizedBox(
  height: 200,
  child: UiMap(
    preview: true,
    onPreviewPressed: () => Navigator.of(context).push(UiPageRoute(builder: (_) => ResultsMap(results))),
    markers: [for (final r in results) UiMapMarker(id: r.id, lat: r.lat, lng: r.lng, semanticLabel: r.name)],
    markerLabels: UiMapMarkerLabels.none,
  ),
)
// Or place it on the results once laid out: mapKey.currentState!.fitPoints(points) (no animation on a preview).''',
          api: const [
            ApiRow('preview', 'bool', 'A still picture that is one button (0.43.0): no gestures, keys or controls; markers drawn but not selectable; drags and the wheel scroll the page around it. Off at runtime gives the full map back.', def: 'false'),
            ApiRow('onPreviewPressed', 'VoidCallback?', 'The preview was tapped, or Enter or Space pressed on it: open the full map.'),
            ApiRow('previewLabel', 'String?', 'Its accessible name. null: UiStrings.mapOpen.', def: "'Open map'"),
            ApiRow('UiStrings.mapOpen', 'String', 'The default preview name, for translation.', def: "'Open map'"),
            ApiRow('UiMapPreviewButton · UiMapPreviewBadge', 'widget', 'How a preview is drawn: the whole-map button (a subtle press tint, the focus ring inside the edge) and the 30px round expand badge at the top-end corner.'),
          ],
        ),
        DocSection(
          name: 'Selected marker',
          widget: 'UiMap selectedMarkerId · markerLabels',
          summary: 'selectedMarkerId (0.43.0) marks one marker as the chosen one: its dot is drawn bigger (22px instead of 16) with a white ring and a soft halo in its tone, above the other markers, with its label shown, and screen readers hear it as selected. The others stay as they are. Changing it moves the selection on the same map, without rebuilding or moving it. markerLabels says which labels show: all (the default), selected (only the selected marker\'s, for a busy map where a tapped pin shows its card) or none. A hidden label still names its marker for screen readers. Tap a marker here to select it; tap empty map to clear it through onMapTap (0.43.1).',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            SizedBox(
              height: 320,
              child: UiMap(
                zoom: 15,
                markers: _markers,
                selectedMarkerId: _selected,
                markerLabels: _labels,
                onMarkerSelected: (m) => setState(() => _selected = m.id),
                onMapTap: (_) => setState(() => _selected = null),
                userAgentPackageName: 'com.zouriel.ui.showcase',
                semanticLabel: 'Nurses near you',
              ),
            ),
            Wrap(spacing: t.space3, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              UiSegmented<UiMapMarkerLabels>(
                label: 'Labels (demo)',
                size: UiSize.sm,
                options: const [
                  UiSegmentedOption(value: UiMapMarkerLabels.all, label: 'All'),
                  UiSegmentedOption(value: UiMapMarkerLabels.selected, label: 'Selected'),
                  UiSegmentedOption(value: UiMapMarkerLabels.none, label: 'None'),
                ],
                value: _labels,
                onChanged: (v) => setState(() => _labels = v),
              ),
              UiButton(label: 'Clear the selection', size: UiSize.sm, variant: UiButtonVariant.ghost, onPressed: _selected == null ? null : () => setState(() => _selected = null)),
            ]),
          ]),
          code: '''UiMap(
  markers: results,
  selectedMarkerId: selected?.id,
  markerLabels: UiMapMarkerLabels.selected,
  onMarkerSelected: (m) => setState(() => selected = m),
  onMapTap: (_) => setState(() => selected = null),
)''',
          api: const [
            ApiRow('selectedMarkerId', 'String?', 'The selected marker (0.43.0): a 22px dot (uiMapSelectedDot) with a white ring and a halo in its tone, on top, its label shown, read out as selected.'),
            ApiRow('markerLabels', 'UiMapMarkerLabels', 'all, selected (only the selected marker\'s label) or none. Hidden labels still name their markers.', def: 'all'),
            ApiRow('onMapTap', 'ValueChanged<UiLatLng>?', 'A background tap (0.43.1), used here to clear the selection; foreground objects, preview, drags and double-taps do not call it.'),
          ],
        ),
        DocSection(
          name: 'Search area',
          widget: 'UiMap area · onAreaChanging · onAreaChanged · fitArea',
          summary: 'area (0.44.0) draws a search area: a soft circle in its tone with a clear outline, in true metres, so it grows and shrinks with the zoom. It sits over the tiles and under routes, markers and the pin, and drags anywhere on it still pan the map. editable adds a round handle on its inline-end edge (the left in right-to-left text) with a chip showing the radius ("2 km", "800 m": uiMapFormatRadius, worded by UiStrings). Dragging the handle changes the radius, rounded and kept between minMeters and maxMeters; the map does not pan while you drag it. onAreaChanging reports each new radius during the drag and onAreaChanged once on release (pass the new radius back in area). For keyboards and screen readers the handle is a slider named areaLabel (UiStrings.mapSearchArea, "Search area"): Up and the outward arrow widen it 10%, Down and the inward arrow narrow it, Home and End go to the smallest and largest. fitArea() shows the whole circle in the visible part, between viewInsets. A preview, or editable: false, draws the circle without a handle.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            SizedBox(
              height: 360,
              child: UiMap(
                key: _areaMap,
                center: _areaCenter,
                zoom: 13,
                markers: _markers,
                area: UiMapArea(center: _areaCenter, radiusMeters: _radius, editable: _areaEditable, minMeters: 500, maxMeters: 50000),
                onAreaChanging: (r) => setState(() => _dragging = r),
                onAreaChanged: (r) => setState(() {
                  _radius = r;
                  _dragging = null;
                }),
                userAgentPackageName: 'com.zouriel.ui.showcase',
                semanticLabel: 'Search area map',
              ),
            ),
            Wrap(spacing: t.space3, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              UiText('Radius: ${uiMapFormatRadius(_dragging ?? _radius, context.uiStrings)}${_dragging != null ? ' (dragging)' : ''}', variant: UiTextVariant.caption),
              UiButton(label: 'Show the whole area', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => _areaMap.currentState?.fitArea()),
              UiSwitch(value: _areaEditable, onChanged: (v) => setState(() => _areaEditable = v), label: 'Editable'),
            ]),
          ]),
          code: '''UiMap(
  key: mapKey,
  area: UiMapArea(center: me, radiusMeters: radius, editable: true, minMeters: 500, maxMeters: 50000),
  onAreaChanged: (r) => setState(() => radius = r),
)
// Show it all:
mapKey.currentState!.fitArea();''',
          api: const [
            ApiRow('area', 'UiMapArea?', 'center, radiusMeters, tone (primary), editable (false), minMeters (200), maxMeters (50000).'),
            ApiRow('onAreaChanging', 'ValueChanged<double>?', 'The radius in metres each time it changes during a handle drag (and on each key step).'),
            ApiRow('onAreaChanged', 'ValueChanged<double>?', 'The radius when the handle is let go (every release), and on each key step. The chosen radius stays drawn until the app passes a new area.'),
            ApiRow('areaLabel', 'String?', 'The handle\'s accessible name; null: UiStrings.mapSearchArea.', def: "'Search area'"),
            ApiRow('UiMapState.fitArea({padding, maxZoom, animate})', 'void', 'Shows the whole circle in the visible part, like fitPoints (also held until the map is ready).'),
            ApiRow('uiMapFormatRadius(m, strings)', 'String', '"800 m", "1.5 km", "20 km" (UiStrings.mapRadiusMeters / mapRadiusKilometers, {n} is the number).'),
            ApiRow('uiMapNiceRadius · uiMapAreaStep · uiMapMetersPerPx · uiMapAreaBounds', 'functions', 'The rounding (10 m / 100 m / 1 km), a 10% key step, metres per px at a latitude and zoom, the circle\'s N/S/E/W points.'),
          ],
        ),
        DocSection(
          name: 'Map page',
          widget: 'UiMap fill · pulse · viewInsets',
          summary: 'A full-screen map with the form in a UiBottomSheet and a UiFloatingPanel status card at the top. fill gives square corners. pulse draws soft rings radiating from a point while the app searches (one still halo under reduced motion); they move with the map, sit under the markers and the pin, and say nothing to screen readers, so put the words in the status card. viewInsets is how much of each edge the sheet and the card cover, straight from their onCoverChanged: the map still draws edge to edge, but its centre, the pin\'s centre, onCenterChanged, the zoom buttons and the attribution use the part between them. When the sheet moves to another snap, the map pans so the point in the middle of the visible part stays in the middle of the new visible part. glass on the sheet and the card (0.41.2) makes them see-through, and glassStrength (0.41.3) says how much: clear, the default, lets a map in the theme\'s brightness plainly show through (roads, coastline, parks), lightly blurred and squeezed just enough to keep every text colour AA over such a map; frosted is the near-opaque surface that stays AA over any backdrop, for photos or a map in the other brightness. Solid under the platform high-contrast setting.',
          demo: Row(children: [
            Expanded(child: UiText('Opens as its own page, the way an app shows it on a phone.', variant: UiTextVariant.body)),
            SizedBox(width: t.space3),
            UiButton(label: 'Open the map page', onPressed: () => Navigator.of(context).push(UiPageRoute<void>(builder: (_) => const MapPageDemo()))),
          ]),
          code: '''Stack(children: [
  Positioned.fill(
    child: UiMap(
      fill: true,
      center: home,
      markers: nurses,
      pin: home,
      pinDraggable: false,
      pulse: UiMapPulse(lat: home.lat, lng: home.lng, active: searching),
      viewInsets: EdgeInsetsDirectional.only(top: cardCover, bottom: sheetCover),
    ),
  ),
  UiFloatingPanel(
    placement: UiFloatingPanelPlacement.top,
    semanticLabel: 'Status',
    glass: true, // see-through: clear by default (a map in the theme's brightness); frosted for photos
    onCoverChanged: (v) => setState(() => cardCover = v),
    child: Text(searching ? 'Looking for a nurse near you' : 'Where should the nurse come?'),
  ),
  UiBottomSheet(
    title: 'Find a nurse',
    snaps: const [0.42, 0.75],
    snap: snap,
    closable: false,
    maxWidth: 560, // tablets and desktops: 560 wide, centred
    glass: true,
    onSnapChanged: (i) => setState(() => snap = i),
    onCoverChanged: (v) => setState(() => sheetCover = v),
    child: form,
  ),
])''',
          api: const [
            ApiRow('pulse', 'UiMapPulse?', 'Soft rings radiating from lat/lng (3 staggered, 2.4s, up to 120px) in tone while active; a still halo under reduced motion. Geo-anchored, under the markers and pin, silent.'),
            ApiRow('viewInsets', 'EdgeInsetsDirectional', 'Px covered over each edge. Centre, pin centre, onCenterChanged and the controls use the part between them; a change pans to keep the visible middle in the middle.', def: 'zero'),
            ApiRow('fill', 'bool', 'Square corners, for a full-screen map page.', def: 'false'),
            ApiRow('UiFloatingPanel.onCoverChanged', 'ValueChanged<double>?', 'Px of its edge the card covers (gutter, safe area and height): feed it to viewInsets.top.'),
            ApiRow('UiBottomSheet.onCoverChanged', 'ValueChanged<double>?', 'Px of the screen bottom the sheet covers once settled: feed it to viewInsets.bottom.'),
            ApiRow('UiBottomSheet.maxWidth', 'double?', 'The widest the sheet gets. On a wider screen it is that wide and centred; the backdrop still covers everything and onCoverChanged still reports the covered height. 560 suits tablets and desktops.'),
            ApiRow('UiBottomSheet.glass · UiFloatingPanel.glass', 'bool', 'See-through surface over the map (0.41.2); how see-through is glassStrength. Fields and buttons stay solid. Solid under MediaQuery.highContrast (Flutter has no reduce-transparency setting).', def: 'false · UiConfig.glass'),
            ApiRow('glassStrength', 'UiGlassStrength', 'How see-through glass is (0.41.3). clear: a 12% tint over a light blur, squeezed into the theme\'s glassClearFloor..glassClearCeiling and saturated, so a map in the theme\'s brightness plainly shows through with text, muted text, primary and status colours AA (icons 3:1) over it. frosted: the 0.41.2 recipe, 60% over a heavy blur and glassSheetFloor..glassSheetCeiling, AA over anything, pure white and black included.', def: 'clear'),
            ApiRow('UiBottomSheetState.persistent', 'bool', 'True when the smallest snap is above 0, as here: Back and Escape collapse it to that snap, and from there Back leaves the page.'),
          ],
        ),
        DocSection(
          name: 'Turning the map',
          widget: 'UiMap rotatable · compass · bearing · rotateTo()',
          summary: 'rotatable (0.47.0, on by default) lets the person turn the map with two fingers. A pinch decides what it is in its first moments: a 15 degree twist turns the map (and it keeps zooming and panning with the fingers), while a 10% zoom or a 30 px pan that comes first makes it a zoom or pan, and no small twist turns the map by accident. While the map is turned away from north, a compass button sits under the zoom buttons in their style (48dp targets, following viewInsets, the inline start); its needle points north and a tap eases the map back north up (Reset to north, in UiStrings). Markers, the pin, the label chips and the area handle stay upright; routes, dots and the you-are-here arrow turn with the map; the attribution stays put. onBearingChanged reports the bearing when a turn ends (or the compass is pressed), onUserMove that the person moved the map. bearing turns it from the app (heading-up navigation), and rotateTo turns it back after the person turned it.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            SizedBox(
              height: 360,
              child: UiMap(
                key: _turnMap,
                zoom: 16,
                center: const UiLatLng(4.1755, 73.5093),
                markers: const [UiMapMarker(id: 'a', lat: 4.1762, lng: 73.5098, label: 'Lily Magu, Hiyaa Tower 4', tone: UiStatus.danger), UiMapMarker(id: 'b', lat: 4.1748, lng: 73.5081, label: 'Faruma clinic')],
                routes: const [UiMapRoute(id: 'r', points: _routePoints, animate: false)],
                rotatable: _rotatable,
                onBearingChanged: (b) => setState(() => _bearing = b),
                tileUrl: _tileLight.isEmpty ? uiMapOsmTiles : _tileLight,
                tileUrlDark: _tileDark.isEmpty ? null : _tileDark,
                userAgentPackageName: 'com.zouriel.ui.showcase',
                semanticLabel: 'A map you can turn',
              ),
            ),
            Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              UiButton(label: 'Turn to 45°', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() {
                _bearing = 45;
                _turnMap.currentState?.rotateTo(45);
              })),
              UiSegmented<bool>(
                label: 'Rotatable (demo)',
                size: UiSize.sm,
                options: const [UiSegmentedOption(value: true, label: 'On'), UiSegmentedOption(value: false, label: 'Off')],
                value: _rotatable,
                onChanged: (v) => setState(() => _rotatable = v),
              ),
              Text('Bearing ${_bearing.round()}°', style: context.uiText.caption),
            ]),
          ]),
          code: '''UiMap(
  key: mapKey,
  markers: places,
  rotatable: true, // the default: two fingers turn it past 15 degrees
  onBearingChanged: (b) => setState(() => bearing = b),
)
mapKey.currentState!.rotateTo(0); // north up from code''',
          api: const [
            ApiRow('rotatable', 'bool', 'Two fingers turn the map (0.47.0): the first of a 15 degree twist, a 10% zoom or a 30 px pan wins the gesture.', def: 'true'),
            ApiRow('compass', 'bool', 'The compass button under the zoom buttons while turned; a tap eases north up.', def: 'true'),
            ApiRow('bearing', 'double', 'The compass direction at the top, degrees clockwise from north; turns the map when it changes.', def: '0'),
            ApiRow('zoomButtons', 'bool', 'The zoom buttons; pinch, double tap, the wheel and keys still zoom.', def: 'true'),
            ApiRow('onBearingChanged', 'ValueChanged<double>?', 'The bearing when the person ends a turn, or presses the compass (0).'),
            ApiRow('onUserMove', 'VoidCallback?', 'The person moved the map: drag, pinch, turn, fling, double tap, wheel, keys.'),
            ApiRow('UiMapState.rotateTo(bearing) / currentBearing', 'void / double', 'Turn the map from code (eased unless reduced motion); the bearing shown.'),
            ApiRow('UiMapUserLocation.heading', 'double?', 'The dot becomes an arrow puck pointing that way, turning with the map.'),
            ApiRow('UiStrings.mapResetNorth', 'String', 'The compass\'s name.', def: "'Reset to north'"),
          ],
        ),
        DocSection(
          name: 'Navigation',
          widget: 'UiMapNavigation · UiNavTracker',
          summary: 'UiMapNavigation (0.47.0) is a turn-by-turn view, like a car\'s navigation, for the nurse driving to a patient. The app gives it the route\'s geometry, its steps (OSRM\'s steps: maneuver type, modifier, location and exit, distance and duration, and the instruction already in the app\'s language) and the live position; the view reads no GPS itself. The map follows the person and turns heading-up (flat, no tilt), the route ahead in the primary tone and the part already driven dimmed, with an arrow for the person. The banner shows the next maneuver: a big arrow for its type (turns, slight and sharp, U-turns, roundabouts with the exit number, forks, merges, depart, arrive), the distance to it (in 80 m), the instruction and the street, with the maneuver after it in a small tab. The bar shows the time and distance left, the arrival time and End. The logic is UiNavTracker, pure and testable: it snaps each position to the route, works out the step, the distance to the next maneuver and what is left, and calls onAnnounce at the start, on each new maneuver ahead and at 200 m and 30 m before it (each once, for the app to speak), onOffRoute after 5 s more than 40 m off the route (reroute: give a new route and steps) and onArrived within 20 m of the end. A drag, pinch or two-finger turn stops the following and shows Recenter (and the compass). With animations off the map turns at once. In right-to-left text the banner and bar mirror; the arrows never do. glass frosts the banner and bar. 0.47.1: the app\'s own buttons (actions, usually UiNavAction: mute, SOS) stack as 48dp round, opaque buttons at the end side under the banner, clear of the compass (the inline start) and Recenter (bottom start); tone danger is the prominent SOS style and pressed makes a toggle. status shows a short state (Rerouting…) as a pill under the banner, a live region. insets (EdgeInsetsDirectional) keep the banner, buttons, Recenter and bar clear of the app\'s own bars, and the banner and bar respect the safe area (MediaQuery padding: status bar, notch, gesture bar) wherever it is bigger. Maneuver types and modifiers may be OSRM\'s spaced words or snake_case (sharp_right, end_of_road). 0.47.2: hold: true (or holdDuration) makes a UiNavAction fire only when held to the end (2 s), as UiHoldButton does: a ring in its ink fills round its edge while held, letting go or sliding off cancels, Space or Enter held works the same, the hold hint is read with it and the progress is read out (Holding, 50%; Hold cancelled). With animations off the hold is still needed and the ring shows whole and steady. A tap or a screen reader\'s activation calls onTap (the SOS confirm sheet) or, without one, the confirm dialog. status wraps to two lines, then ends on a whole word with an ellipsis, between the compass column and the buttons; the pill is outside the measured banner, so a taller one moves nothing. Play the drive; Wander off leaves the road to show onOffRoute and the Rerouting… status; hold SOS (a tap logs the app\'s fallback); Long status shows the wrapping.',
          demo: NavDriveDemo(tileUrl: _tileLight.isEmpty ? null : _tileLight, tileUrlDark: _tileDark.isEmpty ? null : _tileDark),
          code: '''UiMapNavigation(
  route: route, // OSRM geometry, [lng, lat] swapped to UiLatLng
  steps: [
    for (final s in osrm.steps)
      UiNavStep(
        maneuver: UiNavManeuver(type: s.maneuver.type, modifier: s.maneuver.modifier, exit: s.maneuver.exit,
            location: UiLatLng(s.maneuver.location[1], s.maneuver.location[0]), drivingSide: s.drivingSide),
        distanceMeters: s.distance, durationSeconds: s.duration, instruction: s.instruction, streetName: s.name),
  ],
  position: position, // from the app's geolocation stream: UiNavPosition(lat, lng, heading:, speed:, accuracy:, timestamp:)
  destinationLabel: 'Lily Magu',
  onAnnounce: (e) => tts.speak(e.step.instruction),
  onOffRoute: (_) => reroute(),
  onArrived: arrive,
  onEnd: stop,
  status: rerouting ? 'Rerouting…' : null, // 0.47.1
  insets: EdgeInsetsDirectional.only(top: appBarHeight),
  actions: [
    UiNavAction(icon: muted ? HugeIcons.strokeRoundedVolumeOff : HugeIcons.strokeRoundedVolumeHigh,
        label: muted ? 'Unmute' : 'Mute', pressed: muted, onPressed: toggleMute),
    UiNavAction(icon: HugeIcons.strokeRoundedAlert02, label: 'SOS', tone: UiNavActionTone.danger, hold: true, onTap: openSosSheet, onPressed: sos), // 0.47.2
  ],
)''',
          api: const [
            ApiRow('route / steps', 'List<UiLatLng> / List<UiNavStep>', 'The geometry and OSRM steps (UiNavManeuver type, modifier, location, bearingAfter, exit, drivingSide; distanceMeters, durationSeconds, instruction, streetName). A new list (a reroute) starts a new tracker.'),
            ApiRow('position', 'UiNavPosition?', 'The live position: lat, lng, heading, speed, accuracy, timestamp.'),
            ApiRow('options', 'UiNavOptions', 'offRouteMeters (40, or the accuracy if bigger), offRouteSeconds (5), arriveMeters (20), announceMeters ([200, 30]).'),
            ApiRow('zoom / destinationLabel / formatTime / glass', '—', 'The follow zoom (17), the destination marker\'s label, the arrival time format (24-hour), frosted banner and bar.'),
            ApiRow('onAnnounce / onOffRoute / onArrived / onProgress / onEnd', 'callbacks', 'Speak the step; reroute; at the destination; every state; End pressed. Called after the frame that takes the position.'),
            ApiRow('status', 'String?', 'A short state as a pill under the banner (Rerouting…), a live region (0.47.1); up to two lines, then whole words and an ellipsis (0.47.2).'),
            ApiRow('insets', 'EdgeInsetsDirectional', 'What the app covers along each edge: an app bar (with the status bar under it), a bottom navigation, a side rail. The banner, buttons, Recenter and bar stay inside them; the safe area (MediaQuery padding) counts where it is bigger (0.47.1).', def: 'zero'),
            ApiRow('actions', 'List<Widget>', 'The app\'s own buttons, usually UiNavAction: a 48dp round stack at the end side under the banner, clear of the compass and Recenter (0.47.1).', def: '[]'),
            ApiRow('UiNavAction(icon, label, onPressed, tone, pressed)', 'widget', 'A 48dp opaque round button: icon (hugeicons), label (its accessible name), tone (UiNavActionTone.neutral | danger: the SOS style, danger fill in a raised-surface ring), pressed (a toggle: announced, the primary fill while on) (0.47.1).'),
            ApiRow('UiNavAction(hold, holdDuration, holdHint, onTap)', 'bool / Duration? / String? / VoidCallback?', 'Press and hold (0.47.2, off by default): onPressed fires only when held to the end, 2 s (uiNavHoldDuration) or holdDuration; a ring fills round the button, letting go or sliding off cancels, Space / Enter held works; the progress is read out. A tap or screen reader activation calls onTap, else the confirm dialog (confirmTitle, confirmMessage, confirmLabel, destructive).'),
            ApiRow('uiNavFitWords(text, fits)', 'String', 'The status pill\'s cut: the text when it fits, else the most whole words that fit with an ellipsis (0.47.2).'),
            ApiRow('uiNavWord(word)', 'String', 'A maneuver word in OSRM\'s spaced form: sharp_right and END_OF_ROAD become sharp right and end of road; the icons read either (0.47.1).'),
            ApiRow('UiMapNavigationState.recenter()', 'void', 'Follows the person again at zoom, heading-up.'),
            ApiRow('UiNavTracker(route, steps, options:)', 'class', 'update(position) returns UiNavState: snapped, display, distanceFromRoute, traveledMeters, stepIndex, next, nextNext, distanceToManeuver, remainingMeters, remainingSeconds, bearing, offRoute, arrived, events (UiNavAnnounce, UiNavOffRoute, UiNavArrived); also split and pointAt.'),
            ApiRow('uiNavFormatDistance / uiNavFormatDuration / uiNavFormatClock', 'String', '"80 m", "150 m", "2.4 km"; "3 min", "1 h 5 min"; "14:05". Words from the nav strings (Dhivehi in UiStrings.dv).'),
            ApiRow('UiMapRoute.opacity', 'double', 'The line\'s opacity over its casing (0.47.0); the way behind is 0.6.', def: '1'),
          ],
        ),
        DocSection(
          name: 'Maneuver icons',
          widget: 'uiNavIcons · uiNavIcon() · uiNavIconKind()',
          summary: 'The banner\'s arrows (0.47.0), one drawing per maneuver kind, in the library\'s line style on a 24px grid (hugeicons has no maneuver set: no roundabout exits, slight or sharp turns). uiNavIconKind picks the kind from OSRM\'s type and modifier: roundabouts and rotaries by their exit\'s direction, forks and merges by side, ramps as slight turns, everything else by its modifier; a U-turn bends left where traffic keeps right and right where it keeps left (drivingSide). The road not taken at a fork or merge is faint. They are never mirrored in right-to-left text. The same data draws them on the web.',
          demo: const NavIconGallery(),
          api: const [
            ApiRow('uiNavIconKind(maneuver)', 'UiNavIconKind', 'The drawing for an OSRM type + modifier (+ drivingSide for U-turns); webName is the web\'s name.'),
            ApiRow('uiNavIcon(maneuver) / uiNavIcons', 'UiIconData / Map', 'The drawing itself, for UiIcon; every drawing by kind.'),
          ],
        ),
      ],
    );
  }
}

/// The full map a preview opens (0.43.0): the results, the tapped one selected with its card at
/// the top, only its label shown.
class MapResultsDemo extends StatefulWidget {
  const MapResultsDemo({super.key, this.tileProvider});

  /// Tests pass UiMapBlankTiles.
  final TileProvider? tileProvider;

  @override
  State<MapResultsDemo> createState() => _MapResultsDemoState();
}

class _MapResultsDemoState extends State<MapResultsDemo> {
  UiMapMarker? _selected;
  double _cardCover = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final s = _selected;
    return ColoredBox(
      color: t.bg,
      child: Stack(children: [
        Positioned.fill(
          child: UiMap(
            fill: true,
            center: const UiLatLng(4.1760, 73.5087),
            zoom: 16,
            markers: _MapPageState._markers,
            selectedMarkerId: s?.id,
            markerLabels: UiMapMarkerLabels.selected,
            viewInsets: EdgeInsetsDirectional.only(top: _cardCover),
            onMarkerSelected: (m) => setState(() => _selected = m),
            onMapTap: (_) => setState(() => _selected = null),
            userAgentPackageName: 'com.zouriel.ui.showcase',
            tileProvider: widget.tileProvider,
            semanticLabel: 'Nurses near you',
          ),
        ),
        UiFloatingPanel(
          placement: UiFloatingPanelPlacement.top,
          semanticLabel: 'Nurse',
          onCoverChanged: (v) => setState(() => _cardCover = v),
          child: Row(spacing: t.space3, children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
                  UiText(s?.label ?? 'Nurses near you', variant: UiTextVariant.label),
                  UiText(s == null ? 'Tap a pin to see the nurse.' : '${s.lat.toStringAsFixed(4)}, ${s.lng.toStringAsFixed(4)}', variant: UiTextVariant.caption),
                ]),
              ),
            ),
            UiButton(label: 'Close', size: UiSize.sm, variant: UiButtonVariant.ghost, onPressed: () => Navigator.of(context).pop()),
          ]),
        ),
      ]),
    );
  }
}

/// The full-screen "Find a nurse" page: the map behind, a status card at the top, the form in a
/// bottom sheet, and the pulse while searching.
class MapPageDemo extends StatefulWidget {
  const MapPageDemo({super.key, this.tileProvider});

  /// Tests pass UiMapBlankTiles.
  final TileProvider? tileProvider;

  @override
  State<MapPageDemo> createState() => _MapPageDemoState();
}

class _MapPageDemoState extends State<MapPageDemo> {
  static const _home = UiLatLng(4.1752, 73.5089);
  bool _searching = false;
  int _snap = 0;
  double _cardCover = 0, _sheetCover = 0;
  String _when = 'now';
  TextDirection _dir = TextDirection.ltr;
  /// The sheet and status card: clear glass (the default here), frosted glass, or the solid surface (null).
  UiGlassStrength? _glass = UiGlassStrength.clear;
  final _map = GlobalKey<UiMapState>();
  UiMapUserLocation? _me;
  bool _locating = false, _off = false;

  void _findMe() {
    if (_off) return; // an app would ask for permission here
    setState(() => _locating = true);
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _me = const UiMapUserLocation(4.1768, 73.5121, accuracy: 35);
        _locating = false;
      });
      _map.currentState?.flyTo(const UiLatLng(4.1768, 73.5121), zoom: 16);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Directionality(
      textDirection: _dir,
      child: ColoredBox(
        color: t.bg,
        child: Stack(children: [
          Positioned.fill(
            child: UiMap(
              key: _map,
              fill: true,
              center: _home,
              userLocation: _me,
              locateControl: true,
              locating: _locating,
              locateOff: _off,
              onLocate: _findMe,
              controls: [
                UiMapControl(
                  id: 'fit',
                  icon: HugeIcons.strokeRoundedCenterFocus,
                  semanticLabel: 'Show all the nurses',
                  tooltip: 'Show all the nurses',
                  onPressed: () => _map.currentState?.fitPoints([_home, for (final m in _MapPageState._markers) UiLatLng(m.lat, m.lng)]),
                ),
              ],
              zoom: 15,
              markers: _MapPageState._markers,
              pin: _home,
              pinDraggable: false,
              pinLabel: 'Your home',
              pulse: UiMapPulse(lat: _home.lat, lng: _home.lng, active: _searching),
              viewInsets: EdgeInsetsDirectional.only(top: _cardCover, bottom: _sheetCover),
              userAgentPackageName: 'com.zouriel.ui.showcase',
              tileProvider: widget.tileProvider,
              semanticLabel: 'Nurses near your home',
            ),
          ),
          UiFloatingPanel(
            placement: UiFloatingPanelPlacement.top,
            semanticLabel: 'Status',
            glass: _glass != null,
            glassStrength: _glass ?? UiGlassStrength.clear,
            onCoverChanged: (v) => setState(() => _cardCover = v),
            child: Row(spacing: t.space3, children: [
              if (_searching) const UiSpinner(label: 'Searching'),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, spacing: t.space1, children: [
                    UiText(_searching ? 'Looking for a nurse near you' : 'Where should the nurse come?', variant: UiTextVariant.label),
                    UiText(_searching ? 'We ask the nearest nurse first. This takes a minute or two.' : 'Your home is on the map. Fill in the details below.', variant: UiTextVariant.caption),
                  ]),
                ),
              ),
              UiButton(label: 'Close', size: UiSize.sm, variant: UiButtonVariant.ghost, onPressed: () => Navigator.of(context).pop()),
            ]),
          ),
          UiBottomSheet(
            title: 'Find a nurse',
            snaps: const [0.42, 0.75],
            snap: _snap,
            closable: false,
            maxWidth: 560,
            glass: _glass != null,
            glassStrength: _glass ?? UiGlassStrength.clear,
            onSnapChanged: (i) => setState(() => _snap = i),
            onCoverChanged: (v) => setState(() => _sheetCover = v),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space4, children: [
              const UiFormField(label: 'Address', child: UiInput(placeholder: 'Building, street, island', value: 'M. Blue Lagoon, Majeedhee Magu')),
              UiSegmented<String>(
                label: 'When',
                options: const [UiSegmentedOption(value: 'now', label: 'Now'), UiSegmentedOption(value: 'later', label: 'Later today')],
                value: _when,
                onChanged: (v) => setState(() => _when = v),
              ),
              UiSegmented<String>(
                label: 'Surface (demo)',
                size: UiSize.sm,
                options: const [UiSegmentedOption(value: 'clear', label: 'Clear'), UiSegmentedOption(value: 'frosted', label: 'Frosted'), UiSegmentedOption(value: 'solid', label: 'Solid')],
                value: _glass?.name ?? 'solid',
                onChanged: (v) => setState(() => _glass = v == 'solid' ? null : UiGlassStrength.values.byName(v)),
              ),
              UiSegmented<bool>(
                label: 'Location (demo)',
                size: UiSize.sm,
                options: const [UiSegmentedOption(value: false, label: 'On'), UiSegmentedOption(value: true, label: 'Off')],
                value: _off,
                onChanged: (v) => setState(() => _off = v),
              ),
              UiSegmented<TextDirection>(
                label: 'Direction (demo)',
                size: UiSize.sm,
                options: const [UiSegmentedOption(value: TextDirection.ltr, label: 'LTR'), UiSegmentedOption(value: TextDirection.rtl, label: 'RTL')],
                value: _dir,
                onChanged: (v) => setState(() => _dir = v),
              ),
              UiButton(
                label: _searching ? 'Stop searching' : 'Find a nurse',
                block: true,
                variant: _searching ? UiButtonVariant.outline : UiButtonVariant.primary,
                onPressed: () => setState(() => _searching = !_searching),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
