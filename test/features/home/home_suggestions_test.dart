import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/features/home/data/models/home_suggestions_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';

void main() {
  group('HomeSuggestionsModel tests', () {
    test('Parses empty suggestions response correctly', () {
      final json = {
        'places': [],
        'recent': [],
      };

      final model = HomeSuggestionsModel.fromJson(json);
      expect(model.places, isEmpty);
      expect(model.recent, isEmpty);
      expect(model.isEmpty, isTrue);
      expect(model.isNotEmpty, isFalse);
    });

    test('Parses suggestions with saved place and recent destination', () {
      final json = {
        'places': [
          {
            'id': 'place_123',
            'kind': 'HOME',
            'label': 'Maison',
            'address': 'Sacré-Cœur 3, villa 12',
            'lat': 14.7167,
            'lng': -17.4677,
          }
        ],
        'recent': [
          {
            'id': 'recent_456',
            'label': 'Almadies',
            'address': 'Route des Almadies, Dakar',
            'lat': 14.7432,
            'lng': -17.5147,
          }
        ],
      };

      final model = HomeSuggestionsModel.fromJson(json);
      expect(model.isEmpty, isFalse);
      expect(model.places.length, 1);
      expect(model.recent.length, 1);

      // Verify place
      final place = model.places.first;
      expect(place.id, 'place_123');
      expect(place.kind, 'HOME');
      expect(place.name, 'Maison');
      expect(place.address, 'Sacré-Cœur 3, villa 12');
      expect(place.latitude, 14.7167);
      expect(place.longitude, -17.4677);

      final placeSearchResult = place.toPlaceSearchResult();
      expect(placeSearchResult.mainText, 'Maison');
      expect(placeSearchResult.fullAddress, 'Sacré-Cœur 3, villa 12');

      // Verify recent
      final recent = model.recent.first;
      expect(recent.id, 'recent_456');
      expect(recent.label, 'Almadies');
      expect(recent.address, 'Route des Almadies, Dakar');
      expect(recent.lat, 14.7432);
      expect(recent.lng, -17.5147);

      final recentSearchResult = recent.toPlaceSearchResult();
      expect(recentSearchResult.mainText, 'Almadies');
      expect(recentSearchResult.fullAddress, 'Route des Almadies, Dakar');
      expect(recentSearchResult.category, 'recent');
    });

    test('Serializes to JSON correctly', () {
      const model = HomeSuggestionsModel(
        places: [],
        recent: [
          RecentSuggestionModel(
            id: '1',
            label: 'Plateau',
            address: 'Dakar Plateau',
            lat: 14.67,
            lng: -17.43,
          ),
        ],
      );

      final json = model.toJson();
      expect(json['places'], isEmpty);
      expect(json['recent'], hasLength(1));
      expect(json['recent'][0]['label'], 'Plateau');
    });

    test('RecentTripStorage saves, retrieves, and clears only the last recent trip', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});

      // Initially null
      final initial = await RecentTripStorage.getLastRecentTrip();
      expect(initial, isNull);

      // Save a trip
      final trip1 = PlaceSearchResult(
        id: 'place_mermoz',
        mainText: 'Mermoz',
        secondaryText: 'Dakar',
        fullAddress: 'Mermoz Pyrotechnie, Dakar',
        latitude: 14.71,
        longitude: -17.47,
      );
      await RecentTripStorage.saveLastRecentTrip(trip1);

      final retrieved1 = await RecentTripStorage.getLastRecentTrip();
      expect(retrieved1, isNotNull);
      expect(retrieved1!.label, 'Mermoz');
      expect(retrieved1.address, 'Mermoz Pyrotechnie, Dakar');

      // Save a second trip (overwrites with latest recent trip)
      final trip2 = PlaceSearchResult(
        id: 'place_fann',
        mainText: 'Fann Résidence',
        secondaryText: 'Dakar',
        fullAddress: 'Fann Résidence, Rue Aimé Césaire',
        latitude: 14.69,
        longitude: -17.48,
      );
      await RecentTripStorage.saveLastRecentTrip(trip2);

      final retrieved2 = await RecentTripStorage.getLastRecentTrip();
      expect(retrieved2, isNotNull);
      expect(retrieved2!.label, 'Fann Résidence');
      expect(retrieved2.address, 'Fann Résidence, Rue Aimé Césaire');

      // Clear
      await RecentTripStorage.clearLastRecentTrip();
      final afterClear = await RecentTripStorage.getLastRecentTrip();
      expect(afterClear, isNull);
    });

    test('RecentTripStorage purges legacy mock records (e.g. recent_1)', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({
        'seddo_last_recent_trip': '{"id":"recent_1","label":"Ngor","address":"Almadies, Ngor","lat":14.7,"lng":-17.5}',
      });

      final item = await RecentTripStorage.getLastRecentTrip();
      expect(item, isNull);
    });

    test('RecentTripStorage stores multiple recent trips in history', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});

      final trip1 = PlaceSearchResult(
        id: 'place_sea_plaza',
        mainText: 'Sea Plaza',
        secondaryText: 'Dakar',
        fullAddress: 'Sea Plaza, Corniche Ouest',
        latitude: 14.693,
        longitude: -17.472,
      );
      final trip2 = PlaceSearchResult(
        id: 'place_plateau',
        mainText: "Place de l'Indépendance",
        secondaryText: 'Dakar',
        fullAddress: "Place de l'Indépendance, Dakar",
        latitude: 14.671,
        longitude: -17.432,
      );

      await RecentTripStorage.saveLastRecentTrip(trip1);
      await RecentTripStorage.saveLastRecentTrip(trip2);

      final recents = await RecentTripStorage.getRecentTrips();
      expect(recents.length, 2);
      expect(recents[0].label, "Place de l'Indépendance");
      expect(recents[1].label, 'Sea Plaza');
    });
  });
}

