import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_address_details_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_call_courier_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_order_summary_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_update_order_modal.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/presentation/pages/driver_chat_page.dart';

/// Modal / Feuille inférieure de suivi en direct de la livraison (Images 1, 2 & 3)
class DeliveryTrackingSheet extends StatefulWidget {
  final String pickupAddress;
  final String destinationAddress;
  final String pickupPhone;
  final String destinationPhone;
  final DeliveryAddressDetails? pickupDetails;
  final DeliveryAddressDetails? destinationDetails;
  final int price;
  final String paymentMethod;
  final int initialStep; // 1: Recherche / assignation, 2: Prise en charge en route, etc.
  final VoidCallback? onEditAddressDetails;
  final VoidCallback? onShare;
  final VoidCallback? onCallDriver;
  final VoidCallback? onChatDriver;
  final VoidCallback? onCancelOrder;
  final void Function(
    DeliveryAddressDetails pickup,
    DeliveryAddressDetails destination,
  )? onDetailsUpdated;

  const DeliveryTrackingSheet({
    super.key,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.pickupPhone,
    required this.destinationPhone,
    this.pickupDetails,
    this.destinationDetails,
    required this.price,
    this.paymentMethod = 'Espèces',
    this.initialStep = 1,
    this.onEditAddressDetails,
    this.onShare,
    this.onCallDriver,
    this.onChatDriver,
    this.onCancelOrder,
    this.onDetailsUpdated,
  });

  @override
  State<DeliveryTrackingSheet> createState() => _DeliveryTrackingSheetState();
}

class _DeliveryTrackingSheetState extends State<DeliveryTrackingSheet> {
  late int _currentStep;
  bool _showMyPosition = true;
  Timer? _stepSimulationTimer;

  // État d'annulation de la commande (Images 1, 2 & 3)
  bool _isCancelled = false;
  int _cancelledAtStep = 1;
  String? _selectedCancelReason;
  final TextEditingController _problemDescriptionController =
      TextEditingController();
  bool _hasProblemText = false;
  int _driverRatingSelected = 0;

  static const List<String> _cancelReasons = [
    'Le coursier a demandé d\'annuler la commande',
    'Impossible de joindre le coursier',
    'Attente trop longue',
    'Le coursier s\'est montré impoli',
    'Le coursier ne se déplaçait pas dans ma direction',
    'La cargaison ne rentre pas dans le véhicule',
    'La livraison n\'est plus nécessaire',
  ];

  late DeliveryAddressDetails _currentPickupDetails;
  late DeliveryAddressDetails _currentDestinationDetails;

  // Compteur de recherche de coursier
  int _searchElapsedSeconds = 0;
  Timer? _searchCounterTimer;

  // Données du coursier assigné (Image 2)
  final DriverModel _courierDriver = const DriverModel(
    id: 'courier_amour',
    name: 'Amour Juslaure Marland',
    phone: '+221784226719',
    rating: 4.9,
    totalRides: 342,
    carModel: 'Moto Express',
    carColor: 'Rouge',
    licensePlate: 'DK-1234-AZ',
    rideType: RideType.eco,
    currentLocation: LatLng(14.7167, -17.4677),
    etaMinutes: 4,
    distanceKm: 1.2,
  );

  String get _driverName => _courierDriver.name;
  double get _driverRating => _courierDriver.rating;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;

    _currentPickupDetails = widget.pickupDetails ??
        DeliveryAddressDetails(
          address: widget.pickupAddress,
          contactPhone: widget.pickupPhone,
        );

    _currentDestinationDetails = widget.destinationDetails ??
        DeliveryAddressDetails(
          address: widget.destinationAddress,
          contactPhone: widget.destinationPhone,
        );

    // Simulation automatique du passage à l'étape 2 (Livreur assigné / en route) après 4 secondes
    if (_currentStep == 1) {
      // Démarrer le compteur de recherche
      _searchCounterTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _searchElapsedSeconds++;
          });
        }
      });

      _stepSimulationTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          _searchCounterTimer?.cancel();
          setState(() {
            _currentStep = 2;
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant DeliveryTrackingSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pickupDetails != null &&
        widget.pickupDetails != oldWidget.pickupDetails) {
      _currentPickupDetails = widget.pickupDetails!;
    }
    if (widget.destinationDetails != null &&
        widget.destinationDetails != oldWidget.destinationDetails) {
      _currentDestinationDetails = widget.destinationDetails!;
    }
  }

  @override
  void dispose() {
    _stepSimulationTimer?.cancel();
    _searchCounterTimer?.cancel();
    _problemDescriptionController.dispose();
    super.dispose();
  }

  String _formatElapsed(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _pickupLimitTime {
    final now = DateTime.now();
    final limit = now.add(const Duration(minutes: 30));
    return DateFormat('HH:mm').format(limit);
  }

  void _openOrderSummary() {
    DeliveryOrderSummaryModal.show(
      context,
      price: widget.price,
      paymentMethod: widget.paymentMethod,
      serviceClass: 'Le jour même',
      orderDate: DateTime.now(),
    );
  }

  Future<void> _openUpdateOrderModal() async {
    widget.onEditAddressDetails?.call();
    final result = await DeliveryUpdateOrderModal.show(
      context,
      pickupAddress: widget.pickupAddress,
      destinationAddress: widget.destinationAddress,
      initialPickupDetails: _currentPickupDetails,
      initialDestinationDetails: _currentDestinationDetails,
    );

    if (result != null && mounted) {
      setState(() {
        _currentPickupDetails = result.pickupDetails;
        _currentDestinationDetails = result.destinationDetails;
      });
      widget.onDetailsUpdated?.call(
        result.pickupDetails,
        result.destinationDetails,
      );
    }
  }

  void _handleCallCourier() {
    widget.onCallDriver?.call();
    DeliveryCallCourierModal.show(context, driver: _courierDriver);
  }

  void _handleChatCourier() {
    widget.onChatDriver?.call();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverChatPage(
          driver: _courierDriver,
          rideId: 'delivery_order',
        ),
      ),
    );
  }

  void _handleCancelOrder() {
    // Capturer l'étape courante au moment où l'utilisateur ouvre le modal
    final stepAtOpen = _currentStep;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Annuler',
              style: GoogleFonts.inter(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Voulez-vous vraiment annuler ?',
              style: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _stepSimulationTimer?.cancel();
                  _searchCounterTimer?.cancel();
                  setState(() {
                    _isCancelled = true;
                    _cancelledAtStep = stepAtOpen;
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Annuler la commande',
                  style: GoogleFonts.inter(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Fermer',
                  style: GoogleFonts.inter(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleShare() {
    final deliveryLink =
        'https://seddo.app/delivery/track/${DateTime.now().millisecondsSinceEpoch}';
    final shareText =
        'Ma livraison Seddo en direct \n\n'
        'De : ${widget.pickupAddress}\n'
        'Vers : ${widget.destinationAddress}\n\n'
        'Suivez en temps réel : $deliveryLink';
    SharePlus.instance.share(
      ShareParams(
        text: shareText,
        subject: 'Ma livraison Seddo en direct',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCancelled) {
      return _buildCancelledOrderView(context);
    }

    final isDriverAssigned = _currentStep >= 2;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poignée supérieure de glissement
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Badge noir flottant en étape 2 (Image 2)
          if (isDriverAssigned)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Livraison d\'autres commandes\nen route dans votre direction',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),

          // En-tête statut
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDriverAssigned
                            ? 'Prise en charge dans ≈4 min'
                            : 'À la recherche d\'un coursier',
                        style: GoogleFonts.inter(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (!isDriverAssigned) ...[
                        const SizedBox(height: 3),
                        Text(
                          'La recherche d\'un coursier prend un peu plus de temps que d\'habitude. Merci de patienter, nous poursuivons la recherche',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isDriverAssigned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatElapsed(_searchElapsedSeconds),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Stepper de progression (5 étapes reliées par des lignes)
          _buildDeliveryStepper(),

          const SizedBox(height: 18),

          // Ligne d'actions circulaires (Image 1 vs Image 2)
          if (!isDriverAssigned)
            _buildInitialActionButtons()
          else
            _buildDriverActionButtons(),

          const SizedBox(height: 14),

          // Étoiles de notation (Image 2)
          if (isDriverAssigned) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => GestureDetector(
                    onTap: () {
                      setState(() => _driverRatingSelected = index + 1);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.star_rounded,
                        size: 40,
                        color: index < _driverRatingSelected
                            ? AppColors.primary
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_driverRatingSelected > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Center(
                  child: Text(
                    _driverRatingSelected == 5
                        ? 'Excellent !'
                        : _driverRatingSelected == 4
                            ? 'Très bien'
                            : _driverRatingSelected == 3
                                ? 'Bien'
                                : _driverRatingSelected == 2
                                    ? 'Passable'
                                    : 'Décevant',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],

          // Switch "Montrer au coursier où je me trouve"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.near_me_rounded,
                  color: Color(0xFF2563EB),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Montrer au coursier où je me trouve',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                CupertinoSwitch(
                  value: _showMyPosition,
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (val) {
                    setState(() => _showMyPosition = val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),

          // Modalité de paiement
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/cash_banknotes.png',
                  width: 32,
                  height: 24,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.payments_outlined,
                    color: Color(0xFF22C55E),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.paymentMethod,
                        style: GoogleFonts.inter(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Modalité de paiement',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${widget.price} F',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),

          // Ligne "Détails de la commande" (Image 3)
          InkWell(
            onTap: _openOrderSummary,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF64748B),
                    size: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Détails de la commande',
                          style: GoogleFonts.inter(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Le jour même · ${widget.price} F',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF94A3B8),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // Section Expéditeur
          _buildAddressSection(
            sectionTitle: 'Expéditeur',
            phone: _currentPickupDetails.contactPhone.isNotEmpty
                ? _currentPickupDetails.contactPhone
                : widget.pickupPhone,
            address: _currentPickupDetails.address.isNotEmpty
                ? _currentPickupDetails.address
                : widget.pickupAddress,
            isPickup: true,
          ),

          // Section Destinataire
          _buildAddressSection(
            sectionTitle: 'Destinataire',
            phone: _currentDestinationDetails.contactPhone.isNotEmpty
                ? _currentDestinationDetails.contactPhone
                : widget.destinationPhone,
            address: _currentDestinationDetails.address.isNotEmpty
                ? _currentDestinationDetails.address
                : widget.destinationAddress,
            isPickup: false,
          ),

          const SizedBox(height: 16),

          // Bouton Annuler tout en bas du modal
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _handleCancelOrder,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Annuler la commande',
                  style: GoogleFonts.inter(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET STEPPER 5 ÉTAPES ---
  Widget _buildDeliveryStepper({int? overrideStep}) {
    final step = overrideStep ?? _currentStep;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Étape 1 : Commande passée / confirmée
          _buildStepNode(
            stepIndex: 1,
            icon: Icons.check,
            isActive: step >= 1,
            isCurrent: step == 1,
          ),
          _buildStepLine(isActive: step >= 2),

          // Étape 2 : En route pour récupération
          _buildStepNode(
            stepIndex: 2,
            icon: Icons.directions_car_rounded,
            isActive: step >= 2,
            isCurrent: step == 2,
          ),
          _buildStepLine(isActive: step >= 3),

          // Étape 3 : Colis récupéré
          _buildStepNode(
            stepIndex: 3,
            icon: Icons.inventory_2_outlined,
            isActive: step >= 3,
            isCurrent: step == 3,
          ),
          _buildStepLine(isActive: step >= 4),

          // Étape 4 : En route vers le destinataire
          _buildStepNode(
            stepIndex: 4,
            icon: Icons.directions_car_rounded,
            isActive: step >= 4,
            isCurrent: step == 4,
          ),
          _buildStepLine(isActive: step >= 5),

          // Étape 5 : Colis livré
          _buildStepNode(
            stepIndex: 5,
            icon: Icons.flag_outlined,
            isActive: step >= 5,
            isCurrent: step == 5,
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode({
    required int stepIndex,
    required IconData icon,
    required bool isActive,
    required bool isCurrent,
  }) {
    final bgColor = isActive ? AppColors.primary : const Color(0xFFF1F5F9);
    final iconColor = isActive ? Colors.white : const Color(0xFF64748B);

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Icon(
        icon,
        color: iconColor,
        size: 20,
      ),
    );
  }

  Widget _buildStepLine({required bool isActive}) {
    return Expanded(
      child: Container(
        height: 2.5,
        color: isActive ? AppColors.primary : const Color(0xFFE2E8F0),
      ),
    );
  }

  // --- BOUTONS D'ACTION INITIALE (Image 1) ---
  Widget _buildInitialActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCircularActionButton(
          iconWidget: SvgPicture.asset(
            'assets/icons/edit-pencil-line-01-svgrepo-com.svg',
            width: 22,
            height: 22,
            colorFilter: const ColorFilter.mode(
              Color(0xFF0F172A),
              BlendMode.srcIn,
            ),
          ),
          label: 'Préciser les\ndétails de\nl\'adresse',
          onTap: _openUpdateOrderModal,
        ),
        const SizedBox(width: 48),
        _buildCircularActionButton(
          iconWidget: SvgPicture.asset(
            'assets/icons/share-svgrepo-com.svg',
            width: 22,
            height: 22,
            colorFilter: const ColorFilter.mode(
              Color(0xFF0F172A),
              BlendMode.srcIn,
            ),
          ),
          label: 'Partager',
          onTap: _handleShare,
        ),
      ],
    );
  }

  // --- BOUTONS D'ACTION AVEC COURSIER ASSIGNÉ (Image 2) ---
  Widget _buildDriverActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Profil du coursier
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFCBD5E1),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/driver_profile.png',
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.person,
                            size: 32,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_driverRating',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 78,
                child: Text(
                  _driverName,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),

          // 2. Appeler le coursier
          _buildCircularActionButton(
            iconWidget: SvgPicture.asset(
              'assets/icons/call-svgrepo-com.svg',
              width: 22,
              height: 22,
              colorFilter: const ColorFilter.mode(
                Color(0xFF0F172A),
                BlendMode.srcIn,
              ),
            ),
            label: 'Appeler\nle coursier',
            onTap: _handleCallCourier,
          ),

          // 3. Chat avec le coursier
          _buildCircularActionButton(
            iconWidget: SvgPicture.asset(
              'assets/icons/chat-round-svgrepo-com.svg',
              width: 22,
              height: 22,
              colorFilter: const ColorFilter.mode(
                Color(0xFF0F172A),
                BlendMode.srcIn,
              ),
            ),
            label: 'Chat avec\nle coursier',
            onTap: _handleChatCourier,
          ),

          // 4. Partager
          _buildCircularActionButton(
            iconWidget: SvgPicture.asset(
              'assets/icons/share-svgrepo-com.svg',
              width: 22,
              height: 22,
              colorFilter: const ColorFilter.mode(
                Color(0xFF0F172A),
                BlendMode.srcIn,
              ),
            ),
            label: 'Partager',
            onTap: _handleShare,
          ),
        ],
      ),
    );
  }

  Widget _buildCircularActionButton({
    Widget? iconWidget,
    IconData? icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: const Color(0xFFF1F5F9),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 52,
                height: 52,
                child: Center(
                  child: iconWidget ??
                      Icon(
                        icon ?? Icons.help_outline,
                        color: const Color(0xFF0F172A),
                        size: 22,
                      ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 76,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF475569),
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION EXPÉDITEUR / DESTINATAIRE ---
  Widget _buildAddressSection({
    required String sectionTitle,
    required String phone,
    required String address,
    required bool isPickup,
    bool isClickable = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête bandeau gris
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
          color: const Color(0xFFF8FAFC),
          child: Text(
            sectionTitle,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ),

        // Ligne Téléphone - Cliquer ouvre le modal de mise à jour (désactivé lors de l'annulation)
        InkWell(
          onTap: isClickable ? _openUpdateOrderModal : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  color: Color(0xFF0F172A),
                  size: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Numéro de téléphone',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        phone.isNotEmpty ? phone : '+221784226719',
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        const Padding(
          padding: EdgeInsets.only(left: 54, right: 20),
          child: Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),
        ),

        // Ligne Adresse - Cliquer ouvre le modal de mise à jour (désactivé lors de l'annulation)
        InkWell(
          onTap: isClickable ? _openUpdateOrderModal : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isPickup ? AppColors.primary : const Color(0xFF0F172A),
                      width: 3.5,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- COMPOSANTS VUE COMMANDE ANNULÉE (Images 1, 2 & 3) ---

  Widget _buildCancelReasonItem(String reason) {
    final isSelected = _selectedCancelReason == reason;
    return InkWell(
      onTap: () {
        setState(() {
          if (_selectedCancelReason == reason) {
            _selectedCancelReason = null;
          } else {
            _selectedCancelReason = reason;
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                reason,
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelledOrderView(BuildContext context) {
    final hasDriver = _cancelledAtStep >= 2;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poignée supérieure de glissement
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Titre "Commande annulée"
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
            child: Text(
              'Commande annulée',
              style: GoogleFonts.inter(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
          ),

          // Si pas de chauffeur (Image 3) : sous-titre
          if (!hasDriver) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
              child: Text(
                'Veuillez recommander si vous avez annulé par accident',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),
          ],

          // Si chauffeur assigné (Images 1 & 2) : Stepper figé, Profil chauffeur, Raisons d'annulation, Champ problème
          if (hasDriver) ...[
            const SizedBox(height: 10),
            _buildDeliveryStepper(overrideStep: _cancelledAtStep),
            const SizedBox(height: 18),

            // Profil du coursier
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFCBD5E1),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/driver_profile.png',
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.person,
                                size: 32,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            '$_driverRating',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 140,
                    child: Text(
                      _driverName,
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),

            // Liste des raisons d'annulation
            ..._cancelReasons.map((reason) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCancelReasonItem(reason),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        height: 1,
                        thickness: 0.8,
                        color: Color(0xFFF1F5F9),
                      ),
                    ),
                  ],
                )),

            // Champ de texte "Pouvez-vous décrire le problème ?" (Image 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // La question est TOUJOURS visible en haut
                    Text(
                      'Pouvez-vous décrire le problème ?',
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _problemDescriptionController,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: null,
                      onChanged: (val) {
                        setState(() => _hasProblemText = val.trim().isNotEmpty);
                      },
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Décrivez ici...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 14.5,
                          color: const Color(0xFFCBD5E1),
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Modalité de paiement (0 F)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/cash_banknotes.png',
                  width: 32,
                  height: 24,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.payments_outlined,
                    color: Color(0xFF22C55E),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.paymentMethod,
                        style: GoogleFonts.inter(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Modalité de paiement',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '0F',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),

          // Ligne "Détails de la commande" (Image 2 & 3)
          InkWell(
            onTap: () {
              DeliveryOrderSummaryModal.show(
                context,
                price: 0,
                paymentMethod: widget.paymentMethod,
                serviceClass:
                    hasDriver ? 'Le jour même' : 'Any nearest slow',
                orderDate: DateTime.now(),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF64748B),
                    size: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Détails de la commande',
                          style: GoogleFonts.inter(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasDriver
                              ? 'Le jour même · 0F'
                              : 'Any nearest slow · 0F',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF94A3B8),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // Section Expéditeur (non cliquable lors de l'annulation)
          _buildAddressSection(
            sectionTitle: 'Expéditeur',
            phone: _currentPickupDetails.contactPhone.isNotEmpty
                ? _currentPickupDetails.contactPhone
                : widget.pickupPhone,
            address: _currentPickupDetails.address.isNotEmpty
                ? _currentPickupDetails.address
                : widget.pickupAddress,
            isPickup: true,
            isClickable: false,
          ),

          // Section Destinataire (non cliquable lors de l'annulation)
          _buildAddressSection(
            sectionTitle: 'Destinataire',
            phone: _currentDestinationDetails.contactPhone.isNotEmpty
                ? _currentDestinationDetails.contactPhone
                : widget.destinationPhone,
            address: _currentDestinationDetails.address.isNotEmpty
                ? _currentDestinationDetails.address
                : widget.destinationAddress,
            isPickup: false,
            isClickable: false,
          ),

          const SizedBox(height: 16),

          // Bouton Terminer orange tout en bas
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  widget.onCancelOrder?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Terminer',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// --- MODAL DE PARTAGE DE LIVRAISON ---
class _ShareDeliveryModal extends StatefulWidget {
  final String deliveryLink;
  final String shareText;
  final String pickupAddress;
  final String destinationAddress;

  const _ShareDeliveryModal({
    required this.deliveryLink,
    required this.shareText,
    required this.pickupAddress,
    required this.destinationAddress,
  });

  @override
  State<_ShareDeliveryModal> createState() => _ShareDeliveryModalState();
}

class _ShareDeliveryModalState extends State<_ShareDeliveryModal> {
  List<Contact> _contacts = [];
  bool _loadingContacts = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _loadingContacts = true);
    try {
      final status = await FlutterContacts.permissions.request(
        PermissionType.read,
      );
      if (status == PermissionStatus.granted) {
        final contacts = await FlutterContacts.getAll(
          properties: {ContactProperty.phone, ContactProperty.name},
          
        );
        if (mounted) {
          setState(() {
            _contacts = contacts.take(10).toList();
            _loadingContacts = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingContacts = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  void _shareViaApp() {
    Navigator.of(context).pop();
    SharePlus.instance.share(
      ShareParams(
        text: widget.shareText,
        subject: 'Livraison Seddo',
      ),
    );
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: widget.deliveryLink));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Lien copié !',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareToContact(Contact contact) {
    final name = contact.displayName;
    Navigator.of(context).pop();
    SharePlus.instance.share(
      ShareParams(
        text: 'Bonjour $name,\n\n${widget.shareText}',
        subject: 'Livraison Seddo',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poignée
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Text(
              'Partager la livraison',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
          ),

          // Lien Seddo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      'assets/icons/seddo_logo_orange.svg',
                      width: 22,
                      height: 22,
                      colorFilter: ColorFilter.mode(
                        AppColors.primary,
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
                          'Lien de suivi Seddo',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.deliveryLink,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _copyLink,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Copier',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Bouton partager via les apps
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _shareViaApp,
                icon: const Icon(Icons.share_rounded, size: 20),
                label: Text(
                  'Partager via les applications',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Contacts
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Envoyer à un contact',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (_loadingContacts)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Aucun contact disponible',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            )
          else
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _contacts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (ctx, i) {
                  final contact = _contacts[i];
                  final name = contact.displayName ?? '';
                  final initials = name.isNotEmpty
                      ? name[0].toUpperCase()
                      : '?';
                  return GestureDetector(
                    onTap: () => _shareToContact(contact),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 60,
                          child: Text(
                            name.split(' ').first,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          SizedBox(height: bottomPadding + 20),
        ],
      ),
    );
  }
}
