import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as osm;

/// Coordonnées géographiques universelles (indépendantes du fournisseur).
class MapLatLng {
  final double latitude;
  final double longitude;

  const MapLatLng(this.latitude, this.longitude);

  /// Conversion vers le type Google Maps
  gmaps.LatLng toGoogle() => gmaps.LatLng(latitude, longitude);

  /// Conversion vers le type OpenStreetMap / LatLong2
  osm.LatLng toOsm() => osm.LatLng(latitude, longitude);

  /// Instanciation depuis Google Maps
  factory MapLatLng.fromGoogle(gmaps.LatLng point) =>
      MapLatLng(point.latitude, point.longitude);

  /// Instanciation depuis OSM
  factory MapLatLng.fromOsm(osm.LatLng point) =>
      MapLatLng(point.latitude, point.longitude);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapLatLng &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() => 'MapLatLng($latitude, $longitude)';
}

/// Suggestion d'adresse pour l'autocomplétion (Places / Photon).
class MapPlaceSuggestion {
  final String id;
  final String description;
  final String mainText;
  final String secondaryText;
  final double? latitude;
  final double? longitude;

  const MapPlaceSuggestion({
    required this.id,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    this.latitude,
    this.longitude,
  });

  @override
  String toString() => 'MapPlaceSuggestion($description, lat: $latitude, lng: $longitude)';
}

/// Détails complets d'un lieu résolu (adresse, coordonnées GPS).
class MapPlaceDetails {
  final String address;
  final double latitude;
  final double longitude;
  final String? displayName;

  const MapPlaceDetails({
    required this.address,
    required this.latitude,
    required this.longitude,
    this.displayName,
  });

  MapLatLng get position => MapLatLng(latitude, longitude);
}

/// Résultat d'itinéraire (Google Directions / OSRM).
class MapRouteResult {
  final double distanceMeters;
  final double durationSeconds;
  final List<MapLatLng> points;
  final String? polylineEncoded;
  final String? summary;
  final MapLatLng? northeast;
  final MapLatLng? southwest;

  const MapRouteResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
    this.polylineEncoded,
    this.summary,
    this.northeast,
    this.southwest,
  });

  /// Distance formatée en km (ex: "4.8 km" ou "850 m")
  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  /// Durée formatée en minutes (ex: "12 min")
  String get formattedDuration {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}min';
  }

  factory MapRouteResult.empty() => const MapRouteResult(
        distanceMeters: 0,
        durationSeconds: 0,
        points: [],
      );
}

/// Marqueur de carte unifié pour GoogleMap et FlutterMap.
class AppMapMarker {
  final String id;
  final MapLatLng position;
  final Widget? widget; // Rendu custom pour FlutterMap
  final gmaps.BitmapDescriptor? googleIcon; // Rendu pour GoogleMap
  final VoidCallback? onTap;
  final double width;
  final double height;
  final Alignment anchor;

  const AppMapMarker({
    required this.id,
    required this.position,
    this.widget,
    this.googleIcon,
    this.onTap,
    this.width = 40,
    this.height = 40,
    this.anchor = Alignment.center,
  });
}

/// Polyline de tracé de trajet unifiée.
class AppMapPolyline {
  final String id;
  final List<MapLatLng> points;
  final Color color;
  final int width;

  const AppMapPolyline({
    required this.id,
    required this.points,
    this.color = const Color(0xFFFB5B00),
    this.width = 5,
  });
}

/// Position et orientation de caméra unifiée.
class MapCameraPosition {
  final MapLatLng target;
  final double zoom;
  final double bearing;
  final double tilt;

  const MapCameraPosition({
    required this.target,
    this.zoom = 14.0,
    this.bearing = 0.0,
    this.tilt = 0.0,
  });
}
