import 'dart:convert';
import 'package:seddo/core/utils/base_url.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/features/saved_places/data/models/saved_place_model.dart';

/// Service responsible for managing user's saved favorite locations with local persistence
/// and ready to sync with remote API.
class SavedPlacesService {
  static const String _storageKey = 'seddo_saved_places';
  final SharedPreferences? _prefs;
  final String baseUrl;

  SavedPlacesService([this._prefs, String? baseUrl])
      : baseUrl = baseUrl ?? BaseUrl.current;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Initial default presets for quick start
  static final List<SavedPlaceModel> defaultPresets = [
    const SavedPlaceModel(
      id: 'preset_home',
      name: 'Maison',
      address: 'Les Almadies, Ngor, Dakar',
      latitude: 14.7431,
      longitude: -17.5195,
      iconType: 'home',
    ),
    const SavedPlaceModel(
      id: 'preset_work',
      name: 'Travail',
      address: 'Plateau, rue Carnot, Dakar',
      latitude: 14.6720,
      longitude: -17.4330,
      iconType: 'work',
    ),
    const SavedPlaceModel(
      id: 'preset_airport',
      name: 'Aéroport AIBD',
      address: 'Aéroport International Blaise Diagne, Diass',
      latitude: 14.6710,
      longitude: -17.0730,
      iconType: 'airport',
    ),
  ];

  /// Retrieve all saved places
  Future<List<SavedPlaceModel>> getSavedPlaces() async {
    try {
      final prefs = await _getPrefs();
      final String? jsonString = prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        // First launch: initialize with defaults and save
        await saveAll(defaultPresets);
        return List.from(defaultPresets);
      }

      final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
      return decoded
          .map((item) => SavedPlaceModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return List.from(defaultPresets);
    }
  }

  /// Save the full list
  Future<void> saveAll(List<SavedPlaceModel> places) async {
    final prefs = await _getPrefs();
    final jsonString = jsonEncode(places.map((p) => p.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  /// Add a new saved place (prepends to the list)
  Future<List<SavedPlaceModel>> addSavedPlace(SavedPlaceModel place) async {
    final current = await getSavedPlaces();
    final updated = [place, ...current.where((p) => p.id != place.id)];
    await saveAll(updated);
    return updated;
  }

  /// Update an existing saved place
  Future<List<SavedPlaceModel>> updateSavedPlace(SavedPlaceModel updatedPlace) async {
    final current = await getSavedPlaces();
    final updated = current.map((p) {
      return p.id == updatedPlace.id ? updatedPlace : p;
    }).toList();
    await saveAll(updated);
    return updated;
  }

  /// Delete a saved place by id
  Future<List<SavedPlaceModel>> deleteSavedPlace(String id) async {
    final current = await getSavedPlaces();
    final updated = current.where((p) => p.id != id).toList();
    await saveAll(updated);
    return updated;
  }
}
