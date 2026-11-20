import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/pages/home_page.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/services/active_ride_offline_storage.dart';
import 'package:seddo/features/ride/data/services/ride_live_update_service_impl.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/domain/models/ride_live_update_data.dart';
import 'package:seddo/features/ride/presentation/pages/ride_receipt_page.dart';
import 'package:seddo/features/ride/presentation/widgets/driver_avatar_widget.dart';
import 'package:seddo/services/realtime_service.dart';
import 'package:seddo/services/receipt_pdf_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Écran de fin de course inspiré du modèle Figma Community (base light & couleurs Seddo) :
/// - Header avec retour `<` et titre centré "Noter la course"
/// - Grande carte blanche flottante épurée (style Figma / Dribbble)
/// - Photo ronde du chauffeur centrée à cheval sur le haut de la carte
/// - Nom du chauffeur + plaque & modèle
/// - "Comment s'est passée votre course ?" + sous-titre
/// - 5 grandes étoiles dorées interactives (or / ambre vif style Figma)
/// - 4 compliments rapides (Conduite prudente, Ponctuel, Voiture propre, Sympathique)
/// - Champ commentaire "Commentaires additionnels..." style Figma
/// - Bouton principal pleine largeur "Envoyer" aux couleurs Seddo
/// - Module de reçu élégant et discret en bas (accès au reçu, téléchargement et partage)
class RideRatingPage extends StatefulWidget {
  final PlaceSearchResult? departure;
  final PlaceSearchResult destination;
  final DriverModel driver;
  final RideOptionModel rideOption;
  final String arrivalTime;
  final String durationText;
  final String paymentPhone;
  final String? paymentMethod;
  final String? rideId;
  final RideService? rideService;

  const RideRatingPage({
    super.key,
    this.departure,
    required this.destination,
    required this.driver,
    required this.rideOption,
    this.arrivalTime = '18:41',
    this.durationText = '22 min',
    this.paymentPhone = '77 ••• 45 12',
    this.paymentMethod,
    this.rideId,
    this.rideService,
  });

  /// Ouvre la page de notation sous forme de Bottom Sheet modal qui monte presque en haut de l'écran
  static Future<void> show({
    required BuildContext context,
    PlaceSearchResult? departure,
    required PlaceSearchResult destination,
    required DriverModel driver,
    required RideOptionModel rideOption,
    String arrivalTime = '18:41',
    String durationText = '22 min',
    String paymentPhone = '77 ••• 45 12',
    String? paymentMethod,
    String? rideId,
    RideService? rideService,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      barrierColor: const Color(0x73000000),
      builder: (ctx) => RideRatingPage(
        departure: departure,
        destination: destination,
        driver: driver,
        rideOption: rideOption,
        arrivalTime: arrivalTime,
        durationText: durationText,
        paymentPhone: paymentPhone,
        paymentMethod: paymentMethod,
        rideId: rideId,
        rideService: rideService,
      ),
    );
  }

  @override
  State<RideRatingPage> createState() => _RideRatingPageState();
}

class _FeedbackTag {
  final String translationKey;
  final IconData icon;

  const _FeedbackTag({
    required this.translationKey,
    required this.icon,
  });
}

class _RideRatingPageState extends State<RideRatingPage>
    with SingleTickerProviderStateMixin {
  int _selectedStars = 5;
  final Set<String> _selectedTags = {'rating.safe_driving'};
  late final TextEditingController _commentController;
  late final RideService _rideService;
  late final AnimationController _sheetAnimationController;
  Animation<double>? _sheetAnimation;
  late String _paymentPhone;
  late DriverModel _currentDriver;
  bool _isSubmitting = false;
  bool _isDownloadingReceipt = false;
  bool _isSharingReceipt = false;
  bool _isRedirecting = false;
  double _dragOffset = 0.0;
  final ScrollController _scrollController = ScrollController();

  static const Map<String, String> _tagToCompliment = {
    'rating.safe_driving': 'SAFE_DRIVING',
    'rating.punctual': 'PUNCTUAL',
    'rating.clean_car': 'CLEAN_CAR',
    'rating.friendly': 'FRIENDLY',
  };

  static const List<_FeedbackTag> _tags = [
    _FeedbackTag(
      translationKey: 'rating.safe_driving',
      icon: Icons.thumb_up_alt_rounded,
    ),
    _FeedbackTag(
      translationKey: 'rating.punctual',
      icon: Icons.access_time_rounded,
    ),
    _FeedbackTag(
      translationKey: 'rating.clean_car',
      icon: Icons.directions_car_rounded,
    ),
    _FeedbackTag(
      translationKey: 'rating.friendly',
      icon: Icons.favorite_border_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _rideService = widget.rideService ?? RideService();
    _paymentPhone = widget.paymentPhone;
    _currentDriver = widget.driver;
    _sheetAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    ActiveRideOfflineStorage.clearActiveRide();
    final initialRideId = widget.rideId ??
        RideService.lastCompletedRideId ??
        RideService.lastCreatedRideId;
    if (initialRideId != null && initialRideId.isNotEmpty) {
      RideService.lastCompletedRideId = initialRideId;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('seddo_last_completed_ride_id', initialRideId);
      });
    }

    _syncCompletedLiveUpdate();
    _fetchPaymentDetails();
  }

  void _syncCompletedLiveUpdate() {
    final effectiveRideId = widget.rideId ?? RideService.lastCreatedRideId;
    if (effectiveRideId != null && effectiveRideId.isNotEmpty) {
      try {
        RideLiveUpdateServiceImpl().updateLiveUpdate(
          RideLiveUpdateData(
            rideId: effectiveRideId,
            driverName: widget.driver.name,
            carModel: widget.driver.carModel,
            carColor: widget.driver.carColor,
            licensePlate: widget.driver.licensePlate,
            departureText: widget.departure?.mainText ?? '',
            destinationText: widget.destination.mainText,
            statusLabel: 'Course terminée',
            phase: RideLiveUpdatePhase.completed,
            etaMinutes: 0,
            progress: 1.0,
            updatedAtTimestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      } catch (_) {}
    }
  }

  Future<void> _fetchPaymentDetails() async {
    final effectiveRideId = widget.rideId ?? RideService.lastCreatedRideId;
    if (effectiveRideId != null && effectiveRideId.isNotEmpty) {
      try {
        final data = await _rideService.getRideDetails(effectiveRideId);
        if (data != null && mounted) {
          if (data['driver'] != null || data['vehicle'] != null) {
            try {
              final parsed = DriverModel.fromRideJson(
                data,
                fallbackCarColor: _currentDriver.carColor,
                fallbackName: _currentDriver.name,
                fallbackPhotoUrl: _currentDriver.photoUrl,
              );
              if (parsed.name.isNotEmpty && parsed.name != 'Chauffeur Seddo') {
                setState(() {
                  _currentDriver = parsed;
                });
              }
            } catch (_) {}
          }
          final rideObj = data['ride'] is Map<String, dynamic>
              ? data['ride'] as Map<String, dynamic>
              : data;
          final pMap = rideObj['payment'] is Map<String, dynamic>
              ? rideObj['payment'] as Map<String, dynamic>
              : null;
          if (pMap != null && pMap['phone'] != null) {
            setState(() {
              _paymentPhone = pMap['phone'].toString();
            });
          }
        }
      } catch (_) {}
    }
  }

  void _dismissLiveNotification() {
    final effectiveRideId = widget.rideId ??
        RideService.lastCompletedRideId ??
        RideService.lastCreatedRideId;
    if (effectiveRideId != null && effectiveRideId.isNotEmpty) {
      RideLiveUpdateServiceImpl().endLiveUpdate(rideId: effectiveRideId);
    }
  }

  @override
  void dispose() {
    _sheetAnimationController.dispose();
    _dismissLiveNotification();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleSheetCollapsed() {
    final media = MediaQuery.of(context);
    final sheetHeight = media.size.height * 0.92;
    final collapsedOffset = sheetHeight * 0.58;

    if (_dragOffset > 50) {
      _animateToOffset(0.0);
    } else {
      _animateToOffset(collapsedOffset);
    }
  }

  void _animateToOffset(double targetOffset) {
    _sheetAnimationController.stop();
    _sheetAnimationController.reset();
    _sheetAnimation = Tween<double>(
      begin: _dragOffset,
      end: targetOffset,
    ).animate(CurvedAnimation(
      parent: _sheetAnimationController,
      curve: Curves.easeOutCubic,
    ))..addListener(() {
      setState(() {
        _dragOffset = _sheetAnimation!.value;
      });
    });
    _sheetAnimationController.forward();
  }

  void _toggleTag(String tagKey) {
    setState(() {
      if (_selectedTags.contains(tagKey)) {
        _selectedTags.remove(tagKey);
      } else {
        _selectedTags.add(tagKey);
      }
    });
  }

  String _getRatingFeedbackText() {
    switch (_selectedStars) {
      case 5:
        return 'Excellent !';
      case 4:
        return 'Très bien';
      case 3:
        return 'Correct';
      case 2:
        return 'Moyen';
      case 1:
      default:
        return 'À améliorer';
    }
  }

  Future<void> _submitRating() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      String? effectiveRideId = widget.rideId ??
          RideService.lastCompletedRideId ??
          RideService.lastCreatedRideId ??
          RideService.lastCreatedRideData?['id']?.toString();

      if (effectiveRideId == null || effectiveRideId.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        effectiveRideId = prefs.getString('seddo_last_completed_ride_id');
      }

      if (effectiveRideId == null || effectiveRideId.isEmpty) {
        try {
          final currentRes = await _rideService.getCurrentRide();
          effectiveRideId = currentRes?['ride']?['id']?.toString();
        } catch (_) {}
      }

      const allowedCompliments = {
        'SAFE_DRIVING',
        'PUNCTUAL',
        'CLEAN_CAR',
        'FRIENDLY',
        'POLITE_CLIENT',
      };

      final compliments = _selectedTags
          .map((tag) => _tagToCompliment[tag] ?? tag)
          .map((c) => c.toUpperCase() == 'POLITE' ? 'FRIENDLY' : c.toUpperCase())
          .where((c) => allowedCompliments.contains(c))
          .toList();
      final comment = _commentController.text.trim();

      bool success = false;
      if (effectiveRideId != null && effectiveRideId.isNotEmpty) {
        success = await _rideService.submitRating(
          rideId: effectiveRideId,
          stars: _selectedStars,
          comment: comment.isNotEmpty ? comment : null,
          compliments: compliments,
        );
      } else {
        success = true;
      }

      _dismissLiveNotification();

      if (success) {
        RideService.lastCompletedRideId = null;
        RideService.clearActiveRideData();
        RealtimeService().clearLastRideStatus();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('seddo_last_completed_ride_id');
        await ActiveRideOfflineStorage.clearActiveRide();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.slateDark,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
              ),
              content: Text(
                'rating.thanks_notice'.tr(),
                style: GoogleFonts.inter(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
          Navigator.of(context).pushAndRemoveUntil(
            SlideRightToLeftRoute(
              page: const HomePage(),
            ),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
              ),
              content: Text(
                'Impossible d\'envoyer votre avis pour le moment. Veuillez réessayer.',
                style: GoogleFonts.inter(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[RideRatingPage] Erreur _submitRating: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
            ),
            content: Text(
              'Erreur de connexion. Veuillez réessayer.',
              style: GoogleFonts.inter(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _downloadReceipt() async {
    if (_isDownloadingReceipt) return;
    setState(() => _isDownloadingReceipt = true);

    try {
      final effectiveRideId = widget.rideId ?? RideService.lastCreatedRideId;
      ReceiptSaveResult? saveResult;

      if (effectiveRideId != null && effectiveRideId.isNotEmpty) {
        final pdfBytes = await _rideService.downloadReceiptPdf(effectiveRideId);
        if (pdfBytes != null && pdfBytes.isNotEmpty) {
          saveResult = await ReceiptPdfService.saveBytesToDevice(
            bytes: pdfBytes,
            fileName: 'Recu_Seddo_$effectiveRideId.pdf',
          );
        } else {
          final linkData = await _rideService.getReceiptLink(effectiveRideId);
          if (linkData != null) {
            final token = linkData['token']?.toString();
            if (token != null && token.isNotEmpty) {
              final tokenBytes = await _rideService.downloadReceiptByToken(token);
              if (tokenBytes != null && tokenBytes.isNotEmpty) {
                saveResult = await ReceiptPdfService.saveBytesToDevice(
                  bytes: tokenBytes,
                  fileName: 'Recu_Seddo_$token.pdf',
                );
              }
            }

            final url = linkData['url']?.toString();
            if ((saveResult == null || !saveResult.success) && url != null && url.isNotEmpty) {
              final uri = Uri.tryParse(url);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          }
        }
      }

      if (saveResult == null || !saveResult.success) {
        saveResult = await ReceiptPdfService.saveReceiptToDevice(
          departureName: widget.departure?.mainText ?? 'Sacré-Cœur 3',
          arrivalName: widget.destination.mainText,
          departureTime: '18:19',
          arrivalTime: widget.arrivalTime,
          distanceText: widget.durationText,
          durationText: widget.durationText,
          dateText: 'Aujourd\'hui',
          priceText: widget.rideOption.formattedPrice,
          rideType: widget.rideOption.title,
          driverName: widget.driver.name.isNotEmpty ? widget.driver.name : 'Moussa',
          driverCar: _currentDriver.carModel,
          driverPlate: _currentDriver.licensePlate,
          driverRating: ((_currentDriver.rating > 0 ? _currentDriver.rating : 4.9))
              .toStringAsFixed(1),
          paymentPhone: _paymentPhone,
          orangeRef: effectiveRideId ?? 'SEDDO_${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      if (!mounted) return;

      final isSuccess = saveResult.success;
      final message = isSuccess
          ? 'rating.download_success'.tr()
          : 'rating.download_error'.tr();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
          backgroundColor: isSuccess ? AppColors.slateDark : AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
          ),
          action: isSuccess && saveResult.primaryPath.isNotEmpty
              ? SnackBarAction(
                  label: 'rating.share_receipt'.tr(),
                  textColor: AppColors.orangeAccent,
                  onPressed: () {
                    try {
                      SharePlus.instance.share(
                        ShareParams(
                          files: [XFile(saveResult!.primaryPath)],
                          subject: 'rating.share_subject'.tr(),
                        ),
                      );
                    } catch (_) {}
                  },
                )
              : null,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'rating.download_error'.tr(),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingReceipt = false);
      }
    }
  }

  Future<void> _shareReceipt() async {
    if (_isSharingReceipt) return;
    setState(() => _isSharingReceipt = true);

    try {
      final effectiveRideId = widget.rideId ?? RideService.lastCreatedRideId;
      String? receiptUrl;
      String? filePath;

      if (effectiveRideId != null && effectiveRideId.isNotEmpty) {
        final linkData = await _rideService.getReceiptLink(effectiveRideId);
        if (linkData != null && linkData['url'] != null) {
          receiptUrl = linkData['url']?.toString();
        }

        final pdfBytes = await _rideService.downloadReceiptPdf(effectiveRideId);
        if (pdfBytes != null && pdfBytes.isNotEmpty) {
          final saveResult = await ReceiptPdfService.saveBytesToDevice(
            bytes: pdfBytes,
            fileName: 'Recu_Seddo_$effectiveRideId.pdf',
          );
          if (saveResult.success) {
            filePath = saveResult.primaryPath;
          }
        }
      }

      if (filePath == null || filePath.isEmpty) {
        final localSave = await ReceiptPdfService.saveReceiptToDevice(
          departureName: widget.departure?.mainText ?? 'Sacré-Cœur 3',
          arrivalName: widget.destination.mainText,
          departureTime: '18:19',
          arrivalTime: widget.arrivalTime,
          distanceText: widget.durationText,
          durationText: widget.durationText,
          dateText: 'Aujourd\'hui',
          priceText: widget.rideOption.formattedPrice,
          rideType: widget.rideOption.title,
          driverName: widget.driver.name.isNotEmpty ? widget.driver.name : 'Moussa',
          driverCar: _currentDriver.carModel,
          driverPlate: _currentDriver.licensePlate,
          driverRating: ((_currentDriver.rating > 0 ? _currentDriver.rating : 4.9))
              .toStringAsFixed(1),
          paymentPhone: _paymentPhone,
          orangeRef: effectiveRideId ?? 'SEDDO_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (localSave.success) {
          filePath = localSave.primaryPath;
        }
      }

      final shareText = receiptUrl != null && receiptUrl.isNotEmpty
          ? 'rating.share_text'.tr(args: [receiptUrl])
          : null;

      if (filePath != null && filePath.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(filePath)],
            subject: 'rating.share_subject'.tr(),
            text: shareText,
          ),
        );
      } else if (shareText != null) {
        await SharePlus.instance.share(
          ShareParams(
            subject: 'rating.share_subject'.tr(),
            text: shareText,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'rating.download_error'.tr(),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharingReceipt = false);
      }
    }
  }

  void _redirectToHome() {
    if (_isRedirecting) return;
    _isRedirecting = true;
    _dismissLiveNotification();
    ActiveRideOfflineStorage.clearActiveRide();
    RideService.lastCompletedRideId = null;
    RideService.clearActiveRideData();
    RealtimeService().clearLastRideStatus();
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('seddo_last_completed_ride_id');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        SlideRightToLeftRoute(
          page: const HomePage(),
        ),
        (route) => false,
      );
    });
  }

  void _showReceipt() {
    Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: RideReceiptPage(
          departure: widget.departure,
          destination: widget.destination,
          driver: _currentDriver,
          rideOption: widget.rideOption,
          arrivalTime: widget.arrivalTime,
          durationText: widget.durationText,
          paymentPhone: widget.paymentPhone,
          paymentMethod: widget.paymentMethod,
          rideId: widget.rideId ?? RideService.lastCreatedRideId,
          rideService: _rideService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom;
    final viewBottomInset = media.viewInsets.bottom;
    // Monte presque jusqu'en haut de la page (~92% de l'écran)
    final sheetHeight = media.size.height * 0.92;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _redirectToHome();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0x73000000), // Fond sombre semi-transparent de modal barrier
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Stack(
            children: [
              // 1. Zone tactile supérieure au-dessus du bottom sheet (ferme en tapant au-dessus, flèche supprimée)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: sheetHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _redirectToHome,
                  child: Container(
                    color: AppColors.transparent,
                  ),
                ),
              ),

              // 2. Le Bottom Sheet blanc qui monte presque en haut et se ferme en glissant vers le bas
              Align(
                alignment: Alignment.bottomCenter,
                child: Transform.translate(
                  offset: Offset(0, _dragOffset),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (details) {
                      setState(() {
                        _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, sheetHeight);
                      });
                    },
                    onVerticalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0.0;
                      if (_dragOffset > 70 || velocity > 180) {
                        _redirectToHome();
                      } else {
                        _animateToOffset(0.0);
                      }
                    },
                    child: Container(
                      height: sheetHeight,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 24,
                            offset: Offset(0, -6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Drag handle en haut du sheet : Clic pour descendre ou remonter
                          GestureDetector(
                            key: const ValueKey('rating_sheet_drag_handle'),
                            behavior: HitTestBehavior.opaque,
                            onTap: _toggleSheetCollapsed,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 32),
                              child: Center(
                                child: Container(
                                  width: 44,
                                  height: 4.5,
                                  decoration: BoxDecoration(
                                    color: AppColors.sheetHandleGrey,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Contenu défilant du bottom sheet
                          Expanded(
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (notification is ScrollUpdateNotification) {
                                  if (_scrollController.hasClients &&
                                      _scrollController.position.pixels <= 0 &&
                                      (notification.scrollDelta ?? 0) < 0) {
                                    setState(() {
                                      _dragOffset = (_dragOffset - (notification.scrollDelta ?? 0))
                                          .clamp(0.0, sheetHeight);
                                    });
                                  }
                                } else if (notification is OverscrollNotification) {
                                  if (notification.overscroll < 0) {
                                    setState(() {
                                      _dragOffset = (_dragOffset - notification.overscroll)
                                          .clamp(0.0, sheetHeight);
                                    });
                                  }
                                } else if (notification is ScrollEndNotification) {
                                  final velocity =
                                      notification.dragDetails?.primaryVelocity ??
                                          0.0;
                                  if (_dragOffset > 70 || velocity > 180) {
                                    _redirectToHome();
                                  } else if (_dragOffset > 0) {
                                    _animateToOffset(0.0);
                                  }
                                }
                                return false;
                              },
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  20,
                                  viewBottomInset > 0 ? viewBottomInset + 16 : bottomInset + 24,
                                ),
                                child: Column(
                                  children: [
                                    _buildFigmaRatingContent(),
                                    const SizedBox(height: 16),
                                    _buildBottomReceiptCard(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Contenu de notation inspiré du modèle Figma Community :
  /// - Avatar rond du chauffeur centré en haut
  /// - Nom du chauffeur
  /// - Plaque d'immatriculation et véhicule
  /// - "Comment s'est passée votre course ?"
  /// - "Votre avis nous aide à améliorer le service"
  /// - 5 grandes étoiles dorées interactives
  /// - Compliments rapides
  /// - Champ commentaire
  /// - Bouton "Envoyer"
  Widget _buildFigmaRatingContent() {
    const avatarDiameter = 88.0;
    final plateStr = _currentDriver.licensePlate.trim().replaceAll('-', ' ');
    final carModel = _currentDriver.carModel.trim();
    final carColor = _currentDriver.carColor.trim();
    final carWithColor = carColor.isNotEmpty &&
            !carModel.toLowerCase().contains(carColor.toLowerCase())
        ? '$carModel $carColor'
        : carModel;
    final driverFullName = _currentDriver.name.isNotEmpty
        ? _currentDriver.name
        : 'Chauffeur Seddo';
    final vehicleAndPlate = carWithColor.isNotEmpty
        ? (plateStr.isNotEmpty ? '$carWithColor · $plateStr' : carWithColor)
        : (plateStr.isNotEmpty ? plateStr : 'DK 482 AB');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Photo circulaire du chauffeur
        _buildDriverAvatar(avatarDiameter),

        const SizedBox(height: 12),

        // 1. Nom du chauffeur (ex: "Asif Raj" ou "Moussa Sène")
        Text(
          driverFullName,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),

        const SizedBox(height: 4),

        // 2. Plaque d'immatriculation et véhicule
        Text(
          vehicleAndPlate,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
            letterSpacing: 0.3,
          ),
        ),

        const SizedBox(height: 20),

        // 3. Question principale : "How is your trip?" / "Comment s'est passée votre course ?"
        Text(
          'rating.how_is_trip'.tr(),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.4,
            height: 1.25,
          ),
        ),

        const SizedBox(height: 8),

        // 4. Sous-titre : "Your feedback will help improve driving experience"
        Text(
          'rating.feedback_hint'.tr(),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF64748B),
            height: 1.35,
          ),
        ),

        const SizedBox(height: 18),

        // 5. Cinq grandes étoiles interactives (or / ambre vif style Figma)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starNumber = index + 1;
            final isSelected = starNumber <= _selectedStars;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedStars = starNumber;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 160),
                  scale: isSelected ? 1.05 : 0.95,
                  child: Icon(
                    Icons.star_rounded,
                    size: 48,
                    color: isSelected
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 6),

        // Indicateur dynamique de ressenti
        Text(
          _getRatingFeedbackText(),
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFF59E0B),
          ),
        ),

        const SizedBox(height: 16),

        // 6. Compliments rapides (Badges arrondis élégants)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: _tags.map(_buildTagChip).toList(),
        ),

        const SizedBox(height: 18),

        // 7. Champ commentaire "Commentaires additionnels..." style Figma
        _buildFigmaCommentField(),

        const SizedBox(height: 20),

        // 8. Bouton "Submit Review" / "Envoyer"
        _buildFigmaSubmitButton(),
      ],
    );
  }

  /// Avatar rond avec bord blanc 4px et pastille d'étoile / note réelle dans le coin inférieur
  Widget _buildDriverAvatar(double size) {
    final ratingVal = _currentDriver.rating > 0 ? _currentDriver.rating : 4.9;
    final ratingDisplay = (ratingVal * 10 == (ratingVal * 10).roundToDouble())
        ? ratingVal.toStringAsFixed(1)
        : ratingVal.toStringAsFixed(2);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          DriverAvatarWidget(
            photoUrl: _currentDriver.photoUrl,
            rideId: widget.rideId,
            name: _currentDriver.name,
            size: size,
            backgroundColor: AppColors.peachContainer,
            initialsColor: AppColors.primary,
            border: Border.all(color: AppColors.white, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF1F5F9),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    ratingDisplay,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slateDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Chip de compliment (Conduite prudente, Ponctuel, etc.)
  Widget _buildTagChip(_FeedbackTag tag) {
    final isSelected = _selectedTags.contains(tag.translationKey);

    return GestureDetector(
      onTap: () => _toggleTag(tag.translationKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF0E6) : AppColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tag.icon,
              size: 15,
              color: isSelected ? AppColors.primary : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              tag.translationKey.tr(),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppColors.primary : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Boîte de commentaire style Figma : titre, rectangle gris très clair, coins arrondis, placeholder sobre
  Widget _buildFigmaCommentField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.1,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 15,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                'rating.comment_title'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _commentController,
            maxLines: 4,
            minLines: 3,
            maxLength: 250,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: 'rating.additional_comments'.tr(),
              hintStyle: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF94A3B8),
              ),
              counterStyle: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bouton "Submit Review" / "Envoyer" aux couleurs Seddo
  Widget _buildFigmaSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: const Color(0x40FB5B00),
        ),
        onPressed: _isSubmitting ? null : _submitRating,
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.send_rounded,
                    size: 18,
                    color: AppColors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'rating.submit'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Module discret en bas pour le reçu de la course (sans encombrer la carte de notation)
  Widget _buildBottomReceiptCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'rating.total_paid'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      widget.rideOption.formattedPrice,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Actions Télécharger & Partager le reçu
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isDownloadingReceipt ? null : _downloadReceipt,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                    side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isDownloadingReceipt
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(
                          Icons.file_download_outlined,
                          size: 17,
                          color: AppColors.primary,
                        ),
                  label: Text(
                    'rating.download_receipt'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSharingReceipt ? null : _shareReceipt,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                    side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isSharingReceipt
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(
                          Icons.share_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                  label: Text(
                    'rating.share_receipt'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Bouton "Voir le reçu" pleine largeur
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _showReceipt,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF8FAFC),
                foregroundColor: const Color(0xFF0F172A),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                Icons.receipt_long_rounded,
                size: 18,
                color: Color(0xFF0F172A),
              ),
              label: Text(
                'rating.view_receipt'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
