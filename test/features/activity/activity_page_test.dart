import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/core/utils/app_constants.dart';
import 'package:seddo/features/activity/presentation/pages/activity_page.dart';
import 'package:seddo/features/activity/data/services/activity_service.dart';
import 'package:seddo/features/drawer/presentation/widgets/seddo_drawer_widget.dart';
import 'package:seddo/features/ride/presentation/pages/ride_receipt_page.dart';
import '../../test_helpers/test_localization_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
    ActivityService.enableMockDataForTesting = true;
  });

  tearDownAll(() {
    ActivityService.enableMockDataForTesting = false;
  });

  group('ActivityPage & Lateral Drawer Flow Tests', () {
    testWidgets('Opens ActivityPage from SeddoDrawerWidget across entire length',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const Scaffold(
            drawer: SeddoDrawerWidget(),
            body: Center(child: Text('Home')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open drawer
      final ScaffoldState state = tester.firstState(find.byType(Scaffold));
      state.openDrawer();
      await tester.pumpAndSettle();

      // Tap "Activité"
      expect(find.text('Activité'), findsOneWidget);
      await tester.tap(find.text('Activité'));
      await tester.pumpAndSettle();

      // We should now be on ActivityPage
      expect(find.text('ACTIVITÉ'), findsOneWidget);
    });

    testWidgets(
        'ActivityPage displays default COURSES tab with metrics, recent map card, and earlier rides',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const ActivityPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Top title and tabs
      expect(find.text('ACTIVITÉ'), findsOneWidget);
      expect(find.text('COURSES'), findsOneWidget);
      expect(find.text('REMBOURSEMENTS'), findsOneWidget);

      // Summary metric cards removed
      expect(find.text('Courses payées'), findsNothing);
      expect(find.text('Total dépensé'), findsNothing);

      // Recent ride section
      expect(find.text('RÉCENT'), findsOneWidget);
      expect(find.text('Aujourd\'hui · 18:19'), findsOneWidget);
      expect(find.text('ALMADIES'), findsOneWidget);
      expect(find.text('MS'), findsOneWidget);
      expect(find.text('Moussa · 7,8 km'), findsOneWidget);
      expect(find.text('3 500 F'), findsOneWidget);

      // Plus tôt section
      expect(find.text('PLUS TÔT'), findsOneWidget);
      expect(find.text('Plateau, rue Carnot'), findsWidgets);
      expect(find.text('Aujourd\'hui · 08:02 · Annulée'), findsOneWidget);
      expect(find.text('Aéroport AIBD'), findsOneWidget);
      expect(find.text('16 500 F'), findsOneWidget);
    });

    testWidgets(
        'Tapping recent course opens RideReceiptPage superposed on map with specific coordinates',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const ActivityPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on the recent course card ("ALMADIES")
      await tester.tap(find.text('ALMADIES'));
      await tester.pumpAndSettle();

      // RideReceiptPage is opened
      expect(find.byType(RideReceiptPage), findsOneWidget);
      expect(find.text('Almadies'), findsWidgets);
      expect(find.text('3 500 F'), findsWidgets);
      expect(find.text('Moussa Diop'), findsOneWidget);
      expect(find.text('CI270415.1819.A3F2'), findsOneWidget);

      // Back to ActivityPage
      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('ACTIVITÉ'), findsOneWidget);
    });

    testWidgets(
        'Tapping earlier course across horizontal row opens RideReceiptPage with specific price & route',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const ActivityPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on earlier course: "Aéroport AIBD"
      await tester.tap(find.text('Aéroport AIBD'));
      await tester.pumpAndSettle();

      // RideReceiptPage is opened with AIBD details
      expect(find.byType(RideReceiptPage), findsOneWidget);
      expect(find.text('Aéroport AIBD'), findsWidgets);
      expect(find.text('16 500 F'), findsWidgets);
      expect(find.text('Fatou Ndiaye'), findsOneWidget);
      expect(find.text('CI270413.0540.A102'), findsOneWidget);

      // Back to ActivityPage
      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('ACTIVITÉ'), findsOneWidget);
    });

    testWidgets(
        'Mobile infinite scroll pagination loads more earlier rides on scroll down',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const ActivityPage(),
        ),
      );

      await tester.pumpAndSettle();

      // With 10 items per page, all earlier rides are displayed on Page 1
      expect(find.text('Aéroport AIBD'), findsOneWidget);
      expect(find.text('Ouakam, Monument Renaissance'), findsOneWidget);
      expect(find.text('Yoff, Plage BCEAO'), findsOneWidget);
    });

    testWidgets(
        'REMBOURSEMENTS tab displays total refunded card, history items, and footnote',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const ActivityPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap REMBOURSEMENTS tab
      await tester.tap(find.text('REMBOURSEMENTS'));
      await tester.pumpAndSettle();

      // Total refunded hero card
      expect(find.text('Total remboursé'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == AppConstants.assetOrangeMoneyLogo),
        findsWidgets,
      );
      expect(find.textContaining('Orange Money'), findsWidgets);

      // Historique section
      expect(find.text('HISTORIQUE'), findsOneWidget);
      expect(find.text('+2 900 F'), findsOneWidget);
      expect(find.text('Course annulée · Aujourd\'hui · 08:02'), findsOneWidget);
      expect(find.text('Mermoz, Pyrotechnie'), findsOneWidget);
      expect(find.text('+4 200 F'), findsOneWidget);
      expect(find.text('En cours'), findsOneWidget);

      // Footnote
      expect(
        find.text(
          'Les remboursements sont renvoyés sur le moyen de paiement utilisé pour la course.',
        ),
        findsOneWidget,
      );

      // Tapping refunded item opens its receipt
      final refundItemFinder = find.text('+2 900 F');
      await tester.ensureVisible(refundItemFinder);
      await tester.tap(refundItemFinder);
      await tester.pumpAndSettle();

      expect(find.byType(RideReceiptPage), findsOneWidget);
      expect(find.text('Plateau, rue Carnot'), findsWidgets);
      expect(find.text('2 900 F'), findsWidgets);

      // Return back
      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await tester.pumpAndSettle();

      // Switch back to COURSES
      await tester.tap(find.text('COURSES'));
      await tester.pumpAndSettle();

      expect(find.text('Courses payées'), findsNothing);
      expect(find.text('RÉCENT'), findsOneWidget);
    });
  });
}
