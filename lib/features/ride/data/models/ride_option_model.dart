import 'package:seddo/features/ride/data/models/ride_quote_model.dart';

/// Type of ride option
enum RideType { eco, confort }

/// Data model representing a ride option with pricing and estimation.
/// Follows Innov & Impact Africa guidelines (data/models/).
class RideOptionModel {
  final RideType type;
  final String title;
  final String subtitle;
  final int capacity;
  final int price;
  final String currency;
  final String estimatedArrival;
  final String pickupDuration;
  final String? quoteId;
  final int? pickupEtaS;
  final List<TrafficSegmentModel> traffic;
  final int? distanceM;
  final int? durationS;

  const RideOptionModel({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.capacity,
    required this.price,
    this.currency = 'F',
    required this.estimatedArrival,
    required this.pickupDuration,
    this.quoteId,
    this.pickupEtaS,
    this.traffic = const [],
    this.distanceM,
    this.durationS,
  });

  /// Formats the integer price into a clean localized string like "3 500 F"
  String get formattedPrice {
    final str = price.toString();
    if (str.length > 3) {
      final prefix = str.substring(0, str.length - 3);
      final suffix = str.substring(str.length - 3);
      return '$prefix $suffix $currency';
    }
    return '$price $currency';
  }

  RideOptionModel copyWith({
    RideType? type,
    String? title,
    String? subtitle,
    int? capacity,
    int? price,
    String? currency,
    String? estimatedArrival,
    String? pickupDuration,
    String? quoteId,
    int? pickupEtaS,
    List<TrafficSegmentModel>? traffic,
    int? distanceM,
    int? durationS,
  }) {
    return RideOptionModel(
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      capacity: capacity ?? this.capacity,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      pickupDuration: pickupDuration ?? this.pickupDuration,
      quoteId: quoteId ?? this.quoteId,
      pickupEtaS: pickupEtaS ?? this.pickupEtaS,
      traffic: traffic ?? this.traffic,
      distanceM: distanceM ?? this.distanceM,
      durationS: durationS ?? this.durationS,
    );
  }
}
