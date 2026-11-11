// ignore_for_file: file_names

import 'RouteModel.dart';
import 'Stop.dart';
import 'StopTime.dart';

import 'StopTimeTripUpdate.dart';
import 'TripModel.dart';

class StopTimeResponseModel {
  final RouteModel route;
  final StopTimeModel? stopTime;
  final StopModel? stop;
  final StopTimeTripUpdate? stopTimeTripUpdate;
  final TripModel trip;
  final String distance;
  final String duration;
  final bool end;

  StopTimeResponseModel({
    required this.route,
    required this.stopTime,
    required this.trip,
    required this.distance,
    required this.duration,
    required this.end,
    required this.stopTimeTripUpdate,
    required this.stop,
  });

  factory StopTimeResponseModel.fromJson(Map<String, dynamic> map) {
    return StopTimeResponseModel(
      route: RouteModel.fromJson(map['route']),
      trip: TripModel.fromJson(map['trip']),
      stopTime:
          map['stopTime'] != null
              ? StopTimeModel.fromJson(map['stopTime'])
              : null,
      stopTimeTripUpdate:
          map["stopTimeUpdate"] != null
              ? StopTimeTripUpdate.fromJson(map["stopTimeUpdate"])
              : null,
      distance: map['distance'].toString(),
      duration: map['duration'].toString(),
      end: map['end'],
      stop: map['stop'] != null ? StopModel.fromJson(map['stop']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route': route,
      'stopTime': stopTime,
      'trip': trip,
      'stopTimeTripUpdate': stopTimeTripUpdate,
      'stop': stop,
      'distance': distance,
      'duration': duration,
      'end': end,
    };
  }

  static List<StopTimeResponseModel> fromJsonList(List<dynamic> list) {
    return list.map((item) => StopTimeResponseModel.fromJson(item)).toList();
  }
}
