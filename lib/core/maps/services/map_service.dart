import 'package:seddo/core/maps/models/map_models.dart';
import 'package:seddo/core/maps/models/map_provider.dart';

/// Interface unifiée pour tous les services de cartographie (Google et OpenStreetMap).
/// Aucun écran n'appelle directement une API tierce : tous passent par cette abstraction.
abstract class MapService {
  /// Identifiant du fournisseur actif
  MapProvider get provider;

  /// Autocomplétion de recherche d'adresse
  Future<List<MapPlaceSuggestion>> autocomplete(
    String query, {
    MapLatLng? location,
    String? sessionToken,
  });

  /// Résolution d'adresse en coordonnées GPS
  Future<MapPlaceDetails?> geocode(String address);

  /// Géocodage inverse : coordonnées GPS en adresse textuelle
  Future<MapPlaceDetails?> reverseGeocode(double lat, double lng);

  /// Calcul d'itinéraire entre deux points (distance, durée, polyline)
  Future<MapRouteResult> getRoute(
    MapLatLng origin,
    MapLatLng destination,
  );
}

/// Exception levée spécifiquement en cas d'erreur de clé ou quota Google Maps
/// pour déclencher le Circuit Breaker vers OSM.
class GoogleMapApiKeyException implements Exception {
  final String status;
  final String message;
  final int? httpStatusCode;

  const GoogleMapApiKeyException({
    required this.status,
    required this.message,
    this.httpStatusCode,
  });

  @override
  String toString() => 'GoogleMapApiKeyException(status: $status, http: $httpStatusCode)';
}
