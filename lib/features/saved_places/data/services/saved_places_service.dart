import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/core/network/api_client.dart';
import 'package:seddo/core/utils/api_endpoints.dart';
import 'package:seddo/core/utils/base_url.dart';
import 'package:seddo/features/saved_places/data/models/saved_place_model.dart';

/// Service responsible for managing user's saved favorite locations.
/// Connects with backend:
/// - GET /v1/users/me/places (Lieux enregistrés : Maison, Travail, autres)
/// - POST /v1/users/me/places (Enregistre un lieu ; un nouveau « Maison » ou « Travail » remplace l’ancien)
/// - DELETE /v1/users/me/places/{id} (Supprime un lieu enregistré)
/// Includes robust local caching in SharedPreferences.
class SavedPlacesService {
  static const String _storageKey = 'seddo_saved_places';
  final Dio _dio;
  final SharedPreferences? _prefs;
  final String baseUrl;

  SavedPlacesService([
    SharedPreferences? prefs,
    String? baseUrl,
    Dio? dio,
  ])  : _prefs = prefs,
        baseUrl = baseUrl ?? BaseUrl.current,
        _dio = dio ?? ApiClient().dio;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Initial default presets for quick start / offline demo
  static final List<SavedPlaceModel> defaultPresets = [
    const SavedPlaceModel(
      id: 'preset_home',
      name: 'Maison',
      address: 'Sacré-Cœur 3, villa 12',
      latitude: 14.7167,
      longitude: -17.4677,
      iconType: 'home',
      kind: 'HOME',
    ),
    const SavedPlaceModel(
      id: 'preset_work',
      name: 'Travail',
      address: 'Plateau, rue Carnot, Dakar',
      latitude: 14.6720,
      longitude: -17.4330,
      iconType: 'work',
      kind: 'WORK',
    ),
    const SavedPlaceModel(
      id: 'preset_airport',
      name: 'Aéroport AIBD',
      address: 'Aéroport International Blaise Diagne, Diass',
      latitude: 14.6710,
      longitude: -17.0730,
      iconType: 'airport',
      kind: 'OTHER',
    ),
  ];

  /// Retrieve all saved places:
  /// 1. Attempts remote GET /v1/users/me/places
  /// 2. Falls back to local SharedPreferences cache
  Future<List<SavedPlaceModel>> getSavedPlaces() async {
    // 1. Try remote API call
    try {
      debugPrint('[SavedPlacesService] 🚀 GET ${ApiEndpoints.userPlaces}');
      final response = await _dio.get(
        ApiEndpoints.userPlaces,
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;

        List<dynamic> list = [];
        if (raw is List) {
          list = raw;
        } else if (raw is Map<String, dynamic>) {
          list = (raw['places'] ?? raw['data'] ?? raw['items'] ?? [])
              as List<dynamic>;
        }

        final places = list
            .map((item) =>
                SavedPlaceModel.fromJson(item as Map<String, dynamic>))
            .toList();

        debugPrint(
            '[SavedPlacesService] ✅ Reçu ${places.length} lieux depuis l\'API');
        await saveAll(places);
        return places;
      }
    } catch (e) {
      debugPrint(
          '[SavedPlacesService] ⚠️ Erreur GET /v1/users/me/places ($e), utilisation du cache local');
    }

    // 2. Fallback to cached places in SharedPreferences
    try {
      final prefs = await _getPrefs();
      final String? jsonString = prefs.getString(_storageKey);

      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
        return decoded
            .map((item) =>
                SavedPlaceModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    // 3. Fallback to presets if never initialized and offline
    return List.from(defaultPresets);
  }

  /// Save the full list locally
  Future<void> saveAll(List<SavedPlaceModel> places) async {
    final prefs = await _getPrefs();
    final jsonString = jsonEncode(places.map((p) => p.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  Future<List<SavedPlaceModel>> _getLocalSavedPlaces() async {
    try {
      final prefs = await _getPrefs();
      final String? jsonString = prefs.getString(_storageKey);

      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
        return decoded
            .map((item) =>
                SavedPlaceModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return List.from(defaultPresets);
  }

  /// Add a new saved place:
  /// POST /v1/users/me/places
  /// { "kind": "HOME"|"WORK"|"OTHER", "label": "...", "address": "...", "lat": ..., "lng": ... }
  Future<List<SavedPlaceModel>> addSavedPlace(SavedPlaceModel place) async {
    SavedPlaceModel placeToSave = place;

    try {
      final payload = place.toApiJson();
      debugPrint('[SavedPlacesService] 🚀 POST ${ApiEndpoints.userPlaces} payload=$payload');

      final response = await _dio.post(
        ApiEndpoints.userPlaces,
        data: payload,
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null) {
        final data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;
        placeToSave = SavedPlaceModel.fromJson(data);
        debugPrint(
            '[SavedPlacesService] ✅ Lieu enregistré via API: id=${placeToSave.id}');
      }
    } catch (e) {
      debugPrint('[SavedPlacesService] ⚠️ Échec POST /v1/users/me/places ($e)');
    }

    // Backend rule: Un nouveau "Maison" ou "Travail" remplace l'ancien
    final current = await _getLocalSavedPlaces();
    final isHomeOrWork =
        placeToSave.kind == 'HOME' || placeToSave.kind == 'WORK';
    final updated = [
      placeToSave,
      ...current.where((p) {
        if (p.id == placeToSave.id) return false;
        if (isHomeOrWork && p.kind == placeToSave.kind) return false;
        return true;
      }),
    ];

    await saveAll(updated);
    return updated;
  }

  /// Update an existing saved place:
  /// POST /v1/users/me/places (replaces HOME/WORK; updates location)
  Future<List<SavedPlaceModel>> updateSavedPlace(
      SavedPlaceModel updatedPlace) async {
    SavedPlaceModel placeToSave = updatedPlace;

    try {
      final payload = updatedPlace.toApiJson();
      debugPrint('[SavedPlacesService] 🚀 POST ${ApiEndpoints.userPlaces} (update) payload=$payload');

      final response = await _dio.post(
        ApiEndpoints.userPlaces,
        data: payload,
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null) {
        final data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;
        placeToSave = SavedPlaceModel.fromJson(data);
        debugPrint(
            '[SavedPlacesService] ✅ Lieu mis à jour via API: id=${placeToSave.id}');
      }
    } catch (e) {
      debugPrint('[SavedPlacesService] ⚠️ Échec update API ($e)');
    }

    final current = await _getLocalSavedPlaces();
    final updated = current.map((p) {
      return p.id == updatedPlace.id ? placeToSave : p;
    }).toList();
    await saveAll(updated);
    return updated;
  }

  /// Delete a saved place by id:
  /// DELETE /v1/users/me/places/{id}
  Future<List<SavedPlaceModel>> deleteSavedPlace(String id) async {
    try {
      final url = ApiEndpoints.userPlaceById(id);
      debugPrint('[SavedPlacesService] 🚀 DELETE $url');
      final response = await _dio.delete(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      debugPrint('[SavedPlacesService] ✅ DELETE status: ${response.statusCode}');
    } catch (e) {
      debugPrint('[SavedPlacesService] ⚠️ Échec DELETE /v1/users/me/places/$id ($e)');
    }

    final current = await _getLocalSavedPlaces();
    final updated = current.where((p) => p.id != id).toList();
    await saveAll(updated);
    return updated;
  }
}
