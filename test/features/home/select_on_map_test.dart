import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/presentation/pages/select_on_map_page.dart';
import 'package:seddo/services/places_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
  });

  group('SelectOnMapPage Layout & Flow', () {
    testWidgets('Renders arrival mode with "Arrivée ici" and "Point d\'arrivée"',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      PlaceSearchResult? returnedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
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
        MaterialApp(
          home: Builder(
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
