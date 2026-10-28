import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/features/saved_places/data/models/saved_place_model.dart';
import 'package:seddo/features/saved_places/presentation/widgets/add_saved_place_sheet.dart';
import 'package:seddo/services/places_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AddSavedPlaceSheet renders clean, soothing UI without icon picker',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final place = SavedPlaceModel(
      id: 'test_123',
      name: 'Maison',
      address: 'Route des Almadies, Dakar',
      latitude: 14.7431,
      longitude: -17.5195,
      iconType: 'star',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AddSavedPlaceSheet(
            initialPlace: place,
            placesService: PlacesService(),
            currentUserLocation: const LatLng(14.7431, -17.5195),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Header & Address
    expect(find.text('Modifier le lieu'), findsOneWidget);
    expect(find.text('Route des Almadies, Dakar'), findsOneWidget);

    // 2. Name input
    expect(find.text('Nom du lieu'), findsOneWidget);
    expect(find.text('Maison'), findsWidgets);

    // 3. Quick name chips
    expect(find.text('Travail'), findsOneWidget);
    expect(find.text('Bureau'), findsOneWidget);
    expect(find.text('Chez Maman'), findsOneWidget);

    // 4. Verify NO icon picker section or label
    expect(find.text('Icône associée'), findsNothing);
    expect(find.text('Icône'), findsNothing);

    // 5. Submit button
    expect(find.text('Mettre à jour'), findsOneWidget);
  });
}
