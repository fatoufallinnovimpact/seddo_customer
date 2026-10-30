import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/widgets/map_marker_helper.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/shared_ride_details_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/services/map_style_service.dart';
import 'package:seddo/services/realtime_service.dart';

/// Écran de consultation publique du suivi de trajet partagé :
/// - Browser style header with orange Seddo logo and public tracking link
/// - Connected to backend public endpoint GET /v1/share/{token}
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
  final String? token;
  final String? rideId;
  final RideService? rideService;

  const SharedRideTrackingPage({
    super.key,
    required this.departure,
    required this.destination,
    required this.driver,
    this.polylinePoints = const [],
    this.shareUrl = 'suivi.seddo.sn/t/8K02F',
    this.sharerName = 'Awa',
    this.etaText = '18:42',
    this.token,
    this.rideId,
    this.rideService,
  });

  @override
  State<SharedRideTrackingPage> createState() => _SharedRideTrackingPageState();
}

class _SharedRideTrackingPageState extends State<SharedRideTrackingPage> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _carMarkerIcon;
  BitmapDescriptor? _pickupPinIcon;
  BitmapDescriptor? _destPinIcon;

  late final RideService _rideService;
  SharedRideDetailsModel? _sharedDetails;
  Timer? _refreshTimer;
  StreamSubscription<RealtimeDriverLocationEvent>? _realtimeLocSub;
  LatLng? _liveDriverPos;
  String? _effectiveToken;
  late String _displayShareUrl;

  @override
  void initState() {
    super.initState();
    _rideService = widget.rideService ?? RideService();
    _liveDriverPos = widget.driver.location;
    _displayShareUrl = widget.shareUrl;
    _effectiveToken = widget.token;
    _loadMarkers();

    final effectiveRideId = widget.rideId ?? '';
    if (effectiveRideId.isNotEmpty) {
      RealtimeService().connect();
      RealtimeService().joinRide(effectiveRideId);

      _realtimeLocSub =
          RealtimeService().driverLocationStream.listen((event) {
        if (!mounted) return;
        if (event.rideId == null || event.rideId == effectiveRideId) {
          setState(() {
            _liveDriverPos = event.location;
          });
        }
      });
    }

    if (_effectiveToken != null && _effectiveToken!.isNotEmpty) {
      _fetchSharedDetails();
      _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted && !RealtimeService().isConnected) {
          _fetchSharedDetails();
        }
      });
    } else if (widget.rideId != null && widget.rideId!.isNotEmpty) {
      _initFromRideId(widget.rideId!);
    }
  }

  Future<void> _initFromRideId(String rideId) async {
    try {
      final res = await _rideService.shareRide(rideId);
      if (!mounted || res == null) return;
      setState(() {
        _effectiveToken = res.token;
        if (res.url.isNotEmpty) {
          _displayShareUrl = res.url;
        }
      });
      _fetchSharedDetails();
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted && !RealtimeService().isConnected) {
          _fetchSharedDetails();
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _realtimeLocSub?.cancel();
    final effectiveRideId = widget.rideId ?? '';
    if (effectiveRideId.isNotEmpty) {
      RealtimeService().leaveRide(effectiveRideId);
    }
    _refreshTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _fetchSharedDetails() async {
    final token = _effectiveToken;
    if (token == null || token.isEmpty) return;

    try {
      final details = await _rideService.getSharedRideDetails(token);
      if (!mounted || details == null) return;

      setState(() {
        _sharedDetails = details;
        if (details.driverPosition != null) {
          _liveDriverPos = details.driverPosition;
        }
      });

      if (_mapController != null && details.driverPosition != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(details.driverPosition!),
        );
      }
    } catch (_) {}
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
    final pickupLat = widget.departure.latitude;
    final pickupLng = widget.departure.longitude;
    if (_pickupPinIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup_pin'),
          position: LatLng(pickupLat, pickupLng),
          icon: _pickupPinIcon!,
          anchor: const Offset(0.5, 1.0),
        ),
      );
    }

    // 2. Destination location pin
    final destLat = _sharedDetails?.dropoffPosition?.latitude ??
        widget.destination.latitude;
    final destLng = _sharedDetails?.dropoffPosition?.longitude ??
        widget.destination.longitude;
    if (_destPinIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dest_pin'),
          position: LatLng(destLat, destLng),
          icon: _destPinIcon!,
          anchor: const Offset(0.5, 1.0),
        ),
      );
    }

    // 3. 3D Driver car
    final carPos = _liveDriverPos ??
        _sharedDetails?.driverPosition ??
        widget.driver.location;
    if (_carMarkerIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('shared_car'),
          position: carPos,
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
    final _ = context.locale;
    final systemTop = MediaQuery.of(context).padding.top;
    final systemBottom = MediaQuery.of(context).padding.bottom;

    final driverName = _sharedDetails != null &&
            _sharedDetails!.driverFirstName.isNotEmpty
        ? _sharedDetails!.driverFirstName
        : widget.driver.name;

    final initials = driverName.isNotEmpty
        ? driverName
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'MS';

    final vehicleText = _sharedDetails != null &&
            _sharedDetails!.vehicleMake.isNotEmpty
        ? '${_sharedDetails!.vehicleMake} ${_sharedDetails!.vehicleModel} · ${_sharedDetails!.vehiclePlate} (${_sharedDetails!.vehicleColor})'
        : '${widget.driver.carModel} · ${widget.driver.licensePlate}';

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // 1. Map
          Positioned.fill(
            child: GoogleMap(
              style: MapStyleService.style,
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  (widget.departure.latitude + widget.destination.latitude) / 2,
                  (widget.departure.longitude + widget.destination.longitude) /
                      2,
                ),
                zoom: 13.5,
              ),
              onMapCreated: (ctrl) {
                _mapController = ctrl;
                MapStyleService.applyStyle(ctrl);
              },
              markers: _buildMarkers(),
              polylines: _buildPolylines(),
              buildingsEnabled: false,
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
                      _displayShareUrl,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Copy URL Button
                  IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 17,
                      color: AppColors.textSecondary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Copier le lien',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _displayShareUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.buttonBlack,
                          content: Text(
                            'Lien copié dans le presse-papier',
                            style: GoogleFonts.inter(color: AppColors.white),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),

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
                  const SizedBox(height: 12),

                  // Status and Ref if available from API
                  if (_sharedDetails != null) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _sharedDetails!.live
                                ? AppColors.refundPillBg
                                : AppColors.surfaceGrey,
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusPill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _sharedDetails!.live
                                      ? AppColors.refundGreen
                                      : AppColors.textSecondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _sharedDetails!.live
                                    ? 'EN DIRECT · ${_sharedDetails!.ref}'
                                    : _sharedDetails!.ref,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _sharedDetails!.live
                                      ? AppColors.refundGreen
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _sharedDetails!.status == 'ACCEPTED'
                              ? 'Chauffeur en route'
                              : _sharedDetails!.status == 'IN_PROGRESS'
                                  ? 'Course en cours'
                                  : _sharedDetails!.status == 'COMPLETED'
                                      ? 'Course terminée'
                                      : _sharedDetails!.status,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // "Awa partage son trajet avec vous"
                  Text(
                    'shared_tracking.shares_ride'.tr(args: [widget.sharerName]),
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Headline: "Arrivée prévue 18:42"
                  Text(
                    'shared_tracking.arriving_at'.tr(args: [widget.etaText]),
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
                              '$driverName · ★ ${widget.driver.rating}',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              vehicleText,
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
                    'shared_tracking.link_expires'.tr(),
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
