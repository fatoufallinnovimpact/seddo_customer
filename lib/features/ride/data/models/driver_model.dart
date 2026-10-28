import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';

/// Driver data model representing an assigned Seddo driver.
/// Follows Innov & Impact Africa guidelines (data/models/).
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

  /// Convenience getter for current location
  LatLng get location => currentLocation;

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

  DriverModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? photoUrl,
    double? rating,
    int? totalRides,
    String? carModel,
    String? carColor,
    String? licensePlate,
    RideType? rideType,
    LatLng? currentLocation,
    int? etaMinutes,
    double? distanceKm,
  }) {
    return DriverModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      rating: rating ?? this.rating,
      totalRides: totalRides ?? this.totalRides,
      carModel: carModel ?? this.carModel,
      carColor: carColor ?? this.carColor,
      licensePlate: licensePlate ?? this.licensePlate,
      rideType: rideType ?? this.rideType,
      currentLocation: currentLocation ?? this.currentLocation,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'rating': rating,
      'totalRides': totalRides,
      'carModel': carModel,
      'carColor': carColor,
      'licensePlate': licensePlate,
      'rideType': rideType.name,
      'lat': currentLocation.latitude,
      'lng': currentLocation.longitude,
      'etaMinutes': etaMinutes,
      'distanceKm': distanceKm,
    };
  }

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Chauffeur Seddo',
      phone: json['phone'] as String? ?? '+221 77 123 45 67',
      photoUrl: json['photoUrl'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      totalRides: json['totalRides'] as int? ?? 1250,
      carModel: json['carModel'] as String? ?? 'Toyota Corolla',
      carColor: json['carColor'] as String? ?? 'Blanc',
      licensePlate: json['licensePlate'] as String? ?? 'DK-4582-AB',
      rideType: json['rideType'] == 'confort' ? RideType.confort : RideType.eco,
      currentLocation: LatLng(
        (json['lat'] as num?)?.toDouble() ?? 14.6937,
        (json['lng'] as num?)?.toDouble() ?? -17.4647,
      ),
      etaMinutes: json['etaMinutes'] as int? ?? 3,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 1.2,
    );
  }

  factory DriverModel.mockDakarDriver({
    required RideType rideType,
    LatLng? location,
  }) {
    return DriverModel(
      id: 'driver_moussa_diop',
      name: 'Moussa Diop',
      phone: '+221 77 123 45 67',
      rating: 4.9,
      totalRides: 1420,
      carModel: rideType == RideType.confort
          ? 'Mercedes-Benz Classe C'
          : 'Toyota Corolla',
      carColor: 'Gris argent',
      licensePlate: 'DK-4821-AB',
      rideType: rideType,
      currentLocation: location ?? const LatLng(14.6980, -17.4680),
      etaMinutes: 3,
      distanceKm: 0.8,
    );
  }

  /// Extrait et instancie un [DriverModel] depuis la réponse de l'API :
  /// GET /v1/rides/{id} ou GET /v1/rides/current
  factory DriverModel.fromRideJson(
    Map<String, dynamic> rawJson, {
    RideType? defaultRideType,
  }) {
    final json = rawJson['ride'] is Map<String, dynamic>
        ? rawJson['ride'] as Map<String, dynamic>
        : rawJson;

    final driverRaw = json['driver'] is Map<String, dynamic>
        ? json['driver'] as Map<String, dynamic>
        : json;

    final vehicleRaw = driverRaw['vehicle'] is Map<String, dynamic>
        ? driverRaw['vehicle'] as Map<String, dynamic>
        : <String, dynamic>{};

    final firstName = driverRaw['firstName'] as String? ?? '';
    final lastName = driverRaw['lastName'] as String? ?? '';
    String resolvedName = driverRaw['name'] as String? ?? '';
    if (resolvedName.isEmpty && (firstName.isNotEmpty || lastName.isNotEmpty)) {
      resolvedName = '$firstName $lastName'.trim();
    }
    if (resolvedName.isEmpty) resolvedName = 'Chauffeur Seddo';

    final vehicleMake = vehicleRaw['make'] as String? ?? '';
    final vehicleModel = vehicleRaw['model'] as String? ??
        (driverRaw['carModel'] as String? ?? 'Toyota Corolla');
    final resolvedCarModel =
        vehicleMake.isNotEmpty && !vehicleModel.startsWith(vehicleMake)
            ? '$vehicleMake $vehicleModel'
            : vehicleModel;

    final resolvedCarColor = vehicleRaw['color'] as String? ??
        (driverRaw['carColor'] as String? ?? 'Gris');
    final resolvedPlate = vehicleRaw['plate'] as String? ??
        (driverRaw['licensePlate'] as String? ?? 'DK-4582-AB');

    // Location
    final locRaw = driverRaw['location'] is Map<String, dynamic>
        ? driverRaw['location'] as Map<String, dynamic>
        : null;
    final lat = (locRaw?['lat'] as num?)?.toDouble() ??
        (driverRaw['lat'] as num?)?.toDouble() ??
        14.6937;
    final lng = (locRaw?['lng'] as num?)?.toDouble() ??
        (driverRaw['lng'] as num?)?.toDouble() ??
        -17.4647;

    final eta = (json['etaMinutes'] as num?)?.toInt() ??
        (json['eta'] as num?)?.toInt() ??
        (driverRaw['etaMinutes'] as num?)?.toInt() ??
        3;

    final category =
        (json['category'] as String? ?? driverRaw['rideType'] as String? ?? '')
            .toUpperCase();
    final rType = category == 'CONFORT'
        ? RideType.confort
        : (defaultRideType ?? RideType.eco);

    return DriverModel(
      id: driverRaw['id']?.toString() ?? '',
      name: resolvedName,
      phone: driverRaw['phone'] as String? ??
          (driverRaw['phoneNumber'] as String? ?? '+221 77 123 45 67'),
      photoUrl: driverRaw['photoUrl'] as String? ??
          (driverRaw['photo'] as String? ?? driverRaw['avatar'] as String?),
      rating: (driverRaw['rating'] as num?)?.toDouble() ?? 4.9,
      totalRides: (driverRaw['totalRides'] as num?)?.toInt() ?? 1250,
      carModel: resolvedCarModel,
      carColor: resolvedCarColor,
      licensePlate: resolvedPlate,
      rideType: rType,
      currentLocation: LatLng(lat, lng),
      etaMinutes: eta,
      distanceKm: (driverRaw['distanceKm'] as num?)?.toDouble() ??
          (json['distanceKm'] as num?)?.toDouble() ??
          1.2,
    );
  }

  /// Extrait le code de départ à 4 chiffres depuis la réponse de l'API :
  /// Supporte 'code', 'startCode', 'departureCode', 'pin'
  static String extractDepartureCode(
    Map<String, dynamic> rawJson, {
    String fallback = '4821',
  }) {
    final rideMap = rawJson['ride'] is Map<String, dynamic>
        ? rawJson['ride'] as Map<String, dynamic>
        : rawJson;

    final raw = rideMap['code'] ??
        rideMap['startCode'] ??
        rideMap['departureCode'] ??
        rideMap['pin'] ??
        rawJson['code'] ??
        rawJson['startCode'] ??
        rawJson['departureCode'] ??
        rawJson['pin'];

    if (raw != null) {
      final str = raw.toString().trim();
      if (str.isNotEmpty) return str;
    }
    return fallback;
  }
}
