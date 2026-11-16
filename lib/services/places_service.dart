import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
            (const String.fromEnvironment('PLACES_API_KEY').isNotEmpty
                ? const String.fromEnvironment('PLACES_API_KEY')
                : MapConfig.apiKey),
        _dio = dio ?? Dio(),
        _locationFetcher = locationFetcher;

  /// Clé API effective pour les requêtes Google Maps & Places
  String get effectiveApiKey =>
      _apiKey.isNotEmpty ? _apiKey : MapConfig.apiKey;

  Future<List<PlaceSuggestion>> autocomplete(String input) async {
    final query = input.trim();
    if (query.isEmpty) {
      return [];
    }

    final key = effectiveApiKey;
    try {
      debugPrint('[PlacesService] 🔍 Autocomplete Google Places API (New) pour "$query" avec clé: ${key.substring(0, 8)}...');
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
            'X-Goog-FieldMask': 'formattedAddress,location',
          },
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
        queryParameters: {'sessionToken': _sessionToken},
      );

      _sessionToken = const Uuid().v4(); // nouvelle session après la sélection
      final lat = (res.data['location']['latitude'] as num).toDouble();
      final lng = (res.data['location']['longitude'] as num).toDouble();
      final addr = res.data['formattedAddress'] as String? ?? '';
      debugPrint('[PlacesService] ✅ Coordonnées Google reçues: ($lat, $lng) - $addr');
      return PlaceDetails(addr, lat, lng);
    } catch (e) {
      debugPrint('[PlacesService] ⚠️ Erreur Google Places Details: $e');
      _sessionToken = const Uuid().v4();
      return PlaceDetails(
        'Dakar, Sénégal',
        MapConfig.dakarCenterLat,
        MapConfig.dakarCenterLng,
      );
    }
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
        String? bestNeighborhood;
        String? bestSublocality;
        String? bestLocality;
        String? bestAdminArea;
        String? bestCountry;
        String? bestEstablishment;

        // Scanner l'ensemble des résultats Google pour trouver la rue et le numéro exacts
        for (final item in results) {
          final components = (item['address_components'] as List?) ?? [];
          final types = (item['types'] as List?) ?? [];
          final formatted = item['formatted_address'] as String? ?? '';

          String? itemStreetNumber;
          String? itemRoute;
          String? itemSublocality;
          String? itemNeighborhood;
          String? itemLocality;
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
          if (types.contains('point_of_interest') ||
              types.contains('establishment')) {
            final cleaned = _cleanAddress(formatted).split(',').first.trim();
            if (cleaned.isNotEmpty && !_isPlusCode(cleaned)) {
              bestEstablishment ??= cleaned;
            }
          }

          // Enregistrer les métadonnées géographiques (quartier, ville, pays)
          bestNeighborhood ??= itemNeighborhood;
          bestSublocality ??= itemSublocality;
          bestLocality ??= itemLocality;
          bestAdminArea ??= itemAdminArea;
          bestCountry ??= itemCountry;

          final isUnnamedRoad = itemRoute != null &&
              (itemRoute.toLowerCase().contains('route sans nom') ||
                  itemRoute.toLowerCase().contains('unnamed road'));

          // Si on trouve une vraie rue nommée (route)
          if (itemRoute != null && !isUnnamedRoad) {
            if (bestRoute == null) {
              bestRoute = itemRoute;
              bestStreetNumber = itemStreetNumber;
              bestPremise = itemPremise;
            } else if (itemStreetNumber != null && bestStreetNumber == null) {
              // Priorité absolue au résultat avec numéro de rue précis
              bestRoute = itemRoute;
              bestStreetNumber = itemStreetNumber;
              bestPremise = itemPremise;
            }

            // Si numéro de rue + nom de voie sont trouvés, c'est l'adresse exacte idéale !
            if (bestStreetNumber != null && bestRoute.isNotEmpty) {
              break;
            }
          }
        }

        // 1. Détection et affinage du quartier pour Dakar (ex: convertir "Fann-Point E-Amitié" en "Point E")
        final rawDistrict = bestNeighborhood ?? bestSublocality;
        final district = rawDistrict != null && rawDistrict.isNotEmpty
            ? refineDakarDistrict(
                rawDistrict,
                route: bestRoute,
                lat: lat,
                lng: lng,
              )
            : null;

        final city = bestLocality ?? bestAdminArea ?? 'Dakar';

        // 2. Préparer le libellé de rue pour le sous-titre (ex: "Rue LIB 42" ou "Rue PE 24")
        String? streetDetail;
        if (bestRoute != null && bestRoute.isNotEmpty) {
          final rawStreet = bestStreetNumber != null
              ? '$bestStreetNumber $bestRoute'
              : (bestPremise != null ? '$bestPremise, $bestRoute' : bestRoute);
          streetDetail = _cleanAddress(rawStreet);
        }

        // Cas 1 : Lieu ou établissement connu dans Google Maps (ex: "Sea Plaza", "Hôtel Radisson Blu", "Pharmacie...")
        // -> C'est le GRAND TITRE !
        // -> Et le sous-titre contient la rue (ou quartier) + ville
        if (bestEstablishment != null && bestEstablishment.isNotEmpty) {
          final cleanMain = _cleanAddress(bestEstablishment);
          String cleanSec = '';
          if (streetDetail != null && streetDetail.isNotEmpty) {
            cleanSec = '$streetDetail, $city';
          } else if (district != null && district.isNotEmpty && district != cleanMain) {
            cleanSec = '$district, $city';
          } else {
            cleanSec = '$city, Sénégal';
          }
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

        // Cas 2 : Quartier / lieu connu (ex: "Point E", "Liberté 6 Extension", "Almadies", "Grand Yoff")
        // -> Le quartier / lieu est le GRAND TITRE !
        // -> Les rues ("Rue LIB 42", "Rue PE 24") se trouvent dans le SOUS-TITRE !
        if (district != null && district.isNotEmpty) {
          final cleanMain = _cleanAddress(district);
          String cleanSec = '';
          if (streetDetail != null && streetDetail.isNotEmpty) {
            cleanSec = '$streetDetail, $city';
          } else {
            cleanSec = '$city, Sénégal';
          }
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

        // Cas 3 : Si aucun quartier ni établissement n'est détecté, la rue sert de titre
        if (streetDetail != null && streetDetail.isNotEmpty) {
          final cleanMain = streetDetail;
          final cleanSec = '$city, Sénégal';
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
            final sec = parts.length > 1 ? parts.sublist(1).join(', ') : '$city, Sénégal';
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
        final bestDistrict =
            neighbourhood ?? suburb ?? quarter ?? cityDistrict ?? city;
        final sec = (bestDistrict != null && city != null && bestDistrict != city)
            ? '$bestDistrict, $city'
            : (bestDistrict ?? (city ?? 'Dakar, Sénégal'));

        if (bestStreetOrWay != null && bestStreetOrWay.isNotEmpty) {
          final main =
              houseNumber != null ? '$houseNumber $bestStreetOrWay' : bestStreetOrWay;
          return PlaceSearchResult(
            id: 'geo_osm_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}',
            mainText: _cleanAddress(main),
            secondaryText: _cleanAddress(sec),
            fullAddress: '$main, $sec',
            latitude: lat,
            longitude: lng,
          );
        } else if (name != null && name.isNotEmpty) {
          return PlaceSearchResult(
            id: 'geo_osm_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}',
            mainText: _cleanAddress(name),
            secondaryText: _cleanAddress(sec),
            fullAddress: '$name, $sec',
            latitude: lat,
            longitude: lng,
          );
        } else if (bestDistrict != null && bestDistrict.isNotEmpty) {
          return PlaceSearchResult(
            id: 'geo_osm_${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}',
            mainText: _cleanAddress(bestDistrict),
            secondaryText: _cleanAddress(city ?? 'Dakar, Sénégal'),
            fullAddress: '$bestDistrict, ${city ?? 'Dakar, Sénégal'}',
            latitude: lat,
            longitude: lng,
          );
        } else if (displayName != null && displayName.isNotEmpty) {
          final parts = displayName.split(',').map((s) => s.trim()).toList();
          final first = parts.isNotEmpty ? parts.first : '';
          final rest = parts.length > 1
              ? parts.sublist(1).take(2).join(', ')
              : 'Dakar, Sénégal';
          if (first.isNotEmpty) {
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

    // 3. Repli géographique intelligent sur le quartier réel (évite "Position sur la carte" et coordonnées brutes)
    return getDakarDistrictFallback(lat, lng);
  }

  /// Repli géographique précis pour Dakar et sa région lorsqu'aucun nom de rue n'est disponible
  /// ou en mode hors-ligne. Retourne le vrai quartier / commune au lieu de coordonnées ou "Position sur la carte".
  static PlaceSearchResult getDakarDistrictFallback(double lat, double lng) {
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
      district = 'Ouakam / Mamelles';
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
    // 5. Liberté (Liberté 1 à 6, Sicap)
    else if (lat >= 14.710 && lat <= 14.735 && lng >= -17.465 && lng <= -17.445) {
      district = 'Liberté 6 Extension';
      secondary = 'Rue LIB, Dakar';
    }
    // 6. Point E, Fann & Amitié
    else if (lat >= 14.685 && lat <= 14.708 && lng >= -17.475 && lng <= -17.450) {
      if (lat >= 14.688 && lng >= -17.465) {
        district = 'Point E';
        secondary = 'Rue PE, Dakar';
      } else {
        district = 'Fann';
        secondary = 'Fann Hock, Dakar';
      }
    }
    // 7. Médina, Fass, Colobane & Gueule Tapée
    else if (lat >= 14.675 && lat <= 14.698 && lng >= -17.460 && lng <= -17.435) {
      district = 'Médina / Fass';
      secondary = 'Dakar, Sénégal';
    }
    // 8. Dakar Plateau (Centre-ville)
    else if (lat >= 14.650 && lat <= 14.680 && lng >= -17.445 && lng <= -17.420) {
      district = 'Dakar Plateau';
      secondary = 'Dakar Centre, Sénégal';
    }
    // 9. Grand Dakar, HLM, Belle-Vue
    else if (lat >= 14.698 && lat <= 14.720 && lng >= -17.455 && lng <= -17.435) {
      district = 'Grand Dakar / HLM';
      secondary = 'Dakar, Sénégal';
    }
    // 10. Grand Yoff & Zone de Captage
    else if (lat >= 14.725 && lat <= 14.750 && lng >= -17.455 && lng <= -17.430) {
      district = 'Grand Yoff';
      secondary = 'Dakar, Sénégal';
    }
    // 11. Parcelles Assainies & Golf
    else if (lat >= 14.750 && lat <= 14.795 && lng >= -17.450 && lng <= -17.410) {
      district = 'Parcelles Assainies';
      secondary = 'Dakar, Sénégal';
    }
    // 12. Guédiawaye
    else if (lat >= 14.760 && lat <= 14.800 && lng >= -17.410 && lng <= -17.360) {
      district = 'Guédiawaye';
      secondary = 'Dakar Banlieue, Sénégal';
    }
    // 13. Pikine & Thiaroye
    else if (lat >= 14.730 && lat <= 14.770 && lng >= -17.410 && lng <= -17.340) {
      district = 'Pikine';
      secondary = 'Dakar Banlieue, Sénégal';
    }
    // 14. Rufisque & Bargny
    else if (lat >= 14.690 && lat <= 14.745 && lng >= -17.300 && lng <= -17.200) {
      district = 'Rufisque';
      secondary = 'Dakar Région, Sénégal';
    }
    // 15. Diamniadio
    else if (lat >= 14.700 && lat <= 14.750 && lng >= -17.200 && lng <= -17.140) {
      district = 'Diamniadio';
      secondary = 'Dakar Région, Sénégal';
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
  /// (ex: transforme "Fann-Point E-Amitié" en "Point E" ou "Fann", "Mermoz-Sacré-Cœur" en "Sacré-Cœur", etc.)
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

    // 1. Détection Fann - Point E - Amitié
    if (lower.contains('fann') &&
        (lower.contains('point e') ||
            lower.contains('point-e') ||
            lower.contains('amitié') ||
            lower.contains('amitie'))) {
      if (lowerRoute.contains('pe') ||
          lowerRoute.contains('point e') ||
          lowerRoute.contains('point-e')) {
        return 'Point E';
      }
      if (lowerRoute.contains('fn') || lowerRoute.contains('fann')) {
        return 'Fann';
      }
      if (lowerRoute.contains('am') ||
          lowerRoute.contains('amitié') ||
          lowerRoute.contains('amitie')) {
        return 'Amitié';
      }
      if (lat != null && lng != null) {
        // Coordonnées géographiques de Point E
        if (lat >= 14.688 && lat <= 14.700 && lng >= -17.465 && lng <= -17.452) {
          return 'Point E';
        }
        if (lat < 14.688 && lng >= -17.475 && lng <= -17.455) {
          return 'Fann';
        }
      }
      return 'Point E';
    }

    // 2. Mermoz - Sacré-Cœur
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

    // 3. Sicap - Liberté
    if (lower.contains('sicap') &&
        (lower.contains('liberté') || lower.contains('liberte'))) {
      if (lowerRoute.contains('lib')) {
        return 'Liberté 6 Extension';
      }
      return 'Liberté';
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
}


