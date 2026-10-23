import 'package:equatable/equatable.dart';

/// Represents a nearby driver car on the map.
/// Follows Innov & Impact Africa guidelines (data/models/).
class NearbyDriverModel extends Equatable {
  final String id;
  final double latitude;
  final double longitude;
  final double heading; // 0 to 360 degrees
  final double pivotStep; // degrees to pivot per cycle

  const NearbyDriverModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.heading,
    this.pivotStep = 15.0,
  });

  /// Pivots the car in place on itself without altering coordinates
  NearbyDriverModel pivot() {
    return NearbyDriverModel(
      id: id,
      latitude: latitude,
      longitude: longitude,
      heading: (heading + pivotStep) % 360.0,
      pivotStep: pivotStep,
    );
  }

  NearbyDriverModel copyWith({
    String? id,
    double? latitude,
    double? longitude,
    double? heading,
    double? pivotStep,
  }) {
    return NearbyDriverModel(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      heading: heading ?? this.heading,
      pivotStep: pivotStep ?? this.pivotStep,
    );
  }

  @override
  List<Object?> get props => [id, latitude, longitude, heading, pivotStep];
}
