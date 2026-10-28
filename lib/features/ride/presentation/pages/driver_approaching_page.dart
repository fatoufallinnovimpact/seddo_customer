import 'dart:async';
import 'dart:math' as math;
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
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/ride_cancel_result_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/pages/active_ride_page.dart';
import 'package:seddo/features/ride/presentation/pages/driver_chat_page.dart';
import 'package:seddo/features/ride/presentation/pages/in_app_call_page.dart';
import 'package:seddo/features/ride/presentation/pages/ride_cancelled_page.dart';
import 'package:seddo/features/ride/presentation/pages/shared_ride_tracking_page.dart';
import 'package:seddo/features/ride/presentation/widgets/cancel_ride_reason_sheet.dart';
import 'package:seddo/features/ride/presentation/widgets/ride_map_camera_toggle_button.dart';
import 'package:seddo/features/home/presentation/widgets/map_marker_helper.dart';
import 'package:seddo/features/safety/presentation/widgets/safety_modal_widget.dart';

/// Screen displayed when the driver is approaching the pickup location:
/// Matches the user's reference design:
/// - Fullscreen interactive map with:
///   - Pickup pin with floating white badge "Rendez-vous ici" + glowing orange halo
///   - Approaching 3D car with translucent orange halo
///   - Dashed orange route connecting car to pickup + "4 min" pill badge
///   - Back button and recenter button
/// - Bottom sheet:
///   - Header: "Rendez-vous au point de départ" + orange clock pill "4 min"
///   - Card 1: 3D Vehicle image, "MS" avatar, [DK 4521 AB] plate, "Toyota Corolla grise", Moussa • ★ 4,9
///   - Card 2: Code de départ (À donner au chauffeur) + 4 dark boxes [ 4 ] [ 8 ] [ 2 ] [ 1 ]
///   - Card 3: Quick message field "Envoyer un message..." + circular call button
///   - Card 4: 3 action buttons [ Partager ] [ Sécurité ] [ Annuler ]
class DriverApproachingPage extends StatefulWidget {
  final PlaceSearchResult departure;
  final PlaceSearchResult destination;
  final RideOptionModel rideOption;
  final DriverModel driver;
  final List<LatLng> polylinePoints;
  final String departureCode;
  final bool autoStartSimulation;
  final String? rideId;
  final RideService? rideService;

  const DriverApproachingPage({
    super.key,
    required this.departure,
    required this.destination,
    required this.rideOption,
    required this.driver,
    this.polylinePoints = const [],
    this.departureCode = '4821',
    this.autoStartSimulation = false,
    this.rideId,
    this.rideService,
  });

  @override
  State<DriverApproachingPage> createState() => _DriverApproachingPageState();
}

class _DriverApproachingPageState extends State<DriverApproachingPage>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  BitmapDescriptor? _carMarkerIcon;
  BitmapDescriptor? _rendezVousIciMarkerIcon;
  BitmapDescriptor? _etaPillMarkerIcon;

  // Approach Animation State
  AnimationController? _approachController;
  late LatLng _pickupPosition;
  late LatLng _driverInitialPosition;
  late LatLng _currentCarPosition;
  double _currentCarHeading = 0.0;
  int _remainingEtaMinutes = 4;
  bool _driverArrived = false;
  bool _followCar = true;
  int _lastTickMs = 0;

  // Live Ride & Driver State synchronisés avec GET /v1/rides/{id}
  late DriverModel _currentDriver;
  late String _departureCode;
  late RideService _rideService;
  Timer? _ridePollTimer;

  final GlobalKey _bottomCardKey = GlobalKey();
  double _bottomCardHeight = 390.0;

  @override
  void initState() {
    super.initState();

    _currentDriver = widget.driver;
    _departureCode = widget.departureCode;
    _rideService = widget.rideService ?? RideService();
    _remainingEtaMinutes = 4;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureBottomCard();
    });

    _pickupPosition =
        LatLng(widget.departure.latitude, widget.departure.longitude);

    // Initial position of approaching driver
    _driverInitialPosition = _currentDriver.currentLocation.latitude != 0
        ? _currentDriver.currentLocation
        : LatLng(
            _pickupPosition.latitude + 0.0065,
            _pickupPosition.longitude + 0.0055,
          );

    _currentCarPosition = _driverInitialPosition;
    _currentCarHeading =
        _calculateBearing(_driverInitialPosition, _pickupPosition);

    _loadCustomMarkers();

    final bool isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    _approachController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )
      ..addListener(_onApproachTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _onDriverReachedPickup();
        }
      });

    if (widget.autoStartSimulation && !isTest) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          _approachController?.forward();
        }
      });
    }

    // Interroge l'API GET /v1/rides/{id} pour récupérer immédiatement et en continu
    // les données réelles (code à 4 chiffres, infos chauffeur, statut course)
    final effectiveRideId = widget.rideId ?? RideService.lastCreatedRideId;
    if (effectiveRideId != null && effectiveRideId.isNotEmpty) {
      _fetchRideDetails(effectiveRideId);
      if (!isTest) {
        _ridePollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
          _fetchRideDetails(effectiveRideId);
        });
      }
    }
  }

  @override
  void dispose() {
    _ridePollTimer?.cancel();
    _approachController?.stop();
    _approachController?.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _measureBottomCard() {
    final renderBox =
        _bottomCardKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize && mounted) {
      final h = renderBox.size.height;
      if ((_bottomCardHeight - h).abs() > 3) {
        setState(() {
          _bottomCardHeight = h;
        });
      }
    }
  }

  /// Interroge GET /v1/rides/{id} : vue client (chauffeur, code de départ, paiement)
  Future<void> _fetchRideDetails(String id) async {
    try {
      final data = await _rideService.getRideDetails(id);
      if (data != null && mounted) {
        _applyRideDetails(data);
      }
    } catch (e) {
      debugPrint('[DriverApproachingPage] ⚠️ Erreur getRideDetails: $e');
    }
  }

  /// Applique les données retournées par GET /v1/rides/{id} dans le modal et l'écran
  void _applyRideDetails(Map<String, dynamic> data) {
    if (!mounted) return;

    final status = (data['status'] as String? ?? '').toUpperCase();

    // 1. Course annulée
    if (status.startsWith('CANCELLED') ||
        status == 'NO_DRIVER' ||
        status == 'NO_SHOW') {
      _ridePollTimer?.cancel();
      _approachController?.stop();
      Navigator.of(context).pushReplacement(
        SlideRightToLeftRoute(
          page: RideCancelledPage(
            rideOption: widget.rideOption,
            departure: widget.departure,
            destination: widget.destination,
          ),
        ),
      );
      return;
    }

    // 2. Chauffeur a validé le code client et démarré la course
    if (status == 'IN_PROGRESS') {
      _ridePollTimer?.cancel();
      _approachController?.stop();
      startRide();
      return;
    }

    // 3. Extraction du vrai code de départ retourné par l'API
    final newCode =
        DriverModel.extractDepartureCode(data, fallback: _departureCode);

    // 4. Extraction du vrai chauffeur retourné par l'API
    final hasDriver = data['driver'] != null || data['carModel'] != null;
    DriverModel updatedDriver = _currentDriver;
    if (hasDriver) {
      updatedDriver = DriverModel.fromRideJson(
        data,
        defaultRideType: widget.rideOption.type,
      );
    }

    // 5. Statut d'arrivée du chauffeur
    final isArrived = status == 'DRIVER_ARRIVED' || status == 'ARRIVED';

    // 6. Temps d'approche restant (ETA)
    final etaFromApi = (data['etaMinutes'] as num?)?.toInt() ??
        (data['eta'] as num?)?.toInt();

    setState(() {
      _departureCode = newCode;
      _currentDriver = updatedDriver;
      if (isArrived) {
        _driverArrived = true;
        _remainingEtaMinutes = 0;
      } else if (etaFromApi != null && etaFromApi > 0) {
        _remainingEtaMinutes = etaFromApi;
      }

      // Synchronisation de la position GPS en temps réel
      if (updatedDriver.currentLocation.latitude != 0 &&
          updatedDriver.currentLocation.longitude != 0 &&
          (updatedDriver.currentLocation.latitude !=
                  _currentCarPosition.latitude ||
              updatedDriver.currentLocation.longitude !=
                  _currentCarPosition.longitude)) {
        final heading = _calculateBearing(
            _currentCarPosition, updatedDriver.currentLocation);
        _currentCarPosition = updatedDriver.currentLocation;
        _currentCarHeading = heading;
      }
    });
  }

  Future<void> _loadCustomMarkers() async {
    final car = await MapMarkerHelper.get3DCarMarker();
    final pickup = await MapMarkerHelper.getRendezVousIciMarker();
    final eta = await MapMarkerHelper.getEtaPillMarker('4 min');

    if (mounted) {
      setState(() {
        _carMarkerIcon = car;
        _rendezVousIciMarkerIcon = pickup;
        _etaPillMarkerIcon = eta;
      });
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * (math.pi / 180.0);
    final lon1 = start.longitude * (math.pi / 180.0);
    final lat2 = end.latitude * (math.pi / 180.0);
    final lon2 = end.longitude * (math.pi / 180.0);
    final dLon = lon2 - lon1;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final radians = math.atan2(y, x);
    return (radians * (180.0 / math.pi) + 360.0) % 360.0;
  }

  void _onApproachTick() {
    if (!mounted || _approachController == null) return;
    final t = _approachController!.value;

    final now = DateTime.now().millisecondsSinceEpoch;
    // Throttle UI rebuilds to ~20fps (every 50ms) to avoid lagging native Google Map PlatformView
    if (now - _lastTickMs < 50 && t < 1.0) return;
    _lastTickMs = now;

    // Smooth easeInOut curve towards pickup location
    final progress = Curves.easeInOut.transform(t);
    final curLat = _driverInitialPosition.latitude +
        (_pickupPosition.latitude - _driverInitialPosition.latitude) * progress;
    final curLng = _driverInitialPosition.longitude +
        (_pickupPosition.longitude - _driverInitialPosition.longitude) *
            progress;

    final newPos = LatLng(curLat, curLng);
    final heading = _calculateBearing(newPos, _pickupPosition);

    // Calculate remaining ETA (from 4 min down to 0)
    final remainingMinutes = ((1.0 - progress) * 4).ceil().clamp(0, 4);

    setState(() {
      _currentCarPosition = newPos;
      _currentCarHeading = heading;
      _remainingEtaMinutes = remainingMinutes;
    });
  }

  void _onDriverReachedPickup() {
    if (!mounted) return;
    setState(() {
      _driverArrived = true;
      _remainingEtaMinutes = 0;
    });

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ride.driver_arrived_at_pickup'
                      .tr(args: [_currentDriver.name.split(' ').first]),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    // Auto-transition to ActiveRidePage (ride underway) after brief pause
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        startRide();
      }
    });
  }

  /// Méthode publique prête pour connecter l'API backend / WebSocket en direct :
  /// Appelée lorsque le chauffeur accepte et se déplace vers le point de départ
  void updateDriverGpsLocation(LatLng position, {double? heading}) {
    if (_approachController != null && _approachController!.isAnimating) {
      _approachController!.stop();
    }
    setState(() {
      _currentCarPosition = position;
      if (heading != null) _currentCarHeading = heading;
    });
  }

  /// Démarre la course vers la destination (transition vers ActiveRidePage)
  void startRide() {
    _ridePollTimer?.cancel();
    Navigator.of(context).pushReplacement(
      SlideRightToLeftRoute(
        page: ActiveRidePage(
          departure: widget.departure,
          destination: widget.destination,
          rideOption: widget.rideOption,
          driver: _currentDriver,
          polylinePoints: widget.polylinePoints,
          autoStartSimulation: false,
        ),
      ),
    );
  }

  Future<void> _onCancelRide() async {
    final selectedReason = await CancelRideReasonSheet.show(
      context,
      isDriverAssigned: true,
    );

    if (selectedReason == null || !mounted) return;

    _ridePollTimer?.cancel();
    _approachController?.stop();

    final effectiveRideId =
        widget.rideId ?? RideService.lastCreatedRideId;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    final service = widget.rideService ?? RideService();
    final cancelResult = effectiveRideId != null && effectiveRideId.isNotEmpty
        ? await service.cancelRide(
            rideId: effectiveRideId,
            reason: selectedReason,
            originalPrice: widget.rideOption.price,
          )
        : RideCancelResultModel.fallback(
            originalPrice: widget.rideOption.price,
            reason: selectedReason,
          );

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).pushReplacement(
        SlideRightToLeftRoute(
          page: RideCancelledPage(
            rideOption: widget.rideOption,
            departure: widget.departure,
            destination: widget.destination,
            cancellationFee: cancelResult.fee,
            refundAmount: cancelResult.refundAmount,
            reason: cancelResult.reason,
          ),
        ),
      );
    }
  }

  void _openChat() {
    Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: DriverChatPage(
          driver: _currentDriver,
          rideId: widget.rideId,
          rideService: widget.rideService,
        ),
      ),
    );
  }

  Future<void> _callDriver() async {
    await InAppCallPage.show(context, driver: _currentDriver);
  }

  void _openShare() {
    Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: SharedRideTrackingPage(
          departure: widget.departure,
          destination: widget.destination,
          driver: _currentDriver,
          polylinePoints: widget.polylinePoints,
          etaText: '$_remainingEtaMinutes min',
        ),
      ),
    );
  }

  void _openSafety() {
    SafetyModalWidget.show(
      context,
      destination: widget.destination,
      driver: _currentDriver,
    );
  }

  void _fitMapBounds() {
    if (_mapController == null) return;
    try {
      final minLat = math.min(
          _pickupPosition.latitude, _driverInitialPosition.latitude);
      final maxLat = math.max(
          _pickupPosition.latitude, _driverInitialPosition.latitude);
      final minLng = math.min(
          _pickupPosition.longitude, _driverInitialPosition.longitude);
      final maxLng = math.max(
          _pickupPosition.longitude, _driverInitialPosition.longitude);

      final deltaLat = (maxLat - minLat).abs();
      final deltaLng = (maxLng - minLng).abs();

      if (deltaLat < 0.0005 && deltaLng < 0.0005) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_pickupPosition, 16.0),
        );
        return;
      }

      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat - 0.0015, minLng - 0.0015),
            northeast: LatLng(maxLat + 0.0015, maxLng + 0.0015),
          ),
          45.0,
        ),
      );
    } catch (_) {
      try {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_pickupPosition, 15.2),
        );
      } catch (_) {}
    }
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // 1. Pickup location marker with "Rendez-vous ici" badge
    if (_rendezVousIciMarkerIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup_rendez_vous_ici'),
          position: _pickupPosition,
          icon: _rendezVousIciMarkerIcon!,
          anchor: const Offset(0.5, 1.0),
          zIndexInt: 5,
        ),
      );
    }

    // 2. Approaching Car Marker with smooth heading rotation
    if (_carMarkerIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('approaching_car'),
          position: _currentCarPosition,
          icon: _carMarkerIcon!,
          rotation: _currentCarHeading,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndexInt: 10,
        ),
      );
    }

    // 3. Floating "4 min" pill marker along the dashed approach line
    if (_etaPillMarkerIcon != null && !_driverArrived) {
      final midLat = (_currentCarPosition.latitude + _pickupPosition.latitude) / 2;
      final midLng =
          (_currentCarPosition.longitude + _pickupPosition.longitude) / 2;
      markers.add(
        Marker(
          markerId: const MarkerId('approach_eta_pill'),
          position: LatLng(midLat, midLng),
          icon: _etaPillMarkerIcon!,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 6,
        ),
      );
    }

    return markers;
  }

  Set<Circle> _buildCircles() {
    return {
      // Orange glowing halo around pickup location
      Circle(
        circleId: const CircleId('pickup_halo'),
        center: _pickupPosition,
        radius: 45,
        fillColor: AppColors.primary.withAlpha(35),
        strokeColor: AppColors.primary.withAlpha(90),
        strokeWidth: 2,
      ),
      // Orange glowing halo around approaching vehicle
      Circle(
        circleId: const CircleId('car_halo'),
        center: _currentCarPosition,
        radius: 35,
        fillColor: AppColors.primary.withAlpha(30),
        strokeColor: AppColors.primary.withAlpha(80),
        strokeWidth: 1,
      ),
    };
  }

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{
      // Dashed orange line connecting approaching car to pickup location
      Polyline(
        polylineId: const PolylineId('approach_dashed_route'),
        points: [_currentCarPosition, _pickupPosition],
        color: AppColors.primary,
        width: 3,
        patterns: [
          PatternItem.dash(16),
          PatternItem.gap(10),
        ],
      ),
    };

    if (widget.polylinePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('approaching_trip_route'),
          points: widget.polylinePoints,
          color: AppColors.primary.withAlpha(90),
          width: 4,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }

    return polylines;
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final systemBottom = MediaQuery.of(context).padding.bottom;
    final licensePlateText =
        _currentDriver.licensePlate.replaceAll('-', ' ');
    final carDescription = _currentDriver.carModel.isNotEmpty
        ? '${_currentDriver.carModel} ${_currentDriver.carColor.isNotEmpty ? _currentDriver.carColor : "grise"}'
        : 'Toyota Corolla grise';

    final initials = _currentDriver.name.isNotEmpty
        ? _currentDriver.name
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'MS';

    final etaDisplay = _driverArrived
        ? 'ride.arrived'.tr()
        : '$_remainingEtaMinutes min';

    final digits = _departureCode.padRight(4, '0').split('');

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // 1. Fullscreen Google Map with multi-touch gestures enabled
          Listener(
            onPointerDown: (_) {
              if (_followCar) {
                setState(() {
                  _followCar = false;
                });
              }
            },
            child: GoogleMap(
              key: const ValueKey('approaching_google_map'),
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  (_pickupPosition.latitude + _driverInitialPosition.latitude) /
                      2,
                  (_pickupPosition.longitude +
                          _driverInitialPosition.longitude) /
                      2,
                ),
                zoom: 15.2,
              ),
              padding: const EdgeInsets.only(
                bottom: 375,
                top: 70,
                left: 16,
                right: 16,
              ),
              onMapCreated: (ctrl) {
                _mapController = ctrl;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) {
                      _fitMapBounds();
                    }
                  });
                });
              },
              markers: _buildMarkers(),
              circles: _buildCircles(),
              polylines: _buildPolylines(),
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              compassEnabled: false,
              mapToolbarEnabled: false,
              mapType: MapType.normal,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
            ),
          ),

          // 2. Top Bar: Back button (matching screenshot)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingSm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
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
          ),

          // 2.5 Floating Camera Toggle Button (Ma position / Destination / Vue Trajet)
          Positioned(
            right: 16,
            bottom: _bottomCardHeight + 14,
            child: RideMapCameraToggleButton(
              mapControllerGetter: () => _mapController,
              departureLocation: _pickupPosition,
              destinationLocation: LatLng(
                widget.destination.latitude,
                widget.destination.longitude,
              ),
              polylinePoints: widget.polylinePoints,
              initialMode: RideMapCameraMode.tripOverview,
              onModeChanged: (mode) {
                if (mode == RideMapCameraMode.departure) {
                  setState(() => _followCar = true);
                } else {
                  setState(() => _followCar = false);
                }
              },
            ),
          ),

          // 3. Bottom Card matching Screenshot exactly
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              key: _bottomCardKey,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowDarkBlack,
                    blurRadius: 28,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppConstants.spacingLg,
                    12,
                    AppConstants.spacingLg,
                    systemBottom > 0 ? 12 : 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Centered Grey Drag Handle
                      Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: AppColors.dragHandle,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Header: Icon + "Rendez-vous au point de départ" + "4 min" pill
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Orange car icon in peach circle
                          Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              color: AppColors.peachLight,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.directions_car_rounded,
                              color: AppColors.primary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Title: Rendez-vous au point de départ
                          Expanded(
                            child: Text(
                              'ride.pickup_point'.tr(),
                              style: GoogleFonts.inter(
                                fontSize: 18.5,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                height: 1.18,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),

                          // Pill: 4 min with clock icon
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  color: AppColors.white,
                                  size: 15,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  etaDisplay,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Card 1: Vehicle & Driver Card
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.grayBgSubtle,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.grayBorderLight,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            // 3D Car Image
                            Image.asset(
                              widget.rideOption.type == RideType.confort
                                  ? 'assets/images/seddo_confort_3d.png'
                                  : 'assets/images/seddo_eco_3d.png',
                              width: 74,
                              height: 46,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 10),

                            // Initials Avatar Circle (MS)
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: AppColors.peachMedium,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.orangeDarkAccent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Vehicle & Driver Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // License Plate Badge [ DK 4521 AB ]
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.white,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: AppColors.pureBlack,
                                        width: 1.4,
                                      ),
                                    ),
                                    child: Text(
                                      licensePlateText,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.pureBlack,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),

                                  // Car model & color
                                  Text(
                                    carDescription,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),

                                  // Driver Name & Rating
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _currentDriver.name.split(' ').first,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      const Text(
                                        '•',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      const Icon(
                                        Icons.star_rounded,
                                        color: AppColors.amberRating,
                                        size: 15,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        _currentDriver.rating.toStringAsFixed(1),
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Right Chevron
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textSecondary,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Card 2: Code de départ (PIN Code)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.orangeLightBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.peachMedium,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Orange Location Pin Icon
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: AppColors.peachMedium,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Code de départ label
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ride.departure_code'.tr(),
                                    style: GoogleFonts.inter(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ride.give_to_driver'.tr(),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 4 Dark digit boxes [ 4 ] [ 8 ] [ 2 ] [ 1 ]
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: digits.map((digit) {
                                return Container(
                                  width: 32,
                                  height: 38,
                                  margin: const EdgeInsets.only(left: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.licensePlateBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    digit,
                                    style: GoogleFonts.inter(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.white,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Card 3: Quick message input bar + Circular call button
                      Row(
                        children: [
                          // Expanded message input placeholder
                          Expanded(
                            child: GestureDetector(
                              onTap: _openChat,
                              child: Container(
                                height: 46,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: AppColors.grayBgLight,
                                  borderRadius: BorderRadius.circular(23),
                                ),
                                child: Row(
                                  children: [
                                    SvgPicture.asset(
                                      'assets/icons/message-square-lines-svgrepo-com.svg',
                                      width: 20,
                                      height: 20,
                                      colorFilter: const ColorFilter.mode(
                                        AppColors.primary,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'ride.send_message_hint'.tr(),
                                        style: GoogleFonts.inter(
                                          fontSize: 13.5,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Circular Phone Call Button
                          Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              color: AppColors.peachLight,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: SvgPicture.asset(
                                'assets/icons/call-svgrepo-com.svg',
                                width: 20,
                                height: 20,
                                colorFilter: const ColorFilter.mode(
                                  AppColors.primary,
                                  BlendMode.srcIn,
                                ),
                              ),
                              tooltip: 'ride.call_driver'.tr(),
                              onPressed: _callDriver,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Card 4: Action buttons row [ Partager ] [ Sécurité ] [ Annuler ]
                      Row(
                        children: [
                          // Partager Button
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.share_outlined,
                              label: 'common.share'.tr(),
                              onTap: _openShare,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Sécurité Button
                          Expanded(
                            child: _buildActionButton(
                              svgPath: 'assets/icons/security-svgrepo-com.svg',
                              label: 'drawer.safety'.tr(),
                              onTap: _openSafety,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Annuler Button (Allowed before ride start!)
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.close_rounded,
                              label: 'common.cancel'.tr(),
                              onTap: _onCancelRide,
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

  Widget _buildActionButton({
    IconData? icon,
    String? svgPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.grayBorderLight,
            width: 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowSubtleBlack,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (svgPath != null)
              SvgPicture.asset(
                svgPath,
                width: 22,
                height: 22,
                colorFilter: const ColorFilter.mode(
                  AppColors.primary,
                  BlendMode.srcIn,
                ),
              )
            else if (icon != null)
              Icon(
                icon,
                color: AppColors.primary,
                size: 22,
              ),
            const SizedBox(height: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
