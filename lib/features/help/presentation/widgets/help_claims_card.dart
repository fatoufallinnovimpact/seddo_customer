import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/help/presentation/pages/support_tickets_page.dart';

/// Card displayed on the Help page replacing the search bar:
/// Prompts the user to view and follow their support tickets / claims.
/// Tapping anywhere navigates to SupportTicketsPage.
class HelpClaimsCard extends StatelessWidget {
  const HelpClaimsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            SlideRightToLeftRoute(
              page: const SupportTicketsPage(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingMd,
          ),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusCard),
            border: Border.all(
              color: AppColors.grayBorderDivider,
              width: AppConstants.strokeWidthBorder,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowSubtleBlack,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Styled icon container
              Container(
                width: AppConstants.circularAvatarSize,
                height: AppConstants.circularAvatarSize,
                decoration: BoxDecoration(
                  color: AppColors.peachContainer,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSquircle),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                  size: AppConstants.iconSizeLg,
                ),
              ),
              const SizedBox(width: AppConstants.spacingUnitLg),

              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mes réclamations',
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontLg,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slateDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingXxs),
                    Text(
                      'Suivi de vos demandes et objets perdus',
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontSm,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Chevron forward
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: AppConstants.iconSizeSm,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
