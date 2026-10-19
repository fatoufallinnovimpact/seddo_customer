import 'package:flutter/material.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';

/// Animated page dot indicators for onboarding slides.
class OnboardingIndicatorsWidget extends StatelessWidget {
  final int count;
  final int currentIndex;

  const OnboardingIndicatorsWidget({
    super.key,
    required this.count,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final bool isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXs),
          height: 8,
          width: isActive ? 28 : 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.inactiveIndicator,
            borderRadius: BorderRadius.circular(AppConstants.radiusPill),
          ),
        );
      }),
    );
  }
}
