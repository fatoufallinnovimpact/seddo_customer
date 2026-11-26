import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_address_details_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_contact_picker_modal.dart';

class DeliveryUpdatedOrderResult {
  final DeliveryAddressDetails pickupDetails;
  final DeliveryAddressDetails destinationDetails;

  const DeliveryUpdatedOrderResult({
    required this.pickupDetails,
    required this.destinationDetails,
  });
}

/// Modal de mise à jour de commande en cours (Image : Mettez à jour votre commande)
/// Fond noir derrière les cards rattachées, cartes blanches sans contour coloré,
/// icône drapeau SVG pour Vers, et affichage complet de "Numéro de contact".
class DeliveryUpdateOrderModal extends StatefulWidget {
  final String pickupAddress;
  final String destinationAddress;
  final DeliveryAddressDetails? initialPickupDetails;
  final DeliveryAddressDetails? initialDestinationDetails;
  final void Function(
    DeliveryAddressDetails pickup,
    DeliveryAddressDetails destination,
  )? onSave;

  const DeliveryUpdateOrderModal({
    super.key,
    required this.pickupAddress,
    required this.destinationAddress,
    this.initialPickupDetails,
    this.initialDestinationDetails,
    this.onSave,
  });

  static Future<DeliveryUpdatedOrderResult?> show(
    BuildContext context, {
    required String pickupAddress,
    required String destinationAddress,
    DeliveryAddressDetails? initialPickupDetails,
    DeliveryAddressDetails? initialDestinationDetails,
    void Function(
      DeliveryAddressDetails pickup,
      DeliveryAddressDetails destination,
    )? onSave,
  }) {
    return showModalBottomSheet<DeliveryUpdatedOrderResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeliveryUpdateOrderModal(
        pickupAddress: pickupAddress,
        destinationAddress: destinationAddress,
        initialPickupDetails: initialPickupDetails,
        initialDestinationDetails: initialDestinationDetails,
        onSave: onSave,
      ),
    );
  }

  @override
  State<DeliveryUpdateOrderModal> createState() =>
      _DeliveryUpdateOrderModalState();
}

class _DeliveryUpdateOrderModalState extends State<DeliveryUpdateOrderModal> {
  // Expéditeur controllers
  late final TextEditingController _pickupEntryController;
  late final TextEditingController _pickupApartmentController;
  late final TextEditingController _pickupFloorController;
  late final TextEditingController _pickupIntercomController;
  late final TextEditingController _pickupCommentController;
  late String _pickupPhone;

  // Destinataire controllers
  late final TextEditingController _destinationEntryController;
  late final TextEditingController _destinationApartmentController;
  late final TextEditingController _destinationFloorController;
  late final TextEditingController _destinationIntercomController;
  late final TextEditingController _destinationCommentController;
  late String _destinationPhone;

  @override
  void initState() {
    super.initState();
    final pickup = widget.initialPickupDetails;
    _pickupEntryController =
        TextEditingController(text: pickup?.entry ?? '');
    _pickupApartmentController =
        TextEditingController(text: pickup?.apartment ?? '');
    _pickupFloorController =
        TextEditingController(text: pickup?.floor ?? '');
    _pickupIntercomController =
        TextEditingController(text: pickup?.intercom ?? '');
    _pickupCommentController =
        TextEditingController(text: pickup?.comment ?? '');
    _pickupPhone = pickup?.contactPhone.isNotEmpty == true
        ? pickup!.contactPhone
        : '+221784226719';

    final destination = widget.initialDestinationDetails;
    _destinationEntryController =
        TextEditingController(text: destination?.entry ?? '');
    _destinationApartmentController =
        TextEditingController(text: destination?.apartment ?? '');
    _destinationFloorController =
        TextEditingController(text: destination?.floor ?? '');
    _destinationIntercomController =
        TextEditingController(text: destination?.intercom ?? '');
    _destinationCommentController =
        TextEditingController(text: destination?.comment ?? '');
    _destinationPhone = destination?.contactPhone.isNotEmpty == true
        ? destination!.contactPhone
        : '+221784226719';
  }

  @override
  void dispose() {
    _pickupEntryController.dispose();
    _pickupApartmentController.dispose();
    _pickupFloorController.dispose();
    _pickupIntercomController.dispose();
    _pickupCommentController.dispose();

    _destinationEntryController.dispose();
    _destinationApartmentController.dispose();
    _destinationFloorController.dispose();
    _destinationIntercomController.dispose();
    _destinationCommentController.dispose();
    super.dispose();
  }

  Future<void> _selectPickupContact() async {
    final picked = await DeliveryContactPickerModal.show(
      context,
      isExpediteur: true,
    );
    if (picked != null && mounted) {
      setState(() {
        _pickupPhone = picked.phone;
      });
    }
  }

  Future<void> _selectDestinationContact() async {
    final picked = await DeliveryContactPickerModal.show(
      context,
      isExpediteur: false,
    );
    if (picked != null && mounted) {
      setState(() {
        _destinationPhone = picked.phone;
      });
    }
  }

  void _handleSave() {
    final updatedPickup = (widget.initialPickupDetails ??
            DeliveryAddressDetails(address: widget.pickupAddress))
        .copyWith(
      entry: _pickupEntryController.text.trim(),
      apartment: _pickupApartmentController.text.trim(),
      floor: _pickupFloorController.text.trim(),
      intercom: _pickupIntercomController.text.trim(),
      comment: _pickupCommentController.text.trim(),
      contactPhone: _pickupPhone,
    );

    final updatedDestination = (widget.initialDestinationDetails ??
            DeliveryAddressDetails(address: widget.destinationAddress))
        .copyWith(
      entry: _destinationEntryController.text.trim(),
      apartment: _destinationApartmentController.text.trim(),
      floor: _destinationFloorController.text.trim(),
      intercom: _destinationIntercomController.text.trim(),
      comment: _destinationCommentController.text.trim(),
      contactPhone: _destinationPhone,
    );

    widget.onSave?.call(updatedPickup, updatedDestination);

    final result = DeliveryUpdatedOrderResult(
      pickupDetails: updatedPickup,
      destinationDetails: updatedDestination,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = math.max(mediaQuery.padding.bottom, 24.0) +
        mediaQuery.viewInsets.bottom +
        16.0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.94,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF262626), // Effet grisé élégant derrière les cartes (pas totalement noir)
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poignée supérieure de glissement sur fond grisé
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFF94A3B8),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Corps défilable avec les deux cartes blanches séparées par le fond grisé
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                12,
                4,
                12,
                bottomInset, // Remonté pour dégager la barre de navigation Android
              ),
              child: Column(
                children: [
                  // Carte 1 : Titre + Sous-titre + Section Expéditeur (De)
                  _buildPickupCard(),

                  const SizedBox(height: 12), // Séparation montrant le fond grisé

                  // Carte 2 : Section Destinataire (Vers) avec icône flag SVG
                  _buildDestinationCard(),

                  const SizedBox(height: 18),

                  // Bouton Enregistrer surélevé pour être bien au-dessus de la barre de navigation
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Enregistrer',
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
          ),
        ],
      ),
    );
  }

  // --- CARTE 1 BLANCHE (EXPÉDITEUR) SANS CONTOUR COLORÉ ---
  Widget _buildPickupCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: null, // Pas de contour coloré
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête : Titre & Sous-titre
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mettez à jour votre commande',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ces modifications n\'auront pas d\'incidence sur le coût de la livraison',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          // Ligne Adresse : Icône Box + De + Adresse + Cadenas
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: Color(0xFF0F172A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'De',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.pickupAddress.isNotEmpty
                            ? widget.pickupAddress
                            : 'Adresse',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.lock_rounded,
                  color: Color(0xFFCBD5E1),
                  size: 20,
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),

          // Ligne 1 : Entrée | Appt/Bureau
          _buildTwoFieldsRow(
            controller1: _pickupEntryController,
            hint1: 'Entrée',
            controller2: _pickupApartmentController,
            hint2: 'Appt/Bureau',
          ),

          const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),

          // Ligne 2 : Étage | Interphone
          _buildTwoFieldsRow(
            controller1: _pickupFloorController,
            hint1: 'Étage',
            controller2: _pickupIntercomController,
            hint2: 'Interphone',
          ),

          const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),

          // Ligne 3 : Commentaires...
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _pickupCommentController,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Commentaires...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),

          // Ligne 4 : Numéro de contact (toujours affiché en entier sans "...")
          _buildContactRow(
            phone: _pickupPhone,
            onTap: _selectPickupContact,
          ),
        ],
      ),
    );
  }

  // --- CARTE 2 BLANCHE (DESTINATAIRE) SANS CONTOUR COLORÉ ---
  Widget _buildDestinationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: null, // Pas de contour coloré
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ligne Adresse : Icône Flag SVG + Vers + Adresse + Cadenas
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(9),
                  child: SvgPicture.asset(
                    'assets/icons/flag-svgrepo-com.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF0F172A),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vers',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.destinationAddress.isNotEmpty
                            ? widget.destinationAddress
                            : 'Adresse',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.lock_rounded,
                  color: Color(0xFFCBD5E1),
                  size: 20,
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),

          // Ligne 1 : Entrée | Appt/Bureau
          _buildTwoFieldsRow(
            controller1: _destinationEntryController,
            hint1: 'Entrée',
            controller2: _destinationApartmentController,
            hint2: 'Appt/Bureau',
          ),

          const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),

          // Ligne 2 : Étage | Interphone
          _buildTwoFieldsRow(
            controller1: _destinationFloorController,
            hint1: 'Étage',
            controller2: _destinationIntercomController,
            hint2: 'Interphone',
          ),

          const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),

          // Ligne 3 : Commentaires...
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _destinationCommentController,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Commentaires...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),

          // Ligne 4 : Numéro de contact (toujours affiché en entier sans "...")
          _buildContactRow(
            phone: _destinationPhone,
            onTap: _selectDestinationContact,
          ),
        ],
      ),
    );
  }

  // --- LIGNE CONTACT : "Numéro de contact" TOUJOURS ENTIER ---
  Widget _buildContactRow({
    required String phone,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // "Numéro de contact" est fixe et ne peut JAMAIS être tronqué par "..."
            Text(
              'Numéro de contact',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 8),
            // Le texte à droite (numéro ou "Ne pas lui communiquer") prend l'espace restant
            Expanded(
              child: Text(
                phone.isNotEmpty ? phone : '+221784226719',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTwoFieldsRow({
    required TextEditingController controller1,
    required String hint1,
    required TextEditingController controller2,
    required String hint2,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller1,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: hint1,
                hintStyle: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: const Color(0xFFF1F5F9),
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          Expanded(
            child: TextField(
              controller: controller2,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: hint2,
                hintStyle: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
