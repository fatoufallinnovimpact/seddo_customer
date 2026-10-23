import 'package:equatable/equatable.dart';
import 'package:seddo/features/safety/data/models/safety_contact_model.dart';

enum SafetyStatus { initial, loading, success, failure }

class SafetyState extends Equatable {
  final SafetyStatus status;
  final List<SafetyContactModel> contacts;
  final bool sosTriggered;
  final bool autoShare;
  final bool pinCode;
  final bool detourAlert;
  final String? errorMessage;
  final String? userFeedbackMessage;

  const SafetyState({
    this.status = SafetyStatus.initial,
    this.contacts = const [],
    this.sosTriggered = false,
    this.autoShare = false,
    this.pinCode = true,
    this.detourAlert = true,
    this.errorMessage,
    this.userFeedbackMessage,
  });

  SafetyState copyWith({
    SafetyStatus? status,
    List<SafetyContactModel>? contacts,
    bool? sosTriggered,
    bool? autoShare,
    bool? pinCode,
    bool? detourAlert,
    String? errorMessage,
    String? userFeedbackMessage,
    bool clearFeedback = false,
  }) {
    return SafetyState(
      status: status ?? this.status,
      contacts: contacts ?? this.contacts,
      sosTriggered: sosTriggered ?? this.sosTriggered,
      autoShare: autoShare ?? this.autoShare,
      pinCode: pinCode ?? this.pinCode,
      detourAlert: detourAlert ?? this.detourAlert,
      errorMessage: errorMessage ?? this.errorMessage,
      userFeedbackMessage: clearFeedback
          ? null
          : (userFeedbackMessage ?? this.userFeedbackMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        contacts,
        sosTriggered,
        autoShare,
        pinCode,
        detourAlert,
        errorMessage,
        userFeedbackMessage,
      ];
}
