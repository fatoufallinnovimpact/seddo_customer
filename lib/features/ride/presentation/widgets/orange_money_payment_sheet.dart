import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';

enum OrangeMoneyPaymentResult {
  success,
  insufficientBalance,
  cancelled,
}

enum PaymentMethodType {
  wave,
  orangeMoney,
  cash;

  String get label {
    switch (this) {
      case PaymentMethodType.wave:
        return 'payment_sheet.wave_title'.tr();
      case PaymentMethodType.orangeMoney:
        return 'payment_sheet.om_title'.tr();
      case PaymentMethodType.cash:
        return 'payment_sheet.cash_title'.tr();
    }
  }

  String get subtitle {
    switch (this) {
      case PaymentMethodType.wave:
        return 'payment_sheet.wave_sub'.tr();
      case PaymentMethodType.orangeMoney:
        return 'payment_sheet.om_sub'.tr();
      case PaymentMethodType.cash:
        return 'payment_sheet.cash_sub'.tr();
    }
  }

  String get assetPath {
    switch (this) {
      case PaymentMethodType.wave:
        return 'assets/images/images.png';
      case PaymentMethodType.orangeMoney:
        return 'assets/images/unnamed.png';
      case PaymentMethodType.cash:
        return 'assets/images/cfa.jpg';
    }
  }
}

/// Modal de confirmation de paiement connecté à l'API de paiement :
/// Supporte Orange Money (unnamed.png), Wave (images.png) et Paiement en espèces (cfa.jpg).
class OrangeMoneyPaymentSheet extends StatefulWidget {
  final RideOptionModel rideOption;
  final String phoneDisplay;
  final RideService? rideService;
  final PaymentMethodType paymentMethod;

  const OrangeMoneyPaymentSheet({
    super.key,
    required this.rideOption,
    this.phoneDisplay = '77 ••• 45 12',
    this.rideService,
    this.paymentMethod = PaymentMethodType.orangeMoney,
  });

  static Future<OrangeMoneyPaymentResult?> show(
    BuildContext context, {
    required RideOptionModel rideOption,
    String? phoneDisplay,
    RideService? rideService,
    PaymentMethodType paymentMethod = PaymentMethodType.orangeMoney,
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
        rideService: rideService,
        paymentMethod: paymentMethod,
      ),
    );
  }

  @override
  State<OrangeMoneyPaymentSheet> createState() =>
      _OrangeMoneyPaymentSheetState();
}

class _OrangeMoneyPaymentSheetState extends State<OrangeMoneyPaymentSheet> {
  String _pin = '';
  bool _isSubmitting = false;
  late final RideService _rideService;

  @override
  void initState() {
    super.initState();
    _rideService = widget.rideService ?? RideService();
  }

  void _onKeyTap(String digit) {
    if (_pin.length < 4 && !_isSubmitting) {
      setState(() {
        _pin += digit;
      });
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty && !_isSubmitting) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _onValidate() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final quoteId = widget.rideOption.quoteId;
    if (quoteId != null && quoteId.isNotEmpty) {
      debugPrint(
          '[PaymentModal] 🚀 POST /v1/rides avec quoteId: $quoteId (${widget.paymentMethod.name})');
      final rideData = await _rideService.createRide(quoteId: quoteId);

      if (rideData != null) {
        final payment = rideData['payment'] as Map<String, dynamic>?;
        final orderId = payment?['orderId'] as String?;

        if (orderId != null &&
            orderId.isNotEmpty &&
            widget.paymentMethod != PaymentMethodType.cash) {
          debugPrint(
              '[PaymentModal] 🚀 Simulation dev paiement pour orderId: $orderId');
          await _rideService.simulateDevPayment(
            orderId: orderId,
            outcome: 'SUCCESS',
            notify: true,
          );
        }
      }
    }

    if (mounted) {
      Navigator.of(context).pop(OrangeMoneyPaymentResult.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final systemBottom = MediaQuery.of(context).padding.bottom;
    final rideTypeLabel =
        widget.rideOption.type == RideType.eco ? 'Eco' : 'Confort';

    final isCash = widget.paymentMethod == PaymentMethodType.cash;

    final sourceText = switch (widget.paymentMethod) {
      PaymentMethodType.wave =>
        'payment_sheet.from_wave'.tr(args: [widget.phoneDisplay]),
      PaymentMethodType.orangeMoney =>
        'payment_sheet.from_om'.tr(args: [widget.phoneDisplay]),
      PaymentMethodType.cash => 'payment_sheet.from_cash'.tr(),
    };

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

          // Header Row: Confirmer le paiement & Logo du mode de paiement
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
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  widget.paymentMethod.assetPath,
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.payment_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

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

          // Source: depuis Wave / OM / Espèces
          Text(
            sourceText,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),

          if (isCash) ...[
            const SizedBox(height: 20),
            // Cash info card
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingUnitXl),
              decoration: BoxDecoration(
                color: AppColors.grayBgSubtle,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: AppColors.grayBorderDivider),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.peachLight,
                      borderRadius: BorderRadius.circular(AppConstants.radiusItem),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.payments_outlined,
                      color: AppColors.primary,
                      size: AppConstants.iconSizeMd,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingUnitLg),
                  Expanded(
                    child: Text(
                      'payment_sheet.cash_instructions'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bouton de validation pour paiement en espèces
            SizedBox(
              width: double.infinity,
              height: AppConstants.buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                  ),
                ),
                onPressed: _isSubmitting ? null : _onValidate,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'payment_sheet.validate'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 22),

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
                    color: isFilled
                        ? AppColors.textPrimary
                        : AppColors.transparent,
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

            const SizedBox(height: 18),

            // Numeric Keypad (1 to 9, 0, backspace)
            _buildNumericKeypad(),

            const SizedBox(height: 18),

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
                onPressed: _isSubmitting ? null : _onValidate,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'payment_sheet.validate'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
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
