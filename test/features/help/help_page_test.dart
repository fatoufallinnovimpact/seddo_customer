import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/features/help/presentation/pages/help_page.dart';
import 'package:seddo/features/drawer/presentation/widgets/seddo_drawer_widget.dart';
import '../../test_helpers/test_localization_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  group('HelpPage Widget Tests', () {
    testWidgets('HelpPage renders top bar, search bar, contact cards, FAQ and footer note', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const HelpPage(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Top bar
      expect(find.text('Aide'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // 2. Search bar
      expect(find.text('Rechercher dans l\'aide'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);

      // 3. Contact action cards
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('7j/7'), findsOneWidget);
      expect(find.text('Appeler'), findsOneWidget);
      expect(find.text('8h – 20h'), findsOneWidget);

      // 4. Questions fréquentes
      expect(find.text('QUESTIONS FRÉQUENTES'), findsOneWidget);
      expect(find.text('Comment payer avec Orange Money ?'), findsOneWidget);
      expect(find.text('Mon remboursement n\'est pas arrivé'), findsOneWidget);
      expect(find.text('Comment annuler une course ?'), findsOneWidget);

      // 5. Response time note
      expect(
        find.text('Réponse sous 24 h, notification à la réponse'),
        findsOneWidget,
      );
    });

    testWidgets('Tapping FAQ accordion item expands and collapses answer', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const HelpPage(),
        ),
      );
      await tester.pumpAndSettle();

      final questionFinder = find.text('Comment payer avec Orange Money ?');
      expect(questionFinder, findsOneWidget);

      // Tap to expand
      await tester.tap(questionFinder);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Sélectionnez "Orange Money" comme moyen de paiement'),
        findsOneWidget,
      );

      // Tap to collapse
      await tester.tap(questionFinder);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Sélectionnez "Orange Money" comme moyen de paiement'),
        findsNothing,
      );
    });

    testWidgets('Searching in help filters FAQ questions in real time', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const HelpPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter query "remboursement"
      await tester.enterText(find.byType(TextField), 'remboursement');
      await tester.pumpAndSettle();

      // Matches "Mon remboursement n'est pas arrivé"
      expect(find.text('Mon remboursement n\'est pas arrivé'), findsOneWidget);
      expect(find.text('Comment annuler une course ?'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.cancel));
      await tester.pumpAndSettle();

      // All questions are visible again
      expect(find.text('Comment annuler une course ?'), findsOneWidget);
    });

    testWidgets('Tapping Aide in drawer navigates to HelpPage', (
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

      // Tap Aide menu item
      final helpItem = find.text('drawer.help'.tr());
      expect(helpItem, findsOneWidget);
      await tester.tap(helpItem);
      await tester.pumpAndSettle();

      // HelpPage is displayed
      expect(find.byType(HelpPage), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Appeler'), findsOneWidget);
    });
  });
}
