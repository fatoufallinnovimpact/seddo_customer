class TripModel {
  final int? id;
  final String tripId;
  final String stopId;
  final String routeId;
  final String serviceId;
  final String tripHeadsign;
  final String tripShortName;
  final String directionId;

  TripModel({
    this.id,
    required this.tripId,
    required this.stopId,
    required this.routeId,
    required this.serviceId,
    required this.tripHeadsign,
    required this.tripShortName,
    required this.directionId,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] ?? "",
      tripId: json['trip_id'] ?? "",
      stopId: json['stop_id'] ?? "",
      routeId: json['route_id'] ?? "",
      serviceId: json['service_id'] ?? "",
      tripHeadsign: json['trip_headsign'] ?? "",
      tripShortName: json['trip_short_name'] ?? "",
      directionId: json['direction_id'] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'stop_id': stopId,
      'route_id': routeId,
      'service_id': serviceId,
      'trip_headsign': tripHeadsign,
      'trip_short_name': tripShortName,
      'direction_id': directionId,
    };
  }

  static List<TripModel> fromJsonList(List<dynamic> list) {
    return list.map((item) => TripModel.fromJson(item)).toList();
  }
}
