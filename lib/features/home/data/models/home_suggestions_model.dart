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
    // 1. Extraire le nom du lieu (label / name / destination / placeName)
    final rawLabel = json['label'] ??
        json['name'] ??
        json['destination'] ??
        json['placeName'] ??
        '';

    // 2. Extraire fidèlement l'adresse telle que fournie par le backend
    // Ne pas copier le label dans l'adresse pour éviter de doubler "Dakar, Sénégal"
    final rawAddress = json['address'] ??
        json['destinationAddress'] ??
        json['fullAddress'] ??
        '';

    // 3. Extraire latitude et longitude (support num, string, ou nested location)
    double latVal = 0.0;
    double lngVal = 0.0;

    if (json['lat'] is num) {
      latVal = (json['lat'] as num).toDouble();
    } else if (json['latitude'] is num) {
      latVal = (json['latitude'] as num).toDouble();
    } else if (json['destinationLat'] is num) {
      latVal = (json['destinationLat'] as num).toDouble();
    } else if (json['location'] is Map) {
      final loc = json['location'] as Map;
      latVal = ((loc['lat'] ?? loc['latitude'] ?? 0.0) as num).toDouble();
      lngVal = ((loc['lng'] ?? loc['longitude'] ?? 0.0) as num).toDouble();
    }

    if (lngVal == 0.0) {
      if (json['lng'] is num) {
        lngVal = (json['lng'] as num).toDouble();
      } else if (json['longitude'] is num) {
        lngVal = (json['longitude'] as num).toDouble();
      } else if (json['destinationLng'] is num) {
        lngVal = (json['destinationLng'] as num).toDouble();
      }
    }

    final labelStr = rawLabel.toString().trim();
    final addressStr = rawAddress.toString().trim();

    String effectiveLabel = labelStr.isNotEmpty
        ? labelStr
        : (addressStr.isNotEmpty ? addressStr : 'Destination');
    String effectiveAddress = addressStr;

    // Si l'adresse est vide mais que le libellé contient des détails (ex: "Grand Yoff, 2527 Rue DD 98, Dakar")
    final isDakarSenegal = effectiveLabel.toLowerCase() == 'dakar, sénégal' ||
        effectiveLabel.toLowerCase() == 'dakar, senegal';

    if (effectiveAddress.isEmpty &&
        effectiveLabel.contains(',') &&
        !isDakarSenegal) {
      final parts = effectiveLabel.split(',');
      effectiveLabel = parts.first.trim();
      effectiveAddress = parts.sublist(1).join(',').trim();
    } else if (effectiveAddress.isEmpty &&
        !isDakarSenegal &&
        effectiveLabel.toLowerCase() != 'dakar') {
      effectiveAddress = 'Dakar, Sénégal';
    }

    return RecentSuggestionModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      label: effectiveLabel,
      address: effectiveAddress,
      lat: latVal,
      lng: lngVal,
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
    final cleanLabel = label.trim();
    final cleanAddress = address.trim();
    final isSame = cleanAddress.isNotEmpty &&
        cleanLabel.isNotEmpty &&
        cleanAddress.toLowerCase() == cleanLabel.toLowerCase();

    return PlaceSearchResult(
      id: id.isNotEmpty ? id : 'recent_${lat}_$lng',
      mainText: cleanLabel.isNotEmpty ? cleanLabel : cleanAddress,
      secondaryText: isSame ? '' : cleanAddress,
      fullAddress: cleanAddress.isNotEmpty ? cleanAddress : cleanLabel,
      latitude: lat,
      longitude: lng,
      category: 'recent',
    );
  }

  @override
  List<Object?> get props => [id, label, address, lat, lng];
}

/// Local persistent storage and in-memory cache for home suggestions
class HomeSuggestionsStorage {
  static const String _suggestionsKey = 'seddo_cached_home_suggestions';
  static HomeSuggestionsModel? _memorySuggestions;

  /// Synchronous memory cache available immediately on frame 0
  static HomeSuggestionsModel? get cachedSuggestions => _memorySuggestions;

  static Future<void> saveSuggestions(HomeSuggestionsModel model) async {
    _memorySuggestions = model;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_suggestionsKey, jsonEncode(model.toJson()));
    } catch (_) {}
  }

  static Future<HomeSuggestionsModel?> loadSuggestions() async {
    if (_memorySuggestions != null) return _memorySuggestions;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_suggestionsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final model = HomeSuggestionsModel.fromJson(decoded);
        _memorySuggestions = model;
        return model;
      }
    } catch (_) {}
    return null;
  }
}

/// Local storage for the user's recent trips history
class RecentTripStorage {
  static const String _key = 'seddo_last_recent_trip';
  static const String _historyKey = 'seddo_recent_trips_history';
  static List<RecentSuggestionModel>? _memoryRecentTrips;

  /// Synchronous memory cache for zero-latency retrieval
  static List<RecentSuggestionModel> get cachedRecentTrips =>
      _memoryRecentTrips ?? const [];

  static Future<void> saveLastRecentTrip(PlaceSearchResult place) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final effectiveAddress = place.fullAddress.isNotEmpty
          ? place.fullAddress
          : (place.secondaryText.trim().toLowerCase() != place.mainText.trim().toLowerCase()
              ? place.secondaryText
              : '');
      final data = {
        'id': place.id,
        'label': place.mainText,
        'address': effectiveAddress,
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
      _memoryRecentTrips = updated.take(10).toList();
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

      _memoryRecentTrips = result;
      return result;
    } catch (_) {
      return _memoryRecentTrips ?? [];
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
    _memoryRecentTrips = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      await prefs.remove(_historyKey);
    } catch (_) {}
  }
}

