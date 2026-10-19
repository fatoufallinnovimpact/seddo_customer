import 'dart:convert';
import 'dart:io';
import 'package:seddo/core/utils/map_config.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';

/// Autocomplete and Place Search service specialized for Dakar and Senegal.
/// Combines instant local Dakar matching with live Google Places Autocomplete API.
class PlacesService {
  final HttpClient _httpClient;

  PlacesService({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  /// Curated, verified database of popular places, neighborhoods and landmarks across Dakar.
  static const List<PlaceSearchResult> dakarPlaces = [
    // Ouakam & surroundings (specifically prominent for "o" query)
    PlaceSearchResult(
      id: 'dakar_ouakam_center',
      mainText: 'Ouakam',
      secondaryText: 'Dakar, Sénégal',
      fullAddress: 'Ouakam, Dakar, Sénégal',
      latitude: 14.7231,
      longitude: -17.4912,
      category: 'neighborhood',
    ),
    PlaceSearchResult(
      id: 'dakar_ouest_foire',
      mainText: 'Ouest Foire',
      secondaryText: 'Dakar, Sénégal',
      fullAddress: 'Ouest Foire, Dakar, Sénégal',
      latitude: 14.7495,
      longitude: -17.4682,
      category: 'neighborhood',
    ),
    PlaceSearchResult(
      id: 'dakar_monument_renaissance',
      mainText: 'Monument de la Renaissance Africaine',
      secondaryText: 'Ouakam, Dakar',
      fullAddress: 'Monument de la Renaissance Africaine, Ouakam, Dakar',
      latitude: 14.7222,
      longitude: -17.4950,
      category: 'landmark',
    ),
    PlaceSearchResult(
      id: 'dakar_phare_mamelles',
      mainText: 'Phare des Mamelles',
      secondaryText: 'Ouakam, Dakar',
      fullAddress: 'Phare des Mamelles, Ouakam, Dakar',
      latitude: 14.7247,
      longitude: -17.4994,
      category: 'landmark',
    ),
    PlaceSearchResult(
      id: 'dakar_plage_mamelles',
      mainText: 'Plage des Mamelles',
      secondaryText: 'Ouakam, Dakar',
      fullAddress: 'Plage des Mamelles, Ouakam, Dakar',
      latitude: 14.7270,
      longitude: -17.4980,
      category: 'landmark',
    ),
    PlaceSearchResult(
      id: 'dakar_hopital_militaire_ouakam',
      mainText: 'Hôpital Militaire de Ouakam',
      secondaryText: 'Route de Ouakam, Dakar',
      fullAddress: 'Hôpital Militaire de Ouakam, Dakar',
      latitude: 14.7210,
      longitude: -17.4890,
      category: 'landmark',
    ),

    // Almadies & Ngor
    PlaceSearchResult(
      id: 'dakar_almadies',
      mainText: 'Les Almadies',
      secondaryText: 'Dakar, Sénégal',
      fullAddress: 'Les Almadies, Dakar, Sénégal',
      latitude: 14.7431,
      longitude: -17.5195,
      category: 'neighborhood',
    ),
    PlaceSearchResult(
      id: 'dakar_ngor',
      mainText: 'Ngor',
      secondaryText: 'Dakar, Sénégal',
      fullAddress: 'Ngor, Dakar, Sénégal',
      latitude: 14.7547,
      longitude: -17.5142,
      category: 'neighborhood',
    ),
    PlaceSearchResult(
      id: 'dakar_ile_ngor',
      mainText: 'Embarcadère Île de Ngor',
      secondaryText: 'Ngor, Dakar',
      fullAddress: 'Embarcadère Île de Ngor, Dakar',
      latitude: 14.7550,
      longitude: -17.5160,
      category: 'landmark',
    ),

    // Plateau & Centre-ville
    PlaceSearchResult(
      id: 'dakar_plateau',
      mainText: 'Dakar Plateau (Centre-ville)',
      secondaryText: 'Dakar, Sénégal',
      fullAddress: 'Dakar Plateau, Dakar, Sénégal',
      latitude: 14.6720,
      longitude: -17.4330,
      category: 'neighborhood',
    ),
    PlaceSearchResult(
      id: 'dakar_place_independance',
      mainText: 'Place de l\'Indépendance',
      secondaryText: 'Plateau, Dakar',
      fullAddress: 'Place de l\'Indépendance, Dakar Plateau',
      latitude: 14.6708,
      longitude: -17.4331,
      category: 'landmark',
    ),
    PlaceSearchResult(
      id: 'dakar_marche_sandaga',
      mainText: 'Marché Sandaga',
      secondaryText: 'Plateau, Dakar',
      fullAddress: 'Marché Sandaga, Dakar Plateau',
      latitude: 14.6730,
      longitude: -17.4370,
      category: 'landmark',
    ),

    // Point E, Fann, Mermoz
    PlaceSearchResult(
      id: 'dakar_point_e',
      mainText: 'Point E',
      secondaryText: 'Dakar, Sénégal',
      fullAddress: 'Point E, Dakar, Sénégal',
      latitude: 14.6974,
      longitude: -17.4618,
      category: 'neighborhood',
    ),
    PlaceSearchResult(
      id: 'dakar_mermoz',
      mainText: 'Mermoz',
      secondaryText: 'Dakar, Sénégal',
      fullAddress: 'Mermoz, Dakar, Sénégal',
      latitude: 14.7100,
      longitude: -17.4720,
      category: 'neighborhood',
    ),
    PlaceSearchResult(
      id: 'dakar_fann_residence',
      mainText: 'Fann Résidence',
      secondaryText: 'Dakar, Sénégal',
      fullAddress: 'Fann Résidence, Dakar, Sénégal',
      latitude: 14.6930,
      longitude: -17.4720,
      category: 'neighborhood',
    ),
    PlaceSearchResult(
      id: 'dakar_ucad',
      mainText: 'Université Cheikh Anta Diop (UCAD)',
      secondaryText: 'Fann, Dakar',
      fullAddress: 'Université Cheikh Anta Diop (UCAD), Dakar',
      latitude: 14.6910,
      longitude: -17.4670,
      category: 'landmark',
    ),

    // Yoff, Sacré-Cœur, Liberté
    PlaceSearchResult(
      id: 'dakar_yoff',
      mainText: 'Yoff',
      secondaryText: 'Dakar, Sénégal',
      fullAddress: 'Yoff, Dakar, Sénégal',
      latitude: 14.7600,
      longitude: -17.4670,
      category: 'neighborhood',
    ),
    PlaceSearchResult(
      id: 'dakar_sacre_coeur',
      mainText: 'Sacré-Cœur',
      secondaryText: 'Dakar, Sénégal',
      fullAddress: 'Sacré-Cœur 1, 2, 3, Dakar',
      latitude: 14.7150,
      longitude: -17.4650,
      category: 'neighborhood',
    ),
    PlaceSearchResult(
      id: 'dakar_liberte_6',
      mainText: 'Liberté 6',
      secondaryText: 'Dakar, Sénégal',
      fullAddress: 'Liberté 6, Dakar',
      latitude: 14.7230,
      longitude: -17.4620,
      category: 'neighborhood',
    ),
    PlaceSearchResult(
      id: 'dakar_medina',
      mainText: 'Médina',
      secondaryText: 'Dakar, Sénégal',
      fullAddress: 'Médina, Dakar, Sénégal',
      latitude: 14.6850,
      longitude: -17.4470,
      category: 'neighborhood',
    ),
    PlaceSearchResult(
      id: 'dakar_maristes',
      mainText: 'Les Maristes',
      secondaryText: 'Hann, Dakar',
      fullAddress: 'Les Maristes, Hann, Dakar',
      latitude: 14.7270,
      longitude: -17.4370,
      category: 'neighborhood',
    ),
    PlaceSearchResult(
      id: 'dakar_parcelles_assainies',
      mainText: 'Parcelles Assainies',
      secondaryText: 'Dakar, Sénégal',
      fullAddress: 'Parcelles Assainies, Dakar',
      latitude: 14.7670,
      longitude: -17.4430,
      category: 'neighborhood',
    ),

    // Major Transport & Malls
    PlaceSearchResult(
      id: 'dakar_aibd',
      mainText: 'Aéroport International Blaise Diagne (AIBD)',
      secondaryText: 'Diass / Dakar',
      fullAddress: 'Aéroport International Blaise Diagne (AIBD)',
      latitude: 14.6710,
      longitude: -17.0730,
      category: 'transport',
    ),
    PlaceSearchResult(
      id: 'dakar_sea_plaza',
      mainText: 'Sea Plaza',
      secondaryText: 'Corniche Ouest, Fann Dakar',
      fullAddress: 'Centre Commercial Sea Plaza, Corniche Ouest, Dakar',
      latitude: 14.6980,
      longitude: -17.4740,
      category: 'landmark',
    ),
    PlaceSearchResult(
      id: 'dakar_gare_ter',
      mainText: 'Gare de Dakar (TER)',
      secondaryText: 'Plateau, Dakar',
      fullAddress: 'Gare Ferroviaire de Dakar (TER), Dakar',
      latitude: 14.6760,
      longitude: -17.4330,
      category: 'transport',
    ),
    PlaceSearchResult(
      id: 'dakar_cices',
      mainText: 'CICES (Foire Internationale)',
      secondaryText: 'Ouest Foire, Dakar',
      fullAddress: 'CICES, Ouest Foire, Dakar',
      latitude: 14.7410,
      longitude: -17.4670,
      category: 'landmark',
    ),
  ];

  /// Search places matching the query, with immediate local prefix scoring
  /// and parallel Google Places API autocomplete query.
  Future<List<PlaceSearchResult>> searchPlaces(String query) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      // Default initial suggestions (Almadies, Ouakam, Plateau, AIBD)
      return dakarPlaces.take(6).toList();
    }

    // 1. Instant local matching with scoring
    final localMatches = _filterAndRankLocal(cleanQuery);

    // 2. Query Google Places API in parallel
    try {
      final googleMatches = await _queryGooglePlacesAutocomplete(cleanQuery);
      if (googleMatches.isNotEmpty) {
        return _mergeResults(localMatches, googleMatches);
      }
    } catch (_) {
      // Graceful fallback to local matches
    }

    return localMatches;
  }

  /// Filters and ranks local Dakar places so that prefix matches (e.g. 'O' -> 'Ouakam')
  /// always appear first.
  List<PlaceSearchResult> _filterAndRankLocal(String query) {
    final scored = <MapEntry<int, PlaceSearchResult>>[];

    for (final place in dakarPlaces) {
      final main = place.mainText.toLowerCase();
      final full = place.fullAddress.toLowerCase();

      int score = 0;

      // Exact prefix of mainText (e.g. 'o' -> 'Ouakam', 'Ouest Foire')
      if (main.startsWith(query)) {
        score = 100;
      }
      // Any word inside mainText starts with query (e.g. 'o' -> 'Renaissance Africaine, Ouakam')
      else if (main.split(RegExp(r'\s+|[,\-]')).any((w) => w.startsWith(query))) {
        score = 80;
      }
      // Query is a substring of mainText (e.g. 'o' in 'Point E', 'Ngor')
      else if (main.contains(query)) {
        score = 50;
      }
      // Query is anywhere in full address
      else if (full.contains(query)) {
        score = 30;
      }

      if (score > 0) {
        scored.add(MapEntry(score, place));
      }
    }

    // Sort by score descending, preserving alphabetical order for ties
    scored.sort((a, b) {
      if (a.key != b.key) {
        return b.key.compareTo(a.key);
      }
      return a.value.mainText.compareTo(b.value.mainText);
    });

    return scored.map((e) => e.value).toList();
  }

  /// Queries Google Places Autocomplete API restricted to Senegal around Dakar
  Future<List<PlaceSearchResult>> _queryGooglePlacesAutocomplete(
    String query,
  ) async {
    final apiKey = MapConfig.apiKey;
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {
        'input': query,
        'key': apiKey,
        'components': 'country:sn',
        'location':
            '${MapConfig.dakarCenterLat},${MapConfig.dakarCenterLng}',
        'radius': '${MapConfig.dakarSearchRadiusMeters}',
        'language': 'fr',
      },
    );

    final request = await _httpClient.getUrl(uri);
    final response =
        await request.close().timeout(const Duration(seconds: 4));

    if (response.statusCode != 200) {
      return [];
    }

    final responseBody = await response.transform(utf8.decoder).join();
    final data = json.decode(responseBody) as Map<String, dynamic>;
    final status = data['status'] as String?;

    if (status != 'OK') {
      return [];
    }

    final predictions = data['predictions'] as List? ?? [];
    final results = <PlaceSearchResult>[];

    for (final p in predictions) {
      final structured =
          p['structured_formatting'] as Map<String, dynamic>?;
      final mainText = structured?['main_text'] as String? ??
          p['description'] as String? ??
          '';
      final secondaryText = structured?['secondary_text'] as String? ??
          'Dakar, Sénégal';
      final fullAddress = p['description'] as String? ?? mainText;
      final placeId = p['place_id'] as String? ?? '';

      results.add(
        PlaceSearchResult(
          id: placeId,
          mainText: mainText,
          secondaryText: secondaryText,
          fullAddress: fullAddress,
          latitude: MapConfig.dakarCenterLat,
          longitude: MapConfig.dakarCenterLng,
          category: 'google_place',
        ),
      );
    }

    return results;
  }

  /// Merges local matches and Google Places results without duplicates
  List<PlaceSearchResult> _mergeResults(
    List<PlaceSearchResult> local,
    List<PlaceSearchResult> google,
  ) {
    final results = <PlaceSearchResult>[];
    final seen = <String>{};

    for (final item in local) {
      final key = item.mainText.toLowerCase();
      if (!seen.contains(key)) {
        seen.add(key);
        results.add(item);
      }
    }

    for (final item in google) {
      final key = item.mainText.toLowerCase();
      if (!seen.contains(key)) {
        seen.add(key);
        results.add(item);
      }
    }

    return results;
  }
}
