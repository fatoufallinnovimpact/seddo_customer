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
  final String? kind; // 'HOME', 'WORK', 'OTHER'
  final DateTime? createdAt;

  const SavedPlaceModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.iconType = 'star',
    this.kind,
    this.createdAt,
  });

  /// Map UI icon and name to backend enum ("HOME" | "WORK" | "OTHER")
  static String kindFromIconAndName({
    required String iconType,
    required String name,
  }) {
    final normIcon = iconType.trim().toLowerCase();
    final normName = name.trim().toLowerCase();

    if (normIcon == 'home' || normName == 'maison' || normName.startsWith('maison')) {
      return 'HOME';
    }
    if (normIcon == 'work' || normName == 'travail' || normName == 'bureau') {
      return 'WORK';
    }
    return 'OTHER';
  }

  /// Map backend kind and label to UI icon ('home', 'work', 'airport', 'gym', 'heart', 'star')
  static String iconTypeFromKindAndLabel({
    required String? kind,
    required String? label,
  }) {
    final normKind = (kind ?? '').trim().toUpperCase();
    final normLabel = (label ?? '').trim().toLowerCase();

    if (normKind == 'HOME' || normLabel == 'maison') {
      return 'home';
    }
    if (normKind == 'WORK' || normLabel == 'travail' || normLabel == 'bureau') {
      return 'work';
    }
    if (normLabel.contains('aéroport') ||
        normLabel.contains('aeroport') ||
        normLabel.contains('aibd')) {
      return 'airport';
    }
    if (normLabel.contains('sport') || normLabel.contains('gym')) {
      return 'gym';
    }
    if (normLabel.contains('maman') ||
        normLabel.contains('famille') ||
        normLabel.contains('cœur') ||
        normLabel.contains('coeur')) {
      return 'heart';
    }
    return 'star';
  }

  SavedPlaceModel copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? iconType,
    String? kind,
    DateTime? createdAt,
  }) {
    return SavedPlaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      iconType: iconType ?? this.iconType,
      kind: kind ?? this.kind,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Format required by POST /v1/users/me/places
  Map<String, dynamic> toApiJson() {
    final resolvedKind =
        kind ?? kindFromIconAndName(iconType: iconType, name: name);
    return {
      'kind': resolvedKind,
      'label': name,
      'address': address,
      'lat': latitude,
      'lng': longitude,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'label': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'lat': latitude,
      'lng': longitude,
      'iconType': iconType,
      'kind': kind,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory SavedPlaceModel.fromJson(Map<String, dynamic> json) {
    final rawKind = (json['kind'] as String?)?.toUpperCase();
    final nameVal = (json['label'] ?? json['name'] ?? 'Lieu') as String;
    final addressVal = (json['address'] ?? '') as String;
    final latVal = (json['lat'] ?? json['latitude']) as num? ?? 0.0;
    final lngVal = (json['lng'] ?? json['longitude']) as num? ?? 0.0;
    final idVal = (json['id'] ?? '').toString();

    final derivedKind = rawKind ??
        kindFromIconAndName(
          iconType: json['iconType'] as String? ?? 'star',
          name: nameVal,
        );

    final derivedIcon = json['iconType'] as String? ??
        iconTypeFromKindAndLabel(kind: derivedKind, label: nameVal);

    return SavedPlaceModel(
      id: idVal,
      name: nameVal,
      address: addressVal,
      latitude: latVal.toDouble(),
      longitude: lngVal.toDouble(),
      iconType: derivedIcon,
      kind: derivedKind,
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
        kind,
        createdAt,
      ];
}
