import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/home/domain/bloc/home_bloc.dart';
import 'package:seddo/features/home/domain/bloc/home_state.dart';
import 'package:seddo/features/home/presentation/widgets/map_marker_helper.dart';

/// Embedded interactive Google Map Card matching the reference mockup:
/// - Smooth moving nearby drivers (active cars) around Dakar
/// - Full interactive map gestures (pan, zoom, rotate, tilt)
/// - Custom user location pin and realistic top-down car markers
/// - Floating pill indicator: "12 chauffeurs autour · 3 min"
class HomeMapCard extends StatefulWidget {
  final double height;

  const HomeMapCard({
    super.key,
    this.height = 300,
  });

  @override
  State<HomeMapCard> createState() => _HomeMapCardState();
}

class _HomeMapCardState extends State<HomeMapCard> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _userIcon;
  BitmapDescriptor? _destPinIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();
  }

  Future<void> _loadCustomMarkers() async {
    final car = await MapMarkerHelper.get3DCarMarker();
    final user = await MapMarkerHelper.getUserLocationMarker();
    final dest = await MapMarkerHelper.getDestinationPinMarker();
    if (mounted) {
      setState(() {
        _carIcon = car;
        _userIcon = user;
        _destPinIcon = dest;
      });
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeBloc, HomeState>(
      listenWhen: (prev, curr) =>
          prev.userLocation != curr.userLocation ||
          prev.destinationLocation != curr.destinationLocation,
      listener: (context, state) {
        if (state.destinationLocation != null) {
          final south = math.min(
            state.userLocation.latitude,
            state.destinationLocation!.latitude,
          );
          final north = math.max(
            state.userLocation.latitude,
            state.destinationLocation!.latitude,
          );
          final west = math.min(
            state.userLocation.longitude,
            state.destinationLocation!.longitude,
          );
          final east = math.max(
            state.userLocation.longitude,
            state.destinationLocation!.longitude,
          );

          final bounds = LatLngBounds(
            southwest: LatLng(south, west),
            northeast: LatLng(north, east),
          );

          _mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 50),
          );
        } else {
          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: state.userLocation,
                zoom: 15.6,
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final Set<Marker> markers = {};

        // 1. User Position Marker
        if (_userIcon != null) {
          markers.add(
            Marker(
              markerId: const MarkerId('user_location'),
              position: state.userLocation,
              icon: _userIcon!,
              anchor: const Offset(0.5, 0.5),
              zIndexInt: 2,
            ),
          );
        }

        // 2. Moving Nearby Driver Cars
        if (_carIcon != null) {
          for (final driver in state.drivers) {
            markers.add(
              Marker(
                markerId: MarkerId(driver.id),
                position: LatLng(driver.latitude, driver.longitude),
                rotation: driver.heading,
                icon: _carIcon!,
                anchor: const Offset(0.5, 0.5),
                flat: true,
                zIndexInt: 1,
              ),
            );
          }
        }

        // 3. Destination Marker (if selected)
        if (state.destinationLocation != null) {
          markers.add(
            Marker(
              markerId: const MarkerId('destination_location'),
              position: state.destinationLocation!,
              icon: _destPinIcon ??
                  BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueOrange,
                  ),
              anchor: const Offset(0.5, 1.0),
              infoWindow: InfoWindow(
                title: state.destinationAddress ?? 'Destination',
              ),
              zIndexInt: 3,
            ),
          );
        }

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // 1. Interactive Google Map with all gestures enabled
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: state.userLocation,
                    zoom: 15.6,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    controller.animateCamera(
                      CameraUpdate.newLatLng(state.userLocation),
                    );
                  },
                  markers: markers,
                  zoomGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  // EagerGestureRecognizer allows zoom/pan without scroll interference
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                ),

                // 2. Floating Bottom Pill: "12 chauffeurs autour · 3 min"
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadowLight,
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.directions_car_filled,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${state.driversCount} chauffeurs autour · ${state.arrivalMinutes} min',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
