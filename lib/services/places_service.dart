import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:seddo/core/utils/map_config.dart';
import 'package:seddo/features/home/data/services/user_location_storage.dart';
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
            (const String.fromEnvironment('PLACES_API_KEY').isNotEmpty
                ? const String.fromEnvironment('PLACES_API_KEY')
                : MapConfig.apiKey),
        _dio = dio ?? Dio(),
        _locationFetcher = locationFetcher;

  /// Clé API effective pour les requêtes Google Maps & Places
  String get effectiveApiKey =>
      _apiKey.isNotEmpty ? _apiKey : MapConfig.apiKey;

  Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    LatLng? userLocation,
  }) async {
    final query = input.trim();
    if (query.isEmpty) {
      return [];
    }

    final key = effectiveApiKey;
    final centerLocation = userLocation ??
        UserLocationStorage.cached?.location ??
        const LatLng(MapConfig.dakarCenterLat, MapConfig.dakarCenterLng);

    try {
      debugPrint(
        '[PlacesService] 🔍 Autocomplete Google Places API (New) pour "$query" avec proximité: (${centerLocation.latitude}, ${centerLocation.longitude})...',
      );
      final res = await _dio.post(
        'https://places.googleapis.com/v1/places:autocomplete',
        options: Options(
          headers: {
            'X-Goog-Api-Key': key,
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
                'latitude': centerLocation.latitude,
                'longitude': centerLocation.longitude,
              },
              'radius': 12000.0,
            }
          },
        },
      );

      final suggestions = (res.data['suggestions'] as List?) ?? [];
      final List<PlaceSuggestion> apiResults = [];

      for (final s in suggestions) {
        if (s['placePrediction'] == null) continue;
        final pred = s['placePrediction'];
        final fullText = pred['text']?['text'] ?? '';
        final structured = pred['structuredFormat'];
        final main = _cleanAddress(structured?['mainText']?['text'] ?? fullText);
        final secondary = _cleanAddress(structured?['secondaryText']?['text'] ?? 'Dakar, Sénégal');

        if (main.isNotEmpty && !_isPlusCode(main)) {
          apiResults.add(
            PlaceSuggestion(
              pred['placeId'] ?? '',
              fullText,
              mainText: main,
              secondaryText: secondary,
            ),
          );
        }
      }

      // Si la recherche porte sur un code de rue sénégalais (ex: "LIB", "GY", "FN", "Rue")
      // ou si les résultats Places sont peu nombreux, enrichir via l'API Geocoding de Dakar (comme Yango)
      final lowerQuery = query.toLowerCase();
      final isStreetQuery = lowerQuery.contains('rue') ||
          lowerQuery.contains('lib') ||
          lowerQuery.contains('gy') ||
          lowerQuery.contains('fn') ||
          lowerQuery.contains('hlm') ||
          lowerQuery.contains('av') ||
          lowerQuery.contains('voie') ||
          lowerQuery.contains('vdn') ||
          RegExp(r'\d').hasMatch(query);

      if (apiResults.length < 3 || isStreetQuery) {
        try {
          final geoRes = await _dio.get(
            'https://maps.googleapis.com/maps/api/geocode/json',
            queryParameters: {
              'address': '$query, Dakar, Sénégal',
              'components': 'country:SN',
              'key': key,
              'language': 'fr',
            },
            options: Options(
              sendTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 3),
            ),
          );

          if (geoRes.statusCode == 200 && geoRes.data['results'] is List) {
            final geoResults = geoRes.data['results'] as List;
            for (final g in geoResults) {
              final placeId = g['place_id'] as String? ?? '';
              final formatted = g['formatted_address'] as String? ?? '';
              final cleaned = _cleanAddress(formatted);
              final parts = cleaned.split(',').map((p) => p.trim()).toList();
              if (parts.isEmpty || _isPlusCode(parts.first)) continue;

              final main = parts.first;
              final sec = parts.length > 1 ? parts.sublist(1).join(', ') : 'Dakar, Sénégal';

              final exists = apiResults.any((p) =>
                  p.placeId == placeId ||
                  p.mainText?.toLowerCase() == main.toLowerCase());
              if (!exists && main.toLowerCase() != 'dakar') {
                apiResults.add(
                  PlaceSuggestion(
                    placeId,
                    cleaned,
                    mainText: main,
                    secondaryText: sec,
                  ),
                );
              }
            }
          }
        } catch (_) {}
      }

      if (apiResults.isNotEmpty) {
        debugPrint('[PlacesService] ✅ Google Places a retourné ${apiResults.length} résultats réels.');
        return apiResults;
      }
    } catch (e) {
      debugPrint('[PlacesService] ⚠️ Erreur Google Places Autocomplete: $e');
    }

    return [];
  }

  Future<PlaceDetails> details(String placeId) async {
    final key = effectiveApiKey;
    try {
      debugPrint('[PlacesService] 📍 Google Places Details pour placeId="$placeId"...');
      final res = await _dio.get(
        'https://places.googleapis.com/v1/places/$placeId',
        options: Options(
          headers: {
            'X-Goog-Api-Key': key,
            'X-Goog-FieldMask': 'displayName,formattedAddress,location',
          },
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
        queryParameters: {'sessionToken': _sessionToken},
      );

      _sessionToken = const Uuid().v4(); // nouvelle session après la sélection
      final lat = (res.data['location']['latitude'] as num).toDouble();
      final lng = (res.data['location']['longitude'] as num).toDouble();
      final displayName = res.data['displayName']?['text'] as String?;
      final formatted = res.data['formattedAddress'] as String? ?? '';
      final addr = (displayName != null && displayName.isNotEmpty)
          ? '$displayName, $formatted'
          : formatted;
      debugPrint('[PlacesService] ✅ Coordonnées Google reçues: ($lat, $lng) - $addr');
      return PlaceDetails(addr, lat, lng);
    } catch (e) {
      debugPrint('[PlacesService] ⚠️ Erreur Google Places Details: $e');
      _sessionToken = const Uuid().v4();

      // Repli Geocoding si le placeId était un place_id Geocoding
      try {
        final geoRes = await _dio.get(
          'https://maps.googleapis.com/maps/api/geocode/json',
          queryParameters: {
            'place_id': placeId,
            'key': key,
            'language': 'fr',
          },
        );
        if (geoRes.statusCode == 200 && geoRes.data['results'] is List) {
          final results = geoRes.data['results'] as List;
          if (results.isNotEmpty) {
            final first = results.first;
            final lat = (first['geometry']['location']['lat'] as num).toDouble();
            final lng = (first['geometry']['location']['lng'] as num).toDouble();
            final formatted = first['formatted_address'] as String? ?? 'Dakar, Sénégal';
            return PlaceDetails(formatted, lat, lng);
          }
        }
      } catch (_) {}

      return PlaceDetails(
        'Dakar, Sénégal',
        MapConfig.dakarCenterLat,
        MapConfig.dakarCenterLng,
      );
    }
  }

  /// Formate la rue et le numéro selon le standard Yango à Dakar :
  /// - Codes de rue Dakarois ou adresses : "Rue LIB-24, 289"
  /// - Numérotation traditionnelle française : "77 Rue 4"
  /// - Réorganise les préfixes comme "52 Rue GY 113" -> "Rue GY 113, 52"
  static String formatStreetWithNumber(String route, String? streetNumber) {
    var cleanRoute = route.trim();
    var number = streetNumber?.trim();

    // Si cleanRoute commence déjà par un numéro (ex: "52 Rue GY 113" -> number="52", route="Rue GY 113")
    final prefixMatch = RegExp(r'^(\d+)\s*,?\s*(?:Rue|Av|Avenue|Bd|Boulevard)\b', caseSensitive: false)
        .firstMatch(cleanRoute);
    if (prefixMatch != null) {
      number ??= prefixMatch.group(1);
      cleanRoute = cleanRoute.substring(prefixMatch.group(1)!.length).trim();
      if (cleanRoute.startsWith(',')) cleanRoute = cleanRoute.substring(1).trim();
    }

    if (number != null && number.isNotEmpty) {
      // Pour les rues traditionnelles numérotées (ex: Rue 4, Rue 10) : "77 Rue 4"
      if (RegExp(r'^Rue\s+\d+$', caseSensitive: false).hasMatch(cleanRoute)) {
        return '$number $cleanRoute';
      }
      // Pour les codes Dakarois (ex: Rue LIB-24, 289) et autres rues : "Rue LIB-24, 289"
      return '$cleanRoute, $number';
    }

    return cleanRoute;
  }

  /// Détermine si un nom de voie correspond à une voie rapide / autoroute urbaine (ex: VDN, Autoroute)
  /// qui doit céder la priorité aux rues de quartier intérieures (ex: "Rue LIB 42", "Rue LIB-24")
  static bool isExpressway(String route) {
    final lower = route.toLowerCase();
    return lower.contains('voie de degagement') ||
        lower.contains('voie de dégagement') ||
        lower.contains('vdn') ||
        lower.contains('autoroute') ||
        lower.contains('voie express');
  }

  /// Détermine si un nom de voie correspond à une rue locale / résidentielle
  static bool isLocalStreet(String route) {
    final lower = route.toLowerCase();
    if (isExpressway(route)) return false;
    return lower.startsWith('rue') ||
        lower.startsWith('allée') ||
        lower.startsWith('allee') ||
        lower.startsWith('impasse') ||
        RegExp(r'\b(?:LIB|GY|PE|FN|HLM|MZ|DK)[ -]?\d+\b', caseSensitive: false).hasMatch(route);
  }

  /// Vérifie si le nom de rue est cohérent avec le quartier détecté à Dakar
  /// (ex: évite que Google Maps n'attribue une rue "GY" de Grand Yoff à Sicap-Liberté)
  static bool isRouteConsistentWithArea({
    required String route,
    String? district,
    String? sublocality,
    double? lat,
    double? lng,
  }) {
    final lowerRoute = route.toLowerCase();
    // Le seul cas erroné dans la base Google Maps à Dakar est l'attribution d'une fausse rue "Rue GY 113" dans Sicap-Liberté / Liberté 6
    if (lowerRoute.contains('gy 113') || lowerRoute.contains('gy-113')) {
      final isLiberte = (district ?? '').toLowerCase().contains('libert') ||
          (sublocality ?? '').toLowerCase().contains('libert') ||
          (district ?? '').toLowerCase().contains('sicap') ||
          (sublocality ?? '').toLowerCase().contains('sicap') ||
          (lat != null && lng != null && lat >= 14.710 && lat <= 14.745 && lng >= -17.478 && lng <= -17.445);
      if (isLiberte) return false;
    }

    return true;
  }

  /// Reverse geocode coordinates (lat, lng) to a clean human-readable exact street address
  Future<PlaceSearchResult> reverseGeocode(double lat, double lng) async {
    final key = effectiveApiKey;

    // 1. Google Maps Geocoding API officiel
    try {
      debugPrint('[PlacesService] 🗺️ Google Geocoding pour ($lat, $lng)...');
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '$lat,$lng',
          'key': key,
          'language': 'fr',
        },
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      final results = (res.data['results'] as List?) ?? [];
      if (results.isNotEmpty) {
        String? bestRoute;
        String? bestStreetNumber;
        String? bestPremise;
        bool bestRouteIsExpressway = false;
        String? bestNeighborhood;
        String? bestSublocality;
        String? bestAdminArea2;
        String? bestLocality;
        String? bestAdminArea;
        String? bestCountry;
        String? bestEstablishment;

        // Scanner les résultats Google : la première rue rencontrée est la plus proche
        for (final item in results) {
          final components = (item['address_components'] as List?) ?? [];
          final types = (item['types'] as List?) ?? [];
          final formatted = item['formatted_address'] as String? ?? '';

          String? itemStreetNumber;
          String? itemRoute;
          String? itemSublocality;
          String? itemNeighborhood;
          String? itemLocality;
          String? itemAdminArea2;
          String? itemAdminArea;
          String? itemCountry;
          String? itemPremise;

          for (final c in components) {
            final cTypes = (c['types'] as List?) ?? [];
            final longName = (c['long_name'] as String?)?.trim() ?? '';
            if (longName.isEmpty) continue;

            if (cTypes.contains('street_number')) {
              itemStreetNumber = longName;
            } else if (cTypes.contains('route')) {
              itemRoute = longName;
            } else if (cTypes.contains('premise') || cTypes.contains('subpremise')) {
              itemPremise = longName;
            } else if (cTypes.contains('neighborhood')) {
              itemNeighborhood = longName;
            } else if (cTypes.contains('sublocality') ||
                cTypes.contains('sublocality_level_1')) {
              itemSublocality = longName;
            } else if (cTypes.contains('administrative_area_level_2')) {
              itemAdminArea2 = longName;
            } else if (cTypes.contains('locality') ||
                cTypes.contains('postal_town')) {
              itemLocality = longName;
            } else if (cTypes.contains('administrative_area_level_1')) {
              itemAdminArea = longName;
            } else if (cTypes.contains('country')) {
              itemCountry = longName;
            }
          }

          // Détecter un établissement ou point d'intérêt nommé
          if ((types.contains('point_of_interest') ||
                  types.contains('establishment')) &&
              bestEstablishment == null) {
            final cleaned = _cleanAddress(formatted).split(',').first.trim();
            if (cleaned.isNotEmpty && !_isPlusCode(cleaned)) {
              bestEstablishment = cleaned;
            }
          }

          // Enregistrer les métadonnées géographiques (quartier, commune, département, ville, pays)
          bestNeighborhood ??= itemNeighborhood;
          bestSublocality ??= itemSublocality;
          bestAdminArea2 ??= itemAdminArea2;
          bestLocality ??= itemLocality;
          bestAdminArea ??= itemAdminArea;
          bestCountry ??= itemCountry;

          final isUnnamedRoad = itemRoute != null &&
              (itemRoute.toLowerCase().contains('route sans nom') ||
                  itemRoute.toLowerCase().contains('unnamed road'));

          final isConsistentRoute = itemRoute != null &&
              isRouteConsistentWithArea(
                route: itemRoute,
                district: itemNeighborhood ?? bestNeighborhood,
                sublocality: itemSublocality ?? bestSublocality,
                lat: lat,
                lng: lng,
              );

          // Priorité aux rues résidentielles intérieures sur les voies rapides / VDN (comme Yango)
          // NE JAMAIS accepter une rue erronée de Grand Yoff (GY) dans Sicap-Liberté
          if (itemRoute != null && !isUnnamedRoad && isConsistentRoute) {
            final itemIsExpress = isExpressway(itemRoute);
            final itemIsLocal = isLocalStreet(itemRoute);

            // 1. Première route trouvée
            if (bestRoute == null) {
              bestRoute = itemRoute;
              bestStreetNumber = itemStreetNumber;
              bestPremise = itemPremise;
              bestRouteIsExpressway = itemIsExpress;
            }
            // 2. Si la route actuelle est une voie rapide (ex: Voie de dégagement Nord / VDN)
            // et que Google Maps renvoie aussi la vraie rue intérieure du quartier (ex: "Rue LIB 42", "Rue LIB-24") :
            // Remplacer immédiatement par la rue locale !
            else if (bestRouteIsExpressway && (itemIsLocal || !itemIsExpress)) {
              bestRoute = itemRoute;
              bestStreetNumber = itemStreetNumber;
              bestPremise = itemPremise;
              bestRouteIsExpressway = itemIsExpress;
            }
            // 3. Compléter le numéro si c'est la même rue
            else if (itemRoute.toLowerCase() == bestRoute.toLowerCase() &&
                bestStreetNumber == null &&
                itemStreetNumber != null) {
              bestStreetNumber = itemStreetNumber;
            }

            // Extraire un éventuel numéro en tête du formatted_address (ex: "561 Rue LIB 42")
            if (bestStreetNumber == null && bestRoute != null) {
              final prefixNumMatch = RegExp(
                r'^(\d+)\s*,?\s*(?:Rue|Av|Avenue|Bd|Boulevard)\b',
                caseSensitive: false,
              ).firstMatch(formatted);
              if (prefixNumMatch != null) {
                bestStreetNumber = prefixNumMatch.group(1);
              }
            }
          }
        }

        // Fallback extraction de rue depuis formatted_address si Google n'a pas étiqueté 'route'
        // ou si on n'avait trouvé qu'une voie rapide (VDN) alors qu'une rue locale existe dans formatted_address
        if (bestRoute == null || bestRouteIsExpressway) {
          for (final item in results) {
            final formatted = item['formatted_address'] as String? ?? '';
            final streetMatch = RegExp(
              r'\b((?:Rue|Avenue|Av\.|Boulevard|Bd|Route|Rte)\s+[A-Za-z0-9\-_]+(?:\s+[A-Za-z0-9\-_]+)?)',
              caseSensitive: false,
            ).firstMatch(formatted);
            if (streetMatch != null) {
              final candidate = streetMatch.group(1)!.trim();
              if (isRouteConsistentWithArea(
                route: candidate,
                district: bestNeighborhood,
                sublocality: bestSublocality,
                lat: lat,
                lng: lng,
              )) {
                if (bestRoute == null || (bestRouteIsExpressway && !isExpressway(candidate))) {
                  bestRoute = candidate;
                  bestRouteIsExpressway = isExpressway(candidate);
                  final numMatch = RegExp(r'\b(\d{1,4})\s*,\s*' + RegExp.escape(candidate))
                          .firstMatch(formatted) ??
                      RegExp(r'\b(\d{1,4})\s+' + RegExp.escape(candidate))
                          .firstMatch(formatted) ??
                      RegExp(RegExp.escape(candidate) + r'[\s,]+(\d{1,4})\b')
                          .firstMatch(formatted);
                  if (numMatch != null) {
                    bestStreetNumber = numMatch.group(1);
                  }
                  if (!bestRouteIsExpressway) break;
                }
              }
            }
          }
        }

        // 1. Détection et affinage du quartier pour Dakar (ex: convertir "Fann-Point E-Amitié" en "Fann Hock" ou "Point E")
        final rawDistrict = bestNeighborhood ?? bestSublocality;
        var district = rawDistrict != null && rawDistrict.isNotEmpty
            ? refineDakarDistrict(
                rawDistrict,
                route: bestRoute,
                lat: lat,
                lng: lng,
              )
            : null;

        final country = (bestCountry != null && bestCountry.isNotEmpty) ? bestCountry : 'Sénégal';
        final isSenegal = country.toLowerCase() == 'sénégal' || country.toLowerCase() == 'senegal';

        // Si le quartier n'a pas été trouvé ou a renvoyé "Dakar" (trop générique),
        // déterminer le vrai quartier via la géolocalisation précise
        if (isSenegal &&
            (district == null ||
                district.toLowerCase() == 'dakar' ||
                district.toLowerCase() == 'dakar, sénégal' ||
                district.toLowerCase() == 'dakar, senegal')) {
          final fallbackDistrict = getDakarDistrictFallback(lat, lng).mainText;
          if (fallbackDistrict.toLowerCase() != 'dakar') {
            district = fallbackDistrict;
          }
        }

        // Construction du sous-titre selon la hiérarchie Yango :
        // Ex: "Sicap Liberte, Grand Dakar, Département de Dakar"
        String buildSecondary({String? excludeMain}) {
          final parts = <String>[];
          void add(String? s) {
            if (s == null) return;
            final t = s.trim();
            if (t.isEmpty) return;
            if (excludeMain != null && t.toLowerCase() == excludeMain.toLowerCase()) return;
            if (parts.any((p) => p.toLowerCase() == t.toLowerCase())) return;
            parts.add(t);
          }

          // 1. Quartier précis (ex: Sicap Liberte, Point E, Fann Hock)
          add(district);

          // 2. Commune d'arrondissement (ex: Grand Dakar, Dakar Plateau)
          if (bestSublocality != null &&
              (district == null || !bestSublocality!.toLowerCase().contains(district.toLowerCase()))) {
            add(bestSublocality);
          }

          // 3. Département / Division administrative 2 (ex: Département de Dakar)
          if (bestAdminArea2 != null && bestAdminArea2!.isNotEmpty) {
            final admin2 = bestAdminArea2!;
            if (isSenegal &&
                (admin2.toLowerCase() == 'dakar' ||
                    admin2.toLowerCase() == 'région de dakar')) {
              add('Département de Dakar');
            } else {
              add(admin2);
            }
          } else if (bestLocality != null && bestLocality!.isNotEmpty) {
            add(bestLocality);
          } else if (isSenegal && !parts.any((p) => p.toLowerCase().contains('dakar'))) {
            add('Département de Dakar');
          }

          if (!isSenegal && country.isNotEmpty) {
            add(country);
          }

          if (parts.isEmpty) {
            return isSenegal ? 'Dakar, Sénégal' : country;
          }
          return parts.join(', ');
        }

        final isUnnamed = bestRoute != null &&
            (bestRoute.toLowerCase().contains('route sans nom') ||
                bestRoute.toLowerCase().contains('unnamed road'));

        // Priorité 1 (Comme Yango) : Si une vraie rue nommée est détectée
        // (ex: "Rue LIB-24, 289", "Rue LIB 42, 561", "Avenue Cheikh Anta Diop", "77 Rue 4")
        // La rue avec son numéro éventuel est TOUJOURS le grand titre (mainText) !
        if (bestRoute != null && !isUnnamed && bestRoute.isNotEmpty) {
          final cleanMain = _cleanAddress(
            formatStreetWithNumber(bestRoute, bestStreetNumber ?? bestPremise),
          );
          final cleanSec = buildSecondary(excludeMain: cleanMain);
          final full = '$cleanMain, $cleanSec';

          return PlaceSearchResult(
            id: 'geo_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}',
            mainText: cleanMain,
            secondaryText: cleanSec,
            fullAddress: full,
            latitude: lat,
            longitude: lng,
          );
        }

        // Priorité 2 : Lieu ou établissement connu dans Google Maps (ex: "Sea Plaza", "Hôtel Radisson Blu", "Auchan...")
        if (bestEstablishment != null && bestEstablishment.isNotEmpty) {
          final cleanMain = _cleanAddress(bestEstablishment);
          final cleanSec = buildSecondary(excludeMain: cleanMain);
          final full = '$cleanMain, $cleanSec';

          return PlaceSearchResult(
            id: 'geo_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}',
            mainText: cleanMain,
            secondaryText: cleanSec,
            fullAddress: full,
            latitude: lat,
            longitude: lng,
          );
        }

        // Priorité 3 : Quartier / lieu connu si aucune rue précise n'est disponible (ex: "Fann Hock", "Point E", "Liberté 6 Extension", "Almadies", "Grand Yoff")
        if (district != null &&
            district.isNotEmpty &&
            district.toLowerCase() != 'dakar' &&
            district.toLowerCase() != 'dakar, sénégal' &&
            district.toLowerCase() != 'dakar, senegal') {
          final cleanMain = _cleanAddress(district);
          final cleanSec = buildSecondary(excludeMain: cleanMain);
          final full = '$cleanMain, $cleanSec';

          return PlaceSearchResult(
            id: 'geo_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}',
            mainText: cleanMain,
            secondaryText: cleanSec,
            fullAddress: full,
            latitude: lat,
            longitude: lng,
          );
        }

        // Cas 4 : Rue seule si aucun quartier ou établissement détecté
        if (bestRoute != null && bestRoute.isNotEmpty) {
          final cleanMain = _cleanAddress(
            formatStreetWithNumber(bestRoute, bestStreetNumber ?? bestPremise),
          );
          final cleanSec = buildSecondary(excludeMain: cleanMain);
          final full = '$cleanMain, $cleanSec';

          return PlaceSearchResult(
            id: 'geo_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}',
            mainText: cleanMain,
            secondaryText: cleanSec,
            fullAddress: full,
            latitude: lat,
            longitude: lng,
          );
        }

        // Cas 4 : Première adresse formatée propre sans Plus Code ni "Route sans nom"
        for (final item in results) {
          final rawFormatted = item['formatted_address'] as String? ?? '';
          final cleaned = _cleanAddress(rawFormatted);
          final parts = cleaned.split(',').map((s) => s.trim()).toList();
          final firstPart = parts.isNotEmpty ? parts.first : '';
          final isUnnamed = firstPart.toLowerCase().contains('route sans nom') ||
              firstPart.toLowerCase().contains('unnamed road');

          if (firstPart.isNotEmpty && !_isPlusCode(firstPart) && !isUnnamed) {
            // Si la première partie est simplement "Dakar", utiliser le quartier réel
            if (firstPart.toLowerCase() == 'dakar' ||
                firstPart.toLowerCase() == 'dakar, sénégal' ||
                firstPart.toLowerCase() == 'dakar, senegal') {
              final fb = getDakarDistrictFallback(lat, lng);
              return PlaceSearchResult(
                id: 'geo_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}',
                mainText: fb.mainText,
                secondaryText: fb.secondaryText,
                fullAddress: fb.fullAddress,
                latitude: lat,
                longitude: lng,
              );
            }

            final sec = parts.length > 1 ? parts.sublist(1).join(', ') : buildSecondary();
            return PlaceSearchResult(
              id: 'geo_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}',
              mainText: firstPart,
              secondaryText: sec,
              fullAddress: cleaned,
              latitude: lat,
              longitude: lng,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[PlacesService] ⚠️ Erreur Google Geocoding: $e');
    }

    // 2. Repli OpenStreetMap Nominatim en direct (gratuit, sans clé requise)
    try {
      debugPrint('[PlacesService] 🌍 Repli Nominatim OpenStreetMap pour ($lat, $lng)...');
      final osmRes = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'json',
          'addressdetails': 1,
        },
        options: Options(
          headers: {'User-Agent': 'SeddoApp/1.0 (contact@innov.sn)'},
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      if (osmRes.statusCode == 200 && osmRes.data is Map) {
        final data = osmRes.data as Map;
        final address = data['address'] as Map?;
        final road = address?['road']?.toString();
        final pedestrian = address?['pedestrian']?.toString();
        final footway = address?['footway']?.toString();
        final path = address?['path']?.toString();
        final residential = address?['residential']?.toString();
        final houseNumber = address?['house_number']?.toString();
        final neighbourhood = address?['neighbourhood']?.toString();
        final suburb = address?['suburb']?.toString();
        final quarter = address?['quarter']?.toString();
        final cityDistrict = address?['city_district']?.toString();
        final city = address?['city']?.toString() ??
            address?['town']?.toString() ??
            address?['village']?.toString() ??
            address?['municipality']?.toString();
        final name = data['name']?.toString();
        final displayName = data['display_name']?.toString();

        final bestStreetOrWay =
            road ?? pedestrian ?? footway ?? path ?? residential;
        final rawDistrict =
            neighbourhood ?? suburb ?? quarter ?? cityDistrict;
        var bestDistrict = rawDistrict != null
            ? refineDakarDistrict(rawDistrict, route: bestStreetOrWay, lat: lat, lng: lng)
            : null;
        if (bestDistrict == null ||
            bestDistrict.toLowerCase() == 'dakar' ||
            bestDistrict.toLowerCase() == 'dakar, sénégal' ||
            bestDistrict.toLowerCase() == 'dakar, senegal') {
          final fb = getDakarDistrictFallback(lat, lng).mainText;
          if (fb.toLowerCase() != 'dakar') {
            bestDistrict = fb;
          }
        }

        final sec = (bestDistrict != null && city != null && bestDistrict != city)
            ? '$bestDistrict, $city'
            : (bestDistrict ?? (city ?? 'Dakar, Sénégal'));

        // Priorité 1 Nominatim : Si une rue est détectée
        if (bestStreetOrWay != null && bestStreetOrWay.isNotEmpty) {
          final main = houseNumber != null
              ? formatStreetWithNumber(bestStreetOrWay, houseNumber)
              : bestStreetOrWay;
          final sec = (bestDistrict != null && city != null && bestDistrict != city)
              ? '$bestDistrict, $city'
              : (bestDistrict ?? (city ?? 'Dakar, Sénégal'));
          return PlaceSearchResult(
            id: 'geo_osm_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}',
            mainText: _cleanAddress(main),
            secondaryText: _cleanAddress(sec),
            fullAddress: '$main, $sec',
            latitude: lat,
            longitude: lng,
          );
        } else if (bestDistrict != null &&
            bestDistrict.isNotEmpty &&
            bestDistrict.toLowerCase() != 'dakar' &&
            bestDistrict.toLowerCase() != 'dakar, sénégal' &&
            bestDistrict.toLowerCase() != 'dakar, senegal') {
          final cleanMain = _cleanAddress(bestDistrict);
          final cleanSub = city != null ? '$city, Sénégal' : 'Dakar, Sénégal';
          return PlaceSearchResult(
            id: 'geo_osm_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}',
            mainText: cleanMain,
            secondaryText: _cleanAddress(cleanSub),
            fullAddress: '$cleanMain, $cleanSub',
            latitude: lat,
            longitude: lng,
          );
        } else if (name != null && name.isNotEmpty && name.toLowerCase() != 'dakar') {
          return PlaceSearchResult(
            id: 'geo_osm_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}',
            mainText: _cleanAddress(name),
            secondaryText: _cleanAddress(sec),
            fullAddress: '$name, $sec',
            latitude: lat,
            longitude: lng,
          );
        } else if (displayName != null && displayName.isNotEmpty) {
          final parts = displayName.split(',').map((s) => s.trim()).toList();
          final first = parts.isNotEmpty ? parts.first : '';
          final rest = parts.length > 1
              ? parts.sublist(1).take(2).join(', ')
              : 'Dakar, Sénégal';
          if (first.isNotEmpty && first.toLowerCase() != 'dakar') {
            return PlaceSearchResult(
              id: 'geo_osm_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}',
              mainText: _cleanAddress(first),
              secondaryText: _cleanAddress(rest),
              fullAddress: displayName,
              latitude: lat,
              longitude: lng,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[PlacesService] ⚠️ Erreur Nominatim: $e');
    }

    // 3. Repli géographique intelligent sur le quartier réel (évite "Position sur la carte", coordonnées brutes et "Dakar" générique)
    return getDakarDistrictFallback(lat, lng);
  }

  /// Repli géographique précis pour Dakar et sa région lorsqu'aucun nom de rue n'est disponible
  /// ou en mode hors-ligne. Retourne le vrai quartier / commune au lieu de coordonnées ou "Position sur la carte".
  static PlaceSearchResult getDakarDistrictFallback(double lat, double lng) {
    // Si en dehors du Sénégal (ex: Guinée, Mali, etc. ou coordonnées internationales hors Sénégal),
    // renvoyer les coordonnées brutes au lieu d'un faux "Dakar"
    final isWithinSenegal = (lat >= 12.0 && lat <= 16.8 && lng >= -17.6 && lng <= -11.3);
    if (!isWithinSenegal) {
      final coords = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
      return PlaceSearchResult(
        id: 'geo_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}',
        mainText: coords,
        secondaryText: coords,
        fullAddress: coords,
        latitude: lat,
        longitude: lng,
      );
    }

    String district = 'Dakar';
    String secondary = 'Dakar, Sénégal';

    // 1. Almadies & Ngor (Pointe Ouest)
    if (lat >= 14.735 && lat <= 14.765 && lng >= -17.535 && lng <= -17.500) {
      if (lng <= -17.515 && lat >= 14.745) {
        district = 'Les Almadies';
      } else {
        district = 'Ngor / Almadies';
      }
      secondary = 'Dakar, Sénégal';
    }
    // 2. Yoff (Nord-Ouest / Plage / BCEAO)
    else if (lat >= 14.740 && lat <= 14.775 && lng >= -17.485 && lng <= -17.450) {
      district = 'Yoff';
      secondary = 'Dakar, Sénégal';
    }
    // 3. Ouakam & Mamelles
    else if (lat >= 14.715 && lat <= 14.745 && lng >= -17.505 && lng <= -17.475) {
      if (lng <= -17.495) {
        district = 'Les Mamelles';
      } else {
        district = 'Ouakam';
      }
      secondary = 'Dakar, Sénégal';
    }
    // 4. Mermoz & Sacré-Cœur
    else if (lat >= 14.700 && lat <= 14.725 && lng >= -17.485 && lng <= -17.460) {
      if (lng <= -17.472) {
        district = 'Mermoz';
      } else {
        district = 'Sacré-Cœur';
      }
      secondary = 'Dakar, Sénégal';
    }
    // 5. Liberté (Liberté 1 à 6, Liberté 6 Extension, Sicap)
    else if (lat >= 14.710 && lat <= 14.742 && lng >= -17.478 && lng <= -17.445) {
      if (lng <= -17.466 || lat >= 14.723) {
        district = 'Liberté 6 Extension';
      } else {
        district = 'Sicap Liberté';
      }
      secondary = 'Grand Dakar, Département de Dakar';
    }
    // 6. Fann Hock (Sud de Fann, Corniche Ouest sud, Canal 4)
    else if (lat >= 14.672 && lat <= 14.688 && lng > -17.464 && lng <= -17.453) {
      district = 'Fann Hock';
      secondary = 'Dakar, Sénégal';
    }
    // 7. Fann & Fann Résidence (UCAD, Corniche Ouest centre)
    else if (lat >= 14.680 && lat <= 14.698 && lng >= -17.478 && lng <= -17.464) {
      district = 'Fann';
      secondary = 'Dakar, Sénégal';
    }
    // 8. Point E & Amitié
    else if (lat >= 14.687 && lat <= 14.712 && lng >= -17.468 && lng <= -17.452) {
      if (lat >= 14.698) {
        district = 'Amitié';
      } else {
        district = 'Point E';
      }
      secondary = 'Dakar, Sénégal';
    }
    // 9. Médina
    else if (lat >= 14.670 && lat <= 14.690 && lng >= -17.452 && lng <= -17.432) {
      district = 'Médina';
      secondary = 'Dakar, Sénégal';
    }
    // 10. Gueule Tapée, Fass & Colobane
    else if (lat >= 14.675 && lat <= 14.708 && lng >= -17.460 && lng <= -17.435) {
      if (lat <= 14.688 && lng <= -17.450) {
        district = 'Gueule Tapée';
      } else if (lat >= 14.696) {
        district = 'Colobane';
      } else {
        district = 'Fass';
      }
      secondary = 'Dakar, Sénégal';
    }
    // 11. Dakar Plateau (Centre-ville)
    else if (lat >= 14.650 && lat <= 14.680 && lng >= -17.445 && lng <= -17.420) {
      district = 'Dakar Plateau';
      secondary = 'Dakar Centre, Sénégal';
    }
    // 12. Grand Dakar, HLM, Belle-Vue
    else if (lat >= 14.698 && lat <= 14.720 && lng >= -17.455 && lng <= -17.435) {
      district = 'Grand Dakar / HLM';
      secondary = 'Dakar, Sénégal';
    }
    // 13. Grand Yoff & Zone de Captage
    else if (lat >= 14.725 && lat <= 14.750 && lng >= -17.455 && lng <= -17.430) {
      district = 'Grand Yoff';
      secondary = 'Dakar, Sénégal';
    }
    // 14. Parcelles Assainies & Golf
    else if (lat >= 14.750 && lat <= 14.795 && lng >= -17.450 && lng <= -17.410) {
      district = 'Parcelles Assainies';
      secondary = 'Dakar, Sénégal';
    }
    // 15. Guédiawaye
    else if (lat >= 14.760 && lat <= 14.800 && lng >= -17.410 && lng <= -17.360) {
      district = 'Guédiawaye';
      secondary = 'Dakar Banlieue, Sénégal';
    }
    // 16. Pikine & Thiaroye
    else if (lat >= 14.730 && lat <= 14.770 && lng >= -17.410 && lng <= -17.340) {
      district = 'Pikine';
      secondary = 'Dakar Banlieue, Sénégal';
    }
    // 17. Rufisque & Bargny
    else if (lat >= 14.690 && lat <= 14.745 && lng >= -17.300 && lng <= -17.200) {
      district = 'Rufisque';
      secondary = 'Dakar Région, Sénégal';
    }
    // 18. Diamniadio
    else if (lat >= 14.700 && lat <= 14.750 && lng >= -17.200 && lng <= -17.140) {
      district = 'Diamniadio';
      secondary = 'Dakar Région, Sénégal';
    } else if (lat >= 14.650 && lat <= 14.780 && lng >= -17.530 && lng <= -17.410) {
      district = 'Sicap Liberté';
      secondary = 'Grand Dakar, Département de Dakar';
    } else {
      district = 'Dakar';
      secondary = 'Sénégal';
    }

    return PlaceSearchResult(
      id: 'district_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}',
      mainText: district,
      secondaryText: secondary,
      fullAddress: '$district, $secondary',
      latitude: lat,
      longitude: lng,
    );
  }

  /// Raffine les communes administratives composées de Dakar en véritables quartiers usuels
  /// (ex: transforme "Fann-Point E-Amitié" en "Fann Hock" ou "Point E", "Mermoz-Sacré-Cœur" en "Sacré-Cœur", etc.)
  static String refineDakarDistrict(
    String rawDistrict, {
    String? route,
    double? lat,
    double? lng,
  }) {
    var clean = rawDistrict.trim();
    if (clean.isEmpty) return 'Dakar';

    final lower = clean.toLowerCase();
    final lowerRoute = (route ?? '').toLowerCase();

    // 0. Quartiers déjà nommés et précis
    if (lower.contains('fann hock') || lower.contains('fann-hock')) {
      return 'Fann Hock';
    }
    if (lower.contains('fann résidence') || lower.contains('fann residence')) {
      return 'Fann Résidence';
    }
    if (lower.contains('gueule tapée') || lower.contains('gueule tapee')) {
      return 'Gueule Tapée';
    }
    if (lower.contains('colobane')) {
      return 'Colobane';
    }
    if (lower == 'fass' || lower.startsWith('fass ')) {
      return 'Fass';
    }
    if (lower.contains('médina') || lower.contains('medina')) {
      return 'Médina';
    }

    // 1. Détection Fann - Point E - Amitié
    if (lower.contains('fann') &&
        (lower.contains('point e') ||
            lower.contains('point-e') ||
            lower.contains('amitié') ||
            lower.contains('amitie'))) {
      if (lat != null && lng != null) {
        if (lat <= 14.688 && lng > -17.464 && lng <= -17.453) {
          return 'Fann Hock';
        }
        if (lat <= 14.698 && lng <= -17.464) {
          return 'Fann';
        }
        if (lat >= 14.698) {
          return 'Amitié';
        }
        if (lat >= 14.687 && lng >= -17.465) {
          return 'Point E';
        }
      }
      if (lowerRoute.contains('pe') ||
          lowerRoute.contains('point e') ||
          lowerRoute.contains('point-e')) {
        return 'Point E';
      }
      if (lowerRoute.contains('hock') || lower.contains('hock')) {
        return 'Fann Hock';
      }
      if (lowerRoute.contains('fn')) {
        return 'Fann';
      }
      if (lowerRoute.contains('am') ||
          lowerRoute.contains('amitié') ||
          lowerRoute.contains('amitie')) {
        return 'Amitié';
      }
      return 'Fann';
    }

    // 2. Gueule Tapée - Fass - Colobane
    if ((lower.contains('gueule') || lower.contains('tapée') || lower.contains('tapee')) &&
        (lower.contains('fass') || lower.contains('colobane'))) {
      if (lat != null && lng != null) {
        if (lat <= 14.688 && lng <= -17.450) {
          return 'Gueule Tapée';
        }
        if (lat >= 14.696) {
          return 'Colobane';
        }
        return 'Fass';
      }
      if (lowerRoute.contains('gt') || lowerRoute.contains('gueule')) {
        return 'Gueule Tapée';
      }
      if (lowerRoute.contains('colobane')) {
        return 'Colobane';
      }
      return 'Fass';
    }

    // 3. Mermoz - Sacré-Cœur
    if (lower.contains('mermoz') &&
        (lower.contains('sacré') || lower.contains('sacre'))) {
      if (lowerRoute.contains('sc') || lowerRoute.contains('sacr')) {
        return 'Sacré-Cœur';
      }
      if (lowerRoute.contains('mz') || lowerRoute.contains('mermoz')) {
        return 'Mermoz';
      }
      if (lng != null && lng > -17.472) {
        return 'Sacré-Cœur';
      }
      return 'Mermoz';
    }

    // 4. Sicap - Liberté
    if (lower.contains('sicap') &&
        (lower.contains('liberté') || lower.contains('liberte'))) {
      if (lowerRoute.contains('lib') || (lat != null && lat >= 14.723)) {
        return 'Liberté 6 Extension';
      }
      return 'Sicap Liberté';
    }
    if (lower.contains('liberte 6') || lower.contains('liberté 6')) {
      return 'Liberté 6 Extension';
    }
    if (lower.contains('sicap')) {
      return 'Sicap Liberté';
    }

    // Si la chaîne est simplement "Dakar" mais qu'on a des coordonnées précises
    if ((lower == 'dakar' || lower == 'dakar, sénégal' || lower == 'dakar, senegal') &&
        lat != null &&
        lng != null) {
      final fb = getDakarDistrictFallback(lat, lng).mainText;
      if (fb.toLowerCase() != 'dakar') {
        return fb;
      }
    }

    // Retirer les Plus Codes si présents
    clean = clean.replaceAll(RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,}\s*'), '').trim();

    return clean.isNotEmpty ? clean : 'Dakar';
  }

  static bool _isPlusCode(String input) {
    return RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,4}').hasMatch(input.trim());
  }

  static String _cleanAddress(String input) {
    return input
        .replaceFirst(RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,4}[,\s]*'), '')
        .trim();
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
          timeLimit: Duration(seconds: 7),
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

  /// Nettoie le sous-titre d'adresse pour ne jamais répéter le grand titre dans le détail
  /// et élimine toute répétition accidentelle de "Dakar, Sénégal"
  static String formatPlaceSubtitle(String title, String rawSubtitle) {
    final cleanTitle = title.trim();
    var cleanSub = rawSubtitle.trim();

    if (cleanSub.isEmpty) return '';

    // Si le sous-titre est strictement identique au titre (insensible à la casse)
    if (cleanSub.toLowerCase() == cleanTitle.toLowerCase()) {
      return '';
    }

    // Si le sous-titre commence par le titre (ex: "Liberté 6 Extension, Rue LIB 42, Dakar")
    if (cleanTitle.length > 5 &&
        cleanSub.toLowerCase().startsWith(cleanTitle.toLowerCase())) {
      cleanSub = cleanSub.substring(cleanTitle.length).trim();
      cleanSub = cleanSub.replaceFirst(RegExp(r'^[,;\s\-–—]+'), '').trim();
    }

    // Si après nettoyage le sous-titre est vide ou identique au titre
    if (cleanSub.isEmpty ||
        cleanSub.toLowerCase() == cleanTitle.toLowerCase()) {
      return '';
    }

    // Supprimer toute répétition interne de "Dakar, Sénégal" ou "Dakar, Dakar"
    cleanSub = cleanSub.replaceAll(
      RegExp(r'Dakar,\s*Sénégal,\s*Dakar,\s*Sénégal', caseSensitive: false),
      'Dakar, Sénégal',
    );
    cleanSub = cleanSub.replaceAll(
      RegExp(r'Dakar,\s*Dakar', caseSensitive: false),
      'Dakar',
    );

    return cleanSub;
  }

  /// Retourne le grand titre et le sous-titre d'adresse.
  /// Nettoie les Plus Codes Google Maps (ex: "MGHQ+W85", "Point E / MHJ3+JXC") et
  /// résout automatiquement le vrai quartier de Dakar via les coordonnées si le titre est "Dakar, Sénégal"
  static ({String title, String subtitle}) sanitizePlaceHierarchy(
    String rawLabel,
    String rawAddress, {
    double? lat,
    double? lng,
  }) {
    var title = rawLabel.trim();
    var subtitle = rawAddress.trim();

    // Expression régulière pour identifier les Plus Codes Google Maps (ex: "MGHQ+W85", "MHJ3+JXC", "8F3CMGHQ+W85")
    final plusCodeRegex = RegExp(
      r'\b[23456789CFGHJMPQRVWX0-9]{4,8}\+[23456789CFGHJMPQRVWX0-9]{2,4}\b',
      caseSensitive: false,
    );

    // 1. Nettoyer les Plus Codes dans le titre et le sous-titre
    title = title.replaceAll(RegExp(r'\s*/\s*[A-Z0-9]{4,8}\+[A-Z0-9]{2,4}\b', caseSensitive: false), '').trim();
    title = title.replaceAll(RegExp(r'^[A-Z0-9]{4,8}\+[A-Z0-9]{2,4}([\s,]+|\s*-\s*)', caseSensitive: false), '').trim();
    title = title.replaceAll(plusCodeRegex, '').trim();
    title = title.replaceFirst(RegExp(r'^[,;\s\-–—/]+'), '').trim();

    subtitle = subtitle.replaceAll(RegExp(r'\s*/\s*[A-Z0-9]{4,8}\+[A-Z0-9]{2,4}\b', caseSensitive: false), '').trim();
    subtitle = subtitle.replaceAll(RegExp(r'^[A-Z0-9]{4,8}\+[A-Z0-9]{2,4}([\s,]+|\s*-\s*)', caseSensitive: false), '').trim();
    subtitle = subtitle.replaceAll(plusCodeRegex, '').trim();
    subtitle = subtitle.replaceFirst(RegExp(r'^[,;\s\-–—/]+'), '').trim();

    bool isGeneric(String s) {
      final l = s.trim().toLowerCase();
      return l.isEmpty ||
          l == 'dakar' ||
          l == 'dakar, sénégal' ||
          l == 'dakar, senegal' ||
          l == 'dakar senegal' ||
          l == 'sénégal' ||
          l == 'senegal' ||
          l == 'destination' ||
          l == 'adresse inconnue';
    }

    final isDakarSenegalTitle = title.toLowerCase() == 'dakar, sénégal' ||
        title.toLowerCase() == 'dakar, senegal';

    if (title.contains(',') && !isDakarSenegalTitle) {
      final parts = title.split(',');
      title = parts.first.trim();
      if (subtitle.isEmpty ||
          subtitle.toLowerCase() == title.toLowerCase() ||
          subtitle.toLowerCase() == 'dakar, sénégal' ||
          subtitle.toLowerCase() == 'dakar, senegal' ||
          subtitle.toLowerCase() == 'dakar') {
        subtitle = parts.sublist(1).join(',').trim();
      }
    } else if (subtitle.contains(',') &&
        subtitle.toLowerCase() != 'dakar, sénégal' &&
        subtitle.toLowerCase() != 'dakar, senegal' &&
        (title.isEmpty || subtitle.toLowerCase().startsWith(title.toLowerCase()))) {
      final parts = subtitle.split(',');
      if (title.isEmpty) {
        title = parts.first.trim();
      }
      subtitle = parts.sublist(1).join(',').trim();
    }

    // Si le titre est vide mais le sous-titre est présent
    if (title.isEmpty) {
      if (!isGeneric(subtitle) && subtitle.contains(',')) {
        final parts = subtitle.split(',');
        title = parts.first.trim();
        subtitle = parts.sublist(1).join(',').trim();
      } else {
        title = subtitle.isNotEmpty ? subtitle : 'Destination';
        subtitle = '';
      }
    }

    // Résolution intelligente du vrai quartier de Dakar si le titre est générique ("Dakar, Sénégal" ou "Dakar")
    // et qu'on dispose de coordonnées géographiques
    if (isGeneric(title) && lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      final fallback = PlacesService.getDakarDistrictFallback(lat, lng);
      if (fallback.mainText.isNotEmpty && !isGeneric(fallback.mainText)) {
        title = fallback.mainText;
        if (subtitle.isEmpty || isGeneric(subtitle)) {
          subtitle = fallback.secondaryText;
        }
      }
    }

    // Si le sous-titre est vide ou identique au titre
    if (subtitle.isEmpty || subtitle.toLowerCase() == title.toLowerCase()) {
      if (title.toLowerCase() == 'dakar, sénégal' ||
          title.toLowerCase() == 'dakar, senegal' ||
          title.toLowerCase() == 'dakar') {
        subtitle = '';
      } else {
        subtitle = 'Dakar, Sénégal';
      }
    }

    final cleanSub = formatPlaceSubtitle(title, subtitle);

    return (
      title: title,
      subtitle: cleanSub,
    );
  }
}


