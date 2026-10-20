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
            ApiRow('markers', 'List<UiMapMarker>', 'id, lat, lng, tone, label.'),
            ApiRow('onMarkerSelected / onCenterChanged', 'ValueChanged<UiMapMarker / UiMapView>?', 'A marker was tapped; the person moved the map.'),
            ApiRow('tileUrl / attribution / onAttributionTap', 'String / String / VoidCallback?', 'Tiles (OSM by default) and their credit.'),
            ApiRow('userAgentPackageName', 'String', 'Sent with tile requests.', def: "'com.zouriel.ui'"),
            ApiRow('tileProvider', 'TileProvider?', 'Offline or test tiles.'),
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
          ],
        ),
      ],
    );
  }
}
