import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/chat_message_model.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';

abstract class RideEvent extends Equatable {
  const RideEvent();

  @override
  List<Object?> get props => [];
}

/// Customer confirms and requests a ride
class RequestRideEvent extends RideEvent {
  final PlaceSearchResult departure;
  final PlaceSearchResult destination;
  final RideOptionModel rideOption;
  final String paymentPhone;
  final String transactionRef;
  final List<LatLng> polylinePoints;

  const RequestRideEvent({
    required this.departure,
    required this.destination,
    required this.rideOption,
    required this.paymentPhone,
    required this.transactionRef,
    this.polylinePoints = const [],
  });

  @override
  List<Object?> get props => [
        departure,
        destination,
        rideOption,
        paymentPhone,
        transactionRef,
        polylinePoints,
      ];
}

/// Driver accepted ride notification (from Driver App / Backend push)
class DriverAssignedEvent extends RideEvent {
  final DriverModel driver;

  const DriverAssignedEvent(this.driver);

  @override
  List<Object?> get props => [driver];
}

/// Driver GPS position update received from Driver App
class DriverLocationUpdatedEvent extends RideEvent {
  final LatLng location;
  final int etaMinutes;
  final double distanceKm;

  const DriverLocationUpdatedEvent({
    required this.location,
    required this.etaMinutes,
    required this.distanceKm,
  });

  @override
  List<Object?> get props => [location, etaMinutes, distanceKm];
}

/// Ride lifecycle status changed (arrived, inProgress, completed, cancelled)
class RideStatusChangedEvent extends RideEvent {
  final RideStatus status;

  const RideStatusChangedEvent(this.status);

  @override
  List<Object?> get props => [status];
}

/// Customer cancels the ride
class CancelRideEvent extends RideEvent {
  final String reason;

  const CancelRideEvent({this.reason = 'Annulation client'});

  @override
  List<Object?> get props => [reason];
}

/// No driver available after timeout
class NoDriverFoundEvent extends RideEvent {
  const NoDriverFoundEvent();
}

/// Send in-app chat message to driver
class SendChatMessageEvent extends RideEvent {
  final String text;

  const SendChatMessageEvent(this.text);

  @override
  List<Object?> get props => [text];
}

/// Chat message received from driver
class ReceiveChatMessageEvent extends RideEvent {
  final ChatMessageModel message;

  const ReceiveChatMessageEvent(this.message);

  @override
  List<Object?> get props => [message];
}

/// Customer submits rating and tags
class SubmitRideRatingEvent extends RideEvent {
  final int rating;
  final List<String> tags;
  final String? comment;

  const SubmitRideRatingEvent({
    required this.rating,
    required this.tags,
    this.comment,
  });

  @override
  List<Object?> get props => [rating, tags, comment];
}
