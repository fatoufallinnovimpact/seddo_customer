import 'dart:async';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/services/ride_eta_calculator.dart';
import 'package:seddo/features/ride/presentation/pages/driver_chat_page.dart';
import 'package:seddo/features/ride/presentation/pages/in_app_call_page.dart';
import 'package:seddo/features/ride/presentation/pages/ride_rating_page.dart';
import 'package:seddo/features/ride/presentation/pages/ride_cancelled_page.dart';
import 'package:seddo/features/ride/presentation/pages/shared_ride_tracking_page.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/widgets/realtime_status_indicator.dart';
import 'package:seddo/services/map_style_service.dart';
import 'package:seddo/services/realtime_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:seddo/features/ride/presentation/utils/vehicle_color_helper.dart';
import 'package:seddo/features/ride/presentation/widgets/active_driver_card_widget.dart';
import 'package:seddo/features/ride/presentation/widgets/driver_action_buttons_widget.dart';
import 'package:seddo/features/ride/presentation/widgets/ride_map_camera_toggle_button.dart';
import 'package:seddo/features/home/presentation/widgets/map_marker_helper.dart';
import 'package:seddo/features/ride/presentation/widgets/offline_emergency_sheet.dart';
import 'package:seddo/features/ride/presentation/widgets/ride_action_tile_widget.dart';
import 'package:seddo/features/safety/presentation/widgets/safety_modal_widget.dart';

/// Screen displayed once a driver has accepted the ride matching Screenshot 1:
/// - Floating top bar with back button, center status, and red safety siren button
/// - Interactive map showing driver's car approaching or on route
/// - Header: "En route vers [Destination]" + ETA and distance
/// - Driver card with initials avatar, Moussa, ★ 4.9, car model, plate and "✓ Payé" badge
/// - Message & Appeler direct communication actions
/// - "Partager le trajet" with native share_plus sheet and web preview option
/// - "Sécurité" with 24/7 emergency dialer and location sharing
/// - "Annuler la course" with automatic Orange Money refund
/// - "Simuler : arrivée" shortcut opening RideRatingPage
class ActiveRidePage extends StatefulWidget {
  final PlaceSearchResult departure;
  final PlaceSearchResult destination;
  final RideOptionModel rideOption;
  final DriverModel driver;
  final List<LatLng> polylinePoints;
  final bool autoStartSimulation;
  final bool isOffline;
  final String? rideId;
  final RideService? rideService;

  const ActiveRidePage({
    super.key,
    required this.departure,
    required this.destination,
    required this.rideOption,
    required this.driver,
    this.polylinePoints = const [],
    this.autoStartSimulation = false,
    this.isOffline = false,
    this.rideId,
    this.rideService,
  });

  @override
  State<ActiveRidePage> createState() => _ActiveRidePageState();
}

class _ActiveRidePageState extends State<ActiveRidePage>
    with SingleTickerProviderStateMixin {
  late final RideService _rideService;
  GoogleMapController? _mapController;
  BitmapDescriptor? _carMarkerIcon;
  BitmapDescriptor? _pickupBadgeIcon;
  BitmapDescriptor? _destBadgeIcon;

  // Route & Simulation State
  AnimationController? _animController;
  late List<LatLng> _effectiveRoute;
  late List<double> _segmentLengths;
  late double _totalRouteDistanceMeters;
  late LatLng _currentCarPosition;
  double _currentCarHeading = 0.0;
  List<LatLng> _traveledPoints = [];
  List<LatLng> _remainingPoints = [];
  late double _initialDistanceKm;
  late double _remainingDistanceKm;
  late int _initialEtaMinutes;
  late int _remainingEtaMinutes;
  double _progressRatio = 0.0;
  bool _isStopped = false;
  String _stopReason = 'Arrêt feu rouge';
  bool _followCar = true;
  bool _isProgrammaticCameraMove = false;
  double _currentSheetExtent = 0.38;
  DateTime _lastCameraUpdateTime = DateTime.fromMillisecondsSinceEpoch(0);
  late bool _isOffline;

  // Realtime Socket.IO streams & stale location tracking (PDF Seddo)
  StreamSubscription<RealtimeRideStatusEvent>? _realtimeStatusSub;
  StreamSubscription<RealtimeDriverLocationEvent>? _realtimeLocationSub;
  StreamSubscription<RealtimeRideEtaEvent>? _realtimeEtaSub;
  StreamSubscription<RealtimeRideRouteEvent>? _realtimeRouteSub;
  StreamSubscription<void>? _realtimeReconnectSub;

  DateTime _lastDriverLocationTime = DateTime.now();
  Timer? _stalePositionCheckTimer;
  bool _isPositionUpdating = false;

  /// Whether to display the simulation toggle button in the bottom sheet.
  /// Kept in code for later use as requested by the user.
  static const bool _showNetworkSimulationControls = false;

  @override
  void initState() {
    super.initState();
    _rideService = widget.rideService ?? RideService();
    _isOffline = widget.isOffline;
    _currentSheetExtent = _isOffline ? 0.25 : 0.38;
    _initRoute();
    _loadCustomMarkers();

    final bool isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 2),
    )
      ..addListener(() {
        _updateProgress(_animController!.value);
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) {
            // Arrivée automatique à destination après les 2 minutes de simulation
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) {
                _onTripCompleted();
              }
            });
          }
        }
      });

    if (widget.autoStartSimulation &&
        widget.polylinePoints.isNotEmpty &&
        !isTest) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          _startSimulation();
        }
      });
    }

    // Connexion WebSocket en direct pour suivre la course (PDF Seddo)
    final effectiveRideId =
        widget.rideId ?? RideService.lastCreatedRideId ?? '';
    if (effectiveRideId.isNotEmpty) {
      RealtimeService().connect();
      RealtimeService().joinRide(effectiveRideId);

      _realtimeStatusSub =
          RealtimeService().rideStatusStream.listen((event) {
        if (!mounted) return;
        if (event.rideId.isEmpty || event.rideId == effectiveRideId) {
          if (event.status == 'COMPLETED') {
            _cleanupRealtime();
            _onTripCompleted();
          } else if (event.status.startsWith('CANCELLED')) {
            _cleanupRealtime();
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
        }
      });

      _realtimeLocationSub =
          RealtimeService().driverLocationStream.listen((event) {
        if (!mounted) return;
        if (event.rideId == null || event.rideId == effectiveRideId) {
          _lastDriverLocationTime = DateTime.now();
          if (_isPositionUpdating) {
            setState(() {
              _isPositionUpdating = false;
            });
          }
          updateCarLocation(event.location, heading: event.heading);
        }
      });

      _realtimeEtaSub = RealtimeService().rideEtaStream.listen((event) {
        if (!mounted) return;
        if (event.rideId == null || event.rideId == effectiveRideId) {
          if (event.etaMinutes > 0) {
            setState(() {
              _remainingEtaMinutes = event.etaMinutes;
            });
          }
          if (event.distanceMeters != null && event.distanceMeters! > 0) {
            setState(() {
              _remainingDistanceKm = event.distanceMeters! / 1000.0;
            });
          }
        }
      });

      _realtimeRouteSub = RealtimeService().rideRouteStream.listen((event) {
        if (!mounted) return;
        if (event.points.length >= 2) {
          setState(() {
            _effectiveRoute = List.from(event.points);
          });
        }
      });

      _stalePositionCheckTimer =
          Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted && _progressRatio < 0.99) {
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
  }

  void _cleanupRealtime() {
    _stalePositionCheckTimer?.cancel();
    _realtimeStatusSub?.cancel();
    _realtimeLocationSub?.cancel();
    _realtimeEtaSub?.cancel();
    _realtimeRouteSub?.cancel();
    _realtimeReconnectSub?.cancel();
  }

  @override
  void dispose() {
    _cleanupRealtime();
    final effectiveRideId =
        widget.rideId ?? RideService.lastCreatedRideId ?? '';
    if (effectiveRideId.isNotEmpty) {
      RealtimeService().leaveRide(effectiveRideId);
    }
    _animController?.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _initRoute() {
    if (widget.polylinePoints.length >= 2) {
      _effectiveRoute = List<LatLng>.from(widget.polylinePoints);
    } else {
      final start =
          LatLng(widget.departure.latitude, widget.departure.longitude);
      final end =
          LatLng(widget.destination.latitude, widget.destination.longitude);
      const steps = 30;
      _effectiveRoute = List.generate(steps, (i) {
        final t = i / (steps - 1);
        return LatLng(
          start.latitude + (end.latitude - start.latitude) * t,
          start.longitude + (end.longitude - start.longitude) * t,
        );
      });
    }

    _segmentLengths = [];
    _totalRouteDistanceMeters = 0.0;
    for (int i = 0; i < _effectiveRoute.length - 1; i++) {
      final len = _haversineMeters(_effectiveRoute[i], _effectiveRoute[i + 1]);
      _segmentLengths.add(len);
      _totalRouteDistanceMeters += len;
    }

    // Car starts at departure point of the ride
    _currentCarPosition = _effectiveRoute.first;
    if (_effectiveRoute.length >= 2) {
      _currentCarHeading =
          _calculateBearing(_effectiveRoute[0], _effectiveRoute[1]);
    }

    _initialDistanceKm = widget.driver.distanceKm > 0
        ? widget.driver.distanceKm
        : (_totalRouteDistanceMeters / 1000.0);
    _remainingDistanceKm = _initialDistanceKm;

    _initialEtaMinutes =
        widget.driver.etaMinutes > 0 ? widget.driver.etaMinutes : 12;
    _remainingEtaMinutes = _initialEtaMinutes;

    _traveledPoints = [_currentCarPosition];
    _remainingPoints = List<LatLng>.from(_effectiveRoute);
    _progressRatio = 0.0;
  }

  double _haversineMeters(LatLng p1, LatLng p2) {
    const r = 6371000.0;
    final dLat = (p2.latitude - p1.latitude) * (math.pi / 180.0);
    final dLon = (p2.longitude - p1.longitude) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(p1.latitude * (math.pi / 180.0)) *
            math.cos(p2.latitude * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
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

  double _interpolateAngle(double from, double to, double t) {
    double diff = (to - from) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    return (from + diff * t) % 360.0;
  }

  void _updateProgress(double progress) {
    if (!mounted ||
        _effectiveRoute.length < 2 ||
        _totalRouteDistanceMeters <= 0) {
      return;
    }

    final clampedT = progress.clamp(0.0, 1.0);

    // Profil de navigation réaliste sur 2 minutes (120 secondes) :
    // 0:00 - 0:25 (t: 0.00 -> 0.21) : Départ fluide et accélération sur la première artère (0% -> 22% du trajet)
    // 0:25 - 0:38 (t: 0.21 -> 0.32) : 1er arrêt au feu tricolore / carrefour (13s d'arrêt visible avec badge 'Arrêt feu rouge')
    // 0:38 - 1:05 (t: 0.32 -> 0.54) : Redémarrage au feu vert, passage sur grande avenue (22% -> 55% du trajet)
    // 1:05 - 1:22 (t: 0.54 -> 0.68) : Négociation du rond-point avec virages continus et lissage angulaire (55% -> 68% du trajet)
    // 1:22 - 1:35 (t: 0.68 -> 0.79) : 2e arrêt temporaire : priorité / passage piéton (13s d'arrêt visible avec badge 'Arrêt priorité')
    // 1:35 - 1:54 (t: 0.79 -> 0.95) : Reprise et approche de la zone de destination (68% -> 96% du trajet)
    // 1:54 - 2:00 (t: 0.95 -> 1.00) : Décélération douce et stationnement à l'adresse finale (96% -> 100% du trajet)
    double routeProgress = 0.0;
    bool isStoppedNow = false;
    String currentStopReason = 'Arrêt feu rouge';

    if (clampedT <= 0.21) {
      final localT = clampedT / 0.21;
      routeProgress = 0.22 * Curves.easeInOut.transform(localT);
      isStoppedNow = false;
    } else if (clampedT <= 0.32) {
      routeProgress = 0.22;
      isStoppedNow = true;
      currentStopReason = 'Arrêt feu rouge';
    } else if (clampedT <= 0.54) {
      final localT = (clampedT - 0.32) / 0.22;
      routeProgress = 0.22 + (0.55 - 0.22) * Curves.easeInOut.transform(localT);
      isStoppedNow = false;
    } else if (clampedT <= 0.68) {
      final localT = (clampedT - 0.54) / 0.14;
      routeProgress = 0.55 + (0.68 - 0.55) * Curves.linear.transform(localT);
      isStoppedNow = false;
    } else if (clampedT <= 0.79) {
      routeProgress = 0.68;
      isStoppedNow = true;
      currentStopReason = 'Arrêt priorité';
    } else if (clampedT <= 0.95) {
      final localT = (clampedT - 0.79) / 0.16;
      routeProgress = 0.68 + (0.96 - 0.68) * Curves.easeInOut.transform(localT);
      isStoppedNow = false;
    } else {
      final localT = (clampedT - 0.95) / 0.05;
      routeProgress = 0.96 + (1.0 - 0.96) * Curves.easeOut.transform(localT);
      isStoppedNow = false;
    }

    final clampedS = routeProgress.clamp(0.0, 1.0);
    final targetDistance = clampedS * _totalRouteDistanceMeters;

    double acc = 0.0;
    int segIndex = 0;
    double segRatio = 0.0;

    for (int i = 0; i < _segmentLengths.length; i++) {
      final segLen = _segmentLengths[i];
      if (acc + segLen >= targetDistance || i == _segmentLengths.length - 1) {
        segIndex = i;
        segRatio = segLen > 0 ? (targetDistance - acc) / segLen : 0.0;
        break;
      }
      acc += segLen;
    }

    final p1 = _effectiveRoute[segIndex];
    final p2 = _effectiveRoute[segIndex + 1];

    final curLat = p1.latitude + (p2.latitude - p1.latitude) * segRatio;
    final curLng = p1.longitude + (p2.longitude - p1.longitude) * segRatio;
    final newPos = LatLng(curLat, curLng);

    // Orientation dynamique avec lissage doux dans les virages et rond-points (style Yango)
    final rawHeading = _calculateBearing(p1, p2);
    double heading = rawHeading;
    if (segIndex < _effectiveRoute.length - 2 && segRatio > 0.65) {
      final nextHeading = _calculateBearing(
        _effectiveRoute[segIndex + 1],
        _effectiveRoute[segIndex + 2],
      );
      final turnRatio = (segRatio - 0.65) / 0.35;
      heading = _interpolateAngle(rawHeading, nextHeading, turnRatio);
    }

    // Micro-animation subtile de vibration moteur (+/- 0.6°) en marche
    if (!isStoppedNow && clampedS > 0.005 && clampedS < 0.995) {
      final engineVibration = math.sin(clampedS * 90 * math.pi) * 0.6;
      heading = (heading + engineVibration) % 360.0;
    }

    final traveled = <LatLng>[];
    for (int i = 0; i <= segIndex; i++) {
      traveled.add(_effectiveRoute[i]);
    }
    traveled.add(newPos);

    final remaining = <LatLng>[newPos];
    for (int i = segIndex + 1; i < _effectiveRoute.length; i++) {
      remaining.add(_effectiveRoute[i]);
    }

    final remDist = (_initialDistanceKm * (1.0 - clampedS))
        .clamp(0.0, _initialDistanceKm);
    final remainingSeconds = ((1.0 - clampedS) * 120).ceil();
    final remEta = (remainingSeconds / 60).ceil().clamp(1, 2);

    // Recentrage automatique fluide si le mode suivi est activé
    if (_followCar && _mapController != null) {
      final now = DateTime.now();
      if (now.difference(_lastCameraUpdateTime).inMilliseconds > 1000) {
        _lastCameraUpdateTime = now;
        _isProgrammaticCameraMove = true;
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(newPos),
        );
      }
    }

    setState(() {
      _currentCarPosition = newPos;
      _currentCarHeading = heading;
      _traveledPoints = traveled;
      _remainingPoints = remaining;
      _remainingDistanceKm = remDist;
      _remainingEtaMinutes = remEta;
      _progressRatio = clampedS;
      _isStopped = isStoppedNow;
      _stopReason = currentStopReason;
    });
  }

  void _startSimulation() {
    if (_animController == null) return;
    if (_animController!.value >= 1.0) {
      _animController!.reset();
    }
    _animController!.forward();
  }

  /// Méthode publique prête pour connecter l'API backend / WebSockets en temps réel.
  /// Lorsque le serveur ou l'application chauffeur envoie une mise à jour GPS,
  /// appelez cette méthode pour mettre à jour la position du véhicule en direct.
  void updateCarLocation(LatLng newPosition, {double? heading}) {
    if (_animController != null && _animController!.isAnimating) {
      _animController!.stop();
    }
    _applyExternalGpsLocation(newPosition, heading: heading);
  }

  void _applyExternalGpsLocation(LatLng newPosition, {double? heading}) {
    if (!mounted || _effectiveRoute.isEmpty) return;

    int closestIndex = 0;
    double minDistance = double.infinity;
    for (int i = 0; i < _effectiveRoute.length; i++) {
      final d = _haversineMeters(newPosition, _effectiveRoute[i]);
      if (d < minDistance) {
        minDistance = d;
        closestIndex = i;
      }
    }

    final computedHeading = heading ??
        (closestIndex < _effectiveRoute.length - 1
            ? _calculateBearing(_effectiveRoute[closestIndex],
                _effectiveRoute[closestIndex + 1])
            : _currentCarHeading);

    final traveled = <LatLng>[];
    for (int i = 0; i <= closestIndex; i++) {
      traveled.add(_effectiveRoute[i]);
    }
    traveled.add(newPosition);

    final remaining = <LatLng>[newPosition];
    for (int i = closestIndex + 1; i < _effectiveRoute.length; i++) {
      remaining.add(_effectiveRoute[i]);
    }

    final ratio = (closestIndex /
            (_effectiveRoute.length - 1).clamp(1, double.infinity))
        .clamp(0.0, 1.0);

    setState(() {
      _currentCarPosition = newPosition;
      _currentCarHeading = computedHeading;
      _traveledPoints = traveled;
      _remainingPoints = remaining;
      _progressRatio = ratio;
      _remainingDistanceKm =
          (_initialDistanceKm * (1.0 - ratio)).clamp(0.0, _initialDistanceKm);
      _remainingEtaMinutes = (_initialEtaMinutes * (1.0 - ratio))
          .ceil()
          .clamp(1, _initialEtaMinutes);
    });
  }

  void _fitRouteBounds() {
    if (_mapController == null || _effectiveRoute.isEmpty) return;
    try {
      double minLat = _effectiveRoute.first.latitude;
      double maxLat = _effectiveRoute.first.latitude;
      double minLng = _effectiveRoute.first.longitude;
      double maxLng = _effectiveRoute.first.longitude;

      for (final p in _effectiveRoute) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }

      final deltaLat = (maxLat - minLat).abs();
      final deltaLng = (maxLng - minLng).abs();

      if (deltaLat < 0.0005 && deltaLng < 0.0005) {
        _isProgrammaticCameraMove = true;
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_effectiveRoute.first, 15.5),
        );
        return;
      }

      _isProgrammaticCameraMove = true;
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat - 0.001, minLng - 0.001),
            northeast: LatLng(maxLat + 0.001, maxLng + 0.001),
          ),
          50.0,
        ),
      );
    } catch (_) {
      try {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentCarPosition, 15.0),
        );
      } catch (_) {}
    }
  }

  Future<void> _loadCustomMarkers() async {
    final carColor = VehicleColorHelper.parseColor(widget.driver.carColor);
    final car = await MapMarkerHelper.get3DCarMarker(color: carColor);
    final pickup = await MapMarkerHelper.getDeparturePinMarker();
    final dest = await MapMarkerHelper.getDestinationPinMarker();

    if (mounted) {
      setState(() {
        _carMarkerIcon = car;
        _pickupBadgeIcon = pickup;
        _destBadgeIcon = dest;
      });
    }
  }

  Future<void> _callDriver() async {
    await InAppCallPage.show(context, driver: widget.driver);
  }

  void _openChat() {
    Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: DriverChatPage(
          driver: widget.driver,
          rideId: widget.rideId,
        ),
      ),
    );
  }

  Future<void> _shareRide() async {
    final effectiveRideId =
        widget.rideId ?? RideService.lastCreatedRideId ?? 'current';
    String shareUrl = 'https://suivi.seddo.sn/t/8K02F';
    String? token;

    try {
      final result = await _rideService.shareRide(effectiveRideId);
      if (result != null && result.url.isNotEmpty) {
        shareUrl = result.url;
        token = result.token;
      }
    } catch (_) {}

    final shareText =
        'Suis mon trajet Seddo en direct vers ${widget.destination.mainText} avec ${widget.driver.name} (${widget.driver.carModel} ${widget.driver.licensePlate}) : $shareUrl';

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: 'Mon trajet Seddo en direct',
        ),
      );
    } catch (_) {}

    if (mounted) {
      _showShareOptionsSheet(shareUrl, token: token);
    }
  }

  void _showShareOptionsSheet(String shareUrl, {String? token}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusSheet),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dragHandle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'ride.live_tracking_link'.tr(),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ride.live_tracking_desc'.tr(),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceGrey,
                borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.link_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      shareUrl,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
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
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        SlideRightToLeftRoute(
                          page: SharedRideTrackingPage(
                            departure: widget.departure,
                            destination: widget.destination,
                            driver: widget.driver,
                            polylinePoints: widget.polylinePoints,
                            etaText: widget.rideOption.estimatedArrival,
                            shareUrl: shareUrl,
                            token: token,
                            rideService: _rideService,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'ride.web_tracking_preview'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openOfflineEmergency() {
    OfflineEmergencySheet.show(
      context,
      destination: widget.destination,
      driver: widget.driver,
      currentPosition: _currentCarPosition,
      etaText: widget.rideOption.estimatedArrival,
    );
  }

  void _toggleOfflineMode() {
    setState(() {
      _isOffline = !_isOffline;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isOffline
              ? 'ride.offline_mode_active'.tr()
              : 'ride.offline_mode_restored'.tr(),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor:
            _isOffline ? AppColors.offlineDark : AppColors.success,
      ),
    );
  }

  void _openSafetyModal() {
    SafetyModalWidget.show(
      context,
      destination: widget.destination,
      driver: widget.driver,
    );
  }

  void _onTripCompleted() {
    Navigator.of(context).pushReplacement(
      SlideRightToLeftRoute(
        page: RideRatingPage(
          departure: widget.departure,
          destination: widget.destination,
          driver: widget.driver,
          rideOption: widget.rideOption,
          arrivalTime: widget.rideOption.estimatedArrival,
          rideId: widget.rideId ?? RideService.lastCreatedRideId,
          rideService: _rideService,
        ),
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // 1. Pickup departure location pin
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

    // 2. Destination arrival location pin
    if (_destBadgeIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dest_badge_marker'),
          position: LatLng(
            widget.destination.latitude,
            widget.destination.longitude,
          ),
          icon: _destBadgeIcon!,
          anchor: const Offset(0.5, 1.0),
        ),
      );
    }

    // 3. Driver car marker moving along route from departure to destination
    if (_carMarkerIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver_car_marker'),
          position: _currentCarPosition,
          icon: _carMarkerIcon!,
          anchor: const Offset(0.5, 0.5),
          rotation: _currentCarHeading,
          flat: true,
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    if (_effectiveRoute.isEmpty) return {};

    final polylines = <Polyline>{};

    // 1. Distance déjà parcourue avec couleur différenciée (gris discret AppColors.routeTraveled)
    if (_traveledPoints.length >= 2 && _progressRatio > 0.005) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('traveled_route'),
          points: _traveledPoints,
          color: AppColors.routeTraveled,
          width: 4,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }

    // 2. Distance restante avec couleurs dynamiques de trafic (Vert fluide, ambre ralenti, rouge bouchon)
    final activePts =
        _remainingPoints.length >= 2 ? _remainingPoints : _effectiveRoute;
    final activePolylines = RideEtaCalculator.buildTrafficPolylines(
      baseId: 'active_route',
      points: activePts,
      traffic: widget.rideOption.traffic,
      width: 4,
    );
    polylines.addAll(activePolylines);

    return polylines;
  }



  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final systemBottom = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // La course est en cours : navigation retour désactivée
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

          // 1. Fullscreen Google Map avec pinch-to-zoom et contrôle gestuel fluide
          Listener(
            onPointerDown: (_) {
              if (_followCar) {
                setState(() {
                  _followCar = false;
                });
              }
            },
            child: GoogleMap(
              key: const ValueKey('active_ride_map_view'),
              style: MapStyleService.style,
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  (widget.departure.latitude + widget.destination.latitude) / 2,
                  (widget.departure.longitude + widget.destination.longitude) / 2,
                ),
                zoom: 13.8,
              ),
              padding: const EdgeInsets.only(
                bottom: 300,
                top: 70,
                left: 16,
                right: 16,
              ),
              mapType: MapType.normal,
              buildingsEnabled: false,
              onMapCreated: (ctrl) {
                _mapController = ctrl;
                MapStyleService.applyStyle(ctrl);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) {
                      _fitRouteBounds();
                    }
                  });
                });
              },
              onCameraMoveStarted: () {
                if (!_isProgrammaticCameraMove && _followCar) {
                  setState(() {
                    _followCar = false;
                  });
                }
                _isProgrammaticCameraMove = false;
              },
              markers: _buildMarkers(),
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
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
            ),
          ),

          // 2. Floating Offline Banner (when offline) or Top Bar (when online)
          if (_isOffline) ...[
            // Floating Black Offline Banner matching user screenshot
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: _toggleOfflineMode,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.offlineDark,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.black38,
                        blurRadius: 14,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.wifi_off_rounded,
                          color: AppColors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Pas de réseau. Votre course continue et la position se mettra à jour au retour du réseau.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          ] else
            // Normal online Floating Top Bar (Centering Pill with Siren Button on right)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                  vertical: AppConstants.spacingSm,
                ),
                child: Row(
                  children: [
                    // Symmetry spacer to balance the Siren button on the right
                    const SizedBox(width: AppConstants.circularButtonSize),

                    Expanded(
                      child: Center(
                        child: GestureDetector(
                          onLongPress: _toggleOfflineMode,
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
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _isStopped
                                        ? AppColors.orangeMoneyOrange
                                        : AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _progressRatio >= 0.99
                                      ? 'ride.arrived_at_destination'.tr()
                                      : (_isPositionUpdating
                                          ? 'ride.position_updating'.tr()
                                          : (_isStopped
                                              ? _stopReason
                                              : 'ride.arriving_in'.tr(args: ['$_remainingEtaMinutes']))),
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Floating Red Siren Button (Screenshot 1 top-right)
                    Container(
                      width: AppConstants.circularButtonSize,
                      height: AppConstants.circularButtonSize,
                      decoration: const BoxDecoration(
                        color: AppColors.sirenRed,
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
                          Icons.notifications_active_rounded,
                          color: AppColors.white,
                          size: 20,
                        ),
                        onPressed: _openSafetyModal,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Floating Camera Mode Toggle Button (Ma position / Destination / Vue Trajet)
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * _currentSheetExtent +
                12,
            child: RideMapCameraToggleButton(
              mapControllerGetter: () => _mapController,
              departureLocation: _currentCarPosition,
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

          // 4. Draggable Bottom Sheet with Driver Information & Communication
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              if ((_currentSheetExtent - notification.extent).abs() > 0.005) {
                setState(() {
                  _currentSheetExtent = notification.extent;
                });
              }
              return false;
            },
            child: DraggableScrollableSheet(
              initialChildSize: _isOffline ? 0.25 : 0.38,
              minChildSize: 0.14,
              maxChildSize: 0.78,
              snap: true,
              snapSizes: _isOffline
                  ? const [0.14, 0.25, 0.78]
                  : const [0.14, 0.38, 0.78],
              builder: (context, scrollController) {
              return Container(
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
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    AppConstants.spacingLg,
                    10,
                    AppConstants.spacingLg,
                    systemBottom + 16,
                  ),
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: AppConstants.circularIconContainerSize,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.dragHandle,
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusXs,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (_isOffline) ...[
                      // Offline View matching user screenshot:
                      Text(
                        'Dernière position il y a 40 s',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${widget.destination.mainText} · arrivée ${widget.rideOption.estimatedArrival}',
                        style: GoogleFonts.inter(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // "Urgence par SMS" tile matching screenshot
                      InkWell(
                        onTap: _openOfflineEmergency,
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusDefault,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: AppColors.errorLightBg,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: SvgPicture.asset(
                                  'assets/icons/caution-mark-8-svgrepo-com.svg',
                                  width: 22,
                                  height: 22,
                                  colorFilter: const ColorFilter.mode(
                                    AppColors.errorRed,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ride.sms_emergency'.tr(),
                                      style: GoogleFonts.inter(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'ride.sms_emergency_desc'.tr(),
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textSecondary,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.divider),
                      const SizedBox(height: 14),

                      // Driver Summary Card even when offline
                      ActiveDriverCardWidget(
                        driver: widget.driver,
                        isPaid: true,
                        vehicleImagePath: widget.rideOption.type ==
                                RideType.confort
                            ? 'assets/images/seddo_confort_3d.png'
                            : 'assets/images/seddo_eco_3d.png',
                      ),

                      const SizedBox(height: 10),

                      // Quick Communication Row (GSM phone call and SMS work offline)
                      DriverActionButtonsWidget(
                        onMessagePressed: _openChat,
                        onCallPressed: _callDriver,
                      ),

                      // Toggle network button for simulation & testing (preserved in code for testing / debugging)
                      if (_showNetworkSimulationControls) ...[
                        const SizedBox(height: 14),
                        Center(
                          child: TextButton.icon(
                            onPressed: _toggleOfflineMode,
                            icon: const Icon(
                              Icons.wifi_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            label: Text(
                              'Simuler le retour de connexion',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ] else ...[

                    // Header: "En route vers [Destination]" with Yango-style live badge & progress
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _isStopped
                                    ? AppColors.peachContainer
                                    : AppColors.liveStatusBg,
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusPill,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: _isStopped
                                          ? AppColors.orangeMoneyOrange
                                          : (_progressRatio >= 0.99
                                              ? AppColors.success
                                              : AppColors.yangoRouteGreen),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _progressRatio >= 0.99
                                        ? 'ride.arrived'.tr()
                                        : (_isStopped
                                            ? _stopReason
                                            : 'En direct'),
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: _isStopped
                                          ? AppColors.primaryDark
                                          : AppColors.liveStatusText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              widget.rideOption.formattedPrice,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'En route vers ${widget.destination.mainText}',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Arrivée prévue ${widget.rideOption.estimatedArrival} · ${_remainingDistanceKm.toStringAsFixed(1)} km restants',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Yango-style animated route progress bar
                        Stack(
                          children: [
                            Container(
                              height: 4,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceGrey,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: _progressRatio.clamp(0.04, 1.0),
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.yangoRouteGreen,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Driver Summary Card with initials avatar, 3D vehicle and "✓ Payé" badge
                    ActiveDriverCardWidget(
                      driver: widget.driver,
                      isPaid: true,
                      vehicleImagePath: widget.rideOption.type ==
                              RideType.confort
                          ? 'assets/images/seddo_confort_3d.png'
                          : 'assets/images/seddo_eco_3d.png',
                    ),

                    const SizedBox(height: 10),

                    // Quick Communication Row (Message & Appeler)
                    DriverActionButtonsWidget(
                      onMessagePressed: _openChat,
                      onCallPressed: _callDriver,
                    ),

                    const SizedBox(height: 14),

                    // Trip Route Summary Card (Yango-style)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGrey,
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusCard,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.yangoRouteGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.departure.mainText,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 3.5),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: 1.5,
                                height: 14,
                                color: AppColors.border,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.buttonBlack,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.destination.mainText,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 6),

                    // Row 1: "Partager le trajet"
                    RideActionTileWidget(
                      icon: Icons.share_outlined,
                      iconColor: AppColors.textPrimary,
                      iconBgColor: AppColors.surfaceGrey,
                      title: 'ride.share_ride'.tr(),
                      subtitle: 'ride.live_tracking_desc'.tr(),
                      onTap: _shareRide,
                    ),

                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 6),

                    // Row 2: "Sécurité"
                    RideActionTileWidget(
                      svgPath: 'assets/icons/security-svgrepo-com.svg',
                      iconColor: AppColors.sirenRed,
                      iconBgColor: AppColors.walletContainerBg,
                      title: 'drawer.safety'.tr(),
                      subtitle: 'drawer.safety_sub'.tr(),
                      onTap: _openSafetyModal,
                    ),
                  ],
                ],
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
}
