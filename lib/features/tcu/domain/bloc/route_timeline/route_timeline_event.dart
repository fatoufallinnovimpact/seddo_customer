part of 'route_timeline_bloc.dart';

abstract class RouteTimelineEvent extends Equatable {
  const RouteTimelineEvent();

  @override
  List<Object> get props => [];
}

class RouteTimelineInitialized extends RouteTimelineEvent {
  final PlaceModel? fromPlaceDetails;
  final PlaceModel? toPlaceDetails;
  final StopTimeResponseModel? stopTimeResponse;
  final int index;
  final String date;
  final String time;

  const RouteTimelineInitialized({
    this.fromPlaceDetails,
    this.toPlaceDetails,
    this.stopTimeResponse,
    this.index = 0,
    this.date = "",
    this.time = "",
  });

  @override
  List<Object> get props => [
    fromPlaceDetails ?? '',
    toPlaceDetails ?? '',
    stopTimeResponse ?? '',
    index,
    date,
    time,
  ];
}

class RouteTimelineDepartureDataRequested extends RouteTimelineEvent {
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;
  final int maxDistanceFrom;
  final int maxDistanceTo;

  const RouteTimelineDepartureDataRequested({
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    required this.maxDistanceFrom,
    required this.maxDistanceTo,
  });

  @override
  List<Object> get props => [
    startLat,
    startLon,
    endLat,
    endLon,
    maxDistanceFrom,
    maxDistanceTo,
  ];
}
/*
class RouteTimelineFilterChanged extends RouteTimelineEvent {
  final Filter selectedFilter;

  const RouteTimelineFilterChanged(this.selectedFilter);

  @override
  List<Object> get props => [selectedFilter];
}*/

class RouteTimelineCurrentPositionUpdated extends RouteTimelineEvent {
  final Position position;

  const RouteTimelineCurrentPositionUpdated(this.position);

  @override
  List<Object> get props => [position];
}

class RouteTimelineDispose extends RouteTimelineEvent {
  const RouteTimelineDispose();

  @override
  List<Object> get props => [];
}

class RouteTimelineTabChanged extends RouteTimelineEvent {
  final int index;
  const RouteTimelineTabChanged(this.index);
}
