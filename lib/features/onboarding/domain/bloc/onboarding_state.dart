import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:seddo/features/onboarding/data/models/onboarding_item_model.dart';

class OnboardingState extends Equatable {
  final int currentPage;
  final String selectedLanguage;
  final bool isTermsAccepted;
  final bool isPrivacyAccepted;
  final bool isLocationAccepted;
  final bool isConsentModalVisible;
  final bool isCompleted;
  final List<OnboardingItemModel> items;

  const OnboardingState({
    this.currentPage = 0,
    this.selectedLanguage = 'fr',
    this.isTermsAccepted = false,
    this.isPrivacyAccepted = false,
    this.isLocationAccepted = false,
    this.isConsentModalVisible = false,
    this.isCompleted = false,
    this.items = defaultItems,
  });

  /// Default 3 presentation slides for Seddo using easy_localization keys
  static const List<OnboardingItemModel> defaultItems = [
    OnboardingItemModel(
      titleKey: 'onboarding.slide1_title',
      descriptionKey: 'onboarding.slide1_desc',
      icon: Icons.directions_car_filled_rounded,
    ),
    OnboardingItemModel(
      titleKey: 'onboarding.slide2_title',
      descriptionKey: 'onboarding.slide2_desc',
      icon: Icons.verified_user_rounded,
    ),
    OnboardingItemModel(
      titleKey: 'onboarding.slide3_title',
      descriptionKey: 'onboarding.slide3_desc',
      icon: Icons.account_balance_wallet_rounded,
    ),
  ];

  /// User can only complete onboarding once all 3 consents are accepted
  bool get canProceed =>
      isTermsAccepted && isPrivacyAccepted && isLocationAccepted;

  bool get isLastPage => currentPage == items.length - 1;

  OnboardingState copyWith({
    int? currentPage,
    String? selectedLanguage,
    bool? isTermsAccepted,
    bool? isPrivacyAccepted,
    bool? locationAccepted,
    bool? isLocationAccepted,
    bool? isConsentModalVisible,
    bool? isCompleted,
    List<OnboardingItemModel>? items,
  }) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      isTermsAccepted: isTermsAccepted ?? this.isTermsAccepted,
      isPrivacyAccepted: isPrivacyAccepted ?? this.isPrivacyAccepted,
      isLocationAccepted: isLocationAccepted ?? this.isLocationAccepted,
      isConsentModalVisible:
          isConsentModalVisible ?? this.isConsentModalVisible,
      isCompleted: isCompleted ?? this.isCompleted,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [
        currentPage,
        selectedLanguage,
        isTermsAccepted,
        isPrivacyAccepted,
        isLocationAccepted,
        isConsentModalVisible,
        isCompleted,
        items,
      ];
}
