import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/tcu/data/models/transit/ItineraireLegModel.dart';
import 'package:seddo/features/tcu/data/models/transit/PlaceModel.dart';
import 'package:seddo/features/tcu/data/models/transit/StopTimeResponse.dart';
import 'package:seddo/features/tcu/data/models/transit/TransitTripModel.dart';
import 'package:seddo/features/tcu/data/services/public_transport_service.dart';
import 'package:seddo/features/tcu/presentation/pages/RouteTimelinePage.dart';
import 'package:seddo/features/tcu/presentation/pages/public_transport_page.dart';
import 'package:seddo/features/tcu/presentation/widgets/PlaceSearchWidget.dart';
import '../../test_helpers/test_localization_helper.dart';

void main() {
  setUpAll(() async {
    await initTestLocalization();
    PublicTransportService.enableMockDataForTesting = true;
  });

  tearDownAll(() {
    PublicTransportService.enableMockDataForTesting = false;
  });
  testWidgets('PlaceSearchWidget displays Icons.close_rounded with AppColors.neutralIconGrey when text is not empty',
      (WidgetTester tester) async {
    PlaceModel? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceSearchWidget(
            label: 'Origine',
            icon: const Icon(Icons.my_location_rounded),
            initPlace: PlaceModel(
              name: 'Fann Hock',
              address: 'Dakar',
              latitude: 14.68,
              longitude: -17.45,
            ),
            onLocationSelected: (place) {
              selected = place;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify close icon is rendered
    final closeIconFinder = find.byIcon(Icons.close_rounded);
    expect(closeIconFinder, findsOneWidget);

    final Icon iconWidget = tester.widget(closeIconFinder);
    expect(iconWidget.size, 20);
    expect(iconWidget.color, AppColors.neutralIconGrey);

    // Tap to clear
    await tester.tap(closeIconFinder);
    await tester.pumpAndSettle();

    // After clearing, close icon should disappear
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(selected?.name, '');
  });

  testWidgets('PublicTransportPage renders swap button between origin and destination cards and swaps them',
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

    final swapFinder = find.byKey(const Key('tcu_swap_button'));
    expect(swapFinder, findsOneWidget);

    final originFinder = find.byKey(const Key('tcu_origin_search'));
    final destinationFinder = find.byKey(const Key('tcu_destination_search'));
    expect(originFinder, findsOneWidget);
    expect(destinationFinder, findsOneWidget);

    // Verify swap button Y position is between origin top and destination bottom
    final originTop = tester.getTopLeft(originFinder).dy;
    final destinationBottom = tester.getBottomLeft(destinationFinder).dy;
    final swapCenter = tester.getCenter(swapFinder).dy;

    expect(swapCenter > originTop, isTrue);
    expect(swapCenter < destinationBottom, isTrue);

    // Verify Origin field does NOT have the departure prefix icon (my_location_rounded)
    expect(
      find.descendant(
        of: originFinder,
        matching: find.byIcon(Icons.my_location_rounded),
      ),
      findsNothing,
    );
    // Destination field has its location icon
    expect(
      find.descendant(
        of: destinationFinder,
        matching: find.byIcon(Icons.location_on_rounded),
      ),
      findsOneWidget,
    );

    // Tap swap
    await tester.tap(swapFinder);
    await tester.pumpAndSettle();
  });

  testWidgets('Itineraire cards display bus names and arrow for correspondances',
      (WidgetTester tester) async {
    final itineraireDirect = ItineraireModel(
      legs: [
        ItineraireLegModel(
          trip: TransitTripModel(
            id: 1,
            tripId: '1',
            stopId: '1',
            routeId: 'AFTU_4',
            serviceId: '',
            tripHeadsign: '',
            tripShortName: '4',
            directionId: '0',
            shapeId: '',
          ),
          trafficDurationSeconds: 1560,
        ),
      ],
      isDirect: true,
      totalLegs: 1,
      totalTrafficDurationSeconds: 1560,
      score: 1.0,
      label: 'Plus rapide',
    );

    final itineraireCorrespondance = ItineraireModel(
      legs: [
        ItineraireLegModel(
          trip: TransitTripModel(
            id: 1,
            tripId: '1',
            stopId: '1',
            routeId: 'AFTU_4',
            serviceId: '',
            tripHeadsign: '',
            tripShortName: '4',
            directionId: '0',
            shapeId: '',
          ),
          trafficDurationSeconds: 900,
        ),
        ItineraireLegModel(
          trip: TransitTripModel(
            id: 2,
            tripId: '2',
            stopId: '2',
            routeId: 'DDD_1',
            serviceId: '',
            tripHeadsign: '',
            tripShortName: '1',
            directionId: '0',
            shapeId: '',
          ),
          trafficDurationSeconds: 1080,
        ),
      ],
      isDirect: false,
      totalLegs: 2,
      totalTrafficDurationSeconds: 1980,
      score: 0.9,
      label: 'Alternative',
    );

    expect(itineraireDirect.busNames, ['AFTU 4']);
    expect(itineraireDirect.busSummary, 'AFTU 4');

    expect(itineraireCorrespondance.busNames, ['AFTU 4', 'DDD 1']);
    expect(itineraireCorrespondance.busSummary, 'AFTU 4 → DDD 1');

    int selected = 0;
    await tester.pumpWidget(
      wrapWithTestLocalization(
        child: Scaffold(
          body: ItineraireTabBar(
            itineraires: [
              itineraireDirect,
              itineraireCorrespondance,
            ],
            selectedIndex: selected,
            onTap: (index) {
              selected = index;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify bus names and arrow rendered
    expect(find.text('AFTU 4'), findsWidgets);
    expect(find.text('DDD 1'), findsWidgets);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsWidgets);
  });
}
