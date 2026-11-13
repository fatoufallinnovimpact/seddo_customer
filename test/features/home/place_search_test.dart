import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/pages/place_search_page.dart';
import 'package:seddo/features/ride/presentation/pages/ride_booking_page.dart';
import 'package:seddo/services/places_service.dart';

class MockSearchAssetLoader extends AssetLoader {
  const MockSearchAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final file = File('assets/translations/${locale.languageCode}.json');
    if (file.existsSync()) {
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    }
    return {};
  }
}

class MockPlacesHttpClientAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri.toString();

    // 1. Google Places Autocomplete API
    if (uri.contains('places:autocomplete')) {
      final data = options.data is Map ? options.data as Map : {};
      final input = (data['input'] as String? ?? '').toLowerCase();

      List<Map<String, dynamic>> suggestions = [];
      if (input.startsWith('o')) {
        suggestions = [
          {
            'placePrediction': {
              'placeId': 'ChIJ_ouakam',
              'text': {'text': 'Ouakam, Dakar, Sénégal'},
              'structuredFormat': {
                'mainText': {'text': 'Ouakam'},
                'secondaryText': {'text': 'Dakar, Sénégal'}
              }
            }
          },
          {
            'placePrediction': {
              'placeId': 'ChIJ_ouest_foire',
              'text': {'text': 'Ouest Foire, Dakar, Sénégal'},
              'structuredFormat': {
                'mainText': {'text': 'Ouest Foire'},
                'secondaryText': {'text': 'Dakar, Sénégal'}
              }
            }
          }
        ];
      } else if (input.startsWith('almad')) {
        suggestions = [
          {
            'placePrediction': {
              'placeId': 'ChIJ_almadies',
              'text': {'text': 'Les Almadies, Dakar, Sénégal'},
              'structuredFormat': {
                'mainText': {'text': 'Almadies'},
                'secondaryText': {'text': 'Dakar, Sénégal'}
              }
            }
          }
        ];
      }

      return ResponseBody.fromString(
        jsonEncode({'suggestions': suggestions}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    // 2. Google Places Details API
    if (uri.contains('places/')) {
      return ResponseBody.fromString(
        jsonEncode({
          'formattedAddress': 'Ouakam, Dakar, Sénégal',
          'location': {
            'latitude': 14.7231,
            'longitude': -17.4912,
          }
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    // 3. Google Maps Geocoding API
    if (uri.contains('geocode/json')) {
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'OK',
          'results': [
            {
              'formatted_address': 'Route des Almadies, Les Almadies, Dakar, Sénégal',
              'place_id': 'ChIJ_almadies_geo',
              'types': ['street_address'],
              'address_components': [
                {'long_name': 'Route des Almadies', 'types': ['route']},
                {'long_name': 'Les Almadies', 'types': ['neighborhood', 'sublocality']},
                {'long_name': 'Dakar', 'types': ['locality', 'administrative_area_level_1']},
                {'long_name': 'Sénégal', 'types': ['country']}
              ]
            }
          ]
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode({}),
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
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('PlacesService Autocomplete (Dio & Uuid)', () {
    late PlacesService service;

    setUp(() {
      final dio = Dio()..httpClientAdapter = MockPlacesHttpClientAdapter();
      service = PlacesService('mock_api_key', dio);
    });

    test('Query "o" immediately proposes "Ouakam" at the top of results',
        () async {
      final results = await service.autocomplete('o');

      expect(results, isNotEmpty);
      expect(results.first.mainText, 'Ouakam');
      expect(results.first.secondaryText, contains('Dakar'));
      expect(results.any((p) => p.mainText == 'Ouest Foire'), isTrue);
    });

    test('Query "almad" proposes Almadies', () async {
      final results = await service.autocomplete('almad');

      expect(results, isNotEmpty);
      expect(results.first.mainText, 'Almadies');
    });

    test('details returns valid coordinates for a placeId', () async {
      final details = await service.details('ChIJ_ouakam');

      expect(details.address, contains('Ouakam'));
      expect(details.lat, 14.7231);
      expect(details.lng, -17.4912);
    });
  });

  group('PlaceSearchPage Layout & Autocomplete Flow', () {
    testWidgets('Renders reference design with SVG icons, swap button, and autocompletes "o"',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('fr')],
          path: 'assets/translations',
          assetLoader: const MockSearchAssetLoader(),
          fallbackLocale: const Locale('fr'),
          startLocale: const Locale('fr'),
          saveLocale: false,
          useOnlyLangCode: true,
          child: Builder(
            builder: (context) {
              return MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: Builder(
                  builder: (ctx) {
                    return Scaffold(
                      body: ElevatedButton(
                        onPressed: () async {
                          final dio = Dio()..httpClientAdapter = MockPlacesHttpClientAdapter();
                          final mockService = PlacesService('mock_api_key', dio);
                          await Navigator.of(ctx).push<PlaceSearchResult>(
                            MaterialPageRoute(
                              builder: (_) => PlaceSearchPage(
                                placesService: mockService,
                                currentUserLocation: const LatLng(14.7167, -17.4677),
                              ),
                            ),
                          );
                        },
                        child: const Text('Open Search'),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open search page
      await tester.tap(find.text('Open Search'));
      await tester.pumpAndSettle();

      expect(find.byType(PlaceSearchPage), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Verify Quick Action Chips
      expect(find.text('Ma position'), findsOneWidget);
      expect(find.text('Lieux enregistrés'), findsOneWidget);
      expect(find.text('RÉSULTATS'), findsOneWidget);

      // Type 'o' into the arrival text field
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2)); // departure and arrival
      final arrivalField = textFields.last;

      await tester.enterText(arrivalField, 'o');
      // Wait for the 400ms debounce
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      // Verify "Ouakam" is proposed
      expect(find.text('Ouakam'), findsOneWidget);

      // Tap Ouakam to select
      await tester.tap(find.text('Ouakam'));
      await tester.pumpAndSettle();

      // Verify arrival text is updated and Confirmer le trajet button is shown
      expect(find.text('Ouakam'), findsWidgets);
      expect(find.text('Confirmer le trajet'), findsOneWidget);

      // Tap Confirmer le trajet to go to RideBookingPage
      await tester.tap(find.text('Confirmer le trajet'));
      await tester.pumpAndSettle();

      // Verify RideBookingPage is displayed
      expect(find.byType(RideBookingPage), findsOneWidget);
    });

    testWidgets(
        'Tapping "Utiliser ma position actuelle" writes real physical address into the field',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      final dio = Dio()..httpClientAdapter = MockPlacesHttpClientAdapter();
      final placesService = PlacesService(
        'mock_api_key',
        dio,
        () async => const LatLng(14.7431, -17.5195), // Almadies coordinates
      );

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('fr')],
          path: 'assets/translations',
          assetLoader: const MockSearchAssetLoader(),
          fallbackLocale: const Locale('fr'),
          startLocale: const Locale('fr'),
          saveLocale: false,
          useOnlyLangCode: true,
          child: MaterialApp(
            home: PlaceSearchPage(
              placesService: placesService,
              currentUserLocation: const LatLng(14.7431, -17.5195),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find quick action chip "Ma position"
      final useCurrentLocationBtn =
          find.byIcon(Icons.my_location_rounded);
      expect(useCurrentLocationBtn, findsOneWidget);

      await tester.tap(useCurrentLocationBtn);
      await tester.pumpAndSettle();

      // Arrival field should now contain real address (e.g. Almadies)
      final arrivalField = find.byType(TextField).last;
      final TextField fieldWidget = tester.widget(arrivalField);
      expect(fieldWidget.controller?.text, isNot('Ma position actuelle'));
      expect(fieldWidget.controller?.text, isNotEmpty);
      expect(fieldWidget.controller?.text, contains('Almadies'));
    });

    testWidgets('Tapping "Lieux enregistrés" opens SavedPlacesPage and selecting auto-fills the field',
        (tester) async {
      final dio = Dio()..httpClientAdapter = MockPlacesHttpClientAdapter();
      final mockService = PlacesService('mock_api_key', dio);

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('fr')],
          path: 'assets/translations',
          assetLoader: const MockSearchAssetLoader(),
          fallbackLocale: const Locale('fr'),
          startLocale: const Locale('fr'),
          saveLocale: false,
          useOnlyLangCode: true,
          child: MaterialApp(
            home: PlaceSearchPage(placesService: mockService),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Lieux enregistrés
      final savedPlacesTile = find.text('Lieux enregistrés');
      expect(savedPlacesTile, findsOneWidget);

      await tester.tap(savedPlacesTile);
      await tester.pumpAndSettle();

      // Verify SavedPlacesPage is shown with default presets
      expect(find.text('Maison'), findsOneWidget);
      expect(find.text('Travail'), findsOneWidget);

      // Select "Maison"
      await tester.tap(find.text('Maison'));
      await tester.pumpAndSettle();

      // Verify we are back on PlaceSearchPage and the arrival field is auto-filled with "Maison"
      final arrivalField = find.byType(TextField).last;
      final TextField arrivalWidget = tester.widget(arrivalField);
      expect(arrivalWidget.controller?.text, 'Maison');
    });
  });
}

