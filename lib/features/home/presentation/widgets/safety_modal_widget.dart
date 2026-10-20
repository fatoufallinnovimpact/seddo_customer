import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/widgets/safety_incident_report_sheet.dart';

/// Bottom sheet modal displayed when tapping the red siren button or "Sécurité" tile:
/// - Emergency dialer for Police (17) and SAMU (1515)
/// - One-tap location sharing with emergency contacts via Share
/// - Direct reporting to Seddo support
class SafetyModalWidget extends StatelessWidget {
  final PlaceSearchResult destination;
  final DriverModel driver;

  const SafetyModalWidget({
    super.key,
    required this.destination,
    required this.driver,
  });

  static Future<void> show(
    BuildContext context, {
    required PlaceSearchResult destination,
    required DriverModel driver,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafetyModalWidget(
        destination: destination,
        driver: driver,
      ),
    );
  }

  Future<void> _dialNumber(String number) async {
    final uri = Uri.parse('tel:$number');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<void> _shareEmergencyLocation() async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            'URGENT - Trajet Seddo en cours vers ${destination.mainText} avec ${driver.name} (${driver.carModel} ${driver.licensePlate}). Suivi direct : https://suivi.seddo.sn/t/8K02F',
        subject: 'URGENCE - Suivi de trajet Seddo',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        14,
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
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.walletContainerBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.shield_rounded,
                  color: AppColors.sirenRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sécurité du trajet',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Assistance immédiate 24h/24 et 7j/7',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Action 1: Police 17
          _buildActionTile(
            context,
            icon: Icons.local_police_rounded,
            iconColor: AppColors.sirenRed,
            iconBg: AppColors.walletContainerBg,
            title: 'Appeler la Police (17)',
            subtitle: 'En cas d\'urgence ou situation suspecte',
            onTap: () => _dialNumber('17'),
          ),

          const SizedBox(height: 10),

          // Action 2: SAMU 1515
          _buildActionTile(
            context,
            icon: Icons.emergency_rounded,
            iconColor: AppColors.sirenRed,
            iconBg: AppColors.walletContainerBg,
            title: 'Appeler les Secours / SAMU (1515)',
            subtitle: 'Urgence médicale ou accident',
            onTap: () => _dialNumber('1515'),
          ),

          const SizedBox(height: 10),

          // Action 3: Partager position
          _buildActionTile(
            context,
            icon: Icons.share_location_rounded,
            iconColor: AppColors.primary,
            iconBg: AppColors.peachContainer,
            title: 'Partager ma position d\'urgence',
            subtitle: 'Envoyer les détails du trajet à mes proches',
            onTap: _shareEmergencyLocation,
          ),

          const SizedBox(height: 10),

          // Action 4: Signaler un incident
          _buildActionTile(
            context,
            icon: Icons.headset_mic_rounded,
            iconColor: AppColors.textPrimary,
            iconBg: AppColors.surfaceGrey,
            title: 'Signaler un problème à Seddo',
            subtitle: 'Notre équipe support vous assiste',
            onTap: () {
              Navigator.of(context).pop();
              SafetyIncidentReportSheet.show(context, driver: driver);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusCard),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
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
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
