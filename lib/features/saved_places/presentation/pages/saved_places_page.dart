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
          top: Radius.circular(24),
        ),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: _buildIcon(place.iconType),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            place.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            place.address,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(color: Color(0xFFF1F3F5), height: 1),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: const Color(0xFFF8F9FA),
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  title: Text(
                    'saved_places.edit'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF9CA3AF),
                    size: 20,
                  ),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    _editPlace(place);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: const Color(0xFFFEF2F2),
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.deleteRed,
                    size: 20,
                  ),
                  title: Text(
                    'saved_places.delete_action'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deleteRed,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFF87171),
                    size: 20,
                  ),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    _deletePlace(place);
                  },
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getIconBackgroundColor(String iconType) {
    return const Color(0xFFF3F4F6);
  }

  Widget _buildIcon(String iconType) {
    IconData iconData;
    switch (iconType) {
      case 'home':
        iconData = Icons.home_outlined;
        break;
      case 'work':
        iconData = Icons.work_outline_rounded;
        break;
      case 'airport':
        iconData = Icons.flight_rounded;
        break;
      case 'heart':
        iconData = Icons.favorite_border_rounded;
        break;
      case 'gym':
        iconData = Icons.fitness_center_rounded;
        break;
      case 'star':
      default:
        iconData = Icons.star_border_rounded;
        break;
    }
    return Icon(
      iconData,
      size: 22,
      color: AppColors.textPrimary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Top Bar: Bouton retour circulaire + Titre épuré + Capsule "+ Ajouter"
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
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingMd),
                    // Large Two-Line Title with subtitle count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'saved_places.title_caps'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              height: 1.15,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (_savedPlaces.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${_savedPlaces.length} lieu${_savedPlaces.length > 1 ? 'x' : ''} enregistré${_savedPlaces.length > 1 ? 's' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    // "+ Ajouter" Capsule Action Button
                    Material(
                      color: AppColors.transparent,
                      child: InkWell(
                        onTap: _addNewPlace,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.28),
                                blurRadius: 10,
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
                              const SizedBox(width: 5),
                              Text(
                                'saved_places.add'.tr(),
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
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

              const SizedBox(height: AppConstants.spacingXs),

              // 2. Banner info card épurée et moderne
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                      width: 1.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x04000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.touch_app_outlined,
                          color: AppColors.primary,
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'saved_places.tap_hint'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppConstants.spacingMd),

              // 3. List of saved places
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSavedPlaces,
                        color: AppColors.primary,
                        child: _savedPlaces.isEmpty
                            ? SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 60,
                                    horizontal: 32,
                                  ),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3F4F6),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFFE5E7EB),
                                            width: 1,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.bookmark_outline_rounded,
                                          size: 38,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        'saved_places.empty_title'.tr(),
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'saved_places.empty_subtitle'.tr(),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 13.5,
                                          height: 1.4,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: AppColors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 14,
                                          ),
                                        ),
                                        icon: const Icon(Icons.add_rounded, size: 20),
                                        label: Text(
                                          'saved_places.add_place_button'.tr(),
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        onPressed: _addNewPlace,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppConstants.spacingMd,
                                  vertical: AppConstants.spacingXs,
                                ),
                                itemCount: _savedPlaces.length,
                                itemBuilder: (context, index) {
                                  final place = _savedPlaces[index];

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: const Color(0xFFEAEBED),
                                        width: 1.0,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x05000000),
                                          blurRadius: 10,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _selectPlace(place),
                                        borderRadius: BorderRadius.circular(18),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                          child: Row(
                                            children: [
                                              // Themed Neutral Icon Squircle
                                              Container(
                                                width: 48,
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  color: _getIconBackgroundColor(
                                                    place.iconType,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
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
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      place.name,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 15.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            AppColors.textPrimary,
                                                        letterSpacing: -0.2,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      place.address,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Vertical Three-Dots Menu Button in soft round target
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF9FAFB),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: const Color(0xFFF1F3F5),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: IconButton(
                                                  padding: EdgeInsets.zero,
                                                  icon: const Icon(
                                                    Icons.more_vert_rounded,
                                                    size: 19,
                                                    color: Color(0xFF6B7280),
                                                  ),
                                                  tooltip: 'saved_places.more_options'
                                                      .tr(),
                                                  onPressed: () =>
                                                      _showPlaceOptionsMenu(place),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
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

