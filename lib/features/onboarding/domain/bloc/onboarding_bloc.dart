import 'package:flutter_bloc/flutter_bloc.dart';
import 'onboarding_event.dart';
import 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc() : super(const OnboardingState()) {
    on<OnboardingPageChangedEvent>(_onPageChanged);
    on<OnboardingLanguageChangedEvent>(_onLanguageChanged);
    on<OnboardingConsentToggledEvent>(_onConsentToggled);
    on<OnboardingCompletedEvent>(_onCompleted);
  }

  void _onPageChanged(
    OnboardingPageChangedEvent event,
    Emitter<OnboardingState> emit,
  ) {
    emit(state.copyWith(currentPage: event.pageIndex));
  }

  void _onLanguageChanged(
    OnboardingLanguageChangedEvent event,
    Emitter<OnboardingState> emit,
  ) {
    emit(state.copyWith(selectedLanguage: event.languageCode));
  }

  void _onConsentToggled(
    OnboardingConsentToggledEvent event,
    Emitter<OnboardingState> emit,
  ) {
    emit(state.copyWith(
      isTermsAccepted: event.termsAccepted ?? state.isTermsAccepted,
      isPrivacyAccepted: event.privacyAccepted ?? state.isPrivacyAccepted,
      isLocationAccepted: event.locationAccepted ?? state.isLocationAccepted,
    ));
  }

  void _onCompleted(
    OnboardingCompletedEvent event,
    Emitter<OnboardingState> emit,
  ) {
    emit(state.copyWith(
      isTermsAccepted: true,
      isPrivacyAccepted: true,
      isLocationAccepted: true,
      isCompleted: true,
    ));
  }
}
