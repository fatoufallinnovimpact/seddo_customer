import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:seddo/core/utils/map_config.dart';
import '../models/transit/PlaceModel.dart';

/// Service de recherche et autocomplétion d'adresses pour le module Transit (TCU).
/// Combine :
/// 1. Base locale enrichie de Dakar (terminaux de bus, gares, quartiers, repères)
/// 2. Recherche OpenStreetMap Nominatim en direct (Sénégal)
/// 3. Google Places API (New) si disponible
class TransitPlaceSearchService {
  static final TransitPlaceSearchService _instance =
      TransitPlaceSearchService._internal();
  factory TransitPlaceSearchService() => _instance;
  TransitPlaceSearchService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
    ),
  );

  /// Base de repères et quartiers clés à Dakar avec coordonnées GPS réelles
  static final List<PlaceModel> _dakarPresets = [
    // Pôles de transit & Gares
    PlaceModel(
      latitude: 14.6750,
      longitude: -17.4350,
      name: 'Gare Petersen',
      address: 'Gare Routière Petersen, Dakar Plateau',
    ),
    PlaceModel(
      latitude: 14.6850,
      longitude: -17.4420,
      name: 'Gare de Colobane',
      address: 'Colobane, Dakar',
    ),
    PlaceModel(
      latitude: 14.6710,
      longitude: -17.4320,
      name: 'Gare de Dakar (TER)',
      address: 'Place de la Gare, Dakar Plateau',
    ),
    PlaceModel(
      latitude: 14.6790,
      longitude: -17.4350,
      name: 'Marché Sandaga',
      address: 'Avenue Lamine Guèye, Dakar Plateau',
    ),
    PlaceModel(
      latitude: 14.6700,
      longitude: -17.4300,
      name: 'Place de l\'Indépendance',
      address: 'Dakar Plateau',
    ),
    PlaceModel(
      latitude: 14.6650,
      longitude: -17.4310,
      name: 'Palais Présidentiel / Plateau',
      address: 'Avenue Léopold Sédar Senghor, Dakar',
    ),

    // Ouakam, Almadies, Ngor, Yoff
    PlaceModel(
      latitude: 14.7231,
      longitude: -17.4912,
      name: 'Ouakam',
      address: 'Commune de Ouakam, Dakar',
    ),
    PlaceModel(
      latitude: 14.7222,
      longitude: -17.4950,
      name: 'Monument de la Renaissance Africaine',
      address: 'Ouakam, Dakar',
    ),
    PlaceModel(
      latitude: 14.7247,
      longitude: -17.4994,
      name: 'Phare des Mamelles',
      address: 'Ouakam, Dakar',
    ),
    PlaceModel(
      latitude: 14.7210,
      longitude: -17.4890,
      name: 'Hôpital Militaire de Ouakam',
      address: 'Route de Ouakam, Dakar',
    ),
    PlaceModel(
      latitude: 14.7431,
      longitude: -17.5195,
      name: 'Les Almadies',
      address: 'Ngor-Almadies, Dakar',
    ),
    PlaceModel(
      latitude: 14.7550,
      longitude: -17.5180,
      name: 'Plage de Ngor',
      address: 'Ngor, Dakar',
    ),
    PlaceModel(
      latitude: 14.7600,
      longitude: -17.4670,
      name: 'Yoff',
      address: 'Yoff, Dakar',
    ),
    PlaceModel(
      latitude: 14.7530,
      longitude: -17.4760,
      name: 'BCEAO Yoff',
      address: 'Route de l\'Aéroport, Yoff, Dakar',
    ),
    PlaceModel(
      latitude: 14.7495,
      longitude: -17.4682,
      name: 'Ouest Foire',
      address: 'Ouest Foire, Dakar',
    ),
    PlaceModel(
      latitude: 14.7420,
      longitude: -17.4610,
      name: 'Nord Foire',
      address: 'Nord Foire, CICES, Dakar',
    ),
    PlaceModel(
      latitude: 14.7390,
      longitude: -17.4600,
      name: 'CICES',
      address: 'Centre International du Commerce Extérieur, Dakar',
    ),

    // Mermoz, Sacré-Cœur, Fann, Point E
    PlaceModel(
      latitude: 14.7074,
      longitude: -17.4744,
      name: 'Mermoz',
      address: 'Mermoz, Dakar',
    ),
    PlaceModel(
      latitude: 14.7059,
      longitude: -17.4785,
      name: 'Mermoz Dépôt DDD',
      address: 'Route de Ouakam, Mermoz, Dakar',
    ),
    PlaceModel(
      latitude: 14.7130,
      longitude: -17.4813,
      name: 'Bataillon du Train',
      address: 'Route de Ouakam, Mermoz, Dakar',
    ),
    PlaceModel(
      latitude: 14.7150,
      longitude: -17.4650,
      name: 'Sacré-Cœur',
      address: 'Sacré-Cœur 1, 2, 3, Dakar',
    ),
    PlaceModel(
      latitude: 14.7100,
      longitude: -17.4670,
      name: 'Rond-point Liberté 6',
      address: 'Liberté 6, Dakar',
    ),
    PlaceModel(
      latitude: 14.7230,
      longitude: -17.4620,
      name: 'Liberté 6 Extension',
      address: 'Liberté 6, Dakar',
    ),
    PlaceModel(
      latitude: 14.7000,
      longitude: -17.4650,
      name: 'Point E',
      address: 'Point E, Dakar',
    ),
    PlaceModel(
      latitude: 14.6910,
      longitude: -17.4670,
      name: 'Université Cheikh Anta Diop (UCAD)',
      address: 'Avenue Cheikh Anta Diop, Fann, Dakar',
    ),
    PlaceModel(
      latitude: 14.6930,
      longitude: -17.4640,
      name: 'Hôpital Fann',
      address: 'Avenue Cheikh Anta Diop, Fann, Dakar',
    ),
    PlaceModel(
      latitude: 14.6980,
      longitude: -17.4740,
      name: 'Sea Plaza',
      address: 'Centre Commercial Sea Plaza, Corniche Ouest, Dakar',
    ),

    // Médina, Fass, Gueule Tapée, Grand Dakar
    PlaceModel(
      latitude: 14.6850,
      longitude: -17.4470,
      name: 'Médina',
      address: 'Médina, Dakar',
    ),
    PlaceModel(
      latitude: 14.6900,
      longitude: -17.4520,
      name: 'Fass',
      address: 'Fass Paillote, Dakar',
    ),
    PlaceModel(
      latitude: 14.7050,
      longitude: -17.4480,
      name: 'Grand Dakar',
      address: 'Grand Dakar, Dakar',
    ),
    PlaceModel(
      latitude: 14.7130,
      longitude: -17.4520,
      name: 'HLM',
      address: 'Marché HLM, Dakar',
    ),
    PlaceModel(
      latitude: 14.7080,
      longitude: -17.4550,
      name: 'Castors',
      address: 'Marché Castors, Dakar',
    ),

    // Parcelles Assainies, Grand Yoff, Maristes, Patte d'Oie
    PlaceModel(
      latitude: 14.7670,
      longitude: -17.4430,
      name: 'Parcelles Assainies',
      address: 'Parcelles Assainies, Unités 1 à 26, Dakar',
    ),
    PlaceModel(
      latitude: 14.7370,
      longitude: -17.4490,
      name: 'Grand Yoff',
      address: 'Grand Yoff, Dakar',
    ),
    PlaceModel(
      latitude: 14.7380,
      longitude: -17.4400,
      name: 'Patte d\'Oie',
      address: 'Patte d\'Oie Builders, Dakar',
    ),
    PlaceModel(
      latitude: 14.7270,
      longitude: -17.4370,
      name: 'Les Maristes',
      address: 'Hann Maristes, Dakar',
    ),

    // Banlieue & Stations BRT / AIBD
    PlaceModel(
      latitude: 14.7700,
      longitude: -17.4000,
      name: 'Guédiawaye',
      address: 'Préfecture de Guédiawaye, Terminus BRT',
    ),
    PlaceModel(
      latitude: 14.7550,
      longitude: -17.3950,
      name: 'Pikine',
      address: 'Pikine Icotaf, Dakar',
    ),
    PlaceModel(
      latitude: 14.7480,
      longitude: -17.3600,
      name: 'Thiaroye',
      address: 'Poste Thiaroye, Dakar',
    ),
    PlaceModel(
      latitude: 14.7850,
      longitude: -17.3100,
      name: 'Keur Massar',
      address: 'Rond-point Keur Massar, Dakar',
    ),
    PlaceModel(
      latitude: 14.7150,
      longitude: -17.2700,
      name: 'Rufisque',
      address: 'Gare de Rufisque, Dakar',
    ),
    PlaceModel(
      latitude: 14.7200,
      longitude: -17.1800,
      name: 'Diamniadio',
      address: 'Gare TER Diamniadio, Dakar',
    ),
    PlaceModel(
      latitude: 14.6710,
      longitude: -17.0730,
      name: 'Aéroport International Blaise Diagne (AIBD)',
      address: 'AIBD, Diass / Dakar',
    ),
  ];

  /// Recherche avec autocomplétion : Google Places API (New) prioritaire + repli local et OSM
  Future<List<PlaceModel>> search(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return [];

    // 1. Filtrage local instantané avec score de pertinence
    final localMatches = _searchLocal(clean);

    // 2. Recherche en direct avec les vraies clés Google Maps (Places API New)
    List<PlaceModel> remoteMatches = [];
    final apiKey = MapConfig.apiKey;
    if (apiKey.isNotEmpty) {
      try {
        debugPrint('[TCU Search] 🔍 Recherche Google Places API (New) pour "$clean" avec clé Maps...');
        final resp = await _dio.post(
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
            'input': clean,
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

        if (resp.statusCode == 200 && resp.data != null) {
          final suggestions = (resp.data['suggestions'] as List?) ?? [];
          final predictions = suggestions
              .where((s) => s['placePrediction'] != null)
              .map((s) => s['placePrediction'] as Map<String, dynamic>)
              .take(5)
              .toList();

          final futures = predictions.map((pred) async {
            final placeId = pred['placeId'] as String? ?? '';
            final fullText = pred['text']?['text'] as String? ?? '';
            final struct = pred['structuredFormat'] as Map<String, dynamic>?;
            final main = struct?['mainText']?['text'] as String? ?? fullText;

            double lat = 0.0;
            double lon = 0.0;
            String resolvedName = main;
            String resolvedAddress = fullText;

            try {
              final detailResp = await _dio.get(
                'https://places.googleapis.com/v1/places/$placeId',
                options: Options(
                  headers: {
                    'X-Goog-Api-Key': apiKey,
                    'X-Goog-FieldMask': 'id,displayName,formattedAddress,location',
                  },
                  receiveTimeout: const Duration(seconds: 3),
                ),
              );
              if (detailResp.statusCode == 200 && detailResp.data != null) {
                final loc = detailResp.data['location'] as Map<String, dynamic>?;
                lat = (loc?['latitude'] as num?)?.toDouble() ?? 0.0;
                lon = (loc?['longitude'] as num?)?.toDouble() ?? 0.0;
                final dName = detailResp.data['displayName']?['text'] as String?;
                if (dName != null && dName.isNotEmpty) resolvedName = dName;
                final fAddr = detailResp.data['formattedAddress'] as String?;
                if (fAddr != null && fAddr.isNotEmpty) resolvedAddress = fAddr;
              }
            } catch (detailErr) {
              debugPrint('[TCU Search] Erreur détails Place $placeId: $detailErr');
            }

            return PlaceModel(
              latitude: lat,
              longitude: lon,
              name: resolvedName,
              address: resolvedAddress,
              placeId: placeId,
            );
          });

          remoteMatches = await Future.wait(futures);
          debugPrint('[TCU Search] ✅ Google Places API a renvoyé ${remoteMatches.length} résultats réels.');
        }
      } catch (googleErr) {
        debugPrint('[TCU Search] ⚠️ Google Places API error: $googleErr');
      }
    }

    // 3. Si Google n'a rien renvoyé (hors-ligne ou clé inactive), repli sur OpenStreetMap Nominatim
    if (remoteMatches.isEmpty) {
      try {
        final url =
            'https://nominatim.openstreetmap.org/search'
            '?q=${Uri.encodeQueryComponent(clean)}'
            '&countrycodes=sn'
            '&format=json'
            '&limit=6'
            '&addressdetails=1';

        final resp = await _dio.get(
          url,
          options: Options(
            headers: {'User-Agent': 'SeddoTransitApp/1.0 (contact@innov.sn)'},
            receiveTimeout: const Duration(seconds: 4),
          ),
        );

        if (resp.statusCode == 200 && resp.data is List) {
          final list = resp.data as List;
          for (final item in list) {
            final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
            final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
            if (lat != 0.0 && lon != 0.0) {
              final displayName = item['display_name']?.toString() ?? '';
              final parts = displayName.split(',');
              final name = item['name']?.toString().isNotEmpty == true
                  ? item['name'].toString()
                  : parts.first.trim();

              remoteMatches.add(
                PlaceModel(
                  latitude: lat,
                  longitude: lon,
                  name: name,
                  address: displayName,
                  placeId: item['place_id']?.toString(),
                ),
              );
            }
          }
          if (remoteMatches.isNotEmpty) {
            debugPrint('[TCU Search] ℹ️ Repli OSM Nominatim actif (${remoteMatches.length} résultats).');
          }
        }
      } catch (_) {}
    }

    // 4. Fusionner les résultats sans doublons (Google Places 100% prioritaire)
    final merged = <PlaceModel>[];
    final seen = <String>{};

    void addIfNew(PlaceModel place) {
      final key = place.name.trim().toLowerCase();
      if (!seen.contains(key)) {
        seen.add(key);
        merged.add(place);
      }
    }

    // Prioriser les résultats Google Maps en premier (100% Google)
    for (final p in remoteMatches) {
      addIfNew(p);
    }
    // Compléter avec les raccourcis locaux
    for (final p in localMatches) {
      addIfNew(p);
    }

    return merged.take(10).toList();
  }

  /// Recherche locale dans les presets Dakar avec pondération intelligente
  List<PlaceModel> _searchLocal(String query) {
    final scored = <MapEntry<int, PlaceModel>>[];

    for (final item in _dakarPresets) {
      final name = item.name.toLowerCase();
      final address = item.address.toLowerCase();

      int score = 0;
      if (name.startsWith(query)) {
        score = 100;
      } else if (name.split(RegExp(r'\s+|[,\-]')).any((w) => w.startsWith(query))) {
        score = 80;
      } else if (name.contains(query)) {
        score = 50;
      } else if (address.contains(query)) {
        score = 30;
      }

      if (score > 0) {
        scored.add(MapEntry(score, item));
      }
    }

    scored.sort((a, b) => b.key.compareTo(a.key));
    return scored.map((e) => e.value).toList();
  }

  /// Géocodage inverse : Coordonnées GPS -> PlaceModel (Google Geocoding d'abord, Nominatim en secours)
  Future<PlaceModel> reverseGeocode(double lat, double lon) async {
    // 1. Google Maps Geocoding officiel avec la vraie clé Maps
    final apiKey = MapConfig.apiKey;
    if (apiKey.isNotEmpty) {
      try {
        debugPrint('[TCU Geocode] 🗺️ Géocodage Google Maps ($lat, $lon) avec clé Maps...');
        final resp = await _dio.get(
          'https://maps.googleapis.com/maps/api/geocode/json',
          queryParameters: {
            'latlng': '$lat,$lon',
            'key': apiKey,
            'language': 'fr',
          },
          options: Options(receiveTimeout: const Duration(seconds: 4)),
        );

        if (resp.statusCode == 200 && resp.data != null) {
          final results = (resp.data['results'] as List?) ?? [];
          if (results.isNotEmpty) {
            final first = results.first as Map<String, dynamic>;
            final formatted = first['formatted_address'] as String? ?? '';
            final components = (first['address_components'] as List?) ?? [];
            String name = '';
            for (final c in components) {
              final types = (c['types'] as List?) ?? [];
              if (types.contains('point_of_interest') ||
                  types.contains('establishment') ||
                  types.contains('neighborhood') ||
                  types.contains('sublocality') ||
                  types.contains('route')) {
                name = c['long_name'] as String? ?? '';
                break;
              }
            }
            if (name.isEmpty && formatted.isNotEmpty) {
              name = formatted.split(',').first.trim();
            }

            debugPrint('[TCU Geocode] ✅ Google Maps a résolu: "$name" ($formatted)');
            return PlaceModel(
              latitude: lat,
              longitude: lon,
              name: name.isNotEmpty ? name : 'Ma position actuelle',
              address: formatted.isNotEmpty ? formatted : 'Position GPS actuelle',
              placeId: first['place_id'] as String?,
            );
          }
        }
      } catch (geocodeErr) {
        debugPrint('[TCU Geocode] ⚠️ Erreur Google Geocoding: $geocodeErr');
      }
    }

    // 2. Repli Nominatim OpenStreetMap
    try {
      final url =
          'https://nominatim.openstreetmap.org/reverse'
          '?lat=$lat&lon=$lon&format=json';

      final resp = await _dio.get(
        url,
        options: Options(
          headers: {'User-Agent': 'SeddoTransitApp/1.0 (contact@innov.sn)'},
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      if (resp.statusCode == 200 && resp.data is Map) {
        final data = resp.data as Map;
        final displayName = data['display_name']?.toString() ?? '';
        final address = data['address'] as Map?;
        final name = data['name']?.toString().isNotEmpty == true
            ? data['name'].toString()
            : address?['suburb'] ??
                address?['neighbourhood'] ??
                address?['road'] ??
                'Ma position actuelle';

        return PlaceModel(
          latitude: lat,
          longitude: lon,
          name: name.toString(),
          address: displayName.isNotEmpty ? displayName : 'Position GPS actuelle',
        );
      }
    } catch (_) {}

    return PlaceModel(
      latitude: lat,
      longitude: lon,
      name: 'Ma position actuelle',
      address: 'Position GPS (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})',
    );
  }
}
