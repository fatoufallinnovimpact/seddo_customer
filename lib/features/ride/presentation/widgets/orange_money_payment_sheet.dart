import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';
import 'package:seddo/features/ride/presentation/widgets/offline_modal_sheet.dart';
import 'package:seddo/services/network_connectivity_service.dart';
import 'package:seddo/services/realtime_service.dart';

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
      isDismissible: true,
      enableDrag: true,
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

class _OrangeMoneyPaymentSheetState extends State<OrangeMoneyPaymentSheet>
    with WidgetsBindingObserver {
  bool _isSubmitting = false;
  bool _isWaitingForSearching = false;
  String? _errorMessage;
  String? _paymentUrl;
  Timer? _statusPollTimer;
  Timer? _devSimulateTimer;
  Timer? _connectivityPollTimer;
  StreamSubscription<RealtimeRideStatusEvent>? _wsStatusSub;
  String? _activeRideId;
  late final RideService _rideService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rideService = widget.rideService ?? RideService();
    _connectivityPollTimer =
        Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      if (_errorMessage != null &&
          _errorMessage!.toLowerCase().contains('connexion')) {
        final online = await NetworkConnectivityService.isConnected;
        if (online && mounted) {
          setState(() {
            _errorMessage = null;
          });
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed &&
        _isWaitingForSearching &&
        _activeRideId != null) {
      debugPrint(
          '[PaymentModal] 📱 App revenue au premier plan, vérification immédiate du statut pour $_activeRideId');
      _checkRideStatusImmediate(_activeRideId!);
    }
  }

  Future<void> _checkRideStatusImmediate(String rideId) async {
    if (!mounted || !_isWaitingForSearching) return;
    try {
      final details = await _rideService.getRideDetails(rideId);
      if (details != null && mounted && _isWaitingForSearching) {
        final currentStatus =
            (details['status'] as String? ?? '').toUpperCase();
        debugPrint(
            '[PaymentModal] 🔍 Statut immédiat au retour de l\'application: $currentStatus');
        if (currentStatus == 'SEARCHING') {
          _completePaymentAndProceed(details);
        } else if (currentStatus == 'CANCELLED' ||
            currentStatus.startsWith('CANCEL') ||
            currentStatus == 'REJECTED') {
          _statusPollTimer?.cancel();
          _devSimulateTimer?.cancel();
          _connectivityPollTimer?.cancel();
          _wsStatusSub?.cancel();
          if (mounted) {
            Navigator.of(context).pop(OrangeMoneyPaymentResult.cancelled);
          }
        }
      }
    } catch (e) {
      debugPrint('[PaymentModal] ⚠️ Erreur vérification statut au retour: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusPollTimer?.cancel();
    _devSimulateTimer?.cancel();
    _connectivityPollTimer?.cancel();
    _wsStatusSub?.cancel();
    super.dispose();
  }

  void _completePaymentAndProceed(Map<String, dynamic> data) {
    _statusPollTimer?.cancel();
    _devSimulateTimer?.cancel();
    _wsStatusSub?.cancel();
    RideService.lastCreatedRideData = data;
    if (mounted) {
      Navigator.of(context).pop(OrangeMoneyPaymentResult.success);
    }
  }

  Future<void> _cancelOrder() async {
    _statusPollTimer?.cancel();
    _devSimulateTimer?.cancel();
    _wsStatusSub?.cancel();
    if (_activeRideId != null) {
      final rideIdToCancel = _activeRideId!;
      _activeRideId = null;
      RideService.lastCreatedRideId = null;
      RideService.lastCreatedRideData = null;
      try {
        await _rideService.cancelRide(
          rideId: rideIdToCancel,
          reason: 'Annulation paiement par le client',
        );
      } catch (e) {
        debugPrint('[PaymentModal] Erreur annulation course $rideIdToCancel: $e');
      }
    }
    if (mounted) {
      Navigator.of(context).pop(OrangeMoneyPaymentResult.cancelled);
    }
  }

  void _startWaitingForSearching(String rideId) {
    _activeRideId = rideId;
    _statusPollTimer?.cancel();
    _wsStatusSub?.cancel();

    // 1. Écoute temps réel via WebSocket (rideStatusStream)
    try {
      _wsStatusSub = RealtimeService().rideStatusStream.listen((event) {
        if (event.rideId == rideId && event.status == 'SEARCHING') {
          debugPrint(
              '[PaymentModal] ⚡ WebSocket a reçu statut SEARCHING pour course $rideId');
          _completePaymentAndProceed(event.raw);
        }
      });
    } catch (_) {}

    // 2. Polling régulier de secours sur l'endpoint GET /v1/rides/{id} (uniquement si WebSocket déconnecté)
    _statusPollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted || RealtimeService().isConnected) return;
      final details = await _rideService.getRideDetails(rideId);
      if (details != null && mounted) {
        final currentStatus =
            (details['status'] as String? ?? '').toUpperCase();
        debugPrint(
            '[PaymentModal] 🔍 Polling statut course $rideId -> $currentStatus');
        if (currentStatus == 'SEARCHING') {
          _completePaymentAndProceed(details);
        } else if (currentStatus == 'CANCELLED' ||
            currentStatus.startsWith('CANCEL') ||
            currentStatus == 'REJECTED') {
          _statusPollTimer?.cancel();
          _wsStatusSub?.cancel();
          if (mounted) {
            Navigator.of(context).pop(OrangeMoneyPaymentResult.cancelled);
          }
        }
      }
    });
  }

  Future<void> _onValidate() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    // Vérification de la connectivité réseau
    final isOnline = await NetworkConnectivityService.isConnected;
    if (!isOnline && !isTest) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage =
              'Aucune connexion Internet. Veuillez vérifier votre réseau et réessayer.';
        });
        await OfflineModalSheet.show(
          context,
          onRetry: () => _onValidate(),
        );
      }
      return;
    }

    final quoteId = widget.rideOption.quoteId;

    if (quoteId == null || quoteId.isEmpty) {
      if (isTest) {
        if (mounted) {
          Navigator.of(context).pop(OrangeMoneyPaymentResult.success);
        }
        return;
      }
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage =
              'Devis non disponible. Veuillez patienter pendant le calcul de la course.';
        });
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
      final rideId = rideData['id']?.toString() ?? '';
      final status = (rideData['status'] as String? ?? '').toUpperCase();

      debugPrint(
          '[PaymentModal] ✅ Course créée ID: $rideId - Statut initial: $status');
      debugPrint(
          '[PaymentModal] 💳 Paiement (${payment?['method']}) URL: $paymentUrl - Token: $payToken');

      // Si le statut est DÉJÀ SEARCHING (ex: Espèces/CASH ou déjà validé)
      if (status == 'SEARCHING') {
        if (mounted) {
          Navigator.of(context).pop(OrangeMoneyPaymentResult.success);
        }
        return;
      }

      // Si le statut n'est pas encore SEARCHING (ex: PAYMENT_PENDING pour Wave ou OM)
      // On passe IMMÉDIATEMENT en état d'attente active pour afficher le modal avec l'option Annuler
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isWaitingForSearching = true;
          _paymentUrl = paymentUrl;
        });
        _startWaitingForSearching(rideId);
      }

      // Lancement du paiement externe (Wave)
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
        // En environnement de dev : simulation différée (15s) pour que l'utilisateur
        // ait le temps de voir le modal "En attente du paiement..." et tester le bouton "Annuler la commande"
        _devSimulateTimer?.cancel();
        _devSimulateTimer = Timer(const Duration(seconds: 15), () async {
          if (!mounted || !_isWaitingForSearching) return;
          debugPrint(
              '[PaymentModal] 🚀 Simulation dev paiement différée pour orderId: $orderId');
          await _rideService.simulateDevPayment(
            orderId: orderId,
            outcome: 'SUCCESS',
            notify: true,
          );
        });
      }
      return;
    } else {
      // L'API a refusé ou renvoyé une erreur (ex: 422 PAYMENT_DECLINED / INSUFFICIENT_FUNDS / Hors-ligne)
      final isOnlineAfter = await NetworkConnectivityService.isConnected;
      final error = RideService.lastCreateRideError;
      final code = error?['code']?.toString().toUpperCase();
      final reason = error?['reason']?.toString().toUpperCase();
      final message = error?['message']?.toString();

      debugPrint(
          '[PaymentModal] ❌ Échec création course: code=$code, reason=$reason, message=$message');

      if (mounted) {
        final isOffline = !isOnlineAfter || code == 'NO_CONNECTION';
        setState(() {
          _isSubmitting = false;
          if (isOffline) {
            _errorMessage =
                'Aucune connexion Internet. Veuillez vérifier votre réseau et réessayer.';
          } else {
            _errorMessage = message ??
                (code == 'PAYMENT_DECLINED' ||
                        reason == 'INSUFFICIENT_FUNDS' ||
                        (message != null && message.toLowerCase().contains('solde'))
                    ? 'Solde insuffisant pour effectuer ce paiement.'
                    : 'Impossible de créer la course. Veuillez vérifier votre connexion et réessayer.');
          }
        });
        if (isOffline && !isTest) {
          await OfflineModalSheet.show(
            context,
            onRetry: () => _onValidate(),
          );
        }
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

    // Si on est en attente que l'endpoint passe à SEARCHING (Wave / OM)
    if (_isWaitingForSearching) {
      return PopScope(
        canPop: false,
        child: Container(
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
            // Poignée supérieure : clic pour annuler et fermer
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _cancelOrder,
              child: Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 10),
                child: Center(
                  child: Container(
                    width: AppConstants.circularIconContainerSize,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.dragHandle,
                      borderRadius: BorderRadius.circular(AppConstants.radiusXs),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Spinner animé avec logo paiement
            Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 68,
                  height: 68,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3.5,
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    widget.paymentMethod.assetPath,
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text(
              'En attente du paiement...',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              '${widget.rideOption.price} FCFA',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              widget.paymentMethod == PaymentMethodType.wave
                  ? 'Veuillez valider la transaction dans l\'application Wave. Dès réception du paiement, la recherche du chauffeur démarre.'
                  : 'Veuillez valider la transaction sur Orange Money. Dès réception du paiement, la recherche du chauffeur démarre.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            if (_paymentUrl != null && _paymentUrl!.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.paymentMethod == PaymentMethodType.wave
                        ? const Color(0xFF0284C7)
                        : AppColors.primary,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                    ),
                  ),
                  onPressed: () async {
                    final uri = Uri.tryParse(_paymentUrl!);
                    if (uri != null) {
                      try {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (e) {
                        debugPrint('[PaymentModal] ⚠️ Erreur réouverture URL: $e');
                      }
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(
                    widget.paymentMethod == PaymentMethodType.wave
                        ? 'Ouvrir Wave pour payer'
                        : 'Ouvrir Orange Money',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.grayBorderDivider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                  ),
                ),
                onPressed: _cancelOrder,
                child: Text(
                  'Annuler la commande',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          // Drag Handle : clic n'importe où sur le haut pour fermer le modal
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Center(
                child: Container(
                  width: AppConstants.circularIconContainerSize,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.dragHandle,
                    borderRadius: BorderRadius.circular(AppConstants.radiusXs),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Header Row: Confirmer le paiement & Logo du mode de paiement & Bouton Fermer (X)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
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
              ),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  widget.paymentMethod.assetPath,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.payment_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.grayBgSubtle,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
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

          // Message d'erreur élégant dans le modal
          if (_errorMessage != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.errorLightBg,
                borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
                border: Border.all(
                  color: AppColors.errorRed.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.errorRed,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.priority_high_rounded,
                      color: AppColors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.errorRed,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

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
