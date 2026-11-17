import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:seddo/core/utils/map_config.dart';
import 'package:seddo/services/places_service.dart';
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

  /// Recherche avec autocomplétion : 100% Google Places API (New) avec repli OSM
  Future<List<PlaceModel>> search(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return [];

    // 1. Recherche en direct avec les vraies clés Google Maps (Places API New)
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

    // 2. Si Google n'a rien renvoyé (hors-ligne ou clé inactive), repli sur OpenStreetMap Nominatim
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

    // 3. Filtrer les doublons éventuels (100% Google Places)
    final merged = <PlaceModel>[];
    final seen = <String>{};

    void addIfNew(PlaceModel place) {
      final key = place.name.trim().toLowerCase();
      if (!seen.contains(key)) {
        seen.add(key);
        merged.add(place);
      }
    }

    for (final p in remoteMatches) {
      addIfNew(p);
    }

    return merged.take(10).toList();
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
            String? bestRoute;
            String? bestStreetNumber;
            String? bestEstablishment;
            String? bestNeighborhood;
            String? bestSublocality;
            String formatted = (results.first as Map<String, dynamic>)['formatted_address'] as String? ?? '';
            String? placeId = (results.first as Map<String, dynamic>)['place_id'] as String?;

            for (final item in results) {
              final itemMap = item as Map<String, dynamic>;
              final comps = (itemMap['address_components'] as List?) ?? [];
              final types = (itemMap['types'] as List?) ?? [];

              String? itemRoute;
              String? itemStreetNum;
              for (final c in comps) {
                final cTypes = (c['types'] as List?) ?? [];
                final name = c['long_name'] as String? ?? '';
                if (cTypes.contains('street_number')) itemStreetNum = name;
                if (cTypes.contains('route')) itemRoute = name;
                if (cTypes.contains('neighborhood')) bestNeighborhood ??= name;
                if (cTypes.contains('sublocality') || cTypes.contains('sublocality_level_1')) {
                  bestSublocality ??= name;
                }
              }

              if (types.contains('point_of_interest') || types.contains('establishment')) {
                final cleaned = formatted.split(',').first.trim();
                if (!cleaned.contains('+')) bestEstablishment ??= cleaned;
              }

              if (itemRoute != null &&
                  !itemRoute.toLowerCase().contains('route sans nom') &&
                  !itemRoute.toLowerCase().contains('unnamed road')) {
                if (bestRoute == null || (itemStreetNum != null && bestStreetNumber == null)) {
                  bestRoute = itemRoute;
                  bestStreetNumber = itemStreetNum;
                  formatted = itemMap['formatted_address'] as String? ?? formatted;
                  placeId = itemMap['place_id'] as String? ?? placeId;
                }
              }
            }

            final rawDistrict = bestNeighborhood ?? bestSublocality;
            var refinedDistrict = rawDistrict != null
                ? PlacesService.refineDakarDistrict(
                    rawDistrict,
                    route: bestRoute,
                    lat: lat,
                    lng: lon,
                  )
                : null;
            if (refinedDistrict == null ||
                refinedDistrict.toLowerCase() == 'dakar' ||
                refinedDistrict.toLowerCase() == 'dakar, sénégal' ||
                refinedDistrict.toLowerCase() == 'dakar, senegal') {
              final fb = PlacesService.getDakarDistrictFallback(lat, lon).mainText;
              if (fb.toLowerCase() != 'dakar') {
                refinedDistrict = fb;
              }
            }

            String resolvedName = '';
            if (bestEstablishment != null && bestEstablishment.isNotEmpty) {
              resolvedName = bestEstablishment;
            } else if (refinedDistrict != null &&
                refinedDistrict.isNotEmpty &&
                refinedDistrict.toLowerCase() != 'dakar') {
              resolvedName = refinedDistrict;
            } else if (bestRoute != null && bestRoute.isNotEmpty) {
              resolvedName = bestStreetNumber != null ? '$bestStreetNumber $bestRoute' : bestRoute;
            } else if (formatted.isNotEmpty && formatted.split(',').first.trim().toLowerCase() != 'dakar') {
              resolvedName = formatted.split(',').first.trim();
            } else {
              resolvedName = refinedDistrict ?? 'Ma position actuelle';
            }

            debugPrint('[TCU Geocode] ✅ Google Maps a résolu: "$resolvedName" ($formatted)');
            return PlaceModel(
              latitude: lat,
              longitude: lon,
              name: resolvedName.isNotEmpty ? resolvedName : 'Ma position actuelle',
              address: formatted.isNotEmpty ? formatted : 'Position GPS actuelle',
              placeId: placeId,
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
          '?lat=$lat&lon=$lon&format=json&addressdetails=1';

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
        final road = address?['road']?.toString();
        final houseNumber = address?['house_number']?.toString();
        final neighbourhood = address?['neighbourhood']?.toString();
        final suburb = address?['suburb']?.toString();
        final name = data['name']?.toString();

        final rawDist = neighbourhood ?? suburb;
        var refinedDist = rawDist != null
            ? PlacesService.refineDakarDistrict(rawDist, route: road, lat: lat, lng: lon)
            : null;
        if (refinedDist == null ||
            refinedDist.toLowerCase() == 'dakar' ||
            refinedDist.toLowerCase() == 'dakar, sénégal' ||
            refinedDist.toLowerCase() == 'dakar, senegal') {
          final fb = PlacesService.getDakarDistrictFallback(lat, lon).mainText;
          if (fb.toLowerCase() != 'dakar') {
            refinedDist = fb;
          }
        }

        String finalName;
        if (refinedDist != null && refinedDist.isNotEmpty && refinedDist.toLowerCase() != 'dakar') {
          finalName = refinedDist;
        } else if (road != null && road.isNotEmpty) {
          finalName = houseNumber != null ? '$houseNumber $road' : road;
        } else if (name != null && name.isNotEmpty && name.toLowerCase() != 'dakar') {
          finalName = name;
        } else {
          finalName = 'Ma position actuelle';
        }

        return PlaceModel(
          latitude: lat,
          longitude: lon,
          name: finalName,
          address: displayName.isNotEmpty ? displayName : 'Position GPS actuelle',
        );
      }
    } catch (_) {}

    final fb = PlacesService.getDakarDistrictFallback(lat, lon);
    final fallbackName = fb.mainText.toLowerCase() != 'dakar' ? fb.mainText : 'Ma position actuelle';
    return PlaceModel(
      latitude: lat,
      longitude: lon,
      name: fallbackName,
      address: fb.secondaryText,
    );
  }
}
