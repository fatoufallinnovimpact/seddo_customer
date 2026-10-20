import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/domain/models/ride_option_model.dart';
import 'package:seddo/features/home/presentation/pages/active_ride_page.dart';
import 'package:seddo/features/home/presentation/pages/driver_chat_page.dart';
import 'package:seddo/features/home/presentation/pages/ride_cancelled_page.dart';
import 'package:seddo/features/home/presentation/widgets/insufficient_balance_sheet.dart';
import 'package:seddo/features/home/presentation/widgets/orange_money_payment_sheet.dart';

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

  final ecoOption = RideOptionModel(
    type: RideType.eco,
    title: 'Seddo Eco',
    subtitle: '18:42 · à 4 min',
    capacity: 4,
    price: 3500,
    estimatedArrival: '18:42',
    pickupDuration: '4 min',
  );

  final driver = DriverModel.mockDakarDriver(
    rideType: RideType.eco,
    location: const LatLng(14.7200, -17.4700),
  );

  group('Driver & Payment Lifecycle Flow Tests', () {
    testWidgets('OrangeMoneyPaymentSheet enters PIN, backspace, and validates',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      OrangeMoneyPaymentResult? paymentResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  paymentResult = await OrangeMoneyPaymentSheet.show(
                    ctx,
                    rideOption: ecoOption,
                  );
                },
                child: const Text('Pay'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pay'));
      await tester.pumpAndSettle();

      // Verify payment sheet elements
      expect(find.text('Confirmer le paiement'), findsOneWidget);
      expect(find.text('3500 FCFA'), findsOneWidget);
      expect(find.text('Saisissez votre code secret'), findsOneWidget);

      // Tap numeric keypad digits
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump();

      // Tap backspace
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();

      // Tap digits to complete 4
      await tester.tap(find.text('4'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();

      // Tap Valider
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(paymentResult, OrangeMoneyPaymentResult.success);
    });

    testWidgets('InsufficientBalanceSheet renders details and actions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InsufficientBalanceSheet(
              rideOption: ecoOption,
              missingAmount: 1200,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Solde insuffisant'), findsOneWidget);
      expect(find.text('Rien n\'a été débité de votre Orange Money.'), findsOneWidget);
      expect(find.text('Prix de la course'), findsOneWidget);
      expect(find.text('3 500 F'), findsOneWidget);
      expect(find.text('1 200 F'), findsOneWidget);
      expect(find.text('Recharger avec Max it'), findsOneWidget);
      expect(find.text('Revenir au choix de la course'), findsOneWidget);
    });

    testWidgets('RideCancelledPage renders refund info and return actions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        MaterialApp(
          home: RideCancelledPage(
            rideOption: ecoOption,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Course annulée'), findsOneWidget);
      expect(find.text('3 500 F'), findsOneWidget);
      expect(find.text('Remboursé'), findsOneWidget);
      expect(find.text('CI270415.1842.A3F2'), findsOneWidget);
      expect(find.text('Recommander'), findsOneWidget);
      expect(find.text('Retour à l\'accueil'), findsOneWidget);
    });

    testWidgets('ActiveRidePage renders driver info, car details, and contact buttons',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        MaterialApp(
          home: ActiveRidePage(
            departure: departure,
            destination: destination,
            rideOption: ecoOption,
            driver: driver,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify driver info
      expect(find.text('Moussa Diop'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);
      expect(find.textContaining('Toyota Corolla'), findsOneWidget);
      expect(find.text('DK-4821-AB'), findsOneWidget);

      // Verify contact actions
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Appeler'), findsOneWidget);
      expect(find.text('Annuler la course'), findsOneWidget);
    });

    testWidgets('DriverChatPage sends messages, handles quick replies, and displays bubbles',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        MaterialApp(
          home: DriverChatPage(
            driver: driver,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify driver info in header
      expect(find.text('Moussa Diop'), findsOneWidget);
      expect(find.textContaining('DK-4821-AB'), findsWidgets);

      // Verify initial driver message
      expect(find.textContaining('Bonjour ! Je suis en route'), findsOneWidget);

      // Tap quick reply chip: "Je suis devant la porte"
      expect(find.text('Je suis devant la porte'), findsOneWidget);
      await tester.tap(find.text('Je suis devant la porte'));
      await tester.pump();

      // Verify customer message bubble is displayed
      expect(find.text('Je suis devant la porte'), findsWidgets);

      // Enter custom message
      await tester.enterText(find.byType(TextField), 'Merci beaucoup !');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(find.text('Merci beaucoup !'), findsOneWidget);

      // Wait for simulated driver reply
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.textContaining('Bien reçu !'), findsOneWidget);
    });
  });
}
