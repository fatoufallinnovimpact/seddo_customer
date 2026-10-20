/// Type of ride option
enum RideType { eco, confort }

/// Data model representing a ride option with pricing and estimation
class RideOptionModel {
  final RideType type;
  final String title;
  final String subtitle;
  final int capacity;
  final int price;
  final String currency;
  final String estimatedArrival;
  final String pickupDuration;

  const RideOptionModel({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.capacity,
    required this.price,
    this.currency = 'F',
    required this.estimatedArrival,
    required this.pickupDuration,
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
    );
  }
}
