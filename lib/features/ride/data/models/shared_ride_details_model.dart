import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Details of a shared ride returned by public endpoint GET /v1/share/{token}
/// Accessible without login or authentication.
class SharedRideDetailsModel {
  final String ref;
  final String status;
  final bool live;
  final String driverFirstName;
  final String vehicleMake;
  final String vehicleModel;
  final String vehicleColor;
  final String vehiclePlate;
  final LatLng? driverPosition;
  final String pickupAddress;
  final String dropoffAddress;
  final LatLng? dropoffPosition;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const SharedRideDetailsModel({
    required this.ref,
    required this.status,
    required this.live,
    required this.driverFirstName,
    required this.vehicleMake,
    required this.vehicleModel,
    required this.vehicleColor,
    required this.vehiclePlate,
    this.driverPosition,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.dropoffPosition,
    this.startedAt,
    this.completedAt,
  });

  String get vehicleDescription {
    final buffer = StringBuffer();
    if (vehicleMake.isNotEmpty) buffer.write(vehicleMake);
    if (vehicleModel.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(vehicleModel);
    }
    if (vehicleColor.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(vehicleColor);
    }
    return buffer.isEmpty ? 'Véhicule Seddo' : buffer.toString();
  }

  factory SharedRideDetailsModel.fromJson(Map<String, dynamic> json) {
    final driverMap = json['driver'] as Map<String, dynamic>? ?? {};
    final vehicleMap = driverMap['vehicle'] as Map<String, dynamic>? ?? {};
    final posMap = driverMap['position'] as Map<String, dynamic>? ?? {};
    final dropoffMap = json['dropoff'] as Map<String, dynamic>? ?? {};

    LatLng? parsedDriverPos;
    if (posMap['lat'] != null && posMap['lng'] != null) {
      parsedDriverPos = LatLng(
        (posMap['lat'] as num).toDouble(),
        (posMap['lng'] as num).toDouble(),
      );
    }

    LatLng? parsedDropoffPos;
    if (dropoffMap['lat'] != null && dropoffMap['lng'] != null) {
      parsedDropoffPos = LatLng(
        (dropoffMap['lat'] as num).toDouble(),
        (dropoffMap['lng'] as num).toDouble(),
      );
    }

    return SharedRideDetailsModel(
      ref: (json['ref'] ?? '').toString(),
      status: (json['status'] ?? 'ACCEPTED').toString().toUpperCase(),
      live: json['live'] as bool? ?? true,
      driverFirstName: (driverMap['firstName'] ?? '').toString(),
      vehicleMake: (vehicleMap['make'] ?? '').toString(),
      vehicleModel: (vehicleMap['model'] ?? '').toString(),
      vehicleColor: (vehicleMap['color'] ?? '').toString(),
      vehiclePlate: (vehicleMap['plate'] ?? '').toString(),
      driverPosition: parsedDriverPos,
      pickupAddress: (json['pickupAddress'] ?? '').toString(),
      dropoffAddress: (dropoffMap['address'] ?? '').toString(),
      dropoffPosition: parsedDropoffPos,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString())
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'ref': ref,
        'status': status,
        'live': live,
        'driver': {
          'firstName': driverFirstName,
          'vehicle': {
            'make': vehicleMake,
            'model': vehicleModel,
            'color': vehicleColor,
            'plate': vehiclePlate,
          },
          'position': driverPosition != null
              ? {'lat': driverPosition!.latitude, 'lng': driverPosition!.longitude}
              : null,
        },
        'pickupAddress': pickupAddress,
        'dropoff': {
          'address': dropoffAddress,
          'lat': dropoffPosition?.latitude,
          'lng': dropoffPosition?.longitude,
        },
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };
}
