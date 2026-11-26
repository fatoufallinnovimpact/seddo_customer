import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:seddo/core/utils/app_colors.dart';

/// Modal d'information sur les créneaux horaires de livraison :
/// "30 minutes de plus" et "Dans 2 heures".
class DeliveryTimeOptionInfoModal extends StatelessWidget {
  final String title;
  final String timeOptionId; // '30min' ou '2hours'

  const DeliveryTimeOptionInfoModal({
    super.key,
    required this.title,
    required this.timeOptionId,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String timeOptionId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DeliveryTimeOptionInfoModal(
        title: title,
        timeOptionId: timeOptionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final now = DateTime.now();

    // Calcul des horaires selon le créneau choisi
    DateTime pickupTime;
    DateTime deliveryTime;

    if (timeOptionId == '30min') {
      pickupTime = now.add(const Duration(minutes: 32));
      deliveryTime = pickupTime.add(const Duration(minutes: 23));
    } else {
      // Dans 2 heures
      pickupTime = now.add(const Duration(minutes: 62));
      deliveryTime = pickupTime.add(const Duration(minutes: 23));
    }

    final pickupFormatted = DateFormat('HH:mm').format(pickupTime);
    final deliveryFormatted = DateFormat('HH:mm').format(deliveryTime);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiret de drag supérieur
          Center(
            child: Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Titre (ex. "30 minutes de plus" ou "Dans 2 heures")
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),

          // Explication
          Text(
            'Votre commande sera moins chère, mais la recherche d’un coursier ou la livraison pourra prendre plus de temps',
            style: GoogleFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF334155),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Ligne 1 : Prise en charge chez l'expéditeur
          Row(
            children: [
              Expanded(
                child: Text(
                  'Prise en charge chez l’expéditeur',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                pickupFormatted,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Ligne 2 : Livraison au destinataire
          Row(
            children: [
              Expanded(
                child: Text(
                  'Livraison au destinataire',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                deliveryFormatted,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Bouton "J'ai compris"
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'J’ai compris',
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
