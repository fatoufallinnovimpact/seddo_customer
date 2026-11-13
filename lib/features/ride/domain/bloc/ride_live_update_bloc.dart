import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seddo/features/ride/data/models/ride_live_update_mapper.dart';
import 'package:seddo/features/ride/data/models/ride_model.dart';
import 'package:seddo/features/ride/domain/bloc/ride_live_update_event.dart';
import 'package:seddo/features/ride/domain/bloc/ride_live_update_state.dart';
import 'package:seddo/features/ride/domain/models/ride_live_update_data.dart';
import 'package:seddo/features/ride/domain/services/ride_live_update_service.dart';
import 'package:seddo/services/realtime_service.dart';

export 'ride_live_update_event.dart';
export 'ride_live_update_state.dart';

/// Dedicated BLoC managing the lifecycle of Lock Screen Live Activities (iOS)
/// and Live Updates (Android 16 ProgressStyle).
/// Listens to existing real-time services without duplicating business logic.
class RideLiveUpdateBloc
    extends Bloc<RideLiveUpdateEvent, RideLiveUpdateState> {
  final RideLiveUpdateService service;
  final RealtimeService realtimeService;

  StreamSubscription<RealtimeRideStatusEvent>? _statusSub;
  StreamSubscription<RealtimeDriverLocationEvent>? _locationSub;
  StreamSubscription<RealtimeRideEtaEvent>? _etaSub;

  RideLiveUpdateBloc({
    required this.service,
    RealtimeService? realtimeService,
  })  : realtimeService = realtimeService ?? RealtimeService(),
        super(const RideLiveUpdateInitialState()) {
    on<InitializeLiveUpdateEvent>(_onInitialize);
    on<UpdateLiveUpdateLocationEvent>(_onUpdateLocation);
    on<UpdateLiveUpdateEtaEvent>(_onUpdateEta);
    on<UpdateLiveUpdateStatusEvent>(_onUpdateStatus);
    on<DismissLiveUpdateEvent>(_onDismiss);
  }

  Future<void> _onInitialize(
    InitializeLiveUpdateEvent event,
    Emitter<RideLiveUpdateState> emit,
  ) async {
    final isSupported = await service.isSupported();
    if (!isSupported) {
      emit(const RideLiveUpdateDisabledState(
        reason: 'Live updates non supportées sur cet appareil / système.',
      ));
      return;
    }

    final areEnabled = await service.areActivitiesEnabled();
    if (!areEnabled) {
      emit(const RideLiveUpdateDisabledState(
        reason: 'Live updates désactivées par l\'utilisateur dans les réglages.',
      ));
      return;
    }

    final initialData = RideLiveUpdateMapper.fromRideAndDriver(
      rideId: event.rideId,
      driver: event.driver,
      rideStatus: event.initialStatus ?? RideStatus.driverAssigned,
      departureText: event.departure?.mainText,
      destinationText: event.destination?.mainText,
    );

    final activityId = await service.startLiveUpdate(initialData);

    emit(RideLiveUpdateActiveState(
      data: initialData,
      activityId: activityId,
    ));

    _startRealtimeSubscriptions(event.rideId);
  }

  void _startRealtimeSubscriptions(String activeRideId) {
    _statusSub?.cancel();
    _locationSub?.cancel();
    _etaSub?.cancel();

    _statusSub = realtimeService.rideStatusStream.listen((event) {
      if (event.rideId == activeRideId) {
        add(UpdateLiveUpdateStatusEvent(
          status: event.status,
          driver: event.driver,
        ));
      }
    });

    _locationSub = realtimeService.driverLocationStream.listen((event) {
      if (event.rideId == null || event.rideId == activeRideId) {
        add(UpdateLiveUpdateLocationEvent(
          location: event.location,
        ));
      }
    });

    _etaSub = realtimeService.rideEtaStream.listen((event) {
      if (event.rideId == activeRideId) {
        final distKm = event.distanceMeters != null
            ? event.distanceMeters! / 1000.0
            : null;
        add(UpdateLiveUpdateEtaEvent(
          etaMinutes: event.etaMinutes,
          distanceKm: distKm,
        ));
      }
    });
  }

  Future<void> _onUpdateLocation(
    UpdateLiveUpdateLocationEvent event,
    Emitter<RideLiveUpdateState> emit,
  ) async {
    if (state is! RideLiveUpdateActiveState) return;
    final current = (state as RideLiveUpdateActiveState).data;

    // Progression continue de gauche (0.05) vers la droite (0.98) selon le tracé réel
    final updatedEta = event.etaMinutes ?? current.etaMinutes;
    double progress = event.progress ?? current.progress;
    if (event.progress == null) {
      if (current.phase == RideLiveUpdatePhase.driverApproaching) {
        final remaining = (updatedEta / 15.0).clamp(0.0, 1.0);
        progress = (1.0 - remaining).clamp(0.05, 0.98);
      } else if (current.phase == RideLiveUpdatePhase.inProgress) {
        // En cours de course, préserver strictement la progression métrique réelle
        // calculée le long du polyline restant sans appliquer de ratio arbitraire
        progress = current.progress;
      }
    }

    final updatedData = current.copyWith(
      etaMinutes: updatedEta,
      progress: progress,
    );

    await service.updateLiveUpdate(updatedData);
    emit((state as RideLiveUpdateActiveState).copyWith(data: updatedData));
  }

  Future<void> _onUpdateEta(
    UpdateLiveUpdateEtaEvent event,
    Emitter<RideLiveUpdateState> emit,
  ) async {
    if (state is! RideLiveUpdateActiveState) return;
    final current = (state as RideLiveUpdateActiveState).data;

    final updatedData = current.copyWith(
      etaMinutes: event.etaMinutes,
      progress: event.progress ?? current.progress,
    );

    await service.updateLiveUpdate(updatedData);
    emit((state as RideLiveUpdateActiveState).copyWith(data: updatedData));
  }

  Future<void> _onUpdateStatus(
    UpdateLiveUpdateStatusEvent event,
    Emitter<RideLiveUpdateState> emit,
  ) async {
    if (state is! RideLiveUpdateActiveState) return;
    final current = (state as RideLiveUpdateActiveState).data;
    final upperStatus = event.status.toUpperCase();

    // End ride cases
    if (upperStatus.contains('COMPLETE') ||
        upperStatus.contains('CANCEL') ||
        upperStatus.contains('NO_DRIVER')) {
      final isCompleted = upperStatus.contains('COMPLETE');
      final finalData = current.copyWith(
        phase: isCompleted
            ? RideLiveUpdatePhase.completed
            : RideLiveUpdatePhase.cancelled,
        statusLabel: isCompleted ? 'Course terminée' : 'Course annulée',
        etaMinutes: 0,
        progress: isCompleted ? 1.0 : 0.0,
      );

      _cancelSubscriptions();
      await service.endLiveUpdate(
        rideId: current.rideId,
        finalData: finalData,
      );

      emit(RideLiveUpdateEndedState(
        rideId: current.rideId,
        reason: isCompleted ? 'Course terminée' : 'Course annulée',
      ));
      return;
    }

    // Active status progression
    RideLiveUpdatePhase newPhase = current.phase;
    String newLabel = current.statusLabel;
    double newProgress = current.progress;

    if (upperStatus.contains('ARRIVED')) {
      newPhase = RideLiveUpdatePhase.driverArrived;
      newLabel = 'Votre chauffeur est arrivé au point de rendez-vous';
      newProgress = 1.0;
    } else if (upperStatus.contains('IN_PROGRESS') ||
        upperStatus.contains('PROGRESS') ||
        upperStatus.contains('STARTED')) {
      newPhase = RideLiveUpdatePhase.inProgress;
      newLabel = 'En route vers destination';
      newProgress = newProgress >= 1.0 ? 0.05 : newProgress;
    } else if (upperStatus.contains('APPROACH')) {
      newPhase = RideLiveUpdatePhase.driverApproaching;
      newLabel = 'Chauffeur en approche';
    }

    final updatedData = current.copyWith(
      phase: newPhase,
      statusLabel: newLabel,
      progress: newProgress,
      driverName: event.driver?.name.isNotEmpty == true
          ? event.driver!.name
          : current.driverName,
      carColor: event.driver?.carColor.isNotEmpty == true
          ? event.driver!.carColor
          : current.carColor,
      licensePlate: event.driver?.licensePlate.isNotEmpty == true
          ? event.driver!.licensePlate
          : current.licensePlate,
    );

    await service.updateLiveUpdate(updatedData);
    emit((state as RideLiveUpdateActiveState).copyWith(data: updatedData));
  }

  Future<void> _onDismiss(
    DismissLiveUpdateEvent event,
    Emitter<RideLiveUpdateState> emit,
  ) async {
    _cancelSubscriptions();
    if (state is RideLiveUpdateActiveState) {
      final current = (state as RideLiveUpdateActiveState).data;
      await service.endLiveUpdate(rideId: current.rideId);
      emit(RideLiveUpdateEndedState(
        rideId: current.rideId,
        reason: event.reason ?? 'Fermeture manuelle',
      ));
    }
  }

  void _cancelSubscriptions() {
    _statusSub?.cancel();
    _locationSub?.cancel();
    _etaSub?.cancel();
    _statusSub = null;
    _locationSub = null;
    _etaSub = null;
  }

  @override
  Future<void> close() {
    _cancelSubscriptions();
    return super.close();
  }
}
