import 'dart:async';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/chat_message_model.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';

/// Repository for the Ride feature.
/// Handles business logic, reactive streams and remote data access for RideBloc.
/// Follows Innov & Impact Africa guidelines (data/repositories/).
class RideRepository {
  final RideService _service;
  final _driverLocationController = StreamController<DriverModel>.broadcast();
  final _rideStatusController = StreamController<RideModel>.broadcast();
  final _chatMessagesController =
      StreamController<ChatMessageModel>.broadcast();

  RideModel? _currentRide;

  RideRepository({RideService? service}) : _service = service ?? RideService();

  Future<RideModel> requestRide({
    required PlaceSearchResult departure,
    required PlaceSearchResult destination,
    required RideOptionModel rideOption,
    required String paymentPhone,
    required String transactionRef,
  }) async {
    final ride = await _service.requestRide(
      departure: departure,
      destination: destination,
      rideOption: rideOption,
      paymentPhone: paymentPhone,
      transactionRef: transactionRef,
    );
    _currentRide = ride;
    _rideStatusController.add(ride);
    return ride;
  }

  Future<RideModel> cancelRide({
    required String rideId,
    required String reason,
  }) async {
    final current = _currentRide ??
        RideModel(
          id: rideId,
          departure: const PlaceSearchResult(
            id: 'dep',
            mainText: '',
            secondaryText: '',
            fullAddress: '',
            latitude: 14.6937,
            longitude: -17.4647,
          ),
          destination: const PlaceSearchResult(
            id: 'dest',
            mainText: '',
            secondaryText: '',
            fullAddress: '',
            latitude: 14.7431,
            longitude: -17.5195,
          ),
          rideOption: const RideOptionModel(
            type: RideType.eco,
            title: 'Seddo Eco',
            subtitle: '',
            capacity: 4,
            price: 3500,
            estimatedArrival: '',
            pickupDuration: '',
          ),
          createdAt: DateTime.now(),
        );

    final cancelled = await _service.cancelRide(
      rideId: rideId,
      reason: reason,
      currentRide: current,
    );
    _currentRide = cancelled;
    _rideStatusController.add(cancelled);
    return cancelled;
  }

  Stream<DriverModel> watchDriverLocation(String rideId) {
    return _driverLocationController.stream;
  }

  Stream<RideModel> watchRideStatus(String rideId) {
    return _rideStatusController.stream;
  }

  Future<void> sendChatMessage({
    required String rideId,
    required String message,
  }) async {
    final sent = await _service.sendChatMessage(
      rideId: rideId,
      message: message,
    );
    if (sent) {
      _chatMessagesController.add(
        ChatMessageModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: ChatSender.customer,
          text: message,
          timestamp: DateTime.now(),
          isRead: true,
        ),
      );
    }
  }

  Stream<ChatMessageModel> watchChatMessages(String rideId) {
    return _chatMessagesController.stream;
  }

  Future<void> submitRating({
    required String rideId,
    required int rating,
    required List<String> tags,
    String? comment,
  }) async {
    await _service.submitRating(
      rideId: rideId,
      rating: rating,
      tags: tags,
      comment: comment,
    );
  }

  DriverModel getDemoDriver(RideOptionModel rideOption) {
    return _service.getDemoDriver(rideOption);
  }

  void dispose() {
    _driverLocationController.close();
    _rideStatusController.close();
    _chatMessagesController.close();
  }
}
