import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/services/realtime_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RealtimeService Event Parsing & Filtering Tests', () {
    late RealtimeService realtimeService;

    setUp(() {
      realtimeService = RealtimeService();
      realtimeService.resetForTesting();
    });

    test('ride.status parses accepted status and driver correctly', () async {
      RealtimeRideStatusEvent? receivedEvent;
      final sub = realtimeService.rideStatusStream.listen((event) {
        receivedEvent = event;
      });

      realtimeService.emitMockEvent('ride.status', {
        'rideId': 'ride_123',
        'status': 'ACCEPTED',
        'version': 1,
        'code': '8421',
        'driver': {
          'id': 'drv_456',
          'name': 'Amadou Diallo',
          'phone': '+221 77 999 88 77',
          'carModel': 'Peugeot 301',
          'carColor': 'Gris',
          'licensePlate': 'DK-1234-AA',
          'rating': 4.95,
          'lat': 14.6937,
          'lng': -17.4647,
        },
      });

      await pumpEventQueue();

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.rideId, 'ride_123');
      expect(receivedEvent!.status, 'ACCEPTED');
      expect(receivedEvent!.departureCode, '8421');
      expect(receivedEvent!.driver, isNotNull);
      expect(receivedEvent!.driver!.name, 'Amadou Diallo');
      expect(receivedEvent!.driver!.carModel, 'Peugeot 301');

      await sub.cancel();
    });

    test('ride.status ignores older versions (out-of-order)', () async {
      final List<String> statuses = [];
      final sub = realtimeService.rideStatusStream.listen((event) {
        statuses.add(event.status);
      });

      // Version 2 arrives first
      realtimeService.emitMockEvent('ride.status', {
        'rideId': 'ride_abc',
        'status': 'ACCEPTED',
        'version': 2,
      });

      await pumpEventQueue();

      // Older version 1 arrives late -> should be ignored
      realtimeService.emitMockEvent('ride.status', {
        'rideId': 'ride_abc',
        'status': 'PENDING',
        'version': 1,
      });

      await pumpEventQueue();

      expect(statuses.length, 1);
      expect(statuses.first, 'ACCEPTED');

      await sub.cancel();
    });

    test('driver.location filters out accuracy > 50m and out-of-order timestamps', () async {
      final List<LatLng> locations = [];
      final sub = realtimeService.driverLocationStream.listen((event) {
        locations.add(event.location);
      });

      final now = DateTime.now();

      // Valid position
      realtimeService.emitMockEvent('driver.location', {
        'rideId': 'ride_loc_test',
        'lat': 14.7001,
        'lng': -17.4601,
        'accuracy': 15.0,
        'timestamp': now.toIso8601String(),
      });

      await pumpEventQueue();

      // Inaccurate position (> 50m) -> should be discarded
      realtimeService.emitMockEvent('driver.location', {
        'rideId': 'ride_loc_test',
        'lat': 14.7050,
        'lng': -17.4650,
        'accuracy': 65.0, // > 50m !
        'timestamp': now.add(const Duration(seconds: 4)).toIso8601String(),
      });

      await pumpEventQueue();

      // Older timestamp -> should be discarded
      realtimeService.emitMockEvent('driver.location', {
        'rideId': 'ride_loc_test',
        'lat': 14.6990,
        'lng': -17.4590,
        'accuracy': 10.0,
        'timestamp': now.subtract(const Duration(seconds: 10)).toIso8601String(),
      });

      await pumpEventQueue();

      expect(locations.length, 1);
      expect(locations.first.latitude, 14.7001);

      await sub.cancel();
    });

    test('ride.eta calculates etaMinutes and transmits distance', () async {
      RealtimeRideEtaEvent? etaEvent;
      final sub = realtimeService.rideEtaStream.listen((event) {
        etaEvent = event;
      });

      realtimeService.emitMockEvent('ride.eta', {
        'rideId': 'ride_eta_1',
        'durationS': 240, // 4 minutes
        'distanceM': 1800,
        'version': 1,
      });

      await pumpEventQueue();

      expect(etaEvent, isNotNull);
      expect(etaEvent!.durationSeconds, 240);
      expect(etaEvent!.etaMinutes, 4);
      expect(etaEvent!.distanceMeters, 1800);

      await sub.cancel();
    });

    test('nearby.drivers parses anonymous driver list', () async {
      List<dynamic>? cars;
      final sub = realtimeService.nearbyDriversStream.listen((event) {
        cars = event;
      });

      realtimeService.emitMockEvent('nearby.drivers', {
        'cars': [
          {'id': 'c1', 'lat': 14.701, 'lng': -17.461, 'heading': 90.0},
          {'id': 'c2', 'lat': 14.702, 'lng': -17.462, 'heading': 180.0},
        ],
      });

      await pumpEventQueue();

      expect(cars, isNotNull);
      expect(cars!.length, 2);

      await sub.cancel();
    });

    test('chat.message parses incoming message in real time', () async {
      dynamic chatMsg;
      final sub = realtimeService.chatMessageStream.listen((event) {
        chatMsg = event;
      });

      realtimeService.emitMockEvent('chat.message', {
        'id': 'msg_001',
        'body': 'Je suis garé devant la pharmacie',
        'sender': 'driver',
        'createdAt': DateTime.now().toIso8601String(),
      });

      await pumpEventQueue();

      expect(chatMsg, isNotNull);
      expect(chatMsg.text, 'Je suis garé devant la pharmacie');

      await sub.cancel();
    });
  });
}
