import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/presentation/widgets/orange_money_payment_sheet.dart';

enum NoDriverFoundAction {
  later,
  retry,
}

/// Feuille modale affichée lorsqu'aucun chauffeur n'est disponible dans la zone :
/// - Icône de voiture SVG orange avec badge horloge
/// - Titre "Aucun chauffeur disponible"
/// - Sous-titre "Forte demande autour de [lieu]. Réessayez dans quelques instants."
/// - Carte de remboursement (visible uniquement pour Wave ou Orange Money)
/// - Bouton principal "Réessayer" et lien "Plus tard"
class NoDriverFoundSheet extends StatelessWidget {
  final PlaceSearchResult departure;
  final PlaceSearchResult destination;
  final RideOptionModel rideOption;
  final String transactionRef;
  final PaymentMethodType? paymentMethod;

  const NoDriverFoundSheet({
    super.key,
    required this.departure,
    required this.destination,
    required this.rideOption,
    this.transactionRef = 'CI270415.1902.C4D1',
    this.paymentMethod,
  });

  static Future<NoDriverFoundAction?> show(
    BuildContext context, {
    required PlaceSearchResult departure,
    required PlaceSearchResult destination,
    required RideOptionModel rideOption,
    String transactionRef = 'CI270415.1902.C4D1',
    PaymentMethodType? paymentMethod,
  }) {
    return showModalBottomSheet<NoDriverFoundAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => NoDriverFoundSheet(
        departure: departure,
        destination: destination,
        rideOption: rideOption,
        transactionRef: transactionRef,
        paymentMethod: paymentMethod,
      ),
    );
  }

  static String _safeTr(String key, String fallback) {
    try {
      final res = key.tr();
      if (res != key && res.isNotEmpty) return res;
    } catch (_) {}
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final systemBottom = MediaQuery.of(context).padding.bottom;

    final bool isCash = paymentMethod == PaymentMethodType.cash;
    final bool shouldShowRefund = !isCash;

    final String paymentProviderText = paymentMethod == PaymentMethodType.wave
        ? 'Sur votre Wave'
        : 'Sur votre Orange Money';

    final String locationName = departure.mainText.isNotEmpty
        ? departure.mainText
        : 'votre zone';

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
        systemBottom > 0
            ? systemBottom + AppConstants.spacingUnitLg
            : AppConstants.spacingLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Container(
            width: AppConstants.handleWidth,
            height: AppConstants.handleHeight,
            decoration: BoxDecoration(
              color: AppColors.dragHandle,
              borderRadius: BorderRadius.circular(AppConstants.radiusXs),
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),

          // Illustration: Voiture confortcar.svg avec badge horloge
          SizedBox(
            width: AppConstants.refundCarCircleSize,
            height: AppConstants.refundCarCircleSize,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Cercle pêche de fond avec icône de voiture
                Container(
                  width: AppConstants.refundCarCircleSize,
                  height: AppConstants.refundCarCircleSize,
                  decoration: const BoxDecoration(
                    color: AppColors.peachContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    'assets/icons/confortcar.svg',
                    width: AppConstants.refundCarSvgSize,
                    height: AppConstants.refundCarSvgSize,
                    fit: BoxFit.contain,
                    colorFilter: const ColorFilter.mode(
                      AppColors.primary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),

                // Badge blanc avec horloge en bas à droite
                Positioned(
                  bottom: AppConstants.refundClockBadgeOffset,
                  right: AppConstants.refundClockBadgeOffset,
                  child: Container(
                    width: AppConstants.refundClockBadgeSize,
                    height: AppConstants.refundClockBadgeSize,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.refundClockBadgeBorder,
                        width: AppConstants.strokeWidthBorder,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.cardShadow,
                          blurRadius: AppConstants.spacingXs,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.access_time_rounded,
                      size: AppConstants.refundClockIconSize,
                      color: AppColors.refundClockIcon,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),

          // Title
          Text(
            _safeTr('ride.no_driver_title', 'Aucun chauffeur disponible'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: AppConstants.fontTitleDialog,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: AppConstants.fontTitleDialogLetterSpacing,
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),

          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingSm,
            ),
            child: Text(
              'Forte demande autour de $locationName. Réessayez dans quelques instants.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: AppConstants.fontBase,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
                height: AppConstants.bannerLineHeight,
              ),
            ),
          ),

          // Carte de remboursement : visible uniquement si paiement Wave ou Orange Money
          if (shouldShowRefund) ...[
            const SizedBox(height: AppConstants.spacingLg),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingMd,
              ),
              decoration: BoxDecoration(
                color: AppColors.refundContainerBg,
                borderRadius: BorderRadius.circular(AppConstants.radiusCard),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Cercle blanc avec icône check verte
                  Container(
                    width: AppConstants.searchIconBoxSize,
                    height: AppConstants.searchIconBoxSize,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.refundGreen,
                      size: AppConstants.iconSizeXl,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingUnitXl),

                  // Montant, libellé de paiement et référence
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${rideOption.formattedPrice} remboursés',
                          style: GoogleFonts.inter(
                            fontSize: AppConstants.fontXl,
                            fontWeight: FontWeight.w800,
                            color: AppColors.refundAmountGreen,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingTiny),
                        Text(
                          paymentProviderText,
                          style: GoogleFonts.inter(
                            fontSize: AppConstants.fontMd,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingSm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.spacingUnit,
                            vertical: AppConstants.spacingXs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(
                              AppConstants.refundRefPillRadius,
                            ),
                            border: Border.all(
                              color: AppColors.cardBorder,
                              width: AppConstants.strokeWidthBorder,
                            ),
                          ),
                          child: Text(
                            transactionRef,
                            style: GoogleFonts.inter(
                              fontSize: AppConstants.fontSm,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              letterSpacing: AppConstants.refundRefLetterSpacing,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppConstants.spacingLg),

          // Bouton principal : Réessayer
          SizedBox(
            width: double.infinity,
            height: AppConstants.buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                elevation: AppConstants.elevationNone,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusButtonRound,
                  ),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(NoDriverFoundAction.retry);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.refresh_rounded,
                    size: AppConstants.iconSizeLg,
                    color: AppColors.white,
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Text(
                    _safeTr('common.retry', 'Réessayer'),
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontLg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingUnit),

          // Bouton secondaire : Plus tard
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(
                  vertical: AppConstants.spacingUnit,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(NoDriverFoundAction.later);
              },
              child: Text(
                _safeTr('common.later', 'Plus tard'),
                style: GoogleFonts.inter(
                  fontSize: AppConstants.fontLg,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
