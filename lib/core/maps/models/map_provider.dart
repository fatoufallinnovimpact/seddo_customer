/// Fournisseurs de cartographie supportés par Seddo VTC.
enum MapProvider {
  /// Google Maps Platform (GoogleMap natif, Places, Geocoding, Directions API).
  google,

  /// OpenStreetMap / Repli gratuit (FlutterMap, Photon, Nominatim, OSRM).
  osm,
}

extension MapProviderExtension on MapProvider {
  bool get isGoogle => this == MapProvider.google;
  bool get isOsm => this == MapProvider.osm;

  String get displayName => isGoogle ? 'Google Maps' : 'OpenStreetMap (Secours)';
}
