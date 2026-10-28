import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/core/utils/api_endpoints.dart';
import 'package:seddo/features/ride/data/models/nearby_drivers_response_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';

void main() {
  group('NearbyDriversResponseModel Tests', () {
    const rawNearbyResponse = {
      'radiusM': 3000,
      'categories': [
        {
          'category': 'ECO',
          'count': 4,
          'etaS': 180,
          'cars': [
            {'lat': 14.6685, 'lng': -17.4320, 'heading': 45.0, 'id': 'car_eco_1'},
            {'lat': 14.6690, 'lng': -17.4310, 'heading': 120.0, 'id': 'car_eco_2'},
          ]
        },
        {
          'category': 'CONFORT',
          'count': 2,
          'etaS': 240,
          'cars': [
            {'lat': 14.6710, 'lng': -17.4350, 'heading': 210.0, 'id': 'car_conf_1'}
          ]
        }
      ]
    };

    test('Parses nearby drivers response with categories, counts and cars', () {
      final model = NearbyDriversResponseModel.fromJson(rawNearbyResponse);

      expect(model.radiusM, 3000);
      expect(model.categories.length, 2);

      // Eco category
      expect(model.ecoCount, 4);
      expect(model.ecoEtaMinutes, 3);
      expect(model.ecoCars.length, 2);
      expect(model.ecoCars.first.lat, 14.6685);
      expect(model.ecoCars.first.lng, -17.4320);
      expect(model.ecoCars.first.heading, 45.0);

      // Confort category
      expect(model.confortCount, 2);
      expect(model.confortEtaMinutes, 4);
      expect(model.confortCars.length, 1);
      expect(model.confortCars.first.id, 'car_conf_1');

      // Total cars
      expect(model.allCars.length, 3);
    });

    test('Handles empty cars and null ETAs gracefully', () {
      const emptyJson = {
        'radiusM': 3000,
        'categories': [
          {'category': 'ECO', 'count': 0, 'etaS': null, 'cars': []},
          {'category': 'CONFORT', 'count': 0, 'etaS': null, 'cars': []}
        ]
      };

      final model = NearbyDriversResponseModel.fromJson(emptyJson);
      expect(model.ecoCount, 0);
      expect(model.confortCount, 0);
      expect(model.ecoCars, isEmpty);
      expect(model.confortCars, isEmpty);
      expect(model.allCars, isEmpty);
    });

    test('RideService.getNearbyDrivers sends GET to ApiEndpoints.driversNearby',
        () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == ApiEndpoints.driversNearby) {
              expect(options.queryParameters['lat'], 14.6681);
              expect(options.queryParameters['lng'], -17.4316);
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: rawNearbyResponse,
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final service = RideService(dio: dio);
      final result =
          await service.getNearbyDrivers(lat: 14.6681, lng: -17.4316);

      expect(result, isNotNull);
      expect(result!.ecoCount, 4);
      expect(result.confortCount, 2);
      expect(result.allCars.length, 3);
    });
  });
}
