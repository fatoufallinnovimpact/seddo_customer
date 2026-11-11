class TransitTripModel {
  final int id;
  final String tripId;
  final String stopId;
  final String routeId;
  final String serviceId;
  final String tripHeadsign;
  final String tripShortName;
  final String directionId;
  final String shapeId;

  TransitTripModel({
    required this.id,
    required this.tripId,
    required this.stopId,
    required this.routeId,
    required this.serviceId,
    required this.tripHeadsign,
    required this.tripShortName,
    required this.directionId,
    required this.shapeId,
  });

  factory TransitTripModel.fromJson(Map<String, dynamic> json) {
    return TransitTripModel(
      id: json['id'] ?? 0,
      tripId: json['tripId'] ?? '',
      stopId: json['stopId'] ?? '',
      routeId: json['routeId'] ?? '',
      serviceId: json['serviceId'] ?? '',
      tripHeadsign: json['tripHeadsign'] ?? '',
      tripShortName: json['trip_short_name'] ?? '',
      directionId: json['directionId'] ?? '',
      shapeId: json['shapeId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'stopId': stopId,
      'routeId': routeId,
      'serviceId': serviceId,
      'tripHeadsign': tripHeadsign,
      'trip_short_name': tripShortName,
      'directionId': directionId,
      'shapeId': shapeId,
    };
  }

  static List<TransitTripModel> fromJsonList(List<dynamic> list) {
    return list.map((item) => TransitTripModel.fromJson(item)).toList();
  }
}
