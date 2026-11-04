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
import 'package:seddo/features/ride/data/services/active_ride_offline_storage.dart';
import 'package:seddo/features/ride/presentation/widgets/active_ride_offline_banner.dart';
import 'package:seddo/services/network_connectivity_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/widgets/realtime_status_indicator.dart';
import 'package:seddo/services/map_style_service.dart';
import 'package:seddo/services/realtime_service.dart';
import 'package:seddo/services/route_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:seddo/features/ride/presentation/utils/vehicle_color_helper.dart';
import 'package:seddo/features/ride/presentation/widgets/active_driver_card_widget.dart';
import 'package:seddo/features/ride/presentation/widgets/driver_action_buttons_widget.dart';
import 'package:seddo/features/ride/presentation/widgets/ride_map_camera_toggle_button.dart';
import 'package:seddo/features/home/presentation/widgets/map_marker_helper.dart';
import 'package:seddo/features/ride/presentation/widgets/offline_emergency_sheet.dart';
import 'package:seddo/features/safety/presentation/widgets/safety_modal_widget.dart';
import 'package:seddo/features/ride/presentation/widgets/ride_sos_bottom_sheet.dart';
import 'package:seddo/features/ride/data/services/ride_live_update_service_impl.dart';
import 'package:seddo/features/ride/domain/models/ride_live_update_data.dart';
import 'package:seddo/features/ride/presentation/widgets/ride_action_tile_widget.dart';

/// Écran de suivi du trajet en cours avec chauffeur :
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
  final String? paymentMethod;
  final String? paymentPhone;

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
    this.paymentMethod,
    this.paymentPhone,
  });

  @override
  State<ActiveRidePage> createState() => _ActiveRidePageState();
}

class _ActiveRidePageState extends State<ActiveRidePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final RideService _rideService;
  GoogleMapController? _mapController;
  BitmapDescriptor? _carMarkerIcon;
  BitmapDescriptor? _pickupBadgeIcon;
  BitmapDescriptor? _destBadgeIcon;

  // Route & Simulation State
  AnimationController? _animController;
  AnimationController? _smoothCarController;
  bool _hasReceivedRealGps = false;
  bool _isSnappedMovement = true;
  double _startProgressRatio = 0.0;
  double _targetProgressRatio = 0.0;
  LatLng? _animStartPos;
  LatLng? _animEndPos;
  double? _animStartHeading;
  double? _animEndHeading;
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

  @visibleForTesting
  int get remainingEtaMinutes => _remainingEtaMinutes;

  @visibleForTesting
  LatLng get currentCarPosition => _currentCarPosition;

  @visibleForTesting
  bool get isOffline => _isOffline;

  @visibleForTesting
  bool get hasReceivedRealGps => _hasReceivedRealGps;
  double _progressRatio = 0.0;
  bool _isStopped = false;
  final String _stopReason = 'Arrêt temporaire';
  bool _followCar = true;
  bool _isProgrammaticCameraMove = false;
  double _currentSheetExtent = 0.38;
  DateTime _lastCameraUpdateTime = DateTime.fromMillisecondsSinceEpoch(0);
  late bool _isOffline;
  Timer? _offlineMonitorTimer;
  int _consecutiveOfflineFailures = 0;
  bool _isCheckingConnectivity = false;
  String? _paymentMethod;
  String? _paymentPhone;
  DateTime _lastLiveUpdateSync = DateTime.fromMillisecondsSinceEpoch(0);

  // Realtime Socket.IO streams & stale location tracking (PDF Seddo)
  StreamSubscription<RealtimeRideStatusEvent>? _realtimeStatusSub;
  StreamSubscription<RealtimeDriverLocationEvent>? _realtimeLocationSub;
  StreamSubscription<RealtimeRideEtaEvent>? _realtimeEtaSub;
  StreamSubscription<RealtimeRideRouteEvent>? _realtimeRouteSub;
  StreamSubscription<void>? _realtimeReconnectSub;

  DateTime _lastDriverLocationTime = DateTime.now();
  Timer? _stalePositionCheckTimer;
  Timer? _pollTimer;
  bool _isPositionUpdating = false;
  bool _isRerouting = false;
  DateTime _lastRerouteTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Whether to display the simulation toggle button in the bottom sheet.
  /// Kept in code for later use as requested by the user.
  static const bool _showNetworkSimulationControls = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rideService = widget.rideService ?? RideService();
    _isOffline = widget.isOffline;
    _paymentMethod = widget.paymentMethod;
    _paymentPhone = widget.paymentPhone;
    _currentSheetExtent = _isOffline ? 0.25 : 0.38;
    _initRoute();
    _persistLocalState();
    _startOfflineMonitor();
    _loadCustomMarkers();
    _syncLiveUpdate(progress: 0.05, etaMinutes: _remainingEtaMinutes);

    final bool isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    if (!isTest || !widget.isOffline) {
      NetworkConnectivityService.isConnected.then((online) {
        if (mounted && online && _isOffline) {
          _onNetworkRestored();
        }
      });
    }


    _animController = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 2),
    )
      ..addListener(() {
        if (!_hasReceivedRealGps && !_isOffline) {
          _updateProgress(_animController!.value);
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted && !_hasReceivedRealGps) {
            // Arrivée automatique à destination après les 2 minutes de simulation
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted && !_hasReceivedRealGps) {
                _onTripCompleted();
              }
            });
          }
        }
      });

    // Contrôleur de déplacement fluide de la voiture lors des mises à jour GPS en direct
    _smoothCarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() {
        if (!mounted || _isOffline) return;
        final t = _smoothCarController!.value;
        if (_isSnappedMovement) {
          final curS = _startProgressRatio +
              (_targetProgressRatio - _startProgressRatio) * t;
          _setProgressOnRoute(curS);
        } else if (_animStartPos != null && _animEndPos != null) {
          final curLat = _animStartPos!.latitude +
              (_animEndPos!.latitude - _animStartPos!.latitude) * t;
          final curLng = _animStartPos!.longitude +
              (_animEndPos!.longitude - _animStartPos!.longitude) * t;

          double curHead = _currentCarHeading;
          if (_animStartHeading != null && _animEndHeading != null) {
            curHead = _interpolateAngle(_animStartHeading!, _animEndHeading!, t);
          }

          _applyExternalGpsLocation(LatLng(curLat, curLng), heading: curHead);
        }
      });

    if (!isTest && widget.autoStartSimulation) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted &&
            !_hasReceivedRealGps &&
            !_isOffline &&
            _animController != null &&
            !_animController!.isAnimating) {
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
            _syncLiveUpdate(etaMinutes: event.etaMinutes);
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

      // Synchronisation initiale et resynchronisation dès reconnexion
      _fetchRideDetails(effectiveRideId);

      _realtimeReconnectSub = RealtimeService().onReconnect.listen((_) {
        if (mounted) {
          RealtimeService().joinRide(effectiveRideId);
          _fetchRideDetails(effectiveRideId);
        }
      });

      // Filet de sécurité: synchronisation continue toutes les 4s pour garantir
      // la détection en direct de la fin de course ou annulation sans quitter l'application
      if (!isTest) {
        _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
          if (mounted) {
            _fetchRideDetails(effectiveRideId);
          }
        });
      }
    }
  }

  /// Récupère l'état actuel de la course via REST pour garantir l'actualisation en temps réel
  Future<void> _fetchRideDetails(String id) async {
    try {
      final data = await _rideService.getRideDetails(id);
      if (data != null && mounted) {
        _applyRideDetails(data);
      }
    } catch (e) {
      debugPrint('[ActiveRidePage] ⚠️ Erreur getRideDetails: $e');
    }
  }

  /// Applique les données retournées par GET /v1/rides/{id}
  void _applyRideDetails(Map<String, dynamic> data) {
    if (!mounted || _isOffline) return;

    final rideObj = data['ride'] is Map<String, dynamic>
        ? data['ride'] as Map<String, dynamic>
        : data;

    final status = (rideObj['status'] as String? ?? '').toUpperCase();

    // 1. Course terminée
    if (status == 'COMPLETED') {
      _cleanupRealtime();
      _onTripCompleted();
      return;
    }

    // Récupérer la méthode de paiement si transmise par le serveur
    final pMap = rideObj['payment'] is Map<String, dynamic>
        ? rideObj['payment'] as Map<String, dynamic>
        : null;
    if (pMap != null) {
      if (pMap['method'] != null) {
        _paymentMethod = pMap['method'].toString().toUpperCase();
      }
      if (pMap['phone'] != null) {
        _paymentPhone = pMap['phone'].toString();
      }
    }

    // 2. Course annulée
    if (status.startsWith('CANCELLED') ||
        status == 'NO_DRIVER' ||
        status == 'NO_SHOW') {
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
      return;
    }

    // 3. Mise à jour de la polyline réelle si fournie par l'API
    final routeObj = rideObj['route'] is Map<String, dynamic>
        ? rideObj['route'] as Map<String, dynamic>
        : null;
    final plannedPolyStr = rideObj['plannedPolyline'] as String? ??
        (routeObj?['polyline'] as String?);
    if (plannedPolyStr != null && plannedPolyStr.isNotEmpty) {
      final tripPts = RouteService.decodePolyline(plannedPolyStr);
      if (tripPts.length >= 2 && tripPts != _effectiveRoute) {
        _setNewRoute(tripPts);
      }
    }

    // 4. Mise à jour de la position GPS du chauffeur si retournée
    final driverObj = rideObj['driver'] is Map<String, dynamic>
        ? rideObj['driver'] as Map<String, dynamic>
        : null;
    final posObj = driverObj?['position'] is Map<String, dynamic>
        ? driverObj!['position'] as Map<String, dynamic>
        : (driverObj?['location'] is Map<String, dynamic>
            ? driverObj!['location'] as Map<String, dynamic>
            : (rideObj['driverPosition'] is Map<String, dynamic>
                ? rideObj['driverPosition'] as Map<String, dynamic>
                : (rideObj['position'] is Map<String, dynamic>
                    ? rideObj['position'] as Map<String, dynamic>
                    : null)));

    final lat = (posObj?['lat'] ??
            posObj?['latitude'] ??
            driverObj?['lat'] ??
            driverObj?['latitude'] ??
            rideObj['lat'] ??
            rideObj['latitude'] as num?)
        ?.toDouble();
    final lng = (posObj?['lng'] ??
            posObj?['longitude'] ??
            driverObj?['lng'] ??
            driverObj?['longitude'] ??
            rideObj['lng'] ??
            rideObj['longitude'] as num?)
        ?.toDouble();
    final heading = (posObj?['heading'] ??
            posObj?['bearing'] ??
            driverObj?['heading'] ??
            rideObj['heading'] as num?)
        ?.toDouble();

    if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      _lastDriverLocationTime = DateTime.now();
      if (_isPositionUpdating) {
        setState(() {
          _isPositionUpdating = false;
        });
      }
      updateCarLocation(LatLng(lat, lng), heading: heading);
    }
  }

  void _persistLocalState() {
    final effectiveRideId =
        widget.rideId ?? RideService.lastCreatedRideId ?? 'current';
    ActiveRideOfflineStorage.saveActiveRide(
      rideId: effectiveRideId,
      status: 'IN_PROGRESS',
      departure: widget.departure,
      destination: widget.destination,
      driver: widget.driver,
      rideOption: widget.rideOption,
      departureCode: '4821',
      polylinePoints: _effectiveRoute,
      lastDriverLocation: _currentCarPosition,
      lastDriverHeading: _currentCarHeading,
      lastDriverLocationTime: _lastDriverLocationTime,
    );
  }

  void _startOfflineMonitor() {
    _offlineMonitorTimer?.cancel();
    _offlineMonitorTimer =
        Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted || _isCheckingConnectivity) return;
      _isCheckingConnectivity = true;
      try {
        final isSocketConnected = RealtimeService().isConnected;
        final online = isSocketConnected || await NetworkConnectivityService.isConnected;
        if (!mounted) return;
        if (!online) {
          _consecutiveOfflineFailures++;
          if (_consecutiveOfflineFailures >= 3 && !_isOffline) {
            setState(() {
              _isOffline = true;
            });
            _animController?.stop();
            _smoothCarController?.stop();
          }
        } else {
          _consecutiveOfflineFailures = 0;
          if (_isOffline) {
            await _onNetworkRestored();
          }
        }
      } finally {
        _isCheckingConnectivity = false;
      }
    });
  }

  Future<void> _onNetworkRestored() async {
    debugPrint(
        '[ActiveRidePage] 🌐 Réseau rétabli ! Resynchronisation automatique...');
    _consecutiveOfflineFailures = 0;
    NetworkConnectivityService.markOnline();

    // 1. Débloquer immédiatement l'interface utilisateur et masquer la bannière
    if (mounted) {
      setState(() {
        _isOffline = false;
        _currentSheetExtent = 0.38;
      });
      if (!_hasReceivedRealGps &&
          widget.autoStartSimulation &&
          _animController != null &&
          !_animController!.isAnimating &&
          _progressRatio < 0.99) {
        _animController!.forward();
      }
    }

    // 2. Reconnexion WebSocket en tâche de fond
    RealtimeService().connect();
    final effectiveRideId =
        widget.rideId ?? RideService.lastCreatedRideId ?? '';
    if (effectiveRideId.isNotEmpty) {
      RealtimeService().joinRide(effectiveRideId);
      _fetchRideDetails(effectiveRideId);
    }

    // 3. Resynchronisation du statut réel avec le serveur
    try {
      final res = await _rideService.getCurrentRide();
      if (!mounted) return;
      final ride = res?['ride'] as Map<String, dynamic>?;
      if (ride != null) {
        final status = (ride['status'] as String? ?? '').toUpperCase();
        if (status == 'COMPLETED') {
          await ActiveRideOfflineStorage.clearActiveRide();
          if (!mounted) return;
          _onTripCompleted();
          return;
        } else if (status.startsWith('CANCEL') ||
            status == 'NO_DRIVER' ||
            status == 'NO_SHOW') {
          await ActiveRideOfflineStorage.clearActiveRide();
          if (!mounted) return;
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
      }
    } catch (_) {}

    // 4. Vidage de la file d'attente hors-ligne
    try {
      await ActiveRideOfflineStorage.flushQueue(_rideService);
    } catch (_) {}
  }

  void _cleanupRealtime() {
    _offlineMonitorTimer?.cancel();
    _pollTimer?.cancel();
    _stalePositionCheckTimer?.cancel();
    _realtimeStatusSub?.cancel();
    _realtimeLocationSub?.cancel();
    _realtimeEtaSub?.cancel();
    _realtimeRouteSub?.cancel();
    _realtimeReconnectSub?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _consecutiveOfflineFailures = 0;
      NetworkConnectivityService.isConnected.then((online) {
        if (mounted && online && _isOffline) {
          _onNetworkRestored();
        }
      });
      final effectiveRideId =
          widget.rideId ?? RideService.lastCreatedRideId ?? '';
      if (effectiveRideId.isNotEmpty) {
        if (!RealtimeService().isConnected) {
          RealtimeService().connect();
          RealtimeService().joinRide(effectiveRideId);
        }
        _fetchRideDetails(effectiveRideId);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupRealtime();
    final effectiveRideId =
        widget.rideId ?? RideService.lastCreatedRideId ?? '';
    if (effectiveRideId.isNotEmpty) {
      RealtimeService().leaveRide(effectiveRideId);
    }
    _animController?.dispose();
    _smoothCarController?.dispose();
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
      // Récupération asynchrone des vraies routes de Dakar via RouteService
      _loadRoadRoute();
    }

    _recomputeRouteMetrics();

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

  void _recomputeRouteMetrics() {
    _segmentLengths = [];
    _totalRouteDistanceMeters = 0.0;
    for (int i = 0; i < _effectiveRoute.length - 1; i++) {
      final len = _haversineMeters(_effectiveRoute[i], _effectiveRoute[i + 1]);
      _segmentLengths.add(len);
      _totalRouteDistanceMeters += len;
    }
  }

  void _setNewRoute(List<LatLng> newRoute) {
    if (newRoute.length < 2) return;
    setState(() {
      _effectiveRoute = List<LatLng>.from(newRoute);
      _recomputeRouteMetrics();
      final proj = _findClosestProjectionOnRoute(_currentCarPosition);
      _progressRatio = proj.progressRatio;
      _applyExternalGpsLocation(proj.projectedPoint, heading: proj.heading);
    });
  }

  Future<void> _loadRoadRoute() async {
    try {
      final origin =
          LatLng(widget.departure.latitude, widget.departure.longitude);
      final dest =
          LatLng(widget.destination.latitude, widget.destination.longitude);
      final details =
          await RouteService().getRoute(origin: origin, destination: dest);
      if (details.polylinePoints.length >= 2 && mounted) {
        _setNewRoute(details.polylinePoints);
        if (details.distanceKm > 0) {
          setState(() {
            _initialDistanceKm = details.distanceKm;
            _remainingDistanceKm = details.distanceKm;
          });
        }
        if (details.durationMinutes > 0) {
          setState(() {
            _initialEtaMinutes = details.durationMinutes;
            _remainingEtaMinutes = details.durationMinutes;
          });
        }
      }
    } catch (e) {
      debugPrint('[ActiveRidePage] Note route loading fallback: $e');
    }
  }

  Future<void> _checkRerouting(LatLng driverPos) async {
    final now = DateTime.now();
    if (_isRerouting || now.difference(_lastRerouteTime).inSeconds < 10) return;
    _isRerouting = true;
    _lastRerouteTime = now;
    try {
      final dest =
          LatLng(widget.destination.latitude, widget.destination.longitude);
      final details =
          await RouteService().getRoute(origin: driverPos, destination: dest);
      if (details.polylinePoints.length >= 2 && mounted) {
        _setNewRoute(details.polylinePoints);
      }
    } catch (_) {
    } finally {
      _isRerouting = false;
    }
  }

  ({
    LatLng projectedPoint,
    int segmentIndex,
    double distanceMeters,
    double segmentRatio,
    double heading,
    double progressRatio,
  }) _findClosestProjectionOnRoute(LatLng point) {
    if (_effectiveRoute.length < 2) {
      return (
        projectedPoint: point,
        segmentIndex: 0,
        distanceMeters: 0.0,
        segmentRatio: 0.0,
        heading: _currentCarHeading,
        progressRatio: 0.0,
      );
    }

    double minDistance = double.infinity;
    LatLng bestProjected = point;
    int bestSegmentIndex = 0;
    double bestRatio = 0.0;
    double bestHeading = _currentCarHeading;
    double bestAccumulatedDistance = 0.0;

    double runningDistance = 0.0;
    for (int i = 0; i < _effectiveRoute.length - 1; i++) {
      final p1 = _effectiveRoute[i];
      final p2 = _effectiveRoute[i + 1];
      final segLen = i < _segmentLengths.length
          ? _segmentLengths[i]
          : _haversineMeters(p1, p2);

      final dLat = p2.latitude - p1.latitude;
      final dLon = p2.longitude - p1.longitude;
      final meanLatRad =
          (p1.latitude + p2.latitude) / 2.0 * (math.pi / 180.0);
      final cosLat = math.cos(meanLatRad);
      final dx = dLon * cosLat;
      final dy = dLat;
      final px = (point.longitude - p1.longitude) * cosLat;
      final py = point.latitude - p1.latitude;

      final lenSq = dx * dx + dy * dy;
      final t =
          lenSq == 0 ? 0.0 : ((px * dx + py * dy) / lenSq).clamp(0.0, 1.0);
      final proj = LatLng(p1.latitude + t * dLat, p1.longitude + t * dLon);
      final dist = _haversineMeters(point, proj);

      if (dist < minDistance) {
        minDistance = dist;
        bestProjected = proj;
        bestSegmentIndex = i;
        bestRatio = t;
        bestAccumulatedDistance = runningDistance + t * segLen;

        final rawBearing = _calculateBearing(p1, p2);
        if (i < _effectiveRoute.length - 2 && t > 0.65) {
          final nextBearing = _calculateBearing(
            _effectiveRoute[i + 1],
            _effectiveRoute[i + 2],
          );
          final turnRatio = (t - 0.65) / 0.35;
          bestHeading = _interpolateAngle(rawBearing, nextBearing, turnRatio);
        } else {
          bestHeading = rawBearing;
        }
      }
      runningDistance += segLen;
    }

    final totalDist =
        _totalRouteDistanceMeters > 0 ? _totalRouteDistanceMeters : 1.0;
    final progress = (bestAccumulatedDistance / totalDist).clamp(0.0, 1.0);

    return (
      projectedPoint: bestProjected,
      segmentIndex: bestSegmentIndex,
      distanceMeters: minDistance,
      segmentRatio: bestRatio,
      heading: bestHeading,
      progressRatio: progress,
    );
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

  ({LatLng position, double heading, int segmentIndex}) _getPositionAtProgress(
      double s) {
    if (_effectiveRoute.isEmpty) {
      return (position: const LatLng(0, 0), heading: 0.0, segmentIndex: 0);
    }
    if (_effectiveRoute.length == 1 ||
        _segmentLengths.isEmpty ||
        _totalRouteDistanceMeters <= 0) {
      return (
        position: _effectiveRoute.first,
        heading: _currentCarHeading,
        segmentIndex: 0
      );
    }

    final clampedS = s.clamp(0.0, 1.0);
    final targetDistance = clampedS * _totalRouteDistanceMeters;

    double acc = 0.0;
    int segIndex = 0;
    double segRatio = 0.0;

    for (int i = 0; i < _segmentLengths.length; i++) {
      final segLen = _segmentLengths[i];
      if (acc + segLen >= targetDistance || i == _segmentLengths.length - 1) {
        segIndex = i;
        segRatio =
            segLen > 0 ? ((targetDistance - acc) / segLen).clamp(0.0, 1.0) : 0.0;
        break;
      }
      acc += segLen;
    }

    final p1 = _effectiveRoute[segIndex];
    final p2 = _effectiveRoute[segIndex + 1];

    final curLat = p1.latitude + (p2.latitude - p1.latitude) * segRatio;
    final curLng = p1.longitude + (p2.longitude - p1.longitude) * segRatio;
    final newPos = LatLng(curLat, curLng);

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

    return (position: newPos, heading: heading, segmentIndex: segIndex);
  }

  void _setProgressOnRoute(double s, {bool updateCamera = true}) {
    if (!mounted || _effectiveRoute.length < 2) return;

    final clampedS = s.clamp(0.0, 1.0);
    final posInfo = _getPositionAtProgress(clampedS);
    final newPos = posInfo.position;
    final heading = posInfo.heading;
    final segIndex = posInfo.segmentIndex;

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
    final remainingMinutes = (_initialEtaMinutes * (1.0 - clampedS))
        .ceil()
        .clamp(1, _initialEtaMinutes);

    if (updateCamera && _followCar && _mapController != null) {
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
      _remainingEtaMinutes = remainingMinutes;
      _progressRatio = clampedS;
      _isStopped = false;
    });

    final now = DateTime.now();
    if (now.difference(_lastLiveUpdateSync).inMilliseconds > 2000) {
      _lastLiveUpdateSync = now;
      _syncLiveUpdate(progress: clampedS, etaMinutes: remainingMinutes);
    }
  }

  void _syncLiveUpdate({double? progress, int? etaMinutes, String? statusLabel}) {
    final effectiveRideId = widget.rideId ?? RideService.lastCreatedRideId;
    if (effectiveRideId == null || effectiveRideId.isEmpty) return;

    final effProgress = (progress ?? _progressRatio).clamp(0.0, 1.0);
    final effEta = etaMinutes ?? _remainingEtaMinutes;
    final isDone = effProgress >= 0.98 || (statusLabel?.contains('terminée') == true);
    final effLabel = statusLabel ?? (isDone ? 'Course terminée' : 'En route vers la destination');

    try {
      RideLiveUpdateServiceImpl().updateLiveUpdate(
        RideLiveUpdateData(
          rideId: effectiveRideId,
          driverName: widget.driver.name,
          carModel: widget.driver.carModel,
          carColor: widget.driver.carColor,
          licensePlate: widget.driver.licensePlate,
          departureText: widget.departure.mainText,
          destinationText: widget.destination.mainText,
          statusLabel: effLabel,
          phase: isDone ? RideLiveUpdatePhase.completed : RideLiveUpdatePhase.inProgress,
          etaMinutes: isDone ? 0 : effEta,
          progress: isDone ? 1.0 : effProgress,
          updatedAtTimestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (_) {}
  }

  void _updateProgress(double progress) {
    if (!mounted ||
        _hasReceivedRealGps ||
        _isOffline ||
        _effectiveRoute.length < 2 ||
        _totalRouteDistanceMeters <= 0) {
      return;
    }
    _setProgressOnRoute(progress.clamp(0.0, 1.0));
  }

  void _startSimulation() {
    if (_hasReceivedRealGps || _isOffline || _animController == null) return;
    if (_animController!.value >= 1.0) {
      _animController!.reset();
    }
    _animController!.forward();
  }

  /// Méthode publique prête pour connecter l'API backend / WebSockets en temps réel.
  /// Lorsque le serveur ou l'application chauffeur envoie une mise à jour GPS,
  /// cette méthode projette le véhicule sur la route réelle et anime son déplacement fluide.
  void updateCarLocation(LatLng newPosition, {double? heading}) {
    if (_isOffline) {
      // Hors-ligne: conserver strictement la dernière position connue sur la carte
      return;
    }

    _hasReceivedRealGps = true;
    _animController?.stop();

    final bool isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    final proj = _findClosestProjectionOnRoute(newPosition);
    final bool isSnapped = proj.distanceMeters <= 80.0;
    final targetPos = isSnapped ? proj.projectedPoint : newPosition;
    final targetHeading = heading ??
        (isSnapped
            ? proj.heading
            : _calculateBearing(_currentCarPosition, newPosition));

    if (isTest) {
      if (isSnapped) {
        _setProgressOnRoute(proj.progressRatio);
      } else {
        _applyExternalGpsLocation(targetPos, heading: targetHeading);
      }
      return;
    }

    // Anti-jitter: si le déplacement est négligeable (< 0.5m), ignorer
    final distChange = _haversineMeters(_currentCarPosition, targetPos);
    if (distChange < 0.5) {
      return;
    }

    _smoothCarController?.stop();

    if (isSnapped) {
      _isSnappedMovement = true;
      _startProgressRatio = _progressRatio;

      // Filtre anti-retour arrière: si le GPS recule légèrement (< 2.5% du trajet) à cause d'une imprécision satellite,
      // on ne fait pas faire marche arrière au véhicule sur le polyline
      double targetRatio = proj.progressRatio;
      if (targetRatio < _startProgressRatio &&
          (_startProgressRatio - targetRatio) < 0.025) {
        targetRatio = _startProgressRatio;
      }
      _targetProgressRatio = targetRatio;

      _animStartPos = _currentCarPosition;
      _animEndPos = targetPos;
      _animStartHeading = _currentCarHeading;
      _animEndHeading = targetHeading;

      _smoothCarController?.forward(from: 0.0);
    } else {
      _isSnappedMovement = false;
      _animStartPos = _currentCarPosition;
      _animEndPos = targetPos;
      _animStartHeading = _currentCarHeading;
      _animEndHeading = targetHeading;

      _smoothCarController?.forward(from: 0.0);
    }
  }

  void _applyExternalGpsLocation(LatLng newPosition, {double? heading}) {
    if (!mounted || _effectiveRoute.isEmpty) return;

    final proj = _findClosestProjectionOnRoute(newPosition);
    final bool isSnapped = proj.distanceMeters <= 80.0;
    final finalPos = isSnapped ? proj.projectedPoint : newPosition;
    final computedHeading = heading ??
        (isSnapped
            ? proj.heading
            : (proj.segmentIndex < _effectiveRoute.length - 1
                ? _calculateBearing(_effectiveRoute[proj.segmentIndex],
                    _effectiveRoute[proj.segmentIndex + 1])
                : _currentCarHeading));

    final traveled = <LatLng>[];
    for (int i = 0; i <= proj.segmentIndex; i++) {
      traveled.add(_effectiveRoute[i]);
    }
    traveled.add(finalPos);

    final remaining = <LatLng>[finalPos];
    for (int i = proj.segmentIndex + 1; i < _effectiveRoute.length; i++) {
      remaining.add(_effectiveRoute[i]);
    }

    final ratio = proj.progressRatio;

    // Si déviation de plus de 80m de la route, recalculer l'itinéraire vers la destination
    if (!isSnapped) {
      _checkRerouting(newPosition);
    }

    // Recentrage automatique fluide si le mode suivi est activé
    if (_followCar && _mapController != null) {
      final now = DateTime.now();
      if (now.difference(_lastCameraUpdateTime).inMilliseconds > 1000) {
        _lastCameraUpdateTime = now;
        _isProgrammaticCameraMove = true;
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(finalPos),
        );
      }
    }

    setState(() {
      _currentCarPosition = finalPos;
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
    if (_isOffline) {
      final phone = widget.driver.phoneNumber;
      final uri =
          Uri.parse('tel:${phone.isNotEmpty ? phone : "+221770000000"}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
      return;
    }
    await InAppCallPage.show(context, driver: widget.driver);
  }

  Future<void> _sendSmsDriver() async {
    final phone = widget.driver.phoneNumber;
    final uri = Uri.parse(
      'sms:${phone.isNotEmpty ? phone : ""}?body=${Uri.encodeComponent("Bonjour, je suis dans votre véhicule.")}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openChat() {
    if (_isOffline) {
      _sendSmsDriver();
      return;
    }
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

    if (_isOffline) {
      final text =
          'Suis mon trajet Seddo en direct vers ${widget.destination.mainText} avec ${widget.driver.name} (${widget.driver.carModel} ${widget.driver.licensePlate})';
      final uri = Uri.parse('sms:?body=${Uri.encodeComponent(text)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
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
      currentAddress: widget.departure.fullAddress.isNotEmpty
          ? widget.departure.fullAddress
          : widget.departure.mainText,
      etaText: widget.rideOption.estimatedArrival,
    );
  }

  void _toggleOfflineMode() {
    setState(() {
      _isOffline = !_isOffline;
    });
    if (_isOffline) {
      _animController?.stop();
      _smoothCarController?.stop();
    } else {
      _onNetworkRestored();
    }
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

  bool _isSosActive = false;

  void _openSosAlertSheet() {
    final effectiveRideId =
        widget.rideId ?? RideService.lastCreatedRideId ?? 'current';
    RideSosBottomSheet.show(
      context,
      rideId: effectiveRideId,
      currentPosition: _currentCarPosition,
      destination: widget.destination,
      driver: widget.driver,
      onSosTriggered: () {
        if (mounted) {
          setState(() {
            _isSosActive = true;
          });
        }
      },
    );
  }

  void _openSafetyModal() {
    final effectiveRideId =
        widget.rideId ?? RideService.lastCreatedRideId ?? 'current';
    SafetyModalWidget.show(
      context,
      destination: widget.destination,
      driver: widget.driver,
      rideId: effectiveRideId,
      currentPosition: _currentCarPosition,
    );
  }

  void _onTripCompleted() {
    _syncLiveUpdate(progress: 1.0, etaMinutes: 0, statusLabel: 'Course terminée');
    Navigator.of(context).pushReplacement(
      SlideRightToLeftRoute(
        page: RideRatingPage(
          departure: widget.departure,
          destination: widget.destination,
          driver: widget.driver,
          rideOption: widget.rideOption,
          arrivalTime: widget.rideOption.estimatedArrival,
          paymentPhone: _paymentPhone ?? widget.paymentPhone ?? '77 ••• 45 12',
          paymentMethod: _paymentMethod ?? widget.paymentMethod,
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

          // 1. Fullscreen Google Map avec pinch-to-zoom et contrôle gestuel fluide (clipped to remove Google logo)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: AppConstants.mapLogoClipOffset,
            child: Listener(
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
        ),

          // Bannière hors-ligne : "Connexion perdue, dernière mise à jour il y a X min"
          ActiveRideOfflineBanner(
            isOffline: _isOffline,
            lastUpdateTime: _lastDriverLocationTime,
            onRetry: _onNetworkRestored,
          ),

          if (!_isOffline)
            // Floating Top Bar with Siren Button on right
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                  vertical: AppConstants.spacingSm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Bouton rouge flottant d'appel d'urgence / sécurité
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
                        icon: Icon(
                          _isSosActive
                              ? Icons.crisis_alert_rounded
                              : Icons.notifications_active_rounded,
                          color: AppColors.white,
                          size: 20,
                        ),
                        onPressed: _openSosAlertSheet,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 2.bis Floating Active SOS Alert Banner
          if (_isSosActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.sirenRed,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadowMarker,
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.crisis_alert_rounded,
                      color: AppColors.white,
                      size: 22,
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    Expanded(
                      child: Text(
                        'safety.sos_active_banner'.tr(),
                        style: GoogleFonts.inter(
                          color: AppColors.white,
                          fontSize: AppConstants.fontSm,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _isSosActive = false),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.white,
                        size: 20,
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
                      // Vue détaillée en mode hors-ligne :
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

                      // Tuile d'urgence par SMS (sans connexion internet)
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
                        isOffline: true,
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
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Driver Summary Card with initials avatar, 3D vehicle and "✓ Payé" badge
                    ActiveDriverCardWidget(
                      driver: widget.driver,
                      isPaid: true,
                      isOffline: _isOffline,
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
