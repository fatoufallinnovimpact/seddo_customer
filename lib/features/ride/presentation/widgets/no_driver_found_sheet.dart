import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/activity/presentation/widgets/refund_details_card_widget.dart';

enum NoDriverFoundAction {
  later,
  retry,
}

/// Bottom sheet modal displayed when no driver accepts or is found matching Screenshot 2:
/// - "Aucun chauffeur disponible"
/// - "Forte demande en ce moment autour de [lieu]."
/// - Refund notification card with green refresh icon, amount, and OM ref
/// - "Plus tard" button and "Réessayer" button
class NoDriverFoundSheet extends StatelessWidget {
  final PlaceSearchResult departure;
  final PlaceSearchResult destination;
  final RideOptionModel rideOption;
  final String transactionRef;

  const NoDriverFoundSheet({
    super.key,
    required this.departure,
    required this.destination,
    required this.rideOption,
    this.transactionRef = 'CI270415.1902.C4D1',
  });

  static Future<NoDriverFoundAction?> show(
    BuildContext context, {
    required PlaceSearchResult departure,
    required PlaceSearchResult destination,
    required RideOptionModel rideOption,
    String transactionRef = 'CI270415.1902.C4D1',
  }) {
    return showModalBottomSheet<NoDriverFoundAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => NoDriverFoundSheet(
        departure: departure,
        destination: destination,
        rideOption: rideOption,
        transactionRef: transactionRef,
      ),
    );
  }

  static String _safeTr(String key, String fallback) {
    try {
      final res = key.tr();
      if (res != key && res.isNotEmpty) return res;
    } catch (_) {}
    return fallback;
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
        systemBottom > 0 ? systemBottom + 12 : 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: AppConstants.circularIconContainerSize,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.dragHandle,
                borderRadius: BorderRadius.circular(AppConstants.radiusXs),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            _safeTr('ride.no_driver_title', 'Aucun chauffeur disponible'),
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle
          Text(
            'ride.high_demand_around'.tr(args: [departure.mainText]),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 20),

          // Refund Card
          RefundDetailsCardWidget(
            formattedAmount: rideOption.formattedPrice,
            transactionRef: transactionRef,
          ),

          const SizedBox(height: 24),

          // Action Buttons: Plus tard and Réessayer
          Row(
            children: [
              // Plus tard
              Expanded(
                child: SizedBox(
                  height: AppConstants.buttonHeight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cancelSecondaryBtnBg,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusLg,
                        ),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(NoDriverFoundAction.later);
                    },
                    child: Text(
                      _safeTr('common.later', 'Plus tard'),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Réessayer
              Expanded(
                child: SizedBox(
                  height: AppConstants.buttonHeight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusLg,
                        ),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(NoDriverFoundAction.retry);
                    },
                    child: Text(
                      _safeTr('common.retry', 'Réessayer'),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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
