import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seddo/features/privacy/data/repositories/privacy_repository.dart';
import 'package:seddo/features/privacy/domain/bloc/privacy_event.dart';
import 'package:seddo/features/privacy/domain/bloc/privacy_state.dart';

export 'privacy_event.dart';
export 'privacy_state.dart';

/// BLoC for Privacy feature following Innov & Impact Africa guidelines:
/// - Un feature = un BLoC
/// - Séparer clairement : Event, State, Bloc
/// - Communique uniquement avec les repositories
class PrivacyBloc extends Bloc<PrivacyEvent, PrivacyState> {
  final PrivacyRepository _repository;

  PrivacyBloc({PrivacyRepository? repository})
      : _repository = repository ?? PrivacyRepository(),
        super(const PrivacyState()) {
    on<PrivacyLoadRequested>(_onLoadRequested);
    on<PrivacyLocationPermissionChanged>(_onLocationPermissionChanged);
    on<PrivacyPreciseLocationToggled>(_onPreciseLocationToggled);
    on<PrivacyPersonalizedSuggestionsToggled>(_onPersonalizedSuggestionsToggled);
    on<PrivacyOffersPromotionsToggled>(_onOffersPromotionsToggled);
    on<PrivacyUsageStatisticsToggled>(_onUsageStatisticsToggled);
    on<PrivacyDataDownloadRequested>(_onDataDownloadRequested);
    on<PrivacyClearHistoryRequested>(_onClearHistoryRequested);
    on<PrivacyDeleteAccountRequested>(_onDeleteAccountRequested);
  }

  Future<void> _onLoadRequested(
    PrivacyLoadRequested event,
    Emitter<PrivacyState> emit,
  ) async {
    emit(state.copyWith(status: PrivacyStatus.loading));
    try {
      final settings = await _repository.getPrivacySettings();
      emit(state.copyWith(
        status: PrivacyStatus.success,
        settings: settings,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: PrivacyStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLocationPermissionChanged(
    PrivacyLocationPermissionChanged event,
    Emitter<PrivacyState> emit,
  ) async {
    final updated =
        state.settings.copyWith(locationPermissionIndex: event.index);
    emit(state.copyWith(settings: updated));
    await _repository.updatePrivacySettings(updated);
  }

  Future<void> _onPreciseLocationToggled(
    PrivacyPreciseLocationToggled event,
    Emitter<PrivacyState> emit,
  ) async {
    final updated = state.settings.copyWith(preciseLocation: event.value);
    emit(state.copyWith(settings: updated));
    await _repository.updatePrivacySettings(updated);
  }

  Future<void> _onPersonalizedSuggestionsToggled(
    PrivacyPersonalizedSuggestionsToggled event,
    Emitter<PrivacyState> emit,
  ) async {
    final updated =
        state.settings.copyWith(personalizedSuggestions: event.value);
    emit(state.copyWith(settings: updated));
    await _repository.updatePrivacySettings(updated);
  }

  Future<void> _onOffersPromotionsToggled(
    PrivacyOffersPromotionsToggled event,
    Emitter<PrivacyState> emit,
  ) async {
    final updated = state.settings.copyWith(offersPromotions: event.value);
    emit(state.copyWith(settings: updated));
    await _repository.updatePrivacySettings(updated);
  }

  Future<void> _onUsageStatisticsToggled(
    PrivacyUsageStatisticsToggled event,
    Emitter<PrivacyState> emit,
  ) async {
    final updated = state.settings.copyWith(usageStatistics: event.value);
    emit(state.copyWith(settings: updated));
    await _repository.updatePrivacySettings(updated);
  }

  Future<void> _onDataDownloadRequested(
    PrivacyDataDownloadRequested event,
    Emitter<PrivacyState> emit,
  ) async {
    try {
      await _repository.requestDataDownload();
      emit(state.copyWith(
        feedbackMessageKey: 'privacy.download_dialog_snack',
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onClearHistoryRequested(
    PrivacyClearHistoryRequested event,
    Emitter<PrivacyState> emit,
  ) async {
    try {
      await _repository.clearRideHistory();
      emit(state.copyWith(
        feedbackMessageKey: 'privacy.clear_dialog_snack',
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onDeleteAccountRequested(
    PrivacyDeleteAccountRequested event,
    Emitter<PrivacyState> emit,
  ) async {
    try {
      await _repository.deleteAccount();
      emit(state.copyWith(
        feedbackMessageKey: 'privacy.delete_dialog_snack',
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}
