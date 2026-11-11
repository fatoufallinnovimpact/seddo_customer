import 'package:dio/dio.dart';
import 'package:seddo/core/maps/models/map_models.dart';
import 'package:seddo/core/maps/models/map_provider.dart';
import 'package:seddo/core/maps/services/map_service.dart';

/// Implémentation Google Maps REST avec gestion stricte des erreurs de clé/quota.
class GoogleMapService implements MapService {
  final String apiKey;
  final Dio _dio;

  GoogleMapService({
    required this.apiKey,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  @override
  MapProvider get provider => MapProvider.google;

  void _validateGoogleStatus(dynamic data, {int? httpCode}) {
    if (data is Map<String, dynamic>) {
      final status = data['status'] as String? ?? '';
      final errorMsg = data['error_message'] as String? ?? '';

      if (status == 'REQUEST_DENIED' ||
          status == 'OVER_QUERY_LIMIT' ||
          status == 'API_KEY_INVALID' ||
          errorMsg.toLowerCase().contains('api key') ||
          httpCode == 403) {
        throw GoogleMapApiKeyException(
          status: status.isEmpty ? 'HTTP_403' : status,
          message: errorMsg.isNotEmpty ? errorMsg : 'Google Maps access denied or quota exceeded',
          httpStatusCode: httpCode,
        );
      }
    }
  }

  @override
  Future<List<MapPlaceSuggestion>> autocomplete(
    String query, {
    MapLatLng? location,
    String? sessionToken,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _dio.post(
        'https://places.googleapis.com/v1/places:autocomplete',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
          },
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 4),
        ),
        data: {
          'input': query,
          'sessionToken': ?sessionToken,
          'languageCode': 'fr',
          'includedRegionCodes': ['sn'],
          if (location != null)
            'locationBias': {
              'circle': {
                'center': {
                  'latitude': location.latitude,
                  'longitude': location.longitude,
                },
                'radius': 45000.0,
              }
            },
        },
      );

      final suggestions = (response.data['suggestions'] as List?) ?? [];
      return suggestions.where((s) => s['placePrediction'] != null).map((s) {
        final pred = s['placePrediction'] as Map<String, dynamic>;
        final fullText = pred['text']?['text'] as String? ?? '';
        final struct = pred['structuredFormat'] as Map<String, dynamic>?;
        final main = struct?['mainText']?['text'] as String? ?? fullText;
        final secondary = struct?['secondaryText']?['text'] as String? ?? 'Dakar, Sénégal';

        return MapPlaceSuggestion(
          id: pred['placeId'] as String? ?? '',
          description: fullText.isNotEmpty ? fullText : main,
          mainText: main,
          secondaryText: secondary,
        );
      }).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw GoogleMapApiKeyException(
          status: 'HTTP_403',
          message: 'Google Maps Places API returned 403 Forbidden',
          httpStatusCode: 403,
        );
      }
      rethrow;
    }
  }

  @override
  Future<MapPlaceDetails?> geocode(String address) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'address': address,
          'key': apiKey,
          'language': 'fr',
          'components': 'country:sn',
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 4),
        ),
      );

      _validateGoogleStatus(response.data, httpCode: response.statusCode);

      final results = (response.data['results'] as List?) ?? [];
      if (results.isEmpty) return null;

      final first = results.first as Map<String, dynamic>;
      final geometry = first['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;

      return MapPlaceDetails(
        address: first['formatted_address'] as String? ?? address,
        latitude: (location?['lat'] as num?)?.toDouble() ?? 0.0,
        longitude: (location?['lng'] as num?)?.toDouble() ?? 0.0,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw GoogleMapApiKeyException(
          status: 'HTTP_403',
          message: 'Google Geocode 403 Forbidden',
          httpStatusCode: 403,
        );
      }
      rethrow;
    }
  }

  @override
  Future<MapPlaceDetails?> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '$lat,$lng',
          'key': apiKey,
          'language': 'fr',
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 4),
        ),
      );

      _validateGoogleStatus(response.data, httpCode: response.statusCode);

      final results = (response.data['results'] as List?) ?? [];
      if (results.isEmpty) return null;

      final first = results.first as Map<String, dynamic>;
      return MapPlaceDetails(
        address: first['formatted_address'] as String? ?? '$lat, $lng',
        latitude: lat,
        longitude: lng,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw GoogleMapApiKeyException(
          status: 'HTTP_403',
          message: 'Google Reverse Geocode 403 Forbidden',
          httpStatusCode: 403,
        );
      }
      rethrow;
    }
  }

  @override
  Future<MapRouteResult> getRoute(MapLatLng origin, MapLatLng destination) async {
    try {
      final response = await _dio.post(
        'https://routes.googleapis.com/directions/v2:computeRoutes',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask':
                'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
          },
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 6),
        ),
        data: {
          'origin': {
            'location': {
              'latLng': {
                'latitude': origin.latitude,
                'longitude': origin.longitude,
              }
            }
          },
          'destination': {
            'location': {
              'latLng': {
                'latitude': destination.latitude,
                'longitude': destination.longitude,
              }
            }
          },
          'travelMode': 'DRIVE',
        },
      );

      final routes = (response.data['routes'] as List?) ?? [];
      if (routes.isEmpty) return MapRouteResult.empty();

      final firstRoute = routes.first as Map<String, dynamic>;
      final distanceMeters = (firstRoute['distanceMeters'] as num?)?.toDouble() ?? 0.0;
      final durationStr = firstRoute['duration'] as String? ?? '0s';
      final durationSeconds = double.tryParse(durationStr.replaceAll('s', '')) ?? 0.0;
      final overviewPolyline = firstRoute['polyline']?['encodedPolyline'] as String? ?? '';

      final points = _decodePolyline(overviewPolyline);

      return MapRouteResult(
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        points: points,
        polylineEncoded: overviewPolyline,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw GoogleMapApiKeyException(
          status: 'HTTP_403',
          message: 'Google Routes API 403 Forbidden',
          httpStatusCode: 403,
        );
      }
      rethrow;
    }
  }

  /// Décodage de la polyline encodée Google Maps en coordonnées GPS.
  List<MapLatLng> _decodePolyline(String encoded) {
    final List<MapLatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(MapLatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }
}
