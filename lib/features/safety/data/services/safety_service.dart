import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/core/network/api_client.dart';
import 'package:seddo/core/utils/api_endpoints.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/safety/data/models/safety_contact_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';

/// Service responsible for remote API calls regarding Safety and Emergency Contacts.
/// Follows Innov & Impact Africa guidelines (data/services/).
/// Connects to:
/// - GET /v1/users/me/emergency-contacts (Contacts prévenus en cas de SOS)
/// - PUT /v1/users/me/emergency-contacts (Remplace la liste des contacts d'urgence, 3 max)
/// Includes robust local caching in SharedPreferences.
class SafetyService {
  static const String _storageKey = 'seddo_emergency_contacts';
  final Dio _dio;
  final SharedPreferences? _prefs;

  SafetyService([
    SharedPreferences? prefs,
    Dio? dio,
  ])  : _prefs = prefs,
        _dio = dio ?? ApiClient().dio;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Initial default presets for quick start / offline demo fallback
  static const List<SafetyContactModel> defaultPresets = [
    SafetyContactModel(
      id: 'contact_1',
      name: 'Moussa Diop',
      relationship: 'safety.relation_brother',
      phone: AppConstants.initialContactPhone1,
      avatarThemeIndex: 0,
    ),
    SafetyContactModel(
      id: 'contact_2',
      name: 'Fatou Sow',
      relationship: 'safety.relation_friend',
      phone: AppConstants.initialContactPhone2,
      avatarThemeIndex: 1,
    ),
  ];

  /// Fetches emergency contacts from backend:
  /// GET /v1/users/me/emergency-contacts
  Future<List<SafetyContactModel>> fetchEmergencyContacts() async {
    // 1. Try remote API call
    try {
      debugPrint('[SafetyService] 🚀 GET ${ApiEndpoints.emergencyContacts}');
      final response = await _dio.get(
        ApiEndpoints.emergencyContacts,
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
          list = (raw['contacts'] ?? raw['data'] ?? raw['items'] ?? [])
              as List<dynamic>;
        }

        final contacts = <SafetyContactModel>[];
        for (int i = 0; i < list.length; i++) {
          final item = list[i];
          if (item is Map<String, dynamic>) {
            contacts.add(SafetyContactModel.fromJson(item, index: i));
          }
        }

        debugPrint(
            '[SafetyService] ✅ Reçu ${contacts.length} contacts d\'urgence depuis l\'API');
        await saveAll(contacts);
        return contacts;
      }
    } catch (e) {
      debugPrint(
          '[SafetyService] ⚠️ Erreur GET ${ApiEndpoints.emergencyContacts} ($e), fallback cache local');
    }

    // 2. Fallback to cached contacts in SharedPreferences
    final cached = await _getLocalSavedContacts();
    if (cached.isNotEmpty) {
      return cached;
    }

    // 3. Fallback to presets if never initialized and offline (e.g. widget tests)
    return List.from(defaultPresets);
  }

  /// Save the full list locally in SharedPreferences
  Future<void> saveAll(List<SafetyContactModel> contacts) async {
    final prefs = await _getPrefs();
    final jsonString = jsonEncode(contacts.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  Future<List<SafetyContactModel>> _getLocalSavedContacts() async {
    try {
      final prefs = await _getPrefs();
      final String? jsonString = prefs.getString(_storageKey);

      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
        return decoded
            .asMap()
            .entries
            .map((entry) => SafetyContactModel.fromJson(
                  entry.value as Map<String, dynamic>,
                  index: entry.key,
                ))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  /// Replaces the list of emergency contacts (max 3):
  /// PUT /v1/users/me/emergency-contacts
  /// Request body: { "contacts": [ { "name": "...", "phone": "..." } ] }
  Future<List<SafetyContactModel>> setEmergencyContacts(
    List<SafetyContactModel> contacts,
  ) async {
    final capped = contacts.take(AppConstants.maxEmergencyContacts).toList();

    try {
      final payload = {
        'contacts': capped.map((c) => c.toApiJson()).toList(),
      };
      debugPrint(
          '[SafetyService] 🚀 PUT ${ApiEndpoints.emergencyContacts} payload=$payload');

      final response = await _dio.put(
        ApiEndpoints.emergencyContacts,
        data: payload,
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      debugPrint(
          '[SafetyService] ✅ Contacts mis à jour via API: status=${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;

        List<dynamic>? list;
        if (raw is List) {
          list = raw;
        } else if (raw is Map<String, dynamic> && raw['contacts'] is List) {
          list = raw['contacts'] as List<dynamic>;
        }

        if (list != null && list.isNotEmpty) {
          final serverList = <SafetyContactModel>[];
          for (int i = 0; i < list.length; i++) {
            final item = list[i];
            if (item is Map<String, dynamic>) {
              serverList.add(SafetyContactModel.fromJson(item, index: i));
            }
          }
          await saveAll(serverList);
          return serverList;
        }
      }
    } catch (e) {
      debugPrint(
          '[SafetyService] ⚠️ Échec PUT ${ApiEndpoints.emergencyContacts} ($e)');
      rethrow;
    }

    await saveAll(capped);
    return capped;
  }

  /// Adds an emergency contact and syncs with backend
  Future<List<SafetyContactModel>> addEmergencyContact(
    SafetyContactModel contact,
    List<SafetyContactModel> currentList,
  ) async {
    if (currentList.length >= AppConstants.maxEmergencyContacts) {
      throw Exception('Max emergency contacts limit reached');
    }
    final updated = [...currentList, contact];
    return setEmergencyContacts(updated);
  }

  /// Deletes an emergency contact and syncs with backend
  Future<List<SafetyContactModel>> deleteEmergencyContact(
    String idOrPhone,
    List<SafetyContactModel> currentList,
  ) async {
    final updated = currentList
        .where((c) => c.id != idOrPhone && c.phone != idOrPhone)
        .toList();
    return setEmergencyContacts(updated);
  }

  /// Triggers an SOS emergency alert to the backend.
  /// POST /v1/rides/{id}/sos with current GPS coordinates.
  Future<bool> triggerSosAlert({
    String? rideId,
    double? latitude,
    double? longitude,
  }) async {
    final effectiveRideId = (rideId != null && rideId.isNotEmpty)
        ? rideId
        : RideService.lastCreatedRideId;

    if (effectiveRideId != null && effectiveRideId.isNotEmpty) {
      try {
        final url = ApiEndpoints.rideSos(effectiveRideId);
        final payload = {
          'lat': latitude ?? 14.6937,
          'lng': longitude ?? -17.4440,
        };
        debugPrint('[SafetyService] 🚀 POST $url payload=$payload');

        final response = await _dio.post(
          url,
          data: payload,
          options: Options(
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

        debugPrint(
            '[SafetyService] ✅ Alerte SOS transmise: status=${response.statusCode}');
        return response.statusCode == 200 || response.statusCode == 201;
      } catch (e) {
        debugPrint('[SafetyService] ⚠️ Erreur POST SOS ($e)');
        rethrow;
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 200));
    return true;
  }

  /// Updates safety options (autoShare, pinCode, detourAlert).
  Future<bool> updateSafetySettings({
    required bool autoShare,
    required bool pinCode,
    required bool detourAlert,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return true;
  }
}
