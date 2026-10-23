import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';

enum ServiceUnavailableAction {
  notifyMe,
  changeDestination,
}

/// Bottom sheet modal displayed when the user is located in or selects an unsupported area
/// outside Dakar (e.g. Thiès, Mbour, Touba, Saint-Louis):
/// - Location badge with pin icon: "[ 📍 Thiès ]"
/// - Title: "Seddo n'est pas encore disponible ici"
/// - Subtitle: "Seddo roule à Dakar, Pikine, Guédiawaye, Rufisque et vers l'aéroport AIBD."
/// - Primary Black button: "Me prévenir à l'ouverture" with bell icon
/// - Secondary Sand button: "Changer de destination"
class ServiceUnavailableSheet extends StatelessWidget {
  final String cityName;
  final VoidCallback? onNotifyMe;
  final VoidCallback? onChangeDestination;

  const ServiceUnavailableSheet({
    super.key,
    this.cityName = 'Thiès',
    this.onNotifyMe,
    this.onChangeDestination,
  });

  static Future<ServiceUnavailableAction?> show(
    BuildContext context, {
    String cityName = 'Thiès',
    VoidCallback? onNotifyMe,
    VoidCallback? onChangeDestination,
  }) {
    return showModalBottomSheet<ServiceUnavailableAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => ServiceUnavailableSheet(
        cityName: cityName,
        onNotifyMe: onNotifyMe,
        onChangeDestination: onChangeDestination,
      ),
    );
  }

  void _handleNotifyMe(BuildContext context) {
    if (onNotifyMe != null) {
      onNotifyMe!();
    } else {
      Navigator.of(context).pop(ServiceUnavailableAction.notifyMe);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.offlineDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
          ),
          content: Text(
            'service_unavailable.notified_snack'.tr(args: [cityName]),
            style: GoogleFonts.inter(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
  }

  void _handleChangeDestination(BuildContext context) {
    if (onChangeDestination != null) {
      onChangeDestination!();
    } else {
      Navigator.of(context).pop(ServiceUnavailableAction.changeDestination);
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final systemBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusTwentyFour),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppConstants.spacingTwenty,
        AppConstants.spacingUnitLg,
        AppConstants.spacingTwenty,
        systemBottom > 0 ? systemBottom + AppConstants.spacingUnitLg : AppConstants.spacingLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Drag Handle
          Center(
            child: Container(
              width: AppConstants.circularIconContainerSize,
              height: AppConstants.handleHeight,
              decoration: BoxDecoration(
                color: AppColors.slateBorder,
                borderRadius: BorderRadius.circular(AppConstants.radiusXs),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spacingMd),

          // 2. City Location Badge (e.g. "[ 📍 Thiès ]")
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingUnit,
              vertical: AppConstants.spacingFive,
            ),
            decoration: BoxDecoration(
              color: AppColors.grayBgLight,
              borderRadius: BorderRadius.circular(AppConstants.radiusDialog),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: AppConstants.iconSizeSm,
                  color: AppColors.slateDark,
                ),
                const SizedBox(width: AppConstants.spacingFive),
                Text(
                  cityName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slateDark,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.spacingUnitLg),

          // 3. Title: "Seddo n'est pas encore disponible ici"
          Text(
            'service_unavailable.title'.tr(),
            style: GoogleFonts.inter(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: AppColors.slateDark,
              letterSpacing: -0.4,
              height: 1.18,
            ),
          ),

          const SizedBox(height: AppConstants.spacingSm),

          // 4. Subtitle: "Seddo roule à Dakar, Pikine, Guédiawaye, Rufisque et vers l'aéroport AIBD."
          Text(
            'service_unavailable.subtitle'.tr(),
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: AppColors.slateMuted,
              height: 1.35,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: AppConstants.spacingTwenty),

          // 5. Primary Button: "Me prévenir à l'ouverture"
          SizedBox(
            width: double.infinity,
            height: AppConstants.buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.offlineDark,
                foregroundColor: AppColors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                ),
              ),
              onPressed: () => _handleNotifyMe(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    size: AppConstants.iconSizeMd,
                    color: AppColors.white,
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Flexible(
                    child: Text(
                      'service_unavailable.notify_me'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spacingUnit),

          // 6. Secondary Button: "Changer de destination"
          SizedBox(
            width: double.infinity,
            height: AppConstants.buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonSecondaryBeige,
                foregroundColor: AppColors.slateDark,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                ),
              ),
              onPressed: () => _handleChangeDestination(context),
              child: Text(
                'service_unavailable.change_destination'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slateDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
