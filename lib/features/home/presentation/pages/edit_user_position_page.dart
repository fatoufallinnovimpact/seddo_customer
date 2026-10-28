import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/pages/pickup_map_location_picker_page.dart';
import 'package:seddo/features/saved_places/presentation/pages/saved_places_page.dart';
import 'package:seddo/services/places_service.dart';

/// Page élégante et moderne pour modifier l'adresse de prise en charge / départ :
/// - Champ de recherche textuelle avec autocomplétion instantanée
/// - Option dédiée "Choisir sur la carte" (Prendre sur la carte avec marqueur interactif)
/// - Option "Ma position actuelle" (GPS en temps réel)
/// - Option "Lieux enregistrés" (Favoris)
/// - Liste des suggestions Dakar / résultats de recherche en direct
class EditUserPositionPage extends StatefulWidget {
  final LatLng currentLocation;
  final String currentMainText;
  final String currentSecondaryText;
  final PlacesService? placesService;

  const EditUserPositionPage({
    super.key,
    required this.currentLocation,
    required this.currentMainText,
    required this.currentSecondaryText,
    this.placesService,
  });

  @override
  State<EditUserPositionPage> createState() => _EditUserPositionPageState();
}

class _EditUserPositionPageState extends State<EditUserPositionPage> {
  late final PlacesService _placesService;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounceTimer;
  List<PlaceSuggestion> _suggestions = [];
  bool _isLoading = false;
  bool _isLoadingGps = false;

  @override
  void initState() {
    super.initState();
    _placesService = widget.placesService ?? PlacesService();
    _searchController.addListener(_onSearchChanged);

    // Charger les suggestions initiales
    _loadInitialSuggestions();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialSuggestions() async {
    setState(() => _isLoading = true);
    final results = await _placesService.autocomplete('');
    if (mounted) {
      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final results = await _placesService.autocomplete(query);
    if (mounted) {
      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
    }
  }

  /// Ouvre la carte plein écran avec le marqueur animé ("Prendre sur la carte")
  Future<void> _chooseOnMap() async {
    _focusNode.unfocus();

    final result = await Navigator.of(context).push<PlaceSearchResult>(
      SlideRightToLeftRoute(
        page: PickupMapLocationPickerPage(
          initialLocation: widget.currentLocation,
          initialMainText: widget.currentMainText,
          initialSecondaryText: widget.currentSecondaryText,
          placesService: _placesService,
        ),
      ),
    );

    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  /// Récupère la position GPS réelle actuelle
  Future<void> _useCurrentGpsPosition() async {
    _focusNode.unfocus();
    setState(() => _isLoadingGps = true);

    try {
      final currentPlace = await _placesService.getCurrentPlace(
        fallbackLocation: widget.currentLocation,
      );

      if (currentPlace != null && mounted) {
        Navigator.of(context).pop(currentPlace);
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoadingGps = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de récupérer la position GPS'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Ouvre la page des lieux enregistrés
  Future<void> _openSavedPlaces() async {
    _focusNode.unfocus();

    final saved = await Navigator.of(context).push<PlaceSearchResult>(
      SlideRightToLeftRoute(
        page: SavedPlacesPage(
          placesService: _placesService,
          currentUserLocation: widget.currentLocation,
          isSelectionMode: true,
        ),
      ),
    );

    if (saved != null && mounted) {
      Navigator.of(context).pop(saved);
    }
  }

  /// Sélectionne une suggestion d'adresse
  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    _focusNode.unfocus();
    setState(() => _isLoading = true);

    try {
      // Si la suggestion a déjà des coordonnées précises
      if (suggestion.latitude != null && suggestion.longitude != null) {
        final result = PlaceSearchResult(
          id: suggestion.placeId,
          mainText: suggestion.mainText ?? suggestion.description,
          secondaryText: suggestion.secondaryText ?? 'Dakar, Sénégal',
          fullAddress: suggestion.description,
          latitude: suggestion.latitude!,
          longitude: suggestion.longitude!,
          category: 'pickup',
        );
        if (mounted) {
          Navigator.of(context).pop(result);
        }
        return;
      }

      // Sinon interroge les détails de Google Places
      final details = await _placesService.details(suggestion.placeId);
      if (!mounted) return;

      final result = PlaceSearchResult(
        id: suggestion.placeId,
        mainText: suggestion.mainText ?? suggestion.description,
        secondaryText: suggestion.secondaryText ?? 'Dakar, Sénégal',
        fullAddress: details.address.isNotEmpty ? details.address : suggestion.description,
        latitude: details.lat,
        longitude: details.lng,
        category: 'pickup',
      );

      Navigator.of(context).pop(result);
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Text(
          'Modifier votre position',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Champ de saisie de recherche
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F7F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  autofocus: false,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une adresse ou un lieu...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SvgPicture.asset(
                        'assets/icons/search-magnifying-glass-svgrepo-com.svg',
                        width: 18,
                        height: 18,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF6B7280),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.cancel_rounded,
                              size: 18,
                              color: Color(0xFF9CA3AF),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _loadInitialSuggestions();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 8,
                    ),
                  ),
                ),
              ),
            ),

            // 2. Options d'action rapide (Choisir sur la carte, GPS, Favoris)
            if (!isSearching) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Option 1 : "Choisir sur la carte" (Prendre sur la carte)
                    _buildQuickActionCard(
                      iconWidget: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          'assets/icons/map-svgrepo-com.svg',
                          width: 22,
                          height: 22,
                          colorFilter: const ColorFilter.mode(
                            AppColors.primary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      title: 'Choisir sur la carte',
                      subtitle: 'Déplacer le repère vers votre position exacte',
                      highlighted: true,
                      onTap: _chooseOnMap,
                    ),

                    const SizedBox(height: 8),

                    // Option 2 : "Position actuelle" (GPS)
                    _buildQuickActionCard(
                      iconWidget: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: _isLoadingGps
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF3B82F6),
                                ),
                              )
                            : const Icon(
                                Icons.my_location_rounded,
                                color: Color(0xFF3B82F6),
                                size: 22,
                              ),
                      ),
                      title: 'Ma position actuelle',
                      subtitle: 'Utiliser le signal GPS de votre appareil',
                      onTap: _useCurrentGpsPosition,
                    ),

                    const SizedBox(height: 8),

                    // Option 3 : "Lieux enregistrés"
                    _buildQuickActionCard(
                      iconWidget: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          'assets/icons/star-svgrepo-com.svg',
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFFD97706),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      title: 'Lieux enregistrés',
                      subtitle: 'Maison, Travail et favoris',
                      onTap: _openSavedPlaces,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
            ],

            // 3. Titre de section suggestions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Text(
                    isSearching ? 'Résultats de recherche' : 'Adresses suggérées',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (_isLoading) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 4. Liste des résultats / suggestions
            Expanded(
              child: _suggestions.isEmpty && !_isLoading
                  ? Center(
                      child: Text(
                        'Aucune adresse trouvée',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        color: Color(0xFFF3F4F6),
                      ),
                      itemBuilder: (context, index) {
                        final item = _suggestions[index];
                        final main = item.mainText ?? item.description;
                        final secondary = item.secondaryText ?? '';

                        return InkWell(
                          onTap: () => _selectSuggestion(item),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: SvgPicture.asset(
                                    'assets/icons/location.svg',
                                    width: 18,
                                    height: 18,
                                    colorFilter: const ColorFilter.mode(
                                      Color(0xFF4B5563),
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
                                        main,
                                        style: GoogleFonts.inter(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (secondary.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          secondary,
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required Widget iconWidget,
    required String title,
    required String subtitle,
    bool highlighted = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: highlighted
              ? AppColors.primary.withValues(alpha: 0.05)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlighted
                ? AppColors.primary.withValues(alpha: 0.25)
                : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            iconWidget,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: highlighted ? AppColors.primary : const Color(0xFF9CA3AF),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
