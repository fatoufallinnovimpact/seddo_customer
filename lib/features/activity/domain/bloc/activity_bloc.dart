import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/activity/data/repositories/activity_repository.dart';
import 'package:seddo/features/activity/domain/bloc/activity_event.dart';
import 'package:seddo/features/activity/domain/bloc/activity_state.dart';

class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  final ActivityRepository _repository;

  ActivityBloc({
    ActivityRepository? repository,
  })  : _repository = repository ?? ActivityRepositoryImpl(),
        super(const ActivityInitialState()) {
    on<ActivityLoadInitialEvent>(_onLoadInitial);
    on<ActivityChangeTabEvent>(_onChangeTab);
    on<ActivityLoadMorePastRidesEvent>(_onLoadMorePastRides);
    on<ActivityRefreshEvent>(_onRefresh);
  }

  Future<void> _onLoadInitial(
    ActivityLoadInitialEvent event,
    Emitter<ActivityState> emit,
  ) async {
    emit(const ActivityLoadingState());
    try {
      final summary = await _repository.getSummary();
      final recent = await _repository.getRecentRide();
      final past = await _repository.getPastRides(
        page: 1,
        pageSize: AppConstants.activityItemsPerPage,
      );
      final totalPast = await _repository.getTotalPastRidesCount();
      final refunds = await _repository.getRefunds();

      emit(
        ActivityLoadedState(
          currentTab: event.initialTab,
          summary: summary,
          recentRide: recent,
          pastRides: past,
          refunds: refunds,
          currentPage: 1,
          hasMore: past.length < totalPast,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      emit(ActivityErrorState(e.toString()));
    }
  }

  void _onChangeTab(
    ActivityChangeTabEvent event,
    Emitter<ActivityState> emit,
  ) {
    if (state is! ActivityLoadedState) return;
    final current = state as ActivityLoadedState;
    emit(current.copyWith(currentTab: event.tab));
  }

  Future<void> _onLoadMorePastRides(
    ActivityLoadMorePastRidesEvent event,
    Emitter<ActivityState> emit,
  ) async {
    if (state is! ActivityLoadedState) return;
    final current = state as ActivityLoadedState;
    if (current.isLoadingMore || !current.hasMore) return;

    emit(current.copyWith(isLoadingMore: true));

    try {
      final nextPage = current.currentPage + 1;
      final newItems = await _repository.getPastRides(
        page: nextPage,
        pageSize: AppConstants.activityItemsPerPage,
      );

      final totalPast = await _repository.getTotalPastRidesCount();
      final updatedList = List.of(current.pastRides)..addAll(newItems);

      emit(
        current.copyWith(
          pastRides: updatedList,
          currentPage: nextPage,
          hasMore: updatedList.length < totalPast && newItems.isNotEmpty,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      emit(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onRefresh(
    ActivityRefreshEvent event,
    Emitter<ActivityState> emit,
  ) async {
    final currentTab =
        state is ActivityLoadedState ? (state as ActivityLoadedState).currentTab : ActivityTab.courses;
    add(ActivityLoadInitialEvent(initialTab: currentTab));
  }
}
