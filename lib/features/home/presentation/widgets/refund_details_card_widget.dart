import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';

/// Reusable card displaying Orange Money refund confirmation with green refresh circle
class RefundDetailsCardWidget extends StatelessWidget {
  final String formattedAmount;
  final String transactionRef;

  const RefundDetailsCardWidget({
    super.key,
    required this.formattedAmount,
    required this.transactionRef,
  });

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          // Green refresh icon circle
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.refundContainerBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.refresh_rounded,
              color: AppColors.refundGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Amount and details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$formattedAmount ${'refund.refunded'.tr()}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'refund.on_orange_money'.tr(args: [transactionRef]),
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
