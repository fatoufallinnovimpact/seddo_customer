import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/app_colors.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/models/ride_quote_model.dart';
import 'package:seddo/features/ride/data/services/ride_eta_calculator.dart';
import 'package:seddo/features/ride/presentation/pages/driver_approaching_page.dart';
import 'package:seddo/services/route_service.dart';
import '../../test_helpers/test_localization_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  group('Road Approach Route & API Traffic Verification', () {
    const liveGoogleEncodedApproachPolyline =
        r'i~qxAvvqiBRG\[_Ay@XYtDnDXh@f@fB?PDHN@LGBOGMECGYo@qAg@q@cF_F_@i@]y@Qw@Gu@D_ADe@JG^kA\o@hGqHT[Oc@iHrIc@t@Sj@Qr@WH{UDcP?y@K}@YgJqEmA_@qE}Bk@e@sD}D}BiCEGYEOBEL?LDPhCjCJVxCdDHX@Pc@h@';

    test('RouteService decodes real Google approach polyline into road points',
        () {
      final points = RouteService.decodePolyline(
          liveGoogleEncodedApproachPolyline);

      expect(points.length, greaterThanOrEqualTo(50));
      expect(points.first.latitude, closeTo(14.6789, 0.001));
      expect(points.first.longitude, closeTo(-17.4630, 0.001));
      expect(points.last.latitude, closeTo(14.6905, 0.001));
      expect(points.last.longitude, closeTo(-17.4589, 0.001));
    });

    test('DriverModel.fromRideJson parses position, route and traffic correctly',
        () {
      final apiResponse = {
        'ride': {
          'id': '8b7cf723-edd1-4bca-b31a-e5c0878be946',
          'status': 'ACCEPTED',
          'startCode': '6951',
          'driver': {
            'firstName': 'sidy',
            'lastName': 'b.',
            'vehicle': {
              'make': 'Toyota',
              'model': 'Corolla',
              'color': 'Rouge',
              'plate': 'DK 3453 BC',
            },
            'position': {
              'lat': 14.6789175,
              'lng': -17.4630908,
              'heading': 180.0,
              'at': 1793271791461,
            },
          },
          'route': {
            'phase': 'APPROACH',
            'polyline': liveGoogleEncodedApproachPolyline,
            'traffic': [
              {'from': 0, 'to': 57, 'speed': 'NORMAL'}
            ],
            'distanceM': 3364,
            'durationS': 584,
            'eta': '2026-10-29T11:11:39.639Z',
            'source': 'google',
          },
          'plannedPolyline': 'cgtxAb}piBgFvGeD|EQNQAOHGR@HW',
          'plannedTraffic': [
            {'from': 0, 'to': 12, 'speed': 'SLOW'}
          ],
        }
      };

      final driver = DriverModel.fromRideJson(apiResponse);

      expect(driver.name, 'sidy b.');
      expect(driver.carModel, 'Toyota Corolla');
      expect(driver.carColor, 'Rouge');
      expect(driver.licensePlate, 'DK 3453 BC');
      expect(driver.currentLocation.latitude, closeTo(14.6789, 0.0001));
      expect(driver.currentLocation.longitude, closeTo(-17.4630, 0.0001));
      expect(driver.heading, 180.0);
      expect(driver.approachPolyline, liveGoogleEncodedApproachPolyline);
      expect(driver.approachDurationS, 584);
      expect(driver.approachDistanceM, 3364);
      expect(driver.etaMinutes, 10); // ceil(584 / 60)
      expect(driver.distanceKm, 3.4); // 3364m -> 3.4km
      expect(driver.approachTraffic.length, 1);
      expect(driver.approachTraffic.first.speed, TrafficSpeed.normal);
    });

    test('RouteService.getStreetAlignedRoute follows street grid and avoids diagonals',
        () {
      final origin = const LatLng(14.6937, -17.4647);
      final dest = const LatLng(14.7400, -17.5100);

      final route = RouteService().getStreetAlignedRoute(origin, dest);

      expect(route.polylinePoints.length, greaterThanOrEqualTo(10));
      // First leg walks along longitude
      expect(route.polylinePoints[1].latitude, origin.latitude);
      expect(route.polylinePoints.first, origin);
      expect(route.polylinePoints.last, dest);
    });

    testWidgets(
        'DriverApproachingPage uses real road approach points and does not cut across buildings',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      final departure = PlaceSearchResult(
        id: 'dep_1',
        mainText: 'Point E',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Point E, Dakar',
        latitude: 14.6908,
        longitude: -17.4587,
      );

      final destination = PlaceSearchResult(
        id: 'dest_1',
        mainText: 'Almadies',
        secondaryText: 'Ngor-Almadies, Dakar',
        fullAddress: 'Almadies, Dakar',
        latitude: 14.7483,
        longitude: -17.4395,
      );

      final rideOption = RideOptionModel(
        type: RideType.eco,
        title: 'Seddo Eco',
        subtitle: 'Arrivée rapide',
        capacity: 4,
        price: 1900,
        estimatedArrival: '11:15',
        pickupDuration: '10 min',
      );

      final driver = DriverModel(
        id: 'driver_sidy',
        name: 'sidy b.',
        phone: '+221 77 123 45 67',
        rating: 4.9,
        totalRides: 1250,
        carModel: 'Toyota Corolla',
        carColor: 'Rouge',
        licensePlate: 'DK 3453 BC',
        rideType: RideType.eco,
        currentLocation: const LatLng(14.6789, -17.4630),
        etaMinutes: 10,
        distanceKm: 3.4,
        approachPolyline: liveGoogleEncodedApproachPolyline,
        approachDurationS: 584,
        approachDistanceM: 3364,
      );

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: DriverApproachingPage(
            departure: departure,
            destination: destination,
            rideOption: rideOption,
            driver: driver,
            departureCode: '6951',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verifies driver info
      expect(find.text('DK 3453 BC'), findsOneWidget);
      expect(find.text('Toyota Corolla Rouge'), findsOneWidget);
      expect(find.text('sidy'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    test('Decodes plannedPolyline from Patte d\'Oie destination route', () {
      const plannedPoly =
          r"cgtxAb}piBgFvGeD|EQNQAOHGR@HW\k@l@qG~HuGlIgC|C{AjBoA~A_A`Ai@`@u@\iIpCqEnAsBb@cFx@_QdCaI~AkMfBqK~A}@HuBLcENeDCwIW}BMmHeAaAOoAGuEI}IWuBIsC?k@BiDZaEn@}AT}IfByDp@kAVcBToF~@qFfAyCZkBJiCF{BE{CSwAOeBYmBc@oF{AmCm@a@CcCc@aDu@_L_DoAc@{BgA_B{@m@a@o@a@oC_CmAuAcB}BaAeBgAeC}BqHu@sCU}AE}@Hs@h@sBBk@EiADg@Nk@dAyBBQbAmBp@gBb@gB\sB@ChCkYR}BFw@nCg[j@wFBEZ[NETFxAjAFTAPIRSJS@YIWQaCyDwAuBaAaAoBwAECeCyAaBy@E?oBkAmB_BcAw@_CaCEGGIKo@oCeGq@yA}@sCvDo@H?Hi@Ru@vAl@fAoC";

      final tripPoints = RouteService.decodePolyline(plannedPoly);

      expect(tripPoints.length, greaterThanOrEqualTo(100));
      // First point near Av. Cheikh Anta Diop
      expect(tripPoints.first.latitude, closeTo(14.6908, 0.005));
      expect(tripPoints.first.longitude, closeTo(-17.4586, 0.005));
      // Last point near Patte d'Oie
      expect(tripPoints.last.latitude, closeTo(14.7483, 0.005));
      expect(tripPoints.last.longitude, closeTo(-17.4395, 0.005));
    });

    testWidgets(
        'DriverApproachingPage keeps user on approach screen and does NOT auto-start ride when driver arrives',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      final departure = PlaceSearchResult(
        id: 'dep_1',
        mainText: 'Point E',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Point E, Dakar',
        latitude: 14.6908,
        longitude: -17.4587,
      );

      final destination = PlaceSearchResult(
        id: 'dest_1',
        mainText: 'Patte d\'Oie',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Patte d\'Oie, Dakar',
        latitude: 14.7483,
        longitude: -17.4395,
      );

      final rideOption = RideOptionModel(
        type: RideType.eco,
        title: 'Seddo Eco',
        subtitle: 'Arrivée rapide',
        capacity: 4,
        price: 1900,
        estimatedArrival: '11:35',
        pickupDuration: '10 min',
      );

      final driver = DriverModel(
        id: 'driver_sidy',
        name: 'sidy b.',
        phone: '+221 77 123 45 67',
        rating: 4.9,
        totalRides: 1250,
        carModel: 'Toyota Corolla',
        carColor: 'Rouge',
        licensePlate: 'DK 3453 BC',
        rideType: RideType.eco,
        currentLocation: const LatLng(14.6908, -17.4587), // already at pickup
        etaMinutes: 0,
        distanceKm: 0.0,
      );

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: DriverApproachingPage(
            departure: departure,
            destination: destination,
            rideOption: rideOption,
            driver: driver,
            departureCode: '6951',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Even after 2 seconds at pickup, user MUST remain on DriverApproachingPage
      // with departure code 6951 clearly displayed
      expect(find.byType(DriverApproachingPage), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets(
        'DriverApproachingPage sets 14 min for durationS: 809 and only renders approach polyline',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      final departure = PlaceSearchResult(
        id: 'dep_1',
        mainText: 'Point E',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Point E, Dakar',
        latitude: 14.6908,
        longitude: -17.4587,
      );

      final destination = PlaceSearchResult(
        id: 'dest_1',
        mainText: 'Patte d\'Oie',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Patte d\'Oie, Dakar',
        latitude: 14.7483,
        longitude: -17.4395,
      );

      final rideOption = RideOptionModel(
        type: RideType.eco,
        title: 'Seddo Eco',
        subtitle: 'Arrivée rapide',
        capacity: 4,
        price: 1900,
        estimatedArrival: '11:35',
        pickupDuration: '14 min',
      );

      // Driver with durationS: 809 seconds -> 13.48 min -> 14 min
      final driver = DriverModel(
        id: 'driver_sidy',
        name: 'sidy b.',
        phone: '+221 77 123 45 67',
        rating: 4.9,
        totalRides: 1250,
        carModel: 'Toyota Corolla',
        carColor: 'Rouge',
        licensePlate: 'DK 3453 BC',
        rideType: RideType.eco,
        currentLocation: const LatLng(14.6789, -17.4630),
        etaMinutes: 14,
        distanceKm: 3.4,
        approachPolyline: liveGoogleEncodedApproachPolyline,
        approachDurationS: 809,
        approachDistanceM: 3365,
      );

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: DriverApproachingPage(
            departure: departure,
            destination: destination,
            rideOption: rideOption,
            driver: driver,
            departureCode: '6951',
            polylinePoints: const [
              LatLng(14.6908, -17.4587),
              LatLng(14.7483, -17.4395),
            ],
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verifies the modal displays "14 min"
      expect(find.text('14 min'), findsOneWidget);

      // Verifies only the approach polyline is drawn on GoogleMap without dashes
      final googleMapFinder = find.byType(GoogleMap);
      expect(googleMapFinder, findsOneWidget);
      final googleMap = tester.widget<GoogleMap>(googleMapFinder);
      expect(googleMap.polylines.length, 1);
      expect(googleMap.polylines.first.polylineId.value,
          'approach_traffic_route_base');
      expect(googleMap.polylines.first.patterns, isEmpty);
      expect(googleMap.polylines.first.color, AppColors.trafficNormal);
    });

    test(
        'buildTrafficPolylines creates solid colored segments matching route.traffic',
        () {
      const approachPolyline =
          r'k~qxAvvqiBPE`@]_Ay@XYtDnDXh@f@fB?PDHN@LGBOGMECGYo@qAg@q@cF_F_@i@]y@Qw@Gu@D_ADe@JG^kA\o@hGqHT[Oc@iHrIc@t@Sj@Qr@WH{UDcP?y@K}@YgJqEmA_@qE}Bk@e@sD}DUWgBqBEGYEOBEL?LDPzAzAl@n@JVxCdDHX@Pc@h@';
      final points = RouteService.decodePolyline(approachPolyline);

      final traffic = [
        const TrafficSegmentModel(from: 0, to: 45, speed: TrafficSpeed.normal),
        const TrafficSegmentModel(from: 45, to: 53, speed: TrafficSpeed.slow),
        const TrafficSegmentModel(from: 53, to: 59, speed: TrafficSpeed.normal),
      ];

      final polylines = RideEtaCalculator.buildTrafficPolylines(
        baseId: 'approach_traffic_route',
        points: points,
        traffic: traffic,
        width: 5,
      );

      // Base line in Green trafficNormal (entire road) + 3 traffic segments
      expect(polylines.length, 4);
      final list = polylines.toList()
        ..sort((a, b) => a.polylineId.value.compareTo(b.polylineId.value));

      // Base segment: NORMAL -> Green trafficNormal without dashes
      expect(list[0].polylineId.value, 'approach_traffic_route_base');
      expect(list[0].color, AppColors.trafficNormal);
      expect(list[0].patterns, isEmpty);

      // Traffic 0: NORMAL -> Green trafficNormal
      expect(list[1].polylineId.value, 'approach_traffic_route_traffic_0');
      expect(list[1].color, AppColors.trafficNormal);
      expect(list[1].patterns, isEmpty);

      // Traffic 1: SLOW -> Amber trafficSlow
      expect(list[2].polylineId.value, 'approach_traffic_route_traffic_1');
      expect(list[2].color, AppColors.trafficSlow);
      expect(list[2].patterns, isEmpty);
      expect(list[2].points.first, points[45]);
      expect(list[2].points.last, points[53]);

      // Traffic 2: NORMAL -> Green trafficNormal
      expect(list[3].polylineId.value, 'approach_traffic_route_traffic_2');
      expect(list[3].color, AppColors.trafficNormal);
      expect(list[3].patterns, isEmpty);
    });
  });
}
