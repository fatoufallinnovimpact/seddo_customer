import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/presentation/pages/ride_booking_page.dart';
import 'package:seddo/features/ride/presentation/widgets/ride_map_camera_toggle_button.dart';
import '../../test_helpers/test_localization_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initTestLocalization();
  });

  const departureLocation = LatLng(14.6937, -17.4647);
  const destinationLocation = LatLng(14.7431, -17.5195);
  final polylinePoints = [departureLocation, destinationLocation];

  group('RideMapCameraToggleButton Tests', () {
    testWidgets(
        'On full route -> Shows FLAG -> Tap moves to Destination -> Shows DEPARTURE -> Tap moves to Departure -> Shows TRIP -> Tap moves to Route Overview -> Shows FLAG',
        (tester) async {
      RideMapCameraMode currentMode = RideMapCameraMode.tripOverview;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RideMapCameraToggleButton(
                mapControllerGetter: () => null,
                departureLocation: departureLocation,
                destinationLocation: destinationLocation,
                polylinePoints: polylinePoints,
                initialMode: RideMapCameraMode.tripOverview,
                onModeChanged: (mode) => currentMode = mode,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Étape 1 : La carte affiche tout le trajet (tripOverview)
      // -> Le bouton affiche l'icône FLAG pour aller au point d'arrivée
      expect(currentMode, RideMapCameraMode.tripOverview);
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byIcon(Icons.hail_rounded), findsNothing);

      // Tap sur l'icône FLAG -> La caméra se déplace au point d'arrivée (destination)
      // -> Le bouton change et affiche l'icône du point de départ (silhouette passager)
      await tester.tap(find.byType(RideMapCameraToggleButton));
      await tester.pumpAndSettle();

      expect(currentMode, RideMapCameraMode.destination);
      expect(find.byIcon(Icons.hail_rounded), findsOneWidget);

      // Tap sur l'icône point de départ -> La caméra se déplace au point de départ (departure)
      // -> Le bouton change et affiche l'icône TRIP (tracé du trajet)
      await tester.tap(find.byType(RideMapCameraToggleButton));
      await tester.pumpAndSettle();

      expect(currentMode, RideMapCameraMode.departure);
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byIcon(Icons.hail_rounded), findsNothing);

      // Tap sur l'icône TRIP -> La caméra affiche à nouveau le tracé complet (tripOverview)
      // -> Le bouton redevient l'icône FLAG
      await tester.tap(find.byType(RideMapCameraToggleButton));
      await tester.pumpAndSettle();

      expect(currentMode, RideMapCameraMode.tripOverview);
      expect(find.byType(SvgPicture), findsOneWidget);
    });
  });

  group('RideBookingPage Header & Modal Layout Integration', () {
    testWidgets(
        'Displays "Choisissez une course" & zone at top of modal, then Departure and Destination (without Arrêts button, without Orange Money card)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      final departure = PlaceSearchResult(
        id: 'dep_test',
        mainText: 'Rue FN-48, 12',
        secondaryText: 'Dakar',
        fullAddress: 'Rue FN-48, 12, Dakar',
        latitude: 14.6937,
        longitude: -17.4647,
      );

      final destination = PlaceSearchResult(
        id: 'dest_test',
        mainText: 'Eticca Dakar',
        secondaryText: 'Mermoz, Dakar',
        fullAddress: 'Eticca Dakar, Dakar',
        latitude: 14.7431,
        longitude: -17.5195,
      );

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: RideBookingPage(
            departure: departure,
            destination: destination,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Bouton flottant de caméra présent
      expect(find.byType(RideMapCameraToggleButton), findsOneWidget);

      // 2. "Choisissez une course" et "Dakar et banlieue" présents en haut
      expect(find.text('Choisissez une course'), findsOneWidget);
      expect(find.text('Dakar et banlieue'), findsOneWidget);

      // 3. Ligne de départ avec icône silhouette et texte
      expect(find.byIcon(Icons.hail_rounded), findsWidgets);
      expect(find.text('Rue FN-48, 12'), findsOneWidget);

      // 4. Ligne d'arrivée avec nom de destination
      expect(find.text('Eticca Dakar'), findsWidgets);

      // 5. Le bouton / texte "Arrêts" a bien été enlevé
      expect(find.text('Arrêts'), findsNothing);

      // 6. La carte Orange Money plus le numéro a bien été enlevée du modal
      expect(find.text('Prix fixe, payé à la commande'), findsNothing);
      expect(find.text('OM'), findsNothing);
    });
  });
}
