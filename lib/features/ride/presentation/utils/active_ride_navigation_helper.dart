import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/models/ride_quote_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/pages/active_ride_page.dart';
import 'package:seddo/features/ride/presentation/pages/driver_approaching_page.dart';
import 'package:seddo/features/ride/presentation/pages/driver_search_page.dart';
import 'package:seddo/services/route_service.dart';

/// Helper to reconstruct the active ride screen (DriverSearchPage,
/// DriverApproachingPage, or ActiveRidePage) from raw ride data.
class ActiveRideNavigationHelper {
  /// Resolves the corresponding active ride screen according to the current ride status.
  /// Returns null if the ride is completed, cancelled or not active.
  static Widget? resolveActiveRidePage(
    Map<String, dynamic> ride, {
    RideService? rideService,
  }) {
    final status = (ride['status'] as String? ?? '').toUpperCase();
    if (status == 'COMPLETED' ||
        status.startsWith('CANCEL') ||
        status == 'NO_DRIVER' ||
        status == 'NO_SHOW' ||
        status.isEmpty) {
      return null;
    }

    final quoteObj = ride['quote'] as Map<String, dynamic>?;
    final pickupRaw = (ride['pickup'] is Map ? ride['pickup'] as Map<String, dynamic> : null) ??
        (quoteObj?['pickup'] is Map ? quoteObj!['pickup'] as Map<String, dynamic> : null) ??
        (ride['departure'] is Map ? ride['departure'] as Map<String, dynamic> : null) ??
        {};

    final dropoffRaw = (ride['dropoff'] is Map ? ride['dropoff'] as Map<String, dynamic> : null) ??
        (quoteObj?['dropoff'] is Map ? quoteObj!['dropoff'] as Map<String, dynamic> : null) ??
        (ride['destination'] is Map ? ride['destination'] as Map<String, dynamic> : null) ??
        {};

    final pickupAddress = (pickupRaw['address'] as String?) ??
        (ride['pickupAddress'] as String?) ??
        (quoteObj?['pickupAddress'] as String?) ??
        'Point de départ';

    final dropoffAddress = (dropoffRaw['address'] as String?) ??
        (ride['dropoffAddress'] as String?) ??
        (quoteObj?['dropoffAddress'] as String?) ??
        'Point d\'arrivée';

    final pickupLat = (pickupRaw['lat'] as num?)?.toDouble() ??
        (ride['pickupLat'] as num?)?.toDouble() ??
        (pickupRaw['latitude'] as num?)?.toDouble();
    final pickupLng = (pickupRaw['lng'] as num?)?.toDouble() ??
        (ride['pickupLng'] as num?)?.toDouble() ??
        (pickupRaw['longitude'] as num?)?.toDouble();

    final dropoffLat = (dropoffRaw['lat'] as num?)?.toDouble() ??
        (ride['dropoffLat'] as num?)?.toDouble() ??
        (dropoffRaw['latitude'] as num?)?.toDouble();
    final dropoffLng = (dropoffRaw['lng'] as num?)?.toDouble() ??
        (ride['dropoffLng'] as num?)?.toDouble() ??
        (dropoffRaw['longitude'] as num?)?.toDouble();

    if (pickupLat == null || pickupLng == null || dropoffLat == null || dropoffLng == null) {
      return null;
    }

    final departure = PlaceSearchResult(
      id: 'pickup',
      mainText: pickupAddress.split(',').first.trim().isNotEmpty
          ? pickupAddress.split(',').first.trim()
          : 'Départ',
      secondaryText: pickupAddress,
      fullAddress: pickupAddress,
      latitude: pickupLat,
      longitude: pickupLng,
    );

    final destination = PlaceSearchResult(
      id: 'dropoff',
      mainText: dropoffAddress.split(',').first.trim().isNotEmpty
          ? dropoffAddress.split(',').first.trim()
          : 'Destination',
      secondaryText: dropoffAddress,
      fullAddress: dropoffAddress,
      latitude: dropoffLat,
      longitude: dropoffLng,
    );

    final isConfort = (ride['category'] as String? ?? '').toUpperCase() == 'CONFORT';
    final rideType = isConfort ? RideType.confort : RideType.eco;

    final plannedTrafficRaw = (ride['plannedTraffic'] ?? ride['traffic']) as List<dynamic>?;
    final List<TrafficSegmentModel> plannedTraffic = plannedTrafficRaw != null
        ? plannedTrafficRaw
            .whereType<Map<String, dynamic>>()
            .map((item) => TrafficSegmentModel.fromJson(item))
            .toList()
        : const [];

    final rideOption = RideOptionModel(
      type: rideType,
      title: isConfort ? 'Seddo Confort' : 'Seddo Eco',
      subtitle: (ride['categoryName'] as String?) ??
          (isConfort ? 'Seddo Confort' : 'Seddo Eco'),
      price: (ride['finalPrice'] ?? ride['price'] ?? 2000) as int,
      capacity: 4,
      estimatedArrival: 'Dans 15 min',
      pickupDuration: '3 min',
      traffic: plannedTraffic,
    );

    List<LatLng> tripPolyline = [];
    final plannedPolylineStr =
        (ride['plannedPolyline'] ?? ride['polyline']) as String?;
    if (plannedPolylineStr != null && plannedPolylineStr.isNotEmpty) {
      tripPolyline = RouteService.decodePolyline(plannedPolylineStr);
    }

    if (status == 'SEARCHING' || status == 'PAYMENT_PENDING') {
      return DriverSearchPage(
        departure: departure,
        destination: destination,
        rideOption: rideOption,
        polylinePoints: tripPolyline,
        traffic: plannedTraffic,
        rideId: ride['id']?.toString(),
        rideService: rideService,
      );
    }

    final routeRaw = ride['route'] as Map<String, dynamic>?;
    final phase = (routeRaw?['phase'] as String? ?? '').toUpperCase();
    final startedAt = ride['startedAt'];
    final rideId = ride['id']?.toString();

    final driver = DriverModel.fromRideJson(
      ride,
      defaultRideType: rideType,
    );

    final departureCode =
        DriverModel.extractDepartureCode(ride, fallback: '4821');

    final isTripUnderway = (status == 'IN_PROGRESS' ||
            phase == 'TRIP' ||
            (startedAt != null && startedAt.toString().isNotEmpty)) &&
        phase != 'APPROACH';

    if (isTripUnderway) {
      return ActiveRidePage(
        departure: departure,
        destination: destination,
        rideOption: rideOption,
        driver: driver,
        polylinePoints: tripPolyline,
        autoStartSimulation: true,
        rideId: rideId,
        rideService: rideService,
      );
    }

    return DriverApproachingPage(
      departure: departure,
      destination: destination,
      rideOption: rideOption,
      driver: driver,
      departureCode: departureCode,
      polylinePoints: tripPolyline,
      autoStartSimulation: false,
      rideId: rideId,
      rideService: rideService,
    );
  }
}
