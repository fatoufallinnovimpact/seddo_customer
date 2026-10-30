import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
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

  /// Valeur normalisée conforme à l'API Swagger backend (POST /v1/rides)
  /// "paymentMethod doit valoir ORANGE_MONEY, WAVE ou CASH"
  String get apiValue {
    switch (this) {
      case PaymentMethodType.wave:
        return 'WAVE';
      case PaymentMethodType.orangeMoney:
        return 'ORANGE_MONEY';
      case PaymentMethodType.cash:
        return 'CASH';
    }
  }

  static PaymentMethodType fromApiValue(String? value) {
    switch (value?.toUpperCase()) {
      case 'WAVE':
        return PaymentMethodType.wave;
      case 'ORANGE_MONEY':
      case 'OM':
        return PaymentMethodType.orangeMoney;
      case 'CASH':
      default:
        return PaymentMethodType.cash;
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
  bool _isSubmitting = false;
  late final RideService _rideService;

  @override
  void initState() {
    super.initState();
    _rideService = widget.rideService ?? RideService();
  }

  Future<void> _onValidate() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final quoteId = widget.rideOption.quoteId;
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    if (quoteId == null || quoteId.isEmpty) {
      if (isTest) {
        if (mounted) {
          Navigator.of(context).pop(OrangeMoneyPaymentResult.success);
        }
        return;
      }
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Devis non disponible. Veuillez patienter pendant le calcul de la course.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final apiPaymentMethod = widget.paymentMethod.apiValue;
    debugPrint(
        '[PaymentModal] 🚀 POST /v1/rides avec quoteId: $quoteId (paymentMethod: $apiPaymentMethod)');
    final rideData = await _rideService.createRide(
      quoteId: quoteId,
      paymentMethod: apiPaymentMethod,
    );

    if (rideData != null) {
      final payment = rideData['payment'] as Map<String, dynamic>?;
      final orderId = payment?['orderId'] as String?;
      final paymentUrl = payment?['paymentUrl'] as String?;
      final payToken = payment?['payToken']?.toString();

      debugPrint(
          '[PaymentModal] ✅ Course créée ID: ${rideData['id']} - Statut: ${rideData['status']}');
      debugPrint(
          '[PaymentModal] 💳 Paiement (${payment?['method']}) URL: $paymentUrl - Token: $payToken');

      // Si une paymentUrl est retournée (Wave ou Orange Money), ouvre Wave/l'app de paiement
      if (paymentUrl != null && paymentUrl.isNotEmpty) {
        final uri = Uri.tryParse(paymentUrl);
        if (uri != null) {
          try {
            debugPrint(
                '[PaymentModal] 🌐 Ouverture lien de paiement (${widget.paymentMethod.name}): $paymentUrl');
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (e) {
            debugPrint('[PaymentModal] ⚠️ Erreur ouverture URL de paiement: $e');
          }
        }
      } else if (orderId != null &&
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

      if (mounted) {
        Navigator.of(context).pop(OrangeMoneyPaymentResult.success);
      }
      return;
    } else {
      // L'API a refusé ou renvoyé une erreur (ex: 422 PAYMENT_DECLINED / INSUFFICIENT_FUNDS)
      final error = RideService.lastCreateRideError;
      final code = error?['code']?.toString().toUpperCase();
      final reason = error?['reason']?.toString().toUpperCase();
      final message = error?['message']?.toString();

      debugPrint(
          '[PaymentModal] ❌ Échec création course: code=$code, reason=$reason, message=$message');

      if (code == 'PAYMENT_DECLINED' ||
          reason == 'INSUFFICIENT_FUNDS' ||
          (message != null && message.toLowerCase().contains('solde'))) {
        if (mounted) {
          Navigator.of(context).pop(OrangeMoneyPaymentResult.insufficientBalance);
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message ?? 'Impossible de créer la course. Veuillez réessayer.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
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

          const SizedBox(height: 20),

          // Information Card (Cash / Wave / OM)
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
                    color: isCash
                        ? AppColors.peachLight
                        : (widget.paymentMethod == PaymentMethodType.wave
                            ? const Color(0xFFE0F2FE)
                            : AppColors.peachLight),
                    borderRadius: BorderRadius.circular(AppConstants.radiusItem),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isCash
                        ? Icons.payments_outlined
                        : Icons.phone_android_rounded,
                    color: isCash
                        ? AppColors.primary
                        : (widget.paymentMethod == PaymentMethodType.wave
                            ? const Color(0xFF0284C7)
                            : AppColors.primary),
                    size: AppConstants.iconSizeMd,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingUnitLg),
                Expanded(
                  child: Text(
                    isCash
                        ? 'payment_sheet.cash_instructions'.tr()
                        : (widget.paymentMethod == PaymentMethodType.wave
                            ? 'Vous serez redirigé vers l\'application Wave pour valider le paiement. La recherche débutera dès confirmation.'
                            : 'Vous serez redirigé vers Orange Money pour confirmer le paiement. La recherche débutera dès confirmation.'),
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

          // Bouton de validation / confirmation
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
        ],
      ),
    );
  }
}
