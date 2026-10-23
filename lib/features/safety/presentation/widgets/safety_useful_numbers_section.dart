import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:url_launcher/url_launcher.dart';

class SafetyUsefulNumbersSection extends StatelessWidget {
  const SafetyUsefulNumbersSection({super.key});

  Future<void> _makeCall(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'safety.section_useful_numbers'.tr(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildNumberCard(
                label: 'safety.police_label'.tr(),
                number: AppConstants.emergencyPoliceNumber,
                color: AppColors.usefulNumberPoliceBlue,
                icon: Icons.local_police_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildNumberCard(
                label: 'safety.pompiers_label'.tr(),
                number: AppConstants.emergencyPompiersNumber,
                color: AppColors.usefulNumberPompiersRed,
                icon: Icons.fire_truck_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildNumberCard(
                label: 'safety.samu_label'.tr(),
                number: AppConstants.emergencySamuNumber,
                color: AppColors.usefulNumberSamuGreen,
                icon: Icons.medical_services_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberCard({
    required String label,
    required String number,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusCardContainer),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.radiusCardContainer),
          onTap: () => _makeCall(number),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppConstants.usefulNumberCardPaddingV,
              horizontal: AppConstants.usefulNumberCardPaddingH,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(height: 8),
                Text(
                  number,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
