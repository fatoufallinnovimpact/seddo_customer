import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';

enum RideMapCameraMode {
  tripOverview,
  destination,
  departure,
}

/// Bouton flottant circulaire de contrôle de caméra lors d'un trajet (style Yango) :
/// Le bouton affiche toujours la prochaine cible de caméra :
/// 1. La carte affiche tout le trajet (tripOverview) -> L'icône affichée est FLAG (flag-svgrepo-com.svg)
///    Un clic amène la caméra au point d'arrivée (destination).
/// 2. La carte est sur le point d'arrivée (destination) -> L'icône affichée devient le point de départ (silhouette passager Icons.hail_rounded)
///    Un clic amène la caméra au point de départ (departure).
/// 3. La carte est sur le point de départ (departure) -> L'icône affichée devient le trajet TRIP (trip-svgrepo-com.svg)
///    Un clic affiche la vue d'ensemble du tracé polyline entre départ et arrivée (tripOverview).
class RideMapCameraToggleButton extends StatefulWidget {
  final GoogleMapController? Function() mapControllerGetter;
  final LatLng departureLocation;
  final LatLng destinationLocation;
  final List<LatLng> polylinePoints;
  final RideMapCameraMode initialMode;
  final ValueChanged<RideMapCameraMode>? onModeChanged;
  final double topPadding;
  final double bottomPadding;

  const RideMapCameraToggleButton({
    super.key,
    required this.mapControllerGetter,
    required this.departureLocation,
    required this.destinationLocation,
    this.polylinePoints = const [],
    this.initialMode = RideMapCameraMode.tripOverview,
    this.onModeChanged,
    this.topPadding = 80,
    this.bottomPadding = 320,
  });

  @override
  State<RideMapCameraToggleButton> createState() =>
      _RideMapCameraToggleButtonState();
}

class _RideMapCameraToggleButtonState extends State<RideMapCameraToggleButton> {
  late RideMapCameraMode _currentMode;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
  }

  void _onTap() {
    // Transition cyclique de la vue :
    // tripOverview -> clic va vers destination
    // destination  -> clic va vers departure
    // departure    -> clic va vers tripOverview
    final nextMode = switch (_currentMode) {
      RideMapCameraMode.tripOverview => RideMapCameraMode.destination,
      RideMapCameraMode.destination => RideMapCameraMode.departure,
      RideMapCameraMode.departure => RideMapCameraMode.tripOverview,
    };

    setState(() {
      _currentMode = nextMode;
    });

    widget.onModeChanged?.call(nextMode);
    _applyCameraForMode(nextMode);
  }

  void _applyCameraForMode(RideMapCameraMode mode) {
    final controller = widget.mapControllerGetter();
    if (controller == null) return;

    switch (mode) {
      case RideMapCameraMode.destination:
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: widget.destinationLocation,
              zoom: 16.5,
            ),
          ),
        );
        break;

      case RideMapCameraMode.departure:
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: widget.departureLocation,
              zoom: 16.5,
            ),
          ),
        );
        break;

      case RideMapCameraMode.tripOverview:
        _fitBounds(controller);
        break;
    }
  }

  void _fitBounds(GoogleMapController controller) {
    if (widget.polylinePoints.isNotEmpty) {
      double south = widget.departureLocation.latitude;
      double north = widget.departureLocation.latitude;
      double west = widget.departureLocation.longitude;
      double east = widget.departureLocation.longitude;

      for (final p in widget.polylinePoints) {
        if (p.latitude < south) south = p.latitude;
        if (p.latitude > north) north = p.latitude;
        if (p.longitude < west) west = p.longitude;
        if (p.longitude > east) east = p.longitude;
      }

      final bounds = LatLngBounds(
        southwest: LatLng(south, west),
        northeast: LatLng(north, east),
      );

      controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    } else {
      final south = math.min(
        widget.departureLocation.latitude,
        widget.destinationLocation.latitude,
      );
      final north = math.max(
        widget.departureLocation.latitude,
        widget.destinationLocation.latitude,
      );
      final west = math.min(
        widget.departureLocation.longitude,
        widget.destinationLocation.longitude,
      );
      final east = math.max(
        widget.departureLocation.longitude,
        widget.destinationLocation.longitude,
      );

      final bounds = LatLngBounds(
        southwest: LatLng(south, west),
        northeast: LatLng(north, east),
      );

      controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    }
  }

  Widget _buildIconForCurrentView(RideMapCameraMode currentView) {
    switch (currentView) {
      case RideMapCameraMode.tripOverview:
        // La carte affiche tout le trajet -> Le bouton montre le drapeau d'arrivée
        return SvgPicture.asset(
          'assets/icons/flag-svgrepo-com.svg',
          width: 22,
          height: 22,
          colorFilter: const ColorFilter.mode(
            AppColors.markerIconBlack,
            BlendMode.srcIn,
          ),
        );

      case RideMapCameraMode.destination:
        // La carte est à l'arrivée -> Le bouton montre la silhouette du départ
        return const Icon(
          Icons.hail_rounded,
          color: AppColors.markerIconBlack,
          size: 24,
        );

      case RideMapCameraMode.departure:
        // La carte est au départ -> Le bouton montre l'icône de vue d'ensemble du trajet
        return SvgPicture.asset(
          'assets/icons/trip-svgrepo-com.svg',
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(
            AppColors.markerIconBlack,
            BlendMode.srcIn,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppConstants.circularPickerSize,
      height: AppConstants.circularPickerSize,
      decoration: const BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowCardBlack,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _onTap,
          child: Center(
            child: _buildIconForCurrentView(_currentMode),
          ),
        ),
      ),
    );
  }
}
