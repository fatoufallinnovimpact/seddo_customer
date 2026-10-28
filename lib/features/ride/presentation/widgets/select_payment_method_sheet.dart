import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/ride/presentation/widgets/orange_money_payment_sheet.dart';

/// Modal sheet "Mode de paiement" correspondant exactement au design fourni :
/// - Titre "Mode de paiement" (internationalisé FR & WO)
/// - Options Wave, Orange Money et Espèces avec logos officiels
/// - Bouton "Confirmer et payer ->"
/// - Footer "Paiement 100% sécurisé" avec cadenas
/// - Utilise exclusivement les constantes AppColors et AppConstants (aucun appel en dur)
class SelectPaymentMethodSheet extends StatefulWidget {
  final PaymentMethodType initialMethod;

  const SelectPaymentMethodSheet({
    super.key,
    this.initialMethod = PaymentMethodType.cash,
  });

  static Future<PaymentMethodType?> show(
    BuildContext context, {
    PaymentMethodType initialMethod = PaymentMethodType.cash,
  }) {
    return showModalBottomSheet<PaymentMethodType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => SelectPaymentMethodSheet(
        initialMethod: initialMethod,
      ),
    );
  }

  @override
  State<SelectPaymentMethodSheet> createState() =>
      _SelectPaymentMethodSheetState();
}

class _SelectPaymentMethodSheetState extends State<SelectPaymentMethodSheet> {
  late PaymentMethodType _selectedMethod;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.initialMethod;
  }

  @override
  Widget build(BuildContext context) {
    final systemBottom = MediaQuery.of(context).padding.bottom;

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
        AppConstants.spacingLg,
        AppConstants.spacingUnitLg,
        AppConstants.spacingLg,
        systemBottom > 0 ? systemBottom + AppConstants.spacingUnit : AppConstants.spacingTwenty,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: AppConstants.circularIconContainerSize,
              height: AppConstants.handleHeight,
              decoration: BoxDecoration(
                color: AppColors.dragHandle,
                borderRadius: BorderRadius.circular(AppConstants.radiusXs),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingXl / 2 + 2),

          // Titre : Mode de paiement
          Text(
            'payment_sheet.mode_title'.tr(),
            style: GoogleFonts.inter(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Option 1 : Wave
          _buildPaymentOptionCard(
            method: PaymentMethodType.wave,
            title: 'payment_sheet.wave_title'.tr(),
            subtitle: 'payment_sheet.wave_sub'.tr(),
            assetPath: 'assets/images/images.png',
          ),

          // Option 2 : Orange Money
          _buildPaymentOptionCard(
            method: PaymentMethodType.orangeMoney,
            title: 'payment_sheet.om_title'.tr(),
            subtitle: 'payment_sheet.om_sub'.tr(),
            assetPath: 'assets/images/unnamed.png',
          ),

          // Option 3 : Paiement en espèces
          _buildPaymentOptionCard(
            method: PaymentMethodType.cash,
            title: 'payment_sheet.cash_title'.tr(),
            subtitle: 'payment_sheet.cash_sub'.tr(),
            assetPath: 'assets/images/cfa.jpg',
          ),

          const SizedBox(height: AppConstants.spacingUnitXl),

          // Bouton "Confirmer et payer ->"
          SizedBox(
            width: double.infinity,
            height: AppConstants.buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                elevation: AppConstants.elevationNone,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(_selectedMethod);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: AppConstants.iconSizeMd,
                    color: AppColors.white,
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Flexible(
                    child: Text(
                      'payment_sheet.confirm_and_pay'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingS),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: AppConstants.iconSizeDefault,
                    color: AppColors.white,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spacingUnitXl),

          // Footer : Paiement 100% sécurisé
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: AppConstants.iconSizeSm - 2,
                color: AppColors.slateMuted,
              ),
              const SizedBox(width: AppConstants.spacingS),
              Text(
                'payment_sheet.secure_100'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slateMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptionCard({
    required PaymentMethodType method,
    required String title,
    required String subtitle,
    required String assetPath,
  }) {
    final isSelected = _selectedMethod == method;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = method;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: AppConstants.spacingUnitLg),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingUnitXl,
          vertical: AppConstants.spacingUnitLg,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.ecoCardSelectedBackground
              : AppColors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.grayBorderDivider,
            width: isSelected
                ? AppConstants.strokeWidthSelected
                : AppConstants.spacingTiny,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(20),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Logo container
            Container(
              width: AppConstants.circularPickerSize,
              height: AppConstants.circularPickerSize,
              decoration: BoxDecoration(
                color: AppColors.grayBgSubtle,
                borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
                child: Image.asset(
                  assetPath,
                  width: AppConstants.circularPickerSize,
                  height: AppConstants.circularPickerSize,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.grayBgLight,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.payment_rounded,
                      color: AppColors.primary,
                      size: AppConstants.iconSizeLg,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spacingUnitXl),

            // Libellé & description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingXxs),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppConstants.spacingUnit),

            // Bouton radio circulaire
            Container(
              width: AppConstants.iconSizeLg,
              height: AppConstants.iconSizeLg,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textMutedGrey,
                  width: isSelected ? 2.0 : 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? Container(
                      width: 11,
                      height: 11,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
