import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/api_endpoints.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/pages/ride_rating_page.dart';
import '../../test_helpers/test_localization_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  group('Receipt & Rating API Endpoints Tests', () {
    test('ApiEndpoints format verification', () {
      expect(ApiEndpoints.rideRating('123'), endsWith('/v1/rides/123/rating'));
      expect(ApiEndpoints.rideReceiptLink('123'), endsWith('/v1/rides/123/receipt'));
      expect(ApiEndpoints.rideReceiptPdf('123'), endsWith('/v1/rides/123/receipt.pdf'));
      expect(ApiEndpoints.receiptDownload('tok_abc'), endsWith('/v1/receipts/tok_abc'));
    });

    test('RideService.submitRating sends exact OpenAPI payload', () async {
      final dio = Dio();
      Map<String, dynamic>? interceptedBody;
      String? interceptedUrl;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/rating')) {
              interceptedUrl = options.path;
              interceptedBody = options.data is String
                  ? jsonDecode(options.data as String)
                  : options.data as Map<String, dynamic>;
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'success': true},
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final service = RideService(dio: dio);
      final success = await service.submitRating(
        rideId: 'ride_999',
        stars: 5,
        comment: 'Chauffeur très courtois',
        compliments: ['PUNCTUAL', 'CLEAN_CAR'],
      );

      expect(success, isTrue);
      expect(interceptedUrl, endsWith('/v1/rides/ride_999/rating'));
      expect(interceptedBody!['stars'], 5);
      expect(interceptedBody!['comment'], 'Chauffeur très courtois');
      expect(interceptedBody!['compliments'], ['PUNCTUAL', 'CLEAN_CAR']);
    });

    test('RideService.getReceiptLink retrieves signed download URL', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.endsWith('/receipt')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'url': 'https://seddo-api.innov.sn/v1/receipts/signed_token_123',
                    'token': 'signed_token_123',
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final service = RideService(dio: dio);
      final linkData = await service.getReceiptLink('ride_999');

      expect(linkData, isNotNull);
      expect(linkData!['url'], contains('signed_token_123'));
      expect(linkData['token'], 'signed_token_123');
    });

    test('RideService.downloadReceiptPdf retrieves raw PDF bytes', () async {
      final dio = Dio();
      final dummyPdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]); // %PDF-

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.endsWith('/receipt.pdf')) {
              return handler.resolve(
                Response<List<int>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: dummyPdfBytes,
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final service = RideService(dio: dio);
      final bytes = await service.downloadReceiptPdf('ride_999');

      expect(bytes, isNotNull);
      expect(bytes!.length, dummyPdfBytes.length);
    });

    test('RideService.downloadReceiptByToken retrieves raw PDF bytes without auth', () async {
      final dio = Dio();
      final dummyPdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]);

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/receipts/token_xyz')) {
              return handler.resolve(
                Response<List<int>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: dummyPdfBytes,
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final service = RideService(dio: dio);
      final bytes = await service.downloadReceiptByToken('token_xyz');

      expect(bytes, isNotNull);
      expect(bytes!.length, dummyPdfBytes.length);
    });
  });

  group('RideRatingPage UI & Action Buttons Tests', () {
    final destination = PlaceSearchResult(
      id: 'dest_almadies',
      mainText: 'Almadies',
      secondaryText: 'Ngor-Almadies, Dakar',
      fullAddress: 'Almadies, Dakar',
      latitude: 14.7431,
      longitude: -17.5195,
    );

    final driver = DriverModel.mockDakarDriver(
      rideType: RideType.eco,
      location: const LatLng(14.7200, -17.4700),
    );

    final rideOption = RideOptionModel(
      type: RideType.eco,
      title: 'Seddo Eco',
      subtitle: '18:42 · à 4 min',
      capacity: 4,
      price: 3500,
      estimatedArrival: '18:42',
      pickupDuration: '4 min',
    );

    testWidgets('RideRatingPage displays rating stars, comment field, and receipt buttons',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      final dio = Dio();
      Map<String, dynamic>? submittedRatingBody;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/rating')) {
              submittedRatingBody = options.data is String
                  ? jsonDecode(options.data as String)
                  : options.data as Map<String, dynamic>;
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'success': true},
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
          child: RideRatingPage(
            destination: destination,
            driver: driver,
            rideOption: rideOption,
            rideId: 'ride_test_456',
            rideService: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Rating Title
      expect(find.textContaining('Comment s\'est passée votre'), findsOneWidget);

      // 2. Verify Stars
      expect(find.byIcon(Icons.star_rounded), findsWidgets);

      // 3. Verify Feedback Tags
      expect(find.text('Conduite prudente'), findsOneWidget);
      expect(find.text('Ponctuel'), findsOneWidget);
      expect(find.text('Voiture propre'), findsOneWidget);
      expect(find.text('Sympathique'), findsOneWidget);

      // 4. Verify Comment Field
      expect(find.text('Votre commentaire'), findsOneWidget);
      final commentInput = find.byType(TextField);
      expect(commentInput, findsOneWidget);

      // Enter comment
      await tester.enterText(commentInput, 'Service impeccable');
      await tester.pump();

      // 5. Verify Receipt Action Buttons
      expect(find.text('Télécharger le reçu'), findsOneWidget);
      expect(find.text('Partager le reçu'), findsOneWidget);
      expect(find.text('Voir le reçu'), findsOneWidget);

      // 6. Tap "Envoyer" button
      final sendButton = find.text('Envoyer');
      expect(sendButton, findsOneWidget);
      await tester.ensureVisible(sendButton);
      await tester.tap(sendButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify the rating was submitted via RideService
      expect(submittedRatingBody, isNotNull);
      expect(submittedRatingBody!['stars'], 5);
      expect(submittedRatingBody!['comment'], 'Service impeccable');
      expect(submittedRatingBody!['compliments'], contains('SAFE_DRIVING'));
    });
  });
}
