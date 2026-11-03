import 'package:equatable/equatable.dart';
import 'package:seddo/features/ride/domain/models/ride_live_update_data.dart';

abstract class RideLiveUpdateState extends Equatable {
  const RideLiveUpdateState();

  @override
  List<Object?> get props => [];
}

/// Initial dormant state before any ride is active
class RideLiveUpdateInitialState extends RideLiveUpdateState {
  const RideLiveUpdateInitialState();
}

/// State emitted when device doesn't support or user has disabled Live Activities
class RideLiveUpdateDisabledState extends RideLiveUpdateState {
  final String reason;

  const RideLiveUpdateDisabledState({required this.reason});

  @override
  List<Object?> get props => [reason];
}

/// State emitted when a live activity is currently active and presenting updates
class RideLiveUpdateActiveState extends RideLiveUpdateState {
  final RideLiveUpdateData data;
  final String? activityId;

  const RideLiveUpdateActiveState({
    required this.data,
    this.activityId,
  });

  RideLiveUpdateActiveState copyWith({
    RideLiveUpdateData? data,
    String? activityId,
  }) {
    return RideLiveUpdateActiveState(
      data: data ?? this.data,
      activityId: activityId ?? this.activityId,
    );
  }

  @override
  List<Object?> get props => [data, activityId];
}

/// State emitted when the ride has ended or was cancelled and the live activity is dismissed
class RideLiveUpdateEndedState extends RideLiveUpdateState {
  final String rideId;
  final String? reason;

  const RideLiveUpdateEndedState({
    required this.rideId,
    this.reason,
  });

  @override
  List<Object?> get props => [rideId, reason];
}
