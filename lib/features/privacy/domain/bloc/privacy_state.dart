import 'package:equatable/equatable.dart';
import 'package:seddo/features/privacy/data/models/privacy_settings_model.dart';

enum PrivacyStatus { initial, loading, success, failure }

class PrivacyState extends Equatable {
  final PrivacyStatus status;
  final PrivacySettingsModel settings;
  final String? errorMessage;
  final String? feedbackMessageKey;

  const PrivacyState({
    this.status = PrivacyStatus.initial,
    this.settings = const PrivacySettingsModel(),
    this.errorMessage,
    this.feedbackMessageKey,
  });

  PrivacyState copyWith({
    PrivacyStatus? status,
    PrivacySettingsModel? settings,
    String? errorMessage,
    String? feedbackMessageKey,
    bool clearFeedback = false,
  }) {
    return PrivacyState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      errorMessage: errorMessage ?? this.errorMessage,
      feedbackMessageKey:
          clearFeedback ? null : (feedbackMessageKey ?? this.feedbackMessageKey),
    );
  }

  @override
  List<Object?> get props => [
        status,
        settings,
        errorMessage,
        feedbackMessageKey,
      ];
}
