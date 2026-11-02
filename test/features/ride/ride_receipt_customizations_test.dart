import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/activity/data/models/activity_item_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/pages/ride_receipt_page.dart';
import '../../test_helpers/test_localization_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  group('ActivityRideItem Category & Status Parsing Tests', () {
    test('Correctly maps CANCELLED_BY_CLIENT and CANCELLED_BY_ADMIN to Annulée', () {
      final jsonClient = {
        'id': '8f982a9b-2323-4f10-bf1f-12f20af6eda7',
        'ref': 'SD-1270',
        'status': 'CANCELLED_BY_CLIENT',
        'category': 'ECO',
        'price': 1750,
        'cancelFee': 0,
        'pickupAddress': 'Fann-Point E-Amitié, Dakar, Sénégal',
        'dropoffAddress': 'Almadies',
        'distanceM': 10671,
        'createdAt': '2026-11-02T10:01:43.449Z',
      };

      final itemClient = ActivityRideItem.fromBackendSummary(jsonClient);
      expect(itemClient.status, 'Annulée');
      expect(itemClient.isCancelled, isTrue);
      expect(itemClient.isRefunded, isFalse);
      expect(itemClient.category, 'ECO');
      expect(itemClient.categoryLabel, 'Seddo Éco');
      expect(itemClient.toRideOptionModel().title, 'Seddo Éco');

      final jsonAdmin = {
        'id': '1a64256a-6fe7-4f32-9d26-ead4b5012e6d',
        'ref': 'SD-1267',
        'status': 'CANCELLED_BY_ADMIN',
        'category': 'ECO',
        'price': 1850,
        'cancelFee': 0,
        'pickupAddress': 'Dakar, Sénégal',
        'dropoffAddress': 'Almadies',
        'distanceM': 10669,
        'createdAt': '2026-11-02T08:52:54.496Z',
      };

      final itemAdmin = ActivityRideItem.fromBackendSummary(jsonAdmin);
      expect(itemAdmin.status, 'Annulée');
      expect(itemAdmin.isCancelled, isTrue);
      expect(itemAdmin.isRefunded, isFalse);
    });

    test('Correctly maps CONFORT category and NO_DRIVER / PAYMENT_FAILED statuses', () {
      final jsonConfort = {
        'id': '425d5264-46f9-44c6-b3ca-d13298c6d3da',
        'ref': 'SD-1263',
        'status': 'NO_DRIVER',
        'category': 'CONFORT',
        'price': 3700,
        'cancelFee': 0,
        'pickupAddress': 'Place de l’Indépendance, Plateau',
        'dropoffAddress': 'Almadies',
        'distanceM': 11905,
        'createdAt': '2026-11-01T19:18:45.141Z',
      };

      final itemConfort = ActivityRideItem.fromBackendSummary(jsonConfort);
      expect(itemConfort.status, 'Sans chauffeur');
      expect(itemConfort.category, 'CONFORT');
      expect(itemConfort.categoryLabel, 'Seddo Confort');
      expect(itemConfort.toRideOptionModel().title, 'Seddo Confort');
      expect(itemConfort.toRideOptionModel().type, RideType.confort);

      final jsonPaymentFailed = {
        'id': '5f52b2fc-0b06-466f-80d0-38478041bf92',
        'ref': 'SD-1255',
        'status': 'PAYMENT_FAILED',
        'category': 'CONFORT',
        'price': 3650,
        'cancelFee': 0,
        'pickupAddress': 'Place de l’Indépendance, Plateau',
        'dropoffAddress': 'Almadies',
        'distanceM': 11905,
        'createdAt': '2026-10-31T15:51:34.662Z',
      };

      final itemPaymentFailed = ActivityRideItem.fromBackendSummary(jsonPaymentFailed);
      expect(itemPaymentFailed.status, 'Échec');
      expect(itemPaymentFailed.category, 'CONFORT');
      expect(itemPaymentFailed.categoryLabel, 'Seddo Confort');
    });
  });

  group('RideReceiptPage Customizations Widget Tests', () {
    testWidgets(
        'RideReceiptPage displays single time in header, no times at departure/arrival, Référence label, and Seddo Confort',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/v1/rides/ride_test_detail')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'id': 'ride_test_detail',
                    'ref': 'SD-1263',
                    'status': 'CANCELLED_BY_CLIENT',
                    'category': 'CONFORT',
                    'price': 3700,
                    'cancelFee': 0,
                    'distanceM': 11905,
                    'durationS': 1320,
                    'createdAt': '2026-11-01T19:18:45.141Z',
                    'pickup': {
                      'address': 'Place de l’Indépendance, Plateau',
                      'lat': 14.6720,
                      'lng': -17.4360,
                    },
                    'dropoff': {
                      'address': 'Almadies, Dakar',
                      'lat': 14.7431,
                      'lng': -17.5186,
                    },
                    'payment': {
                      'method': 'WAVE',
                      'phone': '77 123 45 67',
                      'status': 'REFUNDED',
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
          child: RideReceiptPage(
            rideId: 'ride_test_detail',
            rideService: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Status is Annulée (not Remboursée)
      expect(find.text('Annulée'), findsOneWidget);

      // 2. Category is Seddo Confort
      expect(find.textContaining('Seddo Confort'), findsOneWidget);

      // 3. Header contains creation time once, without repetition " – "
      expect(find.textContaining(' – '), findsNothing);

      // 4. "Référence" is displayed instead of "Réf. Orange"
      expect(find.text('Référence'), findsOneWidget);
      expect(find.text('Réf. Orange'), findsNothing);
      expect(find.text('SD-1263'), findsOneWidget);

      // 5. Payment method displays official Wave image
      final waveImages = find.byWidgetPredicate((widget) {
        if (widget is Image && widget.image is AssetImage) {
          return (widget.image as AssetImage).assetName == AppConstants.assetWaveLogo;
        }
        return false;
      });
      expect(waveImages, findsOneWidget);
      expect(find.textContaining('Wave 77 123 45 67'), findsOneWidget);
      expect(find.text('WAVE'), findsNothing); // Raw uppercase text container is gone
    });

    testWidgets('RideReceiptPage displays official Orange Money and Cash images',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/v1/rides/ride_om')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'id': 'ride_om',
                    'ref': 'SD-1270',
                    'status': 'COMPLETED',
                    'category': 'ECO',
                    'price': 1750,
                    'payment': {
                      'method': 'ORANGE_MONEY',
                      'phone': '77 987 65 43',
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
          child: RideReceiptPage(
            rideId: 'ride_om',
            rideService: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Official Orange Money asset is displayed
      final omImages = find.byWidgetPredicate((widget) {
        if (widget is Image && widget.image is AssetImage) {
          return (widget.image as AssetImage).assetName == AppConstants.assetOrangeMoneyLogo;
        }
        return false;
      });
      expect(omImages, findsOneWidget);
      expect(find.text('OM'), findsNothing); // Raw 'OM' text container is gone
      expect(find.textContaining('Orange Money 77 987 65 43'), findsOneWidget);
    });

    testWidgets(
        'RideReceiptPage displays Aucun chauffeur assigné and peach badge for NO_DRIVER ride',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/v1/rides/ride_no_driver')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'id': 'ride_no_driver',
                    'ref': 'SD-1263',
                    'status': 'NO_DRIVER',
                    'category': 'CONFORT',
                    'price': 3700,
                    'driver': null, // No driver returned by API
                    'pickup': {
                      'address': 'Place de l’Indépendance, Plateau',
                      'lat': 14.6720,
                      'lng': -17.4360,
                    },
                    'dropoff': {
                      'address': 'Almadies, Dakar',
                      'lat': 14.7431,
                      'lng': -17.5186,
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
          child: RideReceiptPage(
            rideId: 'ride_no_driver',
            rideService: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Status is "Sans chauffeur"
      expect(find.text('Sans chauffeur'), findsOneWidget);

      // 2. Fake driver names and car models must NOT appear
      expect(find.text('Chauffeur Seddo'), findsNothing);
      expect(find.text('Moussa Diop'), findsNothing);

      // 3. "Aucun chauffeur assigné" is clearly shown
      expect(find.text('Aucun chauffeur assigné'), findsOneWidget);
      expect(
        find.text('Aucun chauffeur disponible lors de la commande'),
        findsOneWidget,
      );

      // 4. Verify unified status badge color is peach (same as in Activity list)
      final statusContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('Sans chauffeur'),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = statusContainer.decoration as BoxDecoration;
      expect(decoration.color, AppColors.peachContainer);
    });

    testWidgets(
        'RideReceiptPage displays gray status badge for CANCELLED course (matching Activity list)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/v1/rides/ride_cancel')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'id': 'ride_cancel',
                    'ref': 'SD-1270',
                    'status': 'CANCELLED_BY_CLIENT',
                    'category': 'ECO',
                    'price': 1750,
                    'driver': null,
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
          child: RideReceiptPage(
            rideId: 'ride_cancel',
            rideService: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Status is Annulée with gray background matching Activity list
      expect(find.text('Annulée'), findsOneWidget);
      final statusContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('Annulée'),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = statusContainer.decoration as BoxDecoration;
      expect(decoration.color, AppColors.grayBgLight);

      // No fake driver
      expect(find.text('Chauffeur Seddo'), findsNothing);
      expect(find.text('Moussa Diop'), findsNothing);
      expect(find.text('Aucun chauffeur assigné'), findsOneWidget);
    });
  });
}
