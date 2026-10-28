import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/pages/pickup_map_location_picker_page.dart';
import 'package:seddo/features/saved_places/data/models/saved_place_model.dart';
import 'package:seddo/services/places_service.dart';

/// Modal moderne, épuré et apaisant pour enregistrer ou modifier un lieu favori.
/// Sans surcharge visuelle ni sélection d'icônes multicolores.
class AddSavedPlaceSheet extends StatefulWidget {
  final SavedPlaceModel? initialPlace;
  final PlacesService placesService;
  final LatLng? currentUserLocation;

  const AddSavedPlaceSheet({
    super.key,
    this.initialPlace,
    required this.placesService,
    this.currentUserLocation,
  });

  static Future<SavedPlaceModel?> show(
    BuildContext context, {
    SavedPlaceModel? initialPlace,
    required PlacesService placesService,
    LatLng? currentUserLocation,
  }) {
    return showModalBottomSheet<SavedPlaceModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => AddSavedPlaceSheet(
        initialPlace: initialPlace,
        placesService: placesService,
        currentUserLocation: currentUserLocation,
      ),
    );
  }

  @override
  State<AddSavedPlaceSheet> createState() => _AddSavedPlaceSheetState();
}

class _AddSavedPlaceSheetState extends State<AddSavedPlaceSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String _selectedAddress = '';
  double? _latitude;
  double? _longitude;

  bool _isLoading = false;
  Timer? _searchDebounce;
  List<PlaceSuggestion> _autocompleteSuggestions = [];

  final List<String> _quickNameSuggestions = [
    'Maison',
    'Travail',
    'Bureau',
    'Chez Maman',
    'Salle de sport',
    'Aéroport',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPlace != null) {
      final p = widget.initialPlace!;
      _nameController.text = p.name;
      _selectedAddress = p.address;
      _latitude = p.latitude;
      _longitude = p.longitude;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _useCurrentPosition() async {
    setState(() => _isLoading = true);
    try {
      final currentPlace = await widget.placesService.getCurrentPlace(
        fallbackLocation: widget.currentUserLocation,
      );

      if (currentPlace != null && mounted) {
        setState(() {
          _selectedAddress = currentPlace.fullAddress;
          _latitude = currentPlace.latitude;
          _longitude = currentPlace.longitude;
          if (_nameController.text.trim().isEmpty) {
            _nameController.text = currentPlace.mainText;
          }
          _isLoading = false;
          _autocompleteSuggestions = [];
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickOnMap() async {
    final LatLng? initial = (_latitude != null && _longitude != null)
        ? LatLng(_latitude!, _longitude!)
        : widget.currentUserLocation;

    final PlaceSearchResult? result =
        await Navigator.of(context).push<PlaceSearchResult>(
      SlideRightToLeftRoute(
        page: PickupMapLocationPickerPage(
          initialLocation: initial ?? const LatLng(14.6937, -17.4440),
          placesService: widget.placesService,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedAddress = result.fullAddress;
        _latitude = result.latitude;
        _longitude = result.longitude;
        if (_nameController.text.trim().isEmpty) {
          _nameController.text = result.mainText;
        }
        _autocompleteSuggestions = [];
      });
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() => _autocompleteSuggestions = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await widget.placesService.autocomplete(clean);
      if (mounted) {
        setState(() => _autocompleteSuggestions = results);
      }
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    setState(() => _isLoading = true);
    try {
      if (suggestion.latitude != null && suggestion.longitude != null) {
        setState(() {
          _selectedAddress = suggestion.description;
          _latitude = suggestion.latitude;
          _longitude = suggestion.longitude;
          if (_nameController.text.trim().isEmpty) {
            _nameController.text = suggestion.mainText ?? suggestion.description;
          }
          _searchController.clear();
          _autocompleteSuggestions = [];
          _isLoading = false;
        });
        return;
      }

      final details = await widget.placesService.details(suggestion.placeId);
      if (mounted) {
        setState(() {
          _selectedAddress = details.address.isNotEmpty ? details.address : suggestion.description;
          _latitude = details.lat;
          _longitude = details.lng;
          if (_nameController.text.trim().isEmpty) {
            _nameController.text = suggestion.mainText ?? suggestion.description;
          }
          _searchController.clear();
          _autocompleteSuggestions = [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty || _latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez donner un nom et sélectionner une adresse'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final kind = SavedPlaceModel.kindFromIconAndName(
      iconType: 'star',
      name: name,
    );
    final iconType = SavedPlaceModel.iconTypeFromKindAndLabel(
      kind: kind,
      label: name,
    );

    final place = SavedPlaceModel(
      id: widget.initialPlace?.id.isNotEmpty == true
          ? widget.initialPlace!.id
          : const Uuid().v4(),
      name: name,
      address: _selectedAddress.isNotEmpty ? _selectedAddress : 'Dakar, Sénégal',
      latitude: _latitude!,
      longitude: _longitude!,
      iconType: iconType,
      kind: kind,
      createdAt: widget.initialPlace?.createdAt ?? DateTime.now(),
    );

    Navigator.of(context).pop(place);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final systemBottomPadding = MediaQuery.of(context).padding.bottom;
    final isEditing = widget.initialPlace != null && widget.initialPlace!.id.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          bottomInset > 0 ? bottomInset + 16 : systemBottomPadding + 20,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Barre de glissement
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppColors.dragHandle,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. En-tête : Titre & Fermeture
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Modifier le lieu' : 'Enregistrer ce lieu',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Retrouvez facilement cette adresse dans vos favoris',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 3. Carte de l'adresse sélectionnée
              Text(
                'Adresse',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedAddress.isNotEmpty
                        ? AppColors.primary.withValues(alpha: 0.25)
                        : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _selectedAddress.isNotEmpty
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: SvgPicture.asset(
                        'assets/icons/location.svg',
                        width: 18,
                        height: 18,
                        colorFilter: ColorFilter.mode(
                          _selectedAddress.isNotEmpty
                              ? AppColors.primary
                              : const Color(0xFF9CA3AF),
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
                            _selectedAddress.isNotEmpty
                                ? _selectedAddress
                                : 'Aucune adresse sélectionnée',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: _selectedAddress.isNotEmpty
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _selectedAddress.isNotEmpty
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_latitude != null && _longitude != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Coordonnées : ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Boutons d'action pour changer ou ajuster l'adresse
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _useCurrentPosition,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.my_location_rounded,
                              size: 15,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Position actuelle',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: _pickOnMap,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                              'assets/icons/map-svgrepo-com.svg',
                              width: 15,
                              height: 15,
                              colorFilter: const ColorFilter.mode(
                                AppColors.primary,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Sur la carte',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Recherche textuelle facultative d'adresse
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F7F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/search-magnifying-glass-svgrepo-com.svg',
                      width: 15,
                      height: 15,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF9CA3AF),
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Ou rechercher une autre adresse...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9CA3AF),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 11),
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _autocompleteSuggestions = []);
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                  ],
                ),
              ),

              // Suggestions de recherche
              if (_autocompleteSuggestions.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _autocompleteSuggestions.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      color: Color(0xFFF3F4F6),
                    ),
                    itemBuilder: (context, idx) {
                      final s = _autocompleteSuggestions[idx];
                      return InkWell(
                        onTap: () => _selectSuggestion(s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.mainText ?? s.description,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (s.secondaryText != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  s.secondaryText!,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // 4. Nom du lieu
              Text(
                'Nom du lieu',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _nameController,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Ex: Maison, Bureau, Chez un ami...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF9CA3AF),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Suggestions rapides de noms (puces sobres et douces)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _quickNameSuggestions.map((name) {
                    final isSelected = _nameController.text.trim() == name;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _nameController.text = name;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected
                                  ? AppColors.primary
                                  : const Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // 5. Bouton principal "Enregistrer"
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _save,
                  child: Text(
                    isEditing ? 'Mettre à jour' : 'Enregistrer',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
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
