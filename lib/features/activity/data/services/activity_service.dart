import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/network/api_client.dart';
import 'package:seddo/core/utils/api_endpoints.dart';
import 'package:seddo/core/utils/base_url.dart';
import 'package:seddo/features/activity/data/models/activity_item_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';

/// Data service providing activity history for rides and refunds.
/// Connects to:
/// - GET /v1/rides (RidesController_history)
/// - GET /v1/rides/{id} (RidesController_get)
class ActivityService {
  final String baseUrl;
  final Dio _dio;
  bool _usingRemoteData = false;
  bool get usingRemoteData => _usingRemoteData;

  /// Ne doit être activé QUE pour les tests automatisés de layout UI.
  /// Strictement false par défaut pour ne JAMAIS injecter de fausses courses dans l'application.
  static bool enableMockDataForTesting = false;

  ActivityService({
    String? baseUrl,
    Dio? dio,
  })  : baseUrl = baseUrl ?? BaseUrl.current,
        _dio = dio ?? ApiClient().dio;

  /// GET /v1/rides?limit=$limit
  /// Historique des courses de l'appelant (client : « Mes courses » ; chauffeur : courses réalisées).
  Future<List<ActivityRideItem>> getRidesHistory({int limit = 50}) async {
    try {
      final url = ApiEndpoints.ridesHistory(limit: limit);
      debugPrint('[ActivityService] 🚀 GET $url');
      final response = await _dio.get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final List list;
        if (response.data is String) {
          list = jsonDecode(response.data as String) as List;
        } else if (response.data is List) {
          list = response.data as List;
        } else {
          list = const [];
        }

        final items = list
            .map((item) => ActivityRideItem.fromBackendSummary(
                Map<String, dynamic>.from(item as Map)))
            .toList();

        debugPrint(
            '[ActivityService] ✅ ${items.length} courses récupérées depuis l\'API pour l\'utilisateur connecté');
        _usingRemoteData = true;
        return items;
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint(
            '[ActivityService] ⚠️ Erreur GET /v1/rides [${e.response?.statusCode}]: ${e.response?.data}');
      } else {
        debugPrint('[ActivityService] ⚠️ Erreur inattendue GET /v1/rides: $e');
      }
    }

    _usingRemoteData = false;
    if (enableMockDataForTesting) {
      return _allPastRides;
    }
    // En production réelle : ne pas afficher de fausses courses mockées hors-ligne
    return const <ActivityRideItem>[];
  }

  /// GET /v1/rides/{id}
  /// Détail d’une course : vue client (chauffeur, code de départ, paiement, remboursement) ou vue chauffeur (gain net).
  Future<ActivityRideItem?> getRideDetails(String id) async {
    try {
      final url = ApiEndpoints.rideDetails(id);
      debugPrint('[ActivityService] 🚀 GET $url');
      final response = await _dio.get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);

        final item = ActivityRideItem.fromBackendDetail(data);
        debugPrint(
            '[ActivityService] ✅ Détail course $id récupéré (points: ${item.polylinePoints.length}, traffic: ${item.trafficSegments.length})');
        return item;
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint(
            '[ActivityService] ⚠️ Erreur GET /v1/rides/$id [${e.response?.statusCode}]: ${e.response?.data}');
      } else {
        debugPrint('[ActivityService] ⚠️ Erreur inattendue GET /v1/rides/$id: $e');
      }
    }

    if (enableMockDataForTesting) {
      if (id == 'ride_recent') {
        return (await getRecentRide());
      }
      for (final r in _allPastRides) {
        if (r.id == id) return r;
      }
    }

    return null;
  }

  static DriverModel _createDriver({
    required String id,
    required String name,
    required double rating,
    required String carModel,
    required String licensePlate,
    required LatLng location,
    String carColor = 'Gris argent',
    String phone = '+221 77 123 45 67',
  }) {
    return DriverModel(
      id: id,
      name: name,
      phone: phone,
      rating: rating,
      totalRides: 1240,
      carModel: carModel,
      carColor: carColor,
      licensePlate: licensePlate,
      rideType: RideType.eco,
      currentLocation: location,
      etaMinutes: 3,
      distanceKm: 1.2,
    );
  }

  /// Summary metrics for the Activity page
  Future<ActivitySummary> getSummary({
    List<ActivityRideItem>? rides,
    List<ActivityRefundItem>? refunds,
  }) async {
    if (enableMockDataForTesting) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return const ActivitySummary(
        paidRidesCount: 3,
        totalSpentFormatted: '22 900 F',
        totalRefundedFormatted: '2 900 F',
        refundPaymentAccount: 'Orange Money 77 ••• 45 12',
      );
    }

    if (rides != null && rides.isNotEmpty) {
      final paidRides = rides
          .where((r) =>
              !r.isCancelled && (r.status == 'Payée' || r.status == 'Terminée'))
          .toList();
      final paidCount =
          paidRides.isNotEmpty ? paidRides.length : rides.where((r) => !r.isCancelled).length;
      final totalSpent = paidRides.fold<int>(0, (acc, r) => acc + r.price);

      int totalRefunded = 0;
      if (refunds != null && refunds.isNotEmpty) {
        totalRefunded = refunds
            .where((ref) => !ref.isPending && ref.status != 'Échouée')
            .fold<int>(0, (acc, ref) => acc + (ref.amount ?? 0));
      } else {
        totalRefunded = rides
            .where((r) => r.isRefunded)
            .fold<int>(0, (acc, r) => acc + r.price);
      }

      return ActivitySummary(
        paidRidesCount: paidCount,
        totalSpentFormatted: ActivityRideItem.formatPrice(totalSpent),
        totalRefundedFormatted: ActivityRideItem.formatPrice(totalRefunded),
        refundPaymentAccount: '',
      );
    }

    return const ActivitySummary(
      paidRidesCount: 0,
      totalSpentFormatted: '0 F',
      totalRefundedFormatted: '0 F',
      refundPaymentAccount: '',
    );
  }

  /// The most recent ride (featured with map trajectory preview)
  Future<ActivityRideItem?> getRecentRide({List<ActivityRideItem>? rides}) async {
    if (enableMockDataForTesting) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return ActivityRideItem(
        id: 'ride_recent',
      title: 'ALMADIES',
      subtitle: 'Moussa · 7,8 km',
      price: 3500,
      priceText: '3 500 F',
      status: 'Payée',
      dateTag: 'Aujourd\'hui · 18:19',
      dateText: 'Jeudi 15 avril',
      departureTime: '18:19',
      arrivalTime: '18:41',
      durationText: '22 min',
      distanceText: '7,8 km',
      departure: const PlaceSearchResult(
        id: 'sacre_coeur_3',
        mainText: 'Sacré-Cœur 3',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Sacré-Cœur 3, Dakar',
        latitude: 14.7167,
        longitude: -17.4677,
      ),
      destination: const PlaceSearchResult(
        id: 'almadies',
        mainText: 'Almadies',
        secondaryText: 'Ngor-Almadies, Dakar',
        fullAddress: 'Almadies, Dakar',
        latitude: 14.7431,
        longitude: -17.5186,
      ),
      driver: _createDriver(
        id: 'driver_moussa',
        name: 'Moussa Diop',
        rating: 4.9,
        carModel: 'Toyota Corolla',
        licensePlate: 'DK 4521 AB',
        location: const LatLng(14.7200, -17.4700),
      ),
      driverInitials: 'MS',
      orangeRef: 'CI270415.1819.A3F2',
      isRecentWithMap: true,
      iconType: ActivityRideIconType.car,
      polylinePoints: const [
        LatLng(14.7167, -17.4677),
        LatLng(14.7220, -17.4780),
        LatLng(14.7290, -17.4890),
        LatLng(14.7360, -17.5020),
        LatLng(14.7431, -17.5186),
      ],
    );
  }

  if (rides != null && rides.isNotEmpty) {
    final first = rides.first;
    final detailed = await getRideDetails(first.id);
    if (detailed != null && detailed.polylinePoints.isNotEmpty) {
      return detailed;
    }
    return first;
  }

  return null;
}

  /// Master list of past rides (earlier than the most recent)
  static final List<ActivityRideItem> _allPastRides = [
    ActivityRideItem(
      id: 'ride_carnot_1',
      title: 'Plateau, rue Carnot',
      subtitle: 'Aujourd\'hui · 08:02 · Annulée',
      price: 2900,
      priceText: '2 900 F',
      status: 'Annulée',
      dateTag: 'Aujourd\'hui · 08:02',
      dateText: 'Aujourd\'hui',
      departureTime: '08:02',
      arrivalTime: '08:17',
      durationText: '15 min',
      distanceText: '5,2 km',
      departure: const PlaceSearchResult(
        id: 'point_e',
        mainText: 'Point E',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Point E, Dakar',
        latitude: 14.6937,
        longitude: -17.4647,
      ),
      destination: const PlaceSearchResult(
        id: 'plateau_carnot',
        mainText: 'Plateau, rue Carnot',
        secondaryText: 'Dakar-Plateau, Sénégal',
        fullAddress: 'Rue Carnot, Dakar-Plateau',
        latitude: 14.6720,
        longitude: -17.4360,
      ),
      driver: _createDriver(
        id: 'driver_ibrahima',
        name: 'Ibrahima Sow',
        rating: 4.8,
        carModel: 'Peugeot 301',
        licensePlate: 'DK 8823 BC',
        location: const LatLng(14.6800, -17.4500),
      ),
      driverInitials: 'IS',
      orangeRef: 'CI270415.0802.R991',
      isCancelled: true,
      isRefunded: true,
      iconType: ActivityRideIconType.car,
      polylinePoints: const [
        LatLng(14.6937, -17.4647),
        LatLng(14.6850, -17.4520),
        LatLng(14.6780, -17.4430),
        LatLng(14.6720, -17.4360),
      ],
    ),
    ActivityRideItem(
      id: 'ride_aibd',
      title: 'Aéroport AIBD',
      subtitle: 'Mar. 13 avr. · 05:40 · Fatou',
      price: 16500,
      priceText: '16 500 F',
      status: 'Payée',
      dateTag: 'Mar. 13 avr. · 05:40',
      dateText: 'Mar. 13 avr.',
      departureTime: '05:40',
      arrivalTime: '06:25',
      durationText: '45 min',
      distanceText: '52 km',
      departure: const PlaceSearchResult(
        id: 'mermoz',
        mainText: 'Mermoz',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Mermoz, Dakar',
        latitude: 14.7060,
        longitude: -17.4720,
      ),
      destination: const PlaceSearchResult(
        id: 'aibd_airport',
        mainText: 'Aéroport AIBD',
        secondaryText: 'Diass, Région de Thiès',
        fullAddress: 'Aéroport International Blaise Diagne (AIBD)',
        latitude: 14.6710,
        longitude: -17.0733,
      ),
      driver: _createDriver(
        id: 'driver_fatou',
        name: 'Fatou Ndiaye',
        rating: 5.0,
        carModel: 'Hyundai Accent',
        licensePlate: 'DK 1290 DD',
        location: const LatLng(14.7000, -17.4600),
      ),
      driverInitials: 'FN',
      orangeRef: 'CI270413.0540.A102',
      iconType: ActivityRideIconType.airport,
      polylinePoints: const [
        LatLng(14.7060, -17.4720),
        LatLng(14.7300, -17.3800),
        LatLng(14.7400, -17.2500),
        LatLng(14.6710, -17.0733),
      ],
    ),
    ActivityRideItem(
      id: 'ride_carnot_2',
      title: 'Plateau, rue Carnot',
      subtitle: 'Lun. 12 avr. · 20:10 · Abdoulaye',
      price: 2900,
      priceText: '2 900 F',
      status: 'Payée',
      dateTag: 'Lun. 12 avr. · 20:10',
      dateText: 'Lun. 12 avr.',
      departureTime: '20:10',
      arrivalTime: '20:38',
      durationText: '28 min',
      distanceText: '14 km',
      departure: const PlaceSearchResult(
        id: 'almadies_dep',
        mainText: 'Almadies',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Almadies, Dakar',
        latitude: 14.7431,
        longitude: -17.5186,
      ),
      destination: const PlaceSearchResult(
        id: 'plateau_carnot_2',
        mainText: 'Plateau, rue Carnot',
        secondaryText: 'Dakar-Plateau, Sénégal',
        fullAddress: 'Rue Carnot, Dakar-Plateau',
        latitude: 14.6720,
        longitude: -17.4360,
      ),
      driver: _createDriver(
        id: 'driver_abdoulaye',
        name: 'Abdoulaye Ba',
        rating: 4.7,
        carModel: 'Citroën C-Elysée',
        licensePlate: 'DK 7734 XY',
        location: const LatLng(14.7100, -17.4500),
      ),
      driverInitials: 'AB',
      orangeRef: 'CI270412.2010.B442',
      iconType: ActivityRideIconType.briefcase,
      polylinePoints: const [
        LatLng(14.7431, -17.5186),
        LatLng(14.7200, -17.4800),
        LatLng(14.6900, -17.4500),
        LatLng(14.6720, -17.4360),
      ],
    ),
    ActivityRideItem(
      id: 'ride_ouakam',
      title: 'Ouakam, Monument Renaissance',
      subtitle: 'Sam. 10 avr. · 16:30 · Modou',
      price: 2200,
      priceText: '2 200 F',
      status: 'Payée',
      dateTag: 'Sam. 10 avr. · 16:30',
      dateText: 'Sam. 10 avr.',
      departureTime: '16:30',
      arrivalTime: '16:48',
      durationText: '18 min',
      distanceText: '6,5 km',
      departure: const PlaceSearchResult(
        id: 'sacre_coeur_ouakam',
        mainText: 'Sacré-Cœur 3',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Sacré-Cœur 3, Dakar',
        latitude: 14.7167,
        longitude: -17.4677,
      ),
      destination: const PlaceSearchResult(
        id: 'monument_renaissance',
        mainText: 'Monument Renaissance',
        secondaryText: 'Ouakam, Dakar',
        fullAddress: 'Monument de la Renaissance Africaine, Ouakam',
        latitude: 14.7224,
        longitude: -17.4952,
      ),
      driver: _createDriver(
        id: 'driver_modou',
        name: 'Modou Fall',
        rating: 4.9,
        carModel: 'Toyota Yaris',
        licensePlate: 'DK 3120 EF',
        location: const LatLng(14.7180, -17.4800),
      ),
      driverInitials: 'MF',
      orangeRef: 'CI270410.1630.C881',
      iconType: ActivityRideIconType.car,
      polylinePoints: const [
        LatLng(14.7167, -17.4677),
        LatLng(14.7200, -17.4800),
        LatLng(14.7224, -17.4952),
      ],
    ),
    ActivityRideItem(
      id: 'ride_yoff',
      title: 'Yoff, Plage BCEAO',
      subtitle: 'Jeu. 8 avr. · 12:15 · Ousmane',
      price: 3000,
      priceText: '3 000 F',
      status: 'Payée',
      dateTag: 'Jeu. 8 avr. · 12:15',
      dateText: 'Jeu. 8 avr.',
      departureTime: '12:15',
      arrivalTime: '12:39',
      durationText: '24 min',
      distanceText: '9,1 km',
      departure: const PlaceSearchResult(
        id: 'point_e_yoff',
        mainText: 'Point E',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Point E, Dakar',
        latitude: 14.6937,
        longitude: -17.4647,
      ),
      destination: const PlaceSearchResult(
        id: 'yoff_plage',
        mainText: 'Yoff, Plage BCEAO',
        secondaryText: 'Yoff, Dakar',
        fullAddress: 'Plage BCEAO, Yoff',
        latitude: 14.7610,
        longitude: -17.4720,
      ),
      driver: _createDriver(
        id: 'driver_ousmane',
        name: 'Ousmane Sene',
        rating: 4.8,
        carModel: 'Kia Rio',
        licensePlate: 'DK 5421 GH',
        location: const LatLng(14.7300, -17.4700),
      ),
      driverInitials: 'OS',
      orangeRef: 'CI270408.1215.D722',
      iconType: ActivityRideIconType.car,
      polylinePoints: const [
        LatLng(14.6937, -17.4647),
        LatLng(14.7300, -17.4700),
        LatLng(14.7610, -17.4720),
      ],
    ),
    ActivityRideItem(
      id: 'ride_fann',
      title: 'Fann Résidence',
      subtitle: 'Lun. 5 avr. · 09:00 · Cheikh',
      price: 2500,
      priceText: '2 500 F',
      status: 'Payée',
      dateTag: 'Lun. 5 avr. · 09:00',
      dateText: 'Lun. 5 avr.',
      departureTime: '09:00',
      arrivalTime: '09:20',
      durationText: '20 min',
      distanceText: '5,8 km',
      departure: const PlaceSearchResult(
        id: 'mermoz_fann',
        mainText: 'Mermoz',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Mermoz, Dakar',
        latitude: 14.7060,
        longitude: -17.4720,
      ),
      destination: const PlaceSearchResult(
        id: 'fann_residence',
        mainText: 'Fann Résidence',
        secondaryText: 'Fann, Dakar',
        fullAddress: 'Ambassade, Fann Résidence',
        latitude: 14.6880,
        longitude: -17.4680,
      ),
      driver: _createDriver(
        id: 'driver_cheikh',
        name: 'Cheikh Diallo',
        rating: 4.9,
        carModel: 'Renault Logan',
        licensePlate: 'DK 6731 JK',
        location: const LatLng(14.6950, -17.4700),
      ),
      driverInitials: 'CD',
      orangeRef: 'CI270405.0900.E190',
      iconType: ActivityRideIconType.briefcase,
      polylinePoints: const [
        LatLng(14.7060, -17.4720),
        LatLng(14.6950, -17.4700),
        LatLng(14.6880, -17.4680),
      ],
    ),
    ActivityRideItem(
      id: 'ride_ngor',
      title: 'Ngor, Embarcadère Île',
      subtitle: 'Ven. 2 avr. · 15:00 · Alioune',
      price: 3800,
      priceText: '3 800 F',
      status: 'Payée',
      dateTag: 'Ven. 2 avr. · 15:00',
      dateText: 'Ven. 2 avr.',
      departureTime: '15:00',
      arrivalTime: '15:28',
      durationText: '28 min',
      distanceText: '11,4 km',
      departure: const PlaceSearchResult(
        id: 'sacre_coeur_ngor',
        mainText: 'Sacré-Cœur 3',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Sacré-Cœur 3, Dakar',
        latitude: 14.7167,
        longitude: -17.4677,
      ),
      destination: const PlaceSearchResult(
        id: 'ngor_embarcadere',
        mainText: 'Ngor, Embarcadère',
        secondaryText: 'Ngor, Dakar',
        fullAddress: 'Embarcadère Île de Ngor',
        latitude: 14.7550,
        longitude: -17.5170,
      ),
      driver: _createDriver(
        id: 'driver_alioune',
        name: 'Alioune Gueye',
        rating: 4.8,
        carModel: 'Hyundai Elantra',
        licensePlate: 'DK 9912 LM',
        location: const LatLng(14.7350, -17.4900),
      ),
      driverInitials: 'AG',
      orangeRef: 'CI270402.1500.F554',
      iconType: ActivityRideIconType.car,
      polylinePoints: const [
        LatLng(14.7167, -17.4677),
        LatLng(14.7350, -17.4900),
        LatLng(14.7550, -17.5170),
      ],
    ),
  ];

  /// Get paginated earlier rides
  Future<List<ActivityRideItem>> getPastRides({
    List<ActivityRideItem>? allRides,
    int page = 1,
    int pageSize = 3,
  }) async {
    final list = allRides ??
        (enableMockDataForTesting ? _allPastRides : const <ActivityRideItem>[]);
    if (page < 1) page = 1;
    final startIndex = (page - 1) * pageSize;
    if (startIndex >= list.length) {
      return [];
    }
    final endIndex = (startIndex + pageSize).clamp(0, list.length);
    return list.sublist(startIndex, endIndex);
  }

  /// Total count of earlier past rides
  Future<int> getTotalPastRidesCount({List<ActivityRideItem>? allRides}) async {
    return (allRides ??
            (enableMockDataForTesting ? _allPastRides : const <ActivityRideItem>[]))
        .length;
  }

  /// GET /v1/users/me/refunds (UsersController_refunds)
  /// Remboursements reçus, avec la référence Orange.
  Future<List<ActivityRefundItem>> getRefunds({List<ActivityRideItem>? rides}) async {
    try {
      final url = ApiEndpoints.userRefunds;
      debugPrint('[ActivityService] 🚀 GET $url');
      final response = await _dio.get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final List list;
        if (response.data is String) {
          list = jsonDecode(response.data as String) as List;
        } else if (response.data is List) {
          list = response.data as List;
        } else {
          list = const [];
        }

        if (list.isNotEmpty) {
          final items = list.map((item) {
            final json = Map<String, dynamic>.from(item as Map);
            final rideId = json['rideId']?.toString();
            ActivityRideItem? associated;
            if (rides != null && rideId != null) {
              try {
                associated = rides.firstWhere((r) => r.id == rideId);
              } catch (_) {
                associated = null;
              }
            }
            return ActivityRefundItem.fromBackend(json, associatedRide: associated);
          }).toList();

          debugPrint('[ActivityService] ✅ ${items.length} remboursements reçus avec référence Orange');
          return items;
        }
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint(
            '[ActivityService] ⚠️ Erreur GET /v1/users/me/refunds [${e.response?.statusCode}]: ${e.response?.data}');
      } else {
        debugPrint('[ActivityService] ⚠️ Erreur inattendue GET /v1/users/me/refunds: $e');
      }
    }

    if (!enableMockDataForTesting) {
      return const <ActivityRefundItem>[];
    }

    // Fallback en environnement de test
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return [
      ActivityRefundItem(
        id: 'refund_carnot',
        title: 'Plateau, rue Carnot',
        subtitle: 'Course annulée · Aujourd\'hui · 08:02',
        amountText: '+2 900 F',
        status: 'Remboursée',
        isPending: false,
        associatedRide: _allPastRides.first,
      ),
      const ActivityRefundItem(
        id: 'refund_pending_mermoz',
        title: 'Mermoz, Pyrotechnie',
        subtitle: 'Course annulée · Hier · 19:45',
        amountText: '+4 200 F',
        status: 'En cours',
        isPending: true,
      ),
    ];
  }
}
