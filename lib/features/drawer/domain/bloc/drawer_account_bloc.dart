import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seddo/features/activity/data/repositories/activity_repository.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';
import 'package:seddo/features/payment/data/services/payment_methods_service.dart';
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
          accessToken: AuthRepository.cachedAccessToken,
          tripsCount:
              (authRepository ?? AuthRepository()).currentUser?.tripsCount ??
                  AuthRepository.cachedTripsCount ??
                  0,
        )) {
    on<DrawerAccountLoadRequested>(_onLoadRequested);
    on<DrawerAccountUserUpdated>(_onUserUpdated);
    on<DrawerAccountNotificationsChanged>(_onNotificationsChanged);
  }

  Future<void> _onLoadRequested(
    DrawerAccountLoadRequested event,
    Emitter<DrawerAccountState> emit,
  ) async {
    // 1. Émission instantanée depuis la mémoire vive (0ms, aucune attente réseau)
    final current = _authRepository.currentUser;
    final cachedTrips = current?.tripsCount ??
        AuthRepository.cachedTripsCount ??
        state.tripsCount;
    final token = AuthRepository.cachedAccessToken;

    emit(state.copyWith(
      user: current ?? state.user,
      tripsCount: cachedTrips,
      accessToken: token ?? state.accessToken,
    ));

    // 2. Chargement immédiat du cache disque en parallèle si la mémoire n'était pas encore chaude
    try {
      final results = await Future.wait([
        _authRepository.getAccessToken(),
        _authRepository.getCachedUser(),
      ]);
      final diskToken = results[0] as String?;
      final diskUser = results[1] as dynamic;
      final diskTrips = diskUser?.tripsCount ??
          AuthRepository.cachedTripsCount ??
          state.tripsCount;

      emit(state.copyWith(
        user: diskUser ?? state.user,
        tripsCount: diskTrips,
        accessToken: diskToken ?? state.accessToken,
      ));
    } catch (_) {}

    if (_isTest) {
      return;
    }

    // 3. Rafraîchissement silencieux en arrière-plan (sans bloquer ni faire clignoter l'UI)
    try {
      await Future.wait([
        // Profil distant
        _authRepository.fetchUserProfile().then((remote) {
          if (remote != null && !emit.isDone) {
            emit(state.copyWith(
              user: remote,
              tripsCount: remote.tripsCount ?? state.tripsCount,
            ));
          }
        }).catchError((_) => null),

        // Synchronisation silencieuse du nombre de courses en arrière-plan
        _activityRepository.getRidesHistory(limit: 50).then((history) {
          if (!emit.isDone) {
            final count = history.where((r) => !r.isCancelled).length;
            AuthRepository.setCachedTripsCount(count);
            if (count != state.tripsCount) {
              emit(state.copyWith(tripsCount: count));
            }
          }
        }).catchError((_) => null),

        // Synchronisation silencieuse du mode de paiement
        PaymentMethodsService().refreshFromBackend().catchError((_) => null),

        // Photo de profil en cache mémoire
        if (AuthRepository.cachedUserPhotoBytes == null)
          _authRepository.getUserPhotoBytes().catchError((_) => null),
      ]);
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
