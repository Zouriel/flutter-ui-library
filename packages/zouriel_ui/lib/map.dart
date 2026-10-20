/// `ui-map` for Flutter: an OpenStreetMap map with markers and a draggable pin, on flutter_map.
/// Its own library, so apps that don't import it don't build it in.
library;

export 'package:flutter_map/flutter_map.dart' show MapController, NetworkTileProvider, TileCoordinates, TileLayer, TileProvider;
export 'src/map/map.dart';
