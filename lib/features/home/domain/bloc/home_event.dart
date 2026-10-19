import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched when the home screen loads
class HomeInitEvent extends HomeEvent {
  const HomeInitEvent();
}

/// Dispatched when real GPS user position is fetched or updated
class HomeUserLocationUpdatedEvent extends HomeEvent {
  final LatLng location;

  const HomeUserLocationUpdatedEvent(this.location);

  @override
  List<Object?> get props => [location];
}

/// Dispatched periodically to make nearby cars pivot in place on themselves
class HomeUpdateDriversEvent extends HomeEvent {
  const HomeUpdateDriversEvent();
}

/// Dispatched when selecting a ride suggestion category (Eco, Confort, etc.)
class HomeSelectCategoryEvent extends HomeEvent {
  final String categoryId;

  const HomeSelectCategoryEvent(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}

/// Dispatched when the user selects a destination from place autocomplete search
class HomeSelectDestinationEvent extends HomeEvent {
  final LatLng destinationLocation;
  final String destinationAddress;

  const HomeSelectDestinationEvent({
    required this.destinationLocation,
    required this.destinationAddress,
  });

  @override
  List<Object?> get props => [destinationLocation, destinationAddress];
}

/// Dispatched when the user clears the selected destination
class HomeClearDestinationEvent extends HomeEvent {
  const HomeClearDestinationEvent();
}

