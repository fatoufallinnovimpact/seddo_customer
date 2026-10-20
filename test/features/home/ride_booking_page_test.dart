import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/domain/models/ride_option_model.dart';
import 'package:seddo/features/home/presentation/pages/ride_booking_page.dart';
import 'package:seddo/services/route_service.dart';

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
    latitude: 14.7431,
    longitude: -17.5195,
  );

  group('RideBookingPage Widget Tests', () {
    testWidgets('Renders all UI components matching design mockup and handles ride selection',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        MaterialApp(
          home: RideBookingPage(
            departure: departure,
            destination: destination,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. GoogleMap is present
      expect(find.byType(GoogleMap), findsOneWidget);

      // 2. Floating Destination Pill badge with text
      expect(find.textContaining('Almadies'), findsWidgets);

      // 3. Bottom Sheet title "Choisissez une course"
      expect(find.text('Choisissez une course'), findsOneWidget);

      // 4. Both ride options are present: Seddo Eco and Seddo Confort
      expect(find.text('Seddo Eco'), findsOneWidget);
      expect(find.text('Seddo Confort'), findsOneWidget);

      // 5. Initial selection is Seddo Eco
      expect(find.text('Commander Seddo Eco'), findsOneWidget);

      // 6. Orange Money payment tile is visible
      expect(find.text('Orange Money · 77 ••• 45 12'), findsOneWidget);
      expect(find.text('Prix fixe, payé à la commande'), findsOneWidget);
      expect(find.text('OM'), findsOneWidget);

      // 7. Tap on Seddo Confort
      await tester.tap(find.text('Seddo Confort'));
      await tester.pumpAndSettle();

      // Button updates to Commander Seddo Confort
      expect(find.text('Commander Seddo Confort'), findsOneWidget);

      // 8. Tap on Commander Seddo Confort to confirm
      await tester.tap(find.text('Commander Seddo Confort'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog appears
      expect(find.text('Course Seddo Confort confirmée !'), findsOneWidget);
      expect(find.text('Compris'), findsOneWidget);

      // 9. Tap on "Compris" to dismiss
      await tester.tap(find.text('Compris'));
      await tester.pumpAndSettle();
    });
  });
}
