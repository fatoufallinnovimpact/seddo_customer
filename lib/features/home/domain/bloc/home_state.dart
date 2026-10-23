import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/ride/data/models/nearby_driver_model.dart';

class HomeState extends Equatable {
  final LatLng userLocation;
  final List<NearbyDriverModel> drivers;
  final String selectedCategory; // 'eco', 'comfort', 'airport', 'tcu'
  final int driversCount;
  final int arrivalMinutes;
  final bool isMapReady;
  final LatLng? destinationLocation;
  final String? destinationAddress;

  const HomeState({
    // Central Dakar / Plateau coordinates
    this.userLocation = const LatLng(14.6937, -17.4440),
    this.drivers = const [],
    this.selectedCategory = 'seddo_eco',
    this.driversCount = 12,
    this.arrivalMinutes = 3,
    this.isMapReady = false,
    this.destinationLocation,
    this.destinationAddress,
  });

  HomeState copyWith({
    LatLng? userLocation,
    List<NearbyDriverModel>? drivers,
    String? selectedCategory,
    int? driversCount,
    int? arrivalMinutes,
    bool? isMapReady,
    LatLng? destinationLocation,
    String? destinationAddress,
    bool clearDestination = false,
  }) {
    return HomeState(
      userLocation: userLocation ?? this.userLocation,
      drivers: drivers ?? this.drivers,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      driversCount: driversCount ?? this.driversCount,
      arrivalMinutes: arrivalMinutes ?? this.arrivalMinutes,
      isMapReady: isMapReady ?? this.isMapReady,
      destinationLocation: clearDestination
          ? null
          : (destinationLocation ?? this.destinationLocation),
      destinationAddress: clearDestination
          ? null
          : (destinationAddress ?? this.destinationAddress),
    );
  }

  @override
  List<Object?> get props => [
        userLocation,
        drivers,
        selectedCategory,
        driversCount,
        arrivalMinutes,
        isMapReady,
        destinationLocation,
        destinationAddress,
      ];
}
