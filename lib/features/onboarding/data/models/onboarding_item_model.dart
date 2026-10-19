import 'package:flutter/material.dart';

/// Model representing a single onboarding presentation item with translation keys.
class OnboardingItemModel {
  final String titleKey;
  final String descriptionKey;
  final IconData icon;

  const OnboardingItemModel({
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
  });
}
