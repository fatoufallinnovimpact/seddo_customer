import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/presentation/utils/vehicle_color_helper.dart';

/// Reusable driver summary card widget displaying driver initials, rating, vehicle, and "✓ Payé" badge
class ActiveDriverCardWidget extends StatelessWidget {
  final DriverModel driver;
  final bool isPaid;
  final String? vehicleImagePath;

  const ActiveDriverCardWidget({
    super.key,
    required this.driver,
    this.isPaid = true,
    this.vehicleImagePath,
  });

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final initials = driver.name.isNotEmpty
        ? driver.name
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'MS';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Initials circle avatar with green verified badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.avatarBeige,
                      AppColors.avatarLightBeige,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    size: 14,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),

          // Driver name, rating, vehicle model & license plate
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${driver.name.split(' ').first} · ★ ${driver.rating}',
                        style: GoogleFonts.inter(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${driver.carModel} · ${driver.licensePlate}',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Vehicle thumbnail & "Payé" badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (vehicleImagePath != null)
                Builder(
                  builder: (context) {
                    final colorFilter =
                        VehicleColorHelper.getColorFilter(driver.carColor);
                    final img = Image.asset(
                      vehicleImagePath!,
                      height: 32,
                      width: 52,
                      fit: BoxFit.contain,
                    );
                    if (colorFilter != null) {
                      return ColorFiltered(
                        colorFilter: colorFilter,
                        child: img,
                      );
                    }
                    return img;
                  },
                ),
              if (isPaid) ...[
                if (vehicleImagePath != null) const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.paidBadgeBg,
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusPill,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: AppColors.paidBadgeText,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'ride.paid'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.paidBadgeText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
