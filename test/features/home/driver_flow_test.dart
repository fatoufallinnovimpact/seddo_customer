import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/domain/models/ride_option_model.dart';
import 'package:seddo/features/home/presentation/pages/active_ride_page.dart';
import 'package:seddo/features/home/presentation/pages/driver_chat_page.dart';
import 'package:seddo/features/home/presentation/pages/ride_booking_page.dart';
import 'package:seddo/features/home/presentation/pages/ride_cancelled_page.dart';
import 'package:seddo/features/home/presentation/pages/ride_rating_page.dart';
import 'package:seddo/features/home/presentation/pages/shared_ride_tracking_page.dart';
import 'package:seddo/features/home/presentation/widgets/insufficient_balance_sheet.dart';
import 'package:seddo/features/home/presentation/widgets/no_driver_found_sheet.dart';
import 'package:seddo/features/home/presentation/widgets/orange_money_payment_sheet.dart';
import 'package:seddo/features/home/presentation/widgets/safety_modal_widget.dart';

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

      expect(find.text('Confirmer le paiement'), findsOneWidget);
      expect(find.text('3500 FCFA'), findsOneWidget);
      expect(find.text('Saisissez votre code secret'), findsOneWidget);

      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();

      await tester.tap(find.text('4'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();

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

    testWidgets('NoDriverFoundSheet renders refund details and retry actions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      NoDriverFoundAction? chosenAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  chosenAction = await NoDriverFoundSheet.show(
                    ctx,
                    departure: departure,
                    destination: destination,
                    rideOption: ecoOption,
                  );
                },
                child: const Text('Open No Driver Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open No Driver Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Aucun chauffeur disponible'), findsOneWidget);
      expect(find.textContaining('Forte demande en ce moment'), findsOneWidget);
      expect(find.text('3 500 F remboursés'), findsOneWidget);
      expect(find.text('Plus tard'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(chosenAction, NoDriverFoundAction.retry);
    });

    testWidgets('RideCancelledPage renders refund info and reorder redirects',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        MaterialApp(
          home: RideCancelledPage(
            rideOption: ecoOption,
            departure: departure,
            destination: destination,
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

      await tester.tap(find.text('Recommander'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(RideBookingPage), findsOneWidget);
    });

    testWidgets('ActiveRidePage renders driver card, contact, share, and safety tiles',
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

      expect(find.text('En route vers Almadies'), findsOneWidget);
      expect(find.text('Moussa · ★ 4.9'), findsOneWidget);
      expect(find.text('Payé'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Appeler'), findsOneWidget);

      // Drag bottom sheet up to reveal route details and safety options
      await tester.drag(find.text('En route vers Almadies'), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Partager le trajet'), findsOneWidget);
      expect(find.text('Sécurité'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);

      // Tap Sécurité tile
      await tester.tap(find.text('Sécurité'));
      await tester.pumpAndSettle();

      expect(find.text('Sécurité du trajet'), findsOneWidget);
      expect(find.text('Appeler la Police (17)'), findsOneWidget);
      expect(find.text('Appeler les Secours / SAMU (1515)'), findsOneWidget);
    });

    testWidgets('SafetyModalWidget renders emergency numbers directly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafetyModalWidget(
              destination: destination,
              driver: driver,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sécurité du trajet'), findsOneWidget);
      expect(find.text('Appeler la Police (17)'), findsOneWidget);
      expect(find.text('Appeler les Secours / SAMU (1515)'), findsOneWidget);
      expect(find.text('Partager ma position d\'urgence'), findsOneWidget);
      expect(find.text('Signaler un problème à Seddo'), findsOneWidget);
    });

    testWidgets('RideRatingPage allows star rating, tag toggling, and view receipt',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        MaterialApp(
          home: RideRatingPage(
            destination: destination,
            driver: driver,
            rideOption: ecoOption,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Comment s\'est passée votre'), findsOneWidget);
      expect(find.text('Conduite prudente'), findsOneWidget);
      expect(find.text('Ponctuel'), findsOneWidget);
      expect(find.text('Voiture propre'), findsOneWidget);
      expect(find.text('Sympathique'), findsOneWidget);
      expect(find.text('Total payé'), findsOneWidget);
      expect(find.text('3 500 F'), findsOneWidget);
      expect(find.text('Envoyer'), findsOneWidget);
      expect(find.text('Voir le reçu'), findsOneWidget);

      // Toggle Ponctuel tag
      await tester.tap(find.text('Ponctuel'));
      await tester.pump();

      // Open receipt
      await tester.ensureVisible(find.text('Voir le reçu'));
      await tester.tap(find.text('Voir le reçu'));
      await tester.pumpAndSettle();

      expect(find.text('Reçu de la course'), findsOneWidget);
      expect(find.text('Fermer'), findsOneWidget);
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
    });

    testWidgets('SharedRideTrackingPage renders browser header and tracking details',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        MaterialApp(
          home: SharedRideTrackingPage(
            departure: departure,
            destination: destination,
            driver: driver,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('suivi.seddo.sn/t/8K02F'), findsOneWidget);
      expect(find.text('Awa partage son trajet avec vous'), findsOneWidget);
      expect(find.text('Arrivée prévue 18:42'), findsOneWidget);
      expect(find.text('Le lien expire à la fin de la course.'), findsOneWidget);
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

      expect(find.text('Moussa Diop'), findsOneWidget);
      expect(find.textContaining('DK-4821-AB'), findsWidgets);
      expect(find.textContaining('Bonjour ! Je suis en route'), findsOneWidget);

      expect(find.text('Je suis devant la porte'), findsOneWidget);
      await tester.tap(find.text('Je suis devant la porte'));
      await tester.pump();

      expect(find.text('Je suis devant la porte'), findsWidgets);

      await tester.enterText(find.byType(TextField), 'Merci beaucoup !');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(find.text('Merci beaucoup !'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.textContaining('Bien reçu !'), findsOneWidget);
    });
  });
}
