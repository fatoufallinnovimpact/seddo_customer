import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seddo/features/ride/data/models/chat_message_model.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_model.dart';
import 'package:seddo/features/ride/data/repositories/ride_repository.dart';
import 'package:seddo/features/ride/domain/bloc/ride_event.dart';
import 'package:seddo/features/ride/domain/bloc/ride_state.dart';

export 'ride_event.dart';
export 'ride_state.dart';

/// Central BLoC orchestrating the entire ride lifecycle for Seddo customer app.
/// Follows Innov & Impact Africa guidelines:
/// - Un feature = un BLoC
/// - Séparer clairement : Event, State, Bloc
/// - Communique uniquement avec les repositories
class RideBloc extends Bloc<RideEvent, RideState> {
  final RideRepository repository;
  StreamSubscription<DriverModel>? _driverLocationSub;
  StreamSubscription<RideModel>? _rideStatusSub;
  StreamSubscription<ChatMessageModel>? _chatMessagesSub;

  RideBloc({required this.repository}) : super(const RideInitialState()) {
    on<RequestRideEvent>(_onRequestRide);
    on<DriverAssignedEvent>(_onDriverAssigned);
    on<DriverLocationUpdatedEvent>(_onDriverLocationUpdated);
    on<RideStatusChangedEvent>(_onRideStatusChanged);
    on<CancelRideEvent>(_onCancelRide);
    on<NoDriverFoundEvent>(_onNoDriverFound);
    on<SendChatMessageEvent>(_onSendChatMessage);
    on<ReceiveChatMessageEvent>(_onReceiveChatMessage);
    on<SubmitRideRatingEvent>(_onSubmitRideRating);
  }

  Future<void> _onRequestRide(
    RequestRideEvent event,
    Emitter<RideState> emit,
  ) async {
    try {
      final ride = await repository.requestRide(
        departure: event.departure,
        destination: event.destination,
        rideOption: event.rideOption,
        paymentPhone: event.paymentPhone,
        transactionRef: event.transactionRef,
      );

      final fullRide = ride.copyWith(
        polylinePoints: event.polylinePoints,
      );

      emit(RideSearchingState(ride: fullRide));

      _subscribeToRideUpdates(fullRide.id);
    } catch (e) {
      emit(RideErrorState(
        errorMessage: 'Impossible de demander la course : $e',
      ));
    }
  }

  void _onDriverAssigned(
    DriverAssignedEvent event,
    Emitter<RideState> emit,
  ) {
    if (state.currentRide == null) return;

    final updatedRide = state.currentRide!.copyWith(
      driver: event.driver,
      status: RideStatus.driverAssigned,
    );

    final initialMessage = ChatMessageModel(
      id: 'msg_welcome',
      sender: ChatSender.driver,
      text: 'Bonjour ! Je suis en route pour vous récupérer.',
      timestamp: DateTime.now(),
    );

    emit(RideDriverAssignedState(
      ride: updatedRide,
      driver: event.driver,
      messages: [initialMessage],
    ));
  }

  void _onDriverLocationUpdated(
    DriverLocationUpdatedEvent event,
    Emitter<RideState> emit,
  ) {
    if (state.currentRide == null || state.currentRide!.driver == null) return;

    final updatedDriver = state.currentRide!.driver!.copyWith(
      currentLocation: event.location,
      etaMinutes: event.etaMinutes,
      distanceKm: event.distanceKm,
    );

    final updatedRide = state.currentRide!.copyWith(driver: updatedDriver);

    if (state is RideDriverAssignedState) {
      emit(RideDriverAssignedState(
        ride: updatedRide,
        driver: updatedDriver,
        messages: state.messages,
      ));
    } else if (state is RideInProgressState) {
      emit(RideInProgressState(
        ride: updatedRide,
        driver: updatedDriver,
        messages: state.messages,
      ));
    }
  }

  void _onRideStatusChanged(
    RideStatusChangedEvent event,
    Emitter<RideState> emit,
  ) {
    if (state.currentRide == null) return;

    final updatedRide = state.currentRide!.copyWith(status: event.status);

    switch (event.status) {
      case RideStatus.inProgress:
        if (state.currentRide!.driver != null) {
          emit(RideInProgressState(
            ride: updatedRide,
            driver: state.currentRide!.driver!,
            messages: state.messages,
          ));
        }
        break;
      case RideStatus.completed:
        if (state.currentRide!.driver != null) {
          emit(RideCompletedState(
            ride: updatedRide.copyWith(completedAt: DateTime.now()),
            driver: state.currentRide!.driver!,
          ));
        }
        break;
      case RideStatus.cancelled:
        emit(RideCancelledState(ride: updatedRide));
        break;
      case RideStatus.noDriver:
        emit(RideNoDriverState(ride: updatedRide));
        break;
      default:
        break;
    }
  }

  Future<void> _onCancelRide(
    CancelRideEvent event,
    Emitter<RideState> emit,
  ) async {
    if (state.currentRide == null) return;

    try {
      final cancelledRide = await repository.cancelRide(
        rideId: state.currentRide!.id,
        reason: event.reason,
      );
      emit(RideCancelledState(
        ride: cancelledRide,
        reason: event.reason,
      ));
    } catch (_) {
      final cancelledRide = state.currentRide!.copyWith(
        status: RideStatus.cancelled,
        completedAt: DateTime.now(),
      );
      emit(RideCancelledState(
        ride: cancelledRide,
        reason: event.reason,
      ));
    }
  }

  void _onNoDriverFound(
    NoDriverFoundEvent event,
    Emitter<RideState> emit,
  ) {
    if (state.currentRide == null) return;
    emit(RideNoDriverState(
      ride: state.currentRide!.copyWith(status: RideStatus.noDriver),
    ));
  }

  Future<void> _onSendChatMessage(
    SendChatMessageEvent event,
    Emitter<RideState> emit,
  ) async {
    if (state.currentRide == null) return;

    final userMessage = ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: ChatSender.customer,
      text: event.text,
      timestamp: DateTime.now(),
    );

    final updatedMessages = List<ChatMessageModel>.from(state.messages)
      ..add(userMessage);

    if (state is RideDriverAssignedState) {
      emit(RideDriverAssignedState(
        ride: state.currentRide!,
        driver: (state as RideDriverAssignedState).driver,
        messages: updatedMessages,
      ));
    } else if (state is RideInProgressState) {
      emit(RideInProgressState(
        ride: state.currentRide!,
        driver: (state as RideInProgressState).driver,
        messages: updatedMessages,
      ));
    }

    await repository.sendChatMessage(
      rideId: state.currentRide!.id,
      message: event.text,
    );
  }

  void _onReceiveChatMessage(
    ReceiveChatMessageEvent event,
    Emitter<RideState> emit,
  ) {
    final updatedMessages = List<ChatMessageModel>.from(state.messages)
      ..add(event.message);

    if (state is RideDriverAssignedState) {
      emit(RideDriverAssignedState(
        ride: state.currentRide!,
        driver: (state as RideDriverAssignedState).driver,
        messages: updatedMessages,
      ));
    } else if (state is RideInProgressState) {
      emit(RideInProgressState(
        ride: state.currentRide!,
        driver: (state as RideInProgressState).driver,
        messages: updatedMessages,
      ));
    }
  }

  Future<void> _onSubmitRideRating(
    SubmitRideRatingEvent event,
    Emitter<RideState> emit,
  ) async {
    if (state.currentRide == null) return;

    await repository.submitRating(
      rideId: state.currentRide!.id,
      rating: event.rating,
      tags: event.tags,
      comment: event.comment,
    );

    emit(const RideInitialState());
  }

  void _subscribeToRideUpdates(String rideId) {
    _driverLocationSub?.cancel();
    _rideStatusSub?.cancel();
    _chatMessagesSub?.cancel();

    _driverLocationSub = repository.watchDriverLocation(rideId).listen((driver) {
      add(DriverLocationUpdatedEvent(
        location: driver.currentLocation,
        etaMinutes: driver.etaMinutes,
        distanceKm: driver.distanceKm,
      ));
    });

    _rideStatusSub = repository.watchRideStatus(rideId).listen((ride) {
      add(RideStatusChangedEvent(ride.status));
    });

    _chatMessagesSub = repository.watchChatMessages(rideId).listen((msg) {
      add(ReceiveChatMessageEvent(msg));
    });
  }

  @override
  Future<void> close() {
    _driverLocationSub?.cancel();
    _rideStatusSub?.cancel();
    _chatMessagesSub?.cancel();
    return super.close();
  }
}
