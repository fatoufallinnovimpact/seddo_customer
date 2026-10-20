import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/domain/models/ride_option_model.dart';

enum RideStatus {
  idle,
  searching,
  driverAssigned,
  driverArrived,
  inProgress,
  completed,
  cancelled,
  noDriver,
}

/// Domain model representing a ride throughout its full lifecycle
class RideModel extends Equatable {
  final String id;
  final PlaceSearchResult departure;
  final PlaceSearchResult destination;
  final RideOptionModel rideOption;
  final DriverModel? driver;
  final RideStatus status;
  final String paymentMethod;
  final String paymentPhone;
  final String transactionRef;
  final List<LatLng> polylinePoints;
  final DateTime createdAt;
  final DateTime? completedAt;

  const RideModel({
    required this.id,
    required this.departure,
    required this.destination,
    required this.rideOption,
    this.driver,
    this.status = RideStatus.idle,
    this.paymentMethod = 'Orange Money',
    this.paymentPhone = '77 ••• 45 12',
    this.transactionRef = 'CI270415.1842.A3F2',
    this.polylinePoints = const [],
    required this.createdAt,
    this.completedAt,
  });

  RideModel copyWith({
    String? id,
    PlaceSearchResult? departure,
    PlaceSearchResult? destination,
    RideOptionModel? rideOption,
    DriverModel? driver,
    RideStatus? status,
    String? paymentMethod,
    String? paymentPhone,
    String? transactionRef,
    List<LatLng>? polylinePoints,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return RideModel(
      id: id ?? this.id,
      departure: departure ?? this.departure,
      destination: destination ?? this.destination,
      rideOption: rideOption ?? this.rideOption,
      driver: driver ?? this.driver,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentPhone: paymentPhone ?? this.paymentPhone,
      transactionRef: transactionRef ?? this.transactionRef,
      polylinePoints: polylinePoints ?? this.polylinePoints,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'departure': {
        'id': departure.id,
        'mainText': departure.mainText,
        'secondaryText': departure.secondaryText,
        'fullAddress': departure.fullAddress,
        'latitude': departure.latitude,
        'longitude': departure.longitude,
      },
      'destination': {
        'id': destination.id,
        'mainText': destination.mainText,
        'secondaryText': destination.secondaryText,
        'fullAddress': destination.fullAddress,
        'latitude': destination.latitude,
        'longitude': destination.longitude,
      },
      'rideOption': {
        'type': rideOption.type.name,
        'title': rideOption.title,
        'price': rideOption.price,
      },
      'status': status.name,
      'paymentMethod': paymentMethod,
      'paymentPhone': paymentPhone,
      'transactionRef': transactionRef,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        departure,
        destination,
        rideOption,
        driver,
        status,
        paymentMethod,
        paymentPhone,
        transactionRef,
        polylinePoints,
        createdAt,
        completedAt,
      ];
}
