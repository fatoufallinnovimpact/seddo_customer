import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

import '../../data/models/tcu_route_model.dart';
import '../../data/models/transit/ItineraireLegModel.dart';
import '../../data/models/transit/PlaceModel.dart';
import '../../data/models/transit/StopTimeResponse.dart';
import '../../data/models/transit/TransitResponseModel.dart';
import '../../domain/bloc/route_timeline/route_timeline_bloc.dart';
import 'public_transport_stop_route_page.dart';

const Color transitSecondaryColor = Color(0xFF0D47A1);
const Color transitPrimaryColor = Color(0xFFD95C18);

class RouteTimelinePage extends StatelessWidget {
  final PlaceModel? toPlaceDetails;
  final PlaceModel? fromPlaceDetails;
  final StopTimeResponseModel? stopTimeResponse;
  final String date;
  final String time;
  final ScrollPhysics? physics;
  final void Function(List<TransitFullResponseModel>, Position?)?
      onDepartureTransitUpdated;

  const RouteTimelinePage({
    super.key,
    this.toPlaceDetails,
    this.fromPlaceDetails,
    this.stopTimeResponse,
    required this.date,
    required this.time,
    this.physics,
    this.onDepartureTransitUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RouteTimelineBloc()
        ..add(
          RouteTimelineInitialized(
            fromPlaceDetails: fromPlaceDetails,
            toPlaceDetails: toPlaceDetails,
            stopTimeResponse: stopTimeResponse,
            index: 0,
            date: date,
            time: time,
          ),
        ),
      child: _RouteTimelineContent(
        onDepartureTransitUpdated: onDepartureTransitUpdated,
        fromPlaceDetails: fromPlaceDetails,
        toPlaceDetails: toPlaceDetails,
        physics: physics,
      ),
    );
  }
}

class _RouteTimelineContent extends StatelessWidget {
  final Function(List<TransitFullResponseModel>, Position?)?
      onDepartureTransitUpdated;
  final PlaceModel? toPlaceDetails;
  final PlaceModel? fromPlaceDetails;
  final ScrollPhysics? physics;

  const _RouteTimelineContent({
    this.onDepartureTransitUpdated,
    this.toPlaceDetails,
    this.fromPlaceDetails,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RouteTimelineBloc, RouteTimelineState>(
      builder: (context, state) {
        // Loading
        if (state.status == RouteTimelineStatus.loading ||
            state.departureLoader) {
          return const _TransitLoader();
        }

        // Pas de résultats
        if (state.itineraires.isEmpty &&
            state.status == RouteTimelineStatus.success) {
          return _NoTransitFound(message: state.errorMessage);
        }

        return SingleChildScrollView(
          physics: physics,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Onglets itinéraires (si plus d'un)
              if (state.itineraires.length > 1) ...[
                const SizedBox(height: 8),
                _ItineraireTabBar(
                  itineraires: state.itineraires,
                  selectedIndex: state.itineraireIndex,
                  onTap: (i) => context.read<RouteTimelineBloc>().add(
                        RouteTimelineTabChanged(i),
                      ),
                ),
                const SizedBox(height: 12),
              ],

              // Badge direct/correspondance
              if (state.selectedItineraire != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ItineraireBadge(
                    itineraire: state.selectedItineraire!,
                  ),
                ),

              const SizedBox(height: 8),

              // Timeline
              if (state.selectedItineraire != null)
                _ItineraireTimeline(
                  itineraire: state.selectedItineraire!,
                  fromLabel: fromPlaceDetails?.name ?? 'Départ',
                  toLabel: toPlaceDetails?.name ?? 'Arrivée',
                  fromLat: state.startLat,
                  fromLon: state.startLon,
                  toLat: state.endLat,
                  toLon: state.endLon,
                  currentPosition: state.currentPosition,
                ),

              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADER ANIMÉ
// ─────────────────────────────────────────────────────────────────────────────

class _TransitLoader extends StatefulWidget {
  const _TransitLoader();

  @override
  State<_TransitLoader> createState() => _TransitLoaderState();
}

class _TransitLoaderState extends State<_TransitLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _messageIndex = 0;
  final List<String> _messages = [
    '🔍 Recherche des lignes...',
    '🚌 Analyse du trafic...',
    '📍 Calcul des arrêts...',
    '⚡ Optimisation des itinéraires...',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Changer le message toutes les 1.8s
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return false;
      setState(() {
        _messageIndex = (_messageIndex + 1) % _messages.length;
      });
      return true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Bus animé
            AnimatedBuilder(
              animation: _controller,
              builder: (_, child) {
                final offset = sin(_controller.value * 2 * pi) * 8;
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: Image.asset('assets/transit/dddk.png', width: 80),
                );
              },
            ),
            const SizedBox(height: 24),
            // Barre de progression
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, child) => LinearProgressIndicator(
                  value: null,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    transitSecondaryColor,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _messages[_messageIndex],
                key: ValueKey(_messageIndex),
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUCUN RÉSULTAT
// ─────────────────────────────────────────────────────────────────────────────

class _NoTransitFound extends StatelessWidget {
  final String? message;
  const _NoTransitFound({this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bus_alert_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun trajet disponible',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Essayez une autre heure ou un autre itinéraire.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: transitSecondaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                '🕐 Vérifiez l\'heure de départ',
                style: TextStyle(
                  color: transitSecondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONGLETS ITINÉRAIRES
// ─────────────────────────────────────────────────────────────────────────────

class _ItineraireTabBar extends StatelessWidget {
  final List<ItineraireModel> itineraires;
  final int selectedIndex;
  final void Function(int) onTap;

  const _ItineraireTabBar({
    required this.itineraires,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(itineraires.length, (i) {
            final itineraire = itineraires[i];
            final isSelected = i == selectedIndex;
            final name = ItineraireModel.nameForIndex(i, itineraire.isDirect);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: isSelected
                        ? transitSecondaryColor
                        : Colors.grey.shade100,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: transitSecondaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                            : [],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      if (itineraire.totalTrafficDurationSeconds > 0)
                        Text(
                          itineraire.totalDurationFormatted,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white70
                                : Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BADGE DIRECT / CORRESPONDANCE
// ─────────────────────────────────────────────────────────────────────────────

class _ItineraireBadge extends StatelessWidget {
  final ItineraireModel itineraire;
  const _ItineraireBadge({required this.itineraire});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: itineraire.isDirect
                ? Colors.green.shade50
                : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: itineraire.isDirect
                  ? Colors.green.shade300
                  : Colors.orange.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                itineraire.isDirect ? Icons.check_circle : Icons.swap_horiz,
                size: 14,
                color: itineraire.isDirect
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                itineraire.isDirect
                    ? 'Direct'
                    : '${itineraire.totalLegs} bus · Correspondance',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: itineraire.isDirect
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
        if (itineraire.totalTrafficDurationSeconds > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.blue.shade700),
                const SizedBox(width: 4),
                Text(
                  itineraire.totalDurationFormatted,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIMELINE PRINCIPALE
// ─────────────────────────────────────────────────────────────────────────────

class _ItineraireTimeline extends StatelessWidget {
  final ItineraireModel itineraire;
  final String fromLabel;
  final String toLabel;
  final double fromLat;
  final double fromLon;
  final double toLat;
  final double toLon;
  final Position? currentPosition;

  const _ItineraireTimeline({
    required this.itineraire,
    required this.fromLabel,
    required this.toLabel,
    required this.fromLat,
    required this.fromLon,
    required this.toLat,
    required this.toLon,
    this.currentPosition,
  });

  @override
  Widget build(BuildContext context) {
    final legs = itineraire.legs;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Point départ
          _TimelineStartPoint(label: fromLabel),

          // Pour chaque leg
          for (int i = 0; i < legs.length; i++) ...[
            // Marche vers l'arrêt
            _WalkingSegment(
              distanceMeters: legs[i].walkingDistanceToBoardingStop,
              stopName: legs[i].stopStart?.stopName ?? '',
              stopLat: legs[i].stopStart?.stopLat ?? 0,
              stopLon: legs[i].stopStart?.stopLon ?? 0,
              isNearestStop: currentPosition != null
                  ? _isNearestStop(legs[i], currentPosition!)
                  : true,
              onNavigateToStop: () => _navigateToStop(context, legs[i]),
            ),

            // Arrêt de départ + carte bus
            _BusStopPoint(
              stopName: legs[i].stopStart?.stopName ?? '',
              isBoarding: true,
            ),

            // Carte bus
            _BusCard(
              leg: legs[i],
              onNavigateToStop: () => _navigateToStop(context, legs[i]),
            ),

            // Arrêt d'arrivée
            _BusStopPoint(
              stopName: legs[i].stopEnd?.stopName ?? '',
              isBoarding: false,
            ),

            // Marche vers prochaine correspondance ou destination
            if (i < legs.length - 1)
              _TransferSegment(fromLeg: legs[i], toLeg: legs[i + 1])
            else
              _WalkingSegment(
                distanceMeters: legs[i].walkingDistanceFromAlightingStop,
                stopName: toLabel,
                stopLat: toLat,
                stopLon: toLon,
                isNearestStop: false,
              ),
          ],

          // Point destination
          _TimelineEndPoint(label: toLabel),
        ],
      ),
    );
  }

  bool _isNearestStop(ItineraireLegModel leg, Position position) {
    if (leg.stopStart == null) return false;
    final dist = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      leg.stopStart!.stopLat,
      leg.stopStart!.stopLon,
    );
    return dist < 300;
  }

  void _navigateToStop(BuildContext context, ItineraireLegModel leg) {
    if (leg.stopStart == null) return;

    final transitType = leg.transitType;
    final type = transitType.toUpperCase() == 'BRT'
        ? TcuTransportType.brt
        : transitType.toUpperCase() == 'DDD'
            ? TcuTransportType.ddd
            : TcuTransportType.aftu;

    final imagePath = transitType.toUpperCase() == 'BRT'
        ? 'assets/transit/brt.png'
        : transitType.toUpperCase() == 'DDD'
            ? 'assets/transit/dddk.png'
            : 'assets/transit/aftu.png';

    final stopLat = leg.stopStart!.stopLat;
    final stopLon = leg.stopStart!.stopLon;
    final stopName = leg.stopStart!.stopName.isNotEmpty
        ? leg.stopStart!.stopName
        : 'Arrêt de départ';

    final depStop = TcuStop(
      id: 'stop_${stopLat}_$stopLon',
      name: stopName,
      walkingDistanceMeters: leg.walkingDistanceToBoardingStop.round(),
      walkingDurationMinutes:
          max(1, (leg.walkingDistanceToBoardingStop / 80).round()),
      nextArrivalMinutes: 5,
      latitude: stopLat,
      longitude: stopLon,
    );

    final arrStop = TcuStop(
      id: 'dest_stop',
      name: toLabel.isNotEmpty ? toLabel : 'Destination',
      walkingDistanceMeters: leg.walkingDistanceFromAlightingStop.round(),
      walkingDurationMinutes:
          max(1, (leg.walkingDistanceFromAlightingStop / 80).round()),
      nextArrivalMinutes: 0,
      latitude:
          toLat != 0 ? toLat : leg.stopEnd?.stopLat ?? leg.stopStart!.stopLat,
      longitude:
          toLon != 0 ? toLon : leg.stopEnd?.stopLon ?? leg.stopStart!.stopLon,
    );

    final lineCode = leg.trip?.routeId.replaceAll('_', ' ') ??
        leg.route?.routeShortName ??
        'Bus';

    final userLat =
        fromLat != 0 ? fromLat : (currentPosition?.latitude ?? 14.6937);
    final userLon =
        fromLon != 0 ? fromLon : (currentPosition?.longitude ?? -17.4914);

    final routeOption = TcuRouteOption(
      id: 'route_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      lineCode: lineCode.isNotEmpty ? lineCode : 'Bus',
      linePrefix: 'Ligne de bus :',
      estimatedDurationMinutes:
          max(1, (leg.walkingDistanceToBoardingStop / 80).round()),
      estimatedDurationText:
          '${max(1, (leg.walkingDistanceToBoardingStop / 80).round())} min',
      departureStop: depStop,
      arrivalStop: arrStop,
      stopsCount: leg.intermediateStops.length,
      stopsList: leg.intermediateStops
          .map((s) => s.stop?.stopName ?? '')
          .where((n) => n.isNotEmpty)
          .toList(),
      imagePath: imagePath,
      userOriginCoordinates: LatLng(userLat, userLon),
      walkingPathToStop: [
        LatLng(userLat, userLon),
        LatLng(stopLat, stopLon),
      ],
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PublicTransportStopRoutePage(
          routeOption: routeOption,
        ),
      ),
    );
  }
}

class _TimelineStartPoint extends StatelessWidget {
  final String label;
  const _TimelineStartPoint({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.trip_origin_sharp, color: Color(0xFFE65100), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TimelineEndPoint extends StatelessWidget {
  final String label;
  const _TimelineEndPoint({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.location_on, color: Colors.red, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _WalkingSegment extends StatelessWidget {
  final double distanceMeters;
  final String stopName;
  final double stopLat;
  final double stopLon;
  final bool isNearestStop;
  final VoidCallback? onNavigateToStop;

  const _WalkingSegment({
    required this.distanceMeters,
    required this.stopName,
    required this.stopLat,
    required this.stopLon,
    required this.isNearestStop,
    this.onNavigateToStop,
  });

  String _formatDistance() {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  int _estimateMinutes() => max(1, (distanceMeters / 80).round());

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 9),
      child: Row(
        children: [
          SizedBox(
            width: 2,
            height: 50,
            child: CustomPaint(painter: _DashLinePainter()),
          ),
          const SizedBox(width: 16),
          Icon(Icons.directions_walk, color: Colors.grey.shade500, size: 18),
          const SizedBox(width: 4),
          Text(
            '${_formatDistance()}  |  ${_estimateMinutes()} min',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          if (onNavigateToStop != null || isNearestStop) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onNavigateToStop ??
                  () => _UrlLauncher().openARNavigation(stopLat, stopLon),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE65100),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.navigation, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Y aller',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TransferSegment extends StatelessWidget {
  final ItineraireLegModel fromLeg;
  final ItineraireLegModel toLeg;

  const _TransferSegment({required this.fromLeg, required this.toLeg});

  @override
  Widget build(BuildContext context) {
    final walkDist = fromLeg.walkingDistanceFromAlightingStop;
    final distText = walkDist < 1000
        ? '${walkDist.round()} m'
        : '${(walkDist / 1000).toStringAsFixed(1)} km';
    final minutes = max(1, (walkDist / 80).round());

    return Padding(
      padding: const EdgeInsets.only(left: 9),
      child: Row(
        children: [
          SizedBox(
            width: 2,
            height: 55,
            child: CustomPaint(painter: _DashLinePainter()),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.transfer_within_a_station,
                  color: Colors.orange.shade700,
                  size: 15,
                ),
                const SizedBox(width: 4),
                Text(
                  'Correspondance · $distText · $minutes min à pied',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BusStopPoint extends StatelessWidget {
  final String stopName;
  final bool isBoarding;

  const _BusStopPoint({required this.stopName, required this.isBoarding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.only(left: 2),
            child: Image.asset(
              'assets/transit/arretbus.png',
              width: 18,
              height: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              stopName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARTE BUS
// ─────────────────────────────────────────────────────────────────────────────

class _BusCard extends StatefulWidget {
  final ItineraireLegModel leg;
  final VoidCallback onNavigateToStop;

  const _BusCard({
    required this.leg,
    required this.onNavigateToStop,
  });

  @override
  State<_BusCard> createState() => _BusCardState();
}

class _BusCardState extends State<_BusCard> {
  bool _showStops = false;

  String _getBusImage() {
    final type = widget.leg.transitType.toUpperCase();
    if (type == 'BRT') return 'assets/transit/brt.png';
    if (type == 'DDD') return 'assets/transit/dddk.png';
    return 'assets/transit/aftu.png';
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '--:--';
    final parts = time.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return time;
  }

  @override
  Widget build(BuildContext context) {
    final leg = widget.leg;
    final intermediateCount =
        leg.intermediateStops.length > 2 ? leg.intermediateStops.length - 2 : 0;

    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ligne verticale bleue continue jusqu'en bas (au prochain arrêt)
            Container(
              width: 2,
              color: transitSecondaryColor,
            ),
            const SizedBox(width: 12),

            // Carte
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header : image + infos
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(_getBusImage(), width: 65),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InfoRow(
                              label: 'Ligne de bus :',
                              value:
                                  leg.trip?.routeId.replaceAll('_', ' ') ??
                                  '--',
                              bold: true,
                            ),
                            const SizedBox(height: 6),
                            _InfoRow(
                              label: 'Heure de départ:',
                              value: _formatTime(
                                leg.departureStopTime?.departureTime,
                              ),
                              bold: true,
                            ),
                            if (leg.trafficDurationSeconds != null) ...[
                              const SizedBox(height: 6),
                              _InfoRow(
                                label: 'Durée trajet:',
                                value: leg.trafficDurationFormatted,
                                bold: false,
                                color: Colors.blue.shade700,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Bouton naviguer vers l'arrêt
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: widget.onNavigateToStop,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.navigation,
                            color: Color(0xFFE65100),
                            size: 14,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Naviguer vers cet arrêt',
                            style: TextStyle(
                              color: Color(0xFFE65100),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Arrêts intermédiaires
                  if (intermediateCount > 0) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => setState(() => _showStops = !_showStops),
                      child: Container(
                        height: 35,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '($intermediateCount) Arrêts intermédiaires',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Icon(
                              _showStops
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showStops)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          children: leg.intermediateStops
                              .skip(1)
                              .take(leg.intermediateStops.length - 2)
                              .map(
                                (s) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.circle,
                                        size: 8,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          s.stop?.stopName ?? '',
                                          style: const TextStyle(
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.bold,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
            fontSize: 13,
            color: color ?? Colors.black,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DASH LINE PAINTER
// ─────────────────────────────────────────────────────────────────────────────

class _DashLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double startY = 0;
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 2;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + 5), paint);
      startY += 8;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UrlLauncher {
  Future<void> openARNavigation(double toLat, double toLon) async {
    final uri = Platform.isIOS
        ? Uri.parse('maps://?daddr=$toLat,$toLon&dirflg=w')
        : Uri.parse('google.navigation:q=$toLat,$toLon&mode=w');
    try {
      if (await ul.canLaunchUrl(uri)) {
        await ul.launchUrl(uri, mode: ul.LaunchMode.externalApplication);
      } else {
        await ul.launchUrl(
          Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$toLat,$toLon&travelmode=walking'),
          mode: ul.LaunchMode.externalApplication,
        );
      }
    } catch (_) {}
  }
}
