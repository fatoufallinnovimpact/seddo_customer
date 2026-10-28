import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/pages/edit_user_position_page.dart';
import 'package:seddo/features/home/presentation/pages/pickup_map_location_picker_page.dart';
import 'package:seddo/features/home/presentation/widgets/seddo_share_position_sheet.dart';
import 'package:seddo/features/saved_places/data/models/saved_place_model.dart';
import 'package:seddo/features/saved_places/data/services/saved_places_service.dart';
import 'package:seddo/features/saved_places/presentation/widgets/add_saved_place_sheet.dart';
import 'package:seddo/services/places_service.dart';

/// Modal "VOTRE POSITION" affiché depuis le bas vers le haut
/// lorsqu'on clique sur le logo Seddo ou sur l'adresse de la rue :
/// - Titre "VOTRE POSITION"
/// - Carte aperçu avec marqueur Seddo et adresse
/// - Clic sur la carte aperçu -> ouvre la carte en grand (PickupMapLocationPickerPage)
/// - Actions : Enregistrer, Partager, Modifier la position
class UserPositionBottomSheet extends StatefulWidget {
  final LatLng userLocation;
  final String mainAddress;
  final String secondaryAddress;
  final PlacesService? placesService;

  const UserPositionBottomSheet({
    super.key,
    required this.userLocation,
    required this.mainAddress,
    required this.secondaryAddress,
    this.placesService,
  });

  static Future<PlaceSearchResult?> show(
    BuildContext context, {
    required LatLng userLocation,
    required String mainAddress,
    required String secondaryAddress,
    PlacesService? placesService,
  }) {
    return showModalBottomSheet<PlaceSearchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => UserPositionBottomSheet(
        userLocation: userLocation,
        mainAddress: mainAddress,
        secondaryAddress: secondaryAddress,
        placesService: placesService ?? PlacesService(),
      ),
    );
  }

  @override
  State<UserPositionBottomSheet> createState() =>
      _UserPositionBottomSheetState();
}

class _UserPositionBottomSheetState extends State<UserPositionBottomSheet> {
  final SavedPlacesService _savedPlacesService = SavedPlacesService();
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadySaved();
  }

  Future<void> _checkIfAlreadySaved() async {
    try {
      final list = await _savedPlacesService.getSavedPlaces();
      final already = list.any((p) =>
          (p.latitude - widget.userLocation.latitude).abs() < 0.0005 &&
          (p.longitude - widget.userLocation.longitude).abs() < 0.0005 ||
          p.name.trim().toLowerCase() == widget.mainAddress.trim().toLowerCase() ||
          p.address.toLowerCase().contains(widget.mainAddress.toLowerCase()));
      if (already && mounted) {
        setState(() => _isSaved = true);
      }
    } catch (_) {}
  }

  void _openFullMapPicker() async {
    final result = await Navigator.of(context).push<PlaceSearchResult>(
      SlideRightToLeftRoute(
        page: PickupMapLocationPickerPage(
          initialLocation: widget.userLocation,
          initialMainText: widget.mainAddress,
          initialSecondaryText: widget.secondaryAddress,
          placesService: widget.placesService,
        ),
      ),
    );

    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  void _openEditPosition() async {
    final result = await Navigator.of(context).push<PlaceSearchResult>(
      SlideRightToLeftRoute(
        page: EditUserPositionPage(
          currentLocation: widget.userLocation,
          currentMainText: widget.mainAddress,
          currentSecondaryText: widget.secondaryAddress,
          placesService: widget.placesService,
        ),
      ),
    );

    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  void _saveLocation() async {
    // Ne pas fermer le modal pour pouvoir voir l'icône remplie au retour
    final savedResult = await AddSavedPlaceSheet.show(
      context,
      placesService: widget.placesService ?? PlacesService(),
      currentUserLocation: widget.userLocation,
      initialPlace: SavedPlaceModel(
        id: '',
        name: widget.mainAddress,
        address: '${widget.mainAddress}, ${widget.secondaryAddress}',
        iconType: 'star',
        latitude: widget.userLocation.latitude,
        longitude: widget.userLocation.longitude,
      ),
    );

    if (savedResult != null && mounted) {
      try {
        await _savedPlacesService.addSavedPlace(savedResult);
      } catch (_) {}
      if (!mounted) return;

      setState(() {
        _isSaved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lieu enregistré avec succès dans vos favoris'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _shareLocation() {
    SeddoSharePositionSheet.show(
      context,
      location: widget.userLocation,
      mainAddress: widget.mainAddress,
      secondaryAddress: widget.secondaryAddress,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppConstants.spacingLg,
            12,
            AppConstants.spacingLg,
            bottomPadding > 0 ? 12 : 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Drag handle
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

              // 2. Titre : VOTRE POSITION
              Text(
                'VOTRE POSITION',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 16),

              // 3. Carte aperçu de la position (cliquable pour ouvrir la carte en grand)
              GestureDetector(
                onTap: _openFullMapPicker,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.grayBorderLight,
                      width: 1.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowSubtleBlack,
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Aperçu mini-carte avec le marqueur Seddo
                      SizedBox(
                        height: 145,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            GoogleMap(
                              key: const ValueKey('preview_mini_google_map'),
                              initialCameraPosition: CameraPosition(
                                target: widget.userLocation,
                                zoom: 16.2,
                              ),
                              myLocationEnabled: false,
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: false,
                              compassEnabled: false,
                              mapToolbarEnabled: false,
                              rotateGesturesEnabled: false,
                              scrollGesturesEnabled: false,
                              tiltGesturesEnabled: false,
                              zoomGesturesEnabled: false,
                              gestureRecognizers:
                                  <Factory<OneSequenceGestureRecognizer>>{},
                            ),

                            // Overlay translucide pour rendre tout le bloc cliquable
                            Positioned.fill(
                              child: Container(
                                color: Colors.transparent,
                              ),
                            ),

                            // Marqueur central Seddo sur la mini-carte
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.hail_rounded,
                                      color: AppColors.white,
                                      size: 22,
                                    ),
                                  ),
                                  Container(
                                    width: 2.5,
                                    height: 12,
                                    color: AppColors.markerIconBlack,
                                  ),
                                  Container(
                                    width: 10,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Textes sous la mini-carte
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.mainAddress,
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.secondaryAddress,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
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
              const SizedBox(height: 16),

              // 4. Liste des 3 actions avec les SVGs demandés
              _buildActionTile(
                svgAsset: 'assets/icons/save-2-svgrepo-com.svg',
                iconColor: _isSaved ? AppColors.primary : AppColors.textPrimary,
                title: 'Enregistrer la position pour une utilisation ultérieure',
                onTap: _saveLocation,
              ),
              const Divider(height: 1, color: AppColors.grayBorderLight),
              _buildActionTile(
                svgAsset: 'assets/icons/share-svgrepo-com.svg',
                iconColor: AppColors.textPrimary,
                title: 'Partager la position',
                onTap: _shareLocation,
              ),
              const Divider(height: 1, color: AppColors.grayBorderLight),
              _buildActionTile(
                svgAsset: 'assets/icons/edit-pencil-line-01-svgrepo-com.svg',
                iconColor: AppColors.textPrimary,
                title: 'Modifier votre position',
                onTap: _openEditPosition,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    String? svgAsset,
    IconData? icon,
    Color? iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            if (svgAsset != null)
              SvgPicture.asset(
                svgAsset,
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(
                  iconColor ?? AppColors.textPrimary,
                  BlendMode.srcIn,
                ),
              )
            else if (icon != null)
              Icon(
                icon,
                color: iconColor ?? AppColors.textPrimary,
                size: 22,
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
