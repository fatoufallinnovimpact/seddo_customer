import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/features/ride/data/models/chat_message_model.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/pages/driver_chat_page.dart';
import '../../test_helpers/test_localization_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  final testDriver = DriverModel.mockDakarDriver(
    rideType: RideType.eco,
  );

  group('ChatMessageModel OpenAPI Serialisation Tests', () {
    test('fromJson parses customer message with "body" according to Swagger spec', () {
      final json = {
        'id': 'msg_101',
        'body': 'Je suis devant la pharmacie',
        'sender': 'customer',
        'createdAt': '2026-10-28T22:00:00.000Z',
        'isRead': true,
      };

      final message = ChatMessageModel.fromJson(json);

      expect(message.id, 'msg_101');
      expect(message.text, 'Je suis devant la pharmacie');
      expect(message.sender, ChatSender.customer);
      expect(message.isRead, isTrue);
    });

    test('fromJson parses driver message with "body"', () {
      final json = {
        'id': 'msg_102',
        'body': 'Bien reçu ! Je suis à l\'angle.',
        'sender': 'driver',
        'createdAt': '2026-10-28T22:01:00.000Z',
        'isRead': false,
      };

      final message = ChatMessageModel.fromJson(json);

      expect(message.id, 'msg_102');
      expect(message.text, 'Bien reçu ! Je suis à l\'angle.');
      expect(message.sender, ChatSender.driver);
      expect(message.isRead, isFalse);
    });

    test('toJson serializes to backend structure with "body"', () {
      final message = ChatMessageModel(
        id: 'msg_200',
        sender: ChatSender.customer,
        text: 'Je suis devant la pharmacie',
        timestamp: DateTime(2026, 10, 28, 22, 5),
      );

      final json = message.toJson();

      expect(json['id'], 'msg_200');
      expect(json['body'], 'Je suis devant la pharmacie');
      expect(json['sender'], 'customer');
      expect(json['isRead'], isTrue);
    });
  });

  group('RideService Chat API Tests (GET & POST /v1/rides/{id}/messages)', () {
    test('GET /v1/rides/{id}/messages retrieves list of chat messages', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, contains('/v1/rides/ride_test_99/messages'));
            expect(options.method, 'GET');
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: [
                  {
                    'id': 'msg_1',
                    'body': 'Bonjour ! Je suis en route.',
                    'sender': 'driver',
                    'createdAt': '2026-10-28T22:00:00.000Z',
                  },
                  {
                    'id': 'msg_2',
                    'body': 'Je suis devant la pharmacie',
                    'sender': 'customer',
                    'createdAt': '2026-10-28T22:01:00.000Z',
                  },
                ],
              ),
            );
          },
        ),
      );

      final service = RideService(dio: dio);
      final messages = await service.getChatMessages(rideId: 'ride_test_99');

      expect(messages.length, 2);
      expect(messages[0].text, 'Bonjour ! Je suis en route.');
      expect(messages[0].sender, ChatSender.driver);
      expect(messages[1].text, 'Je suis devant la pharmacie');
      expect(messages[1].sender, ChatSender.customer);
    });

    test('POST /v1/rides/{id}/messages sends { "body": "..." } and receives 201', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, contains('/v1/rides/ride_test_99/messages'));
            expect(options.method, 'POST');
            expect(options.data, {'body': 'Je suis devant la pharmacie'});
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 201,
                data: {'status': 'sent'},
              ),
            );
          },
        ),
      );

      final service = RideService(dio: dio);
      final success = await service.sendChatMessage(
        rideId: 'ride_test_99',
        message: 'Je suis devant la pharmacie',
      );

      expect(success, isTrue);
    });

    test('POST /v1/rides/{id}/share generates public tracking link and token', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, contains('/v1/rides/38d1ae69-f5fb-4895-bca5-542cb2747408/share'));
            expect(options.method, 'POST');
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'url': 'https://seddo-api.innovimpactdev.cloud/v1/share/kBUhKQHwIIfNczTSvB-5f5Nn',
                  'token': 'kBUhKQHwIIfNczTSvB-5f5Nn',
                },
              ),
            );
          },
        ),
      );

      final service = RideService(dio: dio);
      final result = await service.shareRide('38d1ae69-f5fb-4895-bca5-542cb2747408');

      expect(result, isNotNull);
      expect(result!.url, 'https://seddo-api.innovimpactdev.cloud/v1/share/kBUhKQHwIIfNczTSvB-5f5Nn');
      expect(result.token, 'kBUhKQHwIIfNczTSvB-5f5Nn');
    });

    test('GET /v1/share/{token} fetches public shared ride tracking data', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, contains('/v1/share/kBUhKQHwIIfNczTSvB-5f5Nn'));
            expect(options.method, 'GET');
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'ref': 'SD-1071',
                  'status': 'ACCEPTED',
                  'live': true,
                  'driver': {
                    'firstName': 'sidy',
                    'vehicle': {
                      'make': 'Toyota',
                      'model': 'Corolla',
                      'color': 'Rouge',
                      'plate': 'DK 3453 BC',
                    },
                    'position': {
                      'lat': 14.6789179,
                      'lng': -17.4630931,
                    },
                  },
                  'pickupAddress': 'Fann-Point E-Amitié',
                  'dropoff': {
                    'address': 'Hlm grand yoff, Dakar, Senegal',
                    'lat': 14.7422502,
                    'lng': -17.4551161,
                  },
                  'startedAt': null,
                  'completedAt': null,
                },
              ),
            );
          },
        ),
      );

      final service = RideService(dio: dio);
      final details = await service.getSharedRideDetails('kBUhKQHwIIfNczTSvB-5f5Nn');

      expect(details, isNotNull);
      expect(details!.ref, 'SD-1071');
      expect(details.status, 'ACCEPTED');
      expect(details.live, isTrue);
      expect(details.driverFirstName, 'sidy');
      expect(details.vehicleMake, 'Toyota');
      expect(details.vehicleModel, 'Corolla');
      expect(details.vehicleColor, 'Rouge');
      expect(details.vehiclePlate, 'DK 3453 BC');
      expect(details.driverPosition?.latitude, 14.6789179);
      expect(details.pickupAddress, 'Fann-Point E-Amitié');
    });
  });

  group('DriverChatPage UI & Interaction Tests', () {
    testWidgets('renders "Numéros masqués" security notice, empty state, and handles quick preset replies',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'GET') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [],
                ),
              );
            }
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 201,
                data: {'status': 'created'},
              ),
            );
          },
        ),
      );

      final service = RideService(dio: dio);

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: DriverChatPage(
            driver: testDriver,
            rideId: 'ride_test_99',
            rideService: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Masked numbers security banner
      expect(find.text('Numéros masqués'), findsOneWidget);
      expect(find.text('Échanges anonymisés et sécurisés'), findsOneWidget);

      // Check quick reply "Je suis devant la porte"
      expect(find.text('Je suis devant la porte'), findsOneWidget);

      // Tap on the quick reply
      await tester.tap(find.text('Je suis devant la porte'));
      await tester.pump();

      // Message bubble appears for customer
      expect(find.text('Je suis devant la porte'), findsWidgets);

      // Send custom message "Je suis devant la pharmacie" via TextField
      await tester.enterText(find.byType(TextField), 'Je suis devant la pharmacie');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(find.text('Je suis devant la pharmacie'), findsOneWidget);

      await tester.pumpAndSettle();

      // Dispose widget to cancel periodic timer
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('DriverChatPage loads and renders real database messages from GET /v1/rides/{id}/messages',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'GET') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'id': 'msg_remote_1',
                      'sender': 'driver',
                      'body': 'Je suis garé en face de la banque.',
                      'createdAt': '2026-10-29T10:15:00Z',
                    },
                  ],
                ),
              );
            }
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 201,
                data: {'status': 'created'},
              ),
            );
          },
        ),
      );

      final service = RideService(dio: dio);

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: DriverChatPage(
            driver: testDriver,
            rideId: 'ride_test_99',
            rideService: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Je suis garé en face de la banque.'), findsOneWidget);

      // Dispose
      await tester.pumpWidget(const SizedBox());
    });
  });
}
