import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/driver_model.dart';

/// Reusable driver summary card widget displaying driver initials, rating, vehicle, and "✓ Payé" badge
class ActiveDriverCardWidget extends StatelessWidget {
  final DriverModel driver;
  final bool isPaid;

  const ActiveDriverCardWidget({
    super.key,
    required this.driver,
    this.isPaid = true,
  });

  @override
  Widget build(BuildContext context) {
    final initials = driver.name.isNotEmpty
        ? driver.name
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'MS';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 1.1,
        ),
      ),
      child: Row(
        children: [
          // Initials circle avatar
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.avatarBeige,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Driver name, rating, vehicle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${driver.name.split(' ').first} · ★ ${driver.rating}',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${driver.carModel} · ${driver.licensePlate}',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // "✓ Payé" badge
          if (isPaid)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
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
                    size: 14,
                    color: AppColors.paidBadgeText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Payé',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.paidBadgeText,
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
