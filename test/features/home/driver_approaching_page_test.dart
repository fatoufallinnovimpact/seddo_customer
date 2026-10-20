import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/domain/models/ride_option_model.dart';
import 'package:seddo/features/home/presentation/pages/driver_approaching_page.dart';
import 'package:seddo/features/home/presentation/pages/driver_chat_page.dart';
import 'package:seddo/features/home/presentation/pages/ride_cancelled_page.dart';
import 'package:seddo/features/home/presentation/pages/shared_ride_tracking_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
        MaterialApp(
          home: DriverApproachingPage(
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
      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);

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
        MaterialApp(
          home: DriverApproachingPage(
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
        MaterialApp(
          home: DriverApproachingPage(
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
        MaterialApp(
          home: DriverApproachingPage(
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

      expect(find.byType(RideCancelledPage), findsOneWidget);
    });
  });
}
