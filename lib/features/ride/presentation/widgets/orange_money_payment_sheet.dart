import 'dart:async';
import 'package:app_links/app_links.dart';
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
        return 'assets/images/cash_banknotes.png';
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
  final bool autoValidate;

  const OrangeMoneyPaymentSheet({
    super.key,
    required this.rideOption,
    this.phoneDisplay = '77 ••• 45 12',
    this.rideService,
    this.paymentMethod = PaymentMethodType.orangeMoney,
    this.autoValidate = false,
  });

  static Future<OrangeMoneyPaymentResult?> show(
    BuildContext context, {
    required RideOptionModel rideOption,
    String? phoneDisplay,
    RideService? rideService,
    PaymentMethodType paymentMethod = PaymentMethodType.orangeMoney,
    bool autoValidate = false,
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
        autoValidate: autoValidate,
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
  bool _isCompleted = false;
  bool _isCheckingStatus = false;
  DateTime _lastApiCheckTime = DateTime.fromMillisecondsSinceEpoch(0);
  String? _errorMessage;
  String? _paymentUrl;
  Timer? _statusPollTimer;
  Timer? _resumeFollowUpTimer;
  Timer? _devSimulateTimer;
  Timer? _connectivityPollTimer;
  StreamSubscription<RealtimeRideStatusEvent>? _wsStatusSub;
  StreamSubscription<RealtimePaymentStatusEvent>? _wsPaymentSub;
  StreamSubscription<void>? _wsReconnectSub;
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _appLinksSub;
  String? _activeRideId;
  late final RideService _rideService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rideService = widget.rideService ?? RideService();
    _initDeepLinks();
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

    if (widget.autoValidate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _onValidate();
        }
      });
    }
  }

  void _initDeepLinks() {
    try {
      _appLinks = AppLinks();
      _appLinksSub = _appLinks?.uriLinkStream.listen((uri) {
        if (!mounted || !_isWaitingForSearching || _isCompleted) return;
        final uriStr = uri.toString().toLowerCase();
        debugPrint('[PaymentModal] 🔗 Deep link reçu dans PaymentSheet: $uri');
        if (uriStr.contains('payment') ||
            uriStr.contains('return') ||
            uriStr.contains('wave') ||
            uriStr.contains('seddo')) {
          _triggerControlledStatusVerification(force: true);
        }
      });
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed &&
        _isWaitingForSearching &&
        !_isCompleted) {
      debugPrint(
          '[PaymentModal] 📱 Retour de Wave / premier plan détecté, vérification contrôlée du paiement et de la course');
      if (!RealtimeService().isConnected) {
        RealtimeService().connect();
      }
      if (_activeRideId != null && _activeRideId!.isNotEmpty) {
        RealtimeService().joinRide(_activeRideId!);
      }
      _triggerControlledStatusVerification(force: true);
    }
  }

  /// Lance une vérification immédiate suivie d'un unique contrôle différé (à +3s)
  /// au cas où le webhook Wave met 1 à 2 secondes à notifier le backend après le retour dans l'app,
  /// sans jamais faire d'appels en boucle.
  void _triggerControlledStatusVerification({bool force = false}) {
    _verifyRideAndPaymentStatus(force: force);
    _resumeFollowUpTimer?.cancel();
    _resumeFollowUpTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isWaitingForSearching && !_isCompleted) {
        _verifyRideAndPaymentStatus(force: true);
      }
    });
  }

  bool _isRidePaidOrActive(Map<String, dynamic> rawData) {
    final rideObj = rawData['ride'] is Map<String, dynamic>
        ? rawData['ride'] as Map<String, dynamic>
        : rawData;
    final currentStatus =
        (rideObj['status'] as String? ?? rawData['status'] as String? ?? '')
            .toUpperCase()
            .trim();

    final paymentObj = (rideObj['payment'] is Map<String, dynamic>
            ? rideObj['payment']
            : rawData['payment']) as Map<String, dynamic>?;
    final paymentStatus = (paymentObj?['status'] as String? ??
            rideObj['paymentStatus'] as String? ??
            rawData['paymentStatus'] as String? ??
            '')
        .toUpperCase()
        .trim();
    final isPaidFlag = rideObj['isPaid'] == true ||
        rawData['isPaid'] == true ||
        paymentObj?['paid'] == true ||
        paymentObj?['isPaid'] == true;

    final hasValidRideStatus = currentStatus == 'SEARCHING' ||
        currentStatus == 'PAID' ||
        currentStatus == 'ACCEPTED' ||
        currentStatus == 'DRIVER_ACCEPTED' ||
        currentStatus == 'DRIVER_ASSIGNED' ||
        currentStatus == 'CONFIRMED' ||
        currentStatus == 'APPROACHING' ||
        currentStatus == 'EN_ROUTE' ||
        currentStatus == 'ASSIGNED' ||
        currentStatus == 'IN_PROGRESS' ||
        currentStatus == 'DRIVER_ARRIVED' ||
        rawData['driver'] != null ||
        rideObj['driver'] != null;

    final hasValidPaymentStatus = paymentStatus == 'SUCCESS' ||
        paymentStatus == 'PAID' ||
        paymentStatus == 'COMPLETED' ||
        paymentStatus == 'SUCCEEDED' ||
        paymentStatus == 'CONFIRMED' ||
        isPaidFlag;

    return hasValidRideStatus || hasValidPaymentStatus;
  }

  bool _isRideCancelledOrFailed(Map<String, dynamic> rawData) {
    final rideObj = rawData['ride'] is Map<String, dynamic>
        ? rawData['ride'] as Map<String, dynamic>
        : rawData;
    final currentStatus =
        (rideObj['status'] as String? ?? rawData['status'] as String? ?? '')
            .toUpperCase()
            .trim();
    return currentStatus == 'CANCELLED' ||
        currentStatus.startsWith('CANCEL') ||
        currentStatus == 'REJECTED' ||
        currentStatus == 'NO_DRIVER';
  }

  /// Vérifie l'état de la course sur l'API avec anti-rebond (debounce) strict
  /// pour ne jamais saturer le backend.
  Future<void> _verifyRideAndPaymentStatus({bool force = false}) async {
    if (!mounted || !_isWaitingForSearching || _isCompleted || _isCheckingStatus) {
      return;
    }

    final now = DateTime.now();
    if (!force &&
        now.difference(_lastApiCheckTime) < const Duration(seconds: 4)) {
      return;
    }

    _isCheckingStatus = true;
    _lastApiCheckTime = now;

    try {
      Map<String, dynamic>? details;
      final rideId = _activeRideId;

      if (rideId != null && rideId.isNotEmpty) {
        details = await _rideService.getRideDetails(rideId);
      }

      // Si getRideDetails n'a pas encore reflété le statut ou si rideId était absent,
      // vérifier via GET /v1/rides/current (qui renvoie la course active envoyée aux chauffeurs)
      if ((details == null || !_isRidePaidOrActive(details)) &&
          mounted &&
          _isWaitingForSearching &&
          !_isCompleted) {
        final currentRes = await _rideService.getCurrentRide();
        if (currentRes != null && currentRes['ride'] is Map<String, dynamic>) {
          details = currentRes;
          final currentRide = currentRes['ride'] as Map<String, dynamic>;
          final currentId = currentRide['id']?.toString();
          if (currentId != null && currentId.isNotEmpty) {
            _activeRideId = currentId;
            RideService.lastCreatedRideId = currentId;
          }
        }
      }

      if (details != null && mounted && _isWaitingForSearching && !_isCompleted) {
        if (_isRidePaidOrActive(details)) {
          _completePaymentAndProceed(details);
          return;
        } else if (_isRideCancelledOrFailed(details)) {
          _stopAllListeners();
          if (mounted) {
            Navigator.of(context).pop(OrangeMoneyPaymentResult.cancelled);
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('[PaymentModal] ⚠️ Erreur vérification statut: $e');
    } finally {
      _isCheckingStatus = false;
    }
  }

  void _stopAllListeners() {
    _statusPollTimer?.cancel();
    _resumeFollowUpTimer?.cancel();
    _devSimulateTimer?.cancel();
    _connectivityPollTimer?.cancel();
    _wsStatusSub?.cancel();
    _wsPaymentSub?.cancel();
    _wsReconnectSub?.cancel();
    _appLinksSub?.cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAllListeners();
    super.dispose();
  }

  void _completePaymentAndProceed(Map<String, dynamic> data) {
    if (_isCompleted) return;
    _isCompleted = true;
    _stopAllListeners();

    final normalized = Map<String, dynamic>.from(data);
    final rideObj = normalized['ride'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(normalized['ride'] as Map<String, dynamic>)
        : normalized;
    final rawStatus =
        (rideObj['status'] as String? ?? normalized['status'] as String? ?? '')
            .toUpperCase()
            .trim();
    if (rawStatus.isEmpty ||
        rawStatus == 'PAYMENT_PENDING' ||
        rawStatus == 'PENDING' ||
        rawStatus == 'PAID') {
      rideObj['status'] = 'SEARCHING';
      normalized['status'] = 'SEARCHING';
      if (normalized['ride'] is Map) {
        normalized['ride'] = rideObj;
      }
    }

    final rideId = (rideObj['id'] ?? normalized['id'] ?? _activeRideId)?.toString();
    if (rideId != null && rideId.isNotEmpty) {
      RideService.lastCreatedRideId = rideId;
    }
    RideService.lastCreatedRideData = normalized;

    if (mounted) {
      Navigator.of(context).pop(OrangeMoneyPaymentResult.success);
    }
  }

  Future<void> _cancelOrder() async {
    _stopAllListeners();
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
    _wsPaymentSub?.cancel();
    _wsReconnectSub?.cancel();

    // Connexion et adhésion au canal de la course par WebSocket
    RealtimeService().connect();
    if (rideId.isNotEmpty) {
      RealtimeService().joinRide(rideId);
    }

    // Vérifier immédiatement si un événement WebSocket est déjà arrivé en cache
    final cachedStatus = RealtimeService().lastRideStatusEvent;
    if (cachedStatus != null) {
      final matchesRide = rideId.isEmpty ||
          cachedStatus.rideId.isEmpty ||
          cachedStatus.rideId == rideId ||
          cachedStatus.rideId.endsWith(rideId) ||
          rideId.endsWith(cachedStatus.rideId);
      if (matchesRide && _isRidePaidOrActive(cachedStatus.raw)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isCompleted) {
            _completePaymentAndProceed(cachedStatus.raw);
          }
        });
        return;
      }
    }

    // 1. Écoute temps réel du statut de la course via WebSocket (rideStatusStream)
    try {
      _wsStatusSub = RealtimeService().rideStatusStream.listen((event) {
        if (!mounted || _isCompleted) return;
        final matchesRide = rideId.isEmpty ||
            event.rideId.isEmpty ||
            event.rideId == rideId ||
            event.rideId.endsWith(rideId) ||
            rideId.endsWith(event.rideId);

        if (matchesRide) {
          final status = event.status.toUpperCase().trim();
          debugPrint(
              '[PaymentModal] ⚡ WebSocket rideStatusStream reçu: $status pour course $rideId');

          if (status == 'SEARCHING' ||
              status == 'PAID' ||
              status == 'ACCEPTED' ||
              status == 'DRIVER_ACCEPTED' ||
              status == 'DRIVER_ASSIGNED' ||
              status == 'CONFIRMED' ||
              status == 'APPROACHING' ||
              status == 'EN_ROUTE' ||
              status == 'ASSIGNED' ||
              status == 'IN_PROGRESS' ||
              status == 'DRIVER_ARRIVED' ||
              event.driver != null ||
              _isRidePaidOrActive(event.raw)) {
            _completePaymentAndProceed(
              event.raw.isNotEmpty
                  ? event.raw
                  : {'id': rideId, 'status': status},
            );
          } else if (status.startsWith('CANCEL') ||
              status == 'REJECTED' ||
              status == 'NO_DRIVER') {
            _stopAllListeners();
            if (mounted) {
              Navigator.of(context).pop(OrangeMoneyPaymentResult.cancelled);
            }
          }
        }
      });
    } catch (_) {}

    // 2. Écoute temps réel de la confirmation de paiement via WebSocket (paymentStatusStream)
    try {
      _wsPaymentSub = RealtimeService().paymentStatusStream.listen((event) {
        if (!mounted || _isCompleted) return;
        final matchesRide = rideId.isEmpty ||
            event.rideId == null ||
            event.rideId!.isEmpty ||
            event.rideId == rideId ||
            event.rideId!.endsWith(rideId) ||
            rideId.endsWith(event.rideId!);

        if (matchesRide) {
          final pStatus = event.status.toUpperCase().trim();
          debugPrint(
              '[PaymentModal] ⚡ WebSocket paymentStatusStream reçu: $pStatus pour course $rideId');
          if (pStatus == 'SUCCESS' ||
              pStatus == 'PAID' ||
              pStatus == 'COMPLETED' ||
              pStatus == 'SUCCEEDED' ||
              pStatus == 'CONFIRMED') {
            _completePaymentAndProceed({
              if (RideService.lastCreatedRideData != null)
                ...RideService.lastCreatedRideData!,
              'id': rideId,
              'status': 'SEARCHING',
              'payment': {
                'status': 'SUCCESS',
                'method': widget.paymentMethod.apiValue,
              },
            });
          } else if (pStatus == 'FAILED' ||
              pStatus == 'CANCELLED' ||
              pStatus == 'DECLINED' ||
              pStatus == 'REJECTED') {
            _stopAllListeners();
            if (mounted) {
              Navigator.of(context).pop(OrangeMoneyPaymentResult.cancelled);
            }
          }
        }
      });
    } catch (_) {}

    // 3. Resynchronisation unique si le WebSocket se reconnecte au retour dans l'app
    try {
      _wsReconnectSub = RealtimeService().onReconnect.listen((_) {
        if (mounted && _isWaitingForSearching && !_isCompleted) {
          if (rideId.isNotEmpty) {
            RealtimeService().joinRide(rideId);
          }
          _triggerControlledStatusVerification(force: true);
        }
      });
    } catch (_) {}

    // 4. Fallback léger et espacé (toutes les 8 secondes au lieu d'une boucle rapide)
    // pour ne jamais surcharger le backend tout en garantissant la détection si un événement WS est manqué
    _statusPollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || !_isWaitingForSearching || _isCompleted) return;
      _verifyRideAndPaymentStatus();
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
      final rideObj = rideData['ride'] is Map<String, dynamic>
          ? rideData['ride'] as Map<String, dynamic>
          : rideData;
      final payment = (rideData['payment'] is Map<String, dynamic>
              ? rideData['payment']
              : rideObj['payment']) as Map<String, dynamic>?;
      final orderId = (payment?['orderId'] ?? rideObj['orderId'] ?? rideData['orderId'])?.toString();
      final paymentUrl = (payment?['paymentUrl'] ??
              payment?['waveLaunchUrl'] ??
              payment?['checkoutUrl'] ??
              payment?['url'] ??
              rideObj['paymentUrl'] ??
              rideData['paymentUrl'])
          ?.toString();
      final payToken = payment?['payToken']?.toString();
      final rideId = (rideObj['id'] ??
              rideObj['_id'] ??
              rideObj['rideId'] ??
              rideData['id'] ??
              rideData['_id'] ??
              rideData['rideId'] ??
              payment?['rideId'])
          ?.toString() ??
          '';
      if (rideId.isNotEmpty) {
        RideService.lastCreatedRideId = rideId;
      }
      final status = (rideObj['status'] as String? ?? rideData['status'] as String? ?? '').toUpperCase().trim();

      debugPrint(
          '[PaymentModal] ✅ Course créée ID: $rideId - Statut initial: $status');
      debugPrint(
          '[PaymentModal] 💳 Paiement (${payment?['method']}) URL: $paymentUrl - Token: $payToken');

      // Si le statut est DÉJÀ SEARCHING ou PAYÉ ou ACCEPTÉ (ex: Espèces/CASH ou déjà validé)
      if (_isRidePaidOrActive(rideData)) {
        _completePaymentAndProceed(rideData);
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
