import 'dart:async';
import 'package:dio/dio.dart';
import 'package:seddo/core/maps/models/map_models.dart';
import 'package:seddo/core/maps/models/map_provider.dart';
import 'package:seddo/core/maps/services/map_service.dart';

/// Implémentation OpenStreetMap 100 % gratuite :
/// - OSRM pour le calcul d'itinéraires (trajet, polylines, durée)
/// - Nominatim pour le géocodage et reverse-géocodage (avec User-Agent & débit 1 req/s)
/// - Photon (Komoot) pour l'autocomplétion rapide d'adresses
class OsmMapService implements MapService {
  final String osrmBaseUrl;
  final String nominatimBaseUrl;
  final String photonBaseUrl;
  final String userAgent;
  final Dio _dio;

  /// Horodatage de la dernière requête Nominatim pour respecter la politique de 1 req/s
  static DateTime _lastNominatimCall = DateTime.fromMillisecondsSinceEpoch(0);

  OsmMapService({
    this.osrmBaseUrl = 'https://router.project-osrm.org',
    this.nominatimBaseUrl = 'https://nominatim.openstreetmap.org',
    this.photonBaseUrl = 'https://photon.komoot.io',
    this.userAgent = 'Seddo-VTC-App/1.0 (contact@innov.sn; mobile-app)',
    Dio? dio,
  }) : _dio = dio ?? Dio();

  @override
  MapProvider get provider => MapProvider.osm;

  /// Respect strict de la règle Nominatim : maximum 1 requête par seconde.
  Future<void> _throttleNominatim() async {
    final now = DateTime.now();
    final elapsed = now.difference(_lastNominatimCall).inMilliseconds;
    if (elapsed < 1050) {
      final waitMs = 1050 - elapsed;
      await Future.delayed(Duration(milliseconds: waitMs));
    }
    _lastNominatimCall = DateTime.now();
  }

  @override
  Future<List<MapPlaceSuggestion>> autocomplete(
    String query, {
    MapLatLng? location,
    String? sessionToken,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // 1. Essayer d'abord avec Photon (Komoot) : réponse ultra-rapide optimisée pour l'autocomplétion
    try {
      final queryParams = <String, dynamic>{
        'q': cleanQuery,
        'limit': 10,
        'lang': 'fr',
      };

      if (location != null) {
        queryParams['lat'] = location.latitude;
        queryParams['lon'] = location.longitude;
      } else {
        // Dakar par défaut
        queryParams['lat'] = 14.7167;
        queryParams['lon'] = -17.4677;
      }

      final response = await _dio.get(
        '$photonBaseUrl/api/',
        queryParameters: queryParams,
        options: Options(
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 4),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final features = (response.data['features'] as List?) ?? [];
        if (features.isNotEmpty) {
          return features.map((f) {
            final props = (f['properties'] as Map<String, dynamic>?) ?? {};
            final geometry = (f['geometry'] as Map<String, dynamic>?) ?? {};
            final coords = (geometry['coordinates'] as List?) ?? [];

            final name = props['name'] as String? ?? '';
            final street = props['street'] as String? ?? '';
            final city = props['city'] as String? ?? props['county'] as String? ?? props['state'] as String? ?? 'Sénégal';
            final country = props['country'] as String? ?? '';

            final mainText = name.isNotEmpty ? name : street;
            final secondaryParts = [street != name ? street : '', city, country].where((s) => s.isNotEmpty).toList();
            final secondaryText = secondaryParts.join(', ');
            final description = mainText.isNotEmpty
                ? (secondaryText.isNotEmpty ? '$mainText, $secondaryText' : mainText)
                : secondaryText;

            final lng = coords.isNotEmpty ? (coords[0] as num).toDouble() : null;
            final lat = coords.length > 1 ? (coords[1] as num).toDouble() : null;

            return MapPlaceSuggestion(
              id: 'photon_${props['osm_id'] ?? props['osm_value'] ?? description}',
              description: description,
              mainText: mainText.isNotEmpty ? mainText : description,
              secondaryText: secondaryText,
              latitude: lat,
              longitude: lng,
            );
          }).toList();
        }
      }
    } catch (_) {
      // Si Photon échoue, basculer sur Nominatim
    }

    // 2. Fallback Nominatim Search
    try {
      await _throttleNominatim();
      final response = await _dio.get(
        '$nominatimBaseUrl/search',
        queryParameters: {
          'q': cleanQuery,
          'format': 'json',
          'addressdetails': 1,
          'limit': 8,
          'countrycodes': 'sn',
        },
        options: Options(
          headers: {'User-Agent': userAgent},
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 4),
        ),
      );

      if (response.statusCode == 200 && response.data is List) {
        final list = response.data as List;
        return list.map((item) {
          final m = item as Map<String, dynamic>;
          final displayName = m['display_name'] as String? ?? cleanQuery;
          final parts = displayName.split(',');
          final main = parts.first.trim();
          final secondary = parts.skip(1).join(',').trim();

          return MapPlaceSuggestion(
            id: 'nom_${m['place_id'] ?? displayName}',
            description: displayName,
            mainText: main,
            secondaryText: secondary,
            latitude: double.tryParse(m['lat']?.toString() ?? ''),
            longitude: double.tryParse(m['lon']?.toString() ?? ''),
          );
        }).toList();
      }
    } catch (_) {}

    return [];
  }

  @override
  Future<MapPlaceDetails?> geocode(String address) async {
    try {
      await _throttleNominatim();
      final response = await _dio.get(
        '$nominatimBaseUrl/search',
        queryParameters: {
          'q': address,
          'format': 'json',
          'limit': 1,
          'countrycodes': 'sn',
        },
        options: Options(
          headers: {'User-Agent': userAgent},
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 4),
        ),
      );

      if (response.statusCode == 200 && response.data is List) {
        final list = response.data as List;
        if (list.isNotEmpty) {
          final first = list.first as Map<String, dynamic>;
          final lat = double.tryParse(first['lat']?.toString() ?? '') ?? 0.0;
          final lon = double.tryParse(first['lon']?.toString() ?? '') ?? 0.0;
          return MapPlaceDetails(
            address: first['display_name'] as String? ?? address,
            latitude: lat,
            longitude: lon,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<MapPlaceDetails?> reverseGeocode(double lat, double lng) async {
    try {
      await _throttleNominatim();
      final response = await _dio.get(
        '$nominatimBaseUrl/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'json',
        },
        options: Options(
          headers: {'User-Agent': userAgent},
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 4),
        ),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        return MapPlaceDetails(
          address: data['display_name'] as String? ?? '$lat, $lng',
          latitude: lat,
          longitude: lng,
        );
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<MapRouteResult> getRoute(MapLatLng origin, MapLatLng destination) async {
    try {
      // OSRM: coordinates are in {longitude},{latitude}
      final coords = '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
      final url = '$osrmBaseUrl/route/v1/driving/$coords?overview=full&geometries=geojson';

      final response = await _dio.get(
        url,
        options: Options(
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 6),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final routes = (response.data['routes'] as List?) ?? [];
        if (routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0.0;
          final durationSeconds = (route['duration'] as num?)?.toDouble() ?? 0.0;

          final geometry = route['geometry'] as Map<String, dynamic>?;
          final coordsList = (geometry?['coordinates'] as List?) ?? [];

          final points = coordsList.map((c) {
            final pair = c as List;
            final lng = (pair[0] as num).toDouble();
            final lat = (pair[1] as num).toDouble();
            return MapLatLng(lat, lng);
          }).toList();

          return MapRouteResult(
            distanceMeters: distanceMeters,
            durationSeconds: durationSeconds,
            points: points,
            summary: 'Trajet via OpenStreetMap',
          );
        }
      }
    } catch (_) {}

    // Trajet direct par défaut si OSRM est temporairement inaccessible
    return MapRouteResult(
      distanceMeters: 0,
      durationSeconds: 0,
      points: [origin, destination],
    );
  }
}
