import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/pages/place_search_page.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/pages/ride_receipt_page.dart';
import 'package:seddo/services/receipt_pdf_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen displayed at the end of the trip to rate the driver matching the design:
/// - Top bar: Circular back button and centered Seddo logo with decorative organic waves
/// - Illustrated driver avatar with orange cap & polo, verification shield, and sparkles
/// - "Comment s'est passée votre course avec Moussa ?"
/// - Subtitle with destination, time and duration
/// - 5-star rating selector (5 stars active by default)
/// - 4 feedback tag pills (Conduite prudente, Ponctuel, Voiture propre, Sympathique)
/// - Comment input field (optional message)
/// - Total payé card with 3D car asset, "Prix fixe" badge, Orange Money details & chevron
/// - Warm peach appreciation card ("Merci pour votre avis !")
/// - Primary orange "Envoyer" button with paper plane and energy bursts (submits POST /v1/rides/{id}/rating)
/// - "Télécharger le reçu" & "Partager le reçu" actions (using GET /v1/rides/{id}/receipt.pdf and /receipt)
/// - Secondary "Voir le reçu" button opening detailed receipt
class RideRatingPage extends StatefulWidget {
  final PlaceSearchResult? departure;
  final PlaceSearchResult destination;
  final DriverModel driver;
  final RideOptionModel rideOption;
  final String arrivalTime;
  final String durationText;
  final String paymentPhone;
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
    this.rideId,
    this.rideService,
  });

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

class _RideRatingPageState extends State<RideRatingPage> {
  int _selectedStars = 5;
  final Set<String> _selectedTags = {'rating.safe_driving'};
  late final TextEditingController _commentController;
  late final RideService _rideService;
  bool _isSubmitting = false;
  bool _isDownloadingReceipt = false;
  bool _isSharingReceipt = false;

  static const Map<String, String> _tagToCompliment = {
    'rating.safe_driving': 'SAFE_DRIVING',
    'rating.punctual': 'PUNCTUAL',
    'rating.clean_car': 'CLEAN_CAR',
    'rating.friendly': 'POLITE',
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
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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

  Future<void> _submitRating() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final effectiveRideId = widget.rideId ?? RideService.lastCreatedRideId;
      final compliments = _selectedTags
          .map((tag) => _tagToCompliment[tag] ?? tag)
          .toList();
      final comment = _commentController.text.trim();

      if (effectiveRideId != null && effectiveRideId.isNotEmpty) {
        await _rideService.submitRating(
          rideId: effectiveRideId,
          stars: _selectedStars,
          comment: comment.isNotEmpty ? comment : null,
          compliments: compliments,
        );
      }
    } catch (_) {
      // Ignorer silencieusement pour toujours afficher la confirmation visuelle
    } finally {
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
        Navigator.of(context).popUntil((route) => route.isFirst);
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
        // 1. Essayer le reçu binaire direct depuis l'API GET /v1/rides/{id}/receipt.pdf
        final pdfBytes = await _rideService.downloadReceiptPdf(effectiveRideId);
        if (pdfBytes != null && pdfBytes.isNotEmpty) {
          saveResult = await ReceiptPdfService.saveBytesToDevice(
            bytes: pdfBytes,
            fileName: 'Recu_Seddo_$effectiveRideId.pdf',
          );
        } else {
          // 2. Sinon essayer via le lien signé GET /v1/rides/{id}/receipt
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

      // 3. Fallback de génération locale haute fidélité
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
          driverCar: widget.driver.carModel,
          driverPlate: widget.driver.licensePlate,
          driverRating: '${widget.driver.rating.toInt()}',
          paymentPhone: widget.paymentPhone,
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
        // Obtenir le lien de partage signé depuis l'API GET /v1/rides/{id}/receipt
        final linkData = await _rideService.getReceiptLink(effectiveRideId);
        if (linkData != null && linkData['url'] != null) {
          receiptUrl = linkData['url']?.toString();
        }

        // Obtenir le fichier PDF binaire depuis l'API GET /v1/rides/{id}/receipt.pdf
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

      // Si aucun fichier PDF binaire obtenu, générer le reçu local
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
          driverCar: widget.driver.carModel,
          driverPlate: widget.driver.licensePlate,
          driverRating: '${widget.driver.rating.toInt()}',
          paymentPhone: widget.paymentPhone,
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

  void _redirectToPlaceSearch() {
    Navigator.of(context).pushAndRemoveUntil(
      SlideRightToLeftRoute(
        page: const PlaceSearchPage(),
      ),
      (route) => route.isFirst,
    );
  }

  void _showReceipt() {
    Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: RideReceiptPage(
          departure: widget.departure,
          destination: widget.destination,
          driver: widget.driver,
          rideOption: widget.rideOption,
          arrivalTime: widget.arrivalTime,
          durationText: widget.durationText,
          paymentPhone: widget.paymentPhone,
          rideId: widget.rideId ?? RideService.lastCreatedRideId,
          rideService: _rideService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final driverFirstName = widget.driver.name.isNotEmpty
        ? widget.driver.name.split(' ').first
        : 'Moussa';
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _redirectToPlaceSearch();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: Stack(
          children: [
            // Background organic waves (top-right peach blob and bottom-left orange wave)
            Positioned.fill(
              child: CustomPaint(
                painter: _RatingBackgroundWavesPainter(),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // 1. Top Navigation Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Circular Back Button
                        GestureDetector(
                          onTap: _redirectToPlaceSearch,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.shadowSoftBlack,
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            size: 20,
                            color: AppColors.slateDark,
                          ),
                        ),
                      ),

                      // Centered SEDDO Logo
                      SvgPicture.asset(
                        'assets/icons/seddo_logo_orange.svg',
                        height: 26,
                        fit: BoxFit.contain,
                      ),

                      // Empty balancing spacer
                      const SizedBox(width: 42),
                    ],
                  ),
                ),

                // Scrollable Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      4,
                      20,
                      bottomInset > 0 ? bottomInset + 12 : 24,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 4),

                        // 2. Driver Avatar with Badge & Sparkles
                        const _DriverAvatarWithBadge(),

                        const SizedBox(height: 10),

                        // 3. Question Title
                        Text(
                          'rating.how_was_ride_with'.tr(args: [driverFirstName]),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.slateDark,
                            letterSpacing: -0.4,
                            height: 1.25,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // 4. Subtitle: "Almadies • 18:41 • 22 min"
                        Text(
                          '${widget.destination.mainText} • ${widget.arrivalTime} • ${widget.durationText}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slateMuted,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // 5. 5-Star Rating Selector (4 active orange, 1 outline)
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
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                child: isSelected
                                    ? const Icon(
                                        Icons.star_rounded,
                                        size: 40,
                                        color: AppColors.orangeAccent,
                                      )
                                    : const Icon(
                                        Icons.star_outline_rounded,
                                        size: 40,
                                        color: AppColors.slateBorder,
                                      ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 12),

                        // 6. Feedback Tags (Pill Badges in Wrap)
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: _tags.map(_buildTagChip).toList(),
                        ),

                        const SizedBox(height: 14),

                        // 7. Comment Field (Optionnel)
                        _buildCommentField(),

                        const SizedBox(height: 14),

                        // 8. Total Payé Card
                        _buildTotalPaidCard(),

                        const SizedBox(height: 12),

                        // 9. "Merci pour votre avis !" Appreciation Card
                        _buildAppreciationCard(),

                        const SizedBox(height: 16),

                        // 10. Primary Button: "Envoyer"
                        _buildSendButton(),

                        const SizedBox(height: 12),

                        // 11. Download & Share Receipt Buttons
                        _buildReceiptActionButtons(),

                        const SizedBox(height: 10),

                        // 12. Secondary Button: "Voir le reçu"
                        _buildReceiptButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildTagChip(_FeedbackTag tag) {
    final isSelected = _selectedTags.contains(tag.translationKey);

    return GestureDetector(
      onTap: () => _toggleTag(tag.translationKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.orangeVibrant : AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: isSelected
              ? null
              : Border.all(color: AppColors.grayBorderDivider, width: 1.2),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: AppColors.orangeVibrantShadow,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: AppColors.shadowSubtleBlack,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tag.icon,
              size: 18,
              color: isSelected ? AppColors.white : AppColors.slateDark,
            ),
            const SizedBox(width: 8),
            Text(
              tag.translationKey.tr(),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.white : AppColors.slateDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalPaidCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.slateLightBg, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSubtleBlack,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Vehicle 3D thumbnail in warm peach gradient container
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment(0.0, -0.2),
                radius: 0.9,
                colors: [
                  AppColors.peachLight,
                  AppColors.peachDeep,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/seddo_confort_3d.png',
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => Image.asset(
                  'assets/images/seddo_eco_3d.png',
                  fit: BoxFit.contain,
                  errorBuilder: (ctx2, err2, stack2) => const Icon(
                    Icons.directions_car_rounded,
                    size: 36,
                    color: AppColors.orangeVibrant,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Total Payé details & Payment Method
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'rating.total_paid'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.slateMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.rideOption.formattedPrice,
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.slateDark,
                              letterSpacing: -0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 6),

                    // "Prix fixe" badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orangeSubtleBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.peachBorder,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.credit_card_rounded,
                            size: 12,
                            color: AppColors.orangeVibrant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'rating.fixed_price'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.orangeVibrant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Orange Money payment row with OM badge and chevron
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.slateDark,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'OM',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Orange Money',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slateDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.paymentPhone,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: AppColors.slateMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.slateDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppreciationCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.orangeLightBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.badgePeachBorder,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.badgePeachFill,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              color: AppColors.orangeVibrant,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'rating.appreciation_title'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slateDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'rating.appreciation_sub'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.slateMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Radiating accent rays on the right edge
          CustomPaint(
            size: const Size(16, 22),
            painter: _CardSparklePainter(),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.grayBgSubtle,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(
          color: AppColors.grayBorderDivider,
          width: AppConstants.strokeWidthBorder,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                size: AppConstants.iconSizeSm,
                color: AppColors.slateMuted,
              ),
              const SizedBox(width: AppConstants.spacingS),
              Text(
                'rating.comment_title'.tr(),
                style: GoogleFonts.inter(
                  fontSize: AppConstants.fontSm,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slateDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingXs),
          TextField(
            controller: _commentController,
            maxLines: 3,
            minLines: 2,
            maxLength: 250,
            style: GoogleFonts.inter(
              fontSize: AppConstants.fontSm + 1.5,
              fontWeight: FontWeight.w500,
              color: AppColors.slateDark,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: 'rating.comment_hint'.tr(),
              hintStyle: GoogleFonts.inter(
                fontSize: AppConstants.fontSm + 1.0,
                fontWeight: FontWeight.w400,
                color: AppColors.slateMuted,
              ),
              counterStyle: GoogleFonts.inter(
                fontSize: AppConstants.fontXs,
                color: AppColors.slateMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          height: AppConstants.buttonHeight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orangeVibrant,
              foregroundColor: AppColors.white,
              elevation: AppConstants.elevationNone,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSheet),
              ),
              shadowColor: AppColors.orangeVibrantGlow,
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
                      Transform.rotate(
                        angle: -0.2,
                        child: const Icon(
                          Icons.send_rounded,
                          size: AppConstants.iconSizeDefault,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingUnit),
                      Text(
                        'rating.submit'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontLg,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        // Radiating orange burst lines on top-right of the button
        Positioned(
          top: -8,
          right: 4,
          child: CustomPaint(
            size: const Size(20, 20),
            painter: _ButtonBurstPainter(),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptActionButtons() {
    return Row(
      children: [
        // Télécharger le reçu (GET /v1/rides/{id}/receipt.pdf)
        Expanded(
          child: SizedBox(
            height: AppConstants.buttonHeight,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.slateDark,
                side: const BorderSide(
                  color: AppColors.grayBorderDivider,
                  width: AppConstants.strokeWidthBorder,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingSm,
                ),
              ),
              onPressed: _isDownloadingReceipt ? null : _downloadReceipt,
              child: _isDownloadingReceipt
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.orangeAccent,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.file_download_outlined,
                          size: AppConstants.iconSizeMd,
                          color: AppColors.orangeAccent,
                        ),
                        const SizedBox(width: AppConstants.spacingSm),
                        Flexible(
                          child: Text(
                            'rating.download_receipt'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: AppConstants.fontSm,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slateDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: AppConstants.spacingUnitLg),
        // Partager le reçu (GET /v1/rides/{id}/receipt + SharePlus)
        Expanded(
          child: SizedBox(
            height: AppConstants.buttonHeight,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.slateDark,
                side: const BorderSide(
                  color: AppColors.grayBorderDivider,
                  width: AppConstants.strokeWidthBorder,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingSm,
                ),
              ),
              onPressed: _isSharingReceipt ? null : _shareReceipt,
              child: _isSharingReceipt
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.orangeAccent,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.share_outlined,
                          size: AppConstants.iconSizeMd,
                          color: AppColors.orangeAccent,
                        ),
                        const SizedBox(width: AppConstants.spacingSm),
                        Flexible(
                          child: Text(
                            'rating.share_receipt'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: AppConstants.fontSm,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slateDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptButton() {
    return SizedBox(
      width: double.infinity,
      height: AppConstants.buttonHeight,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.slateDark,
          elevation: AppConstants.elevationNone,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
            side: const BorderSide(
              color: AppColors.grayBorderDivider,
              width: AppConstants.strokeWidthBorder,
            ),
          ),
        ),
        onPressed: _showReceipt,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_rounded,
              size: AppConstants.iconSizeMd,
              color: AppColors.slateDark,
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Text(
              'rating.view_receipt'.tr(),
              style: GoogleFonts.inter(
                fontSize: AppConstants.fontBase,
                fontWeight: FontWeight.w700,
                color: AppColors.slateDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Driver avatar with character, cap, polo shirt, verified shield badge, and sparkle accents
class _DriverAvatarWithBadge extends StatelessWidget {
  const _DriverAvatarWithBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Radiating accent sparkles around the avatar
          CustomPaint(
            size: const Size(120, 104),
            painter: _DriverSparklesPainter(),
          ),

          // Circular Avatar with driver character
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.avatarCircleBg,
            ),
            child: ClipOval(
              child: CustomPaint(
                painter: _DriverCharacterPainter(),
              ),
            ),
          ),

          // Verified shield badge on bottom right
          Positioned(
            right: 18,
            bottom: 12,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.orangeVibrant,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.orangeVibrantShadow,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 14,
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the friendly driver character with cap and orange uniform inside the avatar circle
class _DriverCharacterPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 1. Shoulders / Orange Polo Shirt
    final shirtPaint = Paint()..color = AppColors.orangeVibrant;
    final shirtPath = Path()
      ..moveTo(8, size.height)
      ..lineTo(8, size.height * 0.72)
      ..cubicTo(
        cx - 20,
        size.height * 0.60,
        cx + 20,
        size.height * 0.60,
        size.width - 8,
        size.height * 0.72,
      )
      ..lineTo(size.width - 8, size.height)
      ..close();
    canvas.drawPath(shirtPath, shirtPaint);

    // 2. Collar details
    final collarPaint = Paint()..color = AppColors.avatarCollar;
    final collarPath = Path()
      ..moveTo(cx - 10, size.height * 0.64)
      ..lineTo(cx, size.height * 0.76)
      ..lineTo(cx + 10, size.height * 0.64)
      ..close();
    canvas.drawPath(collarPath, collarPaint);

    // 3. Mini white car emblem on chest
    final emblemPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;
    final carEmblem = Path()
      ..moveTo(cx - 5, size.height * 0.84)
      ..lineTo(cx - 3, size.height * 0.81)
      ..lineTo(cx + 3, size.height * 0.81)
      ..lineTo(cx + 5, size.height * 0.84)
      ..lineTo(cx + 6, size.height * 0.86)
      ..lineTo(cx - 6, size.height * 0.86)
      ..close();
    canvas.drawPath(carEmblem, emblemPaint);

    // 4. Neck (African skin tone)
    final skinPaint = Paint()..color = AppColors.avatarSkin;
    final neckRect = Rect.fromCenter(
      center: Offset(cx, cy + 8),
      width: 14,
      height: 16,
    );
    canvas.drawRect(neckRect, skinPaint);

    // 5. Head / Face
    final faceRect = Rect.fromCenter(
      center: Offset(cx, cy - 6),
      width: 26,
      height: 28,
    );
    canvas.drawOval(faceRect, skinPaint);

    // 6. Ears
    canvas.drawCircle(Offset(cx - 13, cy - 6), 3.2, skinPaint);
    canvas.drawCircle(Offset(cx + 13, cy - 6), 3.2, skinPaint);

    // 7. Eyes
    final eyePaint = Paint()..color = AppColors.licensePlateBg;
    canvas.drawCircle(Offset(cx - 5, cy - 7), 1.8, eyePaint);
    canvas.drawCircle(Offset(cx + 5, cy - 7), 1.8, eyePaint);

    // 8. Friendly Smile
    final smilePaint = Paint()
      ..color = AppColors.avatarHair
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final smilePath = Path()
      ..moveTo(cx - 4, cy + 1)
      ..quadraticBezierTo(cx, cy + 4, cx + 4, cy + 1);
    canvas.drawPath(smilePath, smilePaint);

    // 9. Orange Cap Crown
    final capPaint = Paint()..color = AppColors.orangeVibrant;
    final capPath = Path()
      ..moveTo(cx - 14, cy - 10)
      ..cubicTo(
        cx - 14,
        cy - 24,
        cx + 14,
        cy - 24,
        cx + 14,
        cy - 10,
      )
      ..close();
    canvas.drawPath(capPath, capPaint);

    // 10. Cap Visor / Brim
    final visorPaint = Paint()..color = AppColors.avatarCollar;
    final visorPath = Path()
      ..moveTo(cx - 15, cy - 9)
      ..lineTo(cx + 15, cy - 9)
      ..lineTo(cx + 17, cy - 6)
      ..lineTo(cx - 15, cy - 6)
      ..close();
    canvas.drawPath(visorPath, visorPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Radiating sparkle lines around driver avatar
class _DriverSparklesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.orangeAccent
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Top-left tick
    canvas.drawLine(const Offset(30, 24), const Offset(24, 18), paint);
    // Top-right tick
    canvas.drawLine(const Offset(90, 24), const Offset(96, 18), paint);
    // Upper-right tick
    canvas.drawLine(const Offset(84, 12), const Offset(87, 6), paint);
    // Far-left tick
    canvas.drawLine(const Offset(18, 50), const Offset(12, 51), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 2 Slanted accent lines on the appreciation card
class _CardSparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.orangeAccent
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(4, 18), const Offset(14, 6), paint);
    canvas.drawLine(const Offset(0, 10), const Offset(8, 0), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Burst rays on top-right of the "Envoyer" button
class _ButtonBurstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.orangeAccent
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(4, 16), const Offset(0, 8), paint);
    canvas.drawLine(const Offset(10, 14), const Offset(10, 4), paint);
    canvas.drawLine(const Offset(16, 16), const Offset(20, 8), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Decorative organic waves in the background (top-right peach blob and bottom-left orange waves)
class _RatingBackgroundWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Top-right soft peach wave
    final topPaint = Paint()..color = AppColors.avatarBgTop;
    final topPath = Path()
      ..moveTo(size.width * 0.70, 0)
      ..cubicTo(
        size.width * 0.75,
        size.height * 0.05,
        size.width * 0.85,
        size.height * 0.08,
        size.width,
        size.height * 0.10,
      )
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(topPath, topPaint);

    // 2. Bottom-left layered orange waves
    final wave1Paint = Paint()..color = AppColors.avatarWaveLight;
    final wave1 = Path()
      ..moveTo(0, size.height * 0.88)
      ..cubicTo(
        size.width * 0.14,
        size.height * 0.87,
        size.width * 0.26,
        size.height * 0.95,
        size.width * 0.35,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(wave1, wave1Paint);

    final wave2Paint = Paint()..color = AppColors.orangeVibrant;
    final wave2 = Path()
      ..moveTo(0, size.height * 0.91)
      ..cubicTo(
        size.width * 0.10,
        size.height * 0.91,
        size.width * 0.18,
        size.height * 0.97,
        size.width * 0.24,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(wave2, wave2Paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

