import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/bloc/home_bloc.dart';
import 'package:seddo/features/home/domain/bloc/home_event.dart';

void main() {
  group('HomeBloc Tests', () {
    late HomeBloc homeBloc;

    setUp(() {
      // Pass a mock location fetcher to avoid calling real device sensors during tests
      homeBloc = HomeBloc(
        locationFetcher: () async => const LatLng(14.6937, -17.4440),
      );
    });

    tearDown(() {
      homeBloc.close();
    });

    test('Initial state has Dakar center and 6 nearby drivers', () async {
      await Future.delayed(const Duration(milliseconds: 50));

      final state = homeBloc.state;
      expect(state.userLocation, equals(const LatLng(14.6937, -17.4440)));
      expect(state.drivers.length, equals(6));
      expect(state.driversCount, equals(12));
      expect(state.arrivalMinutes, equals(3));
      expect(state.selectedCategory, equals('seddo_eco'));
    });

    test('HomeUpdateDriversEvent pivots cars in place without moving coordinates',
        () async {
      await Future.delayed(const Duration(milliseconds: 50));
      final initialLat = homeBloc.state.drivers.first.latitude;
      final initialHeading = homeBloc.state.drivers.first.heading;

      homeBloc.add(const HomeUpdateDriversEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      final updatedLat = homeBloc.state.drivers.first.latitude;
      final updatedHeading = homeBloc.state.drivers.first.heading;

      // Position remains invariant (cars do NOT drift away)
      expect(updatedLat, equals(initialLat));
      // Car pivots on itself
      expect(updatedHeading, isNot(equals(initialHeading)));
    });

    test('HomeUserLocationUpdatedEvent updates location and positions cars around it',
        () async {
      await Future.delayed(const Duration(milliseconds: 50));
      const realLocation = LatLng(14.7167, -17.4677); // e.g. Almadies

      homeBloc.add(const HomeUserLocationUpdatedEvent(realLocation));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(homeBloc.state.userLocation, equals(realLocation));
      expect(homeBloc.state.drivers.length, equals(6));
      // First driver is near the new real location
      expect(
        (homeBloc.state.drivers.first.latitude - realLocation.latitude).abs(),
        lessThan(0.005),
      );
    });

    test('HomeSelectCategoryEvent updates selected category', () async {
      await Future.delayed(const Duration(milliseconds: 50));

      homeBloc.add(const HomeSelectCategoryEvent('confort'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(homeBloc.state.selectedCategory, equals('confort'));
    });
  });
}
