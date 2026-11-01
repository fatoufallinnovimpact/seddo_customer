import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/safety/domain/bloc/safety_bloc.dart';

/// Bottom sheet dialog for SOS Emergency Alert during an active ride:
/// Connects to POST /v1/rides/{id}/sos
/// "Bouton SOS : alerte immédiate au backoffice avec la position."
/// - Immediate alert to Seddo backoffice with live GPS position
/// - 1-tap direct call to Police 17 & SAMU 1515
/// - Uses SafetyBloc or RideService with robust error handling
class RideSosBottomSheet extends StatefulWidget {
  final String rideId;
  final LatLng currentPosition;
  final PlaceSearchResult destination;
  final DriverModel driver;
  final VoidCallback? onSosTriggered;

  const RideSosBottomSheet({
    super.key,
    required this.rideId,
    required this.currentPosition,
    required this.destination,
    required this.driver,
    this.onSosTriggered,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String rideId,
    required LatLng currentPosition,
    required PlaceSearchResult destination,
    required DriverModel driver,
    VoidCallback? onSosTriggered,
  }) {
    // Check if SafetyBloc is already provided in the parent context
    SafetyBloc? safetyBloc;
    try {
      safetyBloc = context.read<SafetyBloc>();
    } catch (_) {
      safetyBloc = null;
    }

    final sheet = RideSosBottomSheet(
      rideId: rideId,
      currentPosition: currentPosition,
      destination: destination,
      driver: driver,
      onSosTriggered: onSosTriggered,
    );

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) {
        if (safetyBloc != null) {
          return BlocProvider.value(
            value: safetyBloc,
            child: sheet,
          );
        }
        return BlocProvider(
          create: (_) => SafetyBloc(),
          child: sheet,
        );
      },
    );
  }

  @override
  State<RideSosBottomSheet> createState() => _RideSosBottomSheetState();
}

class _RideSosBottomSheetState extends State<RideSosBottomSheet> {
  bool _isLoading = false;
  bool _isSuccess = false;

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

  Future<void> _triggerSos(BuildContext context) async {
    if (_isLoading || _isSuccess) return;

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final safetyBloc = context.read<SafetyBloc>();

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Dispatch BLoC event
      safetyBloc.add(
        SafetySosTriggered(
          rideId: widget.rideId,
          latitude: widget.currentPosition.latitude,
          longitude: widget.currentPosition.longitude,
        ),
      );

      // 2. Also ensure direct backend service call for immediate dispatch
      final service = RideService();
      await service.sendSosAlert(
        rideId: widget.rideId,
        latitude: widget.currentPosition.latitude,
        longitude: widget.currentPosition.longitude,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });

        widget.onSosTriggered?.call();

        // Auto close after 2.2 seconds of success display
        Future.delayed(const Duration(milliseconds: 2200), () {
          if (mounted) {
            nav.pop(true);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              style: GoogleFonts.inter(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: AppColors.sirenRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: AppConstants.circularIconContainerSize,
              height: AppConstants.handleHeight,
              decoration: BoxDecoration(
                color: AppColors.grayBorderDivider,
                borderRadius: BorderRadius.circular(AppConstants.spacingHalf),
              ),
            ),
          ),

          // Header with Red Siren Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingLg,
              AppConstants.spacingUnit,
              AppConstants.spacingLg,
              AppConstants.spacingUnitLg,
            ),
            child: Row(
              children: [
                // Animated / concentric red siren badge
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.sirenRed.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(AppConstants.spacingXxs),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.sirenRed.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(AppConstants.spacingXxs),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.sirenRed,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.crisis_alert_rounded,
                        color: AppColors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingMd),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'safety.sos_backoffice_title'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontLg,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'safety.sos_backoffice_desc'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontSm,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Close Button
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.cardBorder),

          if (_isSuccess) ...[
            // Success Card
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingXl),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.refundContainerBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.greenSuccess,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.greenSuccess,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                  Text(
                    'safety.sos_sent_success'.tr(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontMd,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    'safety.sos_alert_desc'.tr(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontSm,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Details Card: GPS Coordinates & Ride Information
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingLg,
                AppConstants.spacingMd,
                AppConstants.spacingLg,
                AppConstants.spacingSm,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGrey,
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusDefault),
                  border: Border.all(
                    color: AppColors.cardBorder,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.my_location_rounded,
                          size: 16,
                          color: AppColors.sirenRed,
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(
                          'safety.sos_current_pos'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: AppConstants.fontXs,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spacingXs),
                    Text(
                      '${widget.currentPosition.latitude.toStringAsFixed(5)}, ${widget.currentPosition.longitude.toStringAsFixed(5)}',
                      style: GoogleFonts.inter(
                        fontSize: AppConstants.fontSm,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingSm),
                    Row(
                      children: [
                        const Icon(
                          Icons.drive_eta_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Expanded(
                          child: Text(
                            '${widget.driver.name} · ${widget.driver.carModel} (${widget.driver.licensePlate})',
                            style: GoogleFonts.inter(
                              fontSize: AppConstants.fontXs,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
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
            ),

            // Big Red SOS Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingLg,
                AppConstants.spacingSm,
                AppConstants.spacingLg,
                AppConstants.spacingSm,
              ),
              child: SizedBox(
                width: double.infinity,
                height: AppConstants.buttonHeight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sirenRed,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusFull),
                    ),
                  ),
                  onPressed: _isLoading ? null : () => _triggerSos(context),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(AppColors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 20,
                              color: AppColors.white,
                            ),
                            const SizedBox(width: AppConstants.spacingS),
                            Text(
                              'safety.sos_trigger_now'.tr(),
                              style: GoogleFonts.inter(
                                fontSize: AppConstants.fontMd,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            // Police 17 & SAMU 1515 Call Shortcuts
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingLg,
                AppConstants.spacingXs,
                AppConstants.spacingLg,
                AppConstants.spacingSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.pureBlack,
                        side: const BorderSide(
                          color: AppColors.cardBorder,
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusFull),
                        ),
                      ),
                      onPressed: () => _dialNumber('17'),
                      icon: const Icon(Icons.phone_rounded, size: 16),
                      label: Text(
                        'safety.police_17'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontXs,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.sirenRed,
                        side: const BorderSide(
                          color: AppColors.sirenRed,
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusFull),
                        ),
                      ),
                      onPressed: () => _dialNumber('1515'),
                      icon: const Icon(Icons.emergency_rounded, size: 16),
                      label: Text(
                        'safety.samu_1515'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontXs,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: systemBottom > 0 ? systemBottom + 8 : 16),
        ],
      ),
    );
  }
}
