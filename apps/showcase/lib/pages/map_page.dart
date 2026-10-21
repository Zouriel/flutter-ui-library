import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/map.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';

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
          summary: 'Markers are dots in their tone with a label pill; tapping one calls onMarkerSelected. center and zoom move the map; onCenterChanged reports where the person moved it. The zoom buttons sit at the inline start and the attribution at the inline end, so they swap in RTL. The controls use the theme, and on a dark theme the tiles are dimmed; under reduced motion there is no fling. Pass userAgentPackageName (your app id) for the OSM tile policy.',
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
  userAgentPackageName: 'mv.dhirumi.nurse',
)''',
          api: const [
            ApiRow('center / zoom', 'UiLatLng / double', 'Where it looks; changing them moves the map.', def: 'Malé / 13'),
            ApiRow('markers', 'List<UiMapMarker>', 'id, lat, lng, tone, label, semanticLabel (the id is never read out).'),
            ApiRow('onMarkerSelected / onCenterChanged', 'ValueChanged<UiMapMarker / UiMapView>?', 'A marker was tapped; the person moved the map.'),
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
            ApiRow('pinMode', 'bool', 'A tap on the map moves the pin.', def: 'false'),
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
          summary: 'locateControl adds a round Show my location button at the bottom-end corner of the visible part: it follows viewInsets, so on a map page it floats just above the bottom sheet and moves with it. It calls onLocate; the app finds the position itself, sets userLocation and moves the map with UiMapState.flyTo, which centres in the visible part. locating shows a spinner and ignores taps; locateOff shows the icon struck through with the tooltip Location is off, and a tap still calls onLocate so the app can ask again. userLocation draws the you-are-here dot, blue with a white ring, over a soft halo as wide as the accuracy in metres (28 to 240 px across), above the tiles and below markers and the pin, read out as Your location.',
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
          name: 'Map page',
          widget: 'UiMap fill · pulse · viewInsets',
          summary: 'A full-screen map with the form in a UiBottomSheet and a UiFloatingPanel status card at the top. fill gives square corners. pulse draws soft rings radiating from a point while the app searches (one still halo under reduced motion); they move with the map, sit under the markers and the pin, and say nothing to screen readers, so put the words in the status card. viewInsets is how much of each edge the sheet and the card cover, straight from their onCoverChanged: the map still draws edge to edge, but its centre, the pin\'s centre, onCenterChanged, the zoom buttons and the attribution use the part between them. When the sheet moves to another snap, the map pans so the point in the middle of the visible part stays in the middle of the new visible part.',
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
    onCoverChanged: (v) => setState(() => cardCover = v),
    child: Text(searching ? 'Looking for a nurse near you' : 'Where should the nurse come?'),
  ),
  UiBottomSheet(
    title: 'Find a nurse',
    snaps: const [0.42, 0.75],
    snap: snap,
    closable: false,
    maxWidth: 560, // tablets and desktops: 560 wide, centred
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
            ApiRow('UiBottomSheetState.persistent', 'bool', 'True when the smallest snap is above 0, as here: Back and Escape collapse it to that snap, and from there Back leaves the page.'),
          ],
        ),
      ],
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
