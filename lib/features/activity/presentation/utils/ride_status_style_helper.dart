import 'package:flutter/material.dart';
import 'package:seddo/core/utils/app_colors.dart';

/// Centralized status visual styling helper ensuring that the status badge color
/// and icon are strictly identical before entering the ride (Activity list)
/// and after entering the ride detail (RideReceiptPage).
class RideStatusStyle {
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;

  const RideStatusStyle({
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
  });

  /// Resolves the unified visual style for any ride status.
  static RideStatusStyle forStatus(String statusText, {bool isRefunded = false}) {
    final s = statusText.trim().toLowerCase();

    // 1. Remboursée
    if (isRefunded || s == 'remboursée' || s == 'remboursee' || s == 'remboursé') {
      return const RideStatusStyle(
        backgroundColor: AppColors.refundPillBg,
        textColor: AppColors.greenSuccess,
        icon: Icons.refresh_rounded,
      );
    }

    // 2. Annulée (tous les statuts cancel)
    if (s.contains('annul') || s.contains('cancel')) {
      return const RideStatusStyle(
        backgroundColor: AppColors.grayBgLight,
        textColor: AppColors.slateDark,
        icon: Icons.close_rounded,
      );
    }

    // 3. Sans chauffeur / NO_DRIVER
    if (s.contains('sans chauffeur') || s.contains('no_driver')) {
      return const RideStatusStyle(
        backgroundColor: AppColors.peachContainer,
        textColor: AppColors.primaryDark,
        icon: Icons.person_off_outlined,
      );
    }

    // 4. Échec paiement
    if (s.contains('échec') || s.contains('echec') || s.contains('failed')) {
      return const RideStatusStyle(
        backgroundColor: AppColors.peachContainer,
        textColor: AppColors.primaryDark,
        icon: Icons.error_outline_rounded,
      );
    }

    // 5. En cours
    if (s.contains('cours') || s.contains('progress') || s.contains('trip')) {
      return const RideStatusStyle(
        backgroundColor: AppColors.peachContainer,
        textColor: AppColors.primaryDark,
        icon: Icons.navigation_rounded,
      );
    }

    // 6. En attente
    if (s.contains('attente') || s.contains('pending')) {
      return const RideStatusStyle(
        backgroundColor: AppColors.grayBgLight,
        textColor: AppColors.textSecondary,
        icon: Icons.access_time_rounded,
      );
    }

    // 7. Terminée / Payée (défaut succès)
    return const RideStatusStyle(
      backgroundColor: AppColors.receiptPaidBadgeBg,
      textColor: AppColors.receiptPaidBadgeText,
      icon: Icons.check_circle_rounded,
    );
  }
}
