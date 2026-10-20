import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/widgets/map_marker_helper.dart';

/// Screen displayed when opening the shared live tracking link matching Screenshot 4:
/// - Browser style header with orange Seddo logo and "suivi.seddo.sn/t/8K02F"
/// - Live map tracking car
/// - Bottom card with "Awa partage son trajet avec vous"
/// - "Arrivée prévue 18:42"
/// - Driver details (MS avatar, Moussa, Toyota Corolla)
/// - "Le lien expire à la fin de la course."
class SharedRideTrackingPage extends StatefulWidget {
  final PlaceSearchResult departure;
  final PlaceSearchResult destination;
  final DriverModel driver;
  final List<LatLng> polylinePoints;
  final String shareUrl;
  final String sharerName;
  final String etaText;

  const SharedRideTrackingPage({
    super.key,
    required this.departure,
    required this.destination,
    required this.driver,
    this.polylinePoints = const [],
    this.shareUrl = 'suivi.seddo.sn/t/8K02F',
    this.sharerName = 'Awa',
    this.etaText = '18:42',
  });

  @override
  State<SharedRideTrackingPage> createState() => _SharedRideTrackingPageState();
}

class _SharedRideTrackingPageState extends State<SharedRideTrackingPage> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _carMarkerIcon;
  BitmapDescriptor? _pickupPinIcon;
  BitmapDescriptor? _destPinIcon;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadMarkers() async {
    final car = await MapMarkerHelper.get3DCarMarker();
    final pickup = await MapMarkerHelper.getDeparturePinMarker();
    final dest = await MapMarkerHelper.getDestinationPinMarker();
    if (mounted) {
      setState(() {
        _carMarkerIcon = car;
        _pickupPinIcon = pickup;
        _destPinIcon = dest;
      });
    }
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // 1. Departure location pin
    if (_pickupPinIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup_pin'),
          position: LatLng(
            widget.departure.latitude,
            widget.departure.longitude,
          ),
          icon: _pickupPinIcon!,
          anchor: const Offset(0.5, 1.0),
        ),
      );
    }

    // 2. Destination location pin
    if (_destPinIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dest_pin'),
          position: LatLng(
            widget.destination.latitude,
            widget.destination.longitude,
          ),
          icon: _destPinIcon!,
          anchor: const Offset(0.5, 1.0),
        ),
      );
    }

    // 3. 3D Driver car
    if (_carMarkerIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('shared_car'),
          position: widget.driver.location,
          icon: _carMarkerIcon!,
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    if (widget.polylinePoints.isEmpty) return {};
    return {
      Polyline(
        polylineId: const PolylineId('shared_route'),
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
    final systemTop = MediaQuery.of(context).padding.top;
    final systemBottom = MediaQuery.of(context).padding.bottom;
    final initials = widget.driver.name.isNotEmpty
        ? widget.driver.name
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'MS';

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // 1. Map
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  (widget.departure.latitude + widget.destination.latitude) / 2,
                  (widget.departure.longitude + widget.destination.longitude) /
                      2,
                ),
                zoom: 13.5,
              ),
              onMapCreated: (ctrl) => _mapController = ctrl,
              markers: _buildMarkers(),
              polylines: _buildPolylines(),
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),

          // 2. Top Browser / Seddo URL bar
          Positioned(
            top: systemTop + 8,
            left: AppConstants.spacingMd,
            right: AppConstants.spacingMd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowCardBlack,
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Orange Seddo Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'SEDDO',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Lock icon
                  const Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),

                  // URL
                  Expanded(
                    child: Text(
                      widget.shareUrl,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Close button
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Bottom Card
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
                systemBottom > 0 ? systemBottom + 8 : 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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

                  // "Awa partage son trajet avec vous"
                  Text(
                    '${widget.sharerName} partage son trajet avec vous',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Headline: "Arrivée prévue 18:42"
                  Text(
                    'Arrivée prévue ${widget.etaText}',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Driver card
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: AppColors.avatarBeige,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.driver.name.split(' ').first} · ★ ${widget.driver.rating}',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.driver.carModel} · ${widget.driver.licensePlate}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 12),

                  // Footer note: "Le lien expire à la fin de la course."
                  Text(
                    'Le lien expire à la fin de la course.',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
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
