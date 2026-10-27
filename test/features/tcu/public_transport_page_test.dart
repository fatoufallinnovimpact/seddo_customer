import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/drawer/presentation/widgets/seddo_drawer_widget.dart';
import 'package:seddo/features/tcu/data/models/tcu_route_model.dart';
import 'package:seddo/features/tcu/data/services/public_transport_service.dart';
import 'package:seddo/features/tcu/presentation/pages/public_transport_page.dart';
import 'package:seddo/features/tcu/presentation/pages/public_transport_stop_route_page.dart';
import '../../test_helpers/test_localization_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  group('TCU Public Transport Page & Navigation Flow Tests', () {
    testWidgets('Opens PublicTransportPage from SeddoDrawerWidget across entire row',
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

      // Tap "TCU"
      expect(find.text('TCU'), findsOneWidget);
      await tester.tap(find.text('TCU'));
      await tester.pumpAndSettle();

      // We should now be on PublicTransportPage
      expect(find.byType(PublicTransportPage), findsOneWidget);
      expect(find.text('Où allons-nous ?'), findsOneWidget);
    });

    testWidgets(
        'PublicTransportPage renders header, origin/destination swap, date/time search and filters',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const PublicTransportPage(
            initialOrigin: 'Fann Hock',
            initialDestination: 'Liberté 6',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header title
      expect(find.text('Où allons-nous ?'), findsOneWidget);

      // Default origin and destination
      expect(find.text('Fann Hock'), findsWidgets);
      expect(find.text('Liberté 6'), findsWidgets);

      // Swap button inverts fields
      final swapButton = find.byKey(const Key('tcu_swap_button'));
      await tester.tap(swapButton);
      await tester.pumpAndSettle();

      // Date & Time pickers and Rechercher button matching user attachment
      expect(find.byKey(const Key('tcu_date_picker_button')), findsOneWidget);
      expect(find.byKey(const Key('tcu_time_picker_button')), findsOneWidget);
      expect(find.byKey(const Key('tcu_search_button')), findsOneWidget);

      // Filter pills: Plus rapide, Alternative, Panoramique
      expect(find.text('Plus rapide'), findsOneWidget);
      expect(find.text('Alternative'), findsOneWidget);
      expect(find.text('Panoramique'), findsOneWidget);
      expect(find.text('26 min'), findsOneWidget);
      expect(find.text('33 min'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);

      // Before search, placeholder is shown and route options are not yet loaded
      expect(find.text('Où et quand souhaitez-vous partir ?'), findsOneWidget);
      expect(find.textContaining('DDD 10'), findsNothing);

      // Tap "Rechercher"
      await tester.tap(find.byKey(const Key('tcu_search_button')));
      await tester.pumpAndSettle();

      // Options now displayed
      expect(find.text('4 options pour votre trajet'), findsOneWidget);
      expect(find.textContaining('B1'), findsOneWidget);

      // Filter by Alternative
      await tester.tap(find.byKey(const Key('tcu_filter_alternative')));
      await tester.pumpAndSettle();

      expect(find.text('2 options pour votre trajet'), findsOneWidget);
      expect(find.textContaining('AFTU 24'), findsOneWidget);
    });

    testWidgets(
        'Card displays 3 metric columns, expandable stops, and opens navigation map',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const PublicTransportPage(
            autoSearch: true,
            initialOrigin: 'Fann Hock',
            initialDestination: 'Liberté 6',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Select Panoramique filter to bring DDD 10 to top
      final panoramicFilter = find.byKey(const Key('tcu_filter_panoramic'));
      await tester.ensureVisible(panoramicFilter);
      await tester.pumpAndSettle();
      await tester.tap(panoramicFilter);
      await tester.pumpAndSettle();

      // Verify DDD 10 card
      expect(find.textContaining('DDD 10'), findsOneWidget);
      expect(find.text('19 min'), findsWidgets);
      expect(find.text('Prochain'), findsWidgets);
      expect(find.text('Durée'), findsWidgets);
      expect(find.text('Arrêts'), findsWidgets);

      // Expand stops list
      final arretsButton =
          find.widgetWithText(OutlinedButton, 'Arrêts').first;
      await tester.tap(arretsButton);
      await tester.pumpAndSettle();

      expect(find.text('Liste des arrêts'), findsOneWidget);
      expect(find.text('Fann Résidence'), findsOneWidget);
      expect(find.text('Stade Marius Ndiaye'), findsWidgets);

      // Tap "Itinéraire vers l'arrêt"
      final itineraireButton =
          find.widgetWithText(ElevatedButton, 'Itinéraire vers l\'arrêt').first;
      await tester.tap(itineraireButton);
      await tester.pumpAndSettle();

      // Navigated to PublicTransportStopRoutePage
      expect(find.byType(PublicTransportStopRoutePage), findsOneWidget);
      expect(find.text('Démarrer la marche'), findsOneWidget);
      expect(find.text('À pied'), findsOneWidget);

      // Tap "Démarrer la marche"
      await tester.tap(find.text('Démarrer la marche'));
      await tester.pumpAndSettle();

      expect(find.text('Arrêter le guidage'), findsOneWidget);
    });

    testWidgets('PublicTransportPage renders translated title in Wolof',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const PublicTransportPage(),
        ),
      );

      await tester.pumpAndSettle();

      final BuildContext context =
          tester.element(find.byType(PublicTransportPage));
      await context.setLocale(const Locale('wo'));
      await tester.pumpAndSettle();

      // Wolof title
      expect(find.text('Fan lañuy dem ?'), findsOneWidget);
      expect(find.text('Gën a gaaw'), findsOneWidget);
      expect(find.text('Fi ngay jóge'), findsOneWidget);
      expect(find.text('Fa ngay dem'), findsOneWidget);

      // Reset to French
      await context.setLocale(const Locale('fr'));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'Floating Seddo VTC card is displayed, dismissible with cross, and navigates to PlaceSearchPage',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const PublicTransportPage(
            autoSearch: true,
            initialOrigin: 'Fann Hock',
            initialDestination: 'Liberté 6',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Seddo card elements
      expect(find.text('En Seddo : 19 min, porte'), findsOneWidget);
      expect(find.text('à porte'), findsWidgets);
      expect(find.text('Prix fixe 3 200 F'), findsOneWidget);
      expect(find.byKey(const Key('tcu_seddo_commander_button')), findsOneWidget);

      // Dismiss card with cross
      final closeButton = find.byKey(const Key('tcu_seddo_card_close'));
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // Card is now dismissed
      expect(find.text('En Seddo : 19 min, porte'), findsNothing);
    });

    testWidgets(
        'Tapping Commander on Seddo card navigates to PlaceSearchPage with prefilled fields',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const PublicTransportPage(
            autoSearch: true,
            initialOrigin: 'Ouakam',
            initialDestination: 'Plateau',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "Commander"
      final commanderButton =
          find.byKey(const Key('tcu_seddo_commander_button'));
      await tester.tap(commanderButton);
      await tester.pumpAndSettle();

      // Navigated to PlaceSearchPage with prefilled departure & destination
      expect(find.text('VOTRE TRAJET'), findsOneWidget);
      expect(find.text('Ouakam'), findsWidgets);
      expect(find.text('Plateau'), findsWidgets);
    });

    testWidgets('Selecting Ma position and autocomplete updates origin/destination',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const PublicTransportPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "Ma position"
      expect(find.text('Ma position'), findsOneWidget);
      await tester.tap(find.text('Ma position'));
      await tester.pumpAndSettle();

      expect(find.text('Ma position actuelle'), findsWidgets);
    });

    testWidgets(
        'PublicTransportPage scrolls as a single page so header and search box move on scroll',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: const PublicTransportPage(
            autoSearch: true,
            initialOrigin: 'Fann Hock',
            initialDestination: 'Liberté 6',
          ),
        ),
      );

      await tester.pumpAndSettle();

      final headerFinder = find.text('Où allons-nous ?');
      expect(headerFinder, findsOneWidget);
      final initialHeaderY = tester.getTopLeft(headerFinder).dy;

      // Drag up to scroll the page down
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();

      final scrolledHeaderY = tester.getTopLeft(headerFinder).dy;
      // Header has moved up along with the rest of the page
      expect(scrolledHeaderY, lessThan(initialHeaderY));
    });

    testWidgets(
        'PublicTransportStopRoutePage opens GoogleMap and live decrements remaining distance on start walking',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      final service = PublicTransportService();
      final options = await tester.runAsync(() => service.getRouteOptions());
      final sampleOption = options!.first;

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: PublicTransportStopRoutePage(routeOption: sampleOption),
        ),
      );

      await tester.pumpAndSettle();

      // 1. GoogleMap is mounted directly
      expect(find.byType(GoogleMap), findsOneWidget);
      expect(
          find.byKey(const Key('tcu_stop_route_google_map')), findsOneWidget);

      // 2. Initial distance and stat cards are displayed
      final initialMeters = sampleOption.departureStop.walkingDistanceMeters;
      expect(find.text('$initialMeters m'), findsOneWidget);
      expect(find.text('Démarrer la marche'), findsOneWidget);
      expect(find.text('À pied'), findsOneWidget);

      // 3. Tap "Démarrer la marche"
      await tester.tap(find.text('Démarrer la marche'));
      await tester.pumpAndSettle();

      // 4. Button switched to "Arrêter le guidage"
      expect(find.text('Arrêter le guidage'), findsOneWidget);

      // 5. Stat box now shows "Restant" and remaining distance has decreased
      expect(find.text('Restant'), findsOneWidget);
      expect(find.textContaining('restants'), findsOneWidget);
    });

    test('PublicTransportService returns default options and filters correctly',
        () async {
      final service = PublicTransportService();

      final all = await service.getRouteOptions();
      expect(all.length, 4);

      final ddd = await service.getRouteOptions(filter: TcuTransportType.ddd);
      expect(ddd.length, 1);
      expect(ddd.first.lineCode, 'DDD 10');

      final brt = await service.getRouteOptions(filter: TcuTransportType.brt);
      expect(brt.length, 1);
      expect(brt.first.lineCode, 'B1');

      final aftu = await service.getRouteOptions(filter: TcuTransportType.aftu);
      expect(aftu.length, 1);
      expect(aftu.first.lineCode, 'AFTU 24');

      final ter = await service.getRouteOptions(filter: TcuTransportType.ter);
      expect(ter.length, 1);
      expect(ter.first.lineCode, 'TER');
    });
  });
}


