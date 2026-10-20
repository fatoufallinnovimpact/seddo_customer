import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/pages/place_search_page.dart';
import 'package:seddo/services/places_service.dart';

class MockSearchAssetLoader extends AssetLoader {
  const MockSearchAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'home': {
        'where_to': 'Où allez-vous ?',
        'search_subtitle': 'Saisissez une destination, une adresse...',
        'search_hint': 'Rechercher à Dakar (ex: Ouakam)...',
        'popular_destinations': 'Destinations populaires à Dakar',
        'current_position': 'Ma position actuelle',
      }
    };
  }
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
      service = PlacesService();
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
      final details = await service.details('dakar_ouakam');

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

      PlaceSearchResult? selectedPlace;

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
                          final result =
                              await Navigator.of(ctx).push<PlaceSearchResult>(
                            MaterialPageRoute(
                              builder: (_) => const PlaceSearchPage(),
                            ),
                          );
                          selectedPlace = result;
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
      expect(find.text('Votre trajet'), findsOneWidget);

      // Verify Quick Action Tiles
      expect(find.text('Lieux enregistrés'), findsOneWidget);
      expect(find.text('Maison, Travail, Aéroport'), findsOneWidget);
      expect(find.text('Choisir sur la carte'), findsOneWidget);
      expect(find.text('Placer le point d\'arrivée à la main'), findsOneWidget);
      expect(find.text('Résultats'), findsOneWidget);

      // Verify SVG icons are present
      expect(find.byType(SvgPicture), findsWidgets);

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

      // Verify page is popped and result is returned
      expect(find.byType(PlaceSearchPage), findsNothing);
      expect(selectedPlace, isNotNull);
      expect(selectedPlace!.mainText, 'Ouakam');
      expect(selectedPlace!.latitude, 14.7231);
      expect(selectedPlace!.longitude, -17.4912);
    });

    testWidgets(
        'Tapping "Utiliser ma position actuelle" writes real physical address into the field',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      final placesService = PlacesService(
        null,
        null,
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

      // Find "Utiliser ma position actuelle pour l'arrivée"
      final useCurrentLocationBtn =
          find.text('Utiliser ma position actuelle pour l\'arrivée');
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
  });
}

