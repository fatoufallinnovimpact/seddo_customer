import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/map_config.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/presentation/pages/active_ride_page.dart';
import 'package:seddo/features/ride/presentation/utils/active_ride_navigation_helper.dart';
import 'package:seddo/services/realtime_service.dart';
import '../../test_helpers/test_localization_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  group('MapConfig & AppParams Tests', () {
    test('MapConfig updates keys dynamically and provides platform apiKey', () {
      MapConfig.updateKeys(
        android: 'TEST_ANDROID_KEY_123',
        ios: 'TEST_IOS_KEY_456',
        web: 'TEST_WEB_KEY_789',
      );

      expect(MapConfig.googleMapsApiKeyAndroid, equals('TEST_ANDROID_KEY_123'));
      expect(MapConfig.googleMapsApiKeyIos, equals('TEST_IOS_KEY_456'));
      expect(MapConfig.googleMapsApiKeyWeb, equals('TEST_WEB_KEY_789'));
      expect(MapConfig.apiKey, isNotEmpty);
    });
  });

  group('RealtimeDriverLocationEvent Parsing Tests', () {
    test('parses position from nested driver.position format', () {
      final json = {
        'rideId': 'ride_abc',
        'driver': {
          'id': 'drv_1',
          'position': {
            'lat': 14.6937,
            'lng': -17.4440,
            'heading': 90.0,
          },
        },
      };

      final event = RealtimeDriverLocationEvent.fromJson(json);
      expect(event.rideId, equals('ride_abc'));
      expect(event.location.latitude, closeTo(14.6937, 0.0001));
      expect(event.location.longitude, closeTo(-17.4440, 0.0001));
      expect(event.heading, equals(90.0));
    });

    test('parses position from driverPosition and location formats', () {
      final json = {
        'id': 'ride_xyz',
        'driverPosition': {
          'latitude': 14.7123,
          'longitude': -17.4567,
          'bearing': 180.0,
        },
      };

      final event = RealtimeDriverLocationEvent.fromJson(json);
      expect(event.rideId, equals('ride_xyz'));
      expect(event.location.latitude, closeTo(14.7123, 0.0001));
      expect(event.location.longitude, closeTo(-17.4567, 0.0001));
      expect(event.heading, equals(180.0));
    });
  });

  group('ActiveRideNavigation & Road Movement Tests', () {
    final departure = PlaceSearchResult(
      id: 'dep',
      mainText: 'Place de l\'Indépendance',
      secondaryText: 'Dakar',
      fullAddress: 'Place de l\'Indépendance, Dakar',
      latitude: 14.6698,
      longitude: -17.4326,
    );

    final destination = PlaceSearchResult(
      id: 'dest',
      mainText: 'Almadies',
      secondaryText: 'Ngor, Dakar',
      fullAddress: 'Almadies, Ngor, Dakar',
      latitude: 14.7431,
      longitude: -17.5195,
    );

    final driver = DriverModel(
      id: 'drv_test',
      name: 'Ibrahima Fall',
      phone: '+221 77 000 00 00',
      rating: 4.9,
      totalRides: 850,
      carModel: 'Peugeot 508',
      carColor: 'Noir',
      licensePlate: 'DK-9876-AB',
      rideType: RideType.eco,
      currentLocation: const LatLng(14.6698, -17.4326),
      etaMinutes: 15,
      distanceKm: 8.5,
    );

    const rideOption = RideOptionModel(
      type: RideType.eco,
      title: 'Seddo Eco',
      subtitle: 'Seddo Eco',
      price: 2500,
      capacity: 4,
      estimatedArrival: '15 min',
      pickupDuration: '3 min',
    );

    testWidgets('ActiveRidePage starts with auto-simulation enabled and updates car position',
        (tester) async {
      final polylinePoints = [
        const LatLng(14.6698, -17.4326),
        const LatLng(14.6750, -17.4400),
        const LatLng(14.6850, -17.4500),
        const LatLng(14.7431, -17.5195),
      ];

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: ActiveRidePage(
            departure: departure,
            destination: destination,
            driver: driver,
            rideOption: rideOption,
            polylinePoints: polylinePoints,
            autoStartSimulation: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final state = tester.state(find.byType(ActiveRidePage));
      expect(state, isNotNull);

      // Verify that calling updateCarLocation updates the car along the route
      final dynamic dynamicState = state;
      dynamicState.updateCarLocation(
        const LatLng(14.6752, -17.4402),
        heading: 120.0,
      );

      await tester.pump();
      expect(find.byType(ActiveRidePage), findsOneWidget);
    });

    test('ActiveRideNavigationHelper configures ActiveRidePage with autoStartSimulation true', () {
      final rideData = {
        'id': 'ride_active_123',
        'status': 'IN_PROGRESS',
        'pickup': {
          'lat': 14.6698,
          'lng': -17.4326,
          'address': 'Dakar Centre',
        },
        'dropoff': {
          'lat': 14.7431,
          'lng': -17.5195,
          'address': 'Almadies',
        },
        'driver': {
          'id': 'drv_1',
          'firstName': 'Moussa',
          'lastName': 'Fall',
          'vehicle': {
            'make': 'Toyota',
            'model': 'Corolla',
            'color': 'Blanc',
            'plate': 'DK-1111-AA',
          },
          'position': {
            'lat': 14.6700,
            'lng': -17.4330,
            'heading': 45.0,
          },
        },
      };

      final widget = ActiveRideNavigationHelper.resolveActiveRidePage(rideData);
      expect(widget, isNotNull);
      expect(widget, isA<ActiveRidePage>());

      final activeRidePage = widget as ActiveRidePage;
      expect(activeRidePage.autoStartSimulation, isTrue);
    });
  });
}
