import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/features/tcu/data/models/tcu_route_model.dart';
import 'package:seddo/features/tcu/data/services/public_transport_service.dart';

void main() {
  group('Transit v2 Bus Itinerary API & Parsing Tests', () {
    test('Correctly parses Transit v2 Swagger response and maps transitType & bus images',
        () async {
      final sampleSwaggerJson = [
        {
          "legs": [
            {
              "trip": {
                "id": 710101,
                "tripId": "AFTU_67_thiawlene_37",
                "routeId": "AFTU_67",
                "serviceId": "FULL",
                "tripHeadsign": "",
                "tripShortName": "67",
                "directionId": "0",
                "shapeId": "AFTU_67_thiawlene"
              },
              "route": null,
              "stopStart": {
                "stopId": "A_1452",
                "stopCode": "",
                "stopName":
                    "Mermoz Route De Ouakam Depot Ddd Pres Du Siege Apr",
                "stopLat": 14.70592915161162,
                "stopLon": -17.478551373190356,
                "locationType": 0,
                "transitType": "AFTU"
              },
              "stopEnd": {
                "stopId": "A_927",
                "stopCode": "",
                "stopName": "Bataillon Du Train",
                "stopLat": 14.71301074658552,
                "stopLon": -17.48137027696983,
                "locationType": 0,
                "transitType": "AFTU"
              },
              "departureStopTime": {
                "arrivalTime": "18:33:11",
                "departureTime": "18:33:11",
                "stopId": "A_1452",
                "stopSequence": 63,
                "shapeDistTraveledKm": 28.937
              },
              "destinationStopTime": {
                "arrivalTime": "18:36:07",
                "departureTime": "18:36:07",
                "stopId": "A_927",
                "stopSequence": 65,
                "shapeDistTraveledKm": 29.867
              },
              "intermediateStops": [
                {
                  "stop": {
                    "stopId": "A_1452",
                    "stopCode": "",
                    "stopName": "Mermoz Route De Ouakam Depot Ddd",
                    "stopLat": 14.705929,
                    "stopLon": -17.478551,
                    "locationType": 0,
                    "transitType": "AFTU"
                  },
                  "stopTime": {
                    "arrivalTime": "18:33:11",
                    "departureTime": "18:33:11",
                    "stopId": "A_1452",
                    "stopSequence": 63,
                    "shapeDistTraveledKm": 28.937
                  }
                },
                {
                  "stop": {
                    "stopId": "A_927",
                    "stopCode": "",
                    "stopName": "Bataillon Du Train",
                    "stopLat": 14.713010,
                    "stopLon": -17.481370,
                    "locationType": 0,
                    "transitType": "AFTU"
                  },
                  "stopTime": {
                    "arrivalTime": "18:36:07",
                    "departureTime": "18:36:07",
                    "stopId": "A_927",
                    "stopSequence": 65,
                    "shapeDistTraveledKm": 29.867
                  }
                }
              ],
              "walkingDistanceToBoardingStopMeters": 1933.3555130406264,
              "walkingDistanceFromAlightingStopMeters": 599.2442721248154,
              "trafficDurationSeconds": 176
            }
          ],
          "totalLegs": 1,
          "totalTrafficDurationSeconds": 176,
          "score": 1787.0,
          "label": "Direct",
          "direct": true,
          "source": "Seddo",
          "origin": {
            "stopId": "A_1452",
            "stopCode": "",
            "stopName":
                "Mermoz Route De Ouakam Depot Ddd Pres Du Siege Apr",
            "stopLat": 14.70592915161162,
            "stopLon": -17.478551373190356,
            "locationType": 0,
            "transitType": "AFTU"
          },
          "destination": {
            "stopId": "A_927",
            "stopCode": "",
            "stopName": "Bataillon Du Train",
            "stopLat": 14.71301074658552,
            "stopLon": -17.48137027696983,
            "locationType": 0,
            "transitType": "AFTU"
          }
        },
        {
          "legs": [
            {
              "trip": {
                "id": 801122,
                "tripId": "DDD_10_express",
                "routeId": "DDD_10",
                "serviceId": "FULL",
                "tripHeadsign": "",
                "tripShortName": "10",
                "directionId": "0",
                "shapeId": "DDD_10_shape"
              },
              "route": null,
              "stopStart": {
                "stopId": "D_101",
                "stopCode": "DDD101",
                "stopName": "Station Claudel",
                "stopLat": 14.6930,
                "stopLon": -17.4725,
                "locationType": 0,
                "transitType": "DDD"
              },
              "stopEnd": {
                "stopId": "D_109",
                "stopCode": "DDD109",
                "stopName": "Terminus Liberté 6",
                "stopLat": 14.7180,
                "stopLon": -17.4620,
                "locationType": 0,
                "transitType": "DDD"
              },
              "departureStopTime": {
                "arrivalTime": "12:15:00",
                "departureTime": "12:15:00",
                "stopId": "D_101",
                "stopSequence": 1,
                "shapeDistTraveledKm": 0.0
              },
              "destinationStopTime": {
                "arrivalTime": "12:35:00",
                "departureTime": "12:35:00",
                "stopId": "D_109",
                "stopSequence": 6,
                "shapeDistTraveledKm": 12.0
              },
              "intermediateStops": [
                {
                  "stop": {
                    "stopId": "D_101",
                    "stopCode": "DDD101",
                    "stopName": "Station Claudel",
                    "stopLat": 14.6930,
                    "stopLon": -17.4725,
                    "locationType": 0,
                    "transitType": "DDD"
                  },
                  "stopTime": {
                    "arrivalTime": "12:15:00",
                    "departureTime": "12:15:00",
                    "stopId": "D_101",
                    "stopSequence": 1,
                    "shapeDistTraveledKm": 0.0
                  }
                },
                {
                  "stop": {
                    "stopId": "D_109",
                    "stopCode": "DDD109",
                    "stopName": "Terminus Liberté 6",
                    "stopLat": 14.7180,
                    "stopLon": -17.4620,
                    "locationType": 0,
                    "transitType": "DDD"
                  },
                  "stopTime": {
                    "arrivalTime": "12:35:00",
                    "departureTime": "12:35:00",
                    "stopId": "D_109",
                    "stopSequence": 6,
                    "shapeDistTraveledKm": 12.0
                  }
                }
              ],
              "walkingDistanceToBoardingStopMeters": 350.0,
              "walkingDistanceFromAlightingStopMeters": 180.0,
              "trafficDurationSeconds": 1200
            }
          ],
          "totalLegs": 1,
          "totalTrafficDurationSeconds": 1200,
          "score": 1200.0,
          "label": "Direct",
          "direct": true,
          "source": "Seddo",
          "origin": {
            "stopId": "D_101",
            "stopCode": "DDD101",
            "stopName": "Station Claudel",
            "stopLat": 14.6930,
            "stopLon": -17.4725,
            "locationType": 0,
            "transitType": "DDD"
          },
          "destination": {
            "stopId": "D_109",
            "stopCode": "DDD109",
            "stopName": "Terminus Liberté 6",
            "stopLat": 14.7180,
            "stopLon": -17.4620,
            "locationType": 0,
            "transitType": "DDD"
          }
        },
        {
          "legs": [
            {
              "trip": {
                "id": 901122,
                "tripId": "BRT_B1",
                "routeId": "B1",
                "serviceId": "FULL",
                "tripHeadsign": "",
                "tripShortName": "B1",
                "directionId": "0",
                "shapeId": "BRT_B1_shape"
              },
              "route": null,
              "stopStart": {
                "stopId": "B_101",
                "stopCode": "B101",
                "stopName": "Station Voie Réservée BRT",
                "stopLat": 14.7085,
                "stopLon": -17.4580,
                "locationType": 0,
                "transitType": "BRT"
              },
              "stopEnd": {
                "stopId": "B_105",
                "stopCode": "B105",
                "stopName": "Station Liberté 6 BRT",
                "stopLat": 14.7185,
                "stopLon": -17.4600,
                "locationType": 0,
                "transitType": "BRT"
              },
              "departureStopTime": {
                "arrivalTime": "12:12:00",
                "departureTime": "12:12:00",
                "stopId": "B_101",
                "stopSequence": 1,
                "shapeDistTraveledKm": 0.0
              },
              "destinationStopTime": {
                "arrivalTime": "12:20:00",
                "departureTime": "12:20:00",
                "stopId": "B_105",
                "stopSequence": 5,
                "shapeDistTraveledKm": 6.0
              },
              "intermediateStops": [
                {
                  "stop": {
                    "stopId": "B_101",
                    "stopCode": "B101",
                    "stopName": "Station Voie Réservée BRT",
                    "stopLat": 14.7085,
                    "stopLon": -17.4580,
                    "locationType": 0,
                    "transitType": "BRT"
                  },
                  "stopTime": {
                    "arrivalTime": "12:12:00",
                    "departureTime": "12:12:00",
                    "stopId": "B_101",
                    "stopSequence": 1,
                    "shapeDistTraveledKm": 0.0
                  }
                }
              ],
              "walkingDistanceToBoardingStopMeters": 250.0,
              "walkingDistanceFromAlightingStopMeters": 150.0,
              "trafficDurationSeconds": 480
            }
          ],
          "totalLegs": 1,
          "totalTrafficDurationSeconds": 480,
          "score": 500.0,
          "label": "Direct",
          "direct": true,
          "source": "Seddo",
          "origin": {
            "stopId": "B_101",
            "stopCode": "B101",
            "stopName": "Station Voie Réservée BRT",
            "stopLat": 14.7085,
            "stopLon": -17.4580,
            "locationType": 0,
            "transitType": "BRT"
          },
          "destination": {
            "stopId": "B_105",
            "stopCode": "B105",
            "stopName": "Station Liberté 6 BRT",
            "stopLat": 14.7185,
            "stopLon": -17.4600,
            "locationType": 0,
            "transitType": "BRT"
          }
        }
      ];

      // Mock Dio adapter returning sample Swagger JSON
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: sampleSwaggerJson,
                statusCode: 200,
              ),
            );
          },
        ),
      );

      final service = PublicTransportService(dio: dio);

      final results = await service.getRouteOptions(
        origin: 'Fann Hock',
        destination: 'Liberté 6',
        departureLat: 14.6937949,
        departureLon: -17.4914255,
        destinationLat: 14.7115399,
        destinationLon: -17.47601,
        date: DateTime(2026, 8, 1),
        time: const TimeOfDay(hour: 18, minute: 32),
        maxDistanceFrom: 2000,
        maxDistanceTo: 2000,
        orderByFrom: true,
      );

      expect(results.length, 3);

      // 1. First result: AFTU
      final aftuRoute = results[0];
      expect(aftuRoute.type, TcuTransportType.aftu);
      expect(aftuRoute.imagePath, 'assets/images/tcu/aftu_bus.png');
      expect(aftuRoute.lineCode, 'AFTU 67');
      expect(aftuRoute.departureStop.name,
          'Mermoz Route De Ouakam Depot Ddd Pres Du Siege Apr');
      expect(aftuRoute.departureStop.walkingDistanceMeters, 1933);
      expect(aftuRoute.departureStop.latitude, closeTo(14.7059, 0.001));
      expect(aftuRoute.departureStop.longitude, closeTo(-17.4785, 0.001));

      // 2. Second result: DDD
      final dddRoute = results[1];
      expect(dddRoute.type, TcuTransportType.ddd);
      expect(dddRoute.imagePath, 'assets/images/tcu/ddd_bus.png');
      expect(dddRoute.lineCode, 'DDD 10');
      expect(dddRoute.departureStop.name, 'Station Claudel');
      expect(dddRoute.departureStop.walkingDistanceMeters, 350);

      // 3. Third result: BRT
      final brtRoute = results[2];
      expect(brtRoute.type, TcuTransportType.brt);
      expect(brtRoute.imagePath, 'assets/images/tcu/brt_bus.png');
      expect(brtRoute.lineCode, 'B1');
      expect(brtRoute.departureStop.name, 'Station Voie Réservée BRT');
      expect(brtRoute.departureStop.walkingDistanceMeters, 250);
    });
  });
}
