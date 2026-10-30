import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/core/utils/service_area_helper.dart';
import 'package:seddo/features/ride/presentation/widgets/service_unavailable_sheet.dart';
import '../../test_helpers/test_localization_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });
  group('ServiceAreaHelper Unit Tests', () {
    test('Identifies locations in Dakar and AIBD as supported', () {
      // Almadies (Dakar)
      expect(
        ServiceAreaHelper.isWithinServiceCoordinates(14.7431, -17.5195),
        isTrue,
      );
      expect(
        ServiceAreaHelper.getOutsideCityName(
          latitude: 14.7431,
          longitude: -17.5195,
          address: 'Almadies, Dakar',
        ),
        isNull,
      );

      // AIBD airport
      expect(
        ServiceAreaHelper.isWithinServiceCoordinates(14.6710, -17.0733),
        isTrue,
      );
      expect(
        ServiceAreaHelper.getOutsideCityName(
          latitude: 14.6710,
          longitude: -17.0733,
          address: 'Aéroport International Blaise Diagne, AIBD',
        ),
        isNull,
      );
    });

    test('Identifies outside cities like Thiès, Mbour, Saint-Louis as unsupported', () {
      // Thiès
      expect(
        ServiceAreaHelper.getOutsideCityName(
          latitude: 14.7910,
          longitude: -16.9256,
          address: 'Centre-ville, Thiès',
        ),
        equals('Thiès'),
      );

      // Mbour
      expect(
        ServiceAreaHelper.getOutsideCityName(
          latitude: 14.4220,
          longitude: -16.9639,
          address: 'Mbour, Sénégal',
        ),
        equals('Mbour'),
      );
    });
  });

  group('ServiceUnavailableSheet Widget Tests', () {
    testWidgets('Renders all content and triggers actions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      ServiceUnavailableAction? selectedAction;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      selectedAction = await ServiceUnavailableSheet.show(
                        context,
                        cityName: 'Thiès',
                      );
                    },
                    child: const Text('Show Sheet'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Verify content
      expect(find.text('Thiès'), findsOneWidget);
      expect(find.textContaining('Seddo n\'est pas encore'), findsOneWidget);
      expect(
        find.text(
          'Seddo roule à Dakar, Pikine, Guédiawaye, Rufisque et vers l\'aéroport AIBD.',
        ),
        findsOneWidget,
      );
      expect(find.text('Me prévenir à l\'ouverture'), findsOneWidget);
      expect(find.text('Changer de destination'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);

      // Tap "Changer de destination"
      await tester.tap(find.text('Changer de destination'));
      await tester.pumpAndSettle();

      expect(selectedAction, ServiceUnavailableAction.changeDestination);
    });
  });
}
