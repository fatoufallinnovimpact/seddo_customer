import 'dart:async';
import 'package:seddo/features/home/data/providers/ride_api_provider.dart';
import 'package:seddo/features/home/domain/models/chat_message_model.dart';
import 'package:seddo/features/home/domain/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/domain/models/ride_model.dart';
import 'package:seddo/features/home/domain/models/ride_option_model.dart';
import 'package:seddo/features/home/domain/repositories/ride_repository.dart';

/// Implementation of RideRepository combining RideApiProvider with reactive streams
class RideRepositoryImpl implements RideRepository {
  final RideApiProvider _apiProvider;
  final _driverLocationController = StreamController<DriverModel>.broadcast();
  final _rideStatusController = StreamController<RideModel>.broadcast();
  final _chatMessagesController =
      StreamController<ChatMessageModel>.broadcast();

  RideModel? _currentRide;

  RideRepositoryImpl({RideApiProvider? apiProvider})
      : _apiProvider = apiProvider ?? RideApiProvider();

  @override
  Future<RideModel> requestRide({
    required PlaceSearchResult departure,
    required PlaceSearchResult destination,
    required RideOptionModel rideOption,
    required String paymentPhone,
    required String transactionRef,
  }) async {
    final ride = await _apiProvider.requestRide(
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

  @override
  Future<RideModel> cancelRide({
    required String rideId,
    required String reason,
  }) async {
    final current = _currentRide ??
        RideModel(
          id: rideId,
          departure: PlaceSearchResult(
            id: 'dep',
            mainText: '',
            secondaryText: '',
            fullAddress: '',
            latitude: 14.6937,
            longitude: -17.4647,
          ),
          destination: PlaceSearchResult(
            id: 'dest',
            mainText: '',
            secondaryText: '',
            fullAddress: '',
            latitude: 14.7431,
            longitude: -17.5195,
          ),
          rideOption: RideOptionModel(
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

    final cancelled = await _apiProvider.cancelRide(
      rideId: rideId,
      reason: reason,
      currentRide: current,
    );
    _currentRide = cancelled;
    _rideStatusController.add(cancelled);
    return cancelled;
  }

  @override
  Stream<DriverModel> watchDriverLocation(String rideId) {
    return _driverLocationController.stream;
  }

  @override
  Stream<RideModel> watchRideStatus(String rideId) {
    return _rideStatusController.stream;
  }

  @override
  Future<void> sendChatMessage({
    required String rideId,
    required String message,
  }) async {
    final sent = await _apiProvider.sendChatMessage(
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

  @override
  Stream<ChatMessageModel> watchChatMessages(String rideId) {
    return _chatMessagesController.stream;
  }

  @override
  Future<void> submitRating({
    required String rideId,
    required int rating,
    required List<String> tags,
    String? comment,
  }) async {
    await _apiProvider.submitRating(
      rideId: rideId,
      rating: rating,
      tags: tags,
      comment: comment,
    );
  }

  void dispose() {
    _driverLocationController.close();
    _rideStatusController.close();
    _chatMessagesController.close();
  }
}
