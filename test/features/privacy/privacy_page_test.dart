import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/features/drawer/presentation/widgets/seddo_drawer_widget.dart';
import 'package:seddo/features/privacy/presentation/pages/privacy_page.dart';
import '../../test_helpers/test_localization_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  group('PrivacyPage Widget Tests', () {
    testWidgets('PrivacyPage renders all sections and components correctly', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const PrivacyPage(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Top bar
      expect(find.text('Confidentialité'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // 2. Hero Royal Blue Banner
      expect(find.text('Tes données t\'appartiennent'), findsOneWidget);
      expect(
        find.text(
          'Tu décides de ce que Seddo collecte et de ce que tu veux effacer.',
        ),
        findsOneWidget,
      );

      // 3. Section POSITION
      expect(find.text('POSITION'), findsOneWidget);
      expect(find.text('Pendant l\'utilisation'), findsOneWidget);
      expect(find.text('Toujours'), findsOneWidget);
      expect(find.text('Position précise'), findsOneWidget);
      expect(
        find.text('Pour trouver les chauffeurs et arrêts proches'),
        findsOneWidget,
      );

      // 4. Section UTILISATION DE TES DONNÉES
      expect(find.text('UTILISATION DE TES DONNÉES'), findsOneWidget);
      expect(find.text('Suggestions personnalisées'), findsOneWidget);
      expect(find.text('Offres et promotions'), findsOneWidget);
      expect(find.text('Statistiques d\'usage'), findsOneWidget);
      expect(find.text('Accès aux contacts'), findsOneWidget);
      expect(find.text('Désactivé'), findsOneWidget);

      // 5. Section MES DONNÉES
      expect(find.text('MES DONNÉES'), findsOneWidget);
      expect(find.text('Télécharger mes données'), findsOneWidget);
      expect(find.text('Effacer l\'historique des courses'), findsOneWidget);
      expect(find.text('Supprimer mon compte'), findsOneWidget);

      // 6. Footer links
      expect(find.text('Politique de confidentialité'), findsOneWidget);
      expect(find.text('Conditions d\'utilisation'), findsOneWidget);
    });

    testWidgets('Tapping segmented control changes location permission selection', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const PrivacyPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Toujours
      await tester.tap(find.text('Toujours'));
      await tester.pumpAndSettle();

      // Tap Pendant l'utilisation
      await tester.tap(find.text('Pendant l\'utilisation'));
      await tester.pumpAndSettle();
    });

    testWidgets('Tapping switch toggles its value', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const PrivacyPage(),
        ),
      );
      await tester.pumpAndSettle();

      final switches = find.byType(CupertinoSwitch);
      expect(switches, findsNWidgets(4));

      // Initial state of precise location switch: true
      expect(tester.widget<CupertinoSwitch>(switches.at(0)).value, isTrue);

      // Tap precise location switch to disable
      await tester.tap(switches.at(0));
      await tester.pumpAndSettle();

      expect(tester.widget<CupertinoSwitch>(switches.at(0)).value, isFalse);
    });

    testWidgets('Tapping "Télécharger mes données" opens download confirmation modal', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const PrivacyPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to "Télécharger mes données" and tap
      final downloadTile = find.text('Télécharger mes données');
      await tester.ensureVisible(downloadTile);
      await tester.pumpAndSettle();
      await tester.tap(downloadTile);
      await tester.pumpAndSettle();

      expect(find.text('Confirmer la demande'), findsOneWidget);
    });

    testWidgets('Tapping Confidentialité et données in drawer navigates to PrivacyPage', (
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
                child: const Text('Open Drawer'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      // Tap Confidentialité et données
      final privacyItem = find.text('drawer.privacy'.tr());
      expect(privacyItem, findsOneWidget);
      await tester.tap(privacyItem);
      await tester.pumpAndSettle();

      // PrivacyPage is displayed
      expect(find.byType(PrivacyPage), findsOneWidget);
      expect(find.text('Tes données t\'appartiennent'), findsOneWidget);
    });
  });
}
