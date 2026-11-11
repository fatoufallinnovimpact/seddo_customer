// ignore_for_file: unused_element

class StopTimeTripUpdate {
  final int id;
  final String stopId;
  final String tripId;
  final int arrivalTime;
  final int arrivalDelay;
  final int departureTime;
  final int departureDelay;
  final String routeId;
  final String startTime;
  final String startDate;
  final int directionId;
  final String scheduleRelationship;

  StopTimeTripUpdate({
    required this.id,
    required this.stopId,
    required this.tripId,
    required this.arrivalTime,
    required this.arrivalDelay,
    required this.departureTime,
    required this.departureDelay,
    required this.routeId,
    required this.startTime,
    required this.startDate,
    required this.directionId,
    required this.scheduleRelationship,
  });

  /// Factory method to create a StopTimeTripUpdate from a JSON object
  factory StopTimeTripUpdate.fromJson(Map<String, dynamic> map) {
    return StopTimeTripUpdate(
      id: map['id'] ?? 0,
      stopId: map['stopId'] ?? '',
      tripId: map['tripId'] ?? '',
      arrivalTime: map['arrivalTime'] ?? 0,
      arrivalDelay: map['arrivalDelay'] ?? 0,
      departureTime: map['departureTime'] ?? 0,
      departureDelay: map['departureDelay'] ?? 0,
      routeId: map['routeId'] ?? '',
      startTime: map['startTime'] ?? '',
      startDate: map['startDate'] ?? '',
      directionId: map['directionId'] ?? 0,
      scheduleRelationship: map['scheduleRelationship'] ?? 'SCHEDULED',
    );
  }

  /// Convert the object to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stopId': stopId,
      'tripId': tripId,
      'arrivalTime': arrivalTime,
      'arrivalDelay': arrivalDelay * 60,
      // Convert back to seconds if needed
      'departureTime': departureTime,
      'departureDelay': departureDelay * 60,
      // Convert back to seconds if needed
      'routeId': routeId,
      'startTime': startTime,
      'startDate': startDate,
      'directionId': directionId,
      'scheduleRelationship': scheduleRelationship,
    };
  }

  /// Convert a list of JSON objects into a list of StopTimeTripUpdate instances
  static List<StopTimeTripUpdate> fromJsonList(List<dynamic> list) {
    return list.map((item) => StopTimeTripUpdate.fromJson(item)).toList();
  }

  /// Function to convert delay from seconds to minutes, handling positive and negative values.
  static int _convertDelayToMinutes(int delayInSeconds) {
    return delayInSeconds.isNegative
        ? (delayInSeconds / 60).floor()
        : (delayInSeconds / 60).ceil();
  }
}
