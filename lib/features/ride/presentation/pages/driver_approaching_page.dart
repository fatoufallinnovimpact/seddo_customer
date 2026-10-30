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
import 'package:seddo/features/ride/data/models/ride_quote_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/pages/active_ride_page.dart';
import 'package:seddo/features/ride/presentation/pages/driver_chat_page.dart';
import 'package:seddo/features/ride/presentation/pages/in_app_call_page.dart';
import 'package:seddo/features/ride/presentation/pages/ride_cancelled_page.dart';
import 'package:seddo/features/ride/presentation/pages/shared_ride_tracking_page.dart';
import 'package:seddo/features/ride/presentation/widgets/cancel_ride_reason_sheet.dart';
import 'package:seddo/features/home/presentation/widgets/map_marker_helper.dart';
import 'package:seddo/features/ride/data/services/ride_eta_calculator.dart';
import 'package:seddo/features/ride/presentation/widgets/realtime_status_indicator.dart';
import 'package:seddo/features/safety/presentation/widgets/safety_modal_widget.dart';
import 'package:seddo/services/map_style_service.dart';
import 'package:seddo/services/realtime_service.dart';
import 'package:seddo/services/route_service.dart';
import 'package:seddo/features/ride/presentation/utils/vehicle_color_helper.dart';
import 'package:share_plus/share_plus.dart';

/// Écran affiché lorsque le chauffeur est en approche vers le point de départ :
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
    with TickerProviderStateMixin {
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

  // Real road approach route and ETA calculation state (Seddo Note technique)
  List<LatLng> _approachRoutePoints = [];
  List<TrafficSegmentModel> _approachTraffic = [];
  List<LatLng> _tripPolylinePoints = [];
  List<TrafficSegmentModel> _tripTraffic = [];
  int _totalApproachM = 0;
  int _totalApproachS = 0;
  double _remainingDistanceM = 0.0;
  int _currentApproachIndex = 0;
  String _currentEtaLabel = '4 min';

  // Live Ride & Driver State synchronisés avec GET /v1/rides/{id}
  late DriverModel _currentDriver;
  late String _departureCode;
  late RideService _rideService;
  Timer? _ridePollTimer;

  // Realtime Socket.IO streams & smooth movement (PDF Seddo : 4s interpolation)
  AnimationController? _smoothCarController;
  LatLng? _animStartPos;
  LatLng? _animEndPos;
  double? _animStartHeading;
  double? _animEndHeading;

  StreamSubscription<RealtimeRideStatusEvent>? _realtimeStatusSub;
  StreamSubscription<RealtimeDriverLocationEvent>? _realtimeLocationSub;
  StreamSubscription<RealtimeRideEtaEvent>? _realtimeEtaSub;
  StreamSubscription<RealtimeRideRouteEvent>? _realtimeRouteSub;
  StreamSubscription<void>? _realtimeReconnectSub;

  DateTime _lastDriverLocationTime = DateTime.now();
  Timer? _stalePositionCheckTimer;
  bool _isPositionUpdating = false;

  late final AnimationController _sheetAnimationController;
  BitmapDescriptor? _destinationMarkerIcon;

  @override
  void initState() {
    super.initState();

    _currentDriver = widget.driver;
    _departureCode = widget.departureCode;
    _rideService = widget.rideService ?? RideService();
    _tripPolylinePoints = List.from(widget.polylinePoints);
    _tripTraffic = List.from(widget.rideOption.traffic);
    _approachTraffic = List.from(_currentDriver.approachTraffic);
    _sheetAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );

    final initialEtaS = _currentDriver.approachDurationS ??
        widget.rideOption.pickupEtaS ??
        240;
    _totalApproachS = initialEtaS;
    _remainingEtaMinutes = (initialEtaS / 60.0).ceil();
    _currentEtaLabel = '$_remainingEtaMinutes min';

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
    _currentCarHeading = _currentDriver.heading ??
        _calculateBearing(_driverInitialPosition, _pickupPosition);

    // Initialisation immédiate de l'itinéraire routier d'approche s'il est déjà fourni
    if (_currentDriver.approachPolyline != null &&
        _currentDriver.approachPolyline!.isNotEmpty) {
      final decoded =
          RouteService.decodePolyline(_currentDriver.approachPolyline!);
      if (decoded.length >= 2) {
        _approachRoutePoints = decoded;
        if (_currentDriver.approachDistanceM != null &&
            _currentDriver.approachDistanceM! > 0) {
          _totalApproachM = _currentDriver.approachDistanceM!;
        }
      }
    }

    _loadCustomMarkers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadApproachRoute();
      }
    });

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

    // Contrôleur de déplacement fluide de la voiture (interpolation 4 secondes - PDF Seddo)
    _smoothCarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(() {
        if (_animStartPos != null && _animEndPos != null && mounted) {
          final t = _smoothCarController!.value;
          final curLat = _animStartPos!.latitude +
              (_animEndPos!.latitude - _animStartPos!.latitude) * t;
          final curLng = _animStartPos!.longitude +
              (_animEndPos!.longitude - _animStartPos!.longitude) * t;

          double curHead = _currentCarHeading;
          if (_animStartHeading != null && _animEndHeading != null) {
            curHead = _animStartHeading! +
                (_animEndHeading! - _animStartHeading!) * t;
          }

          final newPos = LatLng(curLat, curLng);
          setState(() {
            _currentCarPosition = newPos;
            _currentCarHeading = curHead;
          });
          _updateEtaAndDistance(newPos);
        }
      });

    if (widget.autoStartSimulation && !isTest) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          _approachController?.forward();
        }
      });
    }

    final effectiveRideId = widget.rideId ?? RideService.lastCreatedRideId;
    if (effectiveRideId != null && effectiveRideId.isNotEmpty) {
      // 1. Appel REST initial pour obtenir l'état complet
      _fetchRideDetails(effectiveRideId);

      // 2. Connexion WebSocket unique et adhésion au canal ride:{id}
      RealtimeService().connect();
      RealtimeService().joinRide(effectiveRideId);

      // Écoute du statut de la course (ride.status)
      _realtimeStatusSub = RealtimeService().rideStatusStream.listen((event) {
        if (!mounted) return;
        if (event.rideId.isEmpty || event.rideId == effectiveRideId) {
          _handleRealtimeRideStatus(event);
        }
      });

      // Écoute de la position GPS du chauffeur (driver.location)
      _realtimeLocationSub = RealtimeService().driverLocationStream.listen((event) {
        if (!mounted) return;
        if (event.rideId == null || event.rideId == effectiveRideId) {
          _handleRealtimeDriverLocation(event);
        }
      });

      // Écoute du temps restant estimé (ride.eta)
      _realtimeEtaSub = RealtimeService().rideEtaStream.listen((event) {
        if (!mounted) return;
        if (event.rideId == null || event.rideId == effectiveRideId) {
          _handleRealtimeEta(event);
        }
      });

      // Écoute des mises à jour d'itinéraire (ride.route.updated)
      _realtimeRouteSub = RealtimeService().rideRouteStream.listen((event) {
        if (!mounted) return;
        if (event.rideId == null || event.rideId == effectiveRideId) {
          _handleRealtimeRoute(event);
        }
      });

      // Resynchronisation REST dès reconnexion (PDF page 7 & 8)
      _realtimeReconnectSub = RealtimeService().onReconnect.listen((_) {
        if (mounted) {
          _fetchRideDetails(effectiveRideId);
        }
      });

      // Fallback passif si le WebSocket est temporairement déconnecté (sans polling intensif)
      if (!isTest) {
        _ridePollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
          if (!RealtimeService().isConnected) {
            _fetchRideDetails(effectiveRideId);
          }
        });
      }
    }

    // Détection d'absence de position > 30s (PDF page 8 & 9)
    _stalePositionCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_driverArrived) {
        final elapsed =
            DateTime.now().difference(_lastDriverLocationTime).inSeconds;
        if (elapsed >= 30 && !_isPositionUpdating) {
          setState(() {
            _isPositionUpdating = true;
          });
        } else if (elapsed < 30 && _isPositionUpdating) {
          setState(() {
            _isPositionUpdating = false;
          });
        }
      }
    });
  }

  void _handleRealtimeRideStatus(RealtimeRideStatusEvent event) {
    final status = event.status;
    if (status.startsWith('CANCELLED') ||
        status == 'NO_DRIVER' ||
        status == 'NO_SHOW') {
      _cleanupTimersAndSubs();
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

    if (status == 'IN_PROGRESS') {
      _cleanupTimersAndSubs();
      startRide();
      return;
    }

    if (status == 'DRIVER_ARRIVED' || status == 'ARRIVED') {
      setState(() {
        _driverArrived = true;
        _isPositionUpdating = false;
        _setEtaLabel('ride.arrived'.tr(), 0);
      });
    }

    if (event.departureCode != null && event.departureCode!.isNotEmpty) {
      setState(() {
        _departureCode = event.departureCode!;
      });
    }

    if (event.driver != null) {
      setState(() {
        _currentDriver = event.driver!;
      });
    }
  }

  void _handleRealtimeDriverLocation(RealtimeDriverLocationEvent event) {
    if (event.location.latitude == 0 && event.location.longitude == 0) return;

    _lastDriverLocationTime = DateTime.now();
    if (_isPositionUpdating) {
      setState(() {
        _isPositionUpdating = false;
      });
    }

    final heading = event.heading != 0.0
        ? event.heading
        : _calculateBearing(_currentCarPosition, event.location);

    updateDriverGpsLocation(event.location, heading: heading);
  }

  void _handleRealtimeEta(RealtimeRideEtaEvent event) {
    if (_driverArrived) return;
    if (event.etaMinutes > 0) {
      _setEtaLabel('${event.etaMinutes} min', event.etaMinutes);
    }
    if (event.distanceMeters != null && event.distanceMeters! > 0) {
      setState(() {
        _remainingDistanceM = event.distanceMeters!.toDouble();
      });
    }
  }

  void _handleRealtimeRoute(RealtimeRideRouteEvent event) {
    if (event.points.length >= 2) {
      setState(() {
        _approachRoutePoints = event.points;
        if (event.traffic.isNotEmpty) {
          _approachTraffic = event.traffic;
        }
      });
    }
  }

  void _cleanupTimersAndSubs() {
    _ridePollTimer?.cancel();
    _stalePositionCheckTimer?.cancel();
    _approachController?.stop();
    _smoothCarController?.stop();
    _realtimeStatusSub?.cancel();
    _realtimeLocationSub?.cancel();
    _realtimeEtaSub?.cancel();
    _realtimeRouteSub?.cancel();
    _realtimeReconnectSub?.cancel();
  }

  @override
  void dispose() {
    _cleanupTimersAndSubs();
    final effectiveRideId = widget.rideId ?? RideService.lastCreatedRideId;
    if (effectiveRideId != null && effectiveRideId.isNotEmpty) {
      RealtimeService().leaveRide(effectiveRideId);
    }
    _approachController?.dispose();
    _smoothCarController?.dispose();
    _sheetAnimationController.dispose();
    _mapController?.dispose();
    super.dispose();
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

    final rideObj = data['ride'] is Map<String, dynamic>
        ? data['ride'] as Map<String, dynamic>
        : data;

    final status = (rideObj['status'] as String? ?? '').toUpperCase();
    final routeObj = rideObj['route'] is Map<String, dynamic>
        ? rideObj['route'] as Map<String, dynamic>
        : null;
    final phase = (routeObj?['phase'] as String? ?? '').toUpperCase();
    final startedAt = rideObj['startedAt'];
    final arrivedAt = rideObj['arrivedAt'];

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
    // Uniquement quand status == 'IN_PROGRESS' ou phase == 'TRIP' ou startedAt non nul
    final isTripStarted = (status == 'IN_PROGRESS' ||
            phase == 'TRIP' ||
            (startedAt != null && startedAt.toString().isNotEmpty)) &&
        phase != 'APPROACH';

    if (isTripStarted) {
      _ridePollTimer?.cancel();
      _approachController?.stop();
      startRide();
      return;
    }

    // 3. Extraction du vrai code de départ retourné par l'API
    final newCode =
        DriverModel.extractDepartureCode(data, fallback: _departureCode);

    // 4. Extraction du vrai chauffeur retourné par l'API (avec position, heading et infos véhicule)
    final hasDriver = rideObj['driver'] != null || rideObj['carModel'] != null;
    DriverModel updatedDriver = _currentDriver;
    if (hasDriver) {
      updatedDriver = DriverModel.fromRideJson(
        data,
        defaultRideType: widget.rideOption.type,
      );
    }

    // 5. Statut d'arrivée du chauffeur
    final isArrived = status == 'DRIVER_ARRIVED' ||
        status == 'ARRIVED' ||
        (arrivedAt != null && arrivedAt.toString().isNotEmpty);
    if (routeObj != null) {
      final polylineStr = routeObj['polyline'] as String?;
      if (polylineStr != null && polylineStr.isNotEmpty) {
        final pts = RouteService.decodePolyline(polylineStr);
        if (pts.length >= 2) {
          _approachRoutePoints = pts;
        }
      }
      final durS = (routeObj['durationS'] as num?)?.toInt();
      if (durS != null && durS > 0) {
        _totalApproachS = durS;
      }
      final distM = (routeObj['distanceM'] as num?)?.toInt();
      if (distM != null && distM > 0) {
        _totalApproachM = distM;
      }
      final rawTraffic = routeObj['traffic'] as List<dynamic>?;
      if (rawTraffic != null) {
        _approachTraffic = rawTraffic
            .whereType<Map<String, dynamic>>()
            .map((item) => TrafficSegmentModel.fromJson(item))
            .toList();
      }
    }

    // 7. Polyline et trafic de la course prévus (plannedPolyline & plannedTraffic)
    final plannedPolyStr = rideObj['plannedPolyline'] as String?;
    if (plannedPolyStr != null && plannedPolyStr.isNotEmpty) {
      final tripPts = RouteService.decodePolyline(plannedPolyStr);
      if (tripPts.length >= 2) {
        _tripPolylinePoints = tripPts;
      }
    }
    final rawPlannedTraffic = rideObj['plannedTraffic'] as List<dynamic>?;
    if (rawPlannedTraffic != null) {
      _tripTraffic = rawPlannedTraffic
          .whereType<Map<String, dynamic>>()
          .map((item) => TrafficSegmentModel.fromJson(item))
          .toList();
    }

    // 8. Temps d'approche restant (ETA)
    final int? etaSecondsFromApi = (routeObj != null && routeObj['durationS'] != null)
        ? (routeObj['durationS'] as num).toInt()
        : ((rideObj['etaMinutes'] as num?)?.toInt() != null
            ? (rideObj['etaMinutes'] as num).toInt() * 60
            : null);

    final etaFromApi = etaSecondsFromApi != null && etaSecondsFromApi > 0
        ? (etaSecondsFromApi / 60.0).ceil()
        : null;

    setState(() {
      _departureCode = newCode;
      _currentDriver = updatedDriver;
    });

    if (isArrived) {
      _driverArrived = true;
      _setEtaLabel('ride.arrived'.tr(), 0);
    } else if (etaFromApi != null && etaFromApi > 0) {
      _setEtaLabel('$etaFromApi min', etaFromApi);
    }

    // Synchronisation de la position GPS en temps réel
    if (updatedDriver.currentLocation.latitude != 0 &&
        updatedDriver.currentLocation.longitude != 0 &&
        (updatedDriver.currentLocation.latitude !=
                _currentCarPosition.latitude ||
            updatedDriver.currentLocation.longitude !=
                _currentCarPosition.longitude)) {
      final heading = updatedDriver.heading ??
          _calculateBearing(
              _currentCarPosition, updatedDriver.currentLocation);
      _currentCarPosition = updatedDriver.currentLocation;
      _currentCarHeading = heading;
      _updateEtaAndDistance(
        updatedDriver.currentLocation,
        overrideEtaSeconds: etaSecondsFromApi,
      );

      // Si aucun polyline backend n'est fourni et qu'on n'a pas encore de tracé, charger la route
      if (_approachRoutePoints.isEmpty) {
        _loadApproachRoute();
      }
    } else if (etaSecondsFromApi != null && _approachRoutePoints.isNotEmpty) {
      _updateEtaAndDistance(
        _currentCarPosition,
        overrideEtaSeconds: etaSecondsFromApi,
      );
    }
  }

  /// Charge l'itinéraire routier réel entre la position du chauffeur et le point de départ
  Future<void> _loadApproachRoute() async {
    // Si l'itinéraire routier réel a déjà été initialisé (ex. depuis l'API backend), ne pas l'écraser
    if (_approachRoutePoints.length >= 2) return;

    final bool isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest) {
      _setupFallbackApproachRoute();
      return;
    }
    try {
      final routeDetails = await RouteService().getRoute(
        origin: _currentCarPosition,
        destination: _pickupPosition,
      );
      if (routeDetails.polylinePoints.length >= 2 && mounted) {
        final totalMeters = (routeDetails.distanceKm * 1000).round();
        final calculatedMeters = RideEtaCalculator.remainingMeters(
          routeDetails.polylinePoints,
          0,
          _currentCarPosition,
        ).round();

        setState(() {
          _approachRoutePoints = routeDetails.polylinePoints;
          _totalApproachM = totalMeters > 0 ? totalMeters : calculatedMeters;
          if (_totalApproachS <= 0) {
            _totalApproachS = routeDetails.durationMinutes * 60;
          }
        });
        _updateEtaAndDistance(_currentCarPosition);
        return;
      }
    } catch (e) {
      debugPrint('[DriverApproachingPage] ⚠️ Erreur getRoute approach: $e');
    }

    if (mounted) {
      _setupFallbackApproachRoute();
    }
  }

  void _setupFallbackApproachRoute() {
    // Suit impérativement les axes routiers en grille (ne coupe jamais en diagonale à travers les bâtiments)
    final streetRoute = RouteService().getStreetAlignedRoute(
      _currentCarPosition,
      _pickupPosition,
    );
    final points = streetRoute.polylinePoints;
    final calculatedMeters = RideEtaCalculator.remainingMeters(
      points,
      0,
      _currentCarPosition,
    ).round();

    setState(() {
      _approachRoutePoints = points;
      _totalApproachM = calculatedMeters > 0 ? calculatedMeters : 1500;
      if (_totalApproachS <= 0) {
        _totalApproachS = streetRoute.durationMinutes * 60;
      }
    });
    _updateEtaAndDistance(_currentCarPosition);
  }

  /// Calcule en temps réel la distance restante et l'ETA le long de la ligne
  /// selon les formules de la note technique Seddo (Pages 2-4)
  void _updateEtaAndDistance(LatLng carPos, {int? overrideEtaSeconds}) {
    if (_approachRoutePoints.isEmpty) return;

    final idx = RideEtaCalculator.nearestIndex(
      _approachRoutePoints,
      carPos,
      _currentApproachIndex,
    );
    _currentApproachIndex = idx;

    final remM = RideEtaCalculator.remainingMeters(
      _approachRoutePoints,
      idx,
      carPos,
    );
    _remainingDistanceM = remM;

    final int remS;
    if (overrideEtaSeconds != null && overrideEtaSeconds > 0) {
      remS = overrideEtaSeconds;
    } else if (_totalApproachS > 0 && _totalApproachM > 0) {
      final ratio = (remM / _totalApproachM).clamp(0.0, 1.0);
      remS = (_totalApproachS * ratio).round();
    } else if (_approachTraffic.isNotEmpty) {
      remS = RideEtaCalculator.weightedRemainingSeconds(
        pts: _approachRoutePoints,
        fromIndex: idx,
        driver: carPos,
        traffic: _approachTraffic,
        totalS: _totalApproachS > 0 ? _totalApproachS : 240,
        totalM: _totalApproachM > 0 ? _totalApproachM : remM.round(),
      );
    } else if (_tripTraffic.isNotEmpty) {
      remS = RideEtaCalculator.weightedRemainingSeconds(
        pts: _approachRoutePoints,
        fromIndex: idx,
        driver: carPos,
        traffic: _tripTraffic,
        totalS: _totalApproachS > 0 ? _totalApproachS : 240,
        totalM: _totalApproachM > 0 ? _totalApproachM : remM.round(),
      );
    } else if (widget.rideOption.traffic.isNotEmpty) {
      remS = RideEtaCalculator.weightedRemainingSeconds(
        pts: _approachRoutePoints,
        fromIndex: idx,
        driver: carPos,
        traffic: widget.rideOption.traffic,
        totalS: _totalApproachS > 0 ? _totalApproachS : 240,
        totalM: _totalApproachM > 0 ? _totalApproachM : remM.round(),
      );
    } else {
      remS = RideEtaCalculator.remainingSeconds(
        remainingM: remM,
        totalM: _totalApproachM > 0 ? _totalApproachM : remM.round(),
        totalS: _totalApproachS > 0 ? _totalApproachS : 240,
      );
    }

    final label = RideEtaCalculator.etaLabel(remS, remM);
    final remainingMinutes = (remS / 60.0).ceil();

    _setEtaLabel(label, remainingMinutes);

    if (remM < 50 && !_driverArrived) {
      _onDriverReachedPickup();
    }
  }

  /// Met à jour de façon strictement synchrone le libellé ETA du modal et le marqueur visuel sur la carte
  void _setEtaLabel(String newLabel, int remainingMinutes) {
    if (!mounted) return;
    final bool changed = _currentEtaLabel != newLabel ||
        _remainingEtaMinutes != remainingMinutes ||
        _etaPillMarkerIcon == null;

    setState(() {
      _currentEtaLabel = newLabel;
      _remainingEtaMinutes = remainingMinutes;
    });

    if (changed) {
      MapMarkerHelper.getEtaPillMarker(newLabel).then((markerIcon) {
        if (mounted) {
          setState(() {
            _etaPillMarkerIcon = markerIcon;
          });
        }
      });
    }
  }

  Future<void> _loadCustomMarkers() async {
    final carColor = VehicleColorHelper.parseColor(_currentDriver.carColor);
    final car = await MapMarkerHelper.get3DCarMarker(color: carColor);
    final pickup = await MapMarkerHelper.getRendezVousIciMarker();
    final eta = await MapMarkerHelper.getEtaPillMarker(_currentEtaLabel);
    final dest = await MapMarkerHelper.getDestinationPinMarker();

    if (mounted) {
      setState(() {
        _carMarkerIcon = car;
        _rendezVousIciMarkerIcon = pickup;
        _etaPillMarkerIcon = eta;
        _destinationMarkerIcon = dest;
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

    final progress = Curves.easeInOut.transform(t);

    final LatLng newPos;
    final double heading;

    if (_approachRoutePoints.length >= 2) {
      final totalSegments = _approachRoutePoints.length - 1;
      final floatIndex = progress * totalSegments;
      final lowerIndex = floatIndex.floor().clamp(0, totalSegments - 1);
      final segT = floatIndex - lowerIndex;
      final p1 = _approachRoutePoints[lowerIndex];
      final p2 = _approachRoutePoints[lowerIndex + 1];

      final lat = p1.latitude + (p2.latitude - p1.latitude) * segT;
      final lng = p1.longitude + (p2.longitude - p1.longitude) * segT;
      newPos = LatLng(lat, lng);
      heading = _calculateBearing(p1, p2);
    } else {
      newPos = _currentCarPosition;
      heading = _currentCarHeading;
    }

    setState(() {
      _currentCarPosition = newPos;
      _currentCarHeading = heading;
    });

    _updateEtaAndDistance(newPos);
  }

  void _onDriverReachedPickup() {
    if (!mounted) return;
    _setEtaLabel('ride.arrived'.tr(), 0);
    setState(() {
      _driverArrived = true;
      _totalApproachS = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
    });
  }

  /// Méthode publique prête pour connecter l'API backend / WebSocket en direct :
  /// Appelée lorsque le chauffeur accepte et se déplace vers le point de départ
  void updateDriverGpsLocation(LatLng position, {double? heading}) {
    if (_approachController != null && _approachController!.isAnimating) {
      _approachController!.stop();
    }
    _smoothCarController?.stop();

    final calcHeading =
        heading ?? _calculateBearing(_currentCarPosition, position);

    // Si la position a très peu changé (< 1m), mise à jour instantanée
    if ((_currentCarPosition.latitude - position.latitude).abs() < 0.00001 &&
        (_currentCarPosition.longitude - position.longitude).abs() < 0.00001) {
      setState(() {
        _currentCarPosition = position;
        _currentCarHeading = calcHeading;
      });
      _updateEtaAndDistance(position);
      return;
    }

    _animStartPos = _currentCarPosition;
    _animEndPos = position;
    _animStartHeading = _currentCarHeading;
    _animEndHeading = calcHeading;

    _smoothCarController?.forward(from: 0.0);
  }

  /// Démarre la course vers la destination (transition vers ActiveRidePage)
  void startRide() {
    _cleanupTimersAndSubs();
    final effectiveRideId = widget.rideId ?? RideService.lastCreatedRideId;
    if (effectiveRideId != null && effectiveRideId.isNotEmpty) {
      RealtimeService().leaveRide(effectiveRideId);
    }
    final effectiveTripOption = _tripTraffic.isNotEmpty
        ? widget.rideOption.copyWith(traffic: _tripTraffic)
        : widget.rideOption;
    final effectivePolyline = _tripPolylinePoints.isNotEmpty
        ? _tripPolylinePoints
        : widget.polylinePoints;

    Navigator.of(context).pushReplacement(
      SlideRightToLeftRoute(
        page: ActiveRidePage(
          departure: widget.departure,
          destination: widget.destination,
          rideOption: effectiveTripOption,
          driver: _currentDriver,
          polylinePoints: effectivePolyline,
          autoStartSimulation: false,
          rideId: widget.rideId ?? RideService.lastCreatedRideId,
          rideService: _rideService,
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

  Future<void> _openShare() async {
    final effectiveRideId =
        widget.rideId ?? RideService.lastCreatedRideId ?? 'current';

    final effectivePolyline = _tripPolylinePoints.isNotEmpty
        ? _tripPolylinePoints
        : widget.polylinePoints;

    // Open SharedRideTrackingPage immediately
    Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: SharedRideTrackingPage(
          departure: widget.departure,
          destination: widget.destination,
          driver: _currentDriver,
          polylinePoints: effectivePolyline,
          etaText: '$_remainingEtaMinutes min',
          rideId: effectiveRideId,
          rideService: _rideService,
        ),
      ),
    );

    // Call POST /v1/rides/{id}/share and trigger native share sheet
    try {
      final result = await _rideService.shareRide(effectiveRideId);
      final shareUrl = (result != null && result.url.isNotEmpty)
          ? result.url
          : 'https://suivi.seddo.sn/t/8K02F';
      final shareText =
          'Suis mon trajet Seddo en direct vers ${widget.destination.mainText} avec ${_currentDriver.name} (${_currentDriver.carModel} ${_currentDriver.licensePlate}) : $shareUrl';
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: 'Mon trajet Seddo en direct',
        ),
      );
    } catch (_) {}
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
      double minLat = math.min(
          _pickupPosition.latitude, _currentCarPosition.latitude);
      double maxLat = math.max(
          _pickupPosition.latitude, _currentCarPosition.latitude);
      double minLng = math.min(
          _pickupPosition.longitude, _currentCarPosition.longitude);
      double maxLng = math.max(
          _pickupPosition.longitude, _currentCarPosition.longitude);

      if (_approachRoutePoints.length >= 2) {
        for (final p in _approachRoutePoints) {
          if (p.latitude < minLat) minLat = p.latitude;
          if (p.latitude > maxLat) maxLat = p.latitude;
          if (p.longitude < minLng) minLng = p.longitude;
          if (p.longitude > maxLng) maxLng = p.longitude;
        }
      }

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

    // 3. Floating "4 min" pill marker along the real road approach line
    if (_etaPillMarkerIcon != null && !_driverArrived) {
      final LatLng markerPos;
      if (_approachRoutePoints.length >= 2) {
        final midIdx =
            (_currentApproachIndex + _approachRoutePoints.length) ~/ 2;
        markerPos = _approachRoutePoints[
            midIdx.clamp(0, _approachRoutePoints.length - 1)];
      } else {
        final midLat =
            (_currentCarPosition.latitude + _pickupPosition.latitude) / 2;
        final midLng =
            (_currentCarPosition.longitude + _pickupPosition.longitude) / 2;
        markerPos = LatLng(midLat, midLng);
      }
      markers.add(
        Marker(
          markerId: const MarkerId('approach_eta_pill'),
          position: markerPos,
          icon: _etaPillMarkerIcon!,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 6,
        ),
      );
    }

    // 4. Destination Pin Marker (Arrivée)
    if (_destinationMarkerIcon != null &&
        widget.destination.latitude != 0 &&
        widget.destination.longitude != 0) {
      markers.add(
        Marker(
          markerId: const MarkerId('trip_destination_pin'),
          position: LatLng(
            widget.destination.latitude,
            widget.destination.longitude,
          ),
          icon: _destinationMarkerIcon!,
          anchor: const Offset(0.5, 1.0),
          zIndexInt: 4,
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
    final polylines = <Polyline>{};

    // 1. Tracé routier réel de l'approche du chauffeur vers le point de départ
    // Ligne continue (non en pointillé) aux couleurs du trafic réel (route.traffic) :
    // - Vert (#00C853) pour trafic fluide NORMAL
    // - Jaune ambre (#F59E0B) pour trafic ralenti SLOW
    // - Rouge (#DC2626) pour bouchon JAM
    // Pendant la phase d'approche, on affiche EXCLUSIVEMENT ce tracé sur les vraies routes.
    // Le tracé vers la destination finale ne sera affiché que lors du démarrage effectif de la course (ActiveRidePage).
    if (_approachRoutePoints.length >= 2) {
      final trafficPolylines = RideEtaCalculator.buildTrafficPolylines(
        baseId: 'approach_traffic_route',
        points: _approachRoutePoints,
        traffic: _approachTraffic,
        startIndex: _currentApproachIndex,
        currentCarPosition:
            _currentApproachIndex > 0 ? _currentCarPosition : null,
        width: 5,
        zIndexBase: 4,
      );
      polylines.addAll(trafficPolylines);
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

    final etaDisplay = _isPositionUpdating
        ? 'ride.position_updating'.tr()
        : (_driverArrived ||
                (_remainingDistanceM > 0 && _remainingDistanceM < 50)
            ? 'ride.arrived'.tr()
            : _currentEtaLabel);

    final digits = _departureCode.padRight(4, '0').split('');

    final collapsedHeightPx = 180.0 + (systemBottom > 0 ? systemBottom : 12.0);
    final expandedHeightPx = 430.0 + (systemBottom > 0 ? systemBottom : 16.0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // Course en cours / chauffeur en approche : retour désactivé
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // Indicateur discret de reconnexion WebSocket (PDF page 7)
          const SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: RealtimeStatusIndicator(),
            ),
          ),

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
              style: MapStyleService.style,
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
                bottom: 240,
                top: 70,
                left: 16,
                right: 16,
              ),
              buildingsEnabled: false,
              onMapCreated: (ctrl) {
                _mapController = ctrl;
                MapStyleService.applyStyle(ctrl);
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

          // 2. Bottom Sheet Draggable & Collapsible : glissement direct ultra-fluide
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedBuilder(
              animation: _sheetAnimationController,
              builder: (context, _) {
                final t = _sheetAnimationController.value;
                final isCollapsed = t < 0.45;
                final currentHeight = collapsedHeightPx +
                    (expandedHeightPx - collapsedHeightPx) * t;

                final titleText = _driverArrived
                    ? 'ride.arrived'.tr()
                    : (isCollapsed
                        ? 'Arrive dans $etaDisplay'
                        : 'Votre chauffeur arrive dans');

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) {
                    final totalDelta = expandedHeightPx - collapsedHeightPx;
                    if (totalDelta > 0) {
                      final delta = details.primaryDelta ?? 0.0;
                      _sheetAnimationController.value =
                          (_sheetAnimationController.value -
                                  (delta / totalDelta))
                              .clamp(0.0, 1.0);
                    }
                  },
                  onVerticalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0.0;
                    if (velocity > 250) {
                      // Glissement rapide vers le bas -> replier
                      _sheetAnimationController.animateTo(
                        0.0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                      );
                    } else if (velocity < -250) {
                      // Glissement rapide vers le haut -> déplier
                      _sheetAnimationController.animateTo(
                        1.0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                      );
                    } else {
                      // Rapprochement automatique vers l'état le plus proche
                      if (_sheetAnimationController.value < 0.5) {
                        _sheetAnimationController.animateTo(
                          0.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                        );
                      } else {
                        _sheetAnimationController.animateTo(
                          1.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: currentHeight,
                    clipBehavior: Clip.hardEdge,
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
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppConstants.spacingLg,
                            12,
                            AppConstants.spacingLg,
                            systemBottom > 0 ? 8 : 16,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Drag Handle + En-tête : Clic pour basculer replié/déplié
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (_sheetAnimationController.value > 0.5) {
                                    _sheetAnimationController.animateTo(
                                      0.0,
                                      duration: const Duration(milliseconds: 280),
                                      curve: Curves.easeOutCubic,
                                    );
                                  } else {
                                    _sheetAnimationController.animateTo(
                                      1.0,
                                      duration: const Duration(milliseconds: 280),
                                      curve: Curves.easeOutCubic,
                                    );
                                  }
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Center(
                                      child: Container(
                                        width: 44,
                                        height: 4.5,
                                        decoration: BoxDecoration(
                                          color: AppColors.dragHandle,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Header: Title & Remaining Time Pill
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                titleText,
                                                style: GoogleFonts.inter(
                                                  fontSize: 16.0,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.textPrimary,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                              if (_remainingDistanceM > 0 &&
                                                  !_driverArrived) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${'ride.approaching'.tr()} · ${RideEtaCalculator.formatRemainingDistance(_remainingDistanceM)}',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12.0,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),

                                        // Pill: 4 min avec icône horloge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 7.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius:
                                                BorderRadius.circular(20),
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
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // 2. Card 1: Véhicule & Chauffeur (Toujours visible en position descendue et montée)
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
                                    // 3D Car Image avec teinte dynamique selon l'API
                                    Builder(
                                      builder: (context) {
                                        final colorFilter = VehicleColorHelper.getColorFilter(_currentDriver.carColor);
                                        final carImg = Image.asset(
                                          widget.rideOption.type == RideType.confort
                                              ? 'assets/images/seddo_confort_3d.png'
                                              : 'assets/images/seddo_eco_3d.png',
                                          width: 74,
                                          height: 46,
                                          fit: BoxFit.contain,
                                        );
                                        if (colorFilter != null) {
                                          return ColorFiltered(
                                            colorFilter: colorFilter,
                                            child: carImg,
                                          );
                                        }
                                        return carImg;
                                      },
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // License Plate Badge [ DK 4521 AB ]
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.white,
                                              borderRadius:
                                                  BorderRadius.circular(5),
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
                                                  _currentDriver.name
                                                      .split(' ')
                                                      .first,
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
                                                _currentDriver.rating
                                                    .toStringAsFixed(1),
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

                              // 3. Cards 2, 3, 4 : affichées et animées en opacité
                              if (t > 0.05) ...[
                                Opacity(
                                  opacity: t,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(height: 10),

                                      // Card 2: Code de départ (PIN Code)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.orangeLightBg,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: AppColors.peachMedium,
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
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
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'ride.departure_code'.tr(),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 14.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'ride.give_to_driver'.tr(),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      color:
                                                          AppColors.textSecondary,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: digits.map((digit) {
                                                return Container(
                                                  width: 32,
                                                  height: 38,
                                                  margin: const EdgeInsets.only(
                                                      left: 5),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        AppColors.licensePlateBg,
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    digit,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 16.5,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: AppColors.white,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Card 3: Quick message + Circular call button
                                      Row(
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: _openChat,
                                              child: Container(
                                                height: 46,
                                                padding: const EdgeInsets
                                                    .symmetric(horizontal: 14),
                                                decoration: BoxDecoration(
                                                  color: AppColors.grayBgLight,
                                                  borderRadius:
                                                      BorderRadius.circular(23),
                                                ),
                                                child: Row(
                                                  children: [
                                                    SvgPicture.asset(
                                                      'assets/icons/message-square-lines-svgrepo-com.svg',
                                                      width: 20,
                                                      height: 20,
                                                      colorFilter:
                                                          const ColorFilter.mode(
                                                        AppColors.primary,
                                                        BlendMode.srcIn,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        'ride.send_message_hint'
                                                            .tr(),
                                                        style:
                                                            GoogleFonts.inter(
                                                          fontSize: 13.5,
                                                          color: AppColors
                                                              .textSecondary,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
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
                                                colorFilter:
                                                    const ColorFilter.mode(
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
                                      const SizedBox(height: 10),

                                      // Card 4: Action buttons row [ Partager ] [ Sécurité ] [ Annuler ]
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildActionButton(
                                              icon: Icons.share_outlined,
                                              label: 'common.share'.tr(),
                                              onTap: _openShare,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _buildActionButton(
                                              svgPath:
                                                  'assets/icons/security-svgrepo-com.svg',
                                              label: 'drawer.safety'.tr(),
                                              onTap: _openSafety,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
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
                              ],
                            ],
                          ),
                        ),
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
