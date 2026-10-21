import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';

/// Modal bottom sheet for SMS emergency when customer is offline (no internet connection).
/// Uses cellular GSM / SMS to reach emergency services or relatives with exact ride and GPS details.
class OfflineEmergencySheet extends StatelessWidget {
  final PlaceSearchResult destination;
  final DriverModel driver;
  final LatLng currentPosition;
  final String etaText;

  const OfflineEmergencySheet({
    super.key,
    required this.destination,
    required this.driver,
    required this.currentPosition,
    required this.etaText,
  });

  static Future<void> show(
    BuildContext context, {
    required PlaceSearchResult destination,
    required DriverModel driver,
    required LatLng currentPosition,
    required String etaText,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => OfflineEmergencySheet(
        destination: destination,
        driver: driver,
        currentPosition: currentPosition,
        etaText: etaText,
      ),
    );
  }

  String _buildEmergencyMessage() {
    final lat = currentPosition.latitude.toStringAsFixed(5);
    final lng = currentPosition.longitude.toStringAsFixed(5);
    return 'URGENCE SEDDO: Besoin d\'aide immédiate en cours de trajet vers ${destination.mainText}. '
        'Chauffeur: ${driver.name} (${driver.phone}), Véhicule: ${driver.carModel} [${driver.licensePlate}]. '
        'Dernière position GPS: Lat $lat, Lng $lng. https://maps.google.com/?q=$lat,$lng';
  }

  Future<void> _sendSms(BuildContext context, String recipient) async {
    final message = _buildEmergencyMessage();
    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse(
      recipient.isNotEmpty ? 'sms:$recipient?body=$encoded' : 'sms:?body=$encoded',
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Impossible d\'ouvrir l\'application SMS pour $recipient'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'envoyer le SMS vers $recipient'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri.parse('tel:$number');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final systemBottom = MediaQuery.of(context).padding.bottom;
    final messagePreview = _buildEmergencyMessage();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusSheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingUnitXl,
        AppConstants.spacingLg,
        systemBottom > 0 ? systemBottom + AppConstants.spacingUnitLg : AppConstants.spacingLg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: AppConstants.circularIconContainerSize,
                height: AppConstants.handleHeight,
                decoration: BoxDecoration(
                  color: AppColors.dragHandle,
                  borderRadius: BorderRadius.circular(AppConstants.radiusXs),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.radiusCard),

            // Header with caution mark SVG
            Row(
              children: [
                Container(
                  width: AppConstants.circularPickerSize,
                  height: AppConstants.circularPickerSize,
                  decoration: const BoxDecoration(
                    color: AppColors.errorLightBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    'assets/icons/caution-mark-8-svgrepo-com.svg',
                    width: AppConstants.spacingLg,
                    height: AppConstants.spacingLg,
                    colorFilter: const ColorFilter.mode(
                      AppColors.errorRed,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingUnitXl),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ride.sms_emergency'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingHalf),
                      Text(
                        'ride.sms_emergency_desc'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.radiusCard),

            // Cellular network notice banner
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingUnitLg),
              decoration: BoxDecoration(
                color: AppColors.grayBgSubtle,
                borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
                border: Border.all(color: AppColors.grayBorderDivider),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.signal_cellular_alt_rounded,
                    color: AppColors.primary,
                    size: AppConstants.iconSizeMd,
                  ),
                  const SizedBox(width: AppConstants.spacingUnit),
                  Expanded(
                    child: Text(
                      'ride.sms_cellular_notice'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.spacingMd),

            // Pre-composed SOS SMS Message preview
            Text(
              'ride.sms_preset_message'.tr(),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.spacingUnitLg),
              decoration: BoxDecoration(
                color: AppColors.emergencyAlertBg,
                borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
                border: Border.all(color: AppColors.emergencyAlertBorder),
              ),
              child: Text(
                messagePreview,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.emergencyAlertText,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: AppConstants.radiusCard),

            // Emergency SMS Services choices
            Text(
              'ride.send_alert_to'.tr(),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingUnit),

            // 1. Police Secours (17)
            _buildEmergencyOption(
              context: context,
              icon: Icons.local_police_rounded,
              iconBgColor: AppColors.policeBadgeBg,
              iconColor: AppColors.policeBadgeIcon,
              title: 'safety.police_17'.tr(),
              subtitle: 'safety.police_desc'.tr(),
              onTap: () => _sendSms(context, '17'),
            ),
            const SizedBox(height: AppConstants.spacingSm),

            // 2. Sapeurs-Pompiers (18)
            _buildEmergencyOption(
              context: context,
              icon: Icons.fire_truck_rounded,
              iconBgColor: AppColors.sirenLightBg,
              iconColor: AppColors.sirenRed,
              title: 'safety.firefighters_18'.tr(),
              subtitle: 'safety.firefighters_desc'.tr(),
              onTap: () => _sendSms(context, '18'),
            ),
            const SizedBox(height: AppConstants.spacingSm),

            // 3. SAMU (1515)
            _buildEmergencyOption(
              context: context,
              icon: Icons.emergency_rounded,
              iconBgColor: AppColors.hospitalBadgeBg,
              iconColor: AppColors.hospitalBadgeIcon,
              title: 'safety.samu_1515'.tr(),
              subtitle: 'safety.samu_desc'.tr(),
              onTap: () => _sendSms(context, '1515'),
            ),
            const SizedBox(height: AppConstants.spacingSm),

            // 4. Contact d'urgence (proche)
            _buildEmergencyOption(
              context: context,
              icon: Icons.person_pin_rounded,
              iconBgColor: AppColors.contactBadgeBg,
              iconColor: AppColors.contactBadgeIcon,
              title: 'safety.send_to_contact'.tr(),
              subtitle: 'safety.send_to_contact_desc'.tr(),
              onTap: () => _sendSms(context, ''),
            ),
            const SizedBox(height: AppConstants.radiusCard),

            // Direct Call option fallback
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.sirenRed,
                      side: const BorderSide(color: AppColors.sirenRed),
                      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingUnitLg),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
                      ),
                    ),
                    icon: const Icon(Icons.call, size: AppConstants.iconSizeDefault),
                    label: Text(
                      'safety.call_17'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () => _callNumber('17'),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingUnit),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceGrey,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'common.close'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyOption({
    required BuildContext context,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.send_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
