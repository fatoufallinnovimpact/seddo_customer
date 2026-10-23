import 'package:seddo/features/privacy/data/models/privacy_settings_model.dart';
import 'package:seddo/features/privacy/data/services/privacy_service.dart';

/// Repository for the Privacy feature.
/// Handles business logic and data access between BLoC and remote services.
/// Follows Innov & Impact Africa guidelines (data/repositories/).
class PrivacyRepository {
  final PrivacyService _service;

  PrivacyRepository({PrivacyService? service})
      : _service = service ?? PrivacyService();

  Future<PrivacySettingsModel> getPrivacySettings() {
    return _service.fetchPrivacySettings();
  }

  Future<bool> updatePrivacySettings(PrivacySettingsModel settings) {
    return _service.updatePrivacySettings(settings);
  }

  Future<bool> requestDataDownload() {
    return _service.requestDataDownload();
  }

  Future<bool> clearRideHistory() {
    return _service.clearRideHistory();
  }

  Future<bool> deleteAccount() {
    return _service.deleteAccount();
  }
}
