import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:seddo/core/utils/map_config.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';

class PlaceSuggestion {
  final String placeId;
  final String description;
  final String? mainText;
  final String? secondaryText;
  final double? latitude;
  final double? longitude;
  final String? distanceKm;

  PlaceSuggestion(
    this.placeId,
    this.description, {
    this.mainText,
    this.secondaryText,
    this.latitude,
    this.longitude,
    this.distanceKm,
  });
}

class PlaceDetails {
  final String address;
  final double lat;
  final double lng;

  PlaceDetails(this.address, this.lat, this.lng);
}

class PlacesService {
  final String _apiKey;
  final Dio _dio;
  final Future<LatLng?> Function()? _locationFetcher;
  String _sessionToken = const Uuid().v4();

  PlacesService([
    String? apiKey,
    Dio? dio,
    Future<LatLng?> Function()? locationFetcher,
  ])  : _apiKey = apiKey ??
            const String.fromEnvironment(
              'PLACES_API_KEY',
              defaultValue: MapConfig.googleMapsApiKeyAndroid,
            ),
        _dio = dio ?? Dio(),
        _locationFetcher = locationFetcher;

  /// Curated database of verified Dakar places for instant fallback & matching
  static final List<PlaceSuggestion> _dakarPresets = [
    PlaceSuggestion(
      'dakar_almadies',
      'Almadies, Ngor-Almadies, Dakar',
      mainText: 'Almadies',
      secondaryText: 'Ngor-Almadies, Dakar · 7,8 km',
      latitude: 14.7431,
      longitude: -17.5195,
      distanceKm: '7,8 km',
    ),
    PlaceSuggestion(
      'dakar_pointe_almadies',
      'Pointe des Almadies, Route des Almadies',
      mainText: 'Pointe des Almadies',
      secondaryText: 'Route des Almadies · 8,6 km',
      latitude: 14.7445,
      longitude: -17.5280,
      distanceKm: '8,6 km',
    ),
    PlaceSuggestion(
      'dakar_almadies_village',
      'Almadies Village, Route de Ngor',
      mainText: 'Almadies Village',
      secondaryText: 'Route de Ngor · 8,1 km',
      latitude: 14.7410,
      longitude: -17.5150,
      distanceKm: '8,1 km',
    ),
    PlaceSuggestion(
      'dakar_ouakam',
      'Ouakam, Dakar',
      mainText: 'Ouakam',
      secondaryText: 'Ouakam, Dakar · 5,2 km',
      latitude: 14.7231,
      longitude: -17.4912,
      distanceKm: '5,2 km',
    ),
    PlaceSuggestion(
      'dakar_ouest_foire',
      'Ouest Foire, Dakar',
      mainText: 'Ouest Foire',
      secondaryText: 'Ouest Foire, Dakar · 6,4 km',
      latitude: 14.7495,
      longitude: -17.4682,
      distanceKm: '6,4 km',
    ),
    PlaceSuggestion(
      'dakar_renaissance',
      'Monument de la Renaissance Africaine, Ouakam',
      mainText: 'Monument de la Renaissance Africaine',
      secondaryText: 'Ouakam, Dakar · 5,6 km',
      latitude: 14.7222,
      longitude: -17.4950,
      distanceKm: '5,6 km',
    ),
    PlaceSuggestion(
      'dakar_ngor',
      'Ngor, Dakar',
      mainText: 'Ngor',
      secondaryText: 'Ngor, Dakar · 7,5 km',
      latitude: 14.7547,
      longitude: -17.5142,
      distanceKm: '7,5 km',
    ),
    PlaceSuggestion(
      'dakar_plateau',
      'Dakar Plateau (Centre-ville)',
      mainText: 'Dakar Plateau',
      secondaryText: 'Centre-ville, Dakar · 2,1 km',
      latitude: 14.6720,
      longitude: -17.4330,
      distanceKm: '2,1 km',
    ),
    PlaceSuggestion(
      'dakar_point_e',
      'Point E, Dakar',
      mainText: 'Point E',
      secondaryText: 'Point E, Dakar · 3,4 km',
      latitude: 14.6974,
      longitude: -17.4618,
      distanceKm: '3,4 km',
    ),
    PlaceSuggestion(
      'dakar_mermoz',
      'Mermoz, Dakar',
      mainText: 'Mermoz',
      secondaryText: 'Mermoz, Dakar · 4,2 km',
      latitude: 14.7100,
      longitude: -17.4720,
      distanceKm: '4,2 km',
    ),
    PlaceSuggestion(
      'dakar_yoff',
      'Yoff, Dakar',
      mainText: 'Yoff',
      secondaryText: 'Yoff, Dakar · 7,0 km',
      latitude: 14.7600,
      longitude: -17.4670,
      distanceKm: '7,0 km',
    ),
    PlaceSuggestion(
      'dakar_sea_plaza',
      'Centre Commercial Sea Plaza, Corniche Ouest',
      mainText: 'Sea Plaza',
      secondaryText: 'Corniche Ouest, Fann Dakar · 3,8 km',
      latitude: 14.6980,
      longitude: -17.4740,
      distanceKm: '3,8 km',
    ),
    PlaceSuggestion(
      'dakar_aibd',
      'Aéroport International Blaise Diagne (AIBD)',
      mainText: 'Aéroport AIBD',
      secondaryText: 'Diass / Dakar · 45 km',
      latitude: 14.6710,
      longitude: -17.0730,
      distanceKm: '45 km',
    ),
  ];

  Future<List<PlaceSuggestion>> autocomplete(String input) async {
    final query = input.trim();
    if (query.isEmpty) {
      return _dakarPresets.take(5).toList();
    }

    try {
      final res = await _dio.post(
        'https://places.googleapis.com/v1/places:autocomplete',
        options: Options(
          headers: {
            'X-Goog-Api-Key': _apiKey,
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
        data: {
          'input': query,
          'sessionToken': _sessionToken,
          'languageCode': 'fr',
          'includedRegionCodes': ['sn'],
          'locationBias': {
            'circle': {
              'center': {
                'latitude': MapConfig.dakarCenterLat,
                'longitude': MapConfig.dakarCenterLng,
              },
              'radius': MapConfig.dakarSearchRadiusMeters.toDouble(),
            }
          },
        },
      );

      final suggestions = (res.data['suggestions'] as List?) ?? [];
      final apiResults = suggestions
          .where((s) => s['placePrediction'] != null)
          .map((s) {
            final pred = s['placePrediction'];
            final fullText = pred['text']?['text'] ?? '';
            final structured = pred['structuredFormat'];
            final main = structured?['mainText']?['text'] ?? fullText;
            final secondary = structured?['secondaryText']?['text'] ?? 'Dakar, Sénégal';

            return PlaceSuggestion(
              pred['placeId'] ?? '',
              fullText,
              mainText: main,
              secondaryText: secondary,
            );
          })
          .toList();

      if (apiResults.isNotEmpty) {
        return apiResults;
      }
    } catch (_) {
      // Graceful fallback to local Dakar matching
    }

    // Local matching with prefix scoring (exact prefix 'o' -> 'Ouakam', 'almad' -> 'Almadies')
    return _filterDakarLocally(query);
  }

  List<PlaceSuggestion> _filterDakarLocally(String query) {
    final clean = query.toLowerCase();
    final scored = <MapEntry<int, PlaceSuggestion>>[];

    for (final item in _dakarPresets) {
      final main = (item.mainText ?? item.description).toLowerCase();
      final full = item.description.toLowerCase();

      int score = 0;
      if (main.startsWith(clean)) {
        score = 100;
      } else if (main.split(RegExp(r'\s+|[,\-]')).any((w) => w.startsWith(clean))) {
        score = 80;
      } else if (main.contains(clean)) {
        score = 50;
      } else if (full.contains(clean)) {
        score = 30;
      }

      if (score > 0) {
        scored.add(MapEntry(score, item));
      }
    }

    scored.sort((a, b) => b.key.compareTo(a.key));
    return scored.map((e) => e.value).toList();
  }

  Future<PlaceDetails> details(String placeId) async {
    // Check local presets first
    final localMatch = _dakarPresets.where((p) => p.placeId == placeId);
    if (localMatch.isNotEmpty &&
        localMatch.first.latitude != null &&
        localMatch.first.longitude != null) {
      _sessionToken = const Uuid().v4();
      return PlaceDetails(
        localMatch.first.description,
        localMatch.first.latitude!,
        localMatch.first.longitude!,
      );
    }

    try {
      final res = await _dio.get(
        'https://places.googleapis.com/v1/places/$placeId',
        options: Options(
          headers: {
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask': 'formattedAddress,location',
          },
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
        queryParameters: {'sessionToken': _sessionToken},
      );

      _sessionToken = const Uuid().v4(); // nouvelle session après la sélection
      return PlaceDetails(
        res.data['formattedAddress'] ?? '',
        (res.data['location']['latitude'] as num).toDouble(),
        (res.data['location']['longitude'] as num).toDouble(),
      );
    } catch (_) {
      _sessionToken = const Uuid().v4();
      return PlaceDetails(
        'Dakar, Sénégal',
        MapConfig.dakarCenterLat,
        MapConfig.dakarCenterLng,
      );
    }
  }

  /// Reverse geocode coordinates (lat, lng) to a clean human-readable address in any country
  Future<PlaceSearchResult> reverseGeocode(double lat, double lng) async {
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '$lat,$lng',
          'key': _apiKey,
          'language': 'fr',
        },
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      final results = (res.data['results'] as List?) ?? [];
      if (results.isNotEmpty) {
        // 1. Look for a result with real street/neighborhood/city/country components
        for (final item in results) {
          final components = (item['address_components'] as List?) ?? [];
          String? streetNumber;
          String? route;
          String? sublocality;
          String? locality;
          String? adminArea;
          String? country;

          for (final c in components) {
            final types = (c['types'] as List?) ?? [];
            if (types.contains('street_number')) {
              streetNumber = c['long_name'];
            } else if (types.contains('route')) {
              route = c['long_name'];
            } else if (types.contains('sublocality') ||
                types.contains('sublocality_level_1') ||
                types.contains('neighborhood')) {
              sublocality = c['long_name'];
            } else if (types.contains('locality') ||
                types.contains('postal_town')) {
              locality = c['long_name'];
            } else if (types.contains('administrative_area_level_1')) {
              adminArea = c['long_name'];
            } else if (types.contains('country')) {
              country = c['long_name'];
            }
          }

          final isUnnamedRoad = route != null &&
              (route.toLowerCase().contains('route sans nom') ||
                  route.toLowerCase().contains('unnamed road'));

          // Build clean, human-friendly mainText
          String? main;
          if (route != null && !isUnnamedRoad) {
            main = streetNumber != null ? '$streetNumber $route' : route;
            if (sublocality != null && !main.contains(sublocality)) {
              main = '$main, $sublocality';
            }
          } else {
            // When on an unnamed road or no named street, use neighborhood, locality, or admin area
            main = sublocality ?? locality ?? adminArea;
          }

          if (main != null && main.isNotEmpty) {
            // Build real country-aware secondaryText
            final city = locality ?? adminArea ?? sublocality;
            String secondary;
            if (city != null && country != null) {
              secondary = city != country ? '$city, $country' : country;
            } else if (country != null) {
              secondary = country;
            } else if (city != null) {
              secondary = city;
            } else {
              secondary = '';
            }

            final formatted = item['formatted_address'] as String? ??
                (secondary.isNotEmpty ? '$main, $secondary' : main);

            return PlaceSearchResult(
              id: 'geo_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}',
              mainText: _cleanAddress(main),
              secondaryText: _cleanAddress(
                secondary.isNotEmpty ? secondary : _cleanAddress(formatted),
              ),
              fullAddress: _cleanAddress(formatted),
              latitude: lat,
              longitude: lng,
            );
          }
        }

        // 2. Fallback to first result formatted address stripped of Plus Codes
        final rawFormatted =
            results.first['formatted_address'] as String? ?? '';
        final cleaned = _cleanAddress(rawFormatted);
        final parts = cleaned.split(',');
        final main = parts.first.trim();
        final secondary = parts.length > 1
            ? parts.sublist(1).join(',').trim()
            : cleaned;

        return PlaceSearchResult(
          id: 'geo_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}',
          mainText: main.isNotEmpty ? main : 'Position sélectionnée',
          secondaryText: secondary.isNotEmpty ? secondary : '',
          fullAddress: cleaned.isNotEmpty
              ? cleaned
              : '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
          latitude: lat,
          longitude: lng,
        );
      }
    } catch (_) {
      // Graceful fallback
    }

    return _findNearestDakarPreset(lat, lng);
  }

  static String _cleanAddress(String input) {
    return input
        .replaceFirst(RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,4}[,\s]*'), '')
        .trim();
  }

  PlaceSearchResult _findNearestDakarPreset(double lat, double lng) {
    PlaceSuggestion? best;
    double minDistance = double.infinity;

    for (final item in _dakarPresets) {
      if (item.latitude != null && item.longitude != null) {
        final dLat = lat - item.latitude!;
        final dLng = lng - item.longitude!;
        final distSq = (dLat * dLat) + (dLng * dLng);
        if (distSq < minDistance) {
          minDistance = distSq;
          best = item;
        }
      }
    }

    // Only use local Dakar preset if within ~60km (distSq < 0.3)
    if (best != null && minDistance < 0.3) {
      return PlaceSearchResult(
        id: best.placeId,
        mainText: best.mainText ?? best.description,
        secondaryText: best.secondaryText ?? 'Dakar, Sénégal',
        fullAddress: best.description,
        latitude: lat,
        longitude: lng,
      );
    }

    // If outside Dakar or in another country (e.g. Guinée)
    return PlaceSearchResult(
      id: 'custom_pin_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}',
      mainText: 'Position sur la carte',
      secondaryText: '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
      fullAddress: '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
      latitude: lat,
      longitude: lng,
    );
  }


  /// Attempts to fetch the current user GPS coordinates
  Future<LatLng?> getCurrentCoordinates() async {
    if (_locationFetcher != null) {
      return await _locationFetcher();
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return LatLng(lastKnown.latitude, lastKnown.longitude);
        }
      } catch (_) {}
      return null;
    }
  }

  /// Resolves the current user location to a real physical PlaceSearchResult address in Dakar
  Future<PlaceSearchResult?> getCurrentPlace({LatLng? fallbackLocation}) async {
    final location = await getCurrentCoordinates() ?? fallbackLocation;
    if (location == null) return null;
    return await reverseGeocode(location.latitude, location.longitude);
  }
}


