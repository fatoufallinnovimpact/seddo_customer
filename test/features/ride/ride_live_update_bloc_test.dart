import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/domain/bloc/ride_live_update_bloc.dart';
import 'package:seddo/features/ride/domain/models/ride_live_update_data.dart';
import 'package:seddo/features/ride/domain/services/ride_live_update_service.dart';
import 'package:seddo/services/realtime_service.dart';

class MockRideLiveUpdateService implements RideLiveUpdateService {
  bool supported = true;
  bool enabled = true;
  String? lastStartedActivityId;
  RideLiveUpdateData? lastUpdatedData;
  bool ended = false;
  String? lastEndedRideId;

  final _pushTokenController = StreamController<String>.broadcast();
  final _pushToStartController = StreamController<String>.broadcast();

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> areActivitiesEnabled() async => enabled;

  @override
  Future<String?> startLiveUpdate(RideLiveUpdateData data) async {
    lastStartedActivityId = 'activity_test_123';
    lastUpdatedData = data;
    return lastStartedActivityId;
  }

  @override
  Future<void> updateLiveUpdate(RideLiveUpdateData data) async {
    lastUpdatedData = data;
  }

  @override
  Future<void> endLiveUpdate({required String rideId, RideLiveUpdateData? finalData}) async {
    ended = true;
    lastEndedRideId = rideId;
    if (finalData != null) {
      lastUpdatedData = finalData;
    }
  }

  @override
  Stream<String> get activityPushTokenStream => _pushTokenController.stream;

  @override
  Stream<String> get pushToStartTokenStream => _pushToStartController.stream;

  @override
  void dispose() {
    _pushTokenController.close();
    _pushToStartController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dummyDriver = DriverModel(
    id: 'drv_1',
    name: 'Moussa Diop',
    phone: '+221 77 123 45 67',
    rating: 4.9,
    totalRides: 450,
    carModel: 'Peugeot 301',
    licensePlate: 'DK-1234-AB',
    carColor: 'Gris',
    rideType: RideType.eco,
    currentLocation: LatLng(14.6937, -17.4647),
    etaMinutes: 6,
    distanceKm: 2.1,
  );

  const dummyDeparture = PlaceSearchResult(
    id: 'dep_1',
    mainText: 'Point E',
    secondaryText: 'Dakar',
    fullAddress: 'Point E, Dakar',
    latitude: 14.6937,
    longitude: -17.4647,
  );

  const dummyDestination = PlaceSearchResult(
    id: 'dest_1',
    mainText: 'Almadies',
    secondaryText: 'Dakar',
    fullAddress: 'Almadies, Dakar',
    latitude: 14.7431,
    longitude: -17.5195,
  );

  group('RideLiveUpdateBloc Tests', () {
    late MockRideLiveUpdateService mockService;
    late RealtimeService realtimeService;

    setUp(() {
      mockService = MockRideLiveUpdateService();
      realtimeService = RealtimeService();
    });

    tearDown(() {
      mockService.dispose();
    });

    test('Initial state is RideLiveUpdateInitialState', () {
      final bloc = RideLiveUpdateBloc(
        service: mockService,
        realtimeService: realtimeService,
      );
      expect(bloc.state, isA<RideLiveUpdateInitialState>());
      bloc.close();
    });

    blocTest<RideLiveUpdateBloc, RideLiveUpdateState>(
      'Emits RideLiveUpdateDisabledState when isSupported is false',
      build: () {
        mockService.supported = false;
        return RideLiveUpdateBloc(
          service: mockService,
          realtimeService: realtimeService,
        );
      },
      act: (bloc) => bloc.add(const InitializeLiveUpdateEvent(
        rideId: 'ride_101',
        driver: dummyDriver,
      )),
      expect: () => [
        isA<RideLiveUpdateDisabledState>(),
      ],
    );

    blocTest<RideLiveUpdateBloc, RideLiveUpdateState>(
      'Emits RideLiveUpdateDisabledState when areActivitiesEnabled is false',
      build: () {
        mockService.enabled = false;
        return RideLiveUpdateBloc(
          service: mockService,
          realtimeService: realtimeService,
        );
      },
      act: (bloc) => bloc.add(const InitializeLiveUpdateEvent(
        rideId: 'ride_101',
        driver: dummyDriver,
      )),
      expect: () => [
        isA<RideLiveUpdateDisabledState>(),
      ],
    );

    blocTest<RideLiveUpdateBloc, RideLiveUpdateState>(
      'Initializes successfully and emits RideLiveUpdateActiveState',
      build: () => RideLiveUpdateBloc(
        service: mockService,
        realtimeService: realtimeService,
      ),
      act: (bloc) => bloc.add(const InitializeLiveUpdateEvent(
        rideId: 'ride_101',
        driver: dummyDriver,
        departure: dummyDeparture,
        destination: dummyDestination,
      )),
      expect: () => [
        isA<RideLiveUpdateActiveState>().having(
          (s) => s.data.driverName,
          'driverName',
          'Moussa Diop',
        ).having(
          (s) => s.data.licensePlate,
          'licensePlate',
          'DK-1234-AB',
        ).having(
          (s) => s.activityId,
          'activityId',
          'activity_test_123',
        ),
      ],
      verify: (_) {
        expect(mockService.lastStartedActivityId, 'activity_test_123');
        expect(mockService.lastUpdatedData?.carColor, 'Gris');
      },
    );

    blocTest<RideLiveUpdateBloc, RideLiveUpdateState>(
      'Updates ETA and emits updated RideLiveUpdateActiveState',
      build: () => RideLiveUpdateBloc(
        service: mockService,
        realtimeService: realtimeService,
      ),
      seed: () => RideLiveUpdateActiveState(
        data: RideLiveUpdateData.initial(
          rideId: 'ride_101',
          driverName: 'Moussa Diop',
          carModel: 'Peugeot 301',
          carColor: 'Gris',
          licensePlate: 'DK-1234-AB',
          etaMinutes: 6,
        ),
        activityId: 'activity_test_123',
      ),
      act: (bloc) => bloc.add(const UpdateLiveUpdateEtaEvent(
        etaMinutes: 2,
        distanceKm: 0.6,
      )),
      expect: () => [
        isA<RideLiveUpdateActiveState>().having(
          (s) => s.data.etaMinutes,
          'etaMinutes',
          2,
        ),
      ],
    );

    blocTest<RideLiveUpdateBloc, RideLiveUpdateState>(
      'Ends activity and emits RideLiveUpdateEndedState when course is COMPLETED',
      build: () => RideLiveUpdateBloc(
        service: mockService,
        realtimeService: realtimeService,
      ),
      seed: () => RideLiveUpdateActiveState(
        data: RideLiveUpdateData.initial(
          rideId: 'ride_101',
          driverName: 'Moussa Diop',
          carModel: 'Peugeot 301',
          carColor: 'Gris',
          licensePlate: 'DK-1234-AB',
        ),
        activityId: 'activity_test_123',
      ),
      act: (bloc) => bloc.add(const UpdateLiveUpdateStatusEvent(
        status: 'COMPLETED',
      )),
      expect: () => [
        isA<RideLiveUpdateEndedState>().having(
          (s) => s.rideId,
          'rideId',
          'ride_101',
        ).having(
          (s) => s.reason,
          'reason',
          'Course terminée',
        ),
      ],
      verify: (_) {
        expect(mockService.ended, isTrue);
        expect(mockService.lastEndedRideId, 'ride_101');
      },
    );

    blocTest<RideLiveUpdateBloc, RideLiveUpdateState>(
      'Ends activity and emits RideLiveUpdateEndedState when course is CANCELLED',
      build: () => RideLiveUpdateBloc(
        service: mockService,
        realtimeService: realtimeService,
      ),
      seed: () => RideLiveUpdateActiveState(
        data: RideLiveUpdateData.initial(
          rideId: 'ride_101',
          driverName: 'Moussa Diop',
          carModel: 'Peugeot 301',
          carColor: 'Gris',
          licensePlate: 'DK-1234-AB',
        ),
        activityId: 'activity_test_123',
      ),
      act: (bloc) => bloc.add(const UpdateLiveUpdateStatusEvent(
        status: 'CANCELLED_BY_CUSTOMER',
      )),
      expect: () => [
        isA<RideLiveUpdateEndedState>().having(
          (s) => s.rideId,
          'rideId',
          'ride_101',
        ).having(
          (s) => s.reason,
          'reason',
          'Course annulée',
        ),
      ],
      verify: (_) {
        expect(mockService.ended, isTrue);
      },
    );

    blocTest<RideLiveUpdateBloc, RideLiveUpdateState>(
      'Dismisses live update on DismissLiveUpdateEvent',
      build: () => RideLiveUpdateBloc(
        service: mockService,
        realtimeService: realtimeService,
      ),
      seed: () => RideLiveUpdateActiveState(
        data: RideLiveUpdateData.initial(
          rideId: 'ride_101',
          driverName: 'Moussa Diop',
          carModel: 'Peugeot 301',
          carColor: 'Gris',
          licensePlate: 'DK-1234-AB',
        ),
        activityId: 'activity_test_123',
      ),
      act: (bloc) => bloc.add(const DismissLiveUpdateEvent(reason: 'Test dismissal')),
      expect: () => [
        isA<RideLiveUpdateEndedState>().having(
          (s) => s.reason,
          'reason',
          'Test dismissal',
        ),
      ],
      verify: (_) {
        expect(mockService.ended, isTrue);
      },
    );
  });
}
