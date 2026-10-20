import 'package:flutter/material.dart';
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
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            label: Text(
              'Message',
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
            icon: const Icon(
              Icons.phone_outlined,
              size: 18,
              color: AppColors.success,
            ),
            label: Text(
              'Appeler',
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
