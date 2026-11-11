// ignore_for_file: file_names

class StopTimeModel {
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

  StopTimeModel({
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

  factory StopTimeModel.fromJson(Map<String, dynamic> map) {
    return StopTimeModel(
      tripId: map['trip_id'] ?? "",
      arrivalTime: map['arrivalTime'] ?? "",
      departureTime: map['departureTime'] ?? "",
      stopId: map['stop_id'] ?? "",
      stopSequence: map['stop_sequence'].toString(),
      stopHeadsign: map['stop_headsign'] ?? "",
      pickupType: map['pickup_type'].toString(),
      dropOffType: map['drop_off_type'].toString(),
      shapeDistTraveled: map['shape_dist_traveled'].toString(),
      timepoint: map['timepoint'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trip_id': tripId,
      'arrival_time': arrivalTime,
      'departure_time': departureTime,
      'stop_id': stopId,
      'stop_sequence': stopSequence,
      'stop_headsign': stopHeadsign,
      'pickup_type': pickupType,
      'drop_off_type': dropOffType,
      'shape_dist_traveled': shapeDistTraveled,
      'timepoint': timepoint,
    };
  }

  static List<StopTimeModel> fromJsonList(List<dynamic> list) {
    return list.map((item) => StopTimeModel.fromJson(item)).toList();
  }
}
