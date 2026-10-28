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

  List<NearbyCarModel> get ecoCars => ecoCategory?.cars ?? [];
  List<NearbyCarModel> get confortCars => confortCategory?.cars ?? [];
  List<NearbyCarModel> get allCars => [...ecoCars, ...confortCars];

  factory NearbyDriversResponseModel.fromJson(Map<String, dynamic> json) {
    final rawCats = json['categories'] as List<dynamic>? ?? [];
    return NearbyDriversResponseModel(
      radiusM: (json['radiusM'] as num?)?.toInt() ?? 3000,
      categories: rawCats
          .map((c) => NearbyCategoryModel.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'radiusM': radiusM,
        'categories': categories.map((c) => c.toJson()).toList(),
      };

  @override
  List<Object?> get props => [radiusM, categories];
}
