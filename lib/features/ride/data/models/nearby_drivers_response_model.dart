import 'dart:math' as math;
import 'package:equatable/equatable.dart';

/// Represents a single car position returned by GET /v1/drivers/nearby.
class NearbyCarModel extends Equatable {
  final String id;
  final double lat;
  final double lng;
  final double heading;

  const NearbyCarModel({
    required this.id,
    required this.lat,
    required this.lng,
    this.heading = 0.0,
  });

  NearbyCarModel copyWith({
    String? id,
    double? lat,
    double? lng,
    double? heading,
  }) {
    return NearbyCarModel(
      id: id ?? this.id,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      heading: heading ?? this.heading,
    );
  }

  /// Deduplicates cars by ID and separates any cars whose coordinates are
  /// too close together so that car markers never overlap on the map.
  static List<NearbyCarModel> separateOverlappingCars(
    List<NearbyCarModel> rawCars, {
    double minSeparationDegrees = 0.00055,
  }) {
    if (rawCars.length <= 1) return rawCars;

    // 1. Deduplicate by driver/car ID when an explicit ID is provided
    final List<NearbyCarModel> uniqueCars = [];
    final Set<String> seenExplicitIds = <String>{};

    for (final car in rawCars) {
      if (car.lat == 0.0 && car.lng == 0.0) continue;
      final isCoordBasedId =
          car.id.isEmpty || car.id == 'unknown' || car.id.startsWith('car_');
      if (!isCoordBasedId) {
        if (seenExplicitIds.contains(car.id)) {
          continue;
        }
        seenExplicitIds.add(car.id);
      }
      uniqueCars.add(car);
    }

    if (uniqueCars.length <= 1) return uniqueCars;

    // 2. Ensure minimum visual separation between every pair of cars on the map
    final List<NearbyCarModel> placed = [];
    final double minDistSq = minSeparationDegrees * minSeparationDegrees;

    for (int i = 0; i < uniqueCars.length; i++) {
      final current = uniqueCars[i];
      double candidateLat = current.lat;
      double candidateLng = current.lng;
      double candidateHeading = current.heading;

      int attempt = 0;
      while (attempt < 16) {
        bool overlaps = false;
        for (final other in placed) {
          final dLat = candidateLat - other.lat;
          final dLng = candidateLng - other.lng;
          if ((dLat * dLat + dLng * dLng) < minDistSq) {
            overlaps = true;
            break;
          }
        }
        if (!overlaps) break;

        attempt++;
        final int ring = ((attempt - 1) ~/ 6) + 1;
        final double angle =
            (i * 1.0471975512) + (attempt * 2.399963229728653); // Golden angle
        final double radius = minSeparationDegrees * 1.15 * ring;
        candidateLat = current.lat + radius * math.cos(angle);
        candidateLng = current.lng + radius * math.sin(angle);
        if (candidateHeading == 0.0) {
          candidateHeading = (angle * 180.0 / math.pi) % 360.0;
        }
      }

      placed.add(
        current.copyWith(
          lat: candidateLat,
          lng: candidateLng,
          heading: candidateHeading,
        ),
      );
    }

    return placed;
  }

  factory NearbyCarModel.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      final latVal = (json['lat'] ?? json['latitude']) as num? ?? 0.0;
      final lngVal =
          (json['lng'] ?? json['longitude'] ?? json['lon']) as num? ?? 0.0;
      final headingVal =
          (json['heading'] ?? json['bearing'] ?? json['rotation'] ?? 0.0)
              as num;
      final idVal =
          (json['id'] ?? json['driverId'] ?? 'car_${latVal}_$lngVal').toString();
      return NearbyCarModel(
        id: idVal,
        lat: latVal.toDouble(),
        lng: lngVal.toDouble(),
        heading: headingVal.toDouble(),
      );
    } else if (json is List && json.length >= 2) {
      final latVal = (json[0] as num).toDouble();
      final lngVal = (json[1] as num).toDouble();
      return NearbyCarModel(
        id: 'car_${latVal}_$lngVal',
        lat: latVal,
        lng: lngVal,
      );
    }
    return const NearbyCarModel(id: 'unknown', lat: 0, lng: 0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': lat,
        'lng': lng,
        'heading': heading,
      };

  @override
  List<Object?> get props => [id, lat, lng, heading];
}

/// Category entry inside categories array from GET /v1/drivers/nearby (e.g. ECO, CONFORT).
class NearbyCategoryModel extends Equatable {
  final String category;
  final int count;
  final int? etaS;
  final List<NearbyCarModel> cars;

  const NearbyCategoryModel({
    required this.category,
    required this.count,
    this.etaS,
    required this.cars,
  });

  int? get etaMinutes =>
      etaS != null ? (etaS! / 60.0).round().clamp(1, 60) : null;

  factory NearbyCategoryModel.fromJson(Map<String, dynamic> json) {
    final rawCars = json['cars'] as List<dynamic>? ?? [];
    return NearbyCategoryModel(
      category: (json['category'] as String?)?.toUpperCase() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      etaS: (json['etaS'] as num?)?.toInt(),
      cars: rawCars.map((c) => NearbyCarModel.fromJson(c)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'count': count,
        'etaS': etaS,
        'cars': cars.map((c) => c.toJson()).toList(),
      };

  @override
  List<Object?> get props => [category, count, etaS, cars];
}

/// Response model for GET /v1/drivers/nearby?lat={lat}&lng={lng}.
/// Contains search radius and categories (ECO, CONFORT) with real counts, ETAs and car coordinates.
class NearbyDriversResponseModel extends Equatable {
  final int radiusM;
  final List<NearbyCategoryModel> categories;

  const NearbyDriversResponseModel({
    required this.radiusM,
    required this.categories,
  });

  NearbyCategoryModel? get ecoCategory {
    try {
      return categories.firstWhere(
        (c) => c.category.toUpperCase() == 'ECO',
      );
    } catch (_) {
      return null;
    }
  }

  NearbyCategoryModel? get confortCategory {
    try {
      return categories.firstWhere(
        (c) =>
            c.category.toUpperCase() == 'CONFORT' ||
            c.category.toUpperCase() == 'COMFORT',
      );
    } catch (_) {
      return null;
    }
  }

  int get ecoCount => ecoCategory?.count ?? 0;
  int get confortCount => confortCategory?.count ?? 0;
  int? get ecoEtaMinutes =>
      ecoCategory != null && ecoCategory!.count > 0 ? ecoCategory!.etaMinutes : null;
  int? get confortEtaMinutes =>
      confortCategory != null && confortCategory!.count > 0
          ? confortCategory!.etaMinutes
          : null;

  List<NearbyCarModel> get ecoCars =>
      NearbyCarModel.separateOverlappingCars(ecoCategory?.cars ?? []);
  List<NearbyCarModel> get confortCars =>
      NearbyCarModel.separateOverlappingCars(confortCategory?.cars ?? []);
  List<NearbyCarModel> get allCars => NearbyCarModel.separateOverlappingCars([
        ...(ecoCategory?.cars ?? []),
        ...(confortCategory?.cars ?? []),
      ]);
  int get totalCount => ecoCount + confortCount;

  factory NearbyDriversResponseModel.fromJson(Map<String, dynamic> json) {
    final effectiveJson = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;

    final rawCats = effectiveJson['categories'] as List<dynamic>?;
    List<NearbyCategoryModel> parsedCategories = [];
    if (rawCats != null && rawCats.isNotEmpty) {
      parsedCategories = rawCats
          .whereType<Map<String, dynamic>>()
          .map((c) => NearbyCategoryModel.fromJson(c))
          .toList();
    } else {
      final flatCars = (effectiveJson['cars'] ??
              effectiveJson['drivers'] ??
              effectiveJson['nearbyDrivers'] ??
              effectiveJson['vehicles'] ??
              (json['data'] is List ? json['data'] : null)) as List<dynamic>?;
      if (flatCars != null && flatCars.isNotEmpty) {
        final carsList =
            flatCars.map((c) => NearbyCarModel.fromJson(c)).toList();
        parsedCategories = [
          NearbyCategoryModel(
            category: 'ECO',
            count: carsList.length,
            cars: carsList,
          ),
        ];
      }
    }
    return NearbyDriversResponseModel(
      radiusM: (effectiveJson['radiusM'] as num?)?.toInt() ?? 3000,
      categories: parsedCategories,
    );
  }

  Map<String, dynamic> toJson() => {
        'radiusM': radiusM,
        'categories': categories.map((c) => c.toJson()).toList(),
      };

  @override
  List<Object?> get props => [radiusM, categories];
}
