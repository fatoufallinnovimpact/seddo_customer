import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/presentation/utils/vehicle_color_helper.dart';
import 'package:seddo/features/ride/presentation/widgets/driver_avatar_widget.dart';

/// Reusable driver summary card widget displaying driver photo/initials in grey circle, rating pill, full name, vehicle · color, and colored car + plate
class ActiveDriverCardWidget extends StatelessWidget {
  final DriverModel driver;
  final bool isPaid;
  final String? vehicleImagePath;
  final bool isOffline;
  final String? rideId;

  const ActiveDriverCardWidget({
    super.key,
    required this.driver,
    this.isPaid = true,
    this.vehicleImagePath,
    this.isOffline = false,
    this.rideId,
  });

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final ratingValue = driver.rating > 0 ? driver.rating : 4.9;
    final ratingDisplay =
        (ratingValue * 10 == (ratingValue * 10).roundToDouble())
            ? ratingValue.toStringAsFixed(1)
            : ratingValue.toStringAsFixed(2);

    final carColorStr = driver.carColor.trim();
    final carModelStr = driver.carModel.trim().isNotEmpty
        ? driver.carModel.trim()
        : 'Véhicule';
    final vehicleDescription = carColorStr.isNotEmpty
        ? '$carModelStr · $carColorStr'
        : carModelStr;
    final plateStr = driver.licensePlate.trim().replaceAll('-', ' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.grayBgSubtle,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Grey circle avatar (driver photo or black initials) + rating ★ pill at bottom
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                DriverAvatarWidget(
                  photoUrl: driver.photoUrl,
                  rideId: rideId,
                  name: driver.name,
                  size: 52,
                ),
                Positioned(
                  bottom: -7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadowSubtleBlack,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ratingDisplay,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: AppColors.amberRating,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Centre & Droite : Ligne 1 (Nom complet + Voiture colorée) et Ligne 2 (Modèle · Couleur aligné avec la plaque en bas de la voiture, sans se toucher)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              driver.name,
                              style: GoogleFonts.inter(
                                fontSize: 16.0,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOffline) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.grayLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Position non à jour',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.grayText,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (vehicleImagePath != null) ...[
                      const SizedBox(width: 8),
                      Builder(
                        builder: (context) {
                          final colorFilter =
                              VehicleColorHelper.getColorFilter(driver.carColor);
                          final isSvg =
                              vehicleImagePath!.toLowerCase().endsWith('.svg');
                          final img = isSvg
                              ? SizedBox(
                                  width: 84,
                                  height: 38,
                                  child: Transform.scale(
                                    scale: 1.36,
                                    child: SvgPicture.asset(
                                      vehicleImagePath!,
                                      width: 84,
                                      height: 38,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                )
                              : Image.asset(
                                  vehicleImagePath!,
                                  height: 36,
                                  width: 76,
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
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        vehicleDescription,
                        style: GoogleFonts.inter(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: AppColors.slateDark,
                          width: 1.1,
                        ),
                      ),
                      child: Text(
                        plateStr.isNotEmpty ? plateStr : 'DK 482 AB',
                        style: GoogleFonts.inter(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slateDark,
                          letterSpacing: 0.4,
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
