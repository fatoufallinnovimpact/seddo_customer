import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/features/ride/presentation/pages/active_ride_page.dart';
import 'package:seddo/features/ride/presentation/pages/driver_approaching_page.dart';
import 'package:seddo/features/ride/presentation/pages/driver_search_page.dart';
import 'package:seddo/features/ride/presentation/utils/active_ride_navigation_helper.dart';

void main() {
  group('ActiveRideNavigationHelper Tests', () {
    final baseRideData = {
      'id': 'ride_123',
      'pickup': {
        'lat': 14.6937,
        'lng': -17.4440,
        'address': 'Mermoz, Dakar',
      },
      'dropoff': {
        'lat': 14.7431,
        'lng': -17.5195,
        'address': 'Almadies, Dakar',
      },
      'price': 2500,
      'category': 'ECO',
    };

    test('returns DriverSearchPage when status is SEARCHING', () {
      final rideData = {
        ...baseRideData,
        'status': 'SEARCHING',
      };

      final page = ActiveRideNavigationHelper.resolveActiveRidePage(rideData);

      expect(page, isNotNull);
      expect(page, isA<DriverSearchPage>());
    });

    test('returns DriverApproachingPage when driver is assigned (ACCEPTED)', () {
      final rideData = {
        ...baseRideData,
        'status': 'ACCEPTED',
        'driver': {
          'id': 'driver_99',
          'name': 'Moussa Diop',
          'rating': 4.8,
          'ridesCount': 150,
          'carModel': 'Peugeot 301',
          'carColor': 'Gris',
          'licensePlate': 'DK-1234-AA',
          'etaMinutes': 4,
          'latitude': 14.6950,
          'longitude': -17.4420,
        },
      };

      final page = ActiveRideNavigationHelper.resolveActiveRidePage(rideData);

      expect(page, isNotNull);
      expect(page, isA<DriverApproachingPage>());
    });

    test('returns ActiveRidePage when status is IN_PROGRESS', () {
      final rideData = {
        ...baseRideData,
        'status': 'IN_PROGRESS',
        'driver': {
          'id': 'driver_99',
          'name': 'Moussa Diop',
          'carModel': 'Peugeot 301',
          'carColor': 'Gris',
          'licensePlate': 'DK-1234-AA',
        },
      };

      final page = ActiveRideNavigationHelper.resolveActiveRidePage(rideData);

      expect(page, isNotNull);
      expect(page, isA<ActiveRidePage>());
    });

    test('returns DriverApproachingPage when status is DRIVER_ARRIVED (driver waiting with code)', () {
      final rideData = {
        ...baseRideData,
        'status': 'DRIVER_ARRIVED',
        'driver': {
          'id': 'driver_99',
          'name': 'Moussa Diop',
          'carModel': 'Peugeot 301',
          'carColor': 'Gris',
          'licensePlate': 'DK-1234-AA',
        },
      };

      final page = ActiveRideNavigationHelper.resolveActiveRidePage(rideData);

      expect(page, isNotNull);
      expect(page, isA<DriverApproachingPage>());
    });

    test('returns null when coordinates are missing', () {
      final incompleteData = {
        'id': 'ride_123',
        'status': 'IN_PROGRESS',
      };

      final page = ActiveRideNavigationHelper.resolveActiveRidePage(incompleteData);

      expect(page, isNull);
    });
  });
}
