import 'package:equatable/equatable.dart';

/// Represents a place or address autocomplete search result in Dakar
class PlaceSearchResult extends Equatable {
  final String id;
  final String mainText;
  final String secondaryText;
  final String fullAddress;
  final double latitude;
  final double longitude;
  final String category; // 'neighborhood', 'landmark', 'transport', 'popular'

  const PlaceSearchResult({
    required this.id,
    required this.mainText,
    required this.secondaryText,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
    this.category = 'neighborhood',
  });

  @override
  List<Object?> get props => [
        id,
        mainText,
        secondaryText,
        fullAddress,
        latitude,
        longitude,
        category,
      ];
}
