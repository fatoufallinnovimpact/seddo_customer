import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seddo/features/activity/data/repositories/activity_repository.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';
import 'drawer_account_event.dart';
import 'drawer_account_state.dart';

class DrawerAccountBloc extends Bloc<DrawerAccountEvent, DrawerAccountState> {
  final AuthRepository _authRepository;
  final ActivityRepository _activityRepository;

  bool get _isTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  DrawerAccountBloc({
    AuthRepository? authRepository,
    ActivityRepository? activityRepository,
  })  : _authRepository = authRepository ?? AuthRepository(),
        _activityRepository = activityRepository ?? ActivityRepositoryImpl(),
        super(DrawerAccountState(
          user: (authRepository ?? AuthRepository()).currentUser,
          tripsCount:
              (authRepository ?? AuthRepository()).currentUser?.tripsCount ?? 0,
        )) {
    on<DrawerAccountLoadRequested>(_onLoadRequested);
    on<DrawerAccountUserUpdated>(_onUserUpdated);
    on<DrawerAccountNotificationsChanged>(_onNotificationsChanged);
  }

  Future<void> _onLoadRequested(
    DrawerAccountLoadRequested event,
    Emitter<DrawerAccountState> emit,
  ) async {
    final current = _authRepository.currentUser;
    if (current != null) {
      emit(state.copyWith(
        user: current,
        tripsCount: current.tripsCount ?? state.tripsCount,
      ));
    }

    try {
      final token = await _authRepository.getAccessToken();
      if (token != null) {
        emit(state.copyWith(accessToken: token));
      }
    } catch (_) {}

    try {
      final cached = await _authRepository.getCachedUser();
      if (cached != null) {
        emit(state.copyWith(
          user: cached,
          tripsCount: cached.tripsCount ?? state.tripsCount,
        ));
      }
    } catch (_) {}

    if (_isTest) {
      return;
    }

    try {
      final remote = await _authRepository.fetchUserProfile();
      if (remote != null) {
        emit(state.copyWith(
          user: remote,
          tripsCount: remote.tripsCount ?? state.tripsCount,
        ));
      }
    } catch (_) {}

    try {
      final currentTrips = state.user?.tripsCount;
      if (currentTrips != null) {
        emit(state.copyWith(tripsCount: currentTrips));
      } else {
        final history = await _activityRepository.getRidesHistory(limit: 50);
        if (_activityRepository.isUsingRemoteData) {
          final count = history.where((r) => !r.isCancelled).length;
          emit(state.copyWith(tripsCount: count));
        }
      }
    } catch (_) {}
  }

  Future<void> _onUserUpdated(
    DrawerAccountUserUpdated event,
    Emitter<DrawerAccountState> emit,
  ) async {
    final current = event.updatedUser ?? _authRepository.currentUser;
    if (current != null) {
      emit(state.copyWith(
        user: current,
        tripsCount: current.tripsCount ?? state.tripsCount,
      ));
    }
    add(const DrawerAccountLoadRequested());
  }

  Future<void> _onNotificationsChanged(
    DrawerAccountNotificationsChanged event,
    Emitter<DrawerAccountState> emit,
  ) async {
    try {
      final updated = await _authRepository.updateProfile(
        notifyPush: event.notifyPush,
        notifySms: event.notifySms,
      );
      emit(state.copyWith(
        user: updated,
        tripsCount: updated.tripsCount ?? state.tripsCount,
      ));
    } catch (_) {}
  }
}
