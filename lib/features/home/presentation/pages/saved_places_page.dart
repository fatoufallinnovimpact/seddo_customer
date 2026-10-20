import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/domain/models/saved_place_model.dart';
import 'package:seddo/features/home/presentation/widgets/add_saved_place_sheet.dart';
import 'package:seddo/services/places_service.dart';
import 'package:seddo/services/saved_places_service.dart';

/// Fullscreen modern page for managing and selecting user saved places
class SavedPlacesPage extends StatefulWidget {
  final PlacesService? placesService;
  final SavedPlacesService? savedPlacesService;
  final LatLng? currentUserLocation;

  const SavedPlacesPage({
    super.key,
    this.placesService,
    this.savedPlacesService,
    this.currentUserLocation,
  });

  @override
  State<SavedPlacesPage> createState() => _SavedPlacesPageState();
}

class _SavedPlacesPageState extends State<SavedPlacesPage> {
  late final PlacesService _placesService;
  late final SavedPlacesService _savedPlacesService;

  List<SavedPlaceModel> _savedPlaces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _placesService = widget.placesService ?? PlacesService();
    _savedPlacesService =
        widget.savedPlacesService ?? SavedPlacesService();
    _loadSavedPlaces();
  }

  Future<void> _loadSavedPlaces() async {
    setState(() => _isLoading = true);
    final places = await _savedPlacesService.getSavedPlaces();
    if (mounted) {
      setState(() {
        _savedPlaces = places;
        _isLoading = false;
      });
    }
  }

  Future<void> _addNewPlace() async {
    final result = await AddSavedPlaceSheet.show(
      context,
      placesService: _placesService,
      currentUserLocation: widget.currentUserLocation,
    );

    if (result != null && mounted) {
      final updated = await _savedPlacesService.addSavedPlace(result);
      setState(() => _savedPlaces = updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('« ${result.name} » a été enregistré !'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _editPlace(SavedPlaceModel place) async {
    final result = await AddSavedPlaceSheet.show(
      context,
      initialPlace: place,
      placesService: _placesService,
      currentUserLocation: widget.currentUserLocation,
    );

    if (result != null && mounted) {
      final updated = await _savedPlacesService.updateSavedPlace(result);
      setState(() => _savedPlaces = updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('« ${result.name} » a été mis à jour !'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deletePlace(SavedPlaceModel place) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Supprimer ce lieu ?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          'Voulez-vous vraiment supprimer « ${place.name} » de vos lieux enregistrés ?',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Annuler',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Supprimer',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final updated = await _savedPlacesService.deleteSavedPlace(place.id);
      setState(() => _savedPlaces = updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('« ${place.name} » a été supprimé.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _selectPlace(SavedPlaceModel place) {
    Navigator.of(context).pop<PlaceSearchResult>(place.toPlaceSearchResult());
  }

  Color _getIconBackgroundColor(String iconType) {
    switch (iconType) {
      case 'home':
        return AppColors.peachContainer;
      case 'work':
        return AppColors.greyContainer;
      case 'airport':
        return AppColors.savedPlaceAirportBg;
      case 'heart':
        return AppColors.savedPlaceHeartBg;
      case 'gym':
        return AppColors.savedPlaceGymBg;
      case 'star':
      default:
        return AppColors.savedPlaceStarBg;
    }
  }

  Widget _buildIcon(String iconType) {
    switch (iconType) {
      case 'home':
        return SvgPicture.asset(
          'assets/icons/home-svgrepo-com.svg',
          width: 20,
          height: 20,
          colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
        );
      case 'work':
        return SvgPicture.asset(
          'assets/icons/work-alt-bag-svgrepo-com.svg',
          width: 20,
          height: 20,
          colorFilter: const ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
        );
      case 'airport':
        return SvgPicture.asset(
          'assets/icons/airplane-svgrepo-com.svg',
          width: AppConstants.iconSizeMd,
          height: AppConstants.iconSizeMd,
          colorFilter: const ColorFilter.mode(AppColors.savedPlaceAirportIcon, BlendMode.srcIn),
        );
      case 'heart':
        return const Icon(
          Icons.favorite_rounded,
          size: AppConstants.iconSizeMd,
          color: AppColors.savedPlaceHeartIcon,
        );
      case 'gym':
        return const Icon(
          Icons.fitness_center_rounded,
          size: AppConstants.iconSizeMd,
          color: AppColors.savedPlaceGymIcon,
        );
      case 'star':
      default:
        return SvgPicture.asset(
          'assets/icons/star-svgrepo-com.svg',
          width: 20,
          height: 20,
          colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
          children: [
            // 1. Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingSm,
              ),
              child: Row(
                children: [
                  Container(
                    width: AppConstants.circularButtonSize,
                    height: AppConstants.circularButtonSize,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowSoftBlack,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingMd),
                  Expanded(
                    child: Text(
                      'Lieux enregistrés',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  // "+ Ajouter" Action Button
                  GestureDetector(
                    onTap: _addNewPlace,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            color: AppColors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Ajouter',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // 2. Banner info card
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.bannerGradientStart, AppColors.bannerGradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: SvgPicture.asset(
                        'assets/icons/star-svgrepo-com.svg',
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          AppColors.primary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vos adresses favorites',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sélectionnez un lieu en 1 clic pour votre départ ou arrivée.',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 3. List of saved places
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _savedPlaces.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                'assets/icons/star-svgrepo-com.svg',
                                width: 48,
                                height: 48,
                                colorFilter: const ColorFilter.mode(
                                  AppColors.textSecondary,
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Aucun lieu enregistré',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ajoutez votre maison, travail ou adresse préférée.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Ajouter un lieu'),
                                onPressed: _addNewPlace,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.spacingMd,
                            vertical: 8,
                          ),
                          itemCount: _savedPlaces.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final place = _savedPlaces[index];

                            return Material(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                onTap: () => _selectPlace(place),
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: AppColors.cardBorder,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Themed Icon circle
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: _getIconBackgroundColor(
                                            place.iconType,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: _buildIcon(place.iconType),
                                      ),
                                      const SizedBox(width: 14),

                                      // Name & Address
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              place.name,
                                              style: GoogleFonts.inter(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              place.address,
                                              style: GoogleFonts.inter(
                                                fontSize: 12.5,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Edit Button
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 19,
                                          color: AppColors.textSecondary,
                                        ),
                                        tooltip: 'Modifier',
                                        onPressed: () => _editPlace(place),
                                      ),

                                      // Delete Button
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 19,
                                          color: AppColors.deleteRed,
                                        ),
                                        tooltip: 'Supprimer',
                                        onPressed: () => _deletePlace(place),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

