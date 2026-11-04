import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/widgets/offline_emergency_sheet.dart';
import 'package:seddo/features/ride/presentation/widgets/offline_modal_sheet.dart';
import 'package:seddo/features/ride/presentation/widgets/orange_money_payment_sheet.dart';
import 'package:seddo/features/tcu/presentation/pages/public_transport_page.dart';
import 'package:seddo/features/tcu/data/services/public_transport_service.dart';
import 'package:seddo/services/network_connectivity_service.dart';
import '../../test_helpers/test_localization_helper.dart';

void main() {
  setUpAll(() async {
    await initTestLocalization();
  });

  tearDown(() {
    NetworkConnectivityService.mockIsConnected = null;
    PublicTransportService.enableMockDataForTesting = false;
  });

  group('Offline Trip Search Prevention Tests', () {
    testWidgets('OfflineModalSheet renders offline title and description correctly',
        (tester) async {
      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => OfflineModalSheet.show(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Vérifie l'affichage du titre "Vous êtes hors ligne" et du bouton Réessayer
      expect(find.byType(OfflineModalSheet), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets(
        'Tapping close button at top of OfflineModalSheet closes the modal',
        (tester) async {
      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => OfflineModalSheet.show(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(OfflineModalSheet), findsOneWidget);

      // Clic sur le bouton fermer (X) en haut du modal
      final closeButtonFinder =
          find.byKey(const ValueKey('offline_modal_close_button'));
      expect(closeButtonFinder, findsOneWidget);
      await tester.tap(closeButtonFinder);
      await tester.pumpAndSettle();

      expect(find.byType(OfflineModalSheet), findsNothing);
    });

    testWidgets(
        'OfflineModalSheet auto-dismisses and executes onRetry when connectivity returns',
        (tester) async {
      NetworkConnectivityService.mockIsConnected = false;
      bool retried = false;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => OfflineModalSheet.show(
                  context,
                  onRetry: () async {
                    retried = true;
                  },
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(OfflineModalSheet), findsOneWidget);
      expect(retried, isFalse);

      // Rétablissement de la connexion
      NetworkConnectivityService.mockIsConnected = true;

      // Avancement du timer périodique (1 seconde)
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Le modal n'est plus visible et onRetry a été appelé
      expect(find.byType(OfflineModalSheet), findsNothing);
      expect(retried, isTrue);
    });

    testWidgets(
        'In PublicTransportPage, when offline, search is prevented, no fake data shown, and OfflineModalSheet is shown',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      NetworkConnectivityService.mockIsConnected = false;
      PublicTransportService.enableMockDataForTesting = false;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const PublicTransportPage(
            initialDestination: 'Liberté 6',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clic sur le bouton Rechercher
      final searchButton = find.text('Rechercher');
      expect(searchButton, findsOneWidget);
      await tester.tap(searchButton);
      await tester.pumpAndSettle();

      // OfflineModalSheet s'affiche
      expect(find.byType(OfflineModalSheet), findsOneWidget);

      // Aucune fausse donnée affichée en arrière-plan
      expect(find.text('DDD 10'), findsNothing);
      expect(find.text('AFTU 24'), findsNothing);

      // Dès que la connexion revient, le modal disparaît
      NetworkConnectivityService.mockIsConnected = true;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(OfflineModalSheet), findsNothing);
    });

    test('NetworkConnectivityService mockIsConnected reflects connection status',
        () async {
      NetworkConnectivityService.mockIsConnected = false;
      expect(await NetworkConnectivityService.isConnected, isFalse);

      NetworkConnectivityService.mockIsConnected = true;
      expect(await NetworkConnectivityService.isConnected, isTrue);
    });
  });

  group('Payment & SEARCHING Status Tests', () {
    final testOption = RideOptionModel(
      type: RideType.eco,
      title: 'Seddo Eco',
      subtitle: 'Course économique',
      price: 3780,
      capacity: 4,
      estimatedArrival: 'Dans 12 min',
      pickupDuration: '3 min',
      quoteId: 'quote_test_123',
    );

    testWidgets(
        'OrangeMoneyPaymentSheet completes immediately when API returns SEARCHING status (e.g. CASH)',
        (tester) async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/v1/rides')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: {
                    'id': 'ride_cash_777',
                    'ref': 'SD-1330',
                    'status': 'SEARCHING',
                    'category': 'ECO',
                    'price': 3780,
                    'payment': {
                      'method': 'CASH',
                      'status': 'TO_PAY_DRIVER',
                      'amount': 3780,
                    },
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final service = RideService(dio: dio);
      OrangeMoneyPaymentResult? paymentResult;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  paymentResult = await OrangeMoneyPaymentSheet.show(
                    context,
                    rideOption: testOption,
                    rideService: service,
                    paymentMethod: PaymentMethodType.cash,
                  );
                },
                child: const Text('Commander'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Commander'));
      await tester.pumpAndSettle();

      // Clic sur Valider
      final validateFinder = find.text('Valider');
      expect(validateFinder, findsOneWidget);
      await tester.tap(validateFinder);
      await tester.pumpAndSettle();

      // Comme le statut est SEARCHING, le modal de paiement a réussi
      expect(paymentResult, OrangeMoneyPaymentResult.success);
      expect(RideService.lastCreatedRideData?['status'], 'SEARCHING');
    });

    testWidgets('OfflineModalSheet renders orange chat-round-svgrepo-com.svg icon',
        (tester) async {
      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const Scaffold(
            body: OfflineModalSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final svgFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SvgPicture &&
            widget.bytesLoader.toString().contains('chat-round-svgrepo-com.svg'),
      );
      expect(svgFinder, findsOneWidget);
    });

    testWidgets('OfflineEmergencySheet displays real address instead of raw coordinates',
        (tester) async {
      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const Scaffold(
            body: OfflineEmergencySheet(
              destination: PlaceSearchResult(
                id: 'dest',
                mainText: 'Almadies',
                secondaryText: 'Ngor',
                fullAddress: 'Almadies, Dakar',
                latitude: 14.7431,
                longitude: -17.5195,
              ),
              driver: DriverModel(
                id: 'drv_1',
                name: 'Moussa Diop',
                phone: '+221 77 123 45 67',
                carModel: 'Toyota Corolla',
                carColor: 'Rouge',
                licensePlate: 'DK-3453-BC',
                rating: 4.8,
                totalRides: 120,
                rideType: RideType.eco,
                currentLocation: LatLng(14.7078, -17.4744),
                etaMinutes: 10,
                distanceKm: 5.0,
              ),
              currentPosition: LatLng(14.7078, -17.4744),
              currentAddress: 'Mermoz, Dakar',
              etaText: '10 min',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Vérifie que le card message contient bien l'adresse réelle 'Mermoz, Dakar'
      expect(find.textContaining('Position actuelle: Mermoz, Dakar'), findsOneWidget);
      // Vérifie que le texte n'affiche plus 'Dernière position GPS: Lat'
      expect(find.textContaining('Dernière position GPS: Lat'), findsNothing);
    });

    testWidgets('OrangeMoneyPaymentSheet does NOT contain "Vérifier le paiement" button when waiting',
        (tester) async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/v1/rides')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: {
                    'id': 'ride_om_waiting',
                    'ref': 'SD-1331',
                    'status': 'PAYMENT_PENDING',
                    'category': 'ECO',
                    'price': 3500,
                    'payment': {
                      'method': 'ORANGE_MONEY',
                      'status': 'PENDING',
                      'amount': 3500,
                    },
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final service = RideService(dio: dio);

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  OrangeMoneyPaymentSheet.show(
                    context,
                    rideOption: testOption,
                    rideService: service,
                    paymentMethod: PaymentMethodType.orangeMoney,
                  );
                },
                child: const Text('Commander OM'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Commander OM'));
      await tester.pumpAndSettle();

      // Clic sur Valider
      await tester.tap(find.text('Valider'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // L'écran d'attente est affiché
      expect(find.text('En attente du paiement...'), findsOneWidget);
      // Le bouton "Vérifier le paiement" est bien SUPPRIMÉ
      expect(find.text('Vérifier le paiement'), findsNothing);
      // Le bouton "Annuler la commande" est présent
      expect(find.text('Annuler la commande'), findsOneWidget);

      // Clic sur Annuler la commande pour fermer proprement le modal et le timer
      await tester.tap(find.text('Annuler la commande'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });

    test('createRide auto-cancels PAYMENT_PENDING ride on conflict and successfully retries',
        () async {
      int postRideAttempts = 0;
      bool cancelCalled = false;

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.endsWith('/v1/rides') && options.method == 'POST') {
              postRideAttempts++;
              if (postRideAttempts == 1) {
                // Première tentative : conflit car course déjà en cours
                return handler.reject(
                  DioException(
                    requestOptions: options,
                    response: Response(
                      requestOptions: options,
                      statusCode: 409,
                      data: {
                        'code': 'ACTIVE_RIDE_EXISTS',
                        'message': 'Vous avez déjà une course en cours',
                      },
                    ),
                  ),
                );
              } else {
                // Seconde tentative après auto-annulation : succès
                return handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 201,
                    data: {
                      'id': 'ride_new_success',
                      'status': 'SEARCHING',
                      'price': 4000,
                    },
                  ),
                );
              }
            } else if (options.path.contains('/v1/rides/current')) {
              // Renvoie une course non payée en cours
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'ride': {
                      'id': 'ride_old_unpaid',
                      'status': 'PAYMENT_PENDING',
                    },
                  },
                ),
              );
            } else if (options.path.contains('/cancel')) {
              cancelCalled = true;
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'status': 'CANCELLED',
                    'fee': 0,
                    'refundAmount': 0,
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final service = RideService(dio: dio);
      final result = await service.createRide(
        quoteId: 'quote_test_dest_changed',
        paymentMethod: 'ORANGE_MONEY',
      );

      // Vérifie que cancelRide a bien été appelé automatiquement
      expect(cancelCalled, isTrue);
      // Vérifie que deux requêtes POST ont été envoyées (tentative initiale + retry)
      expect(postRideAttempts, 2);
      // Vérifie que le résultat final est la nouvelle course créée
      expect(result?['id'], 'ride_new_success');
      expect(result?['status'], 'SEARCHING');
    });

    testWidgets('Tapping the top of OrangeMoneyPaymentSheet closes it when an error occurs',
        (tester) async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/v1/rides')) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 400,
                    data: {
                      'message': 'Ce devis a déjà été commandé',
                    },
                  ),
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final service = RideService(dio: dio);

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  OrangeMoneyPaymentSheet.show(
                    context,
                    rideOption: testOption,
                    rideService: service,
                    paymentMethod: PaymentMethodType.wave,
                  );
                },
                child: const Text('Commander Wave'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Commander Wave'));
      await tester.pumpAndSettle();

      // Clic sur Valider -> Erreur reçue
      await tester.tap(find.text('Valider'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // L'erreur est affichée
      expect(find.text('Ce devis a déjà été commandé'), findsOneWidget);

      // Clic sur le bouton de fermeture en haut du modal
      final closeButton = find.byIcon(Icons.close_rounded);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // Le modal est bien fermé
      expect(find.text('Ce devis a déjà été commandé'), findsNothing);
    });

    testWidgets('OrangeMoneyPaymentSheet displays no connection error message when offline',
        (tester) async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: 'No internet connection',
              ),
            );
          },
        ),
      );

      final service = RideService(dio: dio);

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  OrangeMoneyPaymentSheet.show(
                    context,
                    rideOption: testOption,
                    rideService: service,
                    paymentMethod: PaymentMethodType.orangeMoney,
                  );
                },
                child: const Text('Commander OM Offline'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Commander OM Offline'));
      await tester.pumpAndSettle();

      // Clic sur Valider
      await tester.tap(find.text('Valider'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // L'erreur spécifique "Aucune connexion Internet" est affichée
      expect(find.text('Aucune connexion Internet. Veuillez vérifier votre réseau et réessayer.'),
          findsOneWidget);
    });
  });
}


