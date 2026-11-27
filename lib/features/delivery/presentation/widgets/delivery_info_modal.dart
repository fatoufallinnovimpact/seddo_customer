import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DeliveryInfoModal extends StatelessWidget {
  final String deliveryType; // 'moto' ou 'cargo'

  const DeliveryInfoModal({
    super.key,
    required this.deliveryType,
  });

  static Future<void> show(
    BuildContext context, {
    required String deliveryType,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DeliveryInfoModal(deliveryType: deliveryType),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMoto = deliveryType.toLowerCase() == 'moto';
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final title = isMoto ? 'EXPRESS MOTO' : 'EXPRESS VOITURE';
    final subtitle = isMoto
        ? 'Pour les petits colis et documents'
        : 'Transportez de gros volumes';

    final items = isMoto
        ? [
            const _InfoItemData(
              icon: Icons.meeting_room_outlined,
              text: 'Récupération et livraison gratuits des articles porte-à-porte',
            ),
            const _InfoItemData(
              icon: Icons.inventory_2_outlined,
              text: 'Vous pouvez envoyer plusieurs petits articles d\'un poids total jusqu\'à 10 kg',
            ),
            const _InfoItemData(
              icon: Icons.verified_user_outlined,
              text: 'Il est préférable d\'emballer soigneusement les articles fragiles pour les garder en sécurité',
            ),
            const _InfoItemData(
              icon: Icons.near_me_outlined,
              text: 'Le destinataire et vous pouvez suivre la livraison en temps réel',
            ),
          ]
        : [
            const _InfoItemData(
              icon: Icons.meeting_room_outlined,
              text: 'Une personne aidera à charger ou décharger les objets lourds (si l\'option correspondante est choisie).',
            ),
            const _InfoItemData(
              icon: Icons.block_outlined,
              text: 'N\'est pas destiné aux marchandises présentant des exigences particulières en matière de transport (pianos, coffres-forts, bouteilles de gaz, animaux, etc.).',
            ),
            const _InfoItemData(
              icon: Icons.airline_seat_recline_normal_outlined,
              text: 'Un seul siège pour le passager',
            ),
            const _InfoItemData(
              icon: Icons.local_shipping_outlined,
              text: 'Les véhicules transportent des charges d\'un poids maximal de 1 500 kg.',
            ),
            const _InfoItemData(
              icon: Icons.verified_user_outlined,
              text: 'Tous les objets fragiles doivent être communiqués au transporteur et chargés avec précaution dans le véhicule.',
            ),
          ];

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 150) {
          Navigator.of(context).pop();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 1. Bouton circulaire blanc avec croix noire au-dessus à droite du modal
          Padding(
            padding: const EdgeInsets.only(right: 18, bottom: 10),
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.25),
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Icon(
                      Icons.close,
                      color: Color(0xFF0F172A),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Conteneur principal du modal
          Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(18, 20, 18, bottomPadding + 16),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Sous-titre
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Liste des cartes d'informations
                  ...items.map((item) => _buildInfoCard(item)),

                  const SizedBox(height: 16),

                  // Bouton "J'ai compris"
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF0F172A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'J\'ai compris',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
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

  Widget _buildInfoCard(_InfoItemData item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFCBD5E1),
                width: 1.2,
              ),
              color: Colors.white,
            ),
            alignment: Alignment.center,
            child: Icon(
              item.icon,
              color: const Color(0xFF334155),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              item.text,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1E293B),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItemData {
  final IconData icon;
  final String text;

  const _InfoItemData({
    required this.icon,
    required this.text,
  });
}
