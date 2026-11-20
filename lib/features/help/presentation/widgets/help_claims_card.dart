import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/help/presentation/pages/support_tickets_page.dart';

/// Card displayed on the Help page:
/// Prompts the user to view and follow their support tickets / claims.
/// Tapping anywhere navigates to SupportTicketsPage.
/// Design matching user reference mockup with dark card, orange tab on left edge,
/// credit card with '?' badge, checklist watermark, and white forward button.
class HelpClaimsCard extends StatelessWidget {
  const HelpClaimsCard({super.key});

  @override
  Widget build(BuildContext context) {
    const cardRadius = 18.0;
    const orangeTabProtrusion = 6.0;

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            SlideRightToLeftRoute(
              page: const SupportTicketsPage(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(cardRadius),
        child: Padding(
          padding: const EdgeInsets.only(left: orangeTabProtrusion),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Accent orange sous forme d'onglet arrondi dépassant sur le flanc gauche
              Positioned(
                left: -orangeTabProtrusion,
                top: 9,
                bottom: 9,
                width: orangeTabProtrusion + 12,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFB5B00),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                ),
              ),

              // 2. La carte sombre principale
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF222632),
                      Color(0xFF161822),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(cardRadius),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x28000000),
                      blurRadius: 16,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(cardRadius),
                  child: Stack(
                    children: [
                      // Vague stylisée en arrière-plan à droite
                      Positioned(
                        right: -10,
                        top: -20,
                        bottom: -20,
                        width: 140,
                        child: const CustomPaint(
                          painter: _BackgroundWavePainter(),
                        ),
                      ),

                      // Illustration filigrane du bloc-notes / liste de réclamations à droite
                      Positioned(
                        right: 56,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Container(
                            width: 48,
                            height: 60,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xE6262C38),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(
                                3,
                                (_) => Row(
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF3B4455),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Container(
                                        height: 3.5,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3B4455),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Contenu interactif (Carte avec badge '?', Textes, Bouton blanc)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            // Icône graphique : Carte inclinée + pastille orange '?'
                            const _ClaimsCardIllustration(),
                            const SizedBox(width: 14),

                            // Titre & Sous-titre
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mes réclamations',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Suivez vos demandes et objets perdus',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w400,
                                      color: const Color(0xFFCBD5E1),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 10),

                            // Bouton d'action circulaire blanc avec chevron
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x26000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.chevron_right_rounded,
                                size: 22,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

/// Illustration d'une carte de crédit blanche inclinée avec une pastille orange portant '?'
class _ClaimsCardIllustration extends StatelessWidget {
  const _ClaimsCardIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Carte blanche inclinée
          Positioned(
            left: 0,
            top: 3,
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                width: 44,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.only(top: 6, left: 6, right: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2633),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Pastille orange avec point d'interrogation blanc '?'
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFFB5B00),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF1B1E28),
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3D000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '?',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.05,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vague d'arrière-plan en dégradé subtil
class _BackgroundWavePainter extends CustomPainter {
  const _BackgroundWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: const [
          Color(0x59333B4A),
          Color(0x001E232E),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width * 0.25, 0)
      ..quadraticBezierTo(
        0,
        size.height * 0.5,
        size.width * 0.35,
        size.height,
      )
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
