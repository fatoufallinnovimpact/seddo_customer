import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/presentation/pages/driver_approaching_page.dart';
import 'package:seddo/features/ride/presentation/pages/driver_chat_page.dart';
import 'package:seddo/features/ride/presentation/pages/driver_search_page.dart';
import 'package:seddo/features/ride/presentation/pages/ride_booking_page.dart';
import '../../test_helpers/test_localization_helper.dart';

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
    latitude: 14.7431,
    longitude: -17.5195,
  );

  group('RideBookingPage Widget Tests', () {
    testWidgets('Renders all UI components matching design mockup and handles ride selection',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: RideBookingPage(
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

      // 6. Orange Money payment tile removed from modal sheet
      expect(find.text('Prix fixe, payé à la commande'), findsNothing);
      expect(find.text('OM'), findsNothing);

      // 7. Tap on Seddo Confort
      await tester.tap(find.text('Seddo Confort'));
      await tester.pumpAndSettle();

      // Button updates to Commander Seddo Confort
      expect(find.text('Commander Seddo Confort'), findsOneWidget);

      // 8. Tap on Commander Seddo Confort to confirm
      await tester.tap(find.text('Commander Seddo Confort'));
      await tester.pumpAndSettle();

      // Modal 1 : Mode de paiement
      expect(find.text('Mode de paiement'), findsOneWidget);
      expect(find.text('Wave'), findsOneWidget);
      expect(find.text('Orange Money'), findsOneWidget);
      expect(find.text('Paiement en espèces'), findsOneWidget);

      // Tap on Paiement en espèces
      await tester.tap(find.text('Paiement en espèces'));
      await tester.pumpAndSettle();

      // Tap Confirmer et payer
      await tester.tap(find.text('Confirmer et payer'));
      await tester.pumpAndSettle();

      // Modal 2 : Confirmation du paiement en espèces
      expect(find.text('Confirmer le paiement'), findsOneWidget);
      expect(find.text('Valider'), findsOneWidget);

      // 9. Tap Valider to confirm payment
      await tester.tap(find.text('Valider'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify DriverSearchPage is displayed with search title
      expect(find.byType(DriverSearchPage), findsOneWidget);
      expect(find.textContaining('Recherche d\'un chauffeur'), findsOneWidget);

      // 10. Wait for auto-match timer (5 seconds)
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify DriverApproachingPage is displayed matching the reference design
      expect(find.byType(DriverApproachingPage), findsOneWidget);
      expect(find.textContaining('Votre chauffeur arrive dans'), findsWidgets);
      expect(find.textContaining('Moussa'), findsWidgets);
      expect(find.text('Code de départ'), findsOneWidget);
      expect(find.text('Envoyer un message...'), findsOneWidget);

      // 11. Tap message placeholder to open chat
      await tester.tap(find.text('Envoyer un message...'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify DriverChatPage is displayed
      expect(find.byType(DriverChatPage), findsOneWidget);
    });
  });
}
