import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/onboarding/presentation/pages/onboarding_page.dart';

/// Modal bottom sheet for logout confirmation matching the Crone project design:
/// - Slides in from bottom to top
/// - Red circular icon badge with logout SVG
/// - Bold title and explanatory subtitle
/// - "Annuler" outlined capsule button and "Se déconnecter" red capsule button
/// - Upon confirmation, clears backstack and redirects to OnboardingPage
class LogoutModal extends StatelessWidget {
  const LogoutModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => const LogoutModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusTwentyFour)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingMd,
        AppConstants.spacingLg,
        bottomPadding + AppConstants.spacingTwenty,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: AppConstants.handleWidth,
              height: AppConstants.handleHeight,
              decoration: BoxDecoration(
                color: AppColors.grayBorderDivider,
                borderRadius: BorderRadius.circular(AppConstants.radiusXs),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.radiusContainer),

          // Red circular icon badge
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.sirenLightBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/logout-line-svgrepo-com.svg',
                width: AppConstants.iconSizeXxl,
                height: AppConstants.iconSizeXxl,
                colorFilter: const ColorFilter.mode(
                  AppColors.sirenRed,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingTwenty),

          // Title
          Text(
            'drawer.logout_title'.tr(),
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppConstants.spacingUnit),

          // Subtitle
          Text(
            'drawer.logout_message'.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: AppConstants.radiusSheet),

          // Actions row (Annuler + Se déconnecter)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.white,
                    side: const BorderSide(
                      color: AppColors.grayBorderDivider,
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingUnitXl),
                  ),
                  child: Text(
                    'common.cancel'.tr(),
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingUnitLg),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      SlideRightToLeftRoute(page: const OnboardingPage()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sirenRed,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingUnitXl),
                    elevation: 0,
                  ),
                  child: Text(
                    'drawer.logout'.tr(),
                    style: GoogleFonts.inter(
                      color: AppColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
