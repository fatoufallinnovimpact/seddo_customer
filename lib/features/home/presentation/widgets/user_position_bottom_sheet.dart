import 'package:easy_localization/easy_localization.dart';
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
import 'package:seddo/services/map_style_service.dart';
import 'package:seddo/services/places_service.dart';

/// Modal "Position de l'utilisateur" affiché depuis le bas vers le haut
/// lorsqu'on clique sur le logo Seddo ou sur l'adresse de la rue :
/// - Carte aperçu avec marqueur Seddo et bouton "Modifier" en bas à droite
/// - Adresse principale et secondaire
/// - Clic sur la carte aperçu -> ouvre la carte en grand (PickupMapLocationPickerPage)
/// - Deux boutons d'action horizontaux : "Enregistrer" et "Partager"
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
      backgroundColor: AppColors.transparent,
      barrierColor: AppColors.pureBlack.withValues(alpha: 0.45),
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
        setState(() {});
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('user_position.saved_success'.tr()),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
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
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusSheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppConstants.spacingMd,
            AppConstants.userPositionDragHandleTop,
            AppConstants.spacingMd,
            bottomPadding > 0 ? bottomPadding : AppConstants.spacingTwenty,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Poignée de glissement (Drag handle)
              Center(
                child: Container(
                  width: AppConstants.handleWidth,
                  height: AppConstants.handleHeight,
                  decoration: BoxDecoration(
                    color: AppColors.dragHandle,
                    borderRadius: BorderRadius.circular(AppConstants.radiusXs),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spacingMd),

              // 2. Carte aperçu de la position avec bouton Modifier et adresse
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppConstants.radiusDialog),
                  border: Border.all(
                    color: AppColors.grayBorderLight,
                    width: AppConstants.strokeWidthBorder,
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
                    // Mini-carte Google Map avec le marqueur central Seddo
                    SizedBox(
                      height: AppConstants.userPositionMapHeight,
                      width: double.infinity,
                      child: Stack(
                        children: [
                          // Fond beige doux pour garantir un affichage beige instantané
                          Container(color: AppColors.mapBeige),

                          GoogleMap(
                            key: const ValueKey('preview_mini_google_map'),
                            style: MapStyleService.style,
                            initialCameraPosition: CameraPosition(
                              target: widget.userLocation,
                              zoom: AppConstants.userPositionMapZoom,
                            ),
                            onMapCreated: MapStyleService.applyStyle,
                            buildingsEnabled: false,
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

                          // Overlay translucide pour rendre toute la carte cliquable
                          Positioned.fill(
                            child: Material(
                              color: AppColors.transparent,
                              child: InkWell(
                                onTap: _openFullMapPicker,
                              ),
                            ),
                          ),

                          // Marqueur central Seddo sur la mini-carte
                          Center(
                            child: IgnorePointer(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: AppConstants.iconSizeHero,
                                    height: AppConstants.iconSizeHero,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(
                                        AppConstants.radiusDefault,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: AppColors.shadowPinBox,
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.hail_rounded,
                                      color: AppColors.white,
                                      size: AppConstants.iconSizeLg,
                                    ),
                                  ),
                                  Container(
                                    width: AppConstants.userPositionStalkWidth,
                                    height: AppConstants.userPositionStalkHeight,
                                    color: AppColors.mapPinAnchor,
                                  ),
                                  Container(
                                    width: AppConstants.userPositionShadowWidth,
                                    height: AppConstants.userPositionShadowHeight,
                                    decoration: BoxDecoration(
                                      color: AppColors.shadowSoftBlack,
                                      borderRadius: BorderRadius.circular(
                                        AppConstants.radiusSm,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Bouton "Modifier" flottant en bas à droite de la carte
                          Positioned(
                            right: AppConstants.spacingUnit,
                            bottom: AppConstants.spacingUnit,
                            child: Material(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusPill,
                              ),
                              elevation: 2,
                              shadowColor: AppColors.shadowCardBlack,
                              child: InkWell(
                                onTap: _openEditPosition,
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusPill,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppConstants.spacingUnitLg,
                                    vertical: AppConstants.spacingS,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SvgPicture.asset(
                                        'assets/icons/edit-pencil-line-01-svgrepo-com.svg',
                                        width: AppConstants.iconSizeSm,
                                        height: AppConstants.iconSizeSm,
                                        colorFilter: const ColorFilter.mode(
                                          AppColors.textPrimary,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                      const SizedBox(
                                        width: AppConstants.spacingS,
                                      ),
                                      Text(
                                        'common.edit'.tr(),
                                        style: GoogleFonts.inter(
                                          fontSize: AppConstants.fontMd,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Textes de l'adresse sous la carte
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppConstants.spacingMd,
                        AppConstants.spacingUnitLg,
                        AppConstants.spacingMd,
                        AppConstants.spacingMd,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.mainAddress,
                            style: GoogleFonts.inter(
                              fontSize: AppConstants.fontXl,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing:
                                  AppConstants.userPositionLetterSpacingTight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppConstants.spacingXs),
                          Text(
                            widget.secondaryAddress,
                            style: GoogleFonts.inter(
                              fontSize: AppConstants.fontMd,
                              fontWeight: FontWeight.w500,
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
              ),

              const SizedBox(height: AppConstants.spacingMd),

              // 3. Boutons d'action horizontaux : "Enregistrer" et "Partager"
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      title: 'common.save'.tr(),
                      svgAsset: 'assets/icons/save-2-svgrepo-com.svg',
                      badgeBgColor: AppColors.alert,
                      onTap: _saveLocation,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingUnitLg),
                  Expanded(
                    child: _buildActionButton(
                      title: 'common.share'.tr(),
                      svgAsset: 'assets/icons/share-svgrepo-com.svg',
                      badgeBgColor: AppColors.greenSuccess,
                      onTap: _shareLocation,
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

  Widget _buildActionButton({
    required String title,
    required String svgAsset,
    required Color badgeBgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.grayBgLight,
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: Container(
          height: AppConstants.userPositionButtonHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingSm,
            vertical: AppConstants.spacingSm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(
              color: AppColors.grayBorderLight,
              width: AppConstants.strokeWidthBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: AppConstants.userPositionBadgeSize,
                height: AppConstants.userPositionBadgeSize,
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusItem,
                  ),
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  svgAsset,
                  width: AppConstants.iconSizeMd,
                  height: AppConstants.iconSizeMd,
                  colorFilter: const ColorFilter.mode(
                    AppColors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingUnit),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: AppConstants.fontBase,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing:
                        AppConstants.userPositionLetterSpacingSnug,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
