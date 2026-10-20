import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/domain/models/ride_option_model.dart';

/// Screen displayed at the end of the trip to rate the driver matching Screenshot 3:
/// - Driver initials avatar ("MS")
/// - "Comment s'est passée votre course avec Moussa ?"
/// - Subtitle with destination, time and duration
/// - 5-star rating selector
/// - Feedback tags (Conduite prudente, Ponctuel, Voiture propre, Sympathique)
/// - Total payé with Orange Money badge
/// - "Envoyer" and "Voir le reçu" buttons
class RideRatingPage extends StatefulWidget {
  final PlaceSearchResult destination;
  final DriverModel driver;
  final RideOptionModel rideOption;
  final String arrivalTime;
  final String durationText;
  final String paymentPhone;

  const RideRatingPage({
    super.key,
    required this.destination,
    required this.driver,
    required this.rideOption,
    this.arrivalTime = '18:41',
    this.durationText = '22 min',
    this.paymentPhone = '77 ••• 45 12',
  });

  @override
  State<RideRatingPage> createState() => _RideRatingPageState();
}

class _RideRatingPageState extends State<RideRatingPage> {
  int _selectedStars = 5;
  final Set<String> _selectedTags = {'👍 Conduite prudente'};

  static const List<String> _availableTags = [
    '👍 Conduite prudente',
    'Ponctuel',
    'Voiture propre',
    'Sympathique',
  ];

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _submitRating() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.buttonBlack,
        content: Text(
          'Merci pour votre avis ! À très bientôt sur Seddo.',
          style: GoogleFonts.inter(color: AppColors.white),
        ),
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showReceipt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusSheet),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dragHandle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Reçu de la course',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _buildReceiptRow('Type de course', widget.rideOption.title),
            _buildReceiptRow('Destination', widget.destination.mainText),
            _buildReceiptRow('Conducteur', widget.driver.name),
            _buildReceiptRow('Véhicule', widget.driver.carModel),
            _buildReceiptRow('Durée du trajet', widget.durationText),
            _buildReceiptRow('Paiement', 'Orange Money ${widget.paymentPhone}'),
            const Divider(height: 24, color: AppColors.divider),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total payé',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  widget.rideOption.formattedPrice,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: AppConstants.buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonBlack,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Fermer',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final systemBottom = MediaQuery.of(context).padding.bottom;
    final initials = widget.driver.name.isNotEmpty
        ? widget.driver.name
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'MS';

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppConstants.spacingLg,
            24,
            AppConstants.spacingLg,
            systemBottom > 0 ? systemBottom : 20,
          ),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Circle avatar with initials "MS"
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: AppColors.avatarBeige,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Title: "Comment s'est passée votre course avec Moussa ?"
              Text(
                'Comment s\'est passée votre\ncourse avec ${widget.driver.name.split(' ').first} ?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                  height: 1.25,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                '${widget.destination.mainText} · $widget.arrivalTime · $widget.durationText',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 24),

              // 5 Stars Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  final isSelected = starIndex <= _selectedStars;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedStars = starIndex;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Icon(
                        isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 38,
                        color: isSelected ? AppColors.starGold : AppColors.cardBorder,
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),

              // Feedback Chips
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 10,
                children: _availableTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return GestureDetector(
                    onTap: () => _toggleTag(tag),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.tagChipSelectedBg
                            : AppColors.tagChipBg,
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusPill,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.tagChipSelectedText
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Total Payé Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.tagChipBg,
                  borderRadius: BorderRadius.circular(AppConstants.radiusCard),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total payé',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          widget.rideOption.formattedPrice,
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.buttonBlack,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'OM',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Orange Money ${widget.paymentPhone}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Prix fixe',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Button 1: Envoyer
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
                  onPressed: _submitRating,
                  child: Text(
                    'Envoyer',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Button 2: Voir le reçu
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
                  onPressed: _showReceipt,
                  child: Text(
                    'Voir le reçu',
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
