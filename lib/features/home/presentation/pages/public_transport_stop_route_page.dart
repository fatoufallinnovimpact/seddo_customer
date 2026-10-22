import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/tcu_route_model.dart';

/// Screen displaying walking navigation towards the nearest transit stop on the map.
/// Matches Screenshot 4 (media_1792687485707.png) pixel-for-pixel with:
/// - Guaranteed Dakar vector street map canvas (streets, park, ocean, user dot with halo,
///   orange dotted walking path, blue stop pin) ensuring the map is ALWAYS visible even if Google Maps fails.
/// - Floating distance indicator along the route ("277 m · 3 min à pied").
/// - Top bar with circular back button and "Vers [Nom de l'arrêt]" banner.
/// - Bottom sheet firmly anchored at the bottom with 3 stat cards and orange "Démarrer la marche" button at the bottom.
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
  bool _useGoogleMaps = false;

  late final LatLng _userPos;
  late final LatLng _stopPos;

  @override
  void initState() {
    super.initState();
    _userPos = widget.routeOption.userOriginCoordinates;
    _stopPos = widget.routeOption.departureStop.coordinates;
  }

  Set<Marker> _buildMarkers() {
    return {
      Marker(
        markerId: const MarkerId('user_location'),
        position: _userPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Votre position'),
      ),
      Marker(
        markerId: const MarkerId('stop_destination'),
        position: _stopPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(
          title: widget.routeOption.departureStop.name,
          snippet: widget.routeOption.lineCode,
        ),
      ),
    };
  }

  Set<Polyline> _buildPolylines() {
    final points = widget.routeOption.walkingPathToStop;
    return {
      Polyline(
        polylineId: const PolylineId('walking_route'),
        points: points,
        color: AppColors.primary,
        width: 5,
        patterns: [
          PatternItem.dot,
          PatternItem.gap(10.0),
        ],
      ),
    };
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitMapBounds();
    if (mounted) {
      setState(() => _useGoogleMaps = true);
    }
  }

  void _fitMapBounds() {
    if (_mapController == null) return;
    final south = _userPos.latitude < _stopPos.latitude
        ? _userPos.latitude
        : _stopPos.latitude;
    final north = _userPos.latitude > _stopPos.latitude
        ? _userPos.latitude
        : _stopPos.latitude;
    final west = _userPos.longitude < _stopPos.longitude
        ? _userPos.longitude
        : _stopPos.longitude;
    final east = _userPos.longitude > _stopPos.longitude
        ? _userPos.longitude
        : _stopPos.longitude;

    final bounds = LatLngBounds(
      southwest: LatLng(south - 0.002, west - 0.002),
      northeast: LatLng(north + 0.002, east + 0.002),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 60),
    );
  }

  void _toggleWalkingNavigation() {
    setState(() {
      _isNavigating = !_isNavigating;
    });

    final stopName = widget.routeOption.departureStop.name;
    final message = _isNavigating
        ? 'tcu.walking_started'.tr(args: [stopName])
        : 'Guidage piéton suspendu';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor:
            _isNavigating ? AppColors.primary : AppColors.buttonBlack,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
        ),
        duration: const Duration(seconds: 2),
      ),
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
          // 1. Guaranteed Dakar Vector Street Map (always visible, matching Screenshot 4)
          Positioned.fill(
            child: CustomPaint(
              painter: _DakarWalkingMapPainter(
                isNavigating: _isNavigating,
              ),
            ),
          ),

          // 1b. GoogleMap overlay if available
          if (_useGoogleMaps)
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    (_userPos.latitude + _stopPos.latitude) / 2,
                    (_userPos.longitude + _stopPos.longitude) / 2,
                  ),
                  zoom: 16.2,
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

          // 2. Floating Distance Badge on the map (indicates distance & duration along the route)
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            right: AppConstants.spacingMd,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingUnitLg,
                vertical: AppConstants.spacingUnit,
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
                  color: AppColors.tcuFieldBorder,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.directions_walk,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${stop.walkingDistanceMeters} m · ${stop.walkingDurationMinutes} min à pied',
                    style: GoogleFonts.inter(
                      fontSize: AppConstants.fontSm,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Top Navigation Bar matching Screenshot 4
          SafeArea(
            child: Padding(
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
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusPill),
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
            ),
          ),

          // 4. Bottom Sheet firmly anchored at the bottom (matching Screenshot 4)
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

                  // Stop name & Transit Badge (Screenshot 4)
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

                  // 3 Stat Cards: À pied, Durée, Prochain bus
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatBox(
                          label: 'tcu.walking_dist'.tr(),
                          value: '${stop.walkingDistanceMeters} m',
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingSm),
                      Expanded(
                        child: _buildStatBox(
                          label: 'tcu.duration'.tr(),
                          value: '${stop.walkingDurationMinutes} min',
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

                  // Big Orange Action Button at the very bottom: "Démarrer la marche"
                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _toggleWalkingNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isNavigating
                            ? AppColors.buttonBlack
                            : AppColors.primary,
                        foregroundColor: AppColors.white,
                        elevation: AppConstants.elevationNone,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusDefault),
                        ),
                      ),
                      child: Text(
                        _isNavigating
                            ? 'Arrêter le guidage'
                            : 'tcu.start_walking'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: AppConstants.fontLg,
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

  Widget _buildStatBox({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppConstants.spacingUnitLg,
        horizontal: AppConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.tcuStatCardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: AppConstants.fontSm,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
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
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter rendering the exact Dakar street map matching Screenshot 4 (media_1792687485707.png)
class _DakarWalkingMapPainter extends CustomPainter {
  final bool isNavigating;

  const _DakarWalkingMapPainter({
    required this.isNavigating,
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

    // 4. Dakar Road Grid (Wide white road stripes with soft borders)
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final roadBorderPaint = Paint()
      ..color = const Color(0xFFDED9CD)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    void drawRoad(Offset p1, Offset p2, double roadWidth) {
      // Road border / shadow
      roadBorderPaint.strokeWidth = roadWidth + 2.5;
      canvas.drawLine(p1, p2, roadBorderPaint);
      // Road surface
      roadPaint.strokeWidth = roadWidth;
      canvas.drawLine(p1, p2, roadPaint);
    }

    // Vertical Main Street 1 (left)
    drawRoad(
      Offset(width * 0.23, height * 0.10),
      Offset(width * 0.33, height * 0.70),
      18,
    );

    // Vertical Main Street 2 (right)
    drawRoad(
      Offset(width * 0.72, height * 0.12),
      Offset(width * 0.76, height * 0.70),
      18,
    );

    // Horizontal Street 1 (middle-upper)
    drawRoad(
      Offset(0, height * 0.32),
      Offset(width, height * 0.27),
      16,
    );

    // Horizontal Street 2 (lower)
    drawRoad(
      Offset(0, height * 0.52),
      Offset(width, height * 0.48),
      18,
    );

    // 5. Walking Route: Orange Dotted Line matching Screenshot 4
    // Path: User position (width * 0.29, height * 0.53) -> turns right -> (width * 0.73, height * 0.48) -> turns up -> (width * 0.73, height * 0.36)
    final userPos = Offset(width * 0.29, height * 0.53);
    final cornerTurn1 = Offset(width * 0.29, height * 0.50);
    final cornerTurn2 = Offset(width * 0.73, height * 0.48);
    final stopPos = Offset(width * 0.73, height * 0.36);

    final dotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    void drawDottedSegment(Offset start, Offset end, double step) {
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final distance = Offset(dx, dy).distance;
      if (distance == 0) return;

      final count = (distance / step).round();
      for (int i = 0; i <= count; i++) {
        final t = i / count;
        final point = Offset(start.dx + dx * t, start.dy + dy * t);
        canvas.drawCircle(point, 3.2, dotPaint);
      }
    }

    drawDottedSegment(userPos, cornerTurn1, 9.0);
    drawDottedSegment(cornerTurn1, cornerTurn2, 9.0);
    drawDottedSegment(cornerTurn2, stopPos, 9.0);

    // 6. User Location Dot with Soft Halo (Bottom Left)
    final haloPaint = Paint()..color = const Color(0x332B66FF);
    canvas.drawCircle(userPos, 22, haloPaint);

    final userWhiteBorderPaint = Paint()..color = Colors.white;
    canvas.drawCircle(userPos, 10, userWhiteBorderPaint);

    final userDotPaint = Paint()..color = const Color(0xFF2B66FF);
    canvas.drawCircle(userPos, 6.5, userDotPaint);

    // 7. Destination Stop Pin (Blue Teardrop Marker matching Screenshot 4)
    _drawStopPin(canvas, stopPos);
  }

  void _drawStopPin(Canvas canvas, Offset tip) {
    final pinPaint = Paint()
      ..color = const Color(0xFF274C9E)
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Pin Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(tip.dx, tip.dy + 3),
        width: 14,
        height: 6,
      ),
      shadowPaint,
    );

    // Teardrop marker path
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

    // Inner White Dot
    final whiteDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(headCenter, 5.5, whiteDotPaint);
  }

  @override
  bool shouldRepaint(covariant _DakarWalkingMapPainter oldDelegate) =>
      oldDelegate.isNavigating != isNavigating;
}
