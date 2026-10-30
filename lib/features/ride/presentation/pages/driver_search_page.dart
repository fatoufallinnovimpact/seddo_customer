import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/nearby_drivers_response_model.dart';
import 'package:seddo/features/ride/data/models/ride_cancel_result_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/pages/driver_approaching_page.dart';
import 'package:seddo/features/ride/presentation/pages/ride_booking_page.dart';
import 'package:seddo/features/ride/presentation/pages/ride_cancelled_page.dart';
import 'package:seddo/features/ride/presentation/widgets/cancel_ride_reason_sheet.dart';
import 'package:seddo/features/ride/presentation/widgets/orange_money_payment_sheet.dart';
import 'package:seddo/features/home/presentation/widgets/map_marker_helper.dart';
import 'package:seddo/features/ride/presentation/widgets/no_driver_found_sheet.dart';
import 'package:seddo/features/ride/presentation/widgets/realtime_status_indicator.dart';
import 'package:seddo/services/map_style_service.dart';
import 'package:seddo/services/realtime_service.dart';
import 'package:seddo/services/route_service.dart';

/// Screen displayed while searching for nearby drivers:
/// - Map with pickup marker, true pulsating radar waves, real nearby cars from GET /v1/drivers/nearby
/// - Bottom sheet:
///   - "Recherche d'un chauffeur" + animated progress bar
///   - "Paiement reçu · [Price] F" / "Remboursé si aucun chauffeur n'accepte"
///   - "X chauffeurs [Eco/Confort] autour de vous"
///   - "Annuler la course"
class DriverSearchPage extends StatefulWidget {
  final PlaceSearchResult departure;
  final PlaceSearchResult destination;
  final RideOptionModel rideOption;
  final List<LatLng> polylinePoints;
  final String? pickupLandmark;
  final bool? autoMatchDriver;
  final String? rideId;
  final RideService? rideService;
  final PaymentMethodType? paymentMethod;

  const DriverSearchPage({
    super.key,
    required this.departure,
    required this.destination,
    required this.rideOption,
    this.polylinePoints = const [],
    this.pickupLandmark,
    this.autoMatchDriver,
    this.rideId,
    this.rideService,
    this.paymentMethod,
  });

  @override
  State<DriverSearchPage> createState() => _DriverSearchPageState();
}

class _DriverSearchPageState extends State<DriverSearchPage>
    with SingleTickerProviderStateMixin {
  late final RideService _rideService;
  GoogleMapController? _mapController;
  Timer? _autoMatchTimer;
  Timer? _nearbyPollTimer;
  Timer? _rideStatusPollTimer;
  late AnimationController _radarController;

  StreamSubscription<RealtimeRideStatusEvent>? _realtimeStatusSub;
  StreamSubscription<List<NearbyCarModel>>? _realtimeNearbySub;
  StreamSubscription<void>? _realtimeReconnectSub;

  BitmapDescriptor? _destPinIcon;
  BitmapDescriptor? _pickupPinIcon;
  BitmapDescriptor? _carMarkerIcon;

  List<NearbyCarModel> _nearbyCars = [];
  int? _nearbyDriversCount;

  final GlobalKey _bottomSheetKey = GlobalKey();
  double _bottomSheetHeight = 360.0;

  @override
  void initState() {
    super.initState();
    _rideService = widget.rideService ?? RideService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureBottomSheet();
    });

    // True pulsating radar waves expanding outward continuously
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..addListener(() {
        if (mounted) setState(() {});
      })..repeat();

    _loadCustomMarkers();
    _loadNearbyDrivers();

    final bool isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    final bool shouldAutoMatch = widget.autoMatchDriver ?? isTest;

    if (shouldAutoMatch) {
      _autoMatchTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          onDriverFound();
        }
      });
    }

    // Écoute temps réel des chauffeurs proches via WebSocket (nearby.drivers)
    _realtimeNearbySub = RealtimeService().nearbyDriversStream.listen((cars) {
      if (mounted && cars.isNotEmpty) {
        setState(() {
          _nearbyCars = cars;
          _nearbyDriversCount = cars.length;
        });
      }
    });

    // Poll de secours passif pour les chauffeurs à proximité (toutes les 15s si hors ligne)
    _nearbyPollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        if (!RealtimeService().isConnected) {
          _loadNearbyDrivers();
        }
      },
    );

    // Initialisation et écoute temps réel de l'acceptation de la course par WebSocket
    final effectiveRideId = widget.rideId ?? RideService.lastCreatedRideId;
    if (effectiveRideId != null && effectiveRideId.isNotEmpty) {
      _checkRideStatus(effectiveRideId);

      // Connexion Socket.IO et adhésion au canal de la course
      RealtimeService().connect();
      RealtimeService().joinRide(effectiveRideId);

      _realtimeStatusSub = RealtimeService().rideStatusStream.listen((event) {
        if (!mounted) return;
        if (event.rideId.isEmpty || event.rideId == effectiveRideId) {
          if (event.status == 'ACCEPTED' ||
              event.status == 'DRIVER_ARRIVED' ||
              event.status == 'IN_PROGRESS' ||
              event.driver != null) {
            _rideStatusPollTimer?.cancel();
            final driver = event.driver ??
                DriverModel.fromRideJson(
                  event.raw,
                  defaultRideType: widget.rideOption.type,
                );
            final code = event.departureCode ??
                DriverModel.extractDepartureCode(event.raw);
            onDriverFound(driver, code, effectiveRideId);
          } else if (event.status.startsWith('CANCELLED') ||
              event.status == 'NO_DRIVER') {
            _rideStatusPollTimer?.cancel();
            onNoDriverAvailable();
          }
        }
      });

      // Resynchronisation REST automatique dès la reconnexion (PDF page 7 & 8)
      _realtimeReconnectSub = RealtimeService().onReconnect.listen((_) {
        if (mounted) {
          _checkRideStatus(effectiveRideId);
        }
      });

      // Si le WebSocket n'est pas encore connecté, conserver un polling de secours passif
      if (!isTest) {
        _rideStatusPollTimer = Timer.periodic(
          const Duration(seconds: 5),
          (_) {
            if (!RealtimeService().isConnected) {
              _checkRideStatus(effectiveRideId);
            }
          },
        );
      }
    }
  }

  @override
  void dispose() {
    _realtimeStatusSub?.cancel();
    _realtimeNearbySub?.cancel();
    _realtimeReconnectSub?.cancel();
    final effectiveRideId = widget.rideId ?? RideService.lastCreatedRideId;
    if (effectiveRideId != null && effectiveRideId.isNotEmpty) {
      RealtimeService().leaveRide(effectiveRideId);
    }
    _autoMatchTimer?.cancel();
    _nearbyPollTimer?.cancel();
    _rideStatusPollTimer?.cancel();
    _radarController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _measureBottomSheet() {
    final renderBox =
        _bottomSheetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize && mounted) {
      final h = renderBox.size.height;
      if ((_bottomSheetHeight - h).abs() > 3) {
        setState(() {
          _bottomSheetHeight = h;
        });
      }
    }
  }

  /// Vérifie le statut de la course via GET /v1/rides/{id}
  Future<void> _checkRideStatus(String rideId) async {
    try {
      final data = await _rideService.getRideDetails(rideId);
      if (data != null && mounted) {
        final status = (data['status'] as String? ?? '').toUpperCase();
        if (status == 'ACCEPTED' ||
            status == 'DRIVER_ARRIVED' ||
            status == 'IN_PROGRESS' ||
            data['driver'] != null) {
          final driver = DriverModel.fromRideJson(
            data,
            defaultRideType: widget.rideOption.type,
          );
          final code = DriverModel.extractDepartureCode(data);

          final rideObj = data['ride'] is Map<String, dynamic>
              ? data['ride'] as Map<String, dynamic>
              : data;
          List<LatLng>? updatedTripPolyline;
          final plannedPolyStr = rideObj['plannedPolyline'] as String?;
          if (plannedPolyStr != null && plannedPolyStr.isNotEmpty) {
            final decoded = RouteService.decodePolyline(plannedPolyStr);
            if (decoded.length >= 2) {
              updatedTripPolyline = decoded;
            }
          }

          onDriverFound(
            driver,
            code,
            rideId,
            updatedTripPolyline,
          );
        } else if (status.startsWith('CANCELLED') || status == 'NO_DRIVER') {
          _rideStatusPollTimer?.cancel();
          onNoDriverAvailable();
        }
      }
    } catch (e) {
      debugPrint('[DriverSearchPage] ⚠️ Erreur polling statut course: $e');
    }
  }

  Future<void> _loadCustomMarkers() async {
    final pickup = await MapMarkerHelper.getDeparturePinMarker();
    final dest = await MapMarkerHelper.getDestinationPinMarker();
    final car = await MapMarkerHelper.get3DCarMarker();

    if (mounted) {
      setState(() {
        _destPinIcon = dest;
        _pickupPinIcon = pickup;
        _carMarkerIcon = car;
      });
    }
  }

  /// Récupère les vraies voitures disponibles autour du point de départ via GET /v1/drivers/nearby
  Future<void> _loadNearbyDrivers() async {
    try {
      final result = await _rideService.getNearbyDrivers(
        lat: widget.departure.latitude,
        lng: widget.departure.longitude,
      );

      if (result != null && mounted) {
        final isEco = widget.rideOption.type == RideType.eco;
        final categoryCars = isEco ? result.ecoCars : result.confortCars;
        final categoryCount = isEco ? result.ecoCount : result.confortCount;

        setState(() {
          _nearbyCars = categoryCars.isNotEmpty ? categoryCars : result.allCars;
          _nearbyDriversCount =
              categoryCount > 0 ? categoryCount : result.allCars.length;
        });
      }
    } catch (_) {}
  }

  void onDriverFound([
    DriverModel? matchedDriver,
    String? code,
    String? rideId,
    List<LatLng>? tripPolyline,
  ]) {
    _autoMatchTimer?.cancel();
    _rideStatusPollTimer?.cancel();
    final driver = matchedDriver ??
        DriverModel.mockDakarDriver(
          rideType: widget.rideOption.type,
          location: LatLng(
            widget.departure.latitude + 0.0035,
            widget.departure.longitude + 0.0030,
          ),
        );

    final effectiveRideId =
        rideId ?? widget.rideId ?? RideService.lastCreatedRideId;

    Navigator.of(context).pushReplacement(
      SlideRightToLeftRoute(
        page: DriverApproachingPage(
          departure: widget.departure,
          destination: widget.destination,
          rideOption: widget.rideOption,
          driver: driver,
          polylinePoints: tripPolyline ?? widget.polylinePoints,
          departureCode: code ?? '4821',
          rideId: effectiveRideId,
          rideService: widget.rideService,
          autoStartSimulation: false,
        ),
      ),
    );
  }

  Future<void> _onCancelRide() async {
    final selectedReason = await CancelRideReasonSheet.show(
      context,
      isDriverAssigned: false,
    );

    if (selectedReason == null || !mounted) return;

    _autoMatchTimer?.cancel();
    _rideStatusPollTimer?.cancel();

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

  /// Prêt pour l'API : appelé lorsque le backend signale qu'aucun chauffeur n'est disponible
  @visibleForTesting
  Future<void> onNoDriverAvailable() async {
    _autoMatchTimer?.cancel();
    _rideStatusPollTimer?.cancel();
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
    final center = LatLng(
      widget.departure.latitude,
      widget.departure.longitude,
    );

    final t1 = _radarController.value;
    final t2 = (t1 + 0.5) % 1.0;

    final progress1 = Curves.easeOut.transform(t1);
    final progress2 = Curves.easeOut.transform(t2);

    final radius1 = 15.0 + (progress1 * 125.0);
    final alpha1 = (1.0 - progress1) * 0.35;

    final radius2 = 15.0 + (progress2 * 125.0);
    final alpha2 = (1.0 - progress2) * 0.35;

    return {
      // Core glowing anchor at departure
      Circle(
        circleId: const CircleId('radar_core'),
        center: center,
        radius: 10.0,
        fillColor: AppColors.primary.withValues(alpha: 0.40),
        strokeColor: AppColors.primary,
        strokeWidth: 2,
        zIndex: 3,
      ),
      // Pulsatile Wave 1
      Circle(
        circleId: const CircleId('radar_pulse_1'),
        center: center,
        radius: radius1,
        fillColor: AppColors.primary.withValues(alpha: alpha1),
        strokeColor: AppColors.primary.withValues(alpha: alpha1 * 1.8),
        strokeWidth: 2,
        zIndex: 1,
      ),
      // Pulsatile Wave 2
      Circle(
        circleId: const CircleId('radar_pulse_2'),
        center: center,
        radius: radius2,
        fillColor: AppColors.primary.withValues(alpha: alpha2),
        strokeColor: AppColors.primary.withValues(alpha: alpha2 * 1.8),
        strokeWidth: 2,
        zIndex: 2,
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
          zIndexInt: 10,
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
          zIndexInt: 10,
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
          zIndexInt: 10,
        ),
      );
    }

    // 3. Real nearby cars from GET /v1/drivers/nearby (waiting for driver acceptance)
    if (_carMarkerIcon != null && _nearbyCars.isNotEmpty) {
      for (final car in _nearbyCars) {
        markers.add(
          Marker(
            markerId: MarkerId('nearby_car_${car.id}'),
            position: LatLng(car.lat, car.lng),
            icon: _carMarkerIcon!,
            rotation: car.heading,
            anchor: const Offset(0.5, 0.5),
            flat: true,
            zIndexInt: 5,
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
          // 1. Google Map en gros plan (zoom 17.2) verrouillé sur le point de départ
          IgnorePointer(
            ignoring: true,
            child: GoogleMap(
              style: MapStyleService.style,
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  widget.departure.latitude,
                  widget.departure.longitude,
                ),
                zoom: 17.2,
              ),
              buildingsEnabled: false,
              onMapCreated: (ctrl) {
                _mapController = ctrl;
                MapStyleService.applyStyle(ctrl);
                ctrl.moveCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(
                        widget.departure.latitude,
                        widget.departure.longitude,
                      ),
                      zoom: 17.2,
                    ),
                  ),
                );
              },
              circles: _buildRadarCircles(),
              markers: _buildMarkers(),
              polylines: _buildPolylines(),
              scrollGesturesEnabled: false,
              zoomGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),

          // 2. Indicateur discret de reconnexion WebSocket (PDF page 7)
          const SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: RealtimeStatusIndicator(),
            ),
          ),

          // 3. Floating Top Back Button
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
              key: _bottomSheetKey,
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

                  // Tile 1: Paiement reçu ou Paiement en espèces
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
                        child: Icon(
                          widget.paymentMethod == PaymentMethodType.cash
                              ? Icons.payments_outlined
                              : Icons.check_rounded,
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
                              widget.paymentMethod == PaymentMethodType.cash
                                  ? 'ride.payment_cash_due'.tr(args: [widget.rideOption.formattedPrice])
                                  : 'ride.payment_received'.tr(args: [widget.rideOption.formattedPrice]),
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.paymentMethod == PaymentMethodType.cash
                                  ? 'ride.pay_driver_on_arrival'.tr()
                                  : 'ride.refund_guarantee'.tr(),
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
                              _nearbyDriversCount != null
                                  ? (_nearbyDriversCount! > 0
                                      ? 'ride.drivers_around_count'.tr(args: ['$_nearbyDriversCount', rideTypeLabel])
                                      : 'ride.searching_drivers_type'.tr(args: [rideTypeLabel]))
                                  : 'ride.drivers_around_type'
                                      .tr(args: [rideTypeLabel]),
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
