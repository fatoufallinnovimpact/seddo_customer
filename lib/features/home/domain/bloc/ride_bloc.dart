import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seddo/features/home/domain/bloc/ride_event.dart';
import 'package:seddo/features/home/domain/bloc/ride_state.dart';
import 'package:seddo/features/home/domain/models/chat_message_model.dart';
import 'package:seddo/features/home/domain/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/ride_model.dart';
import 'package:seddo/features/home/domain/repositories/ride_repository.dart';

/// Central BLoC orchestrating the entire ride lifecycle for Seddo customer app.
/// Ready to connect to backend REST endpoints & Driver App WebSocket stream.
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

      // Listen to backend status updates & chat
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

    // Initial greeting from driver
    final initialMessage = ChatMessageModel(
      id: 'msg_welcome',
      sender: ChatSender.driver,
      text: 'Bonjour ! Je suis en route pour vous récupérer.',
      timestamp: DateTime.now(),
      isRead: true,
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
    if (state is RideDriverAssignedState) {
      final s = state as RideDriverAssignedState;
      final updatedDriver = s.driver.copyWith(
        currentLocation: event.location,
        etaMinutes: event.etaMinutes,
        distanceKm: event.distanceKm,
      );
      emit(RideDriverAssignedState(
        ride: s.currentRide!,
        driver: updatedDriver,
        messages: s.messages,
      ));
    } else if (state is RideInProgressState) {
      final s = state as RideInProgressState;
      final updatedDriver = s.driver.copyWith(
        currentLocation: event.location,
        etaMinutes: event.etaMinutes,
        distanceKm: event.distanceKm,
      );
      emit(RideInProgressState(
        ride: s.currentRide!,
        driver: updatedDriver,
        messages: s.messages,
      ));
    }
  }

  void _onRideStatusChanged(
    RideStatusChangedEvent event,
    Emitter<RideState> emit,
  ) {
    if (state.currentRide == null) return;

    final current = state.currentRide!;
    final driver = current.driver;

    switch (event.status) {
      case RideStatus.inProgress:
        if (driver != null) {
          emit(RideInProgressState(
            ride: current.copyWith(status: RideStatus.inProgress),
            driver: driver,
            messages: state.messages,
          ));
        }
        break;
      case RideStatus.completed:
        if (driver != null) {
          emit(RideCompletedState(
            ride: current.copyWith(
              status: RideStatus.completed,
              completedAt: DateTime.now(),
            ),
            driver: driver,
          ));
        }
        break;
      case RideStatus.cancelled:
        emit(RideCancelledState(
          ride: current.copyWith(status: RideStatus.cancelled),
        ));
        break;
      case RideStatus.noDriver:
        emit(RideNoDriverState(
          ride: current.copyWith(status: RideStatus.noDriver),
        ));
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
      final cancelled = await repository.cancelRide(
        rideId: state.currentRide!.id,
        reason: event.reason,
      );
      emit(RideCancelledState(ride: cancelled, reason: event.reason));
    } catch (_) {
      emit(RideCancelledState(
        ride: state.currentRide!.copyWith(status: RideStatus.cancelled),
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

    final newMessage = ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: ChatSender.customer,
      text: event.text,
      timestamp: DateTime.now(),
      isRead: true,
    );

    final updatedMessages = List<ChatMessageModel>.from(state.messages)
      ..add(newMessage);

    if (state is RideDriverAssignedState) {
      final s = state as RideDriverAssignedState;
      emit(RideDriverAssignedState(
        ride: s.currentRide!,
        driver: s.driver,
        messages: updatedMessages,
      ));
    } else if (state is RideInProgressState) {
      final s = state as RideInProgressState;
      emit(RideInProgressState(
        ride: s.currentRide!,
        driver: s.driver,
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
      final s = state as RideDriverAssignedState;
      emit(RideDriverAssignedState(
        ride: s.currentRide!,
        driver: s.driver,
        messages: updatedMessages,
      ));
    } else if (state is RideInProgressState) {
      final s = state as RideInProgressState;
      emit(RideInProgressState(
        ride: s.currentRide!,
        driver: s.driver,
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
    _driverLocationSub =
        repository.watchDriverLocation(rideId).listen((driver) {
      add(DriverLocationUpdatedEvent(
        location: driver.location,
        etaMinutes: driver.etaMinutes,
        distanceKm: driver.distanceKm,
      ));
    });

    _rideStatusSub?.cancel();
    _rideStatusSub = repository.watchRideStatus(rideId).listen((ride) {
      add(RideStatusChangedEvent(ride.status));
    });

    _chatMessagesSub?.cancel();
    _chatMessagesSub =
        repository.watchChatMessages(rideId).listen((message) {
      add(ReceiveChatMessageEvent(message));
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
