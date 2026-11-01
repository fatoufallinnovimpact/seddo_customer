import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/core/utils/api_endpoints.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/widgets/ride_sos_bottom_sheet.dart';
import 'package:seddo/features/safety/data/repositories/safety_repository.dart';
import 'package:seddo/features/safety/data/services/safety_service.dart';
import 'package:seddo/features/safety/domain/bloc/safety_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testDestination = PlaceSearchResult(
    id: 'dest_1',
    mainText: 'Almadies',
    secondaryText: 'Dakar',
    fullAddress: 'Almadies, Dakar, Sénégal',
    latitude: 14.7431,
    longitude: -17.5195,
  );

  const testDriver = DriverModel(
    id: 'drv_1',
    name: 'Moussa Diop',
    phone: '+221 77 123 45 67',
    rating: 4.9,
    totalRides: 420,
    carModel: 'Peugeot 301',
    carColor: 'Gris',
    licensePlate: 'DK-1234-AZ',
    rideType: RideType.eco,
    currentLocation: LatLng(14.6937, -17.4440),
    etaMinutes: 4,
    distanceKm: 1.2,
  );

  group('Ride SOS API & Service Tests', () {
    test('RideService.sendSosAlert sends POST to /v1/rides/{id}/sos with lat & lng',
        () async {
      final dio = Dio();
      String? requestedUrl;
      dynamic requestedData;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestedUrl = options.uri.toString();
            requestedData = options.data;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true},
              ),
            );
          },
        ),
      );

      final service = RideService(dio: dio);
      final result = await service.sendSosAlert(
        rideId: 'ride_abc_999',
        latitude: 14.6937,
        longitude: -17.4440,
      );

      expect(result, isTrue);
      expect(requestedUrl, ApiEndpoints.rideSos('ride_abc_999'));
      expect(requestedData, {
        'lat': 14.6937,
        'lng': -17.4440,
      });
    });

    test(
        'SafetyService.triggerSosAlert sends POST to /v1/rides/{id}/sos when rideId provided',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dio = Dio();
      String? requestedUrl;
      dynamic requestedData;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestedUrl = options.uri.toString();
            requestedData = options.data;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'status': 'alert_dispatched'},
              ),
            );
          },
        ),
      );

      final service = SafetyService(prefs, dio);
      final result = await service.triggerSosAlert(
        rideId: 'ride_xyz_123',
        latitude: 14.7123,
        longitude: -17.4567,
      );

      expect(result, isTrue);
      expect(requestedUrl, ApiEndpoints.rideSos('ride_xyz_123'));
      expect(requestedData, {
        'lat': 14.7123,
        'lng': -17.4567,
      });
    });
  });

  group('SafetyBloc SOS Events Tests', () {
    test('SafetySosTriggered emits isSendingSos then sosTriggered: true',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dio = Dio();

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {},
              ),
            );
          },
        ),
      );

      final service = SafetyService(prefs, dio);
      final repository = SafetyRepository(safetyService: service);
      final bloc = SafetyBloc(repository: repository);

      final states = <SafetyState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(
        const SafetySosTriggered(
          rideId: 'ride_sos_test',
          latitude: 14.6937,
          longitude: -17.4440,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(states.length, greaterThanOrEqualTo(2));
      expect(states.any((s) => s.isSendingSos), isTrue);
      expect(states.last.sosTriggered, isTrue);
      expect(states.last.userFeedbackMessage, 'safety.sos_sent_success');

      bloc.add(const SafetySosDismissed());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(states.last.sosTriggered, isFalse);

      await sub.cancel();
      await bloc.close();
    });
  });

  group('RideSosBottomSheet Widget Tests', () {
    setUpAll(() async {
      EasyLocalization.logger.enableLevels = [];
    });

    testWidgets('renders SOS title, coordinates, and trigger button',
        (tester) async {
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('fr')],
          path: 'assets/translations',
          fallbackLocale: const Locale('fr'),
          startLocale: const Locale('fr'),
          useOnlyLangCode: true,
          child: Builder(
            builder: (context) {
              return MaterialApp(
                locale: context.locale,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                home: Scaffold(
                  body: RideSosBottomSheet(
                    rideId: 'ride_sos_ui_test',
                    currentPosition: const LatLng(14.6937, -17.4440),
                    destination: testDestination,
                    driver: testDriver,
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.crisis_alert_rounded), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.textContaining('14.69370'), findsOneWidget);
      expect(find.textContaining('Moussa Diop'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNWidgets(2));
    });
  });
}
