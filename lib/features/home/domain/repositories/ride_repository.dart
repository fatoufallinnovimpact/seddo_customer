import 'package:seddo/features/home/domain/models/chat_message_model.dart';
import 'package:seddo/features/home/domain/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/domain/models/ride_model.dart';
import 'package:seddo/features/home/domain/models/ride_option_model.dart';

/// Clean repository contract ready for backend integration with Customer & Driver apps
abstract class RideRepository {
  /// Request a new ride with Orange Money payment details
  Future<RideModel> requestRide({
    required PlaceSearchResult departure,
    required PlaceSearchResult destination,
    required RideOptionModel rideOption,
    required String paymentPhone,
    required String transactionRef,
  });

  /// Cancel an ongoing or searching ride
  Future<RideModel> cancelRide({
    required String rideId,
    required String reason,
  });

  /// Stream of real-time driver GPS locations from the Driver App / Backend WebSocket
  Stream<DriverModel> watchDriverLocation(String rideId);

  /// Stream of ride status updates (searching, driverAssigned, inProgress, completed, cancelled)
  Stream<RideModel> watchRideStatus(String rideId);

  /// Send in-app chat message to the driver
  Future<void> sendChatMessage({
    required String rideId,
    required String message,
  });

  /// Stream of chat messages between customer and driver
  Stream<ChatMessageModel> watchChatMessages(String rideId);

  /// Submit driver rating and feedback after completion
  Future<void> submitRating({
    required String rideId,
    required int rating,
    required List<String> tags,
    String? comment,
  });
}
