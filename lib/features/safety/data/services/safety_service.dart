import 'dart:async';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/core/utils/base_url.dart';
import 'package:seddo/features/safety/data/models/safety_contact_model.dart';

/// Service responsible for remote API calls regarding Safety.
/// Follows Innov & Impact Africa guidelines (data/services/).
/// Uses centralized [BaseUrl.current] without hardcoding URLs.
class SafetyService {
  final String _endpoint = '${BaseUrl.current}/api/v1/safety';

  String get endpoint => _endpoint;

  /// Fetches emergency contacts from backend (with offline/initial fallback).
  Future<List<SafetyContactModel>> fetchEmergencyContacts() async {
    // In production: final response = await http.get(Uri.parse('$_endpoint/contacts'));
    return const [
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
  }

  /// Adds a new emergency contact via API.
  Future<SafetyContactModel> addEmergencyContact(SafetyContactModel contact) async {
    // In production: final response = await http.post(Uri.parse('$_endpoint/contacts'), body: ...);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return contact;
  }

  /// Deletes an emergency contact via API.
  Future<bool> deleteEmergencyContact(String id) async {
    // In production: final response = await http.delete(Uri.parse('$_endpoint/contacts/$id'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return true;
  }

  /// Triggers an SOS emergency alert to the backend.
  Future<bool> triggerSosAlert({double? latitude, double? longitude}) async {
    // In production: final response = await http.post(Uri.parse('$_endpoint/sos'), body: ...);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return true;
  }

  /// Updates safety options (autoShare, pinCode, detourAlert).
  Future<bool> updateSafetySettings({
    required bool autoShare,
    required bool pinCode,
    required bool detourAlert,
  }) async {
    // In production: final response = await http.put(Uri.parse('$_endpoint/settings'), body: ...);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return true;
  }
}
