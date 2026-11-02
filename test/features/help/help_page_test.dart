import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/features/help/presentation/pages/help_page.dart';
import 'package:seddo/features/help/presentation/pages/support_tickets_page.dart';
import 'package:seddo/features/drawer/presentation/widgets/seddo_drawer_widget.dart';
import '../../test_helpers/test_localization_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  group('HelpPage Widget Tests', () {
    testWidgets(
        'HelpPage renders top bar, Mes réclamations card, contact cards, FAQ and footer note',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const HelpPage(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Top bar
      expect(find.text('Aide'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // 2. Mes réclamations card (replaced search bar per user request)
      expect(find.text('Mes réclamations'), findsOneWidget);
      expect(
        find.text('Suivi de vos demandes et objets perdus'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);

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

    testWidgets('Tapping FAQ accordion item expands and collapses answer',
        (tester) async {
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

    testWidgets('Tapping Mes réclamations card navigates to SupportTicketsPage',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const HelpPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Mes réclamations"
      final claimsCardFinder = find.text('Mes réclamations');
      expect(claimsCardFinder, findsOneWidget);
      await tester.tap(claimsCardFinder);
      await tester.pumpAndSettle();

      // Opened SupportTicketsPage
      expect(find.byType(SupportTicketsPage), findsOneWidget);
      expect(find.text('Mes réclamations'), findsWidgets);

      // Back to HelpPage
      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await tester.pumpAndSettle();

      expect(find.byType(HelpPage), findsOneWidget);
    });

    testWidgets('Tapping Aide in drawer navigates to HelpPage',
        (tester) async {
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

      // Tap Aide item
      final aideItemFinder = find.text('Aide');
      expect(aideItemFinder, findsOneWidget);
      await tester.tap(aideItemFinder);
      await tester.pumpAndSettle();

      // HelpPage is opened
      expect(find.byType(HelpPage), findsOneWidget);
      expect(find.text('Comment pouvons-nous vous aider ?'), findsOneWidget);
    });
  });
}
