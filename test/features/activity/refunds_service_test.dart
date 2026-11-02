import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/core/utils/api_endpoints.dart';
import 'package:seddo/features/activity/data/models/activity_item_model.dart';
import 'package:seddo/features/activity/data/services/activity_service.dart';

void main() {
  group('ActivityRefundItem fromBackend & UsersController_refunds parsing', () {
    test('Correctly parses backend refund with Orange providerRef and formatted reason', () {
      final backendJson = {
        'id': 'fdfc449a-cc94-440b-99dc-afd80fde651e',
        'rideId': 'ecf58ea9-974a-4dfc-b4d9-8b7a55f18fd3',
        'rideRef': 'SD-1229',
        'amount': 2200,
        'status': 'SUCCESS',
        'providerRef': 'CI17933787224556465',
        'reason': 'CANCELLED_BY_CLIENT',
        'createdAt': '2026-10-30T16:45:21.790Z',
        'paidAt': '2026-10-30T16:45:22.468Z',
      };

      final refund = ActivityRefundItem.fromBackend(backendJson);

      expect(refund.id, 'fdfc449a-cc94-440b-99dc-afd80fde651e');
      expect(refund.rideId, 'ecf58ea9-974a-4dfc-b4d9-8b7a55f18fd3');
      expect(refund.rideRef, 'SD-1229');
      expect(refund.providerRef, 'CI17933787224556465');
      expect(refund.amount, 2200);
      expect(refund.amountText, '+2 200 F');
      expect(refund.status, 'Remboursée');
      expect(refund.isPending, isFalse);
      expect(refund.subtitle, contains('CI17933787224556465'));
      expect(refund.subtitle, contains('Annulée par vous'));
      expect(refund.title, 'Course SD-1229');
    });

    test('Parses pending refund and formats reason when NO_DRIVER', () {
      final backendJson = {
        'id': 'e76773a4-4e81-4b16-9f14-156af8d975c1',
        'rideId': 'dca933cc-172a-4e80-a3be-1b93af659363',
        'rideRef': 'SD-1223',
        'amount': 2250,
        'status': 'PENDING',
        'providerRef': 'CI1793374492891C9A4',
        'reason': 'NO_DRIVER',
        'createdAt': '2026-10-30T15:34:49.648Z',
        'paidAt': null,
      };

      final refund = ActivityRefundItem.fromBackend(backendJson);

      expect(refund.isPending, isTrue);
      expect(refund.status, 'En cours');
      expect(refund.amountText, '+2 250 F');
      expect(refund.subtitle, contains('Aucun chauffeur'));
      expect(refund.subtitle, contains('CI1793374492891C9A4'));
    });
  });

  group('ActivityService getRefunds with GET /v1/users/me/refunds', () {
    test('Calls ApiEndpoints.userRefunds and parses items', () async {
      final dio = Dio();
      final sampleBackendRefunds = [
        {
          'id': 'fdfc449a-cc94-440b-99dc-afd80fde651e',
          'rideId': 'ecf58ea9-974a-4dfc-b4d9-8b7a55f18fd3',
          'rideRef': 'SD-1229',
          'amount': 2200,
          'status': 'SUCCESS',
          'providerRef': 'CI17933787224556465',
          'reason': 'CANCELLED_BY_CLIENT',
          'createdAt': '2026-10-30T16:45:21.790Z',
          'paidAt': '2026-10-30T16:45:22.468Z',
        },
        {
          'id': '88dc4145-c202-4487-ab89-66834ac3c975',
          'rideId': 'f41818af-3a90-4eff-bfb5-0a5efe07fd5c',
          'rideRef': 'SD-1228',
          'amount': 1100,
          'status': 'SUCCESS',
          'providerRef': 'CI1793378368217F041',
          'reason': 'CANCELLED_BY_CLIENT',
          'createdAt': '2026-10-30T16:39:27.185Z',
          'paidAt': '2026-10-30T16:39:27.955Z',
        }
      ];

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.uri.toString() == ApiEndpoints.userRefunds) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: sampleBackendRefunds,
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final service = ActivityService(dio: dio);
      final refunds = await service.getRefunds();

      expect(refunds.length, 2);
      expect(refunds.first.providerRef, 'CI17933787224556465');
      expect(refunds.first.amount, 2200);
      expect(refunds.last.providerRef, 'CI1793378368217F041');
      expect(refunds.last.amount, 1100);
    });
  });
}
