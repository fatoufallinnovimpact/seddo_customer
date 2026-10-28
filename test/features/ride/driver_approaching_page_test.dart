import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/pages/active_ride_page.dart';
import 'package:seddo/features/ride/presentation/pages/driver_approaching_page.dart';
import 'package:seddo/features/ride/data/models/nearby_drivers_response_model.dart';
import 'package:seddo/features/ride/presentation/pages/driver_chat_page.dart';
import 'package:seddo/features/ride/presentation/pages/driver_search_page.dart';
import 'package:seddo/features/ride/presentation/pages/ride_cancelled_page.dart';
import 'package:seddo/features/ride/presentation/pages/shared_ride_tracking_page.dart';
import '../../test_helpers/test_localization_helper.dart';

class MockRideService extends RideService {
  final Map<String, dynamic>? mockRideDetails;
  MockRideService({this.mockRideDetails});

  @override
  Future<Map<String, dynamic>?> getRideDetails(String id) async {
    return mockRideDetails;
  }

  @override
  Future<NearbyDriversResponseModel?> getNearbyDrivers({
    required double lat,
    required double lng,
  }) async {
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  final departure = PlaceSearchResult(
    id: 'dep_1',
    mainText: 'Point E',
    secondaryText: 'Dakar, Sénégal',
    fullAddress: 'Point E, Dakar',
    latitude: 14.6937,
    longitude: -17.4647,
  );

  final destination = PlaceSearchResult(
    id: 'dest_1',
    mainText: 'Almadies',
    secondaryText: 'Ngor-Almadies, Dakar',
    fullAddress: 'Almadies, Dakar',
    latitude: 14.7400,
    longitude: -17.5100,
  );

  final rideOption = RideOptionModel(
    type: RideType.eco,
    title: 'Seddo Eco',
    subtitle: 'Arrivée rapide',
    capacity: 4,
    price: 2500,
    estimatedArrival: '14:35',
    pickupDuration: '4 min',
  );

  final driver = DriverModel.mockDakarDriver(
    rideType: RideType.eco,
    location: const LatLng(14.7000, -17.4600),
  );

  group('DriverApproachingPage Widget Tests', () {
    testWidgets('renders all UI components matching reference design',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: DriverApproachingPage(
            departure: departure,
            destination: destination,
            rideOption: rideOption,
            driver: driver,
            departureCode: '4821',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Header verification
      expect(find.textContaining('Rendez-vous au point'), findsOneWidget);
      expect(find.text('4 min'), findsWidgets);

      // Card 1: Driver & Vehicle verification
      expect(find.text('DK 4821 AB'), findsOneWidget);
      expect(find.text('Toyota Corolla Gris argent'), findsOneWidget);
      expect(find.text('Moussa'), findsOneWidget);
      expect(find.text('MD'), findsOneWidget);

      // Card 2: Code de départ verification
      expect(find.text('Code de départ'), findsOneWidget);
      expect(find.text('À donner au chauffeur'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Card 3: Quick message & call bar
      expect(find.text('Envoyer un message...'), findsOneWidget);
      expect(find.byTooltip('Appeler le chauffeur'), findsOneWidget);

      // Card 4: Action buttons
      expect(find.text('Partager'), findsOneWidget);
      expect(find.text('Sécurité'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
    });

    testWidgets('tapping message opens DriverChatPage',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: DriverApproachingPage(
            departure: departure,
            destination: destination,
            rideOption: rideOption,
            driver: driver,
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Envoyer un message...'));
      await tester.pumpAndSettle();

      expect(find.byType(DriverChatPage), findsOneWidget);
    });

    testWidgets('tapping Partager opens SharedRideTrackingPage',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: DriverApproachingPage(
            departure: departure,
            destination: destination,
            rideOption: rideOption,
            driver: driver,
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Partager'));
      await tester.pumpAndSettle();

      expect(find.byType(SharedRideTrackingPage), findsOneWidget);
    });

    testWidgets('tapping Annuler cancels ride and navigates to RideCancelledPage',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: DriverApproachingPage(
            departure: departure,
            destination: destination,
            rideOption: rideOption,
            driver: driver,
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      // Confirmer l'annulation dans la feuille de sélection de motif
      await tester.tap(find.text('Confirmer l\'annulation'));
      await tester.pumpAndSettle();

      expect(find.byType(RideCancelledPage), findsOneWidget);
    });

    testWidgets(
        'fetches GET /v1/rides/{id} and updates departure code and driver details dynamically',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      final mockService = MockRideService(
        mockRideDetails: {
          'id': 'ride_abc123',
          'status': 'ACCEPTED',
          'code': '7259',
          'etaMinutes': 2,
          'driver': {
            'id': 'driver_99',
            'firstName': 'Ibrahima',
            'lastName': 'Ndiaye',
            'phone': '+221 78 999 88 77',
            'rating': 4.8,
            'vehicle': {
              'make': 'Hyundai',
              'model': 'Elantra',
              'color': 'Noir',
              'plate': 'DK 9876 ZZ',
            },
            'location': {
              'lat': 14.7100,
              'lng': -17.4600,
            },
          },
        },
      );

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: DriverApproachingPage(
            departure: departure,
            destination: destination,
            rideOption: rideOption,
            driver: driver,
            rideId: 'ride_abc123',
            rideService: mockService,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Vérification du nouveau code de départ retourné par l'API: 7 2 5 9
      expect(find.text('7'), findsOneWidget);
      expect(find.text('2'), findsWidgets); // '2' appears in digit boxes and '2 min'
      expect(find.text('5'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);

      // Vérification des infos réelles du chauffeur retourné par l'API
      expect(find.text('Ibrahima'), findsOneWidget);
      expect(find.text('IN'), findsOneWidget);
      expect(find.text('DK 9876 ZZ'), findsOneWidget);
      expect(find.text('Hyundai Elantra Noir'), findsOneWidget);
      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('2 min'), findsWidgets);
    });

    testWidgets(
        'auto-transitions to ActiveRidePage when ride status is IN_PROGRESS',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      final mockService = MockRideService(
        mockRideDetails: {
          'id': 'ride_abc123',
          'status': 'IN_PROGRESS',
          'code': '7259',
          'driver': {
            'name': 'Ibrahima Ndiaye',
            'phone': '+221 78 999 88 77',
            'rating': 4.8,
          },
        },
      );

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: DriverApproachingPage(
            departure: departure,
            destination: destination,
            rideOption: rideOption,
            driver: driver,
            rideId: 'ride_abc123',
            rideService: mockService,
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(ActiveRidePage), findsOneWidget);
    });

    testWidgets(
        'DriverSearchPage polls GET /v1/rides/{id} and transitions to DriverApproachingPage on ACCEPTED',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      final mockService = MockRideService(
        mockRideDetails: {
          'id': 'ride_search_123',
          'status': 'ACCEPTED',
          'code': '6183',
          'driver': {
            'firstName': 'Modou',
            'lastName': 'Fall',
            'rating': 4.9,
            'vehicle': {
              'make': 'Peugeot',
              'model': '508',
              'color': 'Bleu',
              'plate': 'DK 1122 CC',
            },
          },
        },
      );

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: DriverSearchPage(
            departure: departure,
            destination: destination,
            rideOption: rideOption,
            rideId: 'ride_search_123',
            rideService: mockService,
            autoMatchDriver: false,
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(DriverApproachingPage), findsOneWidget);
      expect(find.text('Modou'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });
}
