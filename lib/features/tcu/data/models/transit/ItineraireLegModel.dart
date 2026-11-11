import 'TransitStopModel.dart';
import 'TransitStopTimeModel.dart';
import 'TransitTripModel.dart';
import 'TransitRoute.dart';
import 'TransitResponseModel.dart';

/// Représente un leg (un bus) dans un itinéraire
class ItineraireLegModel {
  final TransitTripModel? trip;
  final TransitRoute? route;
  final TransitStopModel? stopStart;
  final TransitStopModel? stopEnd;
  final TransitStopTimeModel? departureStopTime;
  final TransitStopTimeModel? destinationStopTime;
  final List<TransitResponseInterModel> intermediateStops;
  final double walkingDistanceToBoardingStop;
  final double walkingDistanceFromAlightingStop;
  final int? trafficDurationSeconds;

  ItineraireLegModel({
    this.trip,
    this.route,
    this.stopStart,
    this.stopEnd,
    this.departureStopTime,
    this.destinationStopTime,
    this.intermediateStops = const [],
    this.walkingDistanceToBoardingStop = 0,
    this.walkingDistanceFromAlightingStop = 0,
    this.trafficDurationSeconds,
  });

  factory ItineraireLegModel.fromJson(Map<String, dynamic> json) {
    return ItineraireLegModel(
      trip:
          json['trip'] != null ? TransitTripModel.fromJson(json['trip']) : null,
      route:
          json['route'] != null ? TransitRoute.fromJson(json['route']) : null,
      stopStart:
          json['stopStart'] != null
              ? TransitStopModel.fromJson(json['stopStart'])
              : null,
      stopEnd:
          json['stopEnd'] != null
              ? TransitStopModel.fromJson(json['stopEnd'])
              : null,
      departureStopTime:
          json['departureStopTime'] != null
              ? TransitStopTimeModel.fromJson(json['departureStopTime'])
              : null,
      destinationStopTime:
          json['destinationStopTime'] != null
              ? TransitStopTimeModel.fromJson(json['destinationStopTime'])
              : null,
      intermediateStops:
          json['intermediateStops'] != null
              ? (json['intermediateStops'] as List)
                  .map(
                    (e) => TransitResponseInterModel.fromJson({
                      'stop': e['stop'],
                      'stopTime': e['stopTime'],
                    }),
                  )
                  .toList()
              : [],
      walkingDistanceToBoardingStop:
          (json['walkingDistanceToBoardingStopMeters'] ??
                  json['walkingDistanceToBoardingStop'] ??
                  0)
              .toDouble(),
      walkingDistanceFromAlightingStop:
          (json['walkingDistanceFromAlightingStopMeters'] ??
                  json['walkingDistanceFromAlightingStop'] ??
                  0)
              .toDouble(),
      trafficDurationSeconds: json['trafficDurationSeconds'],
    );
  }

  /// Type de transport pour afficher la bonne image
  String get transitType => stopStart?.transitType ?? 'BUS';

  /// Durée trafic en minutes
  String get trafficDurationFormatted {
    if (trafficDurationSeconds == null) return '';
    final minutes = (trafficDurationSeconds! / 60).round();
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  /// Distance de marche vers l'arrêt formatée
  String get walkingToBoardingFormatted {
    if (walkingDistanceToBoardingStop < 1000) {
      return '${walkingDistanceToBoardingStop.round()} m';
    }
    return '${(walkingDistanceToBoardingStop / 1000).toStringAsFixed(1)} km';
  }
}

/// Représente un itinéraire complet (1 ou plusieurs bus)
class ItineraireModel {
  final List<ItineraireLegModel> legs;
  final bool isDirect;
  final int totalLegs;
  final int totalTrafficDurationSeconds;
  final double score;
  final String label;

  ItineraireModel({
    required this.legs,
    required this.isDirect,
    required this.totalLegs,
    required this.totalTrafficDurationSeconds,
    required this.score,
    required this.label,
  });

  factory ItineraireModel.fromJson(Map<String, dynamic> json) {
    final legs =
        (json['legs'] as List)
            .map((e) => ItineraireLegModel.fromJson(e))
            .toList();
    return ItineraireModel(
      legs: legs,
      isDirect: json['direct'] ?? json['isDirect'] ?? legs.length == 1,
      totalLegs: json['totalLegs'] ?? legs.length,
      totalTrafficDurationSeconds: json['totalTrafficDurationSeconds'] ?? 0,
      score: (json['score'] ?? 0).toDouble(),
      label: json['label'] ?? '',
    );
  }

  /// Nom original selon position dans la liste
  static String nameForIndex(int index, bool isDirect) {
    const names = ['🚀 Plus rapide', '🔄 Alternative', '🗺️ Panoramique'];
    if (index < names.length) return names[index];
    return 'Itinéraire ${index + 1}';
  }

  /// Durée totale formatée
  String get totalDurationFormatted {
    final minutes = (totalTrafficDurationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}';
  }
}
