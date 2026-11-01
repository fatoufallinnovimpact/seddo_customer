import 'package:equatable/equatable.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/safety/data/models/safety_contact_model.dart';

enum SafetyStatus { initial, loading, success, failure }

class SafetyState extends Equatable {
  final SafetyStatus status;
  final List<SafetyContactModel> contacts;
  final bool isUpdatingContacts;
  final bool isSendingSos;
  final bool sosTriggered;
  final bool autoShare;
  final bool pinCode;
  final bool detourAlert;
  final String? errorMessage;
  final String? userFeedbackMessage;

  const SafetyState({
    this.status = SafetyStatus.initial,
    this.contacts = const [],
    this.isUpdatingContacts = false,
    this.isSendingSos = false,
    this.sosTriggered = false,
    this.autoShare = false,
    this.pinCode = true,
    this.detourAlert = true,
    this.errorMessage,
    this.userFeedbackMessage,
  });

  bool get canAddContact => contacts.length < AppConstants.maxEmergencyContacts;

  SafetyState copyWith({
    SafetyStatus? status,
    List<SafetyContactModel>? contacts,
    bool? isUpdatingContacts,
    bool? isSendingSos,
    bool? sosTriggered,
    bool? autoShare,
    bool? pinCode,
    bool? detourAlert,
    String? errorMessage,
    String? userFeedbackMessage,
    bool clearFeedback = false,
    bool clearError = false,
  }) {
    return SafetyState(
      status: status ?? this.status,
      contacts: contacts ?? this.contacts,
      isUpdatingContacts: isUpdatingContacts ?? this.isUpdatingContacts,
      isSendingSos: isSendingSos ?? this.isSendingSos,
      sosTriggered: sosTriggered ?? this.sosTriggered,
      autoShare: autoShare ?? this.autoShare,
      pinCode: pinCode ?? this.pinCode,
      detourAlert: detourAlert ?? this.detourAlert,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      userFeedbackMessage: clearFeedback
          ? null
          : (userFeedbackMessage ?? this.userFeedbackMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        contacts,
        isUpdatingContacts,
        isSendingSos,
        sosTriggered,
        autoShare,
        pinCode,
        detourAlert,
        errorMessage,
        userFeedbackMessage,
      ];
}
