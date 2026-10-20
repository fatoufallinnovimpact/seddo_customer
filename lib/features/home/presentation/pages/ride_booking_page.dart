import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/domain/models/ride_option_model.dart';
import 'package:seddo/features/home/presentation/pages/driver_search_page.dart';
import 'package:seddo/features/home/presentation/widgets/insufficient_balance_sheet.dart';
import 'package:seddo/features/home/presentation/widgets/map_marker_helper.dart';
import 'package:seddo/features/home/presentation/widgets/orange_money_payment_sheet.dart';
import 'package:seddo/features/home/presentation/widgets/ride_option_card_widget.dart';
import 'package:seddo/services/places_service.dart';
import 'package:seddo/services/route_service.dart';

/// Screen displaying the active route polyline on Google Maps and the ride options bottom sheet
/// matching the exact reference UI mockup:
/// - Full interactive Google Map with route polyline following the quickest path
/// - Pickup marker with "• Prise en charge · 4 min" black badge
/// - Destination marker with orange square anchor
/// - Nearby Seddo driver car on map
/// - Floating top bar with back button and "[Destination] · [Heure] >" badge
/// - Bottom sheet "Choisissez une course" with Seddo Eco and Seddo Confort cards,
///   Orange Money payment method tile, and "Commander Seddo Eco / Confort" button
class RideBookingPage extends StatefulWidget {
  final PlaceSearchResult departure;
  final PlaceSearchResult destination;
  final PlacesService? placesService;
  final RouteService? routeService;

  const RideBookingPage({
    super.key,
    required this.departure,
    required this.destination,
    this.placesService,
    this.routeService,
  });

  @override
  State<RideBookingPage> createState() => _RideBookingPageState();
}

class _RideBookingPageState extends State<RideBookingPage> {
  late final RouteService _routeService;
  GoogleMapController? _mapController;

  BitmapDescriptor? _carMarkerIcon;
  BitmapDescriptor? _pickupBadgeIcon;
  BitmapDescriptor? _destSquareIcon;

  List<LatLng> _polylinePoints = [];
  bool _isLoadingRoute = true;
  double _distanceKm = 5.0;
  int _durationMinutes = 15;

  RideType _selectedRideType = RideType.eco;
  late RideOptionModel _ecoOption;
  late RideOptionModel _confortOption;

  @override
  void initState() {
    super.initState();
    _routeService = widget.routeService ?? RouteService();
    _computeRideOptions();
    _loadCustomMarkers();
    _fetchRoute();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _computeRideOptions() {
    final now = DateTime.now();
    final arrivalEco = now.add(Duration(minutes: _durationMinutes + 4));
    final arrivalConfort = now.add(Duration(minutes: _durationMinutes + 7));

    final ecoTimeStr =
        '${arrivalEco.hour.toString().padLeft(2, '0')}:${arrivalEco.minute.toString().padLeft(2, '0')}';
    final confortTimeStr =
        '${arrivalConfort.hour.toString().padLeft(2, '0')}:${arrivalConfort.minute.toString().padLeft(2, '0')}';

    // Pricing estimation based on Dakar distance (FCFA rounded to nearest 100)
    final ecoFare = ((1500 + (_distanceKm * 250)) / 100).round() * 100;
    final confortFare = ((2200 + (_distanceKm * 325)) / 100).round() * 100;

    _ecoOption = RideOptionModel(
      type: RideType.eco,
      title: 'Seddo Eco',
      subtitle: '$ecoTimeStr · à 4 min',
      capacity: 4,
      price: ecoFare.clamp(2000, 25000),
      estimatedArrival: ecoTimeStr,
      pickupDuration: '4 min',
    );

    _confortOption = RideOptionModel(
      type: RideType.confort,
      title: 'Seddo Confort',
      subtitle: '$confortTimeStr · climatisée',
      capacity: 4,
      price: confortFare.clamp(2800, 35000),
      estimatedArrival: confortTimeStr,
      pickupDuration: '7 min',
    );
  }

  Future<void> _loadCustomMarkers() async {
    final car = await MapMarkerHelper.get3DCarMarker();
    final pickup = await MapMarkerHelper.getDeparturePinMarker();
    final dest = await MapMarkerHelper.getDestinationPinMarker();

    if (mounted) {
      setState(() {
        _carMarkerIcon = car;
        _pickupBadgeIcon = pickup;
        _destSquareIcon = dest;
      });
    }
  }

  Future<void> _fetchRoute() async {
    final origin = LatLng(
      widget.departure.latitude,
      widget.departure.longitude,
    );
    final destination = LatLng(
      widget.destination.latitude,
      widget.destination.longitude,
    );

    final details = await _routeService.getRoute(
      origin: origin,
      destination: destination,
    );

    if (mounted) {
      setState(() {
        _polylinePoints = details.polylinePoints;
        _distanceKm = details.distanceKm;
        _durationMinutes = details.durationMinutes;
        _isLoadingRoute = false;
        _computeRideOptions();
      });

      _fitCameraToBounds();
    }
  }

  void _fitCameraToBounds() {
    if (_mapController == null || _polylinePoints.isEmpty) return;

    double south = widget.departure.latitude;
    double north = widget.departure.latitude;
    double west = widget.departure.longitude;
    double east = widget.departure.longitude;

    for (final p in _polylinePoints) {
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );

    // Padding ensures top bar and bottom sheet don't obscure route
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 90),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // 1. Pickup departure location pin marker
    if (_pickupBadgeIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup_marker'),
          position: LatLng(
            widget.departure.latitude,
            widget.departure.longitude,
          ),
          icon: _pickupBadgeIcon!,
          anchor: const Offset(0.5, 1.0),
        ),
      );
    }

    // 2. Destination arrival location pin marker
    if (_destSquareIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dest_marker'),
          position: LatLng(
            widget.destination.latitude,
            widget.destination.longitude,
          ),
          icon: _destSquareIcon!,
          anchor: const Offset(0.5, 1.0),
        ),
      );
    }

    // 3. Driver car nearby pickup on the route
    if (_carMarkerIcon != null && _polylinePoints.length > 2) {
      // Place driver car slightly ahead of pickup point
      final carPos = _polylinePoints[math.min(2, _polylinePoints.length - 1)];
      markers.add(
        Marker(
          markerId: const MarkerId('driver_car'),
          position: carPos,
          icon: _carMarkerIcon!,
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    if (_polylinePoints.isEmpty) return {};

    return {
      Polyline(
        polylineId: const PolylineId('route_polyline'),
        points: _polylinePoints,
        color: AppColors.yangoRouteGreen,
        width: 4,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  Future<void> _onOrderRide() async {
    final selectedOption =
        _selectedRideType == RideType.eco ? _ecoOption : _confortOption;

    final result = await OrangeMoneyPaymentSheet.show(
      context,
      rideOption: selectedOption,
    );

    if (!mounted || result == null) return;

    if (result == OrangeMoneyPaymentResult.insufficientBalance) {
      if (mounted) {
        await InsufficientBalanceSheet.show(
          context,
          rideOption: selectedOption,
        );
      }
      return;
    }

    if (result == OrangeMoneyPaymentResult.success) {
      if (mounted) {
        Navigator.of(context).push(
          SlideRightToLeftRoute(
            page: DriverSearchPage(
              departure: widget.departure,
              destination: widget.destination,
              rideOption: selectedOption,
              polylinePoints: _polylinePoints,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final systemBottom = MediaQuery.of(context).padding.bottom;
    final selectedOption =
        _selectedRideType == RideType.eco ? _ecoOption : _confortOption;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // 1. Fullscreen Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                widget.departure.latitude,
                widget.departure.longitude,
              ),
              zoom: 14.5,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (_polylinePoints.isNotEmpty) {
                _fitCameraToBounds();
              }
            },
            polylines: _buildPolylines(),
            markers: _buildMarkers(),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
          ),

          // 2. Floating Top Bar: Back Button + Destination Pill Badge
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingSm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Circular Back Button
                      Container(
                        width: AppConstants.circularButtonSize,
                        height: AppConstants.circularButtonSize,
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

                      const SizedBox(width: AppConstants.spacingSm),

                      // Floating destination pill: "Almadies · 18:42 >"
                      Expanded(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusPill,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.shadowMarker,
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.destination.mainText,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  ' · ${_ecoOption.estimatedArrival} ',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: AppColors.textPrimary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Balance spacing for center pill
                      const SizedBox(width: AppConstants.circularButtonSize),
                    ],
                  ),
                  if (_isLoadingRoute)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(
                        color: AppColors.primary,
                        backgroundColor: Colors.transparent,
                        minHeight: 2.5,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. Bottom Sheet Modal: "Choisissez une course"
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
                    color: AppColors.shadowCardBlack,
                    blurRadius: 24,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                AppConstants.spacingMd + 4,
                10,
                AppConstants.spacingMd + 4,
                systemBottom + AppConstants.spacingMd,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Drag Handle
                  Container(
                    width: AppConstants.circularIconContainerSize,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.dragHandle,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusXs,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header: "Choisissez une course"
                  Text(
                    'Choisissez une course',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Option 1: Seddo Eco Card (3D Vehicle)
                  RideOptionCardWidget(
                    option: _ecoOption,
                    isSelected: _selectedRideType == RideType.eco,
                    imagePath: 'assets/images/seddo_eco_3d.png',
                    onTap: () => setState(() => _selectedRideType = RideType.eco),
                  ),

                  const SizedBox(height: 10),

                  // Option 2: Seddo Confort Card (3D Vehicle)
                  RideOptionCardWidget(
                    option: _confortOption,
                    isSelected: _selectedRideType == RideType.confort,
                    imagePath: 'assets/images/seddo_confort_3d.png',
                    onTap: () =>
                        setState(() => _selectedRideType = RideType.confort),
                  ),

                  const SizedBox(height: 16),

                  // Payment Method Row: Orange Money
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        // Orange Money "OM" badge
                        Container(
                          width: 36,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.buttonBlack,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'OM',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title & Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Orange Money · 77 ••• 45 12',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Prix fixe, payé à la commande',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Lock / fixed icon
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Big Orange Confirmation Button: "Commander Seddo Eco"
                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.buttonHeight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusLg,
                          ),
                        ),
                      ),
                      onPressed: _onOrderRide,
                      child: Text(
                        'Commander ${selectedOption.title}',
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

/// Ride option tile card with custom border for selected state

