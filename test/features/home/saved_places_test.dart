import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/domain/models/saved_place_model.dart';
import 'package:seddo/features/home/presentation/pages/saved_places_page.dart';
import 'package:seddo/services/saved_places_service.dart';
import '../../test_helpers/test_localization_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  group('SavedPlaceModel Tests', () {
    test('JSON serialization & deserialization maintains accurate coordinates', () {
      final model = SavedPlaceModel(
        id: 'place_1',
        name: 'Chez Maman',
        address: 'Mermoz, Dakar',
        latitude: 14.712345,
        longitude: -17.467891,
        iconType: 'heart',
        createdAt: DateTime(2026, 10, 20, 10, 0),
      );

      final jsonMap = model.toJson();
      final fromJson = SavedPlaceModel.fromJson(jsonMap);

      expect(fromJson.id, 'place_1');
      expect(fromJson.name, 'Chez Maman');
      expect(fromJson.address, 'Mermoz, Dakar');
      expect(fromJson.latitude, 14.712345);
      expect(fromJson.longitude, -17.467891);
      expect(fromJson.iconType, 'heart');

      final searchResult = fromJson.toPlaceSearchResult();
      expect(searchResult.mainText, 'Chez Maman');
      expect(searchResult.latitude, 14.712345);
      expect(searchResult.longitude, -17.467891);
    });

    test('copyWith properly modifies fields', () {
      final model = SavedPlaceModel(
        id: 'place_2',
        name: 'Bureau',
        address: 'Plateau',
        latitude: 14.67,
        longitude: -17.43,
        iconType: 'work',
        createdAt: DateTime.now(),
      );

      final updated = model.copyWith(
        name: 'Siège Central',
        address: 'Almadies',
        latitude: 14.75,
        longitude: -17.51,
        iconType: 'star',
      );

      expect(updated.id, 'place_2');
      expect(updated.name, 'Siège Central');
      expect(updated.address, 'Almadies');
      expect(updated.latitude, 14.75);
      expect(updated.longitude, -17.51);
      expect(updated.iconType, 'star');
    });
  });

  group('SavedPlacesService CRUD Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Returns default initial presets if no places are saved yet', () async {
      final service = SavedPlacesService();
      final places = await service.getSavedPlaces();

      expect(places.length, 3);
      expect(places.map((p) => p.name), containsAll(['Maison', 'Travail', 'Aéroport AIBD']));
    });

    test('Add, update, and delete saved places correctly', () async {
      final service = SavedPlacesService();

      // Add custom place
      final newPlace = SavedPlaceModel(
        id: 'gym_001',
        name: 'Salle Olympique',
        address: 'Fann Résidence',
        latitude: 14.695,
        longitude: -17.465,
        iconType: 'gym',
        createdAt: DateTime.now(),
      );

      final withNew = await service.addSavedPlace(newPlace);
      expect(withNew.any((p) => p.id == 'gym_001'), isTrue);

      // Update place
      final modifiedPlace = newPlace.copyWith(name: 'Salle Olympique Club');
      final withUpdated = await service.updateSavedPlace(modifiedPlace);
      final found = withUpdated.firstWhere((p) => p.id == 'gym_001');
      expect(found.name, 'Salle Olympique Club');

      // Delete place
      final withDeleted = await service.deleteSavedPlace('gym_001');
      expect(withDeleted.any((p) => p.id == 'gym_001'), isFalse);
    });
  });

  group('SavedPlacesPage Widget Tests', () {
    late SavedPlacesService mockSavedService;

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'seddo_saved_places': jsonEncode([
          {
            'id': 'home_1',
            'name': 'Maison Familiale',
            'address': 'Ouakam, Dakar',
            'latitude': 14.723,
            'longitude': -17.491,
            'iconType': 'home',
            'createdAt': DateTime(2026, 1, 1).toIso8601String(),
          },
          {
            'id': 'work_1',
            'name': 'Bureau Seddo',
            'address': 'Plateau, Dakar',
            'latitude': 14.672,
            'longitude': -17.433,
            'iconType': 'work',
            'createdAt': DateTime(2026, 1, 1).toIso8601String(),
          },
        ]),
      });
      mockSavedService = SavedPlacesService();
    });

    testWidgets('Renders saved places and selects one returning PlaceSearchResult', (tester) async {
      PlaceSearchResult? returnedResult;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  returnedResult = await Navigator.of(context).push<PlaceSearchResult>(
                    MaterialPageRoute(
                      builder: (_) => SavedPlacesPage(
                        savedPlacesService: mockSavedService,
                        currentUserLocation: const LatLng(14.72, -17.48),
                      ),
                    ),
                  );
                },
                child: const Text('Open Saved Places'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open SavedPlacesPage
      await tester.tap(find.text('Open Saved Places'));
      await tester.pumpAndSettle();

      expect(find.text('Lieux enregistrés'), findsOneWidget);
      expect(find.text('Vos adresses favorites'), findsOneWidget);
      expect(find.text('Maison Familiale'), findsOneWidget);
      expect(find.text('Bureau Seddo'), findsOneWidget);

      // Tap on "Maison Familiale" to select it
      await tester.tap(find.text('Maison Familiale'));
      await tester.pumpAndSettle();

      // Verify that the page popped and returned the correct PlaceSearchResult with exact coordinates
      expect(returnedResult, isNotNull);
      expect(returnedResult!.mainText, 'Maison Familiale');
      expect(returnedResult!.latitude, 14.723);
      expect(returnedResult!.longitude, -17.491);
    });

    testWidgets('Delete confirmation dialog removes item from list', (tester) async {
      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: SavedPlacesPage(
            savedPlacesService: mockSavedService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Maison Familiale'), findsOneWidget);

      // Tap delete icon on first place
      final deleteButtons = find.byTooltip('Supprimer');
      expect(deleteButtons, findsNWidgets(2));
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      // Check dialog appears
      expect(find.text('Supprimer ce lieu ?'), findsOneWidget);
      expect(find.text('Voulez-vous vraiment supprimer « Maison Familiale » de vos lieux enregistrés ?'), findsOneWidget);

      // Tap "Supprimer" button in dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Supprimer'));
      await tester.pumpAndSettle();

      // Verify "Maison Familiale" is gone
      expect(find.text('Maison Familiale'), findsNothing);
      expect(find.text('Bureau Seddo'), findsOneWidget);
    });
  });
}
