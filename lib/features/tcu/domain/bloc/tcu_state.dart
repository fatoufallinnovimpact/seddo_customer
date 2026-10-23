import 'package:equatable/equatable.dart';
import 'package:seddo/features/tcu/data/models/tcu_route_model.dart';

abstract class TcuState extends Equatable {
  const TcuState();

  @override
  List<Object?> get props => [];
}

class TcuInitialState extends TcuState {
  const TcuInitialState();
}

class TcuLoadingState extends TcuState {
  const TcuLoadingState();
}

class TcuLoadedState extends TcuState {
  final String origin;
  final String destination;
  final TcuTransportType selectedFilter;
  final List<TcuRouteOption> allOptions;
  final List<TcuRouteOption> filteredOptions;
  final Set<String> expandedStopsRouteIds;
  final bool showSeddoCard;

  const TcuLoadedState({
    required this.origin,
    required this.destination,
    required this.selectedFilter,
    required this.allOptions,
    required this.filteredOptions,
    required this.expandedStopsRouteIds,
    this.showSeddoCard = true,
  });

  TcuLoadedState copyWith({
    String? origin,
    String? destination,
    TcuTransportType? selectedFilter,
    List<TcuRouteOption>? allOptions,
    List<TcuRouteOption>? filteredOptions,
    Set<String>? expandedStopsRouteIds,
    bool? showSeddoCard,
  }) {
    return TcuLoadedState(
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      allOptions: allOptions ?? this.allOptions,
      filteredOptions: filteredOptions ?? this.filteredOptions,
      expandedStopsRouteIds:
          expandedStopsRouteIds ?? this.expandedStopsRouteIds,
      showSeddoCard: showSeddoCard ?? this.showSeddoCard,
    );
  }

  @override
  List<Object?> get props => [
        origin,
        destination,
        selectedFilter,
        allOptions,
        filteredOptions,
        expandedStopsRouteIds,
        showSeddoCard,
      ];
}

class TcuErrorState extends TcuState {
  final String message;

  const TcuErrorState(this.message);

  @override
  List<Object?> get props => [message];
}
