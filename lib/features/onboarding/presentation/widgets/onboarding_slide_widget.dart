import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/onboarding/data/models/onboarding_item_model.dart';

/// Single presentation slide content for onboarding using easy_localization.
class OnboardingSlideWidget extends StatelessWidget {
  final OnboardingItemModel item;

  const OnboardingSlideWidget({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration / Icon card container
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.surfaceGrey,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withAlpha(30),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(25),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                item.icon,
                size: 80,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingXxl),

          // Title (Oswald condensed style as requested in design spec)
          Text(
            item.titleKey.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.oswald(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.25,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Description (Inter body text)
          Text(
            item.descriptionKey.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
