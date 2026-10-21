import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/driver_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/domain/models/ride_option_model.dart';
import 'package:seddo/features/home/presentation/widgets/safety_incident_report_sheet.dart';

/// Modern safety bottom sheet modal matching reference design:
/// - Vivid Seddo orange header with decorative wave arcs
/// - Concentric badge with security shield SVG icon
/// - Title "SÉCURITÉ DU TRAJET" & "On est là, 24h/24 et 7j/7"
/// - Overlapping Police (17) and SAMU (1515) cards with direct call buttons
/// - "Partager ma position d'urgence" with green location SVG icon & live indicator
/// - "Signaler un problème à Seddo" with orange headset icon
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
      backgroundColor: AppColors.transparent,
      builder: (ctx) => SafetyModalWidget(
        destination: destination,
        driver: driver,
      ),
    );
  }

  /// Opens safety modal with general emergency contacts (Police 17, SAMU 1515)
  static Future<void> showGeneral(BuildContext context) {
    return show(
      context,
      destination: const PlaceSearchResult(
        id: 'safety_home',
        mainText: 'Dakar',
        secondaryText: 'Sénégal',
        fullAddress: 'Dakar, Sénégal',
        latitude: 14.6937,
        longitude: -17.4440,
      ),
      driver: const DriverModel(
        id: 'safety_center',
        name: 'Centre de Sécurité Seddo',
        phone: '+221 77 123 45 12',
        rating: 5.0,
        totalRides: 1500,
        carModel: 'Assistance Sécurité',
        carColor: 'Orange',
        licensePlate: 'DK-0001-SN',
        rideType: RideType.eco,
        currentLocation: LatLng(14.6937, -17.4440),
        etaMinutes: 2,
        distanceKm: 0.5,
      ),
    );
  }

  Future<void> _dialNumber(String number) async {
    final clean = number.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (_) {}
    }
  }

  Future<void> _shareEmergencyLocation() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'URGENT - Trajet Seddo en cours vers ${destination.mainText} avec ${driver.name} (${driver.carModel} ${driver.licensePlate}). Suivi direct : https://suivi.seddo.sn/t/8K02F',
          subject: 'URGENCE - Suivi de trajet Seddo',
        ),
      );
    } catch (_) {}
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

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppConstants.radiusSheet),
      ),
      child: Container(
        color: AppColors.safetyCardBg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stack with Orange Header and Overlapping Emergency Cards
            Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Vivid Orange Header with concentric waves
                Container(
                  height: 175,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                  ),
                  child: Stack(
                    children: [
                      // Decorative ring 1
                      Positioned(
                        top: -50,
                        right: 30,
                        child: Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.white.withValues(alpha: 0.08),
                              width: 32,
                            ),
                          ),
                        ),
                      ),
                      // Decorative ring 2
                      Positioned(
                        top: 10,
                        left: -30,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.white.withValues(alpha: 0.08),
                              width: 24,
                            ),
                          ),
                        ),
                      ),

                      // Header Content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppConstants.spacingMd,
                          AppConstants.spacingUnit,
                          AppConstants.spacingMd,
                          0,
                        ),
                        child: Column(
                          children: [
                            // White translucent drag handle
                            Center(
                              child: Container(
                                width: AppConstants.circularIconContainerSize,
                                height: AppConstants.handleHeight,
                                decoration: BoxDecoration(
                                  color: AppColors.white.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(AppConstants.spacingHalf),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppConstants.spacingUnitXl),

                            // Badge + Title + Close Button
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Concentric Shield Badge
                                Container(
                                  width: 66,
                                  height: 66,
                                  decoration: BoxDecoration(
                                    color: AppColors.white.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4.5),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.white.withValues(alpha: 0.32),
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(4.5),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: AppColors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: SvgPicture.asset(
                                        'assets/icons/security-svgrepo-com.svg',
                                        width: 26,
                                        height: 26,
                                        colorFilter: const ColorFilter.mode(
                                          AppColors.primary,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppConstants.spacingUnitXl),

                                // Headline & Subtitle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _safeTr('safety.title', 'SÉCURITÉ DU\nTRAJET'),
                                        style: GoogleFonts.inter(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.white,
                                          height: 1.05,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      const SizedBox(height: AppConstants.spacingXs),
                                      Text(
                                        _safeTr('safety.subtitle', 'On est là, 24h/24 et 7j/7'),
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.white.withValues(alpha: 0.95),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Circular Close Button '✕'
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppColors.white.withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: AppColors.white,
                                      size: AppConstants.iconSizeMd,
                                    ),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Overlapping Emergency Cards (Police 17 & SAMU 1515)
                Padding(
                  padding: const EdgeInsets.only(
                    top: 112,
                    left: AppConstants.spacingMd,
                    right: AppConstants.spacingMd,
                  ),
                  child: Row(
                    children: [
                      // Police 17
                      Expanded(
                        child: _buildEmergencyCard(
                          context,
                          title: _safeTr('safety.police', 'Police'),
                          number: '17',
                          buttonColor: AppColors.pureBlack,
                          onTap: () => _dialNumber('17'),
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingUnitLg),

                      // SAMU 1515
                      Expanded(
                        child: _buildEmergencyCard(
                          context,
                          title: _safeTr('safety.samu', 'SAMU'),
                          number: '1515',
                          buttonColor: AppColors.sirenRed,
                          onTap: () => _dialNumber('1515'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 3. Modern Action Tiles
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                systemBottom > 0 ? systemBottom + 12 : 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Action 1: Partager ma position d'urgence
                  _buildModernActionTile(
                    iconWidget: SvgPicture.asset(
                      'assets/icons/location.svg',
                      width: AppConstants.iconSizeLg,
                      height: AppConstants.iconSizeLg,
                      colorFilter: const ColorFilter.mode(
                        AppColors.greenSuccess,
                        BlendMode.srcIn,
                      ),
                    ),
                    iconBgColor: AppColors.refundContainerBg,
                    title: _safeTr('safety.share_emergency', 'Partager ma position d\'urgence'),
                    subtitleWidget: Row(
                      children: [
                        Container(
                          width: AppConstants.spacingSeven,
                          height: AppConstants.spacingSeven,
                          decoration: const BoxDecoration(
                            color: AppColors.greenSuccess,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Expanded(
                          child: Text(
                            _safeTr('safety.share_emergency_sub', 'Envoyer le trajet à mes proches'),
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    onTap: _shareEmergencyLocation,
                  ),

                  const SizedBox(height: AppConstants.spacingUnitLg),

                  // Action 2: Signaler un problème à Seddo
                  _buildModernActionTile(
                    iconWidget: const Icon(
                      Icons.headphones_rounded,
                      color: AppColors.orangeDarkAccent,
                      size: AppConstants.iconSizeLg,
                    ),
                    iconBgColor: AppColors.orangeLightBg,
                    title: _safeTr('safety.report_problem', 'Signaler un problème à Seddo'),
                    subtitleText: _safeTr('safety.report_problem_sub', 'Notre équipe support vous répond'),
                    onTap: () {
                      Navigator.of(context).pop();
                      SafetyIncidentReportSheet.show(context, driver: driver);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyCard(
    BuildContext context, {
    required String title,
    required String number,
    required Color buttonColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusDialog),
        splashColor: buttonColor.withValues(alpha: 0.12),
        highlightColor: buttonColor.withValues(alpha: 0.06),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusDialog),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowCardBlack,
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: AppColors.cardBorder,
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Title + Circular Call Button with call SVG icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingS),
                  Container(
                    width: AppConstants.iconSizeXxl,
                    height: AppConstants.iconSizeXxl,
                    decoration: BoxDecoration(
                      color: buttonColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      'assets/icons/call-svgrepo-com.svg',
                      width: AppConstants.iconSizeSm,
                      height: AppConstants.iconSizeSm,
                      colorFilter: const ColorFilter.mode(
                        AppColors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingS),

              // Big Number (17 or 1515)
              Text(
                number,
                style: GoogleFonts.inter(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -1,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: AppConstants.spacingSm),

              // "Appeler" pill container
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingUnitXl,
                  vertical: AppConstants.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.peachContainer,
                  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                ),
                child: Text(
                  _safeTr('safety.call', 'Appeler'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernActionTile({
    required Widget iconWidget,
    required Color iconBgColor,
    required String title,
    String? subtitleText,
    Widget? subtitleWidget,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        splashColor: AppColors.primary.withValues(alpha: 0.1),
        highlightColor: AppColors.primary.withValues(alpha: 0.05),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(AppConstants.spacingUnitXl),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusCard),
            border: Border.all(
              color: AppColors.cardBorder,
              width: 1.1,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowSubtleBlack,
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: AppConstants.circularIconContainerSize,
                height: AppConstants.circularIconContainerSize,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                alignment: Alignment.center,
                child: iconWidget,
              ),
              const SizedBox(width: AppConstants.spacingUnitXl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingHalf),
                    if (subtitleWidget != null)
                      subtitleWidget
                    else if (subtitleText != null)
                      Text(
                        subtitleText,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
