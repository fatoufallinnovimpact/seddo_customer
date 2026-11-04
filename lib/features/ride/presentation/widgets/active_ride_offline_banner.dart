import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';

/// Bannière hors-ligne affichée pendant une course active (en approche ou en trajet)
/// Conforme aux spécifications Seddo :
/// « Connexion perdue, dernière mise à jour il y a X min »
class ActiveRideOfflineBanner extends StatelessWidget {
  final bool isOffline;
  final DateTime? lastUpdateTime;
  final VoidCallback? onRetry;

  const ActiveRideOfflineBanner({
    super.key,
    required this.isOffline,
    this.lastUpdateTime,
    this.onRetry,
  });

  String _formatElapsed() {
    if (lastUpdateTime == null) return 'un instant';
    final diff = DateTime.now().difference(lastUpdateTime!);
    if (diff.inMinutes < 1) {
      return 'un instant';
    }
    return '${diff.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 8,
      left: 16,
      right: 16,
      child: Material(
        color: AppColors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.slateDark.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.5),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowSubtleBlack,
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: AppColors.warning,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Connexion perdue',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ride.offline_banner'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.grayLight,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRetry != null)
                IconButton(
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: AppColors.white,
                    size: 20,
                  ),
                  onPressed: onRetry,
                  tooltip: 'Réessayer',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
