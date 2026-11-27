import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/map_config.dart';
import 'package:seddo/features/delivery/presentation/pages/delivery_itinerary_page.dart';
import 'package:seddo/features/delivery/presentation/pages/delivery_order_details_page.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_address_details_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_destination_search_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_time_option_info_modal.dart';
import 'package:seddo/features/payment/data/services/payment_methods_service.dart';
import 'package:seddo/features/payment/presentation/widgets/payment_method_modal.dart';
import 'package:seddo/services/places_service.dart';

/// Modal / Page Formulaire de commande Express (Express Moto & Express Cargo)
/// Conforme aux spécifications et maquettes :
/// 1. Carte supérieure Adresse : icône box.jpg, titre Express, croix de fermeture X, Point de départ, Destination, + Adresse, Itinéraire
///    Lorsque l'on fait défiler vers le bas, la carte se replie pour ne laisser visible que la barre Express avec la croix (et les boutons d'action).
/// 2. Carte principale du véhicule : illustration avec dimensions (Unknown.webp), poids max 10 kg, créneaux de livraison radio
/// 3. Carte Coursier séparée (seule avec son propre espacement)
/// 4. Carte Options séparée (seule avec son propre espacement)
/// 5. Textes intégraux sans coupure ("...")
/// 6. Barre d'action inférieure fixe
class DeliveryOrderFormModal extends StatefulWidget {
  final String pickupAddress;
  final String destinationAddress;
  final LatLng? pickupLocation;
  final LatLng? destinationLocation;
  final DeliveryAddressDetails? initialPickupDetails;
  final DeliveryAddressDetails? initialDestinationDetails;
  final PlacesService? placesService;
  final String deliveryType; // 'moto' | 'cargo'
  final int estimatedPrice;
  final VoidCallback? onEditPickup;
  final VoidCallback? onEditDestination;
  final Function(String pickup, LatLng? pickupLoc, String dest, LatLng? destLoc)?
      onAddressesUpdated;
  final Function(DeliveryAddressDetails? pickupDetails, DeliveryAddressDetails? destinationDetails)?
      onDetailsUpdated;

  const DeliveryOrderFormModal({
    super.key,
    required this.pickupAddress,
    required this.destinationAddress,
    this.pickupLocation,
    this.destinationLocation,
    this.initialPickupDetails,
    this.initialDestinationDetails,
    this.placesService,
    required this.deliveryType,
    required this.estimatedPrice,
    this.onEditPickup,
    this.onEditDestination,
    this.onAddressesUpdated,
    this.onDetailsUpdated,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String pickupAddress,
    required String destinationAddress,
    LatLng? pickupLocation,
    LatLng? destinationLocation,
    DeliveryAddressDetails? initialPickupDetails,
    DeliveryAddressDetails? initialDestinationDetails,
    PlacesService? placesService,
    required String deliveryType,
    required int estimatedPrice,
    VoidCallback? onEditPickup,
    VoidCallback? onEditDestination,
    Function(String pickup, LatLng? pickupLoc, String dest, LatLng? destLoc)?
        onAddressesUpdated,
    Function(DeliveryAddressDetails? pickupDetails, DeliveryAddressDetails? destinationDetails)?
        onDetailsUpdated,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DeliveryOrderFormModal(
        pickupAddress: pickupAddress,
        destinationAddress: destinationAddress,
        pickupLocation: pickupLocation,
        destinationLocation: destinationLocation,
        initialPickupDetails: initialPickupDetails,
        initialDestinationDetails: initialDestinationDetails,
        placesService: placesService,
        deliveryType: deliveryType,
        estimatedPrice: estimatedPrice,
        onEditPickup: onEditPickup,
        onEditDestination: onEditDestination,
        onAddressesUpdated: onAddressesUpdated,
        onDetailsUpdated: onDetailsUpdated,
      ),
    );
  }

  @override
  State<DeliveryOrderFormModal> createState() => _DeliveryOrderFormModalState();
}

class _DeliveryOrderFormModalState extends State<DeliveryOrderFormModal> {
  // Option horaire sélectionnée : 'asap' | '30min' | '2hours'
  String _selectedTimeOption = '2hours';

  // Préférence du coursier : 'any' (N'importe quel coursier) | 'car' (Coursier en voiture)
  String _courierChoice = 'any';

  // Options supplémentaires
  bool _isThermalBagEnabled = false;
  String _courierInstructions = '';

  late String _pickupAddress;
  late String _destinationAddress;
  late LatLng _pickupLocation;
  late LatLng _destinationLocation;

  DeliveryAddressDetails? _pickupDetails;
  DeliveryAddressDetails? _destinationDetails;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _pickupAddress = widget.pickupAddress;
    _destinationAddress = widget.destinationAddress;
    _pickupLocation = widget.pickupLocation ??
        const LatLng(MapConfig.dakarCenterLat, MapConfig.dakarCenterLng);
    _destinationLocation = widget.destinationLocation ??
        const LatLng(14.6937, -17.4441);
    _pickupDetails = widget.initialPickupDetails;
    _destinationDetails = widget.initialDestinationDetails;
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int get _currentPrice {
    final base = widget.estimatedPrice;
    switch (_selectedTimeOption) {
      case 'asap':
        return base + 300; // ex: 1000 F
      case '30min':
        return base + 200; // ex: 900 F
      case '2hours':
      default:
        return base; // ex: 700 F
    }
  }

  String get _currentPickupEta {
    switch (_selectedTimeOption) {
      case 'asap':
        return 'Prise en charge ~9 min';
      case '30min':
        return 'Prise en charge dans 39 min';
      case '2hours':
      default:
        return 'Prise en charge dans 1 h 11 min';
    }
  }

  String get _currentDeliveryEta {
    switch (_selectedTimeOption) {
      case 'asap':
        return 'Livraison ~22 min';
      case '30min':
        return 'Livraison dans 52 min';
      case '2hours':
      default:
        return 'Livraison dans 1 h 33 min';
    }
  }

  String get _actionButtonText {
    return 'Saisissez les détails';
  }

  // --- MODAL 1 : OPTIONS (Image 3) ---
  void _openOptionsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(ctx).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text(
                'Options',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              // Sac de livraison isotherme + Switch
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sac de livraison isotherme',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  CupertinoSwitch(
                    value: _isThermalBagEnabled,
                    activeColor: AppColors.primary,
                    trackColor: const Color(0xFFD1D5DB),
                    onChanged: (val) {
                      setModalState(() => _isThermalBagEnabled = val);
                      setState(() => _isThermalBagEnabled = val);
                    },
                  ),
                ],
              ),
              const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 4),

              // Instructions du Coursier >
              InkWell(
                onTap: () {
                  _openInstructionsModal();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Instructions du Coursier',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF0F172A),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
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
                      fontSize: 16,
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
    );
  }

  // --- MODAL 2 : INSTRUCTIONS DU COURSIER (Image 4) ---
  void _openInstructionsModal() {
    final controller = TextEditingController(text: _courierInstructions);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          final bottomPadding = MediaQuery.of(ctx).padding.bottom;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              bottomInset + bottomPadding + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Text(
                    'Instructions du Coursier',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Expliquez précisément ce dont vous avez besoin afin que le coursier puisse traiter votre demande dans les meilleures conditions.',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF334155),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        TextField(
                          controller: controller,
                          maxLines: 5,
                          maxLength: 4000,
                          onChanged: (_) => setModalState(() {}),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Saisissez les instructions...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 15,
                              color: const Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            counterText: '',
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            '${controller.text.length}/4000',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assistant will help out',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'If you need to pick up an order or run an errand',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
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
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _courierInstructions = controller.text.trim();
                        });
                        Navigator.of(ctx).pop();
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- MODAL 3 : COURSIER (Image 5) ---
  void _openCourierModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(ctx).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text(
                'Coursier',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 18),
              // Option 1: N'importe quel coursier à proximité
              InkWell(
                onTap: () {
                  setModalState(() => _courierChoice = 'any');
                  setState(() => _courierChoice = 'any');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'N\'importe quel coursier à proximité',
                                style: GoogleFonts.inter(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _courierChoice == 'any'
                              ? AppColors.primary
                              : const Color(0xFFF1F5F9),
                        ),
                        child: _courierChoice == 'any'
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),

              // Option 2: Coursier en voiture
              InkWell(
                onTap: () {
                  setModalState(() => _courierChoice = 'car');
                  setState(() => _courierChoice = 'car');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Coursier en voiture',
                          style: GoogleFonts.inter(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _courierChoice == 'car'
                              ? AppColors.primary
                              : const Color(0xFFF1F5F9),
                        ),
                        child: _courierChoice == 'car'
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
                    'Terminer',
                    style: GoogleFonts.inter(
                      fontSize: 16,
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
    );
  }

  void _submitOrder() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (ctx) => DeliveryOrderDetailsPage(
          pickupAddress: _pickupAddress,
          destinationAddress: _destinationAddress,
          pickupLocation: _pickupLocation,
          destinationLocation: _destinationLocation,
          pickupDetails: _pickupDetails,
          destinationDetails: _destinationDetails,
          selectedTimeOption: _selectedTimeOption,
          courierChoice: _courierChoice,
          estimatedPrice: widget.estimatedPrice,
          placesService: widget.placesService,
          onAddressesUpdated: (pickup, pickupLoc, dest, destLoc) {
            setState(() {
              _pickupAddress = pickup;
              if (pickupLoc != null) _pickupLocation = pickupLoc;
              _destinationAddress = dest;
              if (destLoc != null) _destinationLocation = destLoc;
            });
            widget.onAddressesUpdated?.call(
              pickup,
              pickupLoc,
              dest,
              destLoc,
            );
          },
          onDetailsUpdated: (pickupDet, destDet) {
            setState(() {
              _pickupDetails = pickupDet;
              _destinationDetails = destDet;
            });
            widget.onDetailsUpdated?.call(pickupDet, destDet);
          },
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openPickupDetails() async {
    final result = await DeliveryAddressDetailsModal.show(
      context,
      address: _pickupAddress,
      location: _pickupLocation,
      isPickup: true,
      initialDetails: _pickupDetails,
      placesService: widget.placesService ?? PlacesService(),
      onEditAddress: _editPickupAddressDirectly,
      onSave: (details) {
        if (!mounted) return;
        setState(() {
          _pickupDetails = details;
          if (details.address.isNotEmpty) {
            _pickupAddress = details.address;
          }
          if (details.location != null) {
            _pickupLocation = details.location!;
          }
        });
        widget.onAddressesUpdated?.call(
          _pickupAddress,
          _pickupLocation,
          _destinationAddress,
          _destinationLocation,
        );
        widget.onDetailsUpdated?.call(
          _pickupDetails,
          _destinationDetails,
        );
      },
    );
    if (result != null && mounted) {
      setState(() {
        _pickupDetails = result;
        if (result.address.isNotEmpty) {
          _pickupAddress = result.address;
        }
        if (result.location != null) {
          _pickupLocation = result.location!;
        }
      });
      widget.onAddressesUpdated?.call(
        _pickupAddress,
        _pickupLocation,
        _destinationAddress,
        _destinationLocation,
      );
      widget.onDetailsUpdated?.call(
        _pickupDetails,
        _destinationDetails,
      );
    }
  }

  Future<void> _openDestinationDetails() async {
    final result = await DeliveryAddressDetailsModal.show(
      context,
      address: _destinationAddress,
      location: _destinationLocation,
      isPickup: false,
      initialDetails: _destinationDetails,
      placesService: widget.placesService ?? PlacesService(),
      onEditAddress: _editDestinationAddressDirectly,
      onSave: (details) {
        if (!mounted) return;
        setState(() {
          _destinationDetails = details;
          if (details.address.isNotEmpty) {
            _destinationAddress = details.address;
          }
          if (details.location != null) {
            _destinationLocation = details.location!;
          }
        });
        widget.onAddressesUpdated?.call(
          _pickupAddress,
          _pickupLocation,
          _destinationAddress,
          _destinationLocation,
        );
        widget.onDetailsUpdated?.call(
          _pickupDetails,
          _destinationDetails,
        );
      },
    );
    if (result != null && mounted) {
      setState(() {
        _destinationDetails = result;
        if (result.address.isNotEmpty) {
          _destinationAddress = result.address;
        }
        if (result.location != null) {
          _destinationLocation = result.location!;
        }
      });
      widget.onAddressesUpdated?.call(
        _pickupAddress,
        _pickupLocation,
        _destinationAddress,
        _destinationLocation,
      );
      widget.onDetailsUpdated?.call(
        _pickupDetails,
        _destinationDetails,
      );
    }
  }

  Future<void> _editPickupAddressDirectly() async {
    final result = await DeliveryDestinationSearchModal.show(
      context,
      placesService: widget.placesService ?? PlacesService(),
      pickupLocation: _pickupLocation,
      isPickup: true,
      title: 'Point de départ',
    );
    if (result != null && mounted) {
      final newLoc = LatLng(result.latitude, result.longitude);
      final newAddr = result.mainText.isNotEmpty
          ? result.mainText
          : result.fullAddress;
      setState(() {
        _pickupAddress = newAddr;
        _pickupLocation = newLoc;
      });
      widget.onAddressesUpdated?.call(
        _pickupAddress,
        _pickupLocation,
        _destinationAddress,
        _destinationLocation,
      );
    }
  }

  Future<void> _editDestinationAddressDirectly() async {
    final result = await DeliveryDestinationSearchModal.show(
      context,
      placesService: widget.placesService ?? PlacesService(),
      pickupLocation: _pickupLocation,
      isPickup: false,
    );
    if (result != null && mounted) {
      final newLoc = LatLng(result.latitude, result.longitude);
      final newAddr = result.mainText.isNotEmpty
          ? result.mainText
          : result.fullAddress;
      setState(() {
        _destinationAddress = newAddr;
        _destinationLocation = newLoc;
      });
      widget.onAddressesUpdated?.call(
        _pickupAddress,
        _pickupLocation,
        _destinationAddress,
        _destinationLocation,
      );
    }
  }

  Future<void> _openItinerary() async {
    final result = await DeliveryItineraryPage.show(
      context,
      pickupLocation: _pickupLocation,
      pickupAddress: _pickupAddress,
      destinationLocation: _destinationLocation,
      destinationAddress: _destinationAddress,
      placesService: widget.placesService ?? PlacesService(),
    );

    if (result != null && mounted) {
      setState(() {
        _pickupAddress = result.pickupAddress;
        _pickupLocation = result.pickupLocation;
        _destinationAddress = result.destinationAddress;
        _destinationLocation = result.destinationLocation;
      });
      widget.onAddressesUpdated?.call(
        result.pickupAddress,
        result.pickupLocation,
        result.destinationAddress,
        result.destinationLocation,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isMoto = widget.deliveryType.toLowerCase() == 'moto';
    final bottomPadding = mediaQuery.padding.bottom;

    return Container(
      height: mediaQuery.size.height * 0.94,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Contenu défilable avec en-tête d'adresses collapsible synchronisé
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _AddressCardHeaderDelegate(
                    pickupAddress: _pickupAddress,
                    destinationAddress: _destinationAddress,
                    onOpenPickupDetails: _openPickupDetails,
                    onOpenDestinationDetails: _openDestinationDetails,
                    onOpenItinerary: _openItinerary,
                    onAddAddress: _editDestinationAddressDirectly,
                    onEditPickup: _openPickupDetails,
                    onEditDestination: _openDestinationDetails,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // 2. CARTE PRINCIPALE : Véhicule, Poids max, Créneaux horaires
                        _buildVehicleAndOptionsCard(isMoto),

                        const SizedBox(height: 10),

                        // 3. CARTE COURSIER SÉPARÉE (seule)
                        _buildCourierCard(),

                        const SizedBox(height: 10),

                        // 4. CARTE OPTIONS SÉPARÉE (seule)
                        _buildOptionsCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 5. BARRE INFÉRIEURE FIXE (Images 1 & 2)
          _buildBottomBar(bottomPadding),
        ],
      ),
    );
  }

  // --- WIDGET 2 : CARTE DU VÉHICULE & CRÉNEAUX HORAIRES ---
  Widget _buildVehicleAndOptionsCard(bool isMoto) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Illustration avec dimensions du colis (Unknown.webp)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 8),
              child: Image.asset(
                isMoto
                    ? 'assets/images/Unknown.webp'
                    : 'assets/images/livrcar.png',
                height: 148,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Poids maximal et description complète sans coupure
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  Text(
                    isMoto
                        ? 'Poids maximal : 10 kg'
                        : 'Poids maximal : 500 kg',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isMoto
                        ? 'Livré par coursiers à pied à proximité, en voiture ou en deux-roues'
                        : 'Transportez de gros volumes en toute sérénité',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),
          const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),

          // 1. Créneau : Dès que possible
          _buildTimeOptionTile(
            id: 'asap',
            title: 'Dès que possible',
            price: 'à partir de ${widget.estimatedPrice + 300} F',
            hasInfo: false,
          ),
          const Divider(
            height: 1,
            thickness: 0.8,
            indent: 16,
            endIndent: 16,
            color: Color(0xFFF1F5F9),
          ),

          // 2. Créneau : 30 minutes de plus (i)
          _buildTimeOptionTile(
            id: '30min',
            title: '30 minutes de plus',
            price: 'à partir de ${widget.estimatedPrice + 200} F',
            hasInfo: true,
          ),
          const Divider(
            height: 1,
            thickness: 0.8,
            indent: 16,
            endIndent: 16,
            color: Color(0xFFF1F5F9),
          ),

          // 3. Créneau : Dans 2 heures (i)
          _buildTimeOptionTile(
            id: '2hours',
            title: 'Dans 2 heures',
            price: 'à partir de ${widget.estimatedPrice} F',
            hasInfo: true,
          ),
        ],
      ),
    );
  }

  // --- WIDGET 3 : CARTE COURSIER SÉPARÉE (Image 2) ---
  Widget _buildCourierCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: _openCourierModal,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Coursier • ',
                          style: GoogleFonts.inter(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        TextSpan(
                          text: _courierChoice == 'any'
                              ? 'N\'importe quel coursier à proximité'
                              : 'Coursier en voiture',
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF94A3B8),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET 4 : CARTE OPTIONS SÉPARÉE (Image 2) ---
  Widget _buildOptionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: _openOptionsModal,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Text(
                  'Options',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                if (_isThermalBagEnabled)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Sac isotherme',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
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
      ),
    );
  }

  // --- WIDGET 5 : BARRE INFÉRIEURE FIXE ---
  Widget _buildBottomBar(double bottomPadding) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 14, 18, bottomPadding + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ligne supérieure de la barre : Délais & Tarif
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentPickupEta,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentDeliveryEta,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'à partir de $_currentPrice F',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Ligne inférieure de la barre : Moyen de paiement & Bouton d'action
          Row(
            children: [
              // Moyen de paiement
              ValueListenableBuilder<String>(
                valueListenable: PaymentMethodsService().selectedCodeNotifier,
                builder: (context, code, _) {
                  final assetPath =
                      PaymentMethodsService.getAssetForCode(code);
                  final isCash = code.toUpperCase().trim() == 'CASH';

                  return Material(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => PaymentMethodModal.show(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        height: 52,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            isCash
                                ? Image.asset(
                                    assetPath,
                                    width: 32,
                                    height: 24,
                                    fit: BoxFit.contain,
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.asset(
                                      assetPath,
                                      width: 24,
                                      height: 24,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Paiement',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                                Text(
                                  isCash ? 'Espèces' : code,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(width: 10),

              // Bouton rouge d'action
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _submitOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _actionButtonText,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTimeOptionInfoModal({required String id, required String title}) {
    DeliveryTimeOptionInfoModal.show(
      context,
      title: title,
      timeOptionId: id,
    );
  }

  Widget _buildTimeOptionTile({
    required String id,
    required String title,
    required String price,
    required bool hasInfo,
  }) {
    final isSelected = _selectedTimeOption == id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // En cliquant sur le texte du créneau ou sur l'icône info (i) -> sélectionne et ouvre le modal d'info
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() => _selectedTimeOption = id);
                if (hasInfo) {
                  _showTimeOptionInfoModal(id: id, title: title);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (hasInfo) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 17,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // En cliquant sur le prix ou le bouton radio -> sélectionne directement l'option
          InkWell(
            onTap: () => setState(() => _selectedTimeOption = id),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    price,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 15,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// En-tête sliver persistant pour la carte d'adresses Express
/// Lors du défilement vers le haut, le point de départ, la destination et les boutons d'adresse/itinéraire
/// remontent et disparaissent en douceur sous la barre figée Express qui reste visible en haut avec sa croix.
class _AddressCardHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String pickupAddress;
  final String destinationAddress;
  final VoidCallback? onOpenPickupDetails;
  final VoidCallback? onOpenDestinationDetails;
  final VoidCallback? onOpenItinerary;
  final VoidCallback? onAddAddress;
  final VoidCallback? onEditPickup;
  final VoidCallback? onEditDestination;
  final VoidCallback? onClose;

  _AddressCardHeaderDelegate({
    required this.pickupAddress,
    required this.destinationAddress,
    this.onOpenPickupDetails,
    this.onOpenDestinationDetails,
    this.onOpenItinerary,
    this.onAddAddress,
    this.onEditPickup,
    this.onEditDestination,
    this.onClose,
  });

  @override
  double get minExtent => 78.0;

  @override
  double get maxExtent => 264.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final currentCardHeight = math.max(60.0, 246.0 - shrinkOffset);
    final progress = (shrinkOffset / (246.0 - 60.0)).clamp(0.0, 1.0);

    return Container(
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Container(
        height: currentCardHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // 1. Section défilable des adresses : remonte et s'estompe sous l'en-tête Express
              Positioned(
                left: 0,
                right: 0,
                top: 60.0 - shrinkOffset,
                child: Opacity(
                  opacity: (1.0 - progress * 1.6).clamp(0.0, 1.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(
                        height: 1,
                        thickness: 0.8,
                        color: Color(0xFFF1F5F9),
                      ),

                      // Point de départ (toute la ligne horizontale ouvre le modal de détails)
                      InkWell(
                        onTap: onOpenPickupDetails ?? onEditPickup,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Point de départ',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      pickupAddress,
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
                              const Icon(
                                Icons.chevron_right,
                                color: Color(0xFF94A3B8),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Divider(
                        height: 1,
                        thickness: 0.8,
                        indent: 64,
                        endIndent: 16,
                        color: Color(0xFFF1F5F9),
                      ),

                      // Destination (toute la ligne horizontale ouvre le modal de détails)
                      InkWell(
                        onTap: onOpenDestinationDetails ?? onEditDestination,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: Center(
                                  child: SvgPicture.asset(
                                    'assets/icons/flag-svgrepo-com.svg',
                                    width: 22,
                                    height: 22,
                                    colorFilter: const ColorFilter.mode(
                                      Color(0xFF1E1E1E),
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Destination',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      destinationAddress,
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
                              const Icon(
                                Icons.chevron_right,
                                color: Color(0xFF94A3B8),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Divider(
                        height: 1,
                        thickness: 0.8,
                        color: Color(0xFFF1F5F9),
                      ),

                      // Boutons capsules : + Adresse & Itinéraire
                      // Espacement ajusté pour garantir la visibilité de + Adresse et Itinéraire en toutes circonstances
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                        child: Row(
                          children: [
                            Material(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                onTap: onAddAddress ?? onEditDestination,
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.add,
                                        size: 18,
                                        color: Color(0xFF0F172A),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Adresse',
                                        style: GoogleFonts.inter(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Material(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                onTap: onOpenItinerary ?? onClose,
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.menu_book_outlined,
                                        size: 18,
                                        color: Color(0xFF0F172A),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Itinéraire',
                                        style: GoogleFonts.inter(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. En-tête Express figé à top: 0 avec fond blanc opaque
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 60.0,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/images/box.jpg',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Express',
                        style: GoogleFonts.inter(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.4,
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: const Color(0xFFF1F5F9),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: onClose,
                          customBorder: const CircleBorder(),
                          child: const SizedBox(
                            width: 34,
                            height: 34,
                            child: Center(
                              child: Icon(
                                Icons.close,
                                color: Color(0xFF64748B),
                                size: 18,
                              ),
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
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _AddressCardHeaderDelegate oldDelegate) {
    return pickupAddress != oldDelegate.pickupAddress ||
        destinationAddress != oldDelegate.destinationAddress;
  }
}
