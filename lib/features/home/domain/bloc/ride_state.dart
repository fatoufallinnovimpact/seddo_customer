import 'package:equatable/equatable.dart';
import 'package:seddo/features/home/domain/models/chat_message_model.dart';
import 'package:seddo/features/home/domain/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/ride_model.dart';

abstract class RideState extends Equatable {
  final RideModel? currentRide;
  final List<ChatMessageModel> messages;

  const RideState({
    this.currentRide,
    this.messages = const [],
  });

  @override
  List<Object?> get props => [currentRide, messages];
}

/// Initial state before any ride is ordered
class RideInitialState extends RideState {
  const RideInitialState() : super();
}

/// Searching for nearby drivers (Screenshot 3)
class RideSearchingState extends RideState {
  final int candidateDriversCount;

  const RideSearchingState({
    required RideModel ride,
    this.candidateDriversCount = 6,
  }) : super(currentRide: ride);

  @override
  List<Object?> get props => [currentRide, candidateDriversCount];
}

/// Driver accepted ride and is en route to pickup (Phase 1)
class RideDriverAssignedState extends RideState {
  final DriverModel driver;

  const RideDriverAssignedState({
    required RideModel ride,
    required this.driver,
    super.messages = const [],
  }) : super(currentRide: ride);

  @override
  List<Object?> get props => [currentRide, driver, messages];
}

/// Customer is picked up and en route to destination (Screenshot 1: Phase 2)
class RideInProgressState extends RideState {
  final DriverModel driver;

  const RideInProgressState({
    required RideModel ride,
    required this.driver,
    super.messages = const [],
  }) : super(currentRide: ride);

  @override
  List<Object?> get props => [currentRide, driver, messages];
}

/// Destination reached, showing rating sheet (Screenshot 3)
class RideCompletedState extends RideState {
  final DriverModel driver;

  const RideCompletedState({
    required RideModel ride,
    required this.driver,
  }) : super(currentRide: ride);

  @override
  List<Object?> get props => [currentRide, driver];
}

/// Ride cancelled by customer, refund processed (Screenshot 4)
class RideCancelledState extends RideState {
  final String reason;

  const RideCancelledState({
    required RideModel ride,
    this.reason = 'Annulation client',
  }) : super(currentRide: ride);

  @override
  List<Object?> get props => [currentRide, reason];
}

/// No driver available, refund processed (Screenshot 2)
class RideNoDriverState extends RideState {
  const RideNoDriverState({
    required RideModel ride,
  }) : super(currentRide: ride);
}

/// Network or API error occurred
class RideErrorState extends RideState {
  final String errorMessage;

  const RideErrorState({
    RideModel? ride,
    required this.errorMessage,
  }) : super(currentRide: ride);

  @override
  List<Object?> get props => [currentRide, errorMessage];
}
