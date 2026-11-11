import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/core/maps/models/app_params.dart';
import 'package:seddo/core/maps/models/map_models.dart';
import 'package:seddo/core/maps/models/map_provider.dart';
import 'package:seddo/core/maps/repositories/app_params_repository.dart';
import 'package:seddo/core/maps/manager/map_service_manager.dart';
import 'package:seddo/core/maps/services/map_service.dart';

class MockAppParamsRepository implements IAppParamsRepository {
  AppParams stubbedParams;

  MockAppParamsRepository(this.stubbedParams);

  @override
  Future<AppParams> getCachedParams() async => stubbedParams;

  @override
  Future<AppParams> getParams({bool forceRefresh = false}) async => stubbedParams;
}

void main() {
  group('1. AppParams Model Tests', () {
    test('Tolerant parser handles null and empty json safely', () {
      final params = AppParams.fromJson(null);
      expect(params.maps.android, isNull);
      expect(params.mapsEnabled.android, isFalse);
      expect(params.isGoogleUsable, isFalse);
      expect(params.targetProvider, MapProvider.osm);
    });

    test('Parses mapsEnabled = false even if key is present', () {
      final json = {
        'maps': {'android': 'AIzaSy123456'},
        'mapsEnabled': {'android': false, 'ios': false, 'web': false},
      };
      final params = AppParams.fromJson(json);
      expect(params.maps.android, 'AIzaSy123456');
      expect(params.mapsEnabled.android, isFalse);
      expect(params.isGoogleUsable, isFalse);
      expect(params.targetProvider, MapProvider.osm);
    });

    test('Parses key = null even if mapsEnabled = true', () {
      final json = {
        'maps': {'android': null},
        'mapsEnabled': {'android': true},
      };
      final params = AppParams.fromJson(json);
      expect(params.maps.android, isNull);
      expect(params.mapsEnabled.android, isTrue);
      expect(params.isGoogleUsable, isFalse);
      expect(params.targetProvider, MapProvider.osm);
    });

    test('Parses key = empty string even if mapsEnabled = true', () {
      final json = {
        'maps': {'android': '   '},
        'mapsEnabled': {'android': true},
      };
      final params = AppParams.fromJson(json);
      expect(params.isGoogleUsable, isFalse);
      expect(params.targetProvider, MapProvider.osm);
    });
  });

  group('2. Circuit Breaker & Provider Switching', () {
    test('Circuit breaker trips to OSM on GoogleMapApiKeyException', () async {
      final manager = MapServiceManager.instance;

      // Configurer Google comme actif au départ
      manager.applyParamsForTesting(
        const AppParams(
          maps: MapsKeysConfig(android: 'AIzaSy_ValidKey', ios: 'AIzaSy_ValidKey'),
          mapsEnabled: MapsEnabledConfig(android: true, ios: true),
        ),
      );
      expect(manager.activeProvider, MapProvider.google);
      expect(manager.isCircuitBreakerTripped, isFalse);

      bool osmFallbackCalled = false;

      final result = await manager.safeCall<String>(
        googleCall: (google) async {
          throw const GoogleMapApiKeyException(
            status: 'REQUEST_DENIED',
            message: 'The provided API key is invalid',
            httpStatusCode: 403,
          );
        },
        osmFallback: (osm) async {
          osmFallbackCalled = true;
          return 'OSM_RESULT';
        },
      );

      expect(result, 'OSM_RESULT');
      expect(osmFallbackCalled, isTrue);
      expect(manager.isCircuitBreakerTripped, isTrue);
      expect(manager.activeProvider, MapProvider.osm);
    });

    test('Standard network exceptions do not trip the circuit breaker', () async {
      final manager = MapServiceManager.instance;

      // Réactiver Google
      manager.applyParamsForTesting(
        const AppParams(
          maps: MapsKeysConfig(android: 'AIzaSy_ValidKey', ios: 'AIzaSy_ValidKey'),
          mapsEnabled: MapsEnabledConfig(android: true, ios: true),
        ),
      );
      expect(manager.activeProvider, MapProvider.google);

      expect(
        () => manager.safeCall<String>(
          googleCall: (google) async {
            throw Exception('Connection timeout');
          },
          osmFallback: (osm) async {
            return 'OSM_RESULT';
          },
        ),
        throwsA(isA<Exception>()),
      );

      // Le disjoncteur NE DOIT PAS être déclenché pour une simple coupure réseau
      expect(manager.isCircuitBreakerTripped, isFalse);
      expect(manager.activeProvider, MapProvider.google);
    });
  });

  group('3. Universal Coordinate & Route Model Tests', () {
    test('MapLatLng converts seamlessly between Google and OSM', () {
      const coord = MapLatLng(14.7167, -17.4677);
      final gCoord = coord.toGoogle();
      final oCoord = coord.toOsm();

      expect(gCoord.latitude, 14.7167);
      expect(gCoord.longitude, -17.4677);
      expect(oCoord.latitude, 14.7167);
      expect(oCoord.longitude, -17.4677);

      expect(MapLatLng.fromGoogle(gCoord), coord);
      expect(MapLatLng.fromOsm(oCoord), coord);
    });

    test('MapRouteResult formats distance and duration cleanly', () {
      const route1 = MapRouteResult(
        distanceMeters: 4500,
        durationSeconds: 720,
        points: [],
      );
      expect(route1.formattedDistance, '4.5 km');
      expect(route1.formattedDuration, '12 min');

      const route2 = MapRouteResult(
        distanceMeters: 450,
        durationSeconds: 3700,
        points: [],
      );
      expect(route2.formattedDistance, '450 m');
      expect(route2.formattedDuration, '1h 2min');
    });
  });
}
