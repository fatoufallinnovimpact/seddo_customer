class TransitStopTimeModel {
  final int id;
  final String tripId;
  final String arrivalTime;
  final String departureTime;
  final String stopId;
  final String stopSequence;
  final String stopHeadsign;
  final String pickupType;
  final String dropOffType;
  final String shapeDistTraveled;
  final String timepoint;

  TransitStopTimeModel({
    required this.id,
    required this.tripId,
    required this.arrivalTime,
    required this.departureTime,
    required this.stopId,
    required this.stopSequence,
    required this.stopHeadsign,
    required this.pickupType,
    required this.dropOffType,
    required this.shapeDistTraveled,
    required this.timepoint,
  });

  factory TransitStopTimeModel.fromJson(Map<String, dynamic> json) {
    return TransitStopTimeModel(
      id: json['id'] ?? 0,
      tripId: json['tripId'] ?? '',
      arrivalTime: json['arrivalTime'] ?? '',
      departureTime: json['departureTime'] ?? '',
      stopId: json['stopId'] ?? '',
      stopSequence: json['stop_sequence'] ?? '',
      stopHeadsign: json['stopHeadsign'] ?? '',
      pickupType: json['pickup_type'] ?? '',
      dropOffType: json['drop_off_type'] ?? '',
      shapeDistTraveled: json['shape_dist_traveled'] ?? '',
      timepoint: json['timepoint'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'arrivalTime': arrivalTime,
      'departureTime': departureTime,
      'stopId': stopId,
      'stop_sequence': stopSequence,
      'stopHeadsign': stopHeadsign,
      'pickup_type': pickupType,
      'drop_off_type': dropOffType,
      'shape_dist_traveled': shapeDistTraveled,
      'timepoint': timepoint,
    };
  }

  static List<TransitStopTimeModel> fromJsonList(List<dynamic> list) {
    return list.map((item) => TransitStopTimeModel.fromJson(item)).toList();
  }
}
