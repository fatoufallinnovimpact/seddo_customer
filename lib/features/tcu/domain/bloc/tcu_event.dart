import 'package:equatable/equatable.dart';
import 'package:seddo/features/tcu/data/models/tcu_route_model.dart';

abstract class TcuEvent extends Equatable {
  const TcuEvent();

  @override
  List<Object?> get props => [];
}

class TcuLoadRoutesEvent extends TcuEvent {
  final String origin;
  final String destination;
  final TcuTransportType filter;

  const TcuLoadRoutesEvent({
    required this.origin,
    required this.destination,
    this.filter = TcuTransportType.all,
  });

  @override
  List<Object?> get props => [origin, destination, filter];
}

class TcuChangeFilterEvent extends TcuEvent {
  final TcuTransportType filter;

  const TcuChangeFilterEvent(this.filter);

  @override
  List<Object?> get props => [filter];
}

class TcuSwapOriginDestinationEvent extends TcuEvent {
  const TcuSwapOriginDestinationEvent();
}

class TcuToggleStopExpandedEvent extends TcuEvent {
  final String routeId;

  const TcuToggleStopExpandedEvent(this.routeId);

  @override
  List<Object?> get props => [routeId];
}

class TcuDismissSeddoCardEvent extends TcuEvent {
  const TcuDismissSeddoCardEvent();
}
