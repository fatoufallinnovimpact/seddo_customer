import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/payment/data/services/payment_methods_service.dart';

/// Modal bottom sheet pour la sélection du mode de paiement,
/// correspondant exactement à la maquette fournie par l'utilisateur :
/// - Titre "Méthode de paiement" avec bouton de fermeture
/// - 3 options :
///   * Orange : logo Orange ("orange™"), sous-titre "Paiement par numéro de téléphone ou code QR"
///   * Wave : logo Wave (Pingouin sur fond cyan), sous-titre "Paiement par numéro de téléphone ou code QR"
///   * Espèces : billets de banque verts (exactement comme sur la photo)
/// - Sélecteur radio avec cercle orange et coche blanche (Icons.check) si sélectionné
/// - Bouton "Terminer" grand format stylisé avec nos tons sobres gris/noir et blanc
class PaymentMethodModal extends StatefulWidget {
  final String initialCode;

  const PaymentMethodModal({
    super.key,
    this.initialCode = 'CASH',
  });

  /// Ouvre la modal depuis n'importe quel contexte
  static Future<String?> show(BuildContext context) {
    final currentCode = PaymentMethodsService().currentCode;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => PaymentMethodModal(
        initialCode: currentCode,
      ),
    );
  }

  @override
  State<PaymentMethodModal> createState() => _PaymentMethodModalState();
}

class _PaymentMethodModalState extends State<PaymentMethodModal> {
  late String _selectedCode;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCode = widget.initialCode.toUpperCase();
  }

  Future<void> _handleConfirm() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await PaymentMethodsService().selectPaymentMethod(_selectedCode);
      if (mounted) {
        Navigator.of(context).pop(_selectedCode);
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop(_selectedCode);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusTwentyFour),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.modalShadow,
            blurRadius: 28,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppConstants.spacingTwenty,
        AppConstants.spacingUnitLg,
        AppConstants.spacingTwenty,
        bottomPadding > 0 ? bottomPadding + 12 : 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: AppConstants.handleWidth,
              height: AppConstants.handleHeight,
              decoration: BoxDecoration(
                color: AppColors.grayBorderDivider,
                borderRadius: BorderRadius.circular(AppConstants.radiusXs),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // En-tête : Titre et bouton fermer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'drawer.payment_methods_title'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(AppConstants.spacingXs),
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. Option Orange Money (même icône que lors des courses)
          _buildPaymentRow(
            code: 'ORANGE_MONEY',
            title: 'Orange Money',
            subtitle: 'Paiement par numéro de téléphone ou code QR',
            imagePath: 'assets/images/unnamed.png',
            fit: BoxFit.cover,
          ),

          const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),

          // 2. Option Wave (même icône que lors des courses)
          _buildPaymentRow(
            code: 'WAVE',
            title: 'Wave',
            subtitle: 'Paiement par numéro de téléphone ou code QR',
            imagePath: 'assets/images/images.png',
            fit: BoxFit.cover,
          ),

          const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),

          // 3. Option Espèces (billets de banque verts)
          _buildPaymentRow(
            code: 'CASH',
            title: 'Espèces',
            subtitle: 'Paiement en liquide à la fin de la course',
            imagePath: 'assets/images/cash_banknotes.png',
            fit: BoxFit.contain,
          ),

          const SizedBox(height: 28),

          // Bouton "Terminer"
          // Stylisé selon les tons sobres gris/noir et blanc demandés par l'utilisateur
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonBlack,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.white,
                        ),
                      ),
                    )
                  : Text(
                      'Terminer',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow({
    required String code,
    required String title,
    required String subtitle,
    required String imagePath,
    BoxFit fit = BoxFit.cover,
  }) {
    final isSelected = _selectedCode == code;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCode = code;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo / Image du moyen de paiement (même conteneur stylisé que lors des courses)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.grayBgSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.grayBorderDivider,
                  width: 0.8,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Padding(
                  padding: code == 'CASH'
                      ? const EdgeInsets.all(4.0)
                      : EdgeInsets.zero,
                  child: Image.asset(
                    imagePath,
                    width: 44,
                    height: 44,
                    fit: fit,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Textes : Titre + Sous-titre
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Radio Button personnalisé comme sur la photo :
            // Si sélectionné : cercle orange avec coche blanche
            // Si non sélectionné : cercle gris clair
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.primary
                    : const Color(0xFFE2E8F0),
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 18,
                      color: AppColors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
