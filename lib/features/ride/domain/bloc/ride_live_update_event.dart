import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_model.dart';

abstract class RideLiveUpdateEvent extends Equatable {
  const RideLiveUpdateEvent();

  @override
  List<Object?> get props => [];
}

/// Initializes and starts the Live Activity / Live Update for an assigned ride
class InitializeLiveUpdateEvent extends RideLiveUpdateEvent {
  final String rideId;
  final DriverModel driver;
  final PlaceSearchResult? departure;
  final PlaceSearchResult? destination;
  final RideStatus? initialStatus;

  const InitializeLiveUpdateEvent({
    required this.rideId,
    required this.driver,
    this.departure,
    this.destination,
    this.initialStatus,
  });

  @override
  List<Object?> get props => [rideId, driver, departure, destination, initialStatus];
}

/// Dispatched when the driver's GPS location or arrival ETA updates
class UpdateLiveUpdateLocationEvent extends RideLiveUpdateEvent {
  final LatLng location;
  final int? etaMinutes;
  final double? distanceKm;
  final double? progress;

  const UpdateLiveUpdateLocationEvent({
    required this.location,
    this.etaMinutes,
    this.distanceKm,
    this.progress,
  });

  @override
  List<Object?> get props => [location, etaMinutes, distanceKm, progress];
}

/// Dispatched when ETA calculation changes
class UpdateLiveUpdateEtaEvent extends RideLiveUpdateEvent {
  final int etaMinutes;
  final double? distanceKm;
  final double? progress;

  const UpdateLiveUpdateEtaEvent({
    required this.etaMinutes,
    this.distanceKm,
    this.progress,
  });

  @override
  List<Object?> get props => [etaMinutes, distanceKm, progress];
}

/// Dispatched when backend emits a ride status change (e.g. driver arrived, in progress, completed, cancelled)
class UpdateLiveUpdateStatusEvent extends RideLiveUpdateEvent {
  final String status;
  final DriverModel? driver;

  const UpdateLiveUpdateStatusEvent({
    required this.status,
    this.driver,
  });

  @override
  List<Object?> get props => [status, driver];
}

/// Dispatched to manually dismiss or cancel the live update
class DismissLiveUpdateEvent extends RideLiveUpdateEvent {
  final String? reason;

  const DismissLiveUpdateEvent({this.reason});

  @override
  List<Object?> get props => [reason];
}
