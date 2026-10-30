import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Service centralisé pour charger et appliquer le style personnalisé de Google Maps.
/// Style doux, épuré, aux teintes chaudes et pastel, en accord avec l'identité de marque Seddo.
class MapStyleService {
  MapStyleService._();

  static const String assetPath = 'assets/map_style.json';

  /// Style par défaut intégré de secours (garantit la disponibilité synchrone immédiate)
  static const String defaultMapStyle = '''[
  { "elementType": "geometry", "stylers": [{ "color": "#F6F3EE" }] },
  { "elementType": "labels.text.fill", "stylers": [{ "color": "#6B635B" }] },
  { "elementType": "labels.text.stroke", "stylers": [{ "color": "#FFFFFF" }, { "weight": 3 }] },

  { "featureType": "administrative", "elementType": "geometry.stroke", "stylers": [{ "color": "#E0D9CE" }, { "weight": 1 }] },
  { "featureType": "administrative.land_parcel", "elementType": "geometry", "stylers": [{ "color": "#F6F3EE" }] },
  { "featureType": "administrative.land_parcel", "elementType": "geometry.fill", "stylers": [{ "color": "#F6F3EE" }] },
  { "featureType": "administrative.land_parcel", "elementType": "geometry.stroke", "stylers": [{ "color": "#EFEAE1" }] },
  { "featureType": "administrative.neighborhood", "elementType": "labels.text.fill", "stylers": [{ "color": "#8C8377" }] },
  { "featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{ "color": "#423B33" }] },

  { "featureType": "landscape", "elementType": "geometry", "stylers": [{ "color": "#F6F3EE" }] },
  { "featureType": "landscape.man_made", "elementType": "geometry", "stylers": [{ "color": "#F2ECE3" }] },
  { "featureType": "landscape.man_made", "elementType": "geometry.fill", "stylers": [{ "color": "#F2ECE3" }] },
  { "featureType": "landscape.man_made", "elementType": "geometry.stroke", "stylers": [{ "color": "#E8E2D7" }, { "weight": 0.5 }] },
  { "featureType": "landscape.natural", "elementType": "geometry", "stylers": [{ "color": "#F6F3EE" }] },
  { "featureType": "landscape.natural.landcover", "elementType": "geometry", "stylers": [{ "color": "#F6F3EE" }] },
  { "featureType": "landscape.natural.terrain", "elementType": "geometry", "stylers": [{ "color": "#F6F3EE" }] },

  { "featureType": "poi", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi", "elementType": "geometry", "stylers": [{ "color": "#F0EAE1" }] },
  { "featureType": "poi", "elementType": "geometry.fill", "stylers": [{ "color": "#F0EAE1" }] },
  { "featureType": "poi", "elementType": "labels.text.fill", "stylers": [{ "color": "#6B635B" }] },
  { "featureType": "poi", "elementType": "labels.text.stroke", "stylers": [{ "color": "#FFFFFF" }, { "weight": 2.5 }] },
  { "featureType": "poi", "elementType": "labels.icon", "stylers": [{ "visibility": "on" }] },

  { "featureType": "poi.medical", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.medical", "elementType": "geometry", "stylers": [{ "color": "#FBEAEA" }] },
  { "featureType": "poi.medical", "elementType": "labels.icon", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.medical", "elementType": "labels.text.fill", "stylers": [{ "color": "#B83A3A" }] },

  { "featureType": "poi.business", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.business", "elementType": "geometry", "stylers": [{ "color": "#F3ECE3" }] },
  { "featureType": "poi.business", "elementType": "labels.icon", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.business", "elementType": "labels.text.fill", "stylers": [{ "color": "#685E53" }] },

  { "featureType": "poi.park", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.park", "elementType": "geometry", "stylers": [{ "color": "#DDEBD3" }] },
  { "featureType": "poi.park", "elementType": "geometry.fill", "stylers": [{ "color": "#DDEBD3" }] },
  { "featureType": "poi.park", "elementType": "labels.icon", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{ "color": "#527546" }] },

  { "featureType": "poi.place_of_worship", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.place_of_worship", "elementType": "geometry", "stylers": [{ "color": "#F0EAE1" }] },
  { "featureType": "poi.place_of_worship", "elementType": "labels.icon", "stylers": [{ "visibility": "on" }] },

  { "featureType": "poi.school", "stylers": [{ "visibility": "on" }] },
  { "featureType": "poi.school", "elementType": "geometry", "stylers": [{ "color": "#ECE7DF" }] },
  { "featureType": "poi.school", "elementType": "labels.icon", "stylers": [{ "visibility": "on" }] },

  { "featureType": "transit", "stylers": [{ "visibility": "on" }] },
  { "featureType": "transit", "elementType": "geometry", "stylers": [{ "color": "#F6F3EE" }] },
  { "featureType": "transit.station", "stylers": [{ "visibility": "on" }] },
  { "featureType": "transit.station", "elementType": "labels.icon", "stylers": [{ "visibility": "on" }] },

  { "featureType": "road", "elementType": "geometry.fill", "stylers": [{ "color": "#FFFFFF" }] },
  { "featureType": "road", "elementType": "geometry.stroke", "stylers": [{ "color": "#EAE4DA" }, { "weight": 1 }] },
  { "featureType": "road", "elementType": "labels.text.fill", "stylers": [{ "color": "#8C8377" }] },
  { "featureType": "road", "elementType": "labels.text.stroke", "stylers": [{ "color": "#FFFFFF" }, { "weight": 2 }] },
  { "featureType": "road.local", "elementType": "geometry.fill", "stylers": [{ "color": "#FFFFFF" }] },
  { "featureType": "road.local", "elementType": "geometry.stroke", "stylers": [{ "color": "#EAE4DA" }] },
  { "featureType": "road.arterial", "elementType": "geometry.fill", "stylers": [{ "color": "#FFFFFF" }] },
  { "featureType": "road.arterial", "elementType": "geometry.stroke", "stylers": [{ "color": "#EAE4DA" }] },
  { "featureType": "road.highway", "elementType": "geometry.fill", "stylers": [{ "color": "#FFD9B8" }] },
  { "featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{ "color": "#FFB27A" }] },

  { "featureType": "water", "elementType": "geometry", "stylers": [{ "color": "#CFE8F3" }] },
  { "featureType": "water", "elementType": "geometry.fill", "stylers": [{ "color": "#CFE8F3" }] },
  { "featureType": "water", "elementType": "labels.text.fill", "stylers": [{ "color": "#8FB8C9" }] }
]''';

  static String _cachedStyle = defaultMapStyle;

  /// Obtient la chaîne JSON du style de la carte Seddo.
  static String get style => _cachedStyle;

  /// Charge de manière asynchrone le style depuis [assets/map_style.json].
  static Future<String> loadMapStyle() async {
    try {
      final loaded = await rootBundle.loadString(assetPath);
      if (loaded.trim().isNotEmpty) {
        _cachedStyle = loaded;
      }
    } catch (e) {
      debugPrint('[MapStyleService] Note: chargement depuis asset échoué ($e), fallback utilisé.');
    }
    return _cachedStyle;
  }

  /// Applique le style au contrôleur de carte Google Maps.
  static void applyStyle(GoogleMapController? controller) {
    if (controller != null && _cachedStyle.isNotEmpty) {
      try {
        // ignore: deprecated_member_use
        controller.setMapStyle(_cachedStyle);
      } catch (e) {
        debugPrint('[MapStyleService] Erreur lors de l’application du style: $e');
      }
    }
  }
}
