import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/presentation/pages/edit_user_position_page.dart';
import 'package:seddo/features/home/presentation/pages/pickup_map_location_picker_page.dart';
import 'package:seddo/features/home/presentation/widgets/seddo_map_picker_pin.dart';
import 'package:seddo/features/home/presentation/widgets/user_position_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SeddoMapPickerPin Widget Tests', () {
    testWidgets('renders idle pin with stem and passenger icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SeddoMapPickerPin(isMoving: false),
            ),
          ),
        ),
      );

      // Pin has hail / passenger silhouette icon
      expect(find.byIcon(Icons.hail_rounded), findsOneWidget);
    });

    testWidgets('animates lift and float when isMoving is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SeddoMapPickerPin(isMoving: true),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byIcon(Icons.hail_rounded), findsOneWidget);
    });
  });

  group('UserPositionBottomSheet Widget Tests', () {
    testWidgets('renders modal header, preview and action items',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserPositionBottomSheet(
              userLocation: LatLng(14.6937, -17.4440),
              mainAddress: 'Rue YF-557, 20',
              secondaryAddress: 'Yoff, Almadies, Dakar',
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // 1. Header
      expect(find.text('VOTRE POSITION'), findsOneWidget);

      // 2. Addresses
      expect(find.text('Rue YF-557, 20'), findsOneWidget);
      expect(find.text('Yoff, Almadies, Dakar'), findsOneWidget);

      // 3. Action options
      expect(find.text('Enregistrer la position pour une utilisation ultérieure'),
          findsOneWidget);
      expect(find.text('Partager la position'), findsOneWidget);
      expect(find.text('Modifier votre position'), findsOneWidget);
    });
  });

  group('PickupMapLocationPickerPage Widget Tests', () {
    testWidgets('renders fullscreen map, banner, center pin and bottom card',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: PickupMapLocationPickerPage(
            initialLocation: LatLng(14.6937, -17.4440),
            initialMainText: 'Rue LIB-41, 120',
            initialSecondaryText: 'Sicap Liberte, Dakar',
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 600));

      // 1. Interactive GoogleMap is present
      expect(find.byType(GoogleMap), findsOneWidget);

      // 2. Top floating banner
      expect(find.text('Balayez pour déplacer la carte'), findsOneWidget);

      // 3. Custom center pin
      expect(find.byType(SeddoMapPickerPin), findsOneWidget);

      // 4. Floating action buttons: Back and GPS
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);

      // 5. Bottom card
      expect(find.text('Adresse de prise en charge'), findsOneWidget);
      expect(find.text('Rue LIB-41, 120'), findsOneWidget);
      expect(find.text('Entrée'), findsOneWidget);
      expect(find.text('Terminé'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    });
  });

  group('EditUserPositionPage Widget Tests', () {
    testWidgets('renders search field, choose on map, GPS, saved places and suggestions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: EditUserPositionPage(
            currentLocation: LatLng(14.6937, -17.4440),
            currentMainText: 'Rue YF-557, 20',
            currentSecondaryText: 'Yoff, Almadies, Dakar',
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));

      // Header & Search
      expect(find.text('Modifier votre position'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Fast options
      expect(find.text('Choisir sur la carte'), findsOneWidget);
      expect(find.text('Déplacer le repère vers votre position exacte'), findsOneWidget);
      expect(find.text('Ma position actuelle'), findsOneWidget);
      expect(find.text('Lieux enregistrés'), findsOneWidget);
    });
  });
}
