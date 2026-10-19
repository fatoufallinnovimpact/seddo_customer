import 'package:equatable/equatable.dart';

abstract class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when the user slides or moves to a specific page index.
class OnboardingPageChangedEvent extends OnboardingEvent {
  final int pageIndex;

  const OnboardingPageChangedEvent(this.pageIndex);

  @override
  List<Object?> get props => [pageIndex];
}

/// Triggered when the user toggles language (e.g. 'fr' or 'wo').
class OnboardingLanguageChangedEvent extends OnboardingEvent {
  final String languageCode;

  const OnboardingLanguageChangedEvent(this.languageCode);

  @override
  List<Object?> get props => [languageCode];
}

/// Triggered when user updates terms, privacy, or location consents.
class OnboardingConsentToggledEvent extends OnboardingEvent {
  final bool? termsAccepted;
  final bool? privacyAccepted;
  final bool? locationAccepted;

  const OnboardingConsentToggledEvent({
    this.termsAccepted,
    this.privacyAccepted,
    this.locationAccepted,
  });

  @override
  List<Object?> get props => [
        termsAccepted,
        privacyAccepted,
        locationAccepted,
      ];
}

/// Triggered when the user completes the onboarding process.
class OnboardingCompletedEvent extends OnboardingEvent {
  const OnboardingCompletedEvent();
}
