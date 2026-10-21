import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/domain/models/ride_option_model.dart';
import 'package:seddo/features/home/presentation/pages/driver_approaching_page.dart';
import 'package:seddo/features/home/presentation/pages/ride_booking_page.dart';
import 'package:seddo/features/home/presentation/pages/ride_cancelled_page.dart';
import 'package:seddo/features/home/presentation/widgets/map_marker_helper.dart';
import 'package:seddo/features/home/presentation/widgets/no_driver_found_sheet.dart';

/// Screen displayed while searching for nearby drivers matching Screenshot 3:
/// - Map with pickup marker, radar circle, candidate car with "Offre envoyée · 1,2 km" badge
/// - Bottom sheet:
///   - "Recherche d'un chauffeur" + animated progress bar
///   - "Paiement reçu · [Price] F" / "Remboursé si aucun chauffeur n'accepte"
///   - "6 chauffeurs [Eco/Confort] autour de vous" / "L'offre est proposée au plus proche d'abord"
///   - "Annuler la course"
///   - "Simuler : chauffeur trouvé" and "Simuler : aucun chauffeur" shortcuts
class DriverSearchPage extends StatefulWidget {
  final PlaceSearchResult departure;
  final PlaceSearchResult destination;
  final RideOptionModel rideOption;
  final List<LatLng> polylinePoints;

  const DriverSearchPage({
    super.key,
    required this.departure,
    required this.destination,
    required this.rideOption,
    this.polylinePoints = const [],
  });

  @override
  State<DriverSearchPage> createState() => _DriverSearchPageState();
}

class _DriverSearchPageState extends State<DriverSearchPage>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  Timer? _autoMatchTimer;
  late AnimationController _radarController;

  BitmapDescriptor? _carMarkerIcon;
  BitmapDescriptor? _orangeCarMarkerIcon;
  BitmapDescriptor? _offerSentBadgeIcon;
  BitmapDescriptor? _destPinIcon;
  BitmapDescriptor? _pickupPinIcon;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _loadCustomMarkers();

    // Auto match driver after 5 seconds if not triggered manually
    _autoMatchTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _onDriverFound();
      }
    });
  }

  @override
  void dispose() {
    _autoMatchTimer?.cancel();
    _radarController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadCustomMarkers() async {
    final car = await MapMarkerHelper.get3DCarMarker();
    final pickup = await MapMarkerHelper.getDeparturePinMarker();
    final dest = await MapMarkerHelper.getDestinationPinMarker();
    final offerBadge = await MapMarkerHelper.getPickupBadgeMarker(
      label: 'Offre envoyée · 1,2 km',
      dotColor: AppColors.primary,
    );

    if (mounted) {
      setState(() {
        _carMarkerIcon = car;
        _orangeCarMarkerIcon = car;
        _offerSentBadgeIcon = offerBadge;
        _destPinIcon = dest;
        _pickupPinIcon = pickup;
      });
    }
  }

  void _onDriverFound() {
    _autoMatchTimer?.cancel();
    final driver = DriverModel.mockDakarDriver(
      rideType: widget.rideOption.type,
      location: LatLng(
        widget.departure.latitude + 0.0035,
        widget.departure.longitude + 0.0030,
      ),
    );

    Navigator.of(context).pushReplacement(
      SlideRightToLeftRoute(
        page: DriverApproachingPage(
          departure: widget.departure,
          destination: widget.destination,
          rideOption: widget.rideOption,
          driver: driver,
          polylinePoints: widget.polylinePoints,
        ),
      ),
    );
  }

  void _onCancelRide() {
    _autoMatchTimer?.cancel();
    Navigator.of(context).pushReplacement(
      SlideRightToLeftRoute(
        page: RideCancelledPage(
          rideOption: widget.rideOption,
          departure: widget.departure,
          destination: widget.destination,
        ),
      ),
    );
  }

  /// Prêt pour l'API : appelé lorsque le backend signale qu'aucun chauffeur n'est disponible
  @visibleForTesting
  Future<void> onNoDriverAvailable() async {
    _autoMatchTimer?.cancel();
    final action = await NoDriverFoundSheet.show(
      context,
      departure: widget.departure,
      destination: widget.destination,
      rideOption: widget.rideOption,
    );

    if (!mounted || action == null) return;

    if (action == NoDriverFoundAction.retry) {
      Navigator.of(context).pushAndRemoveUntil(
        SlideRightToLeftRoute(
          page: RideBookingPage(
            departure: widget.departure,
            destination: widget.destination,
          ),
          settings: const RouteSettings(name: 'RideBookingPage'),
        ),
        (route) => route.isFirst,
      );
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Set<Circle> _buildRadarCircles() {
    return {
      Circle(
        circleId: const CircleId('radar_circle'),
        center: LatLng(
          widget.departure.latitude,
          widget.departure.longitude,
        ),
        radius: 400,
        strokeWidth: 2,
        strokeColor: AppColors.radarRingColor,
        fillColor: AppColors.radarFillColor,
      ),
    };
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // 1. Pickup departure location pin
    if (_pickupPinIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup_center'),
          position: LatLng(
            widget.departure.latitude,
            widget.departure.longitude,
          ),
          icon: _pickupPinIcon!,
          anchor: const Offset(0.5, 1.0),
        ),
      );
    } else {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup_center'),
          position: LatLng(
            widget.departure.latitude,
            widget.departure.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }

    // 2. Destination arrival location pin
    if (_destPinIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dest_square'),
          position: LatLng(
            widget.destination.latitude,
            widget.destination.longitude,
          ),
          icon: _destPinIcon!,
          anchor: const Offset(0.5, 1.0),
        ),
      );
    }

    // 3. Candidate car with "Offre envoyée · 1,2 km" badge
    final candidatePos = LatLng(
      widget.departure.latitude + 0.0035,
      widget.departure.longitude + 0.0030,
    );

    if (_orangeCarMarkerIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('candidate_car'),
          position: candidatePos,
          icon: _orangeCarMarkerIcon!,
          anchor: const Offset(0.5, 0.5),
          rotation: 45,
        ),
      );
    }

    if (_offerSentBadgeIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('offer_badge'),
          position: candidatePos,
          icon: _offerSentBadgeIcon!,
          anchor: const Offset(0.5, 1.8),
        ),
      );
    }

    // 4. Other nearby cars (3-4 surrounding cars)
    if (_carMarkerIcon != null) {
      final offsets = [
        [-0.0025, 0.0020, 110.0],
        [0.0028, -0.0022, 220.0],
        [-0.0018, -0.0030, 310.0],
        [0.0015, 0.0038, 70.0],
      ];

      for (int i = 0; i < offsets.length; i++) {
        markers.add(
          Marker(
            markerId: MarkerId('nearby_car_$i'),
            position: LatLng(
              widget.departure.latitude + offsets[i][0],
              widget.departure.longitude + offsets[i][1],
            ),
            icon: _carMarkerIcon!,
            anchor: const Offset(0.5, 0.5),
          ),
        );
      }
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    if (widget.polylinePoints.isEmpty) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route_polyline'),
        points: widget.polylinePoints,
        color: AppColors.yangoRouteGreen,
        width: 4,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final systemBottom = MediaQuery.of(context).padding.bottom;
    final rideTypeLabel =
        widget.rideOption.type == RideType.eco ? 'Eco' : 'Confort';

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
              zoom: 14.8,
            ),
            onMapCreated: (ctrl) => _mapController = ctrl,
            circles: _buildRadarCircles(),
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
          ),

          // 2. Floating Top Back Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingSm,
              ),
              child: Container(
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
            ),
          ),

          // 3. Bottom Sheet Modal ("Recherche d'un chauffeur")
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
                AppConstants.spacingLg,
                12,
                AppConstants.spacingLg,
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
                  const SizedBox(height: 16),

                  // Top Live Status Bar with 3D Vehicle Preview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ride.live_search'.tr(),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Image.asset(
                        widget.rideOption.type == RideType.confort
                            ? 'assets/images/seddo_confort_3d.png'
                            : 'assets/images/seddo_eco_3d.png',
                        width: 56,
                        height: 38,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title: Recherche d'un chauffeur
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ride.searching'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Animated Progress Bar (Orange)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: const LinearProgressIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.surfaceGrey,
                      minHeight: 3.5,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Tile 1: Paiement reçu · 3 500 F
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.refundContainerBg,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.check_rounded,
                          color: AppColors.refundGreen,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ride.payment_received'.tr(args: [widget.rideOption.formattedPrice]),
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ride.refund_guarantee'.tr(),
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

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: AppColors.cardBorder),
                  ),

                  // Tile 2: 6 chauffeurs Eco autour de vous
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceGrey,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          widget.rideOption.type == RideType.eco
                              ? 'assets/icons/ecocar.svg'
                              : 'assets/icons/confortcar.svg',
                          width: 22,
                          height: 22,
                          colorFilter: const ColorFilter.mode(
                            AppColors.textPrimary,
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
                              'ride.drivers_around_type'.tr(args: [rideTypeLabel]),
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ride.offer_closest_first'.tr(),
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

                  const SizedBox(height: 20),

                  // Button: Annuler la course
                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.buttonHeight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cancelSecondaryBtnBg,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusLg,
                          ),
                        ),
                      ),
                      onPressed: _onCancelRide,
                      child: Text(
                        'ride.cancel_ride'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
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
