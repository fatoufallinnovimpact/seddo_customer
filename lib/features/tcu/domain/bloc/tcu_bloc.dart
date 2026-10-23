import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seddo/features/tcu/data/models/tcu_route_model.dart';
import 'package:seddo/features/tcu/data/repositories/tcu_repository.dart';
import 'package:seddo/features/tcu/domain/bloc/tcu_event.dart';
import 'package:seddo/features/tcu/domain/bloc/tcu_state.dart';

class TcuBloc extends Bloc<TcuEvent, TcuState> {
  final TcuRepository _repository;

  TcuBloc({
    TcuRepository? repository,
  })  : _repository = repository ?? TcuRepositoryImpl(),
        super(const TcuInitialState()) {
    on<TcuLoadRoutesEvent>(_onLoadRoutes);
    on<TcuChangeFilterEvent>(_onChangeFilter);
    on<TcuSwapOriginDestinationEvent>(_onSwapOriginDestination);
    on<TcuToggleStopExpandedEvent>(_onToggleStopExpanded);
    on<TcuDismissSeddoCardEvent>(_onDismissSeddoCard);
  }

  Future<void> _onLoadRoutes(
    TcuLoadRoutesEvent event,
    Emitter<TcuState> emit,
  ) async {
    emit(const TcuLoadingState());
    try {
      final all = await _repository.getRouteOptions(
        origin: event.origin,
        destination: event.destination,
        filter: TcuTransportType.all,
      );

      final filtered = event.filter == TcuTransportType.all
          ? all
          : all.where((opt) => opt.type == event.filter).toList();

      emit(
        TcuLoadedState(
          origin: event.origin,
          destination: event.destination,
          selectedFilter: event.filter,
          allOptions: all,
          filteredOptions: filtered,
          expandedStopsRouteIds: const {},
          showSeddoCard: true,
        ),
      );
    } catch (e) {
      emit(TcuErrorState(e.toString()));
    }
  }

  void _onChangeFilter(
    TcuChangeFilterEvent event,
    Emitter<TcuState> emit,
  ) {
    if (state is! TcuLoadedState) return;
    final current = state as TcuLoadedState;

    final filtered = event.filter == TcuTransportType.all
        ? current.allOptions
        : current.allOptions.where((opt) => opt.type == event.filter).toList();

    emit(
      current.copyWith(
        selectedFilter: event.filter,
        filteredOptions: filtered,
      ),
    );
  }

  Future<void> _onSwapOriginDestination(
    TcuSwapOriginDestinationEvent event,
    Emitter<TcuState> emit,
  ) async {
    if (state is! TcuLoadedState) return;
    final current = state as TcuLoadedState;
    final newOrigin = current.destination;
    final newDest = current.origin;

    add(
      TcuLoadRoutesEvent(
        origin: newOrigin,
        destination: newDest,
        filter: current.selectedFilter,
      ),
    );
  }

  void _onToggleStopExpanded(
    TcuToggleStopExpandedEvent event,
    Emitter<TcuState> emit,
  ) {
    if (state is! TcuLoadedState) return;
    final current = state as TcuLoadedState;
    final newExpanded = Set<String>.from(current.expandedStopsRouteIds);
    if (newExpanded.contains(event.routeId)) {
      newExpanded.remove(event.routeId);
    } else {
      newExpanded.add(event.routeId);
    }
    emit(current.copyWith(expandedStopsRouteIds: newExpanded));
  }

  void _onDismissSeddoCard(
    TcuDismissSeddoCardEvent event,
    Emitter<TcuState> emit,
  ) {
    if (state is! TcuLoadedState) return;
    final current = state as TcuLoadedState;
    emit(current.copyWith(showSeddoCard: false));
  }
}
