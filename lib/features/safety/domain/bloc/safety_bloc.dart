import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/safety/data/repositories/safety_repository.dart';
import 'package:seddo/features/safety/domain/bloc/safety_event.dart';
import 'package:seddo/features/safety/domain/bloc/safety_state.dart';

export 'safety_event.dart';
export 'safety_state.dart';

/// BLoC for Safety feature following Innov & Impact Africa guidelines:
/// - Un feature = un BLoC
/// - Séparer clairement : Event, State, Bloc
/// - Communique uniquement avec les repositories
class SafetyBloc extends Bloc<SafetyEvent, SafetyState> {
  final SafetyRepository _repository;

  SafetyBloc({SafetyRepository? repository})
      : _repository = repository ?? SafetyRepository(),
        super(const SafetyState()) {
    on<SafetyLoadRequested>(_onLoadRequested);
    on<SafetySosTriggered>(_onSosTriggered);
    on<SafetySosDismissed>(_onSosDismissed);
    on<SafetyContactAdded>(_onContactAdded);
    on<SafetyContactRemoved>(_onContactRemoved);
    on<SafetyAutoShareToggled>(_onAutoShareToggled);
    on<SafetyPinCodeToggled>(_onPinCodeToggled);
    on<SafetyDetourAlertToggled>(_onDetourAlertToggled);
  }

  Future<void> _onLoadRequested(
    SafetyLoadRequested event,
    Emitter<SafetyState> emit,
  ) async {
    emit(state.copyWith(status: SafetyStatus.loading, clearError: true));
    try {
      final contacts = await _repository.getEmergencyContacts();
      emit(state.copyWith(
        status: SafetyStatus.success,
        contacts: contacts,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: SafetyStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSosTriggered(
    SafetySosTriggered event,
    Emitter<SafetyState> emit,
  ) async {
    emit(state.copyWith(isSendingSos: true, clearError: true));
    try {
      await _repository.triggerSosAlert(
        rideId: event.rideId,
        latitude: event.latitude,
        longitude: event.longitude,
      );
      emit(state.copyWith(
        isSendingSos: false,
        sosTriggered: true,
        userFeedbackMessage: 'safety.sos_sent_success',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSendingSos: false,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onSosDismissed(
    SafetySosDismissed event,
    Emitter<SafetyState> emit,
  ) {
    emit(state.copyWith(sosTriggered: false));
  }

  Future<void> _onContactAdded(
    SafetyContactAdded event,
    Emitter<SafetyState> emit,
  ) async {
    if (state.contacts.length >= AppConstants.maxEmergencyContacts) {
      emit(state.copyWith(
        errorMessage: 'safety.max_contacts_reached',
      ));
      return;
    }

    emit(state.copyWith(isUpdatingContacts: true, clearError: true));
    try {
      final updatedList = await _repository.addEmergencyContact(
        event.contact,
        state.contacts,
      );
      emit(state.copyWith(
        isUpdatingContacts: false,
        contacts: updatedList,
        userFeedbackMessage: event.contact.name,
      ));
    } catch (e) {
      emit(state.copyWith(
        isUpdatingContacts: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onContactRemoved(
    SafetyContactRemoved event,
    Emitter<SafetyState> emit,
  ) async {
    emit(state.copyWith(isUpdatingContacts: true, clearError: true));
    try {
      final updatedList = await _repository.deleteEmergencyContact(
        event.contactId,
        state.contacts,
      );
      emit(state.copyWith(
        isUpdatingContacts: false,
        contacts: updatedList,
      ));
    } catch (e) {
      emit(state.copyWith(
        isUpdatingContacts: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onAutoShareToggled(
    SafetyAutoShareToggled event,
    Emitter<SafetyState> emit,
  ) async {
    final nextVal = event.value;
    emit(state.copyWith(autoShare: nextVal));
    await _repository.updateSafetySettings(
      autoShare: nextVal,
      pinCode: state.pinCode,
      detourAlert: state.detourAlert,
    );
  }

  Future<void> _onPinCodeToggled(
    SafetyPinCodeToggled event,
    Emitter<SafetyState> emit,
  ) async {
    final nextVal = event.value;
    emit(state.copyWith(pinCode: nextVal));
    await _repository.updateSafetySettings(
      autoShare: state.autoShare,
      pinCode: nextVal,
      detourAlert: state.detourAlert,
    );
  }

  Future<void> _onDetourAlertToggled(
    SafetyDetourAlertToggled event,
    Emitter<SafetyState> emit,
  ) async {
    final nextVal = event.value;
    emit(state.copyWith(detourAlert: nextVal));
    await _repository.updateSafetySettings(
      autoShare: state.autoShare,
      pinCode: state.pinCode,
      detourAlert: nextVal,
    );
  }
}
