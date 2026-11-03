import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/presentation/pages/edit_user_position_page.dart';
import 'package:seddo/features/home/presentation/pages/pickup_map_location_picker_page.dart';
import 'package:seddo/features/home/presentation/widgets/seddo_map_picker_pin.dart';
import 'package:seddo/features/home/presentation/widgets/user_position_bottom_sheet.dart';
import 'package:seddo/features/ride/data/models/nearby_drivers_response_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import '../../test_helpers/test_localization_helper.dart';

class _MockRideServiceForNearby extends RideService {
  final NearbyDriversResponseModel? mockResponse;
  int getNearbyDriversCalls = 0;
  double? lastRequestedLat;
  double? lastRequestedLng;

  _MockRideServiceForNearby({this.mockResponse});

  @override
  Future<NearbyDriversResponseModel?> getNearbyDrivers({
    required double lat,
    required double lng,
  }) async {
    getNearbyDriversCalls++;
    lastRequestedLat = lat;
    lastRequestedLng = lng;
    return mockResponse;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  group('SeddoMapPickerPin Widget Tests', () {
    testWidgets('renders idle pin with stem and passenger icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SeddoMapPickerPin(isMoving: false),
            ),
          ),
        ),
      );

      // Pin has hail / passenger silhouette icon
      expect(find.byIcon(Icons.hail_rounded), findsOneWidget);
    });

    testWidgets('animates lift and float when isMoving is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SeddoMapPickerPin(isMoving: true),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byIcon(Icons.hail_rounded), findsOneWidget);
    });
  });

  group('UserPositionBottomSheet Widget Tests', () {
    testWidgets('renders preview, address and horizontal action buttons',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const Scaffold(
            body: UserPositionBottomSheet(
              userLocation: LatLng(14.6937, -17.4440),
              mainAddress: 'Rue YF-557, 20',
              secondaryAddress: 'Yoff, Almadies, Dakar',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Addresses
      expect(find.text('Rue YF-557, 20'), findsOneWidget);
      expect(find.text('Yoff, Almadies, Dakar'), findsOneWidget);

      // 2. Action options
      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
      expect(find.text('Partager'), findsOneWidget);
    });
  });

  group('PickupMapLocationPickerPage Widget Tests', () {
    testWidgets('renders fullscreen map, banner, center pin and bottom card',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: PickupMapLocationPickerPage(
            initialLocation: LatLng(14.6937, -17.4440),
            initialMainText: 'Rue LIB-41, 120',
            initialSecondaryText: 'Sicap Liberte, Dakar',
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 600));

      // 1. Interactive GoogleMap is present
      expect(find.byType(GoogleMap), findsOneWidget);

      // 2. Top floating banner
      expect(find.text('Balayez pour déplacer la carte'), findsOneWidget);

      // 3. Custom center pin
      expect(find.byType(SeddoMapPickerPin), findsOneWidget);

      // 4. Floating action buttons: Back and GPS
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);

      // 5. Bottom card
      expect(find.text('Adresse de prise en charge'), findsOneWidget);
      expect(find.text('Rue LIB-41, 120'), findsOneWidget);
      expect(find.text('Entrée'), findsOneWidget);
      expect(find.text('Terminé'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    });

    testWidgets(
        'displays nearby drivers information at the top when cars are available',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockRideService = _MockRideServiceForNearby(
        mockResponse: const NearbyDriversResponseModel(
          radiusM: 3000,
          categories: [
            NearbyCategoryModel(
              category: 'ECO',
              count: 2,
              etaS: 180,
              cars: [
                NearbyCarModel(id: 'c1', lat: 14.694, lng: -17.443),
                NearbyCarModel(id: 'c2', lat: 14.693, lng: -17.445),
              ],
            ),
            NearbyCategoryModel(
              category: 'CONFORT',
              count: 1,
              etaS: 300,
              cars: [
                NearbyCarModel(id: 'c3', lat: 14.695, lng: -17.442),
              ],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PickupMapLocationPickerPage(
            initialLocation: const LatLng(14.6937, -17.4440),
            initialMainText: 'Point E, Dakar',
            initialSecondaryText: 'Dakar, Sénégal',
            rideService: mockRideService,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 600));

      // Verifies GET /v1/drivers/nearby was called
      expect(mockRideService.getNearbyDriversCalls, greaterThanOrEqualTo(1));
      expect(mockRideService.lastRequestedLat, 14.6937);
      expect(mockRideService.lastRequestedLng, -17.4440);

      // Verifies top info card is rendered with details
      expect(
        find.byKey(const ValueKey('pickup_map_top_nearby_info_card')),
        findsOneWidget,
      );
      expect(find.text('3 voitures disponibles autour'), findsOneWidget);
      expect(find.text('~3 min'), findsOneWidget);
      expect(find.textContaining('ECO: 2'), findsOneWidget);
      expect(find.textContaining('CONFORT: 1'), findsOneWidget);
      expect(find.text('Rayon 3 km'), findsNothing);
      expect(find.text('Balayez pour déplacer la carte'), findsOneWidget);

      // Verifies that after the entrance duration, the drag hint disappears
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Balayez pour déplacer la carte'), findsNothing);
    });

    testWidgets(
        'displays 0 available cars notice when GET /v1/drivers/nearby returns count 0',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockRideService = _MockRideServiceForNearby(
        mockResponse: const NearbyDriversResponseModel(
          radiusM: 3000,
          categories: [
            NearbyCategoryModel(
              category: 'ECO',
              count: 0,
              etaS: null,
              cars: [],
            ),
            NearbyCategoryModel(
              category: 'CONFORT',
              count: 0,
              etaS: null,
              cars: [],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PickupMapLocationPickerPage(
            initialLocation: const LatLng(14.6681, -17.4316),
            initialMainText: 'Plateau',
            initialSecondaryText: 'Dakar',
            rideService: mockRideService,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 600));

      expect(mockRideService.getNearbyDriversCalls, greaterThanOrEqualTo(1));
      expect(
        find.text('Pas de voiture disponible actuellement'),
        findsOneWidget,
      );
      expect(find.text('(rayon 3 km)'), findsNothing);
      expect(find.text('Balayez pour déplacer la carte'), findsOneWidget);

      // Disappears after timeout
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Balayez pour déplacer la carte'), findsNothing);
    });
  });

  group('EditUserPositionPage Widget Tests', () {
    testWidgets('renders search field, choose on map, GPS, saved places and suggestions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: EditUserPositionPage(
            currentLocation: LatLng(14.6937, -17.4440),
            currentMainText: 'Rue YF-557, 20',
            currentSecondaryText: 'Yoff, Almadies, Dakar',
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));

      // Header & Search
      expect(find.text('Modifier votre position'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Fast options
      expect(find.text('Choisir sur la carte'), findsOneWidget);
      expect(find.text('Déplacer le repère vers votre position exacte'), findsOneWidget);
      expect(find.text('Ma position actuelle'), findsOneWidget);
      expect(find.text('Lieux enregistrés'), findsOneWidget);
    });
  });
}
