import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';

enum OrangeMoneyPaymentResult {
  success,
  insufficientBalance,
  cancelled,
}

/// Bottom modal sheet for Orange Money payment confirmation matching Screenshot 1:
/// - Header: "Confirmer le paiement" + lock icon "Max it"
/// - Subtitle: "Seddo Mobilité · course [Eco/Confort]"
/// - Amount: "[price] FCFA"
/// - Source: "depuis Orange Money 77 ••• 45 12"
/// - 4 PIN code dots
/// - "Saisissez votre code secret"
/// - Custom numeric keypad (1-9, 0, backspace)
/// - "Valider" button
/// - "Simuler : solde insuffisant" link
class OrangeMoneyPaymentSheet extends StatefulWidget {
  final RideOptionModel rideOption;
  final String phoneDisplay;

  const OrangeMoneyPaymentSheet({
    super.key,
    required this.rideOption,
    this.phoneDisplay = '77 ••• 45 12',
  });

  static Future<OrangeMoneyPaymentResult?> show(
    BuildContext context, {
    required RideOptionModel rideOption,
    String? phoneDisplay,
  }) {
    final effectivePhone = phoneDisplay ??
        AuthRepository().currentUser?.maskedPhone ??
        '77 ••• 45 12';
    return showModalBottomSheet<OrangeMoneyPaymentResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => OrangeMoneyPaymentSheet(
        rideOption: rideOption,
        phoneDisplay: effectivePhone,
      ),
    );
  }

  @override
  State<OrangeMoneyPaymentSheet> createState() =>
      _OrangeMoneyPaymentSheetState();
}

class _OrangeMoneyPaymentSheetState extends State<OrangeMoneyPaymentSheet> {
  String _pin = '';

  void _onKeyTap(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
      });
      if (_pin.length == 4) {
        // Auto validate after short delay or let user tap Valider
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _onValidate() {
    Navigator.of(context).pop(OrangeMoneyPaymentResult.success);
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final systemBottom = MediaQuery.of(context).padding.bottom;
    final rideTypeLabel =
        widget.rideOption.type == RideType.eco ? 'Eco' : 'Confort';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusSheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        12,
        AppConstants.spacingLg,
        systemBottom + AppConstants.spacingMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: AppConstants.circularIconContainerSize,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.dragHandle,
              borderRadius: BorderRadius.circular(AppConstants.radiusXs),
            ),
          ),
          const SizedBox(height: 16),

          // Header Row: Confirmer le paiement & Max it
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'payment_sheet.title'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Max it',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Subtitle: Seddo Mobilité · course Eco
          Text(
            'payment_sheet.seddo_mobility'.tr(args: [rideTypeLabel]),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),

          // Big Amount: 3 500 FCFA
          Text(
            '${widget.rideOption.price} FCFA',
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),

          // Source: depuis Orange Money 77 ••• 45 12
          Text(
            'payment_sheet.from_om'.tr(args: [widget.phoneDisplay]),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 24),

          // 4 PIN Code Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < _pin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isFilled ? AppColors.textPrimary : AppColors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isFilled
                        ? AppColors.textPrimary
                        : AppColors.textPrimary,
                    width: 2,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),

          Text(
            'payment_sheet.enter_code'.tr(),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 20),

          // Numeric Keypad (1 to 9, 0, backspace)
          _buildNumericKeypad(),

          const SizedBox(height: 20),

          // Valider Button
          SizedBox(
            width: double.infinity,
            height: AppConstants.buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonBlack,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                ),
              ),
              onPressed: _onValidate,
              child: Text(
                'payment_sheet.validate'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildNumericKeypad() {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3']),
        const SizedBox(height: 12),
        _buildKeypadRow(['4', '5', '6']),
        const SizedBox(height: 12),
        _buildKeypadRow(['7', '8', '9']),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 64, height: 44),
            _buildKeypadButton('0'),
            SizedBox(
              width: 64,
              height: 44,
              child: IconButton(
                icon: const Icon(
                  Icons.backspace_outlined,
                  size: 22,
                  color: AppColors.textPrimary,
                ),
                onPressed: _onBackspace,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map(_buildKeypadButton).toList(),
    );
  }

  Widget _buildKeypadButton(String digit) {
    return SizedBox(
      width: 64,
      height: 44,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
          ),
          padding: EdgeInsets.zero,
        ),
        onPressed: () => _onKeyTap(digit),
        child: Text(
          digit,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
