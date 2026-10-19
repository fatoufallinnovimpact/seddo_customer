import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/features/onboarding/domain/bloc/onboarding_bloc.dart';
import 'package:seddo/features/onboarding/domain/bloc/onboarding_event.dart';

void main() {
  group('OnboardingBloc', () {
    late OnboardingBloc bloc;

    setUp(() {
      bloc = OnboardingBloc();
    });

    tearDown(() {
      bloc.close();
    });

    test('initial state has default values', () {
      expect(bloc.state.currentPage, 0);
      expect(bloc.state.selectedLanguage, 'fr');
      expect(bloc.state.canProceed, isFalse);
    });

    test('changes page index on OnboardingPageChangedEvent', () {
      bloc.add(const OnboardingPageChangedEvent(2));
      expectLater(
        bloc.stream,
        emits(predicate<dynamic>((state) => state.currentPage == 2)),
      );
    });

    test('switches language on OnboardingLanguageChangedEvent', () {
      bloc.add(const OnboardingLanguageChangedEvent('wo'));
      expectLater(
        bloc.stream,
        emits(predicate<dynamic>((state) => state.selectedLanguage == 'wo')),
      );
    });

    test('canProceed becomes true when all 3 consents are accepted', () {
      bloc.add(const OnboardingConsentToggledEvent(
        termsAccepted: true,
        privacyAccepted: true,
        locationAccepted: true,
      ));
      expectLater(
        bloc.stream,
        emits(predicate<dynamic>((state) => state.canProceed == true)),
      );
    });

    test(
        'OnboardingCompletedEvent automatically accepts all consents and completes onboarding',
        () {
      bloc.add(const OnboardingCompletedEvent());
      expectLater(
        bloc.stream,
        emits(predicate<dynamic>((state) =>
            state.isCompleted == true &&
            state.isTermsAccepted == true &&
            state.isPrivacyAccepted == true &&
            state.isLocationAccepted == true &&
            state.canProceed == true)),
      );
    });
  });
}
