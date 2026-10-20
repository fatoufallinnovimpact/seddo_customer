import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/domain/models/saved_place_model.dart';
import 'package:seddo/features/home/presentation/pages/select_on_map_page.dart';
import 'package:seddo/services/places_service.dart';

/// Modern and interactive BottomSheet to create or edit a saved place
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

  String _selectedIconType = 'star';
  String _selectedAddress = '';
  double? _latitude;
  double? _longitude;

  bool _isLoading = false;
  List<PlaceSuggestion> _autocompleteSuggestions = [];

  final List<Map<String, dynamic>> _iconOptions = [
    {'type': 'home', 'label': 'Maison', 'color': AppColors.savedPlaceHomeBg},
    {'type': 'work', 'label': 'Travail', 'color': AppColors.savedPlaceWorkBg},
    {'type': 'star', 'label': 'Favori', 'color': AppColors.savedPlaceStarBg},
    {'type': 'airport', 'label': 'Aéroport', 'color': AppColors.savedPlaceAirportBg},
    {'type': 'heart', 'label': 'Cœur', 'color': AppColors.savedPlaceHeartBg},
    {'type': 'gym', 'label': 'Sport', 'color': AppColors.savedPlaceGymBg},
  ];

  final List<String> _quickNameSuggestions = [
    'Maison',
    'Travail',
    'Salle de sport',
    'Chez Maman',
    'Aéroport',
    'Bureau',
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
      _selectedIconType = p.iconType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
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
          if (_nameController.text.isEmpty) {
            _nameController.text = currentPlace.mainText;
          }
          _isLoading = false;
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
        page: SelectOnMapPage(
          isArrival: true,
          initialLocation: initial,
          placesService: widget.placesService,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedAddress = result.fullAddress;
        _latitude = result.latitude;
        _longitude = result.longitude;
        if (_nameController.text.isEmpty) {
          _nameController.text = result.mainText;
        }
      });
    }
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _autocompleteSuggestions = []);
      return;
    }
    final results = await widget.placesService.autocomplete(query);
    if (mounted) {
      setState(() => _autocompleteSuggestions = results);
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    final details = await widget.placesService.details(suggestion.placeId);
    if (mounted) {
      setState(() {
        _selectedAddress = details.address;
        _latitude = details.lat;
        _longitude = details.lng;
        _autocompleteSuggestions = [];
        _searchController.clear();
        if (_nameController.text.isEmpty) {
          _nameController.text = suggestion.mainText ?? suggestion.description;
        }
      });
    }
  }

  void _onQuickNameTapped(String name) {
    setState(() {
      _nameController.text = name;
      if (name.toLowerCase() == 'maison') {
        _selectedIconType = 'home';
      } else if (name.toLowerCase() == 'travail' ||
          name.toLowerCase() == 'bureau') {
        _selectedIconType = 'work';
      } else if (name.toLowerCase().contains('aéroport')) {
        _selectedIconType = 'airport';
      } else if (name.toLowerCase().contains('sport')) {
        _selectedIconType = 'gym';
      } else {
        _selectedIconType = 'star';
      }
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty || _latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez donner un nom et choisir une adresse'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final place = SavedPlaceModel(
      id: widget.initialPlace?.id ?? const Uuid().v4(),
      name: name,
      address: _selectedAddress.isNotEmpty
          ? _selectedAddress
          : 'Dakar, Sénégal',
      latitude: _latitude!,
      longitude: _longitude!,
      iconType: _selectedIconType,
      createdAt: widget.initialPlace?.createdAt ?? DateTime.now(),
    );

    Navigator.of(context).pop(place);
  }

  Widget _buildIcon(String iconType, {double size = 20}) {
    switch (iconType) {
      case 'home':
        return SvgPicture.asset(
          'assets/icons/home-svgrepo-com.svg',
          width: size,
          height: size,
          colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
        );
      case 'work':
        return SvgPicture.asset(
          'assets/icons/work-alt-bag-svgrepo-com.svg',
          width: size,
          height: size,
          colorFilter: const ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
        );
      case 'airport':
        return SvgPicture.asset(
          'assets/icons/airplane-svgrepo-com.svg',
          width: size,
          height: size,
          colorFilter: const ColorFilter.mode(AppColors.savedPlaceAirportIcon, BlendMode.srcIn),
        );
      case 'heart':
        return Icon(
          Icons.favorite_rounded,
          size: size,
          color: AppColors.savedPlaceHeartIcon,
        );
      case 'gym':
        return Icon(
          Icons.fitness_center_rounded,
          size: size,
          color: AppColors.savedPlaceGymIcon,
        );
      case 'star':
      default:
        return SvgPicture.asset(
          'assets/icons/star-svgrepo-com.svg',
          width: size,
          height: size,
          colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.initialPlace != null;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: AppConstants.circularIconContainerSize,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dragHandle,
                  borderRadius: BorderRadius.circular(AppConstants.radiusXs),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.peachContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    'assets/icons/star-svgrepo-com.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
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
                        isEditing ? 'Modifier le lieu' : 'Enregistrer un lieu',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Retrouvez facilement cette destination',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 1. Name Input
            Text(
              'Nom personnalisé',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: AppColors.fieldBackground,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: AppColors.cardBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _nameController,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Ex: Maison, Chez Maman, Bureau...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Quick Name Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickNameSuggestions.map((name) {
                  final isSelected = _nameController.text.trim() == name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _onQuickNameTapped(name),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.chipBackground,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // 2. Icon Picker
            Text(
              'Icône associée',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _iconOptions.map((opt) {
                final type = opt['type'] as String;
                final bg = opt['color'] as Color;
                final isSelected = _selectedIconType == type;

                return GestureDetector(
                  onTap: () => setState(() => _selectedIconType = type),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: _buildIcon(type, size: 22),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 3. Location / Address Picker Section
            Text(
              'Adresse du lieu',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Selected Address Display Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _selectedAddress.isNotEmpty
                    ? AppColors.addressCardBg
                    : AppColors.fieldBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedAddress.isNotEmpty
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.cardBorder,
                ),
              ),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/location.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      _selectedAddress.isNotEmpty
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      BlendMode.srcIn,
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
                            fontSize: 14,
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
                        if (_latitude != null && _longitude != null)
                          Text(
                            'GPS: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
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

            // Two Location Action Buttons (Position actuelle & Choisir sur la carte)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.my_location_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      'Position actuelle',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _useCurrentPosition,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: SvgPicture.asset(
                      'assets/icons/map-svgrepo-com.svg',
                      width: 16,
                      height: 16,
                      colorFilter: const ColorFilter.mode(
                        AppColors.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                    label: Text(
                      'Sur la carte',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _pickOnMap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Optional: Search address autocomplete input
            Container(
              decoration: BoxDecoration(
                color: AppColors.fieldBackground,
                borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Ou rechercher une adresse...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
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
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),

            if (_autocompleteSuggestions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _autocompleteSuggestions.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final s = _autocompleteSuggestions[idx];
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        s.mainText ?? s.description,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        s.secondaryText ?? '',
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                      onTap: () => _selectSuggestion(s),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 22),

            // Save / Update Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _save,
                child: Text(
                  isEditing ? 'Mettre à jour le lieu' : 'Enregistrer ce lieu',
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
}
