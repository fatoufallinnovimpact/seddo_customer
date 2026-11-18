import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/models/ride_quote_model.dart';

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
  final double? heading;
  final String? approachPolyline;
  final int? approachDurationS;
  final int? approachDistanceM;
  final List<TrafficSegmentModel> approachTraffic;

  /// Convenience getter for current location
  LatLng get location => currentLocation;

  /// Convenience getter for driver phone number
  String get phoneNumber => phone;

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
    this.heading,
    this.approachPolyline,
    this.approachDurationS,
    this.approachDistanceM,
    this.approachTraffic = const [],
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
    double? heading,
    String? approachPolyline,
    int? approachDurationS,
    int? approachDistanceM,
    List<TrafficSegmentModel>? approachTraffic,
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
      heading: heading ?? this.heading,
      approachPolyline: approachPolyline ?? this.approachPolyline,
      approachDurationS: approachDurationS ?? this.approachDurationS,
      approachDistanceM: approachDistanceM ?? this.approachDistanceM,
      approachTraffic: approachTraffic ?? this.approachTraffic,
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
      if (heading != null) 'heading': heading,
      if (approachPolyline != null) 'approachPolyline': approachPolyline,
      if (approachDurationS != null) 'approachDurationS': approachDurationS,
      if (approachDistanceM != null) 'approachDistanceM': approachDistanceM,
    };
  }

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    final vehicleMap = json['vehicle'] is Map<String, dynamic>
        ? json['vehicle'] as Map<String, dynamic>
        : null;
    final resolvedColor = (json['carColor'] ??
            json['vehicleColor'] ??
            json['color'] ??
            vehicleMap?['color'] ??
            vehicleMap?['carColor'] ??
            'Blanc')
        .toString();
    return DriverModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Chauffeur Seddo',
      phone: json['phone'] as String? ?? '+221 77 123 45 67',
      photoUrl: json['photoUrl'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      totalRides: json['totalRides'] as int? ?? 1250,
      carModel: json['carModel'] as String? ?? 'Toyota Corolla',
      carColor: resolvedColor,
      licensePlate: json['licensePlate'] as String? ?? 'DK-4582-AB',
      rideType: json['rideType'] == 'confort' ? RideType.confort : RideType.eco,
      currentLocation: LatLng(
        (json['lat'] is num
                ? (json['lat'] as num).toDouble()
                : (json['lat'] is String ? double.tryParse(json['lat']) : null)) ??
            14.6937,
        (json['lng'] is num
                ? (json['lng'] as num).toDouble()
                : (json['lng'] is String ? double.tryParse(json['lng']) : null)) ??
            -17.4647,
      ),
      etaMinutes: json['etaMinutes'] as int? ?? 3,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 1.2,
      heading: (json['heading'] ?? json['cap'] ?? json['bearing']) is num
          ? ((json['heading'] ?? json['cap'] ?? json['bearing']) as num).toDouble()
          : ((json['heading'] ?? json['cap'] ?? json['bearing']) is String
              ? double.tryParse(json['heading'] ?? json['cap'] ?? json['bearing'])
              : null),
      approachPolyline: json['approachPolyline'] as String?,
      approachDurationS: (json['approachDurationS'] as num?)?.toInt(),
      approachDistanceM: (json['approachDistanceM'] as num?)?.toInt(),
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
      carColor: '',
      licensePlate: 'DK-4821-AB',
      rideType: rideType,
      currentLocation: location ?? const LatLng(14.6980, -17.4680),
      etaMinutes: 3,
      distanceKm: 0.8,
    );
  }

  /// Extrait et instancie un [DriverModel] depuis la réponse de l'API :
  /// GET /v1/rides/{id} ou GET /v1/rides/current ou événement WebSocket
  factory DriverModel.fromRideJson(
    Map<String, dynamic> rawJson, {
    RideType? defaultRideType,
    String? fallbackCarColor,
    String? fallbackName,
    String? fallbackPhotoUrl,
  }) {
    final unwrapped = rawJson['data'] is Map<String, dynamic>
        ? rawJson['data'] as Map<String, dynamic>
        : rawJson;

    final json = unwrapped['ride'] is Map<String, dynamic>
        ? unwrapped['ride'] as Map<String, dynamic>
        : (rawJson['ride'] is Map<String, dynamic>
            ? rawJson['ride'] as Map<String, dynamic>
            : unwrapped);

    final driverRaw = json['driver'] is Map<String, dynamic>
        ? json['driver'] as Map<String, dynamic>
        : (unwrapped['driver'] is Map<String, dynamic>
            ? unwrapped['driver'] as Map<String, dynamic>
            : json);

    final userRaw = driverRaw['user'] is Map<String, dynamic>
        ? driverRaw['user'] as Map<String, dynamic>
        : (driverRaw['identity'] is Map<String, dynamic>
            ? driverRaw['identity'] as Map<String, dynamic>
            : (driverRaw['profile'] is Map<String, dynamic>
                ? driverRaw['profile'] as Map<String, dynamic>
                : <String, dynamic>{}));

    final vehicleRaw = driverRaw['vehicle'] is Map<String, dynamic>
        ? driverRaw['vehicle'] as Map<String, dynamic>
        : (driverRaw['vehicule'] is Map<String, dynamic>
            ? driverRaw['vehicule'] as Map<String, dynamic>
            : (json['vehicle'] is Map<String, dynamic>
                ? json['vehicle'] as Map<String, dynamic>
                : (json['vehicule'] is Map<String, dynamic>
                    ? json['vehicule'] as Map<String, dynamic>
                    : (unwrapped['vehicle'] is Map<String, dynamic>
                        ? unwrapped['vehicle'] as Map<String, dynamic>
                        : (unwrapped['vehicule'] is Map<String, dynamic>
                            ? unwrapped['vehicule'] as Map<String, dynamic>
                            : (rawJson['vehicle'] is Map<String, dynamic>
                                ? rawJson['vehicle'] as Map<String, dynamic>
                                : (rawJson['vehicule'] is Map<String, dynamic>
                                    ? rawJson['vehicule'] as Map<String, dynamic>
                                    : (driverRaw['car'] is Map<String, dynamic>
                                        ? driverRaw['car'] as Map<String, dynamic>
                                        : (json['car'] is Map<String, dynamic>
                                            ? json['car'] as Map<String, dynamic>
                                            : <String, dynamic>{})))))))));

    String? firstNonEmpty(List<dynamic> candidates) {
      for (final c in candidates) {
        if (c != null) {
          final str = c.toString().trim();
          if (str.isNotEmpty && str.toLowerCase() != 'null') {
            return str;
          }
        }
      }
      return null;
    }

    final firstName = firstNonEmpty([
          driverRaw['firstName'],
          driverRaw['prenom'],
          driverRaw['givenName'],
          userRaw['firstName'],
          userRaw['prenom'],
          json['driverFirstName'],
        ]) ??
        '';
    final lastName = firstNonEmpty([
          driverRaw['lastName'],
          driverRaw['nom'],
          driverRaw['familyName'],
          userRaw['lastName'],
          userRaw['nom'],
          json['driverLastName'],
        ]) ??
        '';
    String resolvedName = firstNonEmpty([
          driverRaw['fullName'],
          driverRaw['displayName'],
          userRaw['fullName'],
          userRaw['name'],
          driverRaw['name'],
          json['driverName'],
        ]) ??
        '';

    bool isAbbreviatedName(String n) {
      final trimmed = n.trim();
      if (trimmed.isEmpty) return true;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 2) return true;
      final last = parts.last.replaceAll('.', '');
      return trimmed.endsWith('.') || last.length <= 1;
    }

    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      final combined = '$firstName $lastName'.trim();
      final cleanLast = lastName.replaceAll('.', '').trim();
      if (resolvedName.isEmpty ||
          isAbbreviatedName(resolvedName) ||
          (cleanLast.length > 1 && combined.length > resolvedName.length)) {
        resolvedName = combined;
      }
    } else if (lastName.isNotEmpty &&
        resolvedName.isNotEmpty &&
        !resolvedName.toLowerCase().contains(lastName.toLowerCase())) {
      final cleanFirst = resolvedName.split(RegExp(r'\s+')).first;
      resolvedName = '$cleanFirst $lastName'.trim();
    } else if (resolvedName.isEmpty &&
        (firstName.isNotEmpty || lastName.isNotEmpty)) {
      resolvedName = '$firstName $lastName'.trim();
    }

    // Si une réponse partielle ne contient que le prénom ou un nom abrégé ("Abibatou f.") alors qu'on connaissait déjà le nom complet (ex: "Abibatou Fall"), on conserve le nom complet
    if (fallbackName != null &&
        !isAbbreviatedName(fallbackName) &&
        isAbbreviatedName(resolvedName) &&
        (resolvedName.isEmpty ||
            fallbackName
                .trim()
                .toLowerCase()
                .startsWith(resolvedName.split(' ').first.toLowerCase()))) {
      resolvedName = fallbackName.trim();
    }

    if (resolvedName.isEmpty) {
      resolvedName = (fallbackName != null && fallbackName.trim().isNotEmpty)
          ? fallbackName.trim()
          : 'Chauffeur Seddo';
    }

    final vehicleMake = (vehicleRaw['make'] ?? vehicleRaw['brand'] ?? '').toString().trim();
    final vehicleModel = firstNonEmpty([
          vehicleRaw['model'],
          driverRaw['vehicleModel'],
          driverRaw['carModel'],
          json['vehicleModel'],
          json['carModel'],
        ]) ??
        'Toyota Corolla';
    final resolvedCarModel =
        vehicleMake.isNotEmpty && !vehicleModel.startsWith(vehicleMake)
            ? '$vehicleMake $vehicleModel'
            : vehicleModel;

    final resolvedCarColor = firstNonEmpty([
          vehicleRaw['color'],
          vehicleRaw['vehicleColor'],
          vehicleRaw['vehicle_color'],
          vehicleRaw['carColor'],
          vehicleRaw['car_color'],
          vehicleRaw['couleur'],
          vehicleRaw['paint'],
          driverRaw['vehicleColor'],
          driverRaw['vehicle_color'],
          driverRaw['carColor'],
          driverRaw['car_color'],
          driverRaw['color'],
          driverRaw['couleur'],
          json['vehicleColor'],
          json['vehicle_color'],
          json['carColor'],
          json['car_color'],
          json['color'],
          json['couleur'],
          unwrapped['vehicleColor'],
          unwrapped['vehicle_color'],
          unwrapped['carColor'],
          unwrapped['car_color'],
          unwrapped['color'],
          unwrapped['couleur'],
          rawJson['vehicleColor'],
          rawJson['vehicle_color'],
          rawJson['carColor'],
          rawJson['car_color'],
          rawJson['color'],
          rawJson['couleur'],
          if (fallbackCarColor != null &&
              fallbackCarColor.trim().isNotEmpty &&
              fallbackCarColor.trim().toLowerCase() != 'gris' &&
              fallbackCarColor.trim().toLowerCase() != 'grise')
            fallbackCarColor,
        ]) ??
        '';
    final resolvedPlate = firstNonEmpty([
          vehicleRaw['plate'],
          vehicleRaw['licensePlate'],
          vehicleRaw['registrationNumber'],
          driverRaw['licensePlate'],
          driverRaw['plate'],
          json['licensePlate'],
          json['plate'],
        ]) ??
        'DK-4582-AB';

    // Location / Position support (backend returns "position": {"lat": ..., "lng": ..., "heading": ...})
    final posRaw = driverRaw['position'] is Map<String, dynamic>
        ? driverRaw['position'] as Map<String, dynamic>
        : (driverRaw['location'] is Map<String, dynamic>
            ? driverRaw['location'] as Map<String, dynamic>
            : (json['driverPosition'] is Map<String, dynamic>
                ? json['driverPosition'] as Map<String, dynamic>
                : (json['position'] is Map<String, dynamic>
                    ? json['position'] as Map<String, dynamic>
                    : null)));

    double? parseCoord(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final lat = parseCoord(posRaw?['lat'] ??
            posRaw?['latitude'] ??
            driverRaw['lat'] ??
            driverRaw['latitude'] ??
            json['lat'] ??
            json['latitude'] ??
            rawJson['lat']) ??
        14.6937;
    final lng = parseCoord(posRaw?['lng'] ??
            posRaw?['longitude'] ??
            posRaw?['lon'] ??
            driverRaw['lng'] ??
            driverRaw['longitude'] ??
            json['lng'] ??
            json['longitude'] ??
            rawJson['lng']) ??
        -17.4647;
    final heading = parseCoord(posRaw?['heading'] ??
        posRaw?['cap'] ??
        posRaw?['bearing'] ??
        posRaw?['direction'] ??
        driverRaw['heading'] ??
        driverRaw['cap'] ??
        driverRaw['bearing'] ??
        driverRaw['direction'] ??
        json['heading'] ??
        json['cap'] ??
        json['bearing'] ??
        rawJson['heading'] ??
        rawJson['cap'] ??
        rawJson['bearing']);

    // Route & Approach route (phase APPROACH with real street polyline and traffic)
    final routeRaw = json['route'] is Map
        ? Map<String, dynamic>.from(json['route'] as Map)
        : (rawJson['route'] is Map
            ? Map<String, dynamic>.from(rawJson['route'] as Map)
            : null);

    int? parseSec(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      if (v is String) return num.tryParse(v)?.toInt();
      return null;
    }

    final approachPoly = routeRaw?['polyline'] as String? ??
        (json['approachPolyline'] as String?);
    final routeDurS = parseSec(routeRaw?['durationS'] ??
        routeRaw?['etaS'] ??
        routeRaw?['durationSeconds']);
    final rideDurS = parseSec(json['pickupEtaS'] ??
        json['durationS'] ??
        json['durationSeconds'] ??
        rawJson['durationS']);
    final approachDurS = (routeDurS != null && routeDurS > 15)
        ? routeDurS
        : (rideDurS ?? routeDurS);
    final approachDistM = parseSec(routeRaw?['distanceM'] ?? json['distanceM']);

    final rawAppTraffic = (routeRaw?['traffic'] as List<dynamic>? ?? []);
    final appTraffic = rawAppTraffic
        .whereType<Map<String, dynamic>>()
        .map((t) => TrafficSegmentModel.fromJson(t))
        .toList();

    final eta = approachDurS != null && approachDurS > 0
        ? (approachDurS / 60.0).ceil()
        : ((json['etaMinutes'] as num?)?.toInt() ??
            (json['eta'] as num?)?.toInt() ??
            (driverRaw['etaMinutes'] as num?)?.toInt() ??
            3);

    final distKm = approachDistM != null && approachDistM > 0
        ? double.parse((approachDistM / 1000.0).toStringAsFixed(1))
        : ((driverRaw['distanceKm'] as num?)?.toDouble() ??
            (json['distanceKm'] as num?)?.toDouble() ??
            1.2);

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
      photoUrl: firstNonEmpty([
        driverRaw['photoUrl'],
        driverRaw['photo_url'],
        driverRaw['photo'],
        driverRaw['avatar'],
        driverRaw['avatarUrl'],
        driverRaw['avatar_url'],
        driverRaw['profilePicture'],
        driverRaw['profilePictureUrl'],
        driverRaw['image'],
        userRaw['photoUrl'],
        userRaw['photo_url'],
        userRaw['photo'],
        userRaw['avatar'],
        userRaw['avatarUrl'],
        userRaw['avatar_url'],
        userRaw['profilePicture'],
        userRaw['image'],
        json['driverPhotoUrl'],
        json['driver_photo_url'],
        json['driverAvatar'],
        json['driver_avatar'],
        json['driverPhoto'],
        json['photoUrl'],
        json['photo_url'],
        unwrapped['driverPhotoUrl'],
        unwrapped['photoUrl'],
        rawJson['driverPhotoUrl'],
        rawJson['photoUrl'],
        fallbackPhotoUrl,
        if (firstNonEmpty([
              json['id'],
              json['rideId'],
              unwrapped['id'],
              unwrapped['rideId'],
              rawJson['id'],
              rawJson['rideId'],
            ]) !=
            null)
          '/v1/rides/${firstNonEmpty([
                json['id'],
                json['rideId'],
                unwrapped['id'],
                unwrapped['rideId'],
                rawJson['id'],
                rawJson['rideId'],
              ])}/driver/photo',
      ]),
      rating: (driverRaw['rating'] as num?)?.toDouble() ?? 4.9,
      totalRides: (driverRaw['totalRides'] as num?)?.toInt() ?? 1250,
      carModel: resolvedCarModel,
      carColor: resolvedCarColor,
      licensePlate: resolvedPlate,
      rideType: rType,
      currentLocation: LatLng(lat, lng),
      etaMinutes: eta,
      distanceKm: distKm,
      heading: heading,
      approachPolyline: approachPoly,
      approachDurationS: approachDurS,
      approachDistanceM: approachDistM,
      approachTraffic: appTraffic,
    );
  }

  /// Extrait le code de départ à 4 chiffres depuis la réponse de l'API :
  /// Supporte 'startCode', 'code', 'departureCode', 'pin', 'start_code', 'departure_code', 'otp', etc.
  /// Inspecte en profondeur les niveaux imbriqués (data, ride, data.ride, ride.data).
  static String extractDepartureCode(
    Map<String, dynamic> rawJson, {
    String fallback = '4821',
  }) {
    if (rawJson.isEmpty) return fallback;

    // Liste de tous les conteneurs potentiels (à plat, dans data, dans ride, etc.)
    final List<Map<String, dynamic>> mapsToCheck = [];

    void addMap(dynamic m) {
      if (m is Map<String, dynamic> && !mapsToCheck.contains(m)) {
        mapsToCheck.add(m);
      } else if (m is Map && !mapsToCheck.any((existing) => identical(existing, m))) {
        mapsToCheck.add(Map<String, dynamic>.from(m));
      }
    }

    addMap(rawJson);
    if (rawJson['data'] != null) addMap(rawJson['data']);
    if (rawJson['ride'] != null) addMap(rawJson['ride']);
    if (rawJson['data'] is Map && (rawJson['data'] as Map)['ride'] != null) {
      addMap((rawJson['data'] as Map)['ride']);
    }
    if (rawJson['data'] is Map && (rawJson['data'] as Map)['data'] != null) {
      addMap((rawJson['data'] as Map)['data']);
    }
    if (rawJson['ride'] is Map && (rawJson['ride'] as Map)['data'] != null) {
      addMap((rawJson['ride'] as Map)['data']);
    }

    const candidateKeys = [
      'startCode',
      'code',
      'departureCode',
      'start_code',
      'departure_code',
      'pin',
      'pin_code',
      'pickupCode',
      'pickup_code',
      'verificationCode',
      'otp',
    ];

    for (final map in mapsToCheck) {
      for (final key in candidateKeys) {
        final val = map[key];
        if (val != null) {
          final str = val.toString().trim();
          if (str.isNotEmpty && str.toLowerCase() != 'null') {
            return str;
          }
        }
      }
    }

    // Aucun code trouvé dans la réponse API : on retourne le fallback officiel fourni
    // (Ne JAMAIS générer un hash aléatoire côté client, car le chauffeur le rejetterait systématiquement)
    return fallback;
  }
}
