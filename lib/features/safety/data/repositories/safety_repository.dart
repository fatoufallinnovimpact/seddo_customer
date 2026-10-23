import 'package:seddo/features/safety/data/models/safety_contact_model.dart';
import 'package:seddo/features/safety/data/services/safety_service.dart';

/// Repository for the Safety feature.
/// Handles business logic and data access between BLoC and remote/local services.
/// Follows Innov & Impact Africa guidelines (data/repositories/).
class SafetyRepository {
  final SafetyService _safetyService;

  SafetyRepository({SafetyService? safetyService})
      : _safetyService = safetyService ?? SafetyService();

  Future<List<SafetyContactModel>> getEmergencyContacts() {
    return _safetyService.fetchEmergencyContacts();
  }

  Future<SafetyContactModel> addEmergencyContact(SafetyContactModel contact) {
    return _safetyService.addEmergencyContact(contact);
  }

  Future<bool> deleteEmergencyContact(String id) {
    return _safetyService.deleteEmergencyContact(id);
  }

  Future<bool> triggerSosAlert({double? latitude, double? longitude}) {
    return _safetyService.triggerSosAlert(
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<bool> updateSafetySettings({
    required bool autoShare,
    required bool pinCode,
    required bool detourAlert,
  }) {
    return _safetyService.updateSafetySettings(
      autoShare: autoShare,
      pinCode: pinCode,
      detourAlert: detourAlert,
    );
  }
}
