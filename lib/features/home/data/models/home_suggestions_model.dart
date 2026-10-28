import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/saved_places/data/models/saved_place_model.dart';

/// Response model for GET /v1/users/me/suggestions
/// Suggestions de l'accueil : lieux enregistrés et destinations récentes.
/// Schema: { "places": [ ... ], "recent": [ ... ] }
class HomeSuggestionsModel extends Equatable {
  final List<SavedPlaceModel> places;
  final List<RecentSuggestionModel> recent;

  const HomeSuggestionsModel({
    this.places = const [],
    this.recent = const [],
  });

  bool get isEmpty => places.isEmpty && recent.isEmpty;
  bool get isNotEmpty => !isEmpty;

  factory HomeSuggestionsModel.fromJson(Map<String, dynamic> json) {
    final rawPlaces = (json['places'] as List?) ?? [];
    final rawRecent = (json['recent'] as List?) ?? [];

    return HomeSuggestionsModel(
      places: rawPlaces
          .whereType<Map<String, dynamic>>()
          .map(SavedPlaceModel.fromJson)
          .toList(),
      recent: rawRecent
          .whereType<Map<String, dynamic>>()
          .map(RecentSuggestionModel.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'places': places.map((p) => p.toJson()).toList(),
      'recent': recent.map((r) => r.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [places, recent];
}

/// Represents a recent destination from GET /v1/users/me/suggestions
class RecentSuggestionModel extends Equatable {
  final String id;
  final String label;
  final String address;
  final double lat;
  final double lng;

  const RecentSuggestionModel({
    required this.id,
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
  });

  factory RecentSuggestionModel.fromJson(Map<String, dynamic> json) {
    final labelVal =
        (json['label'] ?? json['name'] ?? json['address'] ?? 'Destination')
            as String;
    final addressVal = (json['address'] ?? json['label'] ?? '') as String;
    final latNum = (json['lat'] ?? json['latitude'] ?? 0.0) as num;
    final lngNum = (json['lng'] ?? json['longitude'] ?? 0.0) as num;

    return RecentSuggestionModel(
      id: (json['id'] ?? '').toString(),
      label: labelVal,
      address: addressVal,
      lat: latNum.toDouble(),
      lng: lngNum.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'address': address,
      'lat': lat,
      'lng': lng,
    };
  }

  PlaceSearchResult toPlaceSearchResult() {
    return PlaceSearchResult(
      id: id.isNotEmpty ? id : 'recent_${lat}_$lng',
      mainText: label.isNotEmpty ? label : address,
      secondaryText: address,
      fullAddress: address.isNotEmpty ? address : label,
      latitude: lat,
      longitude: lng,
      category: 'recent',
    );
  }

  @override
  List<Object?> get props => [id, label, address, lat, lng];
}

/// Local storage for the user's recent trips history
class RecentTripStorage {
  static const String _key = 'seddo_last_recent_trip';
  static const String _historyKey = 'seddo_recent_trips_history';

  static Future<void> saveLastRecentTrip(PlaceSearchResult place) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'id': place.id,
        'label': place.mainText,
        'address': place.fullAddress.isNotEmpty
            ? place.fullAddress
            : (place.secondaryText.isNotEmpty ? place.secondaryText : place.mainText),
        'lat': place.latitude,
        'lng': place.longitude,
      };
      await prefs.setString(_key, jsonEncode(data));

      // Mettre à jour la liste complète des trajets récents
      final existing = await getRecentTrips();
      final updated = <RecentSuggestionModel>[
        RecentSuggestionModel.fromJson(data),
      ];
      for (final item in existing) {
        final isDuplicate = (item.id.isNotEmpty && item.id == place.id) ||
            (item.label == place.mainText &&
                item.address == (place.fullAddress.isNotEmpty ? place.fullAddress : place.secondaryText)) ||
            ((item.lat - place.latitude).abs() < 0.0001 &&
                (item.lng - place.longitude).abs() < 0.0001);
        if (!isDuplicate) {
          updated.add(item);
        }
      }
      final toSave = updated.take(10).map((e) => e.toJson()).toList();
      await prefs.setString(_historyKey, jsonEncode(toSave));
    } catch (_) {}
  }

  static Future<List<RecentSuggestionModel>> getRecentTrips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<RecentSuggestionModel> result = [];

      final rawHistory = prefs.getString(_historyKey);
      if (rawHistory != null && rawHistory.isNotEmpty) {
        final decoded = jsonDecode(rawHistory) as List<dynamic>;
        for (final entry in decoded) {
          if (entry is Map<String, dynamic>) {
            final item = RecentSuggestionModel.fromJson(entry);
            if (item.id != 'recent_1' && item.id != 'preset_almadies') {
              result.add(item);
            }
          }
        }
      }

      // Compléter si _key contient un trajet non présent dans l'historique
      final singleRaw = prefs.getString(_key);
      if (singleRaw != null && singleRaw.isNotEmpty) {
        final decoded = jsonDecode(singleRaw) as Map<String, dynamic>;
        final singleItem = RecentSuggestionModel.fromJson(decoded);
        if (singleItem.id != 'recent_1' && singleItem.id != 'preset_almadies') {
          if (!result.any((r) =>
              r.id == singleItem.id ||
              (r.label == singleItem.label && r.address == singleItem.address))) {
            result.insert(0, singleItem);
          }
        }
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  static Future<RecentSuggestionModel?> getLastRecentTrip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final item = RecentSuggestionModel.fromJson(decoded);
        if (item.id == 'recent_1' || item.id == 'preset_almadies') {
          await prefs.remove(_key);
          return null;
        }
        return item;
      }
      final list = await getRecentTrips();
      return list.isNotEmpty ? list.first : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearLastRecentTrip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      await prefs.remove(_historyKey);
    } catch (_) {}
  }
}

