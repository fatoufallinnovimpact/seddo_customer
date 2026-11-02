import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/activity/data/models/activity_item_model.dart';
import 'package:seddo/features/activity/data/repositories/activity_repository.dart';
import 'package:seddo/features/activity/domain/bloc/activity_event.dart';
import 'package:seddo/features/activity/domain/bloc/activity_state.dart';

class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  final ActivityRepository _repository;
  List<ActivityRideItem> _allPastRides = [];
  List<ActivityRefundItem> _allRefunds = [];

  ActivityBloc({
    ActivityRepository? repository,
  })  : _repository = repository ?? ActivityRepositoryImpl(),
        super(const ActivityInitialState()) {
    on<ActivityLoadInitialEvent>(_onLoadInitial);
    on<ActivityChangeTabEvent>(_onChangeTab);
    on<ActivityLoadMorePastRidesEvent>(_onLoadMorePastRides);
    on<ActivityLoadMoreRefundsEvent>(_onLoadMoreRefunds);
    on<ActivityRefreshEvent>(_onRefresh);
  }

  Future<void> _onLoadInitial(
    ActivityLoadInitialEvent event,
    Emitter<ActivityState> emit,
  ) async {
    emit(const ActivityLoadingState());
    try {
      final historyRides = await _repository.getRidesHistory(limit: 50);
      final isRemote = _repository.isUsingRemoteData;
      final rawRefunds =
          await _repository.getRefunds(rides: isRemote ? historyRides : null);
      _allRefunds = rawRefunds;
      final summary = await _repository.getSummary(
        rides: isRemote ? historyRides : null,
        refunds: isRemote ? rawRefunds : null,
      );
      final recent =
          await _repository.getRecentRide(rides: isRemote ? historyRides : null);

      if (isRemote) {
        _allPastRides = historyRides.length > 1 ? historyRides.sublist(1) : [];
      } else {
        _allPastRides = [];
      }

      final past = await _repository.getPastRides(
        allRides: isRemote ? _allPastRides : null,
        page: 1,
        pageSize: AppConstants.activityItemsPerPage,
      );
      final totalPast = await _repository.getTotalPastRidesCount(
        allRides: isRemote ? _allPastRides : null,
      );

      final initialRefunds =
          _allRefunds.take(AppConstants.activityItemsPerPage).toList();

      emit(
        ActivityLoadedState(
          currentTab: event.initialTab,
          summary: summary,
          recentRide: recent,
          pastRides: past,
          refunds: initialRefunds,
          currentPage: 1,
          hasMore: past.length < totalPast,
          isLoadingMore: false,
          currentRefundsPage: 1,
          hasMoreRefunds: initialRefunds.length < _allRefunds.length,
          isLoadingMoreRefunds: false,
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
        allRides: _allPastRides.isNotEmpty ? _allPastRides : null,
        page: nextPage,
        pageSize: AppConstants.activityItemsPerPage,
      );

      final totalPast = await _repository.getTotalPastRidesCount(
        allRides: _allPastRides.isNotEmpty ? _allPastRides : null,
      );
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

  Future<void> _onLoadMoreRefunds(
    ActivityLoadMoreRefundsEvent event,
    Emitter<ActivityState> emit,
  ) async {
    if (state is! ActivityLoadedState) return;
    final current = state as ActivityLoadedState;
    if (current.isLoadingMoreRefunds || !current.hasMoreRefunds) return;

    emit(current.copyWith(isLoadingMoreRefunds: true));

    try {
      await Future.delayed(const Duration(milliseconds: 350));
      final nextPage = current.currentRefundsPage + 1;
      final nextItems = _allRefunds
          .skip((nextPage - 1) * AppConstants.activityItemsPerPage)
          .take(AppConstants.activityItemsPerPage)
          .toList();

      final updatedRefunds = List.of(current.refunds)..addAll(nextItems);

      emit(
        current.copyWith(
          refunds: updatedRefunds,
          currentRefundsPage: nextPage,
          hasMoreRefunds: updatedRefunds.length < _allRefunds.length,
          isLoadingMoreRefunds: false,
        ),
      );
    } catch (_) {
      emit(current.copyWith(isLoadingMoreRefunds: false));
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
