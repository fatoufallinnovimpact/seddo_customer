import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/ride/presentation/widgets/offline_emergency_sheet.dart';
import 'package:seddo/services/network_connectivity_service.dart';

/// Modal bottom sheet affiché lorsqu'une action nécessitant une connexion internet
/// (comme la recherche d'un trajet ou la réservation) est tentée alors que l'appareil est hors-ligne :
/// - Icône réseau déconnecté / wifi off
/// - Titre : "Vous êtes hors ligne" (ride.offline_title)
/// - Sous-titre : "Vérifiez votre connexion internet ou utilisez l'urgence par SMS." (ride.offline_desc)
/// - Bouton principal "Réessayer"
/// - Option secondaire "Urgence par SMS"
/// - Fermeture instantanée par clic sur la croix ou la poignée supérieure
/// - Disparaît automatiquement dès que la connexion internet est rétablie
class OfflineModalSheet extends StatefulWidget {
  final Future<void> Function()? onRetry;
  final LatLng? currentPosition;
  final String? currentAddress;

  const OfflineModalSheet({
    super.key,
    this.onRetry,
    this.currentPosition,
    this.currentAddress,
  });

  static Future<bool?> show(
    BuildContext context, {
    Future<void> Function()? onRetry,
    LatLng? currentPosition,
    String? currentAddress,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => OfflineModalSheet(
        onRetry: onRetry,
        currentPosition: currentPosition,
        currentAddress: currentAddress,
      ),
    );
  }

  @override
  State<OfflineModalSheet> createState() => _OfflineModalSheetState();
}

class _OfflineModalSheetState extends State<OfflineModalSheet> {
  Timer? _connectivityPollTimer;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _startConnectivityMonitoring();
  }

  void _startConnectivityMonitoring() {
    _connectivityPollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkConnection();
    });
  }

  Future<void> _checkConnection() async {
    if (_isChecking || !mounted) return;
    _isChecking = true;
    try {
      final connected = await NetworkConnectivityService.isConnected;
      if (connected && mounted) {
        _connectivityPollTimer?.cancel();
        Navigator.of(context).pop(true);
        if (widget.onRetry != null) {
          await widget.onRetry!();
        }
      }
    } finally {
      _isChecking = false;
    }
  }

  @override
  void dispose() {
    _connectivityPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleRetry(BuildContext context) async {
    final connected = await NetworkConnectivityService.isConnected;
    if (context.mounted) {
      if (connected) {
        _connectivityPollTimer?.cancel();
        Navigator.of(context).pop(true);
        if (widget.onRetry != null) {
          await widget.onRetry!();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.offlineDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
            ),
            content: Text(
              'Toujours hors ligne. Vérifiez vos données mobiles ou votre Wi-Fi.',
              style: GoogleFonts.inter(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openOfflineEmergency(BuildContext context) async {
    _connectivityPollTimer?.cancel();
    Navigator.of(context).pop(false);

    LatLng? realPos = widget.currentPosition;
    if (realPos == null) {
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          realPos = LatLng(lastKnown.latitude, lastKnown.longitude);
        } else {
          final curr = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              timeLimit: Duration(seconds: 2),
            ),
          );
          realPos = LatLng(curr.latitude, curr.longitude);
        }
      } catch (_) {}
    }

    final pos = realPos ?? const LatLng(14.6860, -17.4570);
    if (!context.mounted) return;

    OfflineEmergencySheet.show(
      context,
      currentPosition: pos,
      currentAddress: widget.currentAddress,
      etaText: 'Urgence',
    );
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
        systemBottom > 0
            ? systemBottom + AppConstants.spacingUnitLg
            : AppConstants.spacingLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Barre supérieure : poignée cliquable et bouton fermer (X)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 32, height: 32),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Container(
                    width: AppConstants.circularIconContainerSize,
                    height: AppConstants.handleHeight,
                    decoration: BoxDecoration(
                      color: AppColors.dragHandle,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusXs),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                key: const ValueKey('offline_modal_close_button'),
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(false),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.grayBgSubtle,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.radiusCard),

          // Icône ronde hors ligne
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 18),

          // Titre : "Vous êtes hors ligne"
          Text(
            'ride.offline_title'.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),

          // Sous-titre : "Vérifiez votre connexion internet ou utilisez l'urgence par SMS."
          Text(
            'ride.offline_desc'.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Bouton principal "Réessayer"
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonBlack,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusDefault),
                ),
              ),
              onPressed: () => _handleRetry(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Réessayer',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Option Urgence par SMS
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.grayBorderDivider),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusDefault),
                ),
              ),
              onPressed: () => _openOfflineEmergency(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/icons/chat-round-svgrepo-com.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      AppColors.primary,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ride.sms_emergency'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
