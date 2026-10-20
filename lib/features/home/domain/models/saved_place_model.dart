import 'package:equatable/equatable.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';

/// Represents a persistent user-saved favorite location (Maison, Travail, etc.)
class SavedPlaceModel extends Equatable {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String iconType; // 'home', 'work', 'star', 'airport', 'heart', 'gym'
  final DateTime? createdAt;

  const SavedPlaceModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.iconType = 'star',
    this.createdAt,
  });

  SavedPlaceModel copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? iconType,
    DateTime? createdAt,
  }) {
    return SavedPlaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      iconType: iconType ?? this.iconType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'iconType': iconType,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory SavedPlaceModel.fromJson(Map<String, dynamic> json) {
    return SavedPlaceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      iconType: json['iconType'] as String? ?? 'star',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  PlaceSearchResult toPlaceSearchResult() {
    return PlaceSearchResult(
      id: id,
      mainText: name,
      secondaryText: address,
      fullAddress: address,
      latitude: latitude,
      longitude: longitude,
      category: 'saved_place',
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        address,
        latitude,
        longitude,
        iconType,
        createdAt,
      ];
}
