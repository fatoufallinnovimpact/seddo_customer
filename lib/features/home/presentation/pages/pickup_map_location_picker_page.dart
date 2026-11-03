import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/widgets/map_marker_helper.dart';
import 'package:seddo/features/home/presentation/widgets/seddo_map_picker_pin.dart';
import 'package:seddo/features/ride/data/models/nearby_drivers_response_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/saved_places/data/models/saved_place_model.dart';
import 'package:seddo/features/saved_places/data/services/saved_places_service.dart';
import 'package:seddo/features/saved_places/presentation/widgets/add_saved_place_sheet.dart';
import 'package:seddo/services/map_style_service.dart';
import 'package:seddo/services/places_service.dart';

/// Écran plein écran de sélection de la position de départ sur la carte
/// Inspiré de l'expérience Yango adaptée aux couleurs de Seddo :
/// - Carte interactive Google Map fluide
/// - Marqueur central personnalisé animé (rebond jump à l'arrêt, flottement doux en mouvement)
/// - Bandeau flottant avec informations sur les voitures à proximité (GET /v1/drivers/nearby)
/// - Bouton retour et bouton de recentrage GPS
/// - Carte inférieure avec "Adresse de prise en charge", bouton "Terminé" et bouton de favori
class PickupMapLocationPickerPage extends StatefulWidget {
  final LatLng initialLocation;
  final String? initialMainText;
  final String? initialSecondaryText;
  final PlacesService? placesService;
  final RideService? rideService;

  const PickupMapLocationPickerPage({
    super.key,
    required this.initialLocation,
    this.initialMainText,
    this.initialSecondaryText,
    this.placesService,
    this.rideService,
  });

  @override
  State<PickupMapLocationPickerPage> createState() =>
      _PickupMapLocationPickerPageState();
}

class _PickupMapLocationPickerPageState
    extends State<PickupMapLocationPickerPage> {
  late final PlacesService _placesService;
  late final RideService _rideService;
  GoogleMapController? _mapController;

  late LatLng _currentLocation;
  bool _isMapMoving = false;
  bool _isLoadingAddress = false;
  bool _isLocationSaved = false;
  bool _showDragHint = true;
  Timer? _geocodeDebounce;
  Timer? _dragHintTimer;

  // Voitures disponibles à proximité (GET /v1/drivers/nearby)
  NearbyDriversResponseModel? _nearbyDrivers;
  bool _isLoadingNearby = false;
  BitmapDescriptor? _carMarkerIcon;
  Timer? _nearbyDebounce;

  String _mainAddress = '';
  String _secondaryAddress = '';
  String _fullAddress = '';

  @override
  void initState() {
    super.initState();
    _placesService = widget.placesService ?? PlacesService();
    _rideService = widget.rideService ?? RideService();
    _currentLocation = widget.initialLocation;
    _mainAddress = widget.initialMainText ?? 'Rue YF-557, 20';
    _secondaryAddress = widget.initialSecondaryText ??
        'Yoff, Almadies, Département de Dakar';
    _fullAddress = '$_mainAddress, $_secondaryAddress';

    _dragHintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showDragHint) {
        setState(() => _showDragHint = false);
      }
    });

    _loadCarMarker();
    _fetchNearbyDrivers(_currentLocation);

    // Geocodage initial si aucune adresse n'est déjà fournie
    if (widget.initialMainText == null || widget.initialMainText!.isEmpty) {
      _fetchAddressForLocation(_currentLocation);
    }
  }

  @override
  void dispose() {
    _dragHintTimer?.cancel();
    _geocodeDebounce?.cancel();
    _nearbyDebounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadCarMarker() async {
    try {
      final icon = await MapMarkerHelper.get3DCarMarker();
      if (mounted) {
        setState(() {
          _carMarkerIcon = icon;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchNearbyDrivers(LatLng location) async {
    if (!mounted) return;
    setState(() => _isLoadingNearby = true);

    try {
      final res = await _rideService.getNearbyDrivers(
        lat: location.latitude,
        lng: location.longitude,
      );

      if (mounted) {
        setState(() {
          _nearbyDrivers = res;
          _isLoadingNearby = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingNearby = false);
      }
    }
  }

  int get _totalNearbyCars {
    if (_nearbyDrivers == null) return 0;
    final catSum = _nearbyDrivers!.categories.fold<int>(
      0,
      (sum, c) => sum + c.count,
    );
    return catSum > 0 ? catSum : _nearbyDrivers!.allCars.length;
  }

  int? get _shortestEtaMinutes {
    if (_nearbyDrivers == null) return null;
    int? shortest;
    for (final cat in _nearbyDrivers!.categories) {
      if (cat.count > 0 && cat.etaMinutes != null) {
        if (shortest == null || cat.etaMinutes! < shortest) {
          shortest = cat.etaMinutes;
        }
      }
    }
    return shortest;
  }

  Set<Marker> _buildNearbyMarkers() {
    final markers = <Marker>{};
    final cars = _nearbyDrivers?.allCars ?? [];

    for (int i = 0; i < cars.length; i++) {
      final car = cars[i];
      if (car.lat == 0 && car.lng == 0) continue;

      markers.add(
        Marker(
          markerId: MarkerId('nearby_car_${car.id}_$i'),
          position: LatLng(car.lat, car.lng),
          rotation: car.heading,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          icon: _carMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange,
              ),
          infoWindow: const InfoWindow(
            title: 'Chauffeur Seddo',
            snippet: 'Véhicule disponible à proximité',
          ),
        ),
      );
    }

    return markers;
  }

  void _onCameraMoveStarted() {
    if (_showDragHint) {
      _dragHintTimer?.cancel();
    }
    if (!_isMapMoving || _showDragHint) {
      setState(() {
        _isMapMoving = true;
        _showDragHint = false;
      });
    }
  }

  void _onCameraMove(CameraPosition position) {
    _currentLocation = position.target;
  }

  void _onCameraIdle() {
    setState(() {
      _isMapMoving = false;
    });

    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 320), () {
      _fetchAddressForLocation(_currentLocation);
    });

    _nearbyDebounce?.cancel();
    _nearbyDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchNearbyDrivers(_currentLocation);
    });
  }

  Future<void> _fetchAddressForLocation(LatLng location) async {
    if (!mounted) return;
    setState(() => _isLoadingAddress = true);

    try {
      final res = await _placesService.reverseGeocode(
        location.latitude,
        location.longitude,
      );

      if (mounted) {
        setState(() {
          _mainAddress = res.mainText.isNotEmpty
              ? res.mainText
              : 'Position sélectionnée';
          _secondaryAddress = res.secondaryText.isNotEmpty
              ? res.secondaryText
              : 'Dakar, Sénégal';
          _fullAddress = res.fullAddress.isNotEmpty
              ? res.fullAddress
              : '$_mainAddress, $_secondaryAddress';
          _isLoadingAddress = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingAddress = false);
      }
    }
  }

  Future<void> _recenterOnGps() async {
    try {
      final coords = await _placesService.getCurrentCoordinates();
      if (coords != null && mounted) {
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: coords, zoom: 16.5),
          ),
        );
      }
    } catch (_) {}
  }

  void _confirmPosition() {
    final result = PlaceSearchResult(
      id: 'pickup_${_currentLocation.latitude.toStringAsFixed(5)}_${_currentLocation.longitude.toStringAsFixed(5)}',
      mainText: _mainAddress,
      secondaryText: _secondaryAddress,
      fullAddress: _fullAddress,
      latitude: _currentLocation.latitude,
      longitude: _currentLocation.longitude,
      category: 'pickup',
    );

    Navigator.of(context).pop(result);
  }

  Future<void> _saveCurrentLocation() async {
    final saved = await AddSavedPlaceSheet.show(
      context,
      placesService: _placesService,
      currentUserLocation: _currentLocation,
      initialPlace: SavedPlaceModel(
        id: '',
        name: _mainAddress,
        address: _fullAddress,
        iconType: 'star',
        latitude: _currentLocation.latitude,
        longitude: _currentLocation.longitude,
      ),
    );

    if (saved != null && mounted) {
      try {
        await SavedPlacesService().addSavedPlace(saved);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _isLocationSaved = true;
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

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // 1. Google Map plein écran (clipped to remove Google logo)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: AppConstants.mapLogoClipOffset,
            child: GoogleMap(
              key: const ValueKey('pickup_picker_google_map'),
              style: MapStyleService.style,
              initialCameraPosition: CameraPosition(
                target: _currentLocation,
                zoom: 16.5,
              ),
              onMapCreated: (ctrl) {
                _mapController = ctrl;
                MapStyleService.applyStyle(ctrl);
              },
              onCameraMoveStarted: _onCameraMoveStarted,
              onCameraMove: _onCameraMove,
              onCameraIdle: _onCameraIdle,
              markers: _buildNearbyMarkers(),
              buildingsEnabled: false,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              rotateGesturesEnabled: true,
              scrollGesturesEnabled: true,
              tiltGesturesEnabled: false,
              zoomGesturesEnabled: true,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
            ),
          ),

          // 2. Marqueur central personnalisé animé
          // Placé au centre de la zone visible au-dessus de la bottom card
          Center(
            child: Transform.translate(
              // Compense la hauteur de la carte inférieure (230 / 2 = 115)
              offset: const Offset(0, -50),
              child: IgnorePointer(
                child: SeddoMapPickerPin(
                  isMoving: _isMapMoving,
                ),
              ),
            ),
          ),

          // 3. Carte supérieure flottante : Informations des voitures autour (GET /v1/drivers/nearby)
          _buildTopNearbyCard(),

          // 4. Boutons flottants : Retour (bas-gauche) et Recentrer GPS (bas-droite)
          Positioned(
            left: 16,
            bottom: 240 + bottomPadding,
            child: Container(
              width: AppConstants.circularButtonSize,
              height: AppConstants.circularButtonSize,
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowDarkBlack,
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

          Positioned(
            right: 16,
            bottom: 240 + bottomPadding,
            child: Container(
              width: AppConstants.circularButtonSize,
              height: AppConstants.circularButtonSize,
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowDarkBlack,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.my_location_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                onPressed: _recenterOnGps,
              ),
            ),
          ),

          // 5. Carte inférieure "Adresse de prise en charge"
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppConstants.radiusSheet),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowCardBlack,
                    blurRadius: 24,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppConstants.spacingLg,
                    16,
                    AppConstants.spacingLg,
                    bottomPadding > 0 ? 12 : 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre : Adresse de prise en charge
                      Text(
                        'Adresse de prise en charge',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Ligne d'adresse
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Icône de prise en charge
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.hail_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Textes d'adresse
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _secondaryAddress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _mainAddress,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                    if (_isLoadingAddress) ...[
                                      const SizedBox(width: 8),
                                      const SizedBox(
                                        width: 13,
                                        height: 13,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 10),

                          // Badge "Entrée"
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.softGreySurface,
                              borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
                            ),
                            child: Text(
                              'Entrée',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Boutons d'action : "Terminé" (large) + Signet Bookmark (carré)
                      Row(
                        children: [
                          // Bouton principal orange Terminé
                          Expanded(
                            child: SizedBox(
                              height: AppConstants.buttonHeight,
                              child: ElevatedButton(
                                onPressed: _confirmPosition,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                                  ),
                                ),
                                child: Text(
                                  'Terminé',
                                  style: GoogleFonts.inter(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Bouton Bookmark pour enregistrer le lieu
                          Container(
                            width: AppConstants.buttonHeight,
                            height: AppConstants.buttonHeight,
                            decoration: BoxDecoration(
                              color: AppColors.softGreySurface,
                              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isLocationSaved
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                color: _isLocationSaved
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                size: 24,
                              ),
                              onPressed: _saveCurrentLocation,
                              tooltip: 'Enregistrer ce lieu',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bandeau supérieur d'information des voitures disponibles autour (GET /v1/drivers/nearby)
  Widget _buildTopNearbyCard() {
    final totalCars = _totalNearbyCars;
    final shortestEta = _shortestEtaMinutes;

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          key: const ValueKey('pickup_map_top_nearby_info_card'),
          margin: const EdgeInsets.only(top: 10, left: 16, right: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoadingNearby && _nearbyDrivers == null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowDarkBlack,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Recherche des véhicules à proximité...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (totalCars > 0) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowDarkBlack,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.nearbyCarAvailableBadgeBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.directions_car_rounded,
                          size: 14,
                          color: AppColors.nearbyCarAvailableIcon,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          totalCars == 1
                              ? '1 voiture disponible autour'
                              : '$totalCars voitures disponibles autour',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (shortestEta != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '~$shortestEta min',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if ((_nearbyDrivers?.categories ?? [])
                    .any((c) => c.count > 0)) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final cat in _nearbyDrivers?.categories ??
                          <NearbyCategoryModel>[])
                        if (cat.count > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.shadowDarkBlack,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              '${cat.category}: ${cat.count}${cat.etaMinutes != null ? ' (~${cat.etaMinutes} min)' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slateDark,
                              ),
                            ),
                          ),
                    ],
                  ),
                ],
              ] else ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowDarkBlack,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.nearbyNoCarBadgeBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: AppColors.nearbyNoCarIcon,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Pas de voiture disponible actuellement',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _showDragHint
                    ? Container(
                        key: const ValueKey('drag_hint_badge'),
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadowDarkBlack,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'Balayez pour déplacer la carte',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
