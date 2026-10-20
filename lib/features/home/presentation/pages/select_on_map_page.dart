import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/services/places_service.dart';

/// Fullscreen interactive map picker matching the reference design:
/// - Floating top-left circular back button
/// - Full interactive Google Map
/// - Center pin with:
///   - Black pill bubble ("Arrivée ici" or "Départ ici")
///   - Vertical stem
///   - Square anchor marker (orange center with crisp white border)
/// - Bottom sheet card:
///   - Top handle
///   - Category label ("Point d'arrivée" or "Point de départ")
///   - Address title (e.g. "Rue NG-112, Ngor")
///   - Address subtitle (e.g. "Près de la mosquée de Ngor")
///   - Signature orange "Confirmer ce point" button
class SelectOnMapPage extends StatefulWidget {
  final bool isArrival;
  final LatLng? initialLocation;
  final PlacesService? placesService;

  const SelectOnMapPage({
    super.key,
    this.isArrival = true,
    this.initialLocation,
    this.placesService,
  });

  @override
  State<SelectOnMapPage> createState() => _SelectOnMapPageState();
}

class _SelectOnMapPageState extends State<SelectOnMapPage> {
  late final PlacesService _placesService;
  GoogleMapController? _mapController;

  // Default coordinate: Ngor / Almadies Dakar (matches reference design screenshot)
  static const LatLng _defaultLocation = LatLng(14.7547, -17.5142);

  late LatLng _currentCenter;
  Timer? _geocodeDebounce;
  bool _isLoadingAddress = false;

  String _addressTitle = '';
  String _addressSubtitle = '';
  String _fullAddress = '';

  @override
  void initState() {
    super.initState();
    _placesService = widget.placesService ?? PlacesService();
    _currentCenter = widget.initialLocation ?? _defaultLocation;

    // Initial geocode lookup
    _fetchAddressForLocation(_currentCenter);
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _onCameraMove(CameraPosition position) {
    _currentCenter = position.target;
  }

  void _onCameraIdle() {
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchAddressForLocation(_currentCenter);
    });
  }

  Future<void> _fetchAddressForLocation(LatLng location) async {
    if (!mounted) return;
    setState(() => _isLoadingAddress = true);

    try {
      final result = await _placesService.reverseGeocode(
        location.latitude,
        location.longitude,
      );

      if (mounted) {
        setState(() {
          _addressTitle = result.mainText;
          _addressSubtitle = result.secondaryText;
          _fullAddress = result.fullAddress;
          _isLoadingAddress = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingAddress = false;
        });
      }
    }
  }

  void _confirmSelection() {
    final title = _addressTitle.isNotEmpty
        ? _addressTitle
        : (widget.isArrival ? "Point d'arrivée" : "Point de départ");
    final subtitle = _addressSubtitle.isNotEmpty
        ? _addressSubtitle
        : '${_currentCenter.latitude.toStringAsFixed(4)}, ${_currentCenter.longitude.toStringAsFixed(4)}';
    final full = _fullAddress.isNotEmpty ? _fullAddress : '$title, $subtitle';

    final result = PlaceSearchResult(
      id: 'map_${_currentCenter.latitude.toStringAsFixed(5)}_${_currentCenter.longitude.toStringAsFixed(5)}',
      mainText: title,
      secondaryText: subtitle,
      fullAddress: full,
      latitude: _currentCenter.latitude,
      longitude: _currentCenter.longitude,
      category: widget.isArrival ? 'destination' : 'pickup',
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // 1. Fullscreen Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenter,
              zoom: 16.2,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: false,
            zoomGesturesEnabled: true,
          ),

          // 2. Interactive Map Center Pin
          // Anchored mathematically such that the center of the bottom orange square
          // aligns with the exact center of the map.
          Center(
            child: Transform.translate(
              offset: const Offset(0, -21),
              child: IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Black pill bubble with label
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mapPinAnchor,
                        borderRadius: BorderRadius.circular(AppConstants.radiusItem),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowHeavy,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.isArrival ? 'Arrivée ici' : 'Départ ici',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),

                    // Vertical black stem line
                    Container(
                      width: 2,
                      height: 12,
                      color: AppColors.mapPinAnchor,
                    ),

                    // Square anchor box: orange center with crisp white border
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppConstants.radiusXs),
                        border: Border.all(
                          color: AppColors.white,
                          width: 2.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowPinBox,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Floating Circular Back Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 12),
              child: Container(
                width: AppConstants.circularIconContainerSize,
                height: AppConstants.circularIconContainerSize,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowMarker,
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),

          // 4. Floating "Ma Position" Button (above bottom sheet)
          Positioned(
            right: 16,
            bottom: 220 + MediaQuery.of(context).padding.bottom,
            child: Container(
              width: AppConstants.circularIconContainerSize,
              height: AppConstants.circularIconContainerSize,
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowMarker,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.my_location_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                onPressed: () {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLng(_defaultLocation),
                  );
                },
              ),
            ),
          ),

          // 5. Bottom Sheet Card with Place Information and Confirm Button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppConstants.radiusSheet),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowDarkBlack,
                    blurRadius: 24,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Center drag handle
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

                  // Label: "Point d'arrivée" or "Point de départ"
                  Text(
                    widget.isArrival ? "Point d'arrivée" : "Point de départ",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Main Place / Street Title
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _addressTitle.isNotEmpty
                              ? _addressTitle
                              : (_isLoadingAddress
                                  ? "Recherche de l'adresse..."
                                  : "Position sur la carte"),
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isLoadingAddress)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Subtitle / Area / City
                  Text(
                    _addressSubtitle.isNotEmpty
                        ? _addressSubtitle
                        : (_isLoadingAddress
                            ? "Recherche..."
                            : "${_currentCenter.latitude.toStringAsFixed(4)}, ${_currentCenter.longitude.toStringAsFixed(4)}"),
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 20),

                  // Orange "Confirmer ce point" Button
                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.buttonHeight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _confirmSelection,
                      child: Text(
                        'Confirmer ce point',
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
        ],
      ),
    );
  }
}
