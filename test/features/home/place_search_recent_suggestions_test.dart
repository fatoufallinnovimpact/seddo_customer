import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/data/models/home_suggestions_model.dart';
import 'package:seddo/features/home/presentation/pages/place_search_page.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/features/ride/presentation/pages/ride_booking_page.dart';
import 'package:seddo/services/places_service.dart';
import '../../test_helpers/test_localization_helper.dart';

class MockPlacesHttpClientAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({'suggestions': []}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeRideService extends RideService {
  final HomeSuggestionsModel? mockSuggestions;
  int getSuggestionsCallCount = 0;

  FakeRideService({this.mockSuggestions});

  @override
  Future<HomeSuggestionsModel?> getSuggestions() async {
    getSuggestionsCallCount++;
    return mockSuggestions;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initTestLocalization();
  });

  group('PlaceSearchPage Recent Suggestions & Destinations', () {
    testWidgets('Loads up to 4 recent destinations from GET /v1/users/me/suggestions and displays real names and addresses',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;

      final mockSuggestions = HomeSuggestionsModel(
        places: const [],
        recent: const [
          RecentSuggestionModel(
            id: 'rec_1',
            label: 'Diekal Coiffure',
            address: 'Liberté 6 Extension, Dakar',
            lat: 14.7123,
            lng: -17.4567,
          ),
          RecentSuggestionModel(
            id: 'rec_2',
            label: 'Sea Plaza',
            address: 'Corniche Ouest, Fann Résidence, Dakar',
            lat: 14.6934,
            lng: -17.4729,
          ),
          RecentSuggestionModel(
            id: 'rec_3',
            label: 'Aéroport Blaise Diagne',
            address: 'Diass, Thiès',
            lat: 14.6710,
            lng: -17.0733,
          ),
          RecentSuggestionModel(
            id: 'rec_4',
            label: 'Pharmacie Guigon',
            address: 'Avenue Pompidou, Dakar Plateau',
            lat: 14.6685,
            lng: -17.4338,
          ),
          RecentSuggestionModel(
            id: 'rec_5',
            label: '5ème destination (ne doit pas être affichée)',
            address: 'Adresse 5, Dakar',
            lat: 14.7000,
            lng: -17.4500,
          ),
        ],
      );

      final fakeRideService = FakeRideService(mockSuggestions: mockSuggestions);
      final dio = Dio()..httpClientAdapter = MockPlacesHttpClientAdapter();
      final mockPlacesService = PlacesService('mock_api_key', dio);

      await tester.pumpWidget(
        wrapWithTestLocalization(
          child: PlaceSearchPage(
            placesService: mockPlacesService,
            rideService: fakeRideService,
            currentUserLocation: const LatLng(14.7167, -17.4677),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Vérifier que getSuggestions a bien été appelé
      expect(fakeRideService.getSuggestionsCallCount, 1);

      // Vérifier la section des trajets récents
      expect(find.text('LIEUX RÉCENTS'), findsOneWidget);

      // Vérifier que les 4 premières destinations sont présentes avec leurs vrais noms et adresses
      expect(find.text('Diekal Coiffure'), findsOneWidget);
      expect(find.text('Liberté 6 Extension, Dakar'), findsOneWidget);

      expect(find.text('Sea Plaza'), findsOneWidget);
      expect(find.text('Corniche Ouest, Fann Résidence, Dakar'), findsOneWidget);

      expect(find.text('Aéroport Blaise Diagne'), findsOneWidget);
      expect(find.text('Diass, Thiès'), findsOneWidget);

      expect(find.text('Pharmacie Guigon'), findsOneWidget);
      expect(find.text('Avenue Pompidou, Dakar Plateau'), findsOneWidget);

      // Vérifier que la 5ème n'a pas été chargée (limite de 4)
      expect(find.text('5ème destination (ne doit pas être affichée)'), findsNothing);

      // Taper sur la destination récente "Diekal Coiffure"
      await tester.tap(find.text('Diekal Coiffure'));
      await tester.pumpAndSettle();

      // Vérifier que cela sélectionne directement la destination et ouvre la page de réservation
      expect(find.byType(RideBookingPage), findsOneWidget);
    });
  });
}
