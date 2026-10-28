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
  });

  group('DriverChatPage UI & Interaction Tests', () {
    testWidgets('renders "Numéros masqués" security notice and quick preset replies',
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

      await tester.pump(const Duration(milliseconds: 1600));

      // Dispose widget to cancel periodic timer
      await tester.pumpWidget(const SizedBox());
    });
  });
}
