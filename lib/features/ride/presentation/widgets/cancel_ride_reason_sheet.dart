import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';

/// Bottom modal sheet allowing the passenger to cancel a ride, select a cancellation reason,
/// and understand refund/cancellation policy connected to backend API.
class CancelRideReasonSheet extends StatefulWidget {
  final bool isDriverAssigned;

  const CancelRideReasonSheet({
    super.key,
    this.isDriverAssigned = false,
  });

  static Future<String?> show(
    BuildContext context, {
    bool isDriverAssigned = false,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => CancelRideReasonSheet(
        isDriverAssigned: isDriverAssigned,
      ),
    );
  }

  @override
  State<CancelRideReasonSheet> createState() => _CancelRideReasonSheetState();
}

class _CancelRideReasonSheetState extends State<CancelRideReasonSheet> {
  String? _selectedReason;
  final TextEditingController _customReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedReason = _presetReasons.first;
  }

  List<String> get _presetReasons {
    return [
      'Le chauffeur est trop loin',
      'Temps d\'attente trop long',
      'Le chauffeur ne se déplace pas',
      'J\'ai changé d\'avis',
      'Tarif trop élevé',
      'Autre motif',
    ];
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  String get _effectiveReason {
    if (_selectedReason == 'Autre motif' &&
        _customReasonController.text.trim().isNotEmpty) {
      return _customReasonController.text.trim();
    }
    return _selectedReason ?? 'Annulation demandée par le passager';
  }

  @override
  Widget build(BuildContext context) {
    final systemBottom = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusSheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingUnitLg,
        AppConstants.spacingLg,
        keyboardHeight > 0
            ? keyboardHeight + AppConstants.spacingMd
            : systemBottom + AppConstants.spacingMd,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Barre de préhension
            Container(
              width: AppConstants.circularIconContainerSize,
              height: AppConstants.handleHeight,
              decoration: BoxDecoration(
                color: AppColors.grayBorderDivider,
                borderRadius: BorderRadius.circular(AppConstants.radiusItem),
              ),
            ),
            const SizedBox(height: AppConstants.spacingXl / 2 + 2),

            // Icône d'alerte / annulation
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: AppColors.cancelLightBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.cancel_outlined,
                color: AppColors.cancelRed,
                size: 30,
              ),
            ),
            const SizedBox(height: AppConstants.spacingUnitXl),

            // Titre
            Text(
              'Annuler la course ?',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textDarkGrey,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),

            // Note explicative sur la politique tarifaire de l'API
            Text(
              widget.isDriverAssigned
                  ? 'L\'annulation est gratuite dans les 2 minutes après l\'acceptation. Ensuite, des frais d\'annulation s\'appliquent et le solde vous sera remboursé.'
                  : 'L\'annulation est totalement gratuite tant que la recherche est en cours. Le montant payé vous sera intégralement remboursé.',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.slateMuted,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingTwenty),

            // Liste des motifs
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Motif de votre annulation :',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDarkGrey,
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingUnit),

            ..._presetReasons.map((reason) {
              final isSelected = _selectedReason == reason;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _selectedReason = reason;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: AppConstants.spacingSm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingUnitXl,
                    vertical: AppConstants.spacingUnitLg,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.grayBgSubtle,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.grayBorderDivider,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textMutedGrey,
                        size: 20,
                      ),
                      const SizedBox(width: AppConstants.spacingUnitLg),
                      Expanded(
                        child: Text(
                          reason,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? AppColors.textDarkGrey
                                : AppColors.textBodyGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Champ de saisie personnalisé si "Autre motif"
            if (_selectedReason == 'Autre motif') ...[
              const SizedBox(height: AppConstants.spacingS),
              TextField(
                controller: _customReasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Précisez votre raison...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMutedGrey,
                  ),
                  filled: true,
                  fillColor: AppColors.grayBgSubtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
                    borderSide: const BorderSide(color: AppColors.grayBorderDivider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  contentPadding: const EdgeInsets.all(AppConstants.spacingUnitLg),
                ),
              ),
            ],

            const SizedBox(height: AppConstants.spacingTwenty),

            // Bouton 1 : Confirmer l'annulation (rouge/destructive)
            SizedBox(
              width: double.infinity,
              height: AppConstants.buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cancelRed,
                  foregroundColor: AppColors.white,
                  elevation: AppConstants.elevationNone,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop(_effectiveReason);
                },
                child: Text(
                  'Confirmer l\'annulation',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingUnit),

            // Bouton 2 : Conserver la course
            SizedBox(
              width: double.infinity,
              height: AppConstants.buttonHeight,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.grayBgLight,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(null),
                child: Text(
                  'Conserver ma course',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
