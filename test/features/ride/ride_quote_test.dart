import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/core/utils/api_endpoints.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/ride_quote_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';

void main() {
  group('RideQuoteModel Tests', () {
    const rawQuoteJson = {
      'distanceM': 11905,
      'durationS': 1888,
      'routeSource': 'google',
      'trafficDelayS': 307,
      'polyline':
          'wutxAhpniBeAfAeAfAo@p@hELLR?RwW`Te@JYV^h@jJzJrApAzAfBB\\LTVLD@NRCZtEhf@?j@GR@HW\\k@l@qG~HuGlI{BpCjCpBzItHPVP\\tC~KhDlM|@rDDn@cA?{ASe@MsBaAoMuHgAc@oAUoAKeA@k@DuCd@{A^eAb@qAx@o@n@i@v@Wh@uA`E}ArFyAxEi@zAgAfDc@t@aIpK}CrDQ\\Un@k@`CSj@QXMHALa@j@iFpEsArAkBzB_CfDaAdAmA~@cAj@MBEJSTwBbB_Al@iA\\{@LeA@iAAs@Hg@Pc@VyAnAcAf@mAZw@JiG^gAPaAZs@^g@`@q@n@WNOBINBLBBm@dCe@pEI`@GF[FeFd@sAd@QFOAKFELgWzK}A~@wAnAk@n@aAvAk@hA]v@_ExK[rAK~AA`AJnBIP@PeAjAsB~Ca@bA]|Am@jDm@|BQj@y@~AcA|AaAhA_EhD{HrGmAt@mAf@k@PO@M@MHmAR}QjA_CZMFi@NyJdD{Cv@yCd@uB\\gAXw@\\kGvCc@DU?G?QISBg@I_@Qs@i@aCqB',
      'zone': 'Dakar et banlieue',
      'expiresAt': '2026-10-27T16:46:39.676Z',
      'pickupEtaS': null,
      'paymentMethod': 'ORANGE_MONEY',
      'options': [
        {
          'quoteId': '617813a8-52ab-45b6-891c-2a0b46124f4e',
          'category': 'ECO',
          'name': 'Seddo Eco',
          'seats': 4,
          'price': 3850,
          'currency': 'XOF',
          'surge': 1,
          'airportFee': 0,
          'bookingFee': 0,
          'zoneFee': 0,
          'pickupEtaS': null
        }
      ]
    };

    test('Parses quote response correctly and decodes road polyline', () {
      final quote = RideQuoteModel.fromJson(rawQuoteJson);

      expect(quote.distanceM, 11905);
      expect(quote.distanceKm, closeTo(11.9, 0.05));
      expect(quote.durationS, 1888);
      expect(quote.durationMinutes, 31);
      expect(quote.zone, 'Dakar et banlieue');
      expect(quote.options.length, 1);

      // Decoded polyline
      final points = quote.decodedPolyline;
      expect(points.length, greaterThan(100));
      expect(points.first.latitude, closeTo(14.6929, 0.001));
      expect(points.first.longitude, closeTo(-17.4466, 0.001));
      expect(points.last.latitude, closeTo(14.7449, 0.001));
      expect(points.last.longitude, closeTo(-17.5107, 0.001));

      // Eco option
      final eco = quote.ecoOption;
      expect(eco, isNotNull);
      expect(eco!.quoteId, '617813a8-52ab-45b6-891c-2a0b46124f4e');
      expect(eco.price, 3850);
      expect(eco.category, 'ECO');
      expect(eco.name, 'Seddo Eco');

      // Confort option is null from backend in rawQuoteJson
      expect(quote.confortOption, isNull);
    });

    test('Parses both ECO and CONFORT options when backend returns CONFORT', () {
      final jsonWithConfort = {
        ...rawQuoteJson,
        'options': [
          {
            'quoteId': 'quote-eco-111',
            'category': 'ECO',
            'name': 'Seddo Eco',
            'seats': 4,
            'price': 3850,
            'currency': 'XOF',
          },
          {
            'quoteId': 'quote-confort-222',
            'category': 'CONFORT',
            'name': 'Seddo Confort',
            'seats': 4,
            'price': 5200,
            'currency': 'XOF',
          },
        ]
      };

      final quote = RideQuoteModel.fromJson(jsonWithConfort);
      expect(quote.ecoOption?.price, 3850);
      expect(quote.confortOption?.price, 5200);
      expect(quote.confortOption?.quoteId, 'quote-confort-222');
    });

    test('RideService.getQuote fetches and returns RideQuoteModel on HTTP 200',
        () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == ApiEndpoints.ridesQuote) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: rawQuoteJson,
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final service = RideService(dio: dio);
      final departure = PlaceSearchResult(
        id: '1',
        mainText: 'Place de l’Indépendance',
        secondaryText: 'Plateau',
        fullAddress: 'Place de l’Indépendance, Plateau',
        latitude: 14.6928,
        longitude: -17.4467,
      );
      final destination = PlaceSearchResult(
        id: '2',
        mainText: 'Almadies',
        secondaryText: 'Ngor',
        fullAddress: 'Almadies, Dakar',
        latitude: 14.7449,
        longitude: -17.5107,
      );

      final quote = await service.getQuote(
        departure: departure,
        destination: destination,
      );

      expect(quote, isNotNull);
      expect(quote!.ecoOption!.price, 3850);
      expect(quote.decodedPolyline.isNotEmpty, true);
    });

    test('RideService.createRide calls POST /v1/rides and returns ride data',
        () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == ApiEndpoints.rides) {
              expect(options.data['quoteId'], '617813a8-52ab-45b6-891c-2a0b46124f4e');
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: {
                    'id': 'ride_abc_123',
                    'status': 'PAYMENT_PENDING',
                    'payment': {
                      'orderId': 'order_om_456',
                      'paymentUrl': 'https://om.sn/pay',
                      'payToken': 'token_789',
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
      final result = await service.createRide(
        quoteId: '617813a8-52ab-45b6-891c-2a0b46124f4e',
      );

      expect(result, isNotNull);
      expect(result!['id'], 'ride_abc_123');
      expect(result['status'], 'PAYMENT_PENDING');
      expect((result['payment'] as Map)['orderId'], 'order_om_456');
    });

    test('RideService.simulateDevPayment calls /v1/dev/orange-money/:id/pay',
        () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/v1/dev/orange-money/order_om_456/pay')) {
              expect(options.data['outcome'], 'SUCCESS');
              expect(options.data['notify'], true);
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
      final success = await service.simulateDevPayment(
        orderId: 'order_om_456',
        outcome: 'SUCCESS',
      );

      expect(success, isTrue);
    });
  });
}
