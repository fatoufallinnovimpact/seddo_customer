import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/services/route_service.dart';

/// Individual vehicle category quote option returned by POST /v1/rides/quote
class RideQuoteOptionModel {
  final String quoteId;
  final String category; // 'ECO', 'CONFORT', etc.
  final String name; // 'Seddo Eco', etc.
  final int seats;
  final int price;
  final String currency; // 'XOF'
  final num? surge;
  final num? airportFee;
  final num? bookingFee;
  final num? zoneFee;
  final int? pickupEtaS;

  const RideQuoteOptionModel({
    required this.quoteId,
    required this.category,
    required this.name,
    required this.seats,
    required this.price,
    this.currency = 'XOF',
    this.surge,
    this.airportFee,
    this.bookingFee,
    this.zoneFee,
    this.pickupEtaS,
  });

  factory RideQuoteOptionModel.fromJson(Map<String, dynamic> json) {
    return RideQuoteOptionModel(
      quoteId: json['quoteId'] as String? ?? '',
      category: json['category'] as String? ?? 'ECO',
      name: json['name'] as String? ?? 'Seddo Eco',
      seats: (json['seats'] as num?)?.toInt() ?? 4,
      price: (json['price'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'XOF',
      surge: json['surge'] as num?,
      airportFee: json['airportFee'] as num?,
      bookingFee: json['bookingFee'] as num?,
      zoneFee: json['zoneFee'] as num?,
      pickupEtaS: (json['pickupEtaS'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'quoteId': quoteId,
    'category': category,
    'name': name,
    'seats': seats,
    'price': price,
    'currency': currency,
    'surge': surge,
    'airportFee': airportFee,
    'bookingFee': bookingFee,
    'zoneFee': zoneFee,
    'pickupEtaS': pickupEtaS,
  };
}

/// Data model representing the guaranteed quote response from POST /v1/rides/quote.
/// Contains road distance, duration, encoded polyline for Dakar road network, and options.
class RideQuoteModel {
  final int distanceM;
  final int durationS;
  final String? routeSource;
  final int? trafficDelayS;
  final String polyline;
  final String? zone;
  final DateTime? expiresAt;
  final int? pickupEtaS;
  final String? paymentMethod;
  final List<RideQuoteOptionModel> options;

  const RideQuoteModel({
    required this.distanceM,
    required this.durationS,
    this.routeSource,
    this.trafficDelayS,
    required this.polyline,
    this.zone,
    this.expiresAt,
    this.pickupEtaS,
    this.paymentMethod,
    required this.options,
  });

  /// Distance in kilometers rounded to 2 decimals
  double get distanceKm =>
      double.parse((distanceM / 1000.0).toStringAsFixed(2));

  /// Duration in minutes (rounded)
  int get durationMinutes => (durationS / 60.0).round().clamp(1, 300);

  /// Decodes the encoded polyline string from the backend into road-following LatLng coordinates
  List<LatLng> get decodedPolyline {
    if (polyline.isEmpty) return const [];
    try {
      return RouteService.decodePolyline(polyline);
    } catch (_) {
      return const [];
    }
  }

  /// Finds the ECO category option
  RideQuoteOptionModel? get ecoOption {
    try {
      return options.firstWhere(
        (o) => o.category.toUpperCase() == 'ECO',
      );
    } catch (_) {
      return options.isNotEmpty ? options.first : null;
    }
  }

  /// Finds the CONFORT category option (if available from backend)
  RideQuoteOptionModel? get confortOption {
    try {
      return options.firstWhere(
        (o) =>
            o.category.toUpperCase() == 'CONFORT' ||
            o.category.toUpperCase() == 'COMFORT',
      );
    } catch (_) {
      return null;
    }
  }

  factory RideQuoteModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? [];
    return RideQuoteModel(
      distanceM: (json['distanceM'] as num?)?.toInt() ?? 0,
      durationS: (json['durationS'] as num?)?.toInt() ?? 0,
      routeSource: json['routeSource'] as String?,
      trafficDelayS: (json['trafficDelayS'] as num?)?.toInt(),
      polyline: json['polyline'] as String? ?? '',
      zone: json['zone'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      pickupEtaS: (json['pickupEtaS'] as num?)?.toInt(),
      paymentMethod: json['paymentMethod'] as String?,
      options: rawOptions
          .map((item) =>
              RideQuoteOptionModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'distanceM': distanceM,
    'durationS': durationS,
    'routeSource': routeSource,
    'trafficDelayS': trafficDelayS,
    'polyline': polyline,
    'zone': zone,
    'expiresAt': expiresAt?.toIso8601String(),
    'pickupEtaS': pickupEtaS,
    'paymentMethod': paymentMethod,
    'options': options.map((e) => e.toJson()).toList(),
  };
}
