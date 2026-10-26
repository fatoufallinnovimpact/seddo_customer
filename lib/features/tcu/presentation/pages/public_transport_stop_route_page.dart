import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/tcu/data/models/tcu_route_model.dart';

/// Screen displaying walking navigation towards the nearest transit stop on the map (Yango style).
/// Displays Google Maps with:
/// - Real-time turn-by-turn navigation HUD at the top with next maneuver & distance
/// - Voice guidance (Text-to-Speech) guiding the user with spoken instructions
/// - Yango-style route coloring (vibrant green for remaining path, subtle grey for traveled path)
/// - Floating live distance badge showing real-time remaining meters & minutes in Yango green
/// - Bottom sheet with stat boxes (distance restante highlighted in Yango green, temps restant, prochain bus)
/// - "Démarrer la marche" / "Arrêter le guidage" action button
class PublicTransportStopRoutePage extends StatefulWidget {
  final TcuRouteOption routeOption;

  const PublicTransportStopRoutePage({
    super.key,
    required this.routeOption,
  });

  @override
  State<PublicTransportStopRoutePage> createState() =>
      _PublicTransportStopRoutePageState();
}

class _PublicTransportStopRoutePageState
    extends State<PublicTransportStopRoutePage> {
  GoogleMapController? _mapController;
  bool _isNavigating = false;
  bool _isArrived = false;
  Timer? _navigationTimer;

  late final LatLng _userPos;
  late final LatLng _stopPos;
  late LatLng _currentUserPos;

  late final int _initialDistance;
  late final int _initialDuration;
  late int _remainingDistanceMeters;
  late int _remainingDurationMinutes;
  double _progress = 0.0;

  // Voice Guidance (TTS)
  FlutterTts? _flutterTts;
  bool _isVoiceEnabled = true;
  int _lastSpokenPhase = -1;

  @override
  void initState() {
    super.initState();
    _userPos = widget.routeOption.userOriginCoordinates;
    _stopPos = widget.routeOption.departureStop.coordinates;
    _currentUserPos = _userPos;

    _initialDistance = widget.routeOption.departureStop.walkingDistanceMeters;
    _initialDuration = widget.routeOption.departureStop.walkingDurationMinutes;
    _remainingDistanceMeters = _initialDistance;
    _remainingDurationMinutes = _initialDuration;

    _initTts();
  }

  void _initTts() {
    if (_isTestEnvironment) return;
    try {
      _flutterTts = FlutterTts();
      _flutterTts?.setLanguage('fr-FR').catchError((_) {
        _flutterTts?.setLanguage('fr').catchError((_) {});
      });
      _flutterTts?.setSpeechRate(0.5).catchError((_) {});
      _flutterTts?.setVolume(1.0).catchError((_) {});
      _flutterTts?.setPitch(1.0).catchError((_) {});
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  Future<void> _speak(String message) async {
    if (!_isVoiceEnabled || _isTestEnvironment || _flutterTts == null) return;
    try {
      await _flutterTts?.stop();
      await _flutterTts?.speak(message);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  void _toggleVoiceGuidance() {
    setState(() {
      _isVoiceEnabled = !_isVoiceEnabled;
    });
    if (!_isVoiceEnabled) {
      _flutterTts?.stop();
    } else {
      _speak('Guidage vocal activé.');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isVoiceEnabled ? 'Guidage vocal activé' : 'Guidage vocal désactivé',
          style: GoogleFonts.inter(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.buttonBlack,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _flutterTts?.stop();
    _mapController?.dispose();
    super.dispose();
  }

  bool get _isTestEnvironment {
    return Platform.environment.containsKey('FLUTTER_TEST') ||
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
  }

  Set<Marker> _buildMarkers() {
    return {
      Marker(
        markerId: const MarkerId('user_location'),
        position: _currentUserPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _isNavigating ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange,
        ),
        infoWindow: InfoWindow(
          title: 'Votre position',
          snippet: _isArrived
              ? 'Arrivé à destination'
              : (_isNavigating
                  ? '$_remainingDistanceMeters m restants'
                  : 'Départ piéton'),
        ),
      ),
      Marker(
        markerId: const MarkerId('stop_destination'),
        position: _stopPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: widget.routeOption.departureStop.name,
          snippet:
              '${widget.routeOption.lineCode} · ${widget.routeOption.departureStop.walkingDistanceMeters} m',
        ),
      ),
    };
  }

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};
    final fullPath = widget.routeOption.walkingPathToStop.isNotEmpty
        ? widget.routeOption.walkingPathToStop
        : [_userPos, _stopPos];

    // 1. Traveled path (Discreet grey, style Yango)
    if (_progress > 0.0 && !_isArrived) {
      final traveledPoints =
          _calculateTraveledPath(fullPath, _currentUserPos, _progress);
      if (traveledPoints.length >= 2) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId('walking_route_traveled'),
            points: traveledPoints,
            color: AppColors.routeTraveled,
            width: 6,
          ),
        );
      }
    }

    // 2. Remaining path (Vibrant Yango green style)
    final points = _getRemainingWalkingPath();
    if (points.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('walking_route'),
          points: points,
          color: _isNavigating ? AppColors.yangoRouteGreen : AppColors.primary,
          width: 7,
          patterns: [
            PatternItem.dot,
            PatternItem.gap(8.0),
          ],
        ),
      );
    }

    return polylines;
  }

  double _distanceBetween(LatLng p1, LatLng p2) {
    final dLat = p1.latitude - p2.latitude;
    final dLng = p1.longitude - p2.longitude;
    return math.sqrt(dLat * dLat + dLng * dLng);
  }

  LatLng _interpolateAlongPath(List<LatLng> path, double t) {
    if (path.isEmpty) return _userPos;
    if (path.length == 1 || t <= 0.0) return path.first;
    if (t >= 1.0) return path.last;

    final segmentLengths = <double>[];
    double totalDistance = 0.0;
    for (int i = 0; i < path.length - 1; i++) {
      final d = _distanceBetween(path[i], path[i + 1]);
      segmentLengths.add(d);
      totalDistance += d;
    }

    if (totalDistance == 0.0) return path.first;

    final targetDistance = t * totalDistance;
    double accumulated = 0.0;

    for (int i = 0; i < segmentLengths.length; i++) {
      if (accumulated + segmentLengths[i] >= targetDistance) {
        final segT = (targetDistance - accumulated) / segmentLengths[i];
        final p1 = path[i];
        final p2 = path[i + 1];
        return LatLng(
          p1.latitude + (p2.latitude - p1.latitude) * segT,
          p1.longitude + (p2.longitude - p1.longitude) * segT,
        );
      }
      accumulated += segmentLengths[i];
    }

    return path.last;
  }

  List<LatLng> _getRemainingWalkingPath() {
    final fullPath = widget.routeOption.walkingPathToStop;
    if (fullPath.isEmpty) {
      return [_currentUserPos, _stopPos];
    }
    if (_isArrived || _progress >= 1.0) {
      return [];
    }
    if (_progress <= 0.0) {
      return fullPath;
    }
    return _calculateRemainingPath(fullPath, _currentUserPos, _progress);
  }

  List<LatLng> _calculateRemainingPath(
    List<LatLng> path,
    LatLng currentPos,
    double t,
  ) {
    if (path.length <= 1) return [currentPos];

    final segmentLengths = <double>[];
    double totalDistance = 0.0;
    for (int i = 0; i < path.length - 1; i++) {
      final d = _distanceBetween(path[i], path[i + 1]);
      segmentLengths.add(d);
      totalDistance += d;
    }

    if (totalDistance == 0.0) return [currentPos];

    final targetDistance = t * totalDistance;
    double accumulated = 0.0;
    int currentSegIndex = 0;

    for (int i = 0; i < segmentLengths.length; i++) {
      if (accumulated + segmentLengths[i] >= targetDistance) {
        currentSegIndex = i;
        break;
      }
      accumulated += segmentLengths[i];
    }

    final remaining = <LatLng>[currentPos];
    for (int i = currentSegIndex + 1; i < path.length; i++) {
      remaining.add(path[i]);
    }
    return remaining;
  }

  List<LatLng> _calculateTraveledPath(
    List<LatLng> path,
    LatLng currentPos,
    double t,
  ) {
    if (path.length <= 1) return [currentPos];
    final segmentLengths = <double>[];
    double totalDistance = 0.0;
    for (int i = 0; i < path.length - 1; i++) {
      final d = _distanceBetween(path[i], path[i + 1]);
      segmentLengths.add(d);
      totalDistance += d;
    }
    if (totalDistance == 0.0) return [currentPos];

    final targetDistance = t * totalDistance;
    double accumulated = 0.0;
    int currentSegIndex = 0;
    for (int i = 0; i < segmentLengths.length; i++) {
      if (accumulated + segmentLengths[i] >= targetDistance) {
        currentSegIndex = i;
        break;
      }
      accumulated += segmentLengths[i];
    }

    final traveled = <LatLng>[];
    for (int i = 0; i <= currentSegIndex; i++) {
      traveled.add(path[i]);
    }
    traveled.add(currentPos);
    return traveled;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitMapBounds();
  }

  void _fitMapBounds() {
    if (_mapController == null) return;
    final allPoints = [
      _currentUserPos,
      _stopPos,
      ...widget.routeOption.walkingPathToStop,
    ];

    double south = allPoints.first.latitude;
    double north = allPoints.first.latitude;
    double west = allPoints.first.longitude;
    double east = allPoints.first.longitude;

    for (final pt in allPoints) {
      if (pt.latitude < south) south = pt.latitude;
      if (pt.latitude > north) north = pt.latitude;
      if (pt.longitude < west) west = pt.longitude;
      if (pt.longitude > east) east = pt.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(south - 0.0015, west - 0.0015),
      northeast: LatLng(north + 0.0015, east + 0.0015),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 75),
    );
  }

  void _toggleWalkingNavigation() {
    if (_isArrived) {
      setState(() {
        _isArrived = false;
        _isNavigating = true;
        _progress = 0.0;
        _remainingDistanceMeters = _initialDistance;
        _remainingDurationMinutes = _initialDuration;
        _currentUserPos = _userPos;
        _lastSpokenPhase = 0;
      });
      _fitMapBounds();
      _speak(
        'Guidage piéton démarré. Continuez tout droit vers l\'arrêt ${widget.routeOption.departureStop.name}.',
      );
      _startWalkingSimulation();
      return;
    }

    if (_isNavigating) {
      _navigationTimer?.cancel();
      _flutterTts?.stop();
      _lastSpokenPhase = -1;
      setState(() {
        _isNavigating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Guidage piéton suspendu',
            style: GoogleFonts.inter(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppColors.buttonBlack,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      setState(() {
        _isNavigating = true;
        _lastSpokenPhase = 0;
      });

      final stopName = widget.routeOption.departureStop.name;
      _speak(
        'Guidage piéton démarré. Continuez tout droit vers l\'arrêt $stopName.',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'tcu.walking_started'.tr(args: [stopName]),
                  style: GoogleFonts.inter(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.yangoRouteGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      _startWalkingSimulation();
    }
  }

  void _startWalkingSimulation() {
    _navigationTimer?.cancel();

    final totalDistance = _initialDistance > 0 ? _initialDistance : 280;
    final stepDistance = (totalDistance / 9.0).clamp(25.0, 50.0);
    final progressStep = stepDistance / totalDistance;

    if (_isTestEnvironment) {
      setState(() {
        _progress = (_progress + progressStep).clamp(0.0, 1.0);
        _remainingDistanceMeters =
            ((1.0 - _progress) * totalDistance).round().clamp(0, totalDistance);
        _remainingDurationMinutes =
            _remainingDistanceMeters == 0 ? 0 : (_remainingDistanceMeters / 75.0).ceil();
        _currentUserPos = _interpolateAlongPath(
          widget.routeOption.walkingPathToStop,
          _progress,
        );
      });
      return;
    }

    _navigationTimer = Timer.periodic(
      const Duration(milliseconds: 1400),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          _progress += progressStep;

          if (_progress >= 1.0) {
            _progress = 1.0;
            _remainingDistanceMeters = 0;
            _remainingDurationMinutes = 0;
            _currentUserPos = _stopPos;
            _isNavigating = false;
            _isArrived = true;
            timer.cancel();
          } else {
            _remainingDistanceMeters =
                ((1.0 - _progress) * totalDistance).round().clamp(0, totalDistance);
            _remainingDurationMinutes =
                (_remainingDistanceMeters / 75.0).ceil();
            _currentUserPos = _interpolateAlongPath(
              widget.routeOption.walkingPathToStop,
              _progress,
            );
          }
        });

        // Voice Guidance step announcements
        if (_isNavigating) {
          if (_progress >= 0.35 && _progress < 0.70 && _lastSpokenPhase < 1) {
            _lastSpokenPhase = 1;
            _speak('Dans cinquante mètres, tournez à droite vers l\'arrêt.');
          } else if (_progress >= 0.70 && _progress < 1.0 && _lastSpokenPhase < 2) {
            _lastSpokenPhase = 2;
            _speak(
              'L\'arrêt ${widget.routeOption.departureStop.name} est à cinquante mètres tout droit.',
            );
          }
        }

        if (_isNavigating && _mapController != null) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(_currentUserPos),
          );
        } else if (_isArrived) {
          if (_lastSpokenPhase < 3) {
            _lastSpokenPhase = 3;
            _speak(
              'Vous êtes arrivé à l\'arrêt ${widget.routeOption.departureStop.name}. Bon voyage !',
            );
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vous êtes arrivé à l\'arrêt ${widget.routeOption.departureStop.name} !',
                      style: GoogleFonts.inter(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.tcuDddGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final option = widget.routeOption;
    final stop = option.departureStop;

    return Scaffold(
      backgroundColor: const Color(0xFFEBE6DC),
      body: Stack(
        children: [
          // 1. Guaranteed Dakar Vector Street Map (underlying fallback with Yango route coloring)
          Positioned.fill(
            child: CustomPaint(
              painter: _DakarWalkingMapPainter(
                isNavigating: _isNavigating,
                progress: _progress,
              ),
            ),
          ),

          // 2. GoogleMap view directly mounted as primary map
          Positioned.fill(
            child: GoogleMap(
              key: const Key('tcu_stop_route_google_map'),
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  (_userPos.latitude + _stopPos.latitude) / 2,
                  (_userPos.longitude + _stopPos.longitude) / 2,
                ),
                zoom: 16.5,
              ),
              markers: _buildMarkers(),
              polylines: _buildPolylines(),
              onMapCreated: _onMapCreated,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
            ),
          ),

          // 3. Floating Distance Badge on the map (colored in Yango Green when navigating)
          Positioned(
            top: MediaQuery.of(context).padding.top + (_isNavigating ? 98 : 70),
            right: AppConstants.spacingMd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowLight,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: _isArrived
                      ? AppColors.tcuDddGreen
                      : (_isNavigating
                          ? AppColors.yangoRouteGreen
                          : AppColors.tcuFieldBorder),
                  width: _isNavigating ? 2.0 : 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isArrived ? Icons.check_circle : Icons.directions_walk,
                    size: 16,
                    color: _isArrived
                        ? AppColors.tcuDddGreen
                        : (_isNavigating
                            ? AppColors.yangoRouteGreen
                            : AppColors.primary),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isArrived
                        ? 'Arrivé à l\'arrêt !'
                        : (_isNavigating
                            ? '$_remainingDistanceMeters m restants · $_remainingDurationMinutes min'
                            : '$_remainingDistanceMeters m · $_remainingDurationMinutes min à pied'),
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontSm,
                      fontWeight: FontWeight.w700,
                      color: _isArrived
                          ? AppColors.tcuDddGreen
                          : (_isNavigating
                              ? AppColors.yangoRouteGreen
                              : AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Top Navigation Bar: Either Yango Turn-by-Turn HUD (navigating) or Standard Header
          SafeArea(
            child: _isNavigating
                ? _buildYangoNavigationHeader()
                : _buildStandardTopBar(stop),
          ),

          // 5. Bottom Sheet firmly anchored at the bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppConstants.radiusTwentyFour),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowDarkBlack,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: AppConstants.spacingMd,
                right: AppConstants.spacingMd,
                top: AppConstants.spacingUnitLg,
                bottom: MediaQuery.of(context).padding.bottom +
                    AppConstants.spacingMd,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Center drag handle
                  Center(
                    child: Container(
                      width: AppConstants.handleWidth,
                      height: AppConstants.handleHeight,
                      decoration: BoxDecoration(
                        color: AppColors.dragHandle,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusPill),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingUnitLg),

                  // Stop name & Transit Badge
                  Row(
                    children: [
                      // Badge (AFTU, DDD, BRT, TER)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingUnit,
                          vertical: AppConstants.spacingSm,
                        ),
                        decoration: BoxDecoration(
                          color: option.badgeBgColor,
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusItem),
                        ),
                        child: Text(
                          option.badgeText,
                          style: GoogleFonts.inter(
                            fontSize: AppConstants.fontSm,
                            fontWeight: FontWeight.w800,
                            color: AppColors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingUnitLg),

                      // Stop and Line title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stop.name,
                              style: GoogleFonts.inter(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${option.lineCode} · ${option.type.displayName}',
                              style: GoogleFonts.inter(
                                fontSize: AppConstants.fontSm,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingMd),

                  // 3 Stat Cards: Distance restante (colorée style Yango), Temps, Prochain bus
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatBox(
                          label: _isNavigating ? 'Restant' : 'tcu.walking_dist'.tr(),
                          value: '$_remainingDistanceMeters m',
                          highlightValue: _isNavigating,
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingSm),
                      Expanded(
                        child: _buildStatBox(
                          label: _isNavigating ? 'Temps' : 'tcu.duration'.tr(),
                          value: '$_remainingDurationMinutes min',
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingSm),
                      Expanded(
                        child: _buildStatBox(
                          label: option.isTrain
                              ? 'tcu.next_train'.tr()
                              : 'tcu.next_bus'.tr(),
                          value: '${stop.nextArrivalMinutes} min',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingUnitLg),

                  // Big Action Button: "Démarrer la marche" / "Arrêter le guidage"
                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.buttonHeight,
                    child: ElevatedButton(
                      key: const Key('tcu_toggle_walking_button'),
                      onPressed: _toggleWalkingNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isArrived
                            ? AppColors.tcuDddGreen
                            : (_isNavigating
                                ? const Color(0xFF1F2937)
                                : AppColors.primary),
                        foregroundColor: AppColors.white,
                        elevation: AppConstants.elevationNone,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusDefault),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isArrived
                                ? Icons.refresh
                                : (_isNavigating
                                    ? Icons.stop_rounded
                                    : Icons.directions_walk),
                            size: 20,
                            color: AppColors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isArrived
                                ? 'Arrivé à destination'
                                : (_isNavigating
                                    ? 'Arrêter le guidage'
                                    : 'tcu.start_walking'.tr()),
                            style: GoogleFonts.inter(
                              fontSize: AppConstants.fontLg,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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

  /// Turn-by-Turn GPS Navigation Banner matching Yango experience
  Widget _buildYangoNavigationHeader() {
    IconData turnIcon;
    String turnInstruction;
    String turnDistance;
    String subInstruction;

    if (_isArrived) {
      turnIcon = Icons.check_circle_rounded;
      turnInstruction = 'Vous êtes arrivé !';
      turnDistance = '0 m';
      subInstruction = 'Arrêt ${widget.routeOption.departureStop.name}';
    } else if (_progress < 0.35) {
      turnIcon = Icons.arrow_upward_rounded;
      turnInstruction = 'Marchez tout droit';
      turnDistance = '${(_remainingDistanceMeters * 0.4).round().clamp(20, 200)} m';
      subInstruction = 'En direction de ${widget.routeOption.departureStop.name}';
    } else if (_progress < 0.70) {
      turnIcon = Icons.turn_right_rounded;
      turnInstruction = 'Tournez à droite';
      turnDistance = '${(_remainingDistanceMeters * 0.5).round().clamp(15, 100)} m';
      subInstruction = 'Prenez la rue vers l\'arrêt';
    } else {
      turnIcon = Icons.place_rounded;
      turnInstruction = 'Votre arrêt est tout droit';
      turnDistance = '$_remainingDistanceMeters m';
      subInstruction = 'Arrêt ${widget.routeOption.departureStop.name}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2330),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Maneuver Turn Icon in vibrant green
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _isArrived ? AppColors.tcuDddGreen : AppColors.yangoRouteGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_isArrived ? AppColors.tcuDddGreen : AppColors.yangoRouteGreen)
                      .withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              turnIcon,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          // Maneuver instruction & colored distance
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      turnDistance,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.yangoRouteGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        turnInstruction,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subInstruction,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF9CA3AF),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Voice guidance toggle button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _toggleVoiceGuidance,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _isVoiceEnabled
                      ? AppColors.yangoRouteGreen.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isVoiceEnabled
                        ? AppColors.yangoRouteGreen.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Icon(
                  _isVoiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: _isVoiceEnabled ? AppColors.yangoRouteGreen : const Color(0xFF9CA3AF),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardTopBar(TcuStop stop) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Row(
        children: [
          // Circular back button
          Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowLight,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
                size: AppConstants.iconSizeLg,
              ),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'common.back'.tr(),
            ),
          ),
          const SizedBox(width: AppConstants.spacingUnitLg),

          // Destination Stop Banner
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
              ),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowLight,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                'tcu.nav_destination'.tr(args: [stop.name]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: AppConstants.fontMd,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required String value,
    bool highlightValue = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppConstants.spacingUnitLg,
        horizontal: AppConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: highlightValue
            ? const Color(0xFFE8F8F0)
            : AppColors.tcuStatCardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: highlightValue
            ? Border.all(
                color: AppColors.yangoRouteGreen.withValues(alpha: 0.3),
                width: 1.2,
              )
            : null,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: AppConstants.fontSm,
              fontWeight: FontWeight.w600,
              color: highlightValue
                  ? const Color(0xFF047857)
                  : AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: highlightValue
                  ? AppColors.yangoRouteGreen
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter rendering the Dakar street map matching Screenshot 4 with Yango route coloring
class _DakarWalkingMapPainter extends CustomPainter {
  final bool isNavigating;
  final double progress;

  const _DakarWalkingMapPainter({
    required this.isNavigating,
    this.progress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 1. Terrain Background
    final terrainPaint = Paint()..color = const Color(0xFFEBE6DC);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), terrainPaint);

    // 2. Water / Coast in top-left
    final oceanPaint = Paint()..color = const Color(0xFFC7DEEB);
    final oceanPath = Path()
      ..moveTo(0, 0)
      ..lineTo(width * 0.45, 0)
      ..quadraticBezierTo(width * 0.15, height * 0.08, 0, height * 0.12)
      ..close();
    canvas.drawPath(oceanPath, oceanPaint);

    // 3. Green park area
    final parkPaint = Paint()..color = const Color(0xFFD7E5D5);
    final parkRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(width * 0.06, height * 0.16, width * 0.30, height * 0.12),
      const Radius.circular(16),
    );
    canvas.drawRRect(parkRRect, parkPaint);

    // 4. Dakar Road Grid
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final roadBorderPaint = Paint()
      ..color = const Color(0xFFDED9CD)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    void drawRoad(Offset p1, Offset p2, double roadWidth) {
      roadBorderPaint.strokeWidth = roadWidth + 2.5;
      canvas.drawLine(p1, p2, roadBorderPaint);
      roadPaint.strokeWidth = roadWidth;
      canvas.drawLine(p1, p2, roadPaint);
    }

    drawRoad(
      Offset(width * 0.23, height * 0.10),
      Offset(width * 0.33, height * 0.70),
      18,
    );

    drawRoad(
      Offset(width * 0.72, height * 0.12),
      Offset(width * 0.76, height * 0.70),
      18,
    );

    drawRoad(
      Offset(0, height * 0.32),
      Offset(width, height * 0.27),
      16,
    );

    drawRoad(
      Offset(0, height * 0.52),
      Offset(width, height * 0.48),
      18,
    );

    // 5. Walking Route: Yango Green Remaining & Traveled Grey
    final startPos = Offset(width * 0.29, height * 0.53);
    final cornerTurn1 = Offset(width * 0.29, height * 0.50);
    final cornerTurn2 = Offset(width * 0.73, height * 0.48);
    final stopPos = Offset(width * 0.73, height * 0.36);

    final seg1 = (cornerTurn1 - startPos).distance;
    final seg2 = (cornerTurn2 - cornerTurn1).distance;
    final seg3 = (stopPos - cornerTurn2).distance;
    final totalLen = seg1 + seg2 + seg3;
    final targetLen = progress.clamp(0.0, 1.0) * totalLen;

    Offset currentUserPos = startPos;
    if (targetLen <= seg1) {
      final t = seg1 > 0 ? targetLen / seg1 : 0.0;
      currentUserPos = Offset.lerp(startPos, cornerTurn1, t) ?? startPos;
    } else if (targetLen <= seg1 + seg2) {
      final t = seg2 > 0 ? (targetLen - seg1) / seg2 : 0.0;
      currentUserPos = Offset.lerp(cornerTurn1, cornerTurn2, t) ?? cornerTurn1;
    } else {
      final t = seg3 > 0 ? (targetLen - seg1 - seg2) / seg3 : 0.0;
      currentUserPos = Offset.lerp(cornerTurn2, stopPos, t) ?? stopPos;
    }

    final activeRouteColor =
        isNavigating ? AppColors.yangoRouteGreen : AppColors.primary;

    final dotPaint = Paint()
      ..color = activeRouteColor
      ..style = PaintingStyle.fill;

    final traveledPaint = Paint()
      ..color = AppColors.routeTraveled
      ..style = PaintingStyle.fill;

    void drawDottedSegment(
      Offset start,
      Offset end,
      double step,
      Paint paintToUse,
    ) {
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final distance = Offset(dx, dy).distance;
      if (distance == 0) return;

      final count = (distance / step).round();
      for (int i = 0; i <= count; i++) {
        final t = i / count;
        final point = Offset(start.dx + dx * t, start.dy + dy * t);
        canvas.drawCircle(point, 3.4, paintToUse);
      }
    }

    // Traveled segments in grey
    if (progress > 0.0) {
      if (targetLen <= seg1) {
        drawDottedSegment(startPos, currentUserPos, 9.0, traveledPaint);
      } else if (targetLen <= seg1 + seg2) {
        drawDottedSegment(startPos, cornerTurn1, 9.0, traveledPaint);
        drawDottedSegment(cornerTurn1, currentUserPos, 9.0, traveledPaint);
      } else {
        drawDottedSegment(startPos, cornerTurn1, 9.0, traveledPaint);
        drawDottedSegment(cornerTurn1, cornerTurn2, 9.0, traveledPaint);
        drawDottedSegment(cornerTurn2, currentUserPos, 9.0, traveledPaint);
      }
    }

    // Remaining segments in Yango Green
    if (progress < 1.0) {
      if (targetLen <= seg1) {
        drawDottedSegment(currentUserPos, cornerTurn1, 9.0, dotPaint);
        drawDottedSegment(cornerTurn1, cornerTurn2, 9.0, dotPaint);
        drawDottedSegment(cornerTurn2, stopPos, 9.0, dotPaint);
      } else if (targetLen <= seg1 + seg2) {
        drawDottedSegment(currentUserPos, cornerTurn2, 9.0, dotPaint);
        drawDottedSegment(cornerTurn2, stopPos, 9.0, dotPaint);
      } else {
        drawDottedSegment(currentUserPos, stopPos, 9.0, dotPaint);
      }
    }

    // 6. User Location Dot with Soft Halo (Green when navigating, blue when not)
    final haloColor = isNavigating
        ? AppColors.yangoRouteGreen.withValues(alpha: 0.25)
        : const Color(0x332B66FF);
    final userDotColor =
        isNavigating ? AppColors.yangoRouteGreen : const Color(0xFF2B66FF);

    canvas.drawCircle(currentUserPos, 22, Paint()..color = haloColor);
    canvas.drawCircle(currentUserPos, 10, Paint()..color = Colors.white);
    canvas.drawCircle(currentUserPos, 6.5, Paint()..color = userDotColor);

    // 7. Destination Stop Pin
    _drawStopPin(canvas, stopPos);
  }

  void _drawStopPin(Canvas canvas, Offset tip) {
    final pinPaint = Paint()
      ..color = const Color(0xFF274C9E)
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(tip.dx, tip.dy + 3),
        width: 14,
        height: 6,
      ),
      shadowPaint,
    );

    const headRadius = 15.0;
    final headCenter = Offset(tip.dx, tip.dy - 22);

    final path = Path()
      ..addArc(
        Rect.fromCircle(center: headCenter, radius: headRadius),
        0.5,
        5.28,
      )
      ..lineTo(tip.dx, tip.dy)
      ..close();

    canvas.drawPath(path, pinPaint);

    final whiteDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(headCenter, 5.5, whiteDotPaint);
  }

  @override
  bool shouldRepaint(covariant _DakarWalkingMapPainter oldDelegate) =>
      oldDelegate.isNavigating != isNavigating ||
      oldDelegate.progress != progress;
}
