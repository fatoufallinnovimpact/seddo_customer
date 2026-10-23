import 'dart:async';
import 'package:seddo/core/utils/base_url.dart';
import 'package:seddo/features/privacy/data/models/privacy_settings_model.dart';

/// Remote API Service for Privacy & Data Management.
/// Follows Innov & Impact Africa guidelines (data/services/).
/// Uses [BaseUrl.current] without hardcoding URLs.
class PrivacyService {
  final String _endpoint = '${BaseUrl.current}/api/v1/privacy';

  String get endpoint => _endpoint;

  /// Fetches the user's current privacy settings.
  Future<PrivacySettingsModel> fetchPrivacySettings() async {
    // In production: final res = await http.get(Uri.parse('$_endpoint/settings'));
    return const PrivacySettingsModel();
  }

  /// Updates privacy preferences.
  Future<bool> updatePrivacySettings(PrivacySettingsModel settings) async {
    // In production: final res = await http.put(Uri.parse('$_endpoint/settings'), body: ...);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return true;
  }

  /// Requests a copy of user data to be sent by email within 48h.
  Future<bool> requestDataDownload() async {
    // In production: final res = await http.post(Uri.parse('$_endpoint/export'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return true;
  }

  /// Clears ride history.
  Future<bool> clearRideHistory() async {
    // In production: final res = await http.delete(Uri.parse('$_endpoint/history'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return true;
  }

  /// Initiates account deletion.
  Future<bool> deleteAccount() async {
    // In production: final res = await http.delete(Uri.parse('$_endpoint/account'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return true;
  }
}
