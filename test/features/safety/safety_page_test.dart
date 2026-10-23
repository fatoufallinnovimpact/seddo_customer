import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/features/drawer/presentation/widgets/seddo_drawer_widget.dart';
import 'package:seddo/features/safety/presentation/pages/safety_page.dart';
import '../../test_helpers/test_localization_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  group('SafetyPage Widget Tests', () {
    testWidgets('SafetyPage renders all components matching the reference design', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const SafetyPage(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Top bar
      expect(find.text('Sécurité'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // 2. Hero Orange Banner
      expect(find.text('Ton trajet, protégé'), findsOneWidget);
      expect(
        find.text(
          'Alerte, partage et contacts de confiance, à portée de main.',
        ),
        findsOneWidget,
      );

      // 3. SOS Card
      expect(find.text('Alerte d\'urgence'), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);
      expect(
        find.text(
          'Maintiens le bouton 3 secondes pour prévenir tes contacts et le support Seddo.',
        ),
        findsOneWidget,
      );

      // 4. Section Contacts
      expect(find.text('CONTACTS D\'URGENCE'), findsOneWidget);
      expect(find.text('Moussa Diop'), findsOneWidget);
      expect(find.text('Frère · 77 456 12 09'), findsOneWidget);
      expect(find.text('Fatou Sow'), findsOneWidget);
      expect(find.text('Amie · 78 321 45 67'), findsOneWidget);
      expect(find.text('Ajouter un contact'), findsOneWidget);

      // 5. Section Pendant tes courses
      expect(find.text('PENDANT TES COURSES'), findsOneWidget);
      expect(
        find.text('Partage de trajet\nautomatique'),
        findsOneWidget,
      );
      expect(find.text('Code PIN de course'), findsOneWidget);
      expect(find.text('Alerte en cas de détour'), findsOneWidget);

      // 6. Section Numéros utiles
      expect(find.text('NUMÉROS UTILES'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
      expect(find.text('Police'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('Pompiers'), findsOneWidget);
      expect(find.text('1515'), findsOneWidget);
      expect(find.text('SAMU'), findsOneWidget);
    });

    testWidgets('Tapping switches toggles their state in SafetyPage', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const SafetyPage(),
        ),
      );
      await tester.pumpAndSettle();

      final switches = find.byType(CupertinoSwitch);
      expect(switches, findsNWidgets(3));

      // Initial state from SafetyState: autoShare is false, pinCode is true, detourAlert is true
      final switch1 = tester.widget<CupertinoSwitch>(switches.at(0));
      final switch2 = tester.widget<CupertinoSwitch>(switches.at(1));
      final switch3 = tester.widget<CupertinoSwitch>(switches.at(2));
      expect(switch1.value, isFalse);
      expect(switch2.value, isTrue);
      expect(switch3.value, isTrue);

      // Tap first switch to toggle autoShare
      await tester.ensureVisible(switches.at(0));
      await tester.pumpAndSettle();
      await tester.tap(switches.at(0));
      await tester.pumpAndSettle();

      final updatedSwitch1 = tester.widget<CupertinoSwitch>(switches.at(0));
      expect(updatedSwitch1.value, isTrue);
    });

    testWidgets('Tapping "+ Ajouter un contact" opens add contact bottom sheet', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const SafetyPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajouter un contact'));
      await tester.pumpAndSettle();

      // Bottom sheet displays form fields
      expect(find.text('Ajouter un contact d\'urgence'), findsOneWidget);
      expect(find.text('Nom complet'), findsOneWidget);
      expect(find.text('Lien de parenté'), findsOneWidget);
      expect(find.text('Numéro de téléphone'), findsOneWidget);
      expect(find.text('Enregistrer le contact'), findsOneWidget);
    });

    testWidgets('Tapping Sécurité in SeddoDrawerWidget opens SafetyPage', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: Scaffold(
            drawer: const SeddoDrawerWidget(),
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap Sécurité menu item
      final safetyItem = find.text('Sécurité');
      expect(safetyItem, findsOneWidget);
      await tester.tap(safetyItem);
      await tester.pumpAndSettle();

      // SafetyPage is displayed
      expect(find.byType(SafetyPage), findsOneWidget);
      expect(find.text('Ton trajet, protégé'), findsOneWidget);
      expect(find.text('Alerte d\'urgence'), findsOneWidget);
    });
  });
}
