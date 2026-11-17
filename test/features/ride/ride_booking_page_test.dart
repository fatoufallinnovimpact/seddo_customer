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

      // 4. Both ride options are present: Seddo Eco and Seddo Confort (with Climatisé badge)
      expect(find.text('Seddo Eco'), findsOneWidget);
      expect(find.text('Seddo Confort'), findsOneWidget);
      expect(find.byKey(const Key('ride_confort_ac_badge')), findsOneWidget);
      expect(find.text('Climatisé'), findsOneWidget);

      // 5. Order button simply says "Commander" and payment icon button is on its left
      expect(find.text('Commander'), findsOneWidget);
      expect(find.byKey(const Key('ride_payment_method_selector_button')), findsOneWidget);
      expect(find.byKey(const Key('ride_order_button')), findsOneWidget);

      // 6. Payment method bar card is removed from modal sheet
      expect(find.text('Moyen présélectionné · Toucher pour changer'), findsNothing);
      expect(find.text('Prix fixe, payé à la commande'), findsNothing);
      expect(find.text('OM'), findsNothing);

      // 7. Tap on Seddo Confort
      await tester.tap(find.text('Seddo Confort'));
      await tester.pumpAndSettle();

      // Button text remains "Commander"
      expect(find.text('Commander'), findsOneWidget);

      // 8. Tap on payment icon on the left of Commander button to open PaymentMethodModal
      await tester.tap(find.byKey(const Key('ride_payment_method_selector_button')));
      await tester.pumpAndSettle();

      expect(find.text('Méthode de paiement'), findsOneWidget);
      expect(find.text('Orange Money'), findsOneWidget);
      expect(find.text('Wave'), findsOneWidget);
      expect(find.text('Espèces'), findsOneWidget);

      // Select Espèces and tap Terminer
      await tester.tap(find.text('Espèces'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();

      // 9. Tap on Commander to confirm
      await tester.tap(find.byKey(const Key('ride_order_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify DriverSearchPage is displayed with search title and Confort vehicle image
      expect(find.byType(DriverSearchPage), findsOneWidget);
      expect(find.textContaining('Recherche d\'un chauffeur'), findsOneWidget);
      expect(find.byKey(const Key('driver_search_confort_vehicle_image')), findsOneWidget);

      // 10. Wait for auto-match timer (5 seconds)
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify DriverApproachingPage is displayed matching the reference design
      expect(find.byType(DriverApproachingPage), findsOneWidget);
      expect(find.textContaining('Moussa'), findsWidgets);

      // 11. Tap Discussion button to open chat
      await tester.tap(find.byKey(const ValueKey('approaching_btn_discussion')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify DriverChatPage is displayed
      expect(find.byType(DriverChatPage), findsOneWidget);
    });
  });
}
