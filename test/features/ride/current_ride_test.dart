import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/core/utils/api_endpoints.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';

void main() {
  group('GET /v1/rides/current Tests', () {
    test('ApiEndpoints.ridesCurrent points to /v1/rides/current', () {
      expect(ApiEndpoints.ridesCurrent, endsWith('/v1/rides/current'));
    });

    test('RideService.getCurrentRide returns null when ride is null', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/v1/rides/current')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'ride': null},
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final service = RideService(dio: dio);
      final result = await service.getCurrentRide();

      expect(result, isNotNull);
      expect(result!['ride'], isNull);
    });

    test('RideService.getCurrentRide returns active ride data when ride is present', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/v1/rides/current')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'ride': {
                      'id': 'ride_abc123',
                      'status': 'SEARCHING',
                      'category': 'ECO',
                      'pickup': {
                        'lat': 14.6937,
                        'lng': -17.4440,
                        'address': 'Mermoz, Dakar',
                      },
                      'dropoff': {
                        'lat': 14.7431,
                        'lng': -17.5195,
                        'address': 'Almadies, Dakar',
                      },
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
      final result = await service.getCurrentRide();

      expect(result, isNotNull);
      expect(result!['ride'], isNotNull);
      final ride = result['ride'] as Map<String, dynamic>;
      expect(ride['id'], 'ride_abc123');
      expect(ride['status'], 'SEARCHING');
      expect(ride['category'], 'ECO');
    });

    test('RideService.getCurrentRide handles error gracefully without throwing', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 400,
                  data: {'message': 'Bad Request'},
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );

      final service = RideService(dio: dio);
      final result = await service.getCurrentRide();

      expect(result, isNull);
    });
  });
}
