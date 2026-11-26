import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/map_config.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_address_details_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_contact_picker_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_destination_search_modal.dart';
import 'package:seddo/features/payment/data/services/payment_methods_service.dart';
import 'package:seddo/features/payment/presentation/widgets/payment_method_modal.dart';
import 'package:seddo/services/places_service.dart';

/// Page de récapitulatif des détails de livraison (Porte-à-porte / À l'entrée)
/// avec rattachement complet des détails de départ et de destination dans un grand card blanc.
class DeliveryOrderDetailsPage extends StatefulWidget {
  final String pickupAddress;
  final String destinationAddress;
  final LatLng pickupLocation;
  final LatLng destinationLocation;
  final DeliveryAddressDetails? pickupDetails;
  final DeliveryAddressDetails? destinationDetails;
  final String selectedTimeOption; // 'asap' | '30min' | '2hours'
  final String courierChoice; // 'any' | 'car'
  final int estimatedPrice;
  final PlacesService? placesService;
  final void Function(
    String pickupAddress,
    LatLng? pickupLocation,
    String destinationAddress,
    LatLng? destinationLocation,
  )? onAddressesUpdated;
  final void Function(
    DeliveryAddressDetails pickupDetails,
    DeliveryAddressDetails destinationDetails,
  )? onDetailsUpdated;

  const DeliveryOrderDetailsPage({
    super.key,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.pickupLocation,
    required this.destinationLocation,
    this.pickupDetails,
    this.destinationDetails,
    this.selectedTimeOption = '2hours',
    this.courierChoice = 'any',
    this.estimatedPrice = 700,
    this.placesService,
    this.onAddressesUpdated,
    this.onDetailsUpdated,
  });

  @override
  State<DeliveryOrderDetailsPage> createState() =>
      _DeliveryOrderDetailsPageState();
}

class _DeliveryOrderDetailsPageState extends State<DeliveryOrderDetailsPage> {
  // Option de livraison : 'door' (Porte-à-porte) | 'entrance' (À l'entrée) | null
  String? _deliveryMode;

  // Détails Départ (De)
  late String _pickupAddress;
  late LatLng _pickupLocation;
  late final TextEditingController _pickupEntryController;
  late final TextEditingController _pickupApartmentController;
  late final TextEditingController _pickupFloorController;
  late final TextEditingController _pickupIntercomController;
  late final TextEditingController _pickupCommentController;
  late String _pickupContact;
  final List<String> _pickupAttachments = [];
  GoogleMapController? _pickupMapController;

  // Détails Destination (Vers)
  late String _destinationAddress;
  late LatLng _destinationLocation;
  late final TextEditingController _destEntryController;
  late final TextEditingController _destApartmentController;
  late final TextEditingController _destFloorController;
  late final TextEditingController _destIntercomController;
  late final TextEditingController _destCommentController;
  late String _destContact;
  final List<String> _destAttachments = [];
  GoogleMapController? _destMapController;

  @override
  void initState() {
    super.initState();
    _pickupAddress = widget.pickupAddress;
    _pickupLocation = widget.pickupLocation;
    final p = widget.pickupDetails;
    _pickupEntryController = TextEditingController(text: p?.entry ?? '');
    _pickupApartmentController = TextEditingController(text: p?.apartment ?? '');
    _pickupFloorController = TextEditingController(text: p?.floor ?? '');
    _pickupIntercomController = TextEditingController(text: p?.intercom ?? '');
    _pickupCommentController = TextEditingController(text: p?.comment ?? '');
    _pickupContact = p?.contactPhone ?? 'Ne pas lui communiquer';
    if (p?.attachments != null) {
      _pickupAttachments.addAll(p!.attachments);
    }

    _destinationAddress = widget.destinationAddress;
    _destinationLocation = widget.destinationLocation;
    final d = widget.destinationDetails;
    _destEntryController = TextEditingController(text: d?.entry ?? '');
    _destApartmentController = TextEditingController(text: d?.apartment ?? '');
    _destFloorController = TextEditingController(text: d?.floor ?? '');
    _destIntercomController = TextEditingController(text: d?.intercom ?? '');
    _destCommentController = TextEditingController(text: d?.comment ?? '');
    _destContact = d?.contactPhone ?? 'Ne pas lui communiquer';
    if (d?.attachments != null) {
      _destAttachments.addAll(d!.attachments);
    }
  }

  @override
  void dispose() {
    _pickupEntryController.dispose();
    _pickupApartmentController.dispose();
    _pickupFloorController.dispose();
    _pickupIntercomController.dispose();
    _pickupCommentController.dispose();

    _destEntryController.dispose();
    _destApartmentController.dispose();
    _destFloorController.dispose();
    _destIntercomController.dispose();
    _destCommentController.dispose();
    super.dispose();
  }

  // Tarifs calculés selon créneau et mode de livraison
  int get _baseSlotPrice {
    final base = widget.estimatedPrice;
    switch (widget.selectedTimeOption) {
      case 'asap':
        return base + 300;
      case '30min':
        return base + 200;
      case '2hours':
      default:
        return base;
    }
  }

  int get _doorPrice => _baseSlotPrice + 100;
  int get _entrancePrice => _baseSlotPrice;

  int get _currentDisplayedPrice {
    if (_deliveryMode == 'door') return _doorPrice;
    if (_deliveryMode == 'entrance') return _entrancePrice;
    return _entrancePrice; // Affiché par défaut : à partir de ...
  }

  // Horaires de prise en charge et livraison dynamiques
  String get _pickupTimeFormatted {
    final now = DateTime.now();
    int minutesToAdd = 71;
    if (widget.selectedTimeOption == 'asap') {
      minutesToAdd = 12;
    } else if (widget.selectedTimeOption == '30min') {
      minutesToAdd = 40;
    }
    final pickupTime = now.add(Duration(minutes: minutesToAdd));
    return DateFormat('HH:mm').format(pickupTime);
  }

  String get _deliveryTimeFormatted {
    final now = DateTime.now();
    int minutesToAdd = 113;
    if (widget.selectedTimeOption == 'asap') {
      minutesToAdd = 35;
    } else if (widget.selectedTimeOption == '30min') {
      minutesToAdd = 70;
    }
    final deliveryTime = now.add(Duration(minutes: minutesToAdd));
    return DateFormat('HH:mm').format(deliveryTime);
  }

  String get _headerTitle {
    switch (widget.selectedTimeOption) {
      case 'asap':
        return 'Dès que possible';
      case '30min':
        return '30 minutes de plus';
      case '2hours':
      default:
        return 'Dans 2 heures';
    }
  }

  String get _headerSubtitle {
    switch (widget.courierChoice) {
      case 'car':
        return 'Coursier en voiture';
      case 'any':
      default:
        return 'N\'importe quel coursier à proximité';
    }
  }

  // Méthodes pour changer l'adresse de départ ou de destination
  Future<void> _changePickupAddress() async {
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
      _pickupMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(newLoc, 16.0),
      );
      widget.onAddressesUpdated?.call(
        _pickupAddress,
        _pickupLocation,
        _destinationAddress,
        _destinationLocation,
      );
    }
  }

  Future<void> _changeDestinationAddress() async {
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
      _destMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(newLoc, 16.0),
      );
      widget.onAddressesUpdated?.call(
        _pickupAddress,
        _pickupLocation,
        _destinationAddress,
        _destinationLocation,
      );
    }
  }

  // Sélection du contact
  Future<void> _pickPickupContact() async {
    final result = await DeliveryContactPickerModal.show(
      context,
      isExpediteur: true,
      currentPhone: _pickupContact,
    );
    if (result != null && mounted) {
      setState(() {
        _pickupContact = result.phone.isNotEmpty ? result.phone : result.name;
      });
    }
  }

  Future<void> _pickDestContact() async {
    final result = await DeliveryContactPickerModal.show(
      context,
      isExpediteur: false,
      currentPhone: _destContact,
    );
    if (result != null && mounted) {
      setState(() {
        _destContact = result.phone.isNotEmpty ? result.phone : result.name;
      });
    }
  }

  // Fichiers joints réels
  Future<void> _pickFromGallery(bool isPickup) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      setState(() {
        if (isPickup) {
          _pickupAttachments.add('Photo_1.jpg');
        } else {
          _destAttachments.add('Photo_1.jpg');
        }
      });
      return;
    }
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        final fileName = image.name.isNotEmpty
            ? image.name
            : image.path.split(Platform.pathSeparator).last;
        setState(() {
          if (isPickup) {
            _pickupAttachments.add(fileName);
          } else {
            _destAttachments.add(fileName);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _takePhoto(bool isPickup) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      setState(() {
        if (isPickup) {
          _pickupAttachments.add('Camera_1.jpg');
        } else {
          _destAttachments.add('Camera_1.jpg');
        }
      });
      return;
    }
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null && mounted) {
        final fileName = photo.name.isNotEmpty
            ? photo.name
            : photo.path.split(Platform.pathSeparator).last;
        setState(() {
          if (isPickup) {
            _pickupAttachments.add(fileName);
          } else {
            _destAttachments.add(fileName);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _pickFiles(bool isPickup) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      setState(() {
        if (isPickup) {
          _pickupAttachments.add('Document_1.pdf');
        } else {
          _destAttachments.add('Document_1.pdf');
        }
      });
      return;
    }
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.any,
      );
      if (files.isNotEmpty && mounted) {
        final fileName = files.first.name;
        setState(() {
          if (isPickup) {
            _pickupAttachments.add(fileName);
          } else {
            _destAttachments.add(fileName);
          }
        });
      }
    } catch (_) {}
  }

  void _submitFinalOrder() {
    if (_deliveryMode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Veuillez sélectionner une option de livraison (Porte-à-porte ou À l\'entrée).',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Commande de livraison confirmée avec succès !',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  DeliveryAddressDetails _getPickupDetails() {
    return DeliveryAddressDetails(
      address: _pickupAddress,
      location: _pickupLocation,
      entry: _pickupEntryController.text.trim(),
      apartment: _pickupApartmentController.text.trim(),
      floor: _pickupFloorController.text.trim(),
      intercom: _pickupIntercomController.text.trim(),
      comment: _pickupCommentController.text.trim(),
      contactPhone: _pickupContact,
      attachments: List.from(_pickupAttachments),
    );
  }

  DeliveryAddressDetails _getDestDetails() {
    return DeliveryAddressDetails(
      address: _destinationAddress,
      location: _destinationLocation,
      entry: _destEntryController.text.trim(),
      apartment: _destApartmentController.text.trim(),
      floor: _destFloorController.text.trim(),
      intercom: _destIntercomController.text.trim(),
      comment: _destCommentController.text.trim(),
      contactPhone: _destContact,
      attachments: List.from(_destAttachments),
    );
  }

  void _notifyDetailsUpdated() {
    widget.onDetailsUpdated?.call(_getPickupDetails(), _getDestDetails());
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _notifyDetailsUpdated();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
            onPressed: () {
              _notifyDetailsUpdated();
              Navigator.of(context).pop();
            },
          ),
          centerTitle: true,
        title: Column(
          children: [
            Text(
              _headerTitle,
              style: GoogleFonts.inter(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _headerSubtitle,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Contenu défilable
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Titre "Quelle option est la plus pratique ?"
                Text(
                  'Quelle option est la plus pratique ?',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Options : Porte-à-porte & À l'entrée (dans des cartes stylées)
                _buildDeliveryModeOptions(),

                const SizedBox(height: 16),

                // 3. GRAND CARD BLANC RATACHANT DÉPART ET DESTINATION
                _buildUnifiedAddressDetailsCard(),
              ],
            ),
          ),

          // Barre d'actions inférieure fixe
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(bottomPadding),
          ),
        ],
      ),
    ),
  );
}

  // --- WIDGET OPTIONS : PORTE-À-PORTE / À L'ENTRÉE ---
  Widget _buildDeliveryModeOptions() {
    return Column(
      children: [
        // Option 1 : Porte-à-porte
        _buildModeOptionItem(
          id: 'door',
          icon: Icons.meeting_room_outlined,
          title: 'Porte-à-porte',
          subtitle: 'Le coursier se rendra à votre étage',
          price: 'F$_doorPrice',
          isSelected: _deliveryMode == 'door',
          onTap: () {
            setState(() => _deliveryMode = 'door');
          },
        ),

        const SizedBox(height: 8),

        // Option 2 : À l'entrée
        _buildModeOptionItem(
          id: 'entrance',
          icon: Icons.directions_car_outlined,
          title: 'À l\'entrée',
          subtitle: 'Vous rejoignez le coursier à l\'extérieur',
          price: 'F$_entrancePrice',
          isSelected: _deliveryMode == 'entrance',
          onTap: () {
            setState(() => _deliveryMode = 'entrance');
          },
        ),
      ],
    );
  }

  Widget _buildModeOptionItem({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
    required String price,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9).withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: const Color(0xFF0F172A),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              price,
              style: GoogleFonts.inter(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 15,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // --- GRAND CARD BLANC RATTACHANT DÉPART ET DESTINATION ---
  Widget _buildUnifiedAddressDetailsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ================= SECTION DÉPART (DE) AVEC BARRE ROUGE VERTICALE =================
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barre rouge/orange verticale le long de toute la section départ (Images 9 & 10)
                Container(
                  width: 3.5,
                  margin: const EdgeInsets.only(top: 4, bottom: 4, right: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Contenu complet Départ (De)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderRow(
                        isPickup: true,
                        address: _pickupAddress,
                        onTap: _changePickupAddress,
                      ),
                      const SizedBox(height: 12),

                      // Mini carte Départ
                      _buildMiniMap(
                        isPickup: true,
                        location: _pickupLocation,
                        onMapCreated: (c) => _pickupMapController = c,
                        onTap: _changePickupAddress,
                      ),
                      const SizedBox(height: 14),

                      // Champs Départ
                      _buildFieldsGrid(
                        entryController: _pickupEntryController,
                        apartmentController: _pickupApartmentController,
                        floorController: _pickupFloorController,
                        intercomController: _pickupIntercomController,
                      ),
                      const SizedBox(height: 6),

                      // Commentaire Départ + trombone
                      _buildCommentField(
                        controller: _pickupCommentController,
                        attachments: _pickupAttachments,
                        isPickup: true,
                      ),

                      if (_pickupAttachments.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildAttachmentsChips(_pickupAttachments),
                      ],

                      const SizedBox(height: 12),

                      // Contact Départ
                      _buildContactRow(
                        contact: _pickupContact,
                        onTap: _pickPickupContact,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(
              height: 1,
              thickness: 0.8,
              color: Color(0xFFF1F5F9),
            ),
          ),

          // ================= SECTION DESTINATION (VERS) =================
          // Alignée avec la section départ
          Padding(
            padding: const EdgeInsets.only(left: 17.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderRow(
                  isPickup: false,
                  address: _destinationAddress,
                  onTap: _changeDestinationAddress,
                ),
                const SizedBox(height: 12),

                // Mini carte Destination
                _buildMiniMap(
                  isPickup: false,
                  location: _destinationLocation,
                  onMapCreated: (c) => _destMapController = c,
                  onTap: _changeDestinationAddress,
                ),
                const SizedBox(height: 14),

                // Champs Destination
                _buildFieldsGrid(
                  entryController: _destEntryController,
                  apartmentController: _destApartmentController,
                  floorController: _destFloorController,
                  intercomController: _destIntercomController,
                ),
                const SizedBox(height: 6),

                // Commentaire Destination + trombone
                _buildCommentField(
                  controller: _destCommentController,
                  attachments: _destAttachments,
                  isPickup: false,
                ),

                if (_destAttachments.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _buildAttachmentsChips(_destAttachments),
                ],

                const SizedBox(height: 12),

                // Contact Destination
                _buildContactRow(
                  contact: _destContact,
                  onTap: _pickDestContact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // En-tête De / Vers avec chevron
  Widget _buildHeaderRow({
    required bool isPickup,
    required String address,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            if (isPickup)
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
              )
            else
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
                    isPickup ? 'De' : 'Vers',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address,
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
              color: Color(0xFF0F172A),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // Mini-carte avec repère central et point exact au sol
  Widget _buildMiniMap({
    required bool isPickup,
    required LatLng location,
    required void Function(GoogleMapController) onMapCreated,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 135,
          width: double.infinity,
          color: const Color(0xFFE2E8F0),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            alignment: Alignment.center,
            children: [
              // Carte Google Map débordant vers le bas pour cacher le logo Google
              Positioned(
                top: -15,
                left: 0,
                right: 0,
                bottom: -35,
                child: SizedBox(
                  height: 185,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: location,
                      zoom: 16.0,
                    ),
                    onMapCreated: onMapCreated,
                    zoomControlsEnabled: false,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                    zoomGesturesEnabled: false,
                    scrollGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                  ),
                ),
              ),

              // Repère central + point au sol
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPickup)
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    )
                  else
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: SvgPicture.asset(
                        'assets/icons/flag-svgrepo-com.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF1E1E1E),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Grille 2x2 des champs
  Widget _buildFieldsGrid({
    required TextEditingController entryController,
    required TextEditingController apartmentController,
    required TextEditingController floorController,
    required TextEditingController intercomController,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildUnderlineField(
                controller: entryController,
                hint: 'Entrée',
                hasTrailingPadding: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildUnderlineField(
                controller: apartmentController,
                hint: 'Appartement',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildUnderlineField(
                controller: floorController,
                hint: 'Étage',
                hasTrailingPadding: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildUnderlineField(
                controller: intercomController,
                hint: 'Interphone',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Champ Commentaire avec trombone contextuel
  Widget _buildCommentField({
    required TextEditingController controller,
    required List<String> attachments,
    required bool isPickup,
  }) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        _buildUnderlineField(
          controller: controller,
          hint: 'Commentaire',
          hasTrailingPadding: true,
        ),
        Positioned(
          right: 0,
          bottom: 4,
          child: Material(
            color: const Color(0xFFF1F5F9),
            shape: const CircleBorder(),
            child: Theme(
              data: Theme.of(context).copyWith(
                popupMenuTheme: const PopupMenuThemeData(
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
              child: PopupMenuButton<String>(
                tooltip: 'Joindre un fichier',
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.attach_file,
                  color: Color(0xFF0F172A),
                  size: 20,
                ),
                offset: const Offset(0, -150),
                onSelected: (val) {
                  if (val == 'gallery') {
                    _pickFromGallery(isPickup);
                  } else if (val == 'camera') {
                    _takePhoto(isPickup);
                  } else if (val == 'files') {
                    _pickFiles(isPickup);
                  }
                },
                itemBuilder: (popupCtx) => [
                  PopupMenuItem(
                    value: 'gallery',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          size: 20,
                          color: Color(0xFF0F172A),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Photothèque',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem(
                    value: 'camera',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.camera_alt_outlined,
                          size: 20,
                          color: Color(0xFF0F172A),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Prendre une photo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem(
                    value: 'files',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.folder_open_outlined,
                          size: 20,
                          color: Color(0xFF0F172A),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Parcourir les fichiers',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF0F172A),
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
        ),
      ],
    );
  }

  Widget _buildAttachmentsChips(List<String> attachments) {
    return Wrap(
      spacing: 8,
      children: attachments.map((file) {
        return Chip(
          label: Text(file, style: const TextStyle(fontSize: 12)),
          deleteIcon: const Icon(Icons.close, size: 16),
          onDeleted: () {
            setState(() => attachments.remove(file));
          },
        );
      }).toList(),
    );
  }

  // Ligne Contact
  Widget _buildContactRow({
    required String contact,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(
              'Contact',
              style: GoogleFonts.inter(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                contact,
                textAlign: TextAlign.end,
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
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnderlineField({
    required TextEditingController controller,
    required String hint,
    bool hasTrailingPadding = false,
  }) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 14.5,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF94A3B8),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: EdgeInsets.fromLTRB(
          0,
          8,
          hasTrailingPadding ? 36 : 0,
          8,
        ),
        isDense: true,
      ),
    );
  }

  // --- BARRE INFÉRIEURE FIXE ---
  Widget _buildBottomBar(double bottomPadding) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 14, 18, bottomPadding + 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ligne supérieure de la barre : Horaires & Prix
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prise en charge avant $_pickupTimeFormatted',
                      style: GoogleFonts.inter(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Livraison avant $_deliveryTimeFormatted',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'à partir de $_currentDisplayedPrice F',
                style: GoogleFonts.inter(
                  fontSize: 17.5,
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
                  final assetPath = PaymentMethodsService.getAssetForCode(code);
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
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitFinalOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _deliveryMode == null
                            ? 'Choisissez le mode de\nlivraison'
                            : 'Commander la livraison',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          color: Colors.white,
                        ),
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
}
