import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/data/services/user_location_storage.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/presentation/pages/ride_booking_page.dart';
import 'package:seddo/features/ride/presentation/widgets/ride_map_camera_toggle_button.dart';
import 'package:seddo/services/places_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/test_localization_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  group('PlacesService & Dakar District Fallbacks', () {
    test('getDakarDistrictFallback returns valid human-readable districts', () {
      // Almadies
      final almadies = PlacesService.getDakarDistrictFallback(14.748, -17.525);
      expect(almadies.mainText, contains('Almadies'));
      expect(almadies.mainText, isNot(contains('Position sur la carte')));
      expect(almadies.mainText, isNot(contains('14.')));

      // Point E / Fann
      final pointE = PlacesService.getDakarDistrictFallback(14.695, -17.465);
      expect(pointE.mainText, contains('Point E'));

      // Plateau
      final plateau = PlacesService.getDakarDistrictFallback(14.665, -17.435);
      expect(plateau.mainText, contains('Plateau'));

      // Yoff
      final yoff = PlacesService.getDakarDistrictFallback(14.755, -17.465);
      expect(yoff.mainText, contains('Yoff'));
    });
  });

  group('UserLocationStorage address filtering & cache safety', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      UserLocationStorage.resetCache();
    });

    test('isStreetLevelAddress rejects coordinates and generic placeholders', () {
      expect(UserLocationStorage.isStreetLevelAddress('Position sur la carte'), isFalse);
      expect(UserLocationStorage.isStreetLevelAddress('Position sélectionnée'), isFalse);
      expect(UserLocationStorage.isStreetLevelAddress('Position GPS actuelle'), isFalse);
      expect(UserLocationStorage.isStreetLevelAddress('14.7123, -17.4567'), isFalse);
      expect(UserLocationStorage.isStreetLevelAddress('Lat: 14.712, Lng: -17.456'), isFalse);
      expect(UserLocationStorage.isStreetLevelAddress('14.7123'), isFalse);
      expect(UserLocationStorage.isStreetLevelAddress('-17.4567'), isFalse);
    });

    test('isStreetLevelAddress accepts genuine street addresses', () {
      expect(UserLocationStorage.isStreetLevelAddress('77 Rue 4'), isTrue);
      expect(UserLocationStorage.isStreetLevelAddress('Rue PE 34'), isTrue);
      expect(UserLocationStorage.isStreetLevelAddress('Avenue Cheikh Anta Diop'), isTrue);
      expect(UserLocationStorage.isStreetLevelAddress('Boulevard de la République'), isTrue);
      expect(UserLocationStorage.isStreetLevelAddress('Route des Almadies'), isTrue);
      expect(UserLocationStorage.isStreetLevelAddress('Villa 12'), isTrue);
      expect(UserLocationStorage.isStreetLevelAddress('Immeuble Horizon'), isTrue);
    });

    test('saveLocation rejects coordinates and Position sur la carte', () async {
      await UserLocationStorage.saveLocation(
        addressShort: 'Position sur la carte',
        addressDetails: '14.7123, -17.4567',
        location: const LatLng(14.7123, -17.4567),
      );
      expect(UserLocationStorage.cached, isNull);

      await UserLocationStorage.saveLocation(
        addressShort: '14.7123, -17.4567',
        addressDetails: 'Dakar',
        location: const LatLng(14.7123, -17.4567),
      );
      expect(UserLocationStorage.cached, isNull);

      await UserLocationStorage.saveLocation(
        addressShort: 'Rue PE 34',
        addressDetails: 'Point E, Dakar',
        location: const LatLng(14.695, -17.465),
      );
      expect(UserLocationStorage.cached, isNotNull);
      expect(UserLocationStorage.cached!.addressShort, equals('Rue PE 34'));
    });

    test('loadCachedLocation discards coordinates or Position sur la carte in prefs', () async {
      SharedPreferences.setMockInitialValues({
        'seddo_user_address_short': 'Position sur la carte',
        'seddo_user_address_details': '14.7123, -17.4567',
        'seddo_user_lat': 14.7123,
        'seddo_user_lng': -17.4567,
      });

      final loaded = await UserLocationStorage.loadCachedLocation();
      expect(loaded, isNull);
    });
  });

  group('RideBookingPage Departure Sanitization & Draggable Modal Sheet', () {
    testWidgets('RideBookingPage sanitizes coordinates departure to district fallback and builds draggable sheet', (tester) async {
      // Set larger viewport to avoid any layout overflow
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Create departure with coordinate text
      const genericDeparture = PlaceSearchResult(
        id: 'generic_test',
        mainText: '14.7480, -17.5250',
        secondaryText: '14.7480, -17.5250',
        fullAddress: '14.7480, -17.5250',
        latitude: 14.748,
        longitude: -17.525,
      );

      const destination = PlaceSearchResult(
        id: 'dest_test',
        mainText: 'Place de l\'Indépendance',
        secondaryText: 'Plateau, Dakar',
        fullAddress: 'Place de l\'Indépendance, Plateau, Dakar',
        latitude: 14.668,
        longitude: -17.432,
      );

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const RideBookingPage(
            departure: genericDeparture,
            destination: destination,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Check that departure is sanitized to a real district and no raw coordinates are shown
      expect(find.text('14.7480, -17.5250'), findsNothing);
      expect(find.textContaining('Almadies'), findsWidgets);

      // 2. Check that camera toggle button is present
      expect(find.byType(RideMapCameraToggleButton), findsOneWidget);

      // 3. Check that the drag handle and "Choisissez une course" are rendered
      expect(find.text('Choisissez une course'), findsOneWidget);

      // 4. Test dragging the sheet header downwards
      final chooseRideFinder = find.text('Choisissez une course');
      await tester.drag(chooseRideFinder, const Offset(0, 300), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // After dragging down, the sheet and camera button are still mounted
      expect(find.byType(RideMapCameraToggleButton), findsOneWidget);
      expect(find.text('Choisissez une course'), findsOneWidget);
    });
  });
}
