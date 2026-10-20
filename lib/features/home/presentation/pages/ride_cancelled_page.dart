import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/domain/models/ride_option_model.dart';
import 'package:seddo/features/home/presentation/pages/ride_booking_page.dart';

/// Screen displayed when a ride is cancelled and automatically refunded matching Screenshot 4:
/// - Green circular refund icon
/// - "Course annulée" title and free cancellation subtitle
/// - Card with Montant remboursé, Vers Orange Money, Statut Remboursé, Réf. Orange
/// - "Recommander" button and "Retour à l'accueil" button
class RideCancelledPage extends StatelessWidget {
  final RideOptionModel rideOption;
  final PlaceSearchResult? departure;
  final PlaceSearchResult? destination;
  final String phoneDisplay;
  final String transactionRef;

  const RideCancelledPage({
    super.key,
    required this.rideOption,
    this.departure,
    this.destination,
    this.phoneDisplay = '77 ••• 45 12',
    this.transactionRef = 'CI270415.1842.A3F2',
  });

  @override
  Widget build(BuildContext context) {
    final systemBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppConstants.spacingLg,
            40,
            AppConstants.spacingLg,
            systemBottom > 0 ? systemBottom : 20,
          ),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Green Circular Refund Icon
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.refundContainerBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.replay_rounded,
                  size: 40,
                  color: AppColors.refundGreen,
                ),
              ),

              const SizedBox(height: 24),

              // Title: "Course annulée"
              Text(
                'Course annulée',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.6,
                ),
              ),

              const SizedBox(height: 6),

              // Subtitle: "Annulation gratuite : moins de 2 min après l'acceptation"
              Text(
                'Annulation gratuite : moins de 2 min après l\'acceptation',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Refund Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                  border: Border.all(
                    color: AppColors.cardBorder,
                    width: 1.2,
                  ),
                ),
                child: Column(
                  children: [
                    // Montant remboursé
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Montant remboursé',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          rideOption.formattedPrice,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Vers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Vers',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            'Orange Money $phoneDisplay',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Statut: Remboursé pill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Statut',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.refundPillBg,
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusPill,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: AppColors.refundGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Remboursé',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.refundGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Réf. Orange
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Réf. Orange',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            transactionRef,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // Button 1: Recommander
              SizedBox(
                width: double.infinity,
                height: AppConstants.buttonHeight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusLg,
                      ),
                    ),
                  ),
                  onPressed: () {
                    if (departure != null && destination != null) {
                      Navigator.of(context).pushAndRemoveUntil(
                        SlideRightToLeftRoute(
                          page: RideBookingPage(
                            departure: departure!,
                            destination: destination!,
                          ),
                          settings: const RouteSettings(name: 'RideBookingPage'),
                        ),
                        (route) => route.isFirst,
                      );
                    } else {
                      Navigator.of(context).pop('reorder');
                    }
                  },
                  child: Text(
                    'Recommander',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Button 2: Retour à l'accueil
              SizedBox(
                width: double.infinity,
                height: AppConstants.buttonHeight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cancelSecondaryBtnBg,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusLg,
                      ),
                    ),
                  ),
                  onPressed: () {
                    // Pop back to root / HomePage
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: Text(
                    'Retour à l\'accueil',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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
}
