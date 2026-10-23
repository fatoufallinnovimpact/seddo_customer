import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';

/// Modal bottom sheet for insufficient balance matching Screenshot 2:
/// - Wallet icon in circular peach/red badge
/// - Title: "Solde insuffisant"
/// - Subtitle: "Rien n'a été débité de votre Orange Money."
/// - Info card with "Prix de la course" and "Il vous manque"
/// - Orange button: "Recharger avec Max it"
/// - Grey button: "Revenir au choix de la course"
class InsufficientBalanceSheet extends StatelessWidget {
  final RideOptionModel rideOption;
  final int missingAmount;

  const InsufficientBalanceSheet({
    super.key,
    required this.rideOption,
    this.missingAmount = 1200,
  });

  static Future<void> show(
    BuildContext context, {
    required RideOptionModel rideOption,
    int missingAmount = 1200,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => InsufficientBalanceSheet(
        rideOption: rideOption,
        missingAmount: missingAmount,
      ),
    );
  }

  String _formatCurrency(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(str[i]);
    }
    return '${buffer.toString()} F';
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final systemBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusSheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        12,
        AppConstants.spacingLg,
        systemBottom + AppConstants.spacingMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: AppConstants.circularIconContainerSize,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.dragHandle,
              borderRadius: BorderRadius.circular(AppConstants.radiusXs),
            ),
          ),
          const SizedBox(height: 24),

          // Wallet Icon inside soft circular container
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.walletContainerBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              size: 32,
              color: AppColors.walletIconColor,
            ),
          ),
          const SizedBox(height: 16),

          // Title: "Solde insuffisant"
          Text(
            'insufficient_balance.title'.tr(),
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle: "Rien n'a été débité de votre Orange Money."
          Text(
            'insufficient_balance.subtitle'.tr(),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Summary Card Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceGrey,
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            ),
            child: Column(
              children: [
                // Prix de la course
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'insufficient_balance.ride_price'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      rideOption.formattedPrice,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Il vous manque
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'insufficient_balance.missing_amount'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      _formatCurrency(missingAmount),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.walletIconColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Orange Button: Recharger avec Max it
          SizedBox(
            width: double.infinity,
            height: AppConstants.buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('insufficient_balance.opening_max_it'.tr()),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
              child: Text(
                'insufficient_balance.recharge_max_it'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Secondary Button: Revenir au choix de la course
          SizedBox(
            width: double.infinity,
            height: AppConstants.buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cancelSecondaryBtnBg,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'insufficient_balance.back_to_ride'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
