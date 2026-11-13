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
import 'package:seddo/features/ride/data/models/ride_quote_model.dart';
import 'package:seddo/features/ride/data/services/ride_eta_calculator.dart';
import 'package:seddo/features/ride/presentation/pages/driver_chat_page.dart';
import 'package:seddo/features/ride/presentation/pages/in_app_call_page.dart';
import 'package:seddo/features/ride/presentation/pages/ride_rating_page.dart';
import 'package:seddo/features/ride/presentation/pages/ride_cancelled_page.dart';
import 'package:seddo/features/ride/presentation/pages/shared_ride_tracking_page.dart';
import 'package:seddo/features/ride/data/services/active_ride_offline_storage.dart';
import 'package:seddo/features/ride/presentation/widgets/active_ride_offline_banner.dart';
import 'package:seddo/services/network_connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  late DriverModel _currentDriver;
  GoogleMapController? _mapController;
  BitmapDescriptor? _carMarkerIcon;
  BitmapDescriptor? _pickupBadgeIcon;
  BitmapDescriptor? _destBadgeIcon;

  // Route & Realtime Tracking State
  AnimationController? _smoothCarController;
  bool _hasReceivedRealGps = false;
  late List<LatLng> _effectiveRoute;
  late LatLng _currentCarPosition;
  double _currentCarHeading = 0.0;
  List<LatLng> _traveledPoints = [];
  List<LatLng> _remainingPoints = [];
  List<TrafficSegmentModel> _traffic = [];
  late double _remainingDistanceKm;
  late int _remainingEtaMinutes;

  @visibleForTesting
  int get remainingEtaMinutes => _remainingEtaMinutes;

  @visibleForTesting
  double get remainingDistanceKm => _remainingDistanceKm;

  @visibleForTesting
  LatLng get currentCarPosition => _currentCarPosition;

  @visibleForTesting
  bool get isOffline => _isOffline;

  @visibleForTesting
  bool get hasReceivedRealGps => _hasReceivedRealGps;
  double _progressRatio = 0.0;
  final bool _isStopped = false;
  bool _driverArrivedAtDestination = false;
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
  DateTime _lastRerouteFetchTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _currentRouteVersion = 0;
  DateTime _lastRouteUpdateTime = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _stalePositionCheckTimer;
  Timer? _pollTimer;
  bool _isPositionUpdating = false;

  /// Whether to display the simulation toggle button in the bottom sheet.
  /// Kept in code for later use as requested by the user.
  static const bool _showNetworkSimulationControls = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rideService = widget.rideService ?? RideService();
    _currentDriver = widget.driver;
    _isOffline = widget.isOffline;
    _paymentMethod = widget.paymentMethod;
    _paymentPhone = widget.paymentPhone;
    _traffic = List<TrafficSegmentModel>.from(widget.rideOption.traffic);
    _currentSheetExtent = _isOffline ? 0.25 : 0.38;
    _initRoute();
    _persistLocalState();
    _startOfflineMonitor();
    _loadCustomMarkers();
    _startOrSyncLiveUpdate();

    final bool isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    if (!isTest || !widget.isOffline) {
      NetworkConnectivityService.isConnected.then((online) {
        if (mounted && online && _isOffline) {
          _onNetworkRestored();
        }
      });
    }

    final effectiveRideId =
        widget.rideId ?? RideService.lastCreatedRideId ?? '';

    // Contrôleur conservé pour cycle de vie sans animation artificielle
    _smoothCarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Connexion WebSocket en direct pour suivre la course (PDF Seddo)
    if (effectiveRideId.isNotEmpty) {
      RealtimeService().connect();
      RealtimeService().joinRide(effectiveRideId);

      // Appliquer immédiatement le dernier statut en mémoire WebSocket
      final cachedStatus = RealtimeService().lastRideStatusEvent;
      if (cachedStatus != null) {
        final matchesRide = cachedStatus.rideId.isEmpty ||
            cachedStatus.rideId == effectiveRideId ||
            cachedStatus.rideId.endsWith(effectiveRideId) ||
            effectiveRideId.endsWith(cachedStatus.rideId);
        if (matchesRide) {
          final s = cachedStatus.status.toUpperCase();
          if (s == 'COMPLETED' || s == 'FINISHED' || s == 'DONE' || s == 'RIDE_COMPLETED') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _cleanupRealtime();
                _onTripCompleted();
              }
            });
          }
        }
      }

      _realtimeStatusSub =
          RealtimeService().rideStatusStream.listen((event) {
        if (!mounted) return;
        final matchesRide = event.rideId.isEmpty ||
            event.rideId == effectiveRideId ||
            event.rideId.endsWith(effectiveRideId) ||
            effectiveRideId.endsWith(event.rideId);
        if (matchesRide) {
          // Si l'événement statut ou mise à jour de course inclut un nouvel itinéraire
          final raw = event.raw;
          final rideObj = raw['ride'] is Map<String, dynamic>
              ? raw['ride'] as Map<String, dynamic>
              : (raw['data'] is Map<String, dynamic>
                  ? raw['data'] as Map<String, dynamic>
                  : raw);
          final rawPoly = rideObj['plannedPolyline'] ??
              rideObj['polyline'] ??
              (rideObj['route'] is Map ? rideObj['route']['polyline'] : null);
          if (rawPoly is String && rawPoly.isNotEmpty) {
            final pts = RouteService.decodePolyline(rawPoly);
            if (pts.length >= 2 && pts != _effectiveRoute) {
              debugPrint('[ActiveRide] 🔄 Nouvel itinéraire reçu dans le statut/raw: ${pts.length} pts');
              _setNewRoute(pts);
            }
          }

          final s = event.status.toUpperCase();
          if (s == 'ARRIVED' || s == 'DRIVER_ARRIVED' || s == 'DRIVER_AT_DESTINATION') {
            setState(() {
              _driverArrivedAtDestination = true;
            });
          } else if (s == 'COMPLETED' ||
              s == 'FINISHED' ||
              s == 'DONE' ||
              s == 'RIDE_COMPLETED') {
            _cleanupRealtime();
            _onTripCompleted();
          } else if (s.startsWith('CANCEL')) {
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
        final matchesRide = event.rideId == null ||
            event.rideId!.isEmpty ||
            event.rideId == effectiveRideId ||
            event.rideId!.endsWith(effectiveRideId) ||
            effectiveRideId.endsWith(event.rideId!);
        if (matchesRide) {
          _lastDriverLocationTime = DateTime.now();
          if (_isPositionUpdating) {
            setState(() {
              _isPositionUpdating = false;
            });
          }

          // 1. polyline : tracé restant
          // Ne JAMAIS écraser _effectiveRoute ici avec event.remainingPoints (sinon l'itinéraire complet est détruit
          // et clignote si un ancien paquet télémétrie arrive après un recalcul).
          final now = DateTime.now();
          final isRecentReroute =
              now.difference(_lastRouteUpdateTime).inSeconds < 8;
          final isOlderVersion =
              event.version > 0 && event.version < _currentRouteVersion;

          if (event.remainingPoints.length >= 2 &&
              !isRecentReroute &&
              !isOlderVersion) {
            setState(() {
              _remainingPoints = List<LatLng>.from(event.remainingPoints);
              if (event.traffic.isNotEmpty) {
                _traffic = event.traffic;
              }
            });
          } else if (event.traffic.isNotEmpty) {
            setState(() {
              _traffic = event.traffic;
            });
          }

          // 2. remainingM, etaS : distance et temps restants, barre de progression, Live Activity
          final effectiveRemainingM = event.remainingM ?? event.distanceMeters;
          if (effectiveRemainingM != null && effectiveRemainingM > 0) {
            setState(() {
              _remainingDistanceKm = effectiveRemainingM > 100
                  ? effectiveRemainingM / 1000.0
                  : effectiveRemainingM;
            });
          }

          final effectiveEtaS = event.etaS;
          if (effectiveEtaS != null && effectiveEtaS > 0) {
            final mins = (effectiveEtaS / 60.0).ceil();
            setState(() {
              _remainingEtaMinutes = mins;
            });
            _syncLiveUpdate(etaMinutes: mins);
          } else if (event.etaMinutes != null && event.etaMinutes! > 0) {
            setState(() {
              _remainingEtaMinutes = event.etaMinutes!;
            });
            _syncLiveUpdate(etaMinutes: event.etaMinutes!);
          }

          // 3. animateMs, lat, lng, heading : animation fluide voiture et caméra
          updateCarLocation(
            event.location,
            heading: event.heading,
            animateMs: event.animateMs,
          );
        }
      });

      _realtimeEtaSub = RealtimeService().rideEtaStream.listen((event) {
        if (!mounted) return;
        final matchesRide = event.rideId == null ||
            event.rideId!.isEmpty ||
            event.rideId == effectiveRideId ||
            event.rideId!.endsWith(effectiveRideId) ||
            effectiveRideId.endsWith(event.rideId!);
        if (matchesRide) {
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
        final matchesRide = event.rideId == null ||
            event.rideId!.isEmpty ||
            event.rideId == effectiveRideId ||
            event.rideId!.endsWith(effectiveRideId) ||
            effectiveRideId.endsWith(event.rideId!);
        if (matchesRide) {
          if (event.points.length >= 2) {
            debugPrint(
                '[ActiveRide] 🗺️ Nouvel itinéraire reçu via rideRouteStream (${event.points.length} points, v${event.version})');
            final newVer = event.version > 0
                ? event.version
                : (_currentRouteVersion + 1);
            _setNewRoute(event.points, version: newVer, force: true);
            if (event.traffic.isNotEmpty) {
              setState(() {
                _traffic = event.traffic;
              });
            }
            if (event.distanceMeters != null && event.distanceMeters! > 0) {
              setState(() {
                _remainingDistanceKm = event.distanceMeters! / 1000.0;
              });
            }
            if (event.durationSeconds != null && event.durationSeconds! > 0) {
              setState(() {
                _remainingEtaMinutes = (event.durationSeconds! / 60.0).ceil();
              });
            }
          }
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

      // Filet de sécurité actif : vérification périodique (toutes les 6s)
      if (!isTest) {
        _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
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

    // 1. Course arrivée ou terminée
    if (status == 'ARRIVED' || status == 'DRIVER_ARRIVED' || status == 'DRIVER_AT_DESTINATION') {
      setState(() {
        _driverArrivedAtDestination = true;
      });
    } else if (status == 'COMPLETED' ||
        status == 'FINISHED' ||
        status == 'DONE' ||
        status == 'RIDE_COMPLETED') {
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
    final restVersion = (rideObj['routeVersion'] ??
            rideObj['version'] ??
            routeObj?['version'] as num?)
        ?.toInt() ?? 0;
    if (plannedPolyStr != null && plannedPolyStr.isNotEmpty) {
      final tripPts = RouteService.decodePolyline(plannedPolyStr);
      // Ne remplacer la route que si les points correspondent à un vrai tracé routier (>= 2 points)
      if (tripPts.length >= 2 && tripPts != _effectiveRoute) {
        _setNewRoute(tripPts, version: restVersion);
      }
    }

    // 4. Mise à jour de la position GPS du chauffeur si retournée
    final driverObj = rideObj['driver'] is Map<String, dynamic>
        ? rideObj['driver'] as Map<String, dynamic>
        : null;

    if (driverObj != null) {
      final dName = driverObj['name'] as String? ?? (driverObj['fullName'] as String?);
      final dPlate = driverObj['licensePlate'] as String? ?? (driverObj['plate'] as String?);
      final dCarModel = driverObj['vehicleModel'] as String? ?? (driverObj['carModel'] as String?);
      final dCarColor = driverObj['vehicleColor'] as String? ?? (driverObj['carColor'] as String?);
      final dPhone = driverObj['phoneNumber'] as String? ?? (driverObj['phone'] as String?);

      if (dName != null || dPlate != null || dCarModel != null || dCarColor != null) {
        _currentDriver = _currentDriver.copyWith(
          name: dName ?? _currentDriver.name,
          licensePlate: dPlate ?? _currentDriver.licensePlate,
          carModel: dCarModel ?? _currentDriver.carModel,
          carColor: dCarColor ?? _currentDriver.carColor,
          phone: dPhone ?? _currentDriver.phone,
        );
      }
    }
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

    final durS = (rideObj['durationSeconds'] ??
            rideObj['duration'] ??
            routeObj?['durationSeconds'] ??
            routeObj?['duration'] as num?)
        ?.toInt();
    final etaM = (rideObj['etaMinutes'] ??
            rideObj['eta'] ??
            (durS != null && durS > 0 ? (durS / 60.0).ceil() : null) as num?)
        ?.toInt();
    final distM = (rideObj['distanceMeters'] ??
            rideObj['distance'] ??
            routeObj?['distanceMeters'] ??
            routeObj?['distance'] as num?)
        ?.toDouble();

    if (etaM != null && etaM > 0) {
      _remainingEtaMinutes = etaM;
    }
    if (distM != null && distM > 0) {
      _remainingDistanceKm = distM > 100 ? distM / 1000.0 : distM;
    }

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

    final effectiveRideId =
        widget.rideId ?? RideService.lastCreatedRideId ?? '';

    // 1. Débloquer immédiatement l'interface utilisateur et masquer la bannière
    if (mounted) {
      setState(() {
        _isOffline = false;
        _currentSheetExtent = 0.38;
      });
      if (_effectiveRoute.length < 2) {
        _loadRoadRoute();
      }
    }

    // 2. Reconnexion WebSocket en tâche de fond
    RealtimeService().connect();
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
    _smoothCarController?.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _initRoute() {
    // Prioriser la polyline passée en paramètre si elle contient un tracé routier valide
    if (widget.polylinePoints.length >= 2) {
      _effectiveRoute = List<LatLng>.from(widget.polylinePoints);
    } else {
      // Ne JAMAIS tracer de vol d'oiseau artificiel (lignes droites entre départ et destination)
      _effectiveRoute = [];
    }

    // Position initiale du véhicule
    if (_effectiveRoute.isNotEmpty) {
      _currentCarPosition = _effectiveRoute.first;
      if (_effectiveRoute.length >= 2) {
        _currentCarHeading =
            _calculateBearing(_effectiveRoute[0], _effectiveRoute[1]);
      }
    } else {
      _currentCarPosition =
          LatLng(widget.departure.latitude, widget.departure.longitude);
      _currentCarHeading = 0.0;
    }

    final optDistKm = (widget.rideOption.distanceM != null &&
            widget.rideOption.distanceM! > 0)
        ? widget.rideOption.distanceM! / 1000.0
        : 5.0;
    _remainingDistanceKm = widget.driver.distanceKm > 0
        ? widget.driver.distanceKm
        : optDistKm;

    final optEtaMin = (widget.rideOption.durationS != null &&
            widget.rideOption.durationS! > 0)
        ? (widget.rideOption.durationS! / 60).ceil()
        : 12;
    _remainingEtaMinutes = widget.driver.etaMinutes > 0
        ? widget.driver.etaMinutes
        : optEtaMin;

    _traveledPoints = [];
    _remainingPoints = List<LatLng>.from(_effectiveRoute);
    _progressRatio = 0.0;

    // Si pas de route routière valide, charger les vraies routes
    if (_effectiveRoute.length < 2) {
      _loadRoadRoute();
    }
  }

  void _setNewRoute(List<LatLng> newRoute,
      {int version = 0, bool force = false}) {
    if (newRoute.length < 2) return;
    final now = DateTime.now();

    // Protection 1 : Rejet des versions de route strictement antérieures
    if (!force && version > 0 && version < _currentRouteVersion) {
      debugPrint(
          '[ActiveRide] 🛡️ Ignoré itinéraire obsolète v$version (version courante v$_currentRouteVersion)');
      return;
    }

    // Protection 2 : Verrou anti-clignotement pendant 8 secondes après un recalcul
    // Rejette les tracés non-versionnés (ex: polling REST GET /v1/rides/{id} en cache)
    if (!force &&
        version == 0 &&
        _currentRouteVersion > 0 &&
        now.difference(_lastRouteUpdateTime).inSeconds < 8) {
      debugPrint(
          '[ActiveRide] 🛡️ Verrou recalcul actif : tracé REST non versionné ignoré pour éviter tout clignotement');
      return;
    }

    if (version > _currentRouteVersion) {
      _currentRouteVersion = version;
    }
    _lastRouteUpdateTime = now;

    setState(() {
      _effectiveRoute = List<LatLng>.from(newRoute);
      // Si aucun GPS réel n'a encore été reçu, positionner le véhicule au début
      if (!_hasReceivedRealGps) {
        _currentCarPosition = _effectiveRoute.first;
        if (_effectiveRoute.length >= 2) {
          _currentCarHeading =
              _calculateBearing(_effectiveRoute[0], _effectiveRoute[1]);
        }
      }
      _updateRouteProgressForCar(_currentCarPosition);
    });
  }

  int _findNearestRouteIndex(LatLng point) {
    if (_effectiveRoute.isEmpty) return 0;
    int nearestIndex = 0;
    double minDistance = double.infinity;
    for (int i = 0; i < _effectiveRoute.length; i++) {
      final p = _effectiveRoute[i];
      final dLat = p.latitude - point.latitude;
      final dLon = p.longitude - point.longitude;
      final distSq = dLat * dLat + dLon * dLon;
      if (distSq < minDistance) {
        minDistance = distSq;
        nearestIndex = i;
      }
    }
    return nearestIndex;
  }

  /// Découpe la route réelle en tronçon parcouru et tronçon restant basé sur
  /// la vraie position du chauffeur reçue en direct sans jamais déplacer ou contraindre la voiture
  /// et SANS JAMAIS tracer de ligne artificielle en vol d'oiseau vers la voiture.
  void _updateRouteProgressForCar(LatLng curPos) {
    if (_effectiveRoute.length < 2) {
      _traveledPoints = [];
      _remainingPoints = [];
      return;
    }

    final nearestIdx = _findNearestRouteIndex(curPos);
    final nearestPt = _effectiveRoute[nearestIdx];
    final distToRoute = _haversineMeters(curPos, nearestPt);

    // Tronçon déjà parcouru : uniquement composé des points réels de la polyline backend
    final traveled = <LatLng>[];
    for (int i = 0; i <= nearestIdx && i < _effectiveRoute.length; i++) {
      traveled.add(_effectiveRoute[i]);
    }

    // Tronçon restant : uniquement composé des points réels de la polyline backend
    // Ne JAMAIS ajouter curPos ici pour éradiquer tout tracé en vol d'oiseau
    final remaining = <LatLng>[];
    for (int i = nearestIdx; i < _effectiveRoute.length; i++) {
      remaining.add(_effectiveRoute[i]);
    }

    _traveledPoints = traveled;
    _remainingPoints = remaining;
    _progressRatio = (_effectiveRoute.length > 1)
        ? (nearestIdx / (_effectiveRoute.length - 1)).clamp(0.0, 1.0)
        : 0.0;

    // SUPPRESSION STRICTE DE TOUT CALCUL CÔTÉ FRONT DU TRAJET :
    // Dès qu'une course est active côté backend ou qu'un signal GPS réel est reçu,
    // toutes les métriques (ETA, distance restante) proviennent EXCLUSIVEMENT du backend (WebSocket / REST).
    // Aucun recalcul local n'est effectué pour garantir une concordance 100% avec le chauffeur.

    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    final effectiveRideId =
        widget.rideId ?? RideService.lastCreatedRideId ?? '';
    if (effectiveRideId.isNotEmpty &&
        distToRoute > 100.0 &&
        mounted &&
        !isTest &&
        !_isOffline &&
        DateTime.now().difference(_lastRerouteFetchTime).inSeconds > 15) {
      _lastRerouteFetchTime = DateTime.now();
      _fetchRideDetails(effectiveRideId);
    }

    final now = DateTime.now();
    if (now.difference(_lastLiveUpdateSync).inMilliseconds > 2000) {
      _lastLiveUpdateSync = now;
      _syncLiveUpdate();
    }

    if (_followCar && _mapController != null) {
      if (now.difference(_lastCameraUpdateTime).inMilliseconds > 1000) {
        _lastCameraUpdateTime = now;
        _isProgrammaticCameraMove = true;
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(curPos),
        );
      }
    }
  }

  Future<void> _loadRoadRoute() async {
    final effectiveRideId =
        widget.rideId ?? RideService.lastCreatedRideId ?? '';
    // Pour une course réelle connectée au backend, le client ne calcule JAMAIS la route lui-même.
    // L'itinéraire provient EXCLUSIVEMENT du backend (plannedPolyline / ride.route.updated).
    if (effectiveRideId.isNotEmpty) {
      _fetchRideDetails(effectiveRideId);
      return;
    }

    try {
      final origin =
          LatLng(widget.departure.latitude, widget.departure.longitude);
      final dest =
          LatLng(widget.destination.latitude, widget.destination.longitude);
      final details =
          await RouteService().getRoute(origin: origin, destination: dest);
      if (details.polylinePoints.length >= 2 && mounted) {
        _setNewRoute(details.polylinePoints);
        if (!_hasReceivedRealGps) {
          if (details.distanceKm > 0) {
            setState(() {
              _remainingDistanceKm = details.distanceKm;
            });
          }
          if (details.durationMinutes > 0) {
            setState(() {
              _remainingEtaMinutes = details.durationMinutes;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[ActiveRidePage] Note route loading fallback: $e');
    }
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

  void _startOrSyncLiveUpdate() {
    final effectiveRideId =
        widget.rideId ?? RideService.lastCreatedRideId ?? 'seddo_active_ride';
    final data = RideLiveUpdateData(
      rideId: effectiveRideId,
      driverName: _currentDriver.name,
      carModel: _currentDriver.carModel,
      carColor: _currentDriver.carColor,
      licensePlate: _currentDriver.licensePlate,
      departureText: widget.departure.mainText,
      destinationText: widget.destination.mainText,
      statusLabel: 'En route vers ${widget.destination.mainText}',
      phase: RideLiveUpdatePhase.inProgress,
      etaMinutes: _remainingEtaMinutes,
      progress: 0.05,
      updatedAtTimestamp: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      RideLiveUpdateServiceImpl().startLiveUpdate(data);
    } catch (_) {
      RideLiveUpdateServiceImpl().updateLiveUpdate(data);
    }
  }

  void _syncLiveUpdate({double? progress, int? etaMinutes, String? statusLabel}) {
    final effectiveRideId =
        widget.rideId ?? RideService.lastCreatedRideId ?? 'seddo_active_ride';

    final effProgress = (progress ?? _progressRatio).clamp(0.0, 1.0);
    final effEta = etaMinutes ?? _remainingEtaMinutes;
    // La course n'est terminée QUE si le chauffeur ou le backend a explicitement clôturé la course
    final isDone = statusLabel != null && statusLabel.contains('terminée');
    final effLabel = statusLabel ??
        (_driverArrivedAtDestination
            ? 'Arrivé à destination'
            : 'En route vers ${widget.destination.mainText}');

    try {
      RideLiveUpdateServiceImpl().updateLiveUpdate(
        RideLiveUpdateData(
          rideId: effectiveRideId,
          driverName: _currentDriver.name,
          carModel: _currentDriver.carModel,
          carColor: _currentDriver.carColor,
          licensePlate: _currentDriver.licensePlate,
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

  /// Méthode appelée lorsque le serveur envoie une mise à jour GPS du chauffeur (via WebSocket driverLocationStream).
  /// Positionne le véhicule exactement là où se trouve le chauffeur en animant son déplacement de manière fluide.
  void updateCarLocation(
    LatLng newPosition, {
    double? heading,
    int? animateMs,
  }) {
    if (_isOffline) {
      // Hors-ligne: conserver strictement la dernière position connue sur la carte
      return;
    }

    _hasReceivedRealGps = true;

    // Supprimer toutes les animations côté front : le backend calcule et transmet
    // directement la position et le cap/heading exacts.
    final targetHeading = heading ?? _currentCarHeading;

    setState(() {
      _currentCarPosition = newPosition;
      _currentCarHeading = targetHeading;
      _updateRouteProgressForCar(newPosition);
    });

    // Suivi de caméra fluide avec la position reçue
    if (_followCar && _mapController != null) {
      _isProgrammaticCameraMove = true;
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(newPosition),
      );
    }
  }

  @visibleForTesting
  void applyExternalGpsLocation(LatLng newPosition, {double? heading}) {
    if (!mounted) return;
    final targetHeading = heading ?? _currentCarHeading;
    setState(() {
      _currentCarPosition = newPosition;
      _currentCarHeading = targetHeading;
      _updateRouteProgressForCar(newPosition);
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
    final effectiveRideId = widget.rideId ?? RideService.lastCreatedRideId;
    if (effectiveRideId != null && effectiveRideId.isNotEmpty) {
      RideService.lastCompletedRideId = effectiveRideId;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('seddo_last_completed_ride_id', effectiveRideId);
      });
    }
    ActiveRideOfflineStorage.clearActiveRide();
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
          rideId: effectiveRideId,
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
    if (_effectiveRoute.length < 2) return {};

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
    // Ne JAMAIS tracer de ligne droite artificielle en vol d'oiseau
    final activePts = _remainingPoints.length >= 2
        ? _remainingPoints
        : _effectiveRoute;

    if (activePts.length >= 2) {
      final activePolylines = RideEtaCalculator.buildTrafficPolylines(
        baseId: 'active_route',
        points: activePts,
        traffic: _traffic.isNotEmpty ? _traffic : widget.rideOption.traffic,
        width: 4,
      );
      polylines.addAll(activePolylines);
    }

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
                        driver: _currentDriver,
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
                                          : (_driverArrivedAtDestination
                                              ? AppColors.success
                                              : AppColors.yangoRouteGreen),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _driverArrivedAtDestination
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                      driver: _currentDriver,
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
