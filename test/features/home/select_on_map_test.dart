import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/pages/select_on_map_page.dart';
import 'package:seddo/services/places_service.dart';
import '../../test_helpers/test_localization_helper.dart';

class MockGeocodeAdapter implements HttpClientAdapter {
  final Map<String, dynamic> responseData;

  MockGeocodeAdapter(this.responseData);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(responseData),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  group('PlacesService.reverseGeocode', () {
    late PlacesService service;

    setUp(() {
      service = PlacesService();
    });

    test('reverseGeocode for Ngor coordinates returns clean Dakar address',
        () async {
      final result = await service.reverseGeocode(14.7547, -17.5142);

      expect(result.mainText, isNotEmpty);
      expect(result.fullAddress, contains('Ngor'));
      expect(result.latitude, 14.7547);
      expect(result.longitude, -17.5142);
    });

    test('reverseGeocode for Plateau coordinates returns Dakar Plateau',
        () async {
      final result = await service.reverseGeocode(14.6720, -17.4330);

      expect(result.mainText, isNotEmpty);
      expect(result.fullAddress, contains('Dakar'));
      expect(result.latitude, 14.6720);
      expect(result.longitude, -17.4330);
    });

    test(
        'reverseGeocode for Guinea coordinates returns Guinea and NOT Dakar/Senegal',
        () async {
      final conakryDio = Dio()
        ..httpClientAdapter = MockGeocodeAdapter({
          'results': [
            {
              'formatted_address': 'Transversale 5, Conakry, Guinée',
              'address_components': [
                {'long_name': 'Transversale 5', 'types': ['route']},
                {'long_name': 'Conakry', 'types': ['locality', 'political']},
                {'long_name': 'Guinée', 'types': ['country', 'political']},
              ],
            }
          ]
        });
      final guineaService = PlacesService(null, conakryDio);

      final result = await guineaService.reverseGeocode(9.6412, -13.5784);

      expect(result.mainText, 'Transversale 5');
      expect(result.secondaryText, 'Conakry, Guinée');
      expect(result.secondaryText, isNot(contains('Dakar')));
      expect(result.secondaryText, isNot(contains('Sénégal')));
    });

    test(
        'reverseGeocode handles unnamed roads by showing area instead of "Route sans nom"',
        () async {
      final kindiaDio = Dio()
        ..httpClientAdapter = MockGeocodeAdapter({
          'results': [
            {
              'formatted_address': 'Route Sans Nom, Penten, Kindia, Guinée',
              'address_components': [
                {'long_name': 'Route Sans Nom', 'types': ['route']},
                {'long_name': 'Penten', 'types': ['sublocality', 'political']},
                {'long_name': 'Kindia', 'types': ['locality', 'political']},
                {'long_name': 'Guinée', 'types': ['country', 'political']},
              ],
            }
          ]
        });
      final kindiaService = PlacesService(null, kindiaDio);

      final result = await kindiaService.reverseGeocode(9.9, -13.2);

      // Main text should be "Penten" instead of "Route sans nom"
      expect(result.mainText, 'Penten');
      expect(result.mainText.toLowerCase(), isNot(equals('route sans nom')));
      expect(result.secondaryText, 'Kindia, Guinée');
      expect(result.secondaryText, isNot(contains('Dakar')));
      expect(result.secondaryText, isNot(contains('Sénégal')));
    });

    test(
        'reverseGeocode offline fallback outside Senegal returns coordinates and NOT Dakar',
        () async {
      final offlineResult = await service.reverseGeocode(9.6412, -13.5784);

      expect(offlineResult.secondaryText, isNot(contains('Dakar')));
      expect(offlineResult.secondaryText, isNot(contains('Sénégal')));
    });
  });

  group('SelectOnMapPage Layout & Flow', () {
    testWidgets('Renders arrival mode with "Arrivée ici" and "Point d\'arrivée"',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      PlaceSearchResult? returnedResult;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    final res =
                        await Navigator.of(context).push<PlaceSearchResult>(
                      MaterialPageRoute(
                        builder: (_) => const SelectOnMapPage(
                          isArrival: true,
                          initialLocation: LatLng(14.7547, -17.5142),
                        ),
                      ),
                    );
                    returnedResult = res;
                  },
                  child: const Text('Open Map'),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open map page
      await tester.tap(find.text('Open Map'));
      await tester.pumpAndSettle();

      expect(find.byType(SelectOnMapPage), findsOneWidget);

      // Verify pin label
      expect(find.text('Arrivée ici'), findsOneWidget);

      // Verify bottom card label
      expect(find.text('Point d\'arrivée'), findsOneWidget);

      // Verify confirm button
      expect(find.text('Confirmer ce point'), findsOneWidget);

      // Tap confirm button
      await tester.tap(find.text('Confirmer ce point'));
      await tester.pumpAndSettle();

      // Verify page popped and returned result
      expect(find.byType(SelectOnMapPage), findsNothing);
      expect(returnedResult, isNotNull);
      expect(returnedResult!.category, 'destination');
      expect(returnedResult!.latitude, 14.7547);
      expect(returnedResult!.longitude, -17.5142);
    });

    testWidgets('Renders departure mode with "Départ ici" and "Point de départ"',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      PlaceSearchResult? returnedResult;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    final res =
                        await Navigator.of(context).push<PlaceSearchResult>(
                      MaterialPageRoute(
                        builder: (_) => const SelectOnMapPage(
                          isArrival: false,
                          initialLocation: LatLng(14.7231, -17.4912),
                        ),
                      ),
                    );
                    returnedResult = res;
                  },
                  child: const Text('Open Map Departure'),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Map Departure'));
      await tester.pumpAndSettle();

      expect(find.byType(SelectOnMapPage), findsOneWidget);
      expect(find.text('Départ ici'), findsOneWidget);
      expect(find.text('Point de départ'), findsOneWidget);

      // Tap confirm button
      await tester.tap(find.text('Confirmer ce point'));
      await tester.pumpAndSettle();

      expect(find.byType(SelectOnMapPage), findsNothing);
      expect(returnedResult, isNotNull);
      expect(returnedResult!.category, 'pickup');
      expect(returnedResult!.latitude, 14.7231);
      expect(returnedResult!.longitude, -17.4912);
    });
  });
}
