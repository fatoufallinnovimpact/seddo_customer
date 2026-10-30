import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/services/realtime_service.dart';

/// Discreet connection indicator banner (PDF page 7):
/// « L'application affiche discrètement "Connexion en cours", sans bloquer l'écran. »
class RealtimeStatusIndicator extends StatelessWidget {
  const RealtimeStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RealtimeConnectionStatus>(
      stream: RealtimeService().statusStream,
      initialData: RealtimeService().connectionStatus,
      builder: (context, snapshot) {
        final status = snapshot.data ?? RealtimeConnectionStatus.disconnected;
        final isReconnecting = status == RealtimeConnectionStatus.reconnecting ||
            status == RealtimeConnectionStatus.connecting;

        if (!isReconnecting) {
          return const SizedBox.shrink();
        }

        return IgnorePointer(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isReconnecting ? 1.0 : 0.0,
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ride.reconnecting'.tr(),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
