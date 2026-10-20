import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/ride_option_model.dart';

/// Driver data model representing an assigned Seddo driver.
class DriverModel {
  final String id;
  final String name;
  final String phone;
  final String? photoUrl;
  final double rating;
  final int totalRides;
  final String carModel;
  final String carColor;
  final String licensePlate;
  final RideType rideType;
  final LatLng currentLocation;
  final int etaMinutes;
  final double distanceKm;

  const DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    this.photoUrl,
    required this.rating,
    required this.totalRides,
    required this.carModel,
    required this.carColor,
    required this.licensePlate,
    required this.rideType,
    required this.currentLocation,
    required this.etaMinutes,
    required this.distanceKm,
  });

  /// Default mock driver in Dakar matching user requirements
  factory DriverModel.mockDakarDriver({
    RideType rideType = RideType.eco,
    LatLng? location,
  }) {
    return DriverModel(
      id: 'driver_dakar_01',
      name: 'Moussa Diop',
      phone: '+221 77 123 45 67',
      photoUrl: null,
      rating: 4.9,
      totalRides: 1240,
      carModel: rideType == RideType.eco ? 'Toyota Corolla' : 'Peugeot 508',
      carColor: rideType == RideType.eco ? 'Gris argent' : 'Noir ébène',
      licensePlate: 'DK-4821-AB',
      rideType: rideType,
      currentLocation: location ?? const LatLng(14.7190, -17.4720),
      etaMinutes: 3,
      distanceKm: 1.2,
    );
  }
}
