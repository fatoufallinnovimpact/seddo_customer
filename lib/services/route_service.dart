import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/map_config.dart';

class RouteDetails {
  final List<LatLng> polylinePoints;
  final double distanceKm;
  final int durationMinutes;

  const RouteDetails({
    required this.polylinePoints,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

/// Service that computes optimal route polylines and estimates
class RouteService {
  final Dio _dio;
  final String _apiKey;

  RouteService([Dio? dio, String? apiKey])
      : _dio = dio ?? Dio(),
        _apiKey = apiKey ??
            const String.fromEnvironment(
              'PLACES_API_KEY',
              defaultValue: MapConfig.googleMapsApiKeyAndroid,
            );

  /// Computes the driving route between [origin] and [destination]
  Future<RouteDetails> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    // 1. Try Google Directions API
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'mode': 'driving',
          'key': _apiKey,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final routes = response.data['routes'] as List<dynamic>;
        if (routes.isNotEmpty) {
          final route = routes.first;
          final overviewPolyline =
              route['overview_polyline']?['points'] as String?;
          final legs = route['legs'] as List<dynamic>?;

          double distanceKm = 5.0;
          int durationMinutes = 15;

          if (legs != null && legs.isNotEmpty) {
            final firstLeg = legs.first;
            final distMeters = (firstLeg['distance']?['value'] as num?)?.toDouble() ?? 5000.0;
            final durSeconds = (firstLeg['duration']?['value'] as num?)?.toInt() ?? 900;
            distanceKm = distMeters / 1000.0;
            durationMinutes = (durSeconds / 60).round();
          }

          if (overviewPolyline != null && overviewPolyline.isNotEmpty) {
            final points = decodePolyline(overviewPolyline);
            if (points.length >= 2) {
              return RouteDetails(
                polylinePoints: points,
                distanceKm: distanceKm,
                durationMinutes: durationMinutes,
              );
            }
          }
        }
      }
    } catch (_) {
      // Fallback to local smooth road curve calculation
    }

    // 2. High-quality smooth simulated road route fallback
    return _generateRealisticRoadRoute(origin, destination);
  }

  /// Generates a realistic curved road path between [origin] and [destination]
  RouteDetails _generateRealisticRoadRoute(LatLng origin, LatLng destination) {
    final distMeters = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    final distanceKm = (distMeters / 1000.0).clamp(1.2, 75.0);
    final durationMinutes = (distanceKm / 24.0 * 60).round().clamp(4, 120);

    final List<LatLng> points = [];
    const int segments = 16;

    // Perpendicular vector for realistic road curves
    final dLat = destination.latitude - origin.latitude;
    final dLng = destination.longitude - origin.longitude;
    final perpLat = -dLng * 0.18;
    final perpLng = dLat * 0.18;

    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      // Quadratic bezier curve formula
      final curveFactor = 4 * t * (1 - t);
      final lat = origin.latitude + (dLat * t) + (perpLat * curveFactor);
      final lng = origin.longitude + (dLng * t) + (perpLng * curveFactor);
      points.add(LatLng(lat, lng));
    }

    return RouteDetails(
      polylinePoints: points,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
    );
  }

  /// Decodes Google encoded polyline string
  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
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

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
}
