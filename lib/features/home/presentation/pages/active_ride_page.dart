import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:seddo/core/navigation/slide_page_route.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/home/domain/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/domain/models/ride_option_model.dart';
import 'package:seddo/features/home/presentation/pages/driver_chat_page.dart';
import 'package:seddo/features/home/presentation/pages/ride_cancelled_page.dart';
import 'package:seddo/features/home/presentation/pages/ride_rating_page.dart';
import 'package:seddo/features/home/presentation/pages/shared_ride_tracking_page.dart';
import 'package:seddo/features/home/presentation/widgets/active_driver_card_widget.dart';
import 'package:seddo/features/home/presentation/widgets/driver_action_buttons_widget.dart';
import 'package:seddo/features/home/presentation/widgets/map_marker_helper.dart';
import 'package:seddo/features/home/presentation/widgets/ride_action_tile_widget.dart';
import 'package:seddo/features/home/presentation/widgets/safety_modal_widget.dart';

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

  const ActiveRidePage({
    super.key,
    required this.departure,
    required this.destination,
    required this.rideOption,
    required this.driver,
    this.polylinePoints = const [],
  });

  @override
  State<ActiveRidePage> createState() => _ActiveRidePageState();
}

class _ActiveRidePageState extends State<ActiveRidePage> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _carMarkerIcon;
  BitmapDescriptor? _pickupBadgeIcon;
  BitmapDescriptor? _destBadgeIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadCustomMarkers() async {
    final car = await MapMarkerHelper.get3DCarMarker();
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
    final uri = Uri.parse('tel:${widget.driver.phone.replaceAll(' ', '')}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          _showCallDialog();
        }
      }
    } catch (_) {
      if (mounted) {
        _showCallDialog();
      }
    }
  }

  void _showCallDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusDialog),
        ),
        title: Text(
          'Appeler ${widget.driver.name}',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Numéro direct du chauffeur :',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.driver.phone,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Annuler',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Appel vers ${widget.driver.phone}...'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            child: const Text('Appeler'),
          ),
        ],
      ),
    );
  }

  void _openChat() {
    Navigator.of(context).push(
      SlideRightToLeftRoute(
        page: DriverChatPage(driver: widget.driver),
      ),
    );
  }

  Future<void> _shareRide() async {
    const shareUrl = 'https://suivi.seddo.sn/t/8K02F';
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
      _showShareOptionsSheet(shareUrl);
    }
  }

  void _showShareOptionsSheet(String shareUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
              'Lien de suivi en direct',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Vos proches peuvent suivre votre voiture en temps réel jusqu\'à destination.',
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
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Aperçu du suivi web',
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

  void _openSafetyModal() {
    SafetyModalWidget.show(
      context,
      destination: widget.destination,
      driver: widget.driver,
    );
  }

  void _simulateArrival() {
    Navigator.of(context).pushReplacement(
      SlideRightToLeftRoute(
        page: RideRatingPage(
          destination: widget.destination,
          driver: widget.driver,
          rideOption: widget.rideOption,
          arrivalTime: widget.rideOption.estimatedArrival,
        ),
      ),
    );
  }

  void _confirmCancelRide() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusDialog),
        ),
        title: Text(
          'Annuler la course ?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'L\'annulation est gratuite dans les 2 minutes. Votre compte Orange Money sera instantanément remboursé de ${widget.rideOption.formattedPrice}.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Conserver la course',
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deleteRed,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                SlideRightToLeftRoute(
                  page: RideCancelledPage(
                    rideOption: widget.rideOption,
                    departure: widget.departure,
                    destination: widget.destination,
                  ),
                ),
              );
            },
            child: const Text('Oui, annuler'),
          ),
        ],
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

    // 3. Driver car marker moving along route
    if (_carMarkerIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver_car_marker'),
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
        polylineId: const PolylineId('active_route'),
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
    final systemBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // 1. Fullscreen Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                (widget.departure.latitude + widget.destination.latitude) / 2,
                (widget.departure.longitude + widget.destination.longitude) / 2,
              ),
              zoom: 13.8,
            ),
            onMapCreated: (ctrl) => _mapController = ctrl,
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
          ),

          // 2. Floating Top Bar with back button, center status, and red safety siren button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingSm,
              ),
              child: Row(
                children: [
                  Container(
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

                  const SizedBox(width: AppConstants.spacingSm),

                  Expanded(
                    child: Center(
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
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Arrive dans ${widget.driver.etaMinutes} min',
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

          // 3. Bottom Sheet Modal with Driver Information & Communication
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
                10,
                AppConstants.spacingLg,
                systemBottom + 10,
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
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
                    const SizedBox(height: 14),

                    // Header: "En route vers [Destination]" (Screenshot 1)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'En route vers ${widget.destination.mainText}',
                            style: GoogleFonts.inter(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Arrivée prévue ${widget.rideOption.estimatedArrival} · ${widget.driver.distanceKm} km restants',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Driver Summary Card with initials avatar and "✓ Payé" badge (Screenshot 1)
                    ActiveDriverCardWidget(
                      driver: widget.driver,
                      isPaid: true,
                    ),

                    const SizedBox(height: 10),

                    // Quick Communication Row (Message & Appeler)
                    DriverActionButtonsWidget(
                      onMessagePressed: _openChat,
                      onCallPressed: _callDriver,
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 8),

                    // Row 1: "Partager le trajet" (Screenshot 1)
                    RideActionTileWidget(
                      icon: Icons.share_outlined,
                      iconColor: AppColors.textPrimary,
                      iconBgColor: AppColors.surfaceGrey,
                      title: 'Partager le trajet',
                      subtitle: 'Envoyer le suivi en direct à un proche',
                      onTap: _shareRide,
                    ),

                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 8),

                    // Row 2: "Sécurité" (Screenshot 1)
                    RideActionTileWidget(
                      icon: Icons.shield_outlined,
                      iconColor: AppColors.sirenRed,
                      iconBgColor: AppColors.walletContainerBg,
                      title: 'Sécurité',
                      subtitle: 'Urgence, contacts d\'urgence, signaler',
                      onTap: _openSafetyModal,
                    ),

                    const SizedBox(height: 12),

                    // Annuler la course Link
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.deleteRed,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusDefault,
                            ),
                          ),
                        ),
                        onPressed: _confirmCancelRide,
                        child: Text(
                          'Annuler la course',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deleteRed,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Simulator shortcut: "Simuler : arrivée" (Screenshot 1)
                    GestureDetector(
                      onTap: _simulateArrival,
                      child: Text(
                        'Simuler : arrivée',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
