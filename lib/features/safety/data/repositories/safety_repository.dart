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

  Future<List<SafetyContactModel>> setEmergencyContacts(
    List<SafetyContactModel> contacts,
  ) {
    return _safetyService.setEmergencyContacts(contacts);
  }

  Future<List<SafetyContactModel>> addEmergencyContact(
    SafetyContactModel contact, [
    List<SafetyContactModel> currentList = const [],
  ]) {
    return _safetyService.addEmergencyContact(contact, currentList);
  }

  Future<List<SafetyContactModel>> deleteEmergencyContact(
    String id, [
    List<SafetyContactModel> currentList = const [],
  ]) {
    return _safetyService.deleteEmergencyContact(id, currentList);
  }

  Future<bool> triggerSosAlert({
    String? rideId,
    double? latitude,
    double? longitude,
  }) {
    return _safetyService.triggerSosAlert(
      rideId: rideId,
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
