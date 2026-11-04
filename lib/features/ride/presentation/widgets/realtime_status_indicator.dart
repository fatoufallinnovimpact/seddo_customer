import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/services/realtime_service.dart';

/// Discreet connection indicator banner (PDF page 7):
/// « L'application affiche discrètement "Connexion en cours", sans bloquer l'écran. »
/// Utilise un délai d'apparition (debounce) de 1,5s pour éviter de clignoter pendant
/// 1 seconde lors d'un simple basculement d'application lorsque le Wi-Fi est actif.
class RealtimeStatusIndicator extends StatefulWidget {
  const RealtimeStatusIndicator({super.key});

  @override
  State<RealtimeStatusIndicator> createState() => _RealtimeStatusIndicatorState();
}

class _RealtimeStatusIndicatorState extends State<RealtimeStatusIndicator> {
  StreamSubscription<RealtimeConnectionStatus>? _statusSub;
  Timer? _debounceTimer;
  bool _showIndicator = false;

  @override
  void initState() {
    super.initState();
    _handleStatus(RealtimeService().connectionStatus);
    _statusSub = RealtimeService().statusStream.listen(_handleStatus);
  }

  void _handleStatus(RealtimeConnectionStatus status) {
    final isReconnecting = status == RealtimeConnectionStatus.reconnecting ||
        status == RealtimeConnectionStatus.connecting;

    if (!isReconnecting) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      if (_showIndicator && mounted) {
        setState(() => _showIndicator = false);
      }
    } else {
      if (!_showIndicator && _debounceTimer == null) {
        // N'affiche le voyant que si la reconnexion prend réellement plus de 1,5 seconde
        _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() => _showIndicator = true);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showIndicator) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _showIndicator ? 1.0 : 0.0,
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
  }
}

