import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/domain/models/ride_option_model.dart';

/// Screen displayed at the end of the trip to rate the driver matching the design:
/// - Top bar: Circular back button and centered Seddo logo with decorative organic waves
/// - Illustrated driver avatar with orange cap & polo, verification shield, and sparkles
/// - "Comment s'est passée votre course avec Moussa ?"
/// - Subtitle with destination, time and duration
/// - 5-star rating selector (4 stars active by default)
/// - 4 feedback tag pills (Conduite prudente, Ponctuel, Voiture propre, Sympathique)
/// - Total payé card with 3D car asset, "Prix fixe" badge, Orange Money details & chevron
/// - Warm peach appreciation card ("Merci pour votre avis !")
/// - Primary orange "Envoyer" button with paper plane and energy bursts
/// - Secondary "Voir le reçu" button
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

class _FeedbackTag {
  final String label;
  final IconData icon;

  const _FeedbackTag({
    required this.label,
    required this.icon,
  });
}

class _RideRatingPageState extends State<RideRatingPage> {
  int _selectedStars = 4;
  final Set<String> _selectedTags = {'Conduite prudente'};

  static const List<_FeedbackTag> _tags = [
    _FeedbackTag(
      label: 'Conduite prudente',
      icon: Icons.thumb_up_alt_rounded,
    ),
    _FeedbackTag(
      label: 'Ponctuel',
      icon: Icons.access_time_rounded,
    ),
    _FeedbackTag(
      label: 'Voiture propre',
      icon: Icons.directions_car_rounded,
    ),
    _FeedbackTag(
      label: 'Sympathique',
      icon: Icons.favorite_border_rounded,
    ),
  ];

  void _toggleTag(String tagLabel) {
    setState(() {
      if (_selectedTags.contains(tagLabel)) {
        _selectedTags.remove(tagLabel);
      } else {
        _selectedTags.add(tagLabel);
      }
    });
  }

  void _submitRating() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Text(
          'Merci pour votre avis ! À très bientôt sur Seddo.',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
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
          color: Colors.white,
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
                  color: const Color(0xFFE2E8F0),
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
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 14),
            _buildReceiptRow('Type de course', widget.rideOption.title),
            _buildReceiptRow('Destination', widget.destination.mainText),
            _buildReceiptRow('Conducteur', widget.driver.name),
            _buildReceiptRow('Véhicule', widget.driver.carModel),
            _buildReceiptRow('Durée du trajet', widget.durationText),
            _buildReceiptRow('Paiement', 'Orange Money ${widget.paymentPhone}'),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total payé',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  widget.rideOption.formattedPrice,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFFF5722),
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
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
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
                color: const Color(0xFF6B7280),
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
                color: const Color(0xFF0F172A),
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
    final driverFirstName = widget.driver.name.isNotEmpty
        ? widget.driver.name.split(' ').first
        : 'Moussa';
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
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
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0F000000),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            size: 20,
                            color: Color(0xFF0F172A),
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

                        // 3. Question Title: "Comment s'est passée votre course avec Moussa ?"
                        Text(
                          'Comment s\'est passée votre\ncourse avec $driverFirstName ?',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
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
                            color: const Color(0xFF6B7280),
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
                                        color: Color(0xFFFF7A00),
                                      )
                                    : const Icon(
                                        Icons.star_outline_rounded,
                                        size: 40,
                                        color: Color(0xFFCBD5E1),
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

                        // 7. Total Payé Card
                        _buildTotalPaidCard(),

                        const SizedBox(height: 12),

                        // 8. "Merci pour votre avis !" Appreciation Card
                        _buildAppreciationCard(),

                        const SizedBox(height: 16),

                        // 9. Primary Button: "Envoyer"
                        _buildSendButton(),

                        const SizedBox(height: 10),

                        // 10. Secondary Button: "Voir le reçu"
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
    );
  }

  Widget _buildTagChip(_FeedbackTag tag) {
    final isSelected = _selectedTags.contains(tag.label);

    return GestureDetector(
      onTap: () => _toggleTag(tag.label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5722) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isSelected
              ? null
              : Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x4DFF5722),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x05000000),
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
              color: isSelected ? Colors.white : const Color(0xFF0F172A),
            ),
            const SizedBox(width: 8),
            Text(
              tag.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
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
                  Color(0xFFFFF2E8),
                  Color(0xFFFFDFC8),
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
                    color: Color(0xFFFF5722),
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
                            'Total payé',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.rideOption.formattedPrice,
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
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
                        color: const Color(0xFFFFF4EC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFFD9C2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.credit_card_rounded,
                            size: 12,
                            color: Color(0xFFFF5722),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Prix fixe',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFF5722),
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
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'OM',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
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
                              color: const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.paymentPhone,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF6B7280),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Color(0xFF0F172A),
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
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFEEDD),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE5D3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              color: Color(0xFFFF5722),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Merci pour votre avis !',
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Votre retour nous aide à améliorer la qualité de nos services.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
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

  Widget _buildSendButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5722),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(27),
              ),
              shadowColor: const Color(0x66FF5722),
            ),
            onPressed: _submitRating,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.rotate(
                  angle: -0.2,
                  child: const Icon(
                    Icons.send_rounded,
                    size: 19,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Envoyer',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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

  Widget _buildReceiptButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: const BorderSide(
              color: Color(0xFFE5E7EB),
              width: 1.2,
            ),
          ),
        ),
        onPressed: _showReceipt,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_rounded,
              size: 20,
              color: Color(0xFF0F172A),
            ),
            const SizedBox(width: 8),
            Text(
              'Voir le reçu',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
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
              color: Color(0xFFFFE8D6),
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
                color: const Color(0xFFFF5722),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x59FF5722),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 14,
                color: Colors.white,
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
    final shirtPaint = Paint()..color = const Color(0xFFFF5722);
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
    final collarPaint = Paint()..color = const Color(0xFFE64A19);
    final collarPath = Path()
      ..moveTo(cx - 10, size.height * 0.64)
      ..lineTo(cx, size.height * 0.76)
      ..lineTo(cx + 10, size.height * 0.64)
      ..close();
    canvas.drawPath(collarPath, collarPaint);

    // 3. Mini white car emblem on chest
    final emblemPaint = Paint()
      ..color = Colors.white
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
    final skinPaint = Paint()..color = const Color(0xFFA66038);
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
    final eyePaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawCircle(Offset(cx - 5, cy - 7), 1.8, eyePaint);
    canvas.drawCircle(Offset(cx + 5, cy - 7), 1.8, eyePaint);

    // 8. Friendly Smile
    final smilePaint = Paint()
      ..color = const Color(0xFF33180D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final smilePath = Path()
      ..moveTo(cx - 4, cy + 1)
      ..quadraticBezierTo(cx, cy + 4, cx + 4, cy + 1);
    canvas.drawPath(smilePath, smilePaint);

    // 9. Orange Cap Crown
    final capPaint = Paint()..color = const Color(0xFFFF5722);
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
    final visorPaint = Paint()..color = const Color(0xFFE64A19);
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
      ..color = const Color(0xFFFF7A00)
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
      ..color = const Color(0xFFFF7A00)
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
      ..color = const Color(0xFFFF7A00)
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
    final topPaint = Paint()..color = const Color(0xFFFFEAD8);
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
    final wave1Paint = Paint()..color = const Color(0xFFFF8A3D);
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

    final wave2Paint = Paint()..color = const Color(0xFFFF5722);
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

