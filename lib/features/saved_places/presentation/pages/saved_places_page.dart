import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/saved_places/data/models/saved_place_model.dart';
import 'package:seddo/features/saved_places/data/services/saved_places_service.dart';
import 'package:seddo/features/saved_places/presentation/widgets/add_saved_place_sheet.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/features/home/domain/bloc/home_bloc.dart';
import 'package:seddo/features/home/presentation/pages/place_search_page.dart';
import 'package:seddo/services/places_service.dart';

/// Fullscreen modern page for managing and selecting user saved places
class SavedPlacesPage extends StatefulWidget {
  final PlacesService? placesService;
  final SavedPlacesService? savedPlacesService;
  final LatLng? currentUserLocation;
  final bool isSelectionMode;

  const SavedPlacesPage({
    super.key,
    this.placesService,
    this.savedPlacesService,
    this.currentUserLocation,
    this.isSelectionMode = false,
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
            content: Text('saved_places.saved_notice'.tr(args: [result.name])),
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
            content: Text('saved_places.updated_notice'.tr(args: [result.name])),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusDialog),
        ),
        title: Text(
          'saved_places.delete_title'.tr(),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: AppConstants.fontXl,
          ),
        ),
        content: Text(
          'saved_places.delete_confirm'.tr(args: [place.name]),
          style: GoogleFonts.inter(
            fontSize: AppConstants.fontMd,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'common.cancel'.tr(),
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
              elevation: AppConstants.elevationNone,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusItem),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'saved_places.delete_action'.tr(),
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
            content: Text('saved_places.deleted_notice'.tr(args: [place.name])),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  LatLng? _getUserLocation() {
    if (widget.currentUserLocation != null) return widget.currentUserLocation;
    try {
      return context.read<HomeBloc>().state.userLocation;
    } catch (_) {
      return null;
    }
  }

  void _selectPlace(SavedPlaceModel place) {
    if (widget.isSelectionMode) {
      Navigator.of(context).pop<PlaceSearchResult>(place.toPlaceSearchResult());
    } else {
      Navigator.of(context).pushReplacement(
        SlideRightToLeftRoute(
          page: PlaceSearchPage(
            placesService: _placesService,
            initialPickup: 'Ma position actuelle',
            initialDestination: place.name,
            initialDestinationResult: place.toPlaceSearchResult(),
            currentUserLocation: _getUserLocation(),
          ),
        ),
      );
    }
  }

  void _showPlaceOptionsMenu(SavedPlaceModel place) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusSheet),
        ),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingUnitXl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: AppConstants.handleWidth,
                    height: AppConstants.handleHeight,
                    decoration: BoxDecoration(
                      color: AppColors.dragHandle,
                      borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: AppConstants.circularPickerSize,
                    height: AppConstants.circularPickerSize,
                    decoration: BoxDecoration(
                      color: _getIconBackgroundColor(place.iconType),
                      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                    ),
                    alignment: Alignment.center,
                    child: _buildIcon(place.iconType),
                  ),
                  title: Text(
                    place.name,
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontLg,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    place.address,
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontSm,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Divider(color: AppColors.divider),
                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.textPrimary,
                    size: AppConstants.iconSizeLg,
                  ),
                  title: Text(
                    'saved_places.edit'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontBase,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    _editPlace(place);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.deleteRed,
                    size: AppConstants.iconSizeLg,
                  ),
                  title: Text(
                    'saved_places.delete_action'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontBase,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deleteRed,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    _deletePlace(place);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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
        return const Icon(
          Icons.home_outlined,
          size: AppConstants.iconSizeXl,
          color: AppColors.primary,
        );
      case 'work':
        return const Icon(
          Icons.work_outline_rounded,
          size: AppConstants.iconSizeLg,
          color: AppColors.textPrimary,
        );
      case 'airport':
        return const Icon(
          Icons.flight_rounded,
          size: AppConstants.iconSizeLg,
          color: AppColors.savedPlaceAirportIcon,
        );
      case 'heart':
        return const Icon(
          Icons.favorite_outline_rounded,
          size: AppConstants.iconSizeLg,
          color: AppColors.savedPlaceHeartIcon,
        );
      case 'gym':
        return const Icon(
          Icons.fitness_center_rounded,
          size: AppConstants.iconSizeLg,
          color: AppColors.savedPlaceGymIcon,
        );
      case 'star':
      default:
        return const Icon(
          Icons.star_outline_rounded,
          size: AppConstants.iconSizeLg,
          color: AppColors.primary,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Top Bar: Back Circle + Two-line Title + "+ Ajouter" Capsule
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                  vertical: AppConstants.spacingSm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Back circular button
                    Container(
                      width: AppConstants.circularPickerSize,
                      height: AppConstants.circularPickerSize,
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowSoftBlack,
                            blurRadius: AppConstants.spacingSm,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.textPrimary,
                          size: AppConstants.iconSizeMd,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingMd),
                    // Large Two-Line Title
                    Expanded(
                      child: Text(
                        'saved_places.title_caps'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontTitleLarge,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          height: AppConstants.titleLineHeight,
                          letterSpacing: AppConstants.titleLetterSpacing,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    // "+ Ajouter" Capsule Action Button
                    Material(
                      color: AppColors.transparent,
                      child: InkWell(
                        onTap: _addNewPlace,
                        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.spacingUnitXl,
                            vertical: AppConstants.spacingUnit,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.add_rounded,
                                color: AppColors.white,
                                size: AppConstants.iconSizeDefault,
                              ),
                              const SizedBox(width: AppConstants.spacingXs),
                              Text(
                                'saved_places.add'.tr(),
                                style: GoogleFonts.inter(
                                  fontSize: AppConstants.fontMd,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.white,
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

              const SizedBox(height: AppConstants.spacingSm),

              // 2. Banner info card (Touchez un lieu pour l'utiliser...)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppConstants.spacingMd),
                  decoration: BoxDecoration(
                    color: AppColors.peachContainer,
                    borderRadius: BorderRadius.circular(AppConstants.radiusDialog),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star_outline_rounded,
                        color: AppColors.primary,
                        size: AppConstants.iconSizeLg,
                      ),
                      const SizedBox(width: AppConstants.spacingUnitLg),
                      Expanded(
                        child: Text(
                          'saved_places.tap_hint'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: AppConstants.fontMd,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                            height: AppConstants.bannerLineHeight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppConstants.spacingUnitXl),

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
                                const Icon(
                                  Icons.star_outline_rounded,
                                  size: AppConstants.iconSizeHuge,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(height: AppConstants.spacingUnitLg),
                                Text(
                                  'saved_places.empty_title'.tr(),
                                  style: GoogleFonts.inter(
                                    fontSize: AppConstants.fontLg,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppConstants.spacingXs),
                                Text(
                                  'saved_places.empty_subtitle'.tr(),
                                  style: GoogleFonts.inter(
                                    fontSize: AppConstants.fontSm,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppConstants.spacingMd),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppConstants.radiusLg,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppConstants.spacingTwenty,
                                      vertical: AppConstants.spacingUnitLg,
                                    ),
                                  ),
                                  icon: const Icon(Icons.add_rounded),
                                  label: Text('saved_places.add_place_button'.tr()),
                                  onPressed: _addNewPlace,
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.spacingMd,
                              vertical: AppConstants.spacingSm,
                            ),
                            itemCount: _savedPlaces.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: AppConstants.spacingUnitLg),
                            itemBuilder: (context, index) {
                              final place = _savedPlaces[index];

                              return Material(
                                color: AppColors.grayBgLight,
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusDialog,
                                ),
                                child: InkWell(
                                  onTap: () => _selectPlace(place),
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.radiusDialog,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(
                                      AppConstants.spacingUnitXl,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        AppConstants.radiusDialog,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Themed Icon Squircle
                                        Container(
                                          width: AppConstants
                                              .savedPlaceIconContainerSize,
                                          height: AppConstants
                                              .savedPlaceIconContainerSize,
                                          decoration: BoxDecoration(
                                            color: _getIconBackgroundColor(
                                              place.iconType,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(
                                              AppConstants.radiusLg,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: _buildIcon(place.iconType),
                                        ),
                                        const SizedBox(
                                          width: AppConstants.spacingUnitXl,
                                        ),

                                        // Name & Address
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                place.name,
                                                style: GoogleFonts.inter(
                                                  fontSize:
                                                      AppConstants.fontLg,
                                                  fontWeight:
                                                      FontWeight.w800,
                                                  color:
                                                      AppColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(
                                                height: AppConstants.spacingXs,
                                              ),
                                              Text(
                                                place.address,
                                                style: GoogleFonts.inter(
                                                  fontSize: AppConstants.fontMd,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Vertical Three-Dots Menu Button
                                        IconButton(
                                          icon: const Icon(
                                            Icons.more_vert_rounded,
                                            size: AppConstants.iconSizeLg,
                                            color: AppColors.textPrimary,
                                          ),
                                          tooltip: 'saved_places.more_options'
                                              .tr(),
                                          onPressed: () =>
                                              _showPlaceOptionsMenu(place),
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

