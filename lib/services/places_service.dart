import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:seddo/core/utils/map_config.dart';

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
  String _sessionToken = const Uuid().v4();

  PlacesService([String? apiKey, Dio? dio])
      : _apiKey = apiKey ??
            const String.fromEnvironment(
              'PLACES_API_KEY',
              defaultValue: MapConfig.googleMapsApiKeyAndroid,
            ),
        _dio = dio ?? Dio();

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
}
