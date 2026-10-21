import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';

/// Reusable communication action buttons (Message and Call)
class DriverActionButtonsWidget extends StatelessWidget {
  final VoidCallback onMessagePressed;
  final VoidCallback onCallPressed;

  const DriverActionButtonsWidget({
    super.key,
    required this.onMessagePressed,
    required this.onCallPressed,
  });

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceGrey,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppConstants.radiusDefault,
                ),
              ),
            ),
            onPressed: onMessagePressed,
            icon: SvgPicture.asset(
              'assets/icons/message-square-lines-svgrepo-com.svg',
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(
                AppColors.primary,
                BlendMode.srcIn,
              ),
            ),
            label: Text(
              'common.message'.tr(),
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceGrey,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppConstants.radiusDefault,
                ),
              ),
            ),
            onPressed: onCallPressed,
            icon: SvgPicture.asset(
              'assets/icons/call-svgrepo-com.svg',
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(
                AppColors.primary,
                BlendMode.srcIn,
              ),
            ),
            label: Text(
              'common.call'.tr(),
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
