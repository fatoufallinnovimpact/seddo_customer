import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/ride/domain/bloc/ride_bloc.dart';
import 'package:seddo/features/ride/data/models/chat_message_model.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/ride_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/repositories/ride_repository.dart';

const dummyDeparture = PlaceSearchResult(
  id: 'dep_1',
  mainText: 'Point E',
  secondaryText: 'Dakar, Sénégal',
  fullAddress: 'Rue de Louga, Point E, Dakar',
  latitude: 14.6937,
  longitude: -17.4719,
);

const dummyDestination = PlaceSearchResult(
  id: 'dest_1',
  mainText: 'Almadies',
  secondaryText: 'Dakar, Sénégal',
  fullAddress: 'Route des Almadies, Dakar',
  latitude: 14.7431,
  longitude: -17.5186,
);

const dummyOption = RideOptionModel(
  type: RideType.eco,
  title: 'Seddo Eco',
  subtitle: 'Citadine · 4 places',
  capacity: 4,
  price: 2100,
  estimatedArrival: '18:41',
  pickupDuration: '2 min',
);

const dummyDriver = DriverModel(
  id: 'drv_1',
  name: 'Moussa Sall',
  phone: '+221 77 123 45 67',
  rating: 4.9,
  totalRides: 1240,
  carModel: 'Peugeot 301',
  licensePlate: 'DK-4589-AZ',
  carColor: 'Gris métallisé',
  rideType: RideType.eco,
  currentLocation: LatLng(14.6950, -17.4700),
  etaMinutes: 3,
  distanceKm: 0.8,
);

class MockRideRepository implements RideRepository {
  final _driverLocationController = StreamController<DriverModel>.broadcast();
  final _rideStatusController = StreamController<RideModel>.broadcast();
  final _chatMessagesController = StreamController<ChatMessageModel>.broadcast();

  RideModel? lastRequestedRide;
  bool cancelRideCalled = false;
  bool submitRatingCalled = false;
  String? sentChatMessage;

  @override
  Future<RideModel> requestRide({
    required PlaceSearchResult departure,
    required PlaceSearchResult destination,
    required RideOptionModel rideOption,
    required String paymentPhone,
    required String transactionRef,
  }) async {
    final ride = RideModel(
      id: 'ride_test_123',
      departure: departure,
      destination: destination,
      rideOption: rideOption,
      paymentPhone: paymentPhone,
      transactionRef: transactionRef,
      createdAt: DateTime.now(),
      status: RideStatus.searching,
    );
    lastRequestedRide = ride;
    return ride;
  }

  @override
  Future<RideModel> cancelRide({
    required String rideId,
    required String reason,
  }) async {
    cancelRideCalled = true;
    final ride = lastRequestedRide ??
        RideModel(
          id: rideId,
          departure: dummyDeparture,
          destination: dummyDestination,
          rideOption: dummyOption,
          createdAt: DateTime.now(),
          status: RideStatus.cancelled,
        );
    return ride.copyWith(status: RideStatus.cancelled);
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
  Stream<ChatMessageModel> watchChatMessages(String rideId) {
    return _chatMessagesController.stream;
  }

  @override
  Future<void> sendChatMessage({
    required String rideId,
    required String message,
  }) async {
    sentChatMessage = message;
    _chatMessagesController.add(
      ChatMessageModel(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: ChatSender.customer,
        text: message,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> submitRating({
    required String rideId,
    required int rating,
    required List<String> tags,
    String? comment,
  }) async {
    submitRatingCalled = true;
  }

  @override
  DriverModel getDemoDriver(RideOptionModel rideOption) {
    return dummyDriver;
  }

  void emitDriverLocation(DriverModel driver) {
    _driverLocationController.add(driver);
  }

  void emitRideStatus(RideModel ride) {
    _rideStatusController.add(ride);
  }

  void emitIncomingMessage(ChatMessageModel message) {
    _chatMessagesController.add(message);
  }

  @override
  void dispose() {
    _driverLocationController.close();
    _rideStatusController.close();
    _chatMessagesController.close();
  }
}

void main() {
  group('RideBloc Architecture & Lifecycle Tests', () {
    late MockRideRepository repository;
    late RideBloc rideBloc;

    setUp(() {
      repository = MockRideRepository();
      rideBloc = RideBloc(repository: repository);
    });

    tearDown(() {
      rideBloc.close();
      repository.dispose();
    });

    test('Initial state is RideInitialState', () {
      expect(rideBloc.state, isA<RideInitialState>());
    });

    test('RequestRideEvent transitions to RideSearchingState and calls repository', () async {
      rideBloc.add(const RequestRideEvent(
        departure: dummyDeparture,
        destination: dummyDestination,
        rideOption: dummyOption,
        paymentPhone: '77 123 45 12',
        transactionRef: 'CI270415.1902.C4D1',
      ));

      await expectLater(
        rideBloc.stream,
        emitsInOrder([
          isA<RideSearchingState>(),
        ]),
      );

      expect(repository.lastRequestedRide, isNotNull);
      expect(repository.lastRequestedRide!.status, RideStatus.searching);
      expect(repository.lastRequestedRide!.departure.mainText, 'Point E');
      expect(repository.lastRequestedRide!.destination.mainText, 'Almadies');
    });

    test('DriverAssignedEvent transitions to RideDriverAssignedState with welcome message', () async {
      rideBloc.add(const RequestRideEvent(
        departure: dummyDeparture,
        destination: dummyDestination,
        rideOption: dummyOption,
        paymentPhone: '77 123 45 12',
        transactionRef: 'CI270415.1902.C4D1',
      ));

      await pumpEventQueue();

      rideBloc.add(const DriverAssignedEvent(dummyDriver));

      await expectLater(
        rideBloc.stream,
        emitsInOrder([
          predicate<RideState>((state) {
            if (state is! RideDriverAssignedState) return false;
            return state.driver.name == 'Moussa Sall' &&
                state.messages.isNotEmpty &&
                state.messages.first.sender == ChatSender.driver;
          }),
        ]),
      );
    });

    test('DriverLocationUpdatedEvent updates driver position and ETA in real-time from Driver App', () async {
      rideBloc.add(const RequestRideEvent(
        departure: dummyDeparture,
        destination: dummyDestination,
        rideOption: dummyOption,
        paymentPhone: '77 123 45 12',
        transactionRef: 'CI270415.1902.C4D1',
      ));
      await pumpEventQueue();

      rideBloc.add(const DriverAssignedEvent(dummyDriver));
      await pumpEventQueue();

      // Location update received from driver app
      const updatedLocation = LatLng(14.6942, -17.4710);
      rideBloc.add(const DriverLocationUpdatedEvent(
        location: updatedLocation,
        etaMinutes: 1,
        distanceKm: 0.3,
      ));

      await expectLater(
        rideBloc.stream,
        emitsInOrder([
          predicate<RideState>((state) {
            if (state is! RideDriverAssignedState) return false;
            return state.driver.location.latitude == updatedLocation.latitude &&
                state.driver.etaMinutes == 1 &&
                state.driver.distanceKm == 0.3;
          }),
        ]),
      );
    });

    test('SendChatMessageEvent sends message and appends it to state', () async {
      rideBloc.add(const RequestRideEvent(
        departure: dummyDeparture,
        destination: dummyDestination,
        rideOption: dummyOption,
        paymentPhone: '77 123 45 12',
        transactionRef: 'CI270415.1902.C4D1',
      ));
      await pumpEventQueue();
      rideBloc.add(const DriverAssignedEvent(dummyDriver));
      await pumpEventQueue();

      rideBloc.add(const SendChatMessageEvent('Je suis devant le portail blanc'));

      await expectLater(
        rideBloc.stream,
        emitsInOrder([
          predicate<RideState>((state) {
            if (state is! RideDriverAssignedState) return false;
            return state.messages.any((m) =>
                m.sender == ChatSender.customer &&
                m.text == 'Je suis devant le portail blanc');
          }),
        ]),
      );

      expect(repository.sentChatMessage, 'Je suis devant le portail blanc');
    });

    test('CancelRideEvent updates status to cancelled and invokes repository', () async {
      rideBloc.add(const RequestRideEvent(
        departure: dummyDeparture,
        destination: dummyDestination,
        rideOption: dummyOption,
        paymentPhone: '77 123 45 12',
        transactionRef: 'CI270415.1902.C4D1',
      ));
      await pumpEventQueue();

      rideBloc.add(const CancelRideEvent(reason: 'Attente trop longue'));

      await expectLater(
        rideBloc.stream,
        emitsInOrder([
          predicate<RideState>((state) {
            if (state is! RideCancelledState) return false;
            return state.reason == 'Attente trop longue';
          }),
        ]),
      );

      expect(repository.cancelRideCalled, isTrue);
    });

    test('SubmitRideRatingEvent sends rating and returns to RideInitialState', () async {
      rideBloc.add(const RequestRideEvent(
        departure: dummyDeparture,
        destination: dummyDestination,
        rideOption: dummyOption,
        paymentPhone: '77 123 45 12',
        transactionRef: 'CI270415.1902.C4D1',
      ));
      await pumpEventQueue();
      rideBloc.add(const DriverAssignedEvent(dummyDriver));
      await pumpEventQueue();

      rideBloc.add(const SubmitRideRatingEvent(
        rating: 5,
        tags: ['👍 Conduite prudente', 'Voiture propre'],
        comment: 'Super trajet !',
      ));

      await expectLater(
        rideBloc.stream,
        emitsInOrder([
          isA<RideInitialState>(),
        ]),
      );

      expect(repository.submitRatingCalled, isTrue);
    });
  });
}
