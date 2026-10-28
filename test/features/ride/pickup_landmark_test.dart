import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/presentation/pages/ride_booking_page.dart';
import 'package:seddo/features/ride/presentation/widgets/pickup_landmark_sheet.dart';
import '../../test_helpers/test_localization_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  group('PickupLandmarkSheet Tests', () {
    testWidgets('Renders simplified UI without suggestions and saves entered landmark',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? savedResult;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    savedResult = await PickupLandmarkSheet.show(context);
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap button to open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // 1. Header is rendered
      expect(find.text('Comment vous trouver ?'), findsOneWidget);
      expect(find.text('Aide le chauffeur à vous repérer vite.'), findsOneWidget);

      // 2. Input textfield is rendered
      expect(find.byType(TextField), findsOneWidget);

      // 3. Suggestions are removed completely
      expect(find.text('Suggestions rapides'), findsNothing);
      expect(find.text('Au rond-point'), findsNothing);

      // 4. Buttons: Enregistrer and Annuler
      expect(find.text('Enregistrer'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);

      // 5. Enter custom text
      await tester.enterText(find.byType(TextField), 'Près de la pharmacie');
      await tester.pump();

      // Verify textfield now contains "Près de la pharmacie"
      expect(find.text('Près de la pharmacie'), findsOneWidget);

      // 6. Tap on "Enregistrer"
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      // Check result returned
      expect(savedResult, 'Près de la pharmacie');
    });

    testWidgets('Custom text input and clear button work as expected',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? savedResult;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    savedResult = await PickupLandmarkSheet.show(
                      context,
                      initialLandmark: 'Portail vert, en face de la pharmacie',
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open sheet with initial text
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Portail vert, en face de la pharmacie'), findsWidgets);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      // Enter new custom text
      await tester.enterText(find.byType(TextField), 'Devant la mosquée');
      await tester.pump();

      // Save
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(savedResult, 'Devant la mosquée');
    });

    testWidgets('Tapping Annuler cancels without saving',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? savedResult = 'initial';

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    savedResult = await PickupLandmarkSheet.show(context);
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(savedResult, isNull);
    });

    testWidgets('RideBookingPage automatically opens PickupLandmarkSheet when showHowToFindYouInitially is true',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final departure = PlaceSearchResult(
        id: 'dep_1',
        mainText: 'Point E',
        secondaryText: 'Dakar',
        fullAddress: 'Point E, Dakar',
        latitude: 14.6937,
        longitude: -17.4647,
      );
      final destination = PlaceSearchResult(
        id: 'dest_1',
        mainText: 'Almadies',
        secondaryText: 'Ngor-Almadies, Dakar',
        fullAddress: 'Almadies, Dakar',
        latitude: 14.7431,
        longitude: -17.5195,
      );

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: RideBookingPage(
            departure: departure,
            destination: destination,
            showHowToFindYouInitially: true,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Sheet opens automatically
      expect(find.byType(PickupLandmarkSheet), findsOneWidget);
      expect(find.text('Comment vous trouver ?'), findsWidgets);
      expect(find.text('Enregistrer'), findsOneWidget);

      // Type landmark
      await tester.enterText(find.byType(TextField), 'Devant l\'entrée');
      await tester.pump();

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      // Banner is displayed on RideBookingPage
      expect(find.text('Devant l\'entrée'), findsOneWidget);
    });
  });
}
