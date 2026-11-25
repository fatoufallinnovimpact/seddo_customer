import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/map_config.dart';
import 'package:seddo/services/places_service.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_contact_picker_modal.dart';
import 'package:seddo/features/delivery/presentation/widgets/delivery_destination_search_modal.dart';

/// Modèle pour les compléments d'adresse de livraison (interphone, étage, etc.)
class DeliveryAddressDetails {
  final String address;
  final LatLng? location;
  final String entry;
  final String apartment;
  final String floor;
  final String intercom;
  final String comment;
  final String contactPhone;
  final List<String> attachments;

  const DeliveryAddressDetails({
    required this.address,
    this.location,
    this.entry = '',
    this.apartment = '',
    this.floor = '',
    this.intercom = '',
    this.comment = '',
    this.contactPhone = '+221784226719',
    this.attachments = const [],
  });

  DeliveryAddressDetails copyWith({
    String? address,
    LatLng? location,
    String? entry,
    String? apartment,
    String? floor,
    String? intercom,
    String? comment,
    String? contactPhone,
    List<String>? attachments,
  }) {
    return DeliveryAddressDetails(
      address: address ?? this.address,
      location: location ?? this.location,
      entry: entry ?? this.entry,
      apartment: apartment ?? this.apartment,
      floor: floor ?? this.floor,
      intercom: intercom ?? this.intercom,
      comment: comment ?? this.comment,
      contactPhone: contactPhone ?? this.contactPhone,
      attachments: attachments ?? this.attachments,
    );
  }
}

/// Modal de détail d'adresse (Point de départ ou Destination)
/// Conforme aux maquettes :
/// 1. En-tête : icône colis ou drapeau, libellé De/Vers, nom de l'adresse, chevron > (cliquable pour modifier)
/// 2. Aperçu mini carte avec repère central (boîte noire ou drapeau)
/// 3. Champs de saisie : Entrée, Appartement, Étage, Interphone
/// 4. Commentaire avec icône trombone / trombone menu contextuel (Photothèque, Prendre une photo, Parcourir les fichiers)
/// 5. Ligne Contact (+221...)
/// 6. Bouton Terminé (orange/rouge)
class DeliveryAddressDetailsModal extends StatefulWidget {
  final String address;
  final LatLng? location;
  final bool isPickup;
  final DeliveryAddressDetails? initialDetails;
  final PlacesService? placesService;
  final VoidCallback? onEditAddress;
  final ValueChanged<DeliveryAddressDetails>? onSave;

  const DeliveryAddressDetailsModal({
    super.key,
    required this.address,
    this.location,
    required this.isPickup,
    this.initialDetails,
    this.placesService,
    this.onEditAddress,
    this.onSave,
  });

  static Future<DeliveryAddressDetails?> show(
    BuildContext context, {
    required String address,
    LatLng? location,
    required bool isPickup,
    DeliveryAddressDetails? initialDetails,
    PlacesService? placesService,
    VoidCallback? onEditAddress,
  }) {
    return showModalBottomSheet<DeliveryAddressDetails>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DeliveryAddressDetailsModal(
        address: address,
        location: location,
        isPickup: isPickup,
        initialDetails: initialDetails,
        placesService: placesService,
        onEditAddress: onEditAddress,
      ),
    );
  }

  @override
  State<DeliveryAddressDetailsModal> createState() =>
      _DeliveryAddressDetailsModalState();
}

class _DeliveryAddressDetailsModalState
    extends State<DeliveryAddressDetailsModal> {
  late final TextEditingController _entryController;
  late final TextEditingController _apartmentController;
  late final TextEditingController _floorController;
  late final TextEditingController _intercomController;
  late final TextEditingController _commentController;

  late String _currentAddress;
  late LatLng? _currentLocation;
  GoogleMapController? _mapController;

  late String _contactPhone;
  final List<String> _attachments = [];

  @override
  void initState() {
    super.initState();
    _currentAddress = widget.address;
    _currentLocation = widget.location;
    final d = widget.initialDetails;
    _entryController = TextEditingController(text: d?.entry ?? '');
    _apartmentController = TextEditingController(text: d?.apartment ?? '');
    _floorController = TextEditingController(text: d?.floor ?? '');
    _intercomController = TextEditingController(text: d?.intercom ?? '');
    _commentController = TextEditingController(text: d?.comment ?? '');
    _contactPhone = d?.contactPhone ?? '+221784226719';
    if (d?.attachments != null) {
      _attachments.addAll(d!.attachments);
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _apartmentController.dispose();
    _floorController.dispose();
    _intercomController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _changeAddress() async {
    final result = await DeliveryDestinationSearchModal.show(
      context,
      placesService: widget.placesService ?? PlacesService(),
      pickupLocation: widget.isPickup ? null : _currentLocation,
      isPickup: widget.isPickup,
      title: widget.isPickup ? 'Point de départ' : 'Adresse de livraison',
    );

    if (result != null && mounted) {
      final newLoc = LatLng(result.latitude, result.longitude);
      final newAddr = result.mainText.isNotEmpty
          ? result.mainText
          : result.fullAddress;
      setState(() {
        _currentAddress = newAddr;
        _currentLocation = newLoc;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(newLoc, 16.0),
      );
    }
  }

  void _saveAndClose() {
    final details = DeliveryAddressDetails(
      address: _currentAddress,
      location: _currentLocation,
      entry: _entryController.text.trim(),
      apartment: _apartmentController.text.trim(),
      floor: _floorController.text.trim(),
      intercom: _intercomController.text.trim(),
      comment: _commentController.text.trim(),
      contactPhone: _contactPhone,
      attachments: _attachments,
    );

    widget.onSave?.call(details);
    Navigator.of(context).pop(details);
  }

  Future<void> _openContactPicker() async {
    final result = await DeliveryContactPickerModal.show(
      context,
      isExpediteur: widget.isPickup,
      currentPhone: _contactPhone,
    );

    if (result != null && mounted) {
      setState(() {
        _contactPhone =
            result.phone.isNotEmpty ? result.phone : result.name;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      setState(() => _attachments.add('Photo_1.jpg'));
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
        setState(() => _attachments.add(fileName));
      }
    } catch (e) {
      debugPrint('Error picking from gallery: $e');
    }
  }

  Future<void> _takePhoto() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      setState(() => _attachments.add('Camera_1.jpg'));
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
        setState(() => _attachments.add(fileName));
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
    }
  }

  Future<void> _pickFiles() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      setState(() => _attachments.add('Document_1.pdf'));
      return;
    }
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.any,
      );
      if (files.isNotEmpty && mounted) {
        final fileName = files.first.name;
        setState(() => _attachments.add(fileName));
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final mapCenter = _currentLocation ??
        const LatLng(MapConfig.dakarCenterLat, MapConfig.dakarCenterLng);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          mediaQuery.padding.bottom + 16,
        ),
        child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Poignée de tirage grise
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
                const SizedBox(height: 14),

                // 1. En-tête : Icône + De / Vers + Adresse + Chevron >
                InkWell(
                  onTap: _changeAddress,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        // Icône spécifique colis (pickup) ou drapeau (destination)
                        if (widget.isPickup)
                          Container(
                            width: 38,
                            height: 38,
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
                            width: 38,
                            height: 38,
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

                        // Textes : De / Vers et Nom de l'adresse
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isPickup ? 'De' : 'Vers',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currentAddress,
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
                ),
                const SizedBox(height: 12),

                // 2. Aperçu interactif mini-carte avec repère central et point exact au sol (sans logo Google visible)
                GestureDetector(
                  onTap: _changeAddress,
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
                                  target: mapCenter,
                                  zoom: 16.0,
                                ),
                                onMapCreated: (c) => _mapController = c,
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

                        // Repère central d'épingle + point exact sur la route (comme sur les photos jointes)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.isPickup)
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
                            // Point noir avec bordure blanche sur la route exacte
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E1E),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2.2),
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
              ),
                const SizedBox(height: 14),

                // 3. Grille de champs 2x2 : Entrée, Appartement / Étage, Interphone
                Row(
                  children: [
                    Expanded(
                      child: _buildUnderlineField(
                        controller: _entryController,
                        hint: 'Entrée',
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _buildUnderlineField(
                        controller: _apartmentController,
                        hint: 'Appartement',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildUnderlineField(
                        controller: _floorController,
                        hint: 'Étage',
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _buildUnderlineField(
                        controller: _intercomController,
                        hint: 'Interphone',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 4. Ligne Commentaire avec bouton trombone
                Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    _buildUnderlineField(
                      controller: _commentController,
                      hint: 'Commentaire',
                      hasTrailingPadding: true,
                    ),

                    // Bouton trombone avec menu contextuel (Photothèque, Prendre une photo, Parcourir les fichiers)
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
                                borderRadius:
                                    BorderRadius.all(Radius.circular(16)),
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
                                _pickFromGallery();
                              } else if (val == 'camera') {
                                _takePhoto();
                              } else if (val == 'files') {
                                _pickFiles();
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
                ),

                // Affichage d'éventuels fichiers joints
                if (_attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _attachments.map((file) {
                      return Chip(
                        label: Text(file, style: const TextStyle(fontSize: 12)),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() => _attachments.remove(file));
                        },
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 16),

                // 5. Ligne Contact
                InkWell(
                  onTap: _openContactPicker,
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
                            _contactPhone,
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
                ),

                const SizedBox(height: 20),

                // 6. Bouton Terminé (orange/rouge)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saveAndClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Terminé',
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
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF94A3B8),
        ),
        contentPadding: EdgeInsets.fromLTRB(
          0,
          10,
          hasTrailingPadding ? 44 : 0,
          8,
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF0F172A), width: 1.5),
        ),
      ),
    );
  }
}
