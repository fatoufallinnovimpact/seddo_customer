import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/activity_item_model.dart';
import 'package:seddo/features/home/domain/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/domain/models/ride_option_model.dart';

/// Data service providing activity history for rides and refunds.
/// Designed for easy swap with real remote backend API endpoints later.
abstract class ActivityDataService {
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
  static ActivitySummary getSummary() {
    return const ActivitySummary(
      paidRidesCount: 3,
      totalSpentFormatted: '22 900 F',
      totalRefundedFormatted: '2 900 F',
      refundPaymentAccount: 'Orange Money 77 ••• 45 12',
    );
  }

  /// The most recent ride (featured with map trajectory preview)
  static ActivityRideItem getRecentRide() {
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
      departure: PlaceSearchResult(
        id: 'sacre_coeur_3',
        mainText: 'Sacré-Cœur 3',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Sacré-Cœur 3, Dakar',
        latitude: 14.7167,
        longitude: -17.4677,
      ),
      destination: PlaceSearchResult(
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

  /// Master list of past rides (earlier than the most recent)
  static final List<ActivityRideItem> _allPastRides = [
    ActivityRideItem(
      id: 'ride_carnot_1',
      title: 'Plateau, rue Carnot',
      subtitle: 'Aujourd\'hui · 08:02 · Annulée',
      price: 2900,
      priceText: '2 900 F',
      status: 'Remboursée',
      dateTag: 'Aujourd\'hui · 08:02',
      dateText: 'Aujourd\'hui',
      departureTime: '08:02',
      arrivalTime: '08:17',
      durationText: '15 min',
      distanceText: '5,2 km',
      departure: PlaceSearchResult(
        id: 'point_e',
        mainText: 'Point E',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Point E, Dakar',
        latitude: 14.6937,
        longitude: -17.4647,
      ),
      destination: PlaceSearchResult(
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
      departure: PlaceSearchResult(
        id: 'mermoz',
        mainText: 'Mermoz',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Mermoz, Dakar',
        latitude: 14.7060,
        longitude: -17.4720,
      ),
      destination: PlaceSearchResult(
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
      departure: PlaceSearchResult(
        id: 'almadies_dep',
        mainText: 'Almadies',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Almadies, Dakar',
        latitude: 14.7431,
        longitude: -17.5186,
      ),
      destination: PlaceSearchResult(
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
      departure: PlaceSearchResult(
        id: 'sacre_coeur_ouakam',
        mainText: 'Sacré-Cœur 3',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Sacré-Cœur 3, Dakar',
        latitude: 14.7167,
        longitude: -17.4677,
      ),
      destination: PlaceSearchResult(
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
      departure: PlaceSearchResult(
        id: 'point_e_yoff',
        mainText: 'Point E',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Point E, Dakar',
        latitude: 14.6937,
        longitude: -17.4647,
      ),
      destination: PlaceSearchResult(
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
      departure: PlaceSearchResult(
        id: 'mermoz_fann',
        mainText: 'Mermoz',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Mermoz, Dakar',
        latitude: 14.7060,
        longitude: -17.4720,
      ),
      destination: PlaceSearchResult(
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
      departure: PlaceSearchResult(
        id: 'sacre_coeur_ngor',
        mainText: 'Sacré-Cœur 3',
        secondaryText: 'Dakar, Sénégal',
        fullAddress: 'Sacré-Cœur 3, Dakar',
        latitude: 14.7167,
        longitude: -17.4677,
      ),
      destination: PlaceSearchResult(
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
  static List<ActivityRideItem> getPastRides({
    int page = 1,
    int pageSize = 3,
  }) {
    if (page < 1) page = 1;
    final startIndex = (page - 1) * pageSize;
    if (startIndex >= _allPastRides.length) {
      return [];
    }
    final endIndex = (startIndex + pageSize).clamp(0, _allPastRides.length);
    return _allPastRides.sublist(startIndex, endIndex);
  }

  /// Total count of earlier past rides
  static int getTotalPastRidesCount() {
    return _allPastRides.length;
  }

  /// Total number of pages for pagination
  static int getTotalPages({int pageSize = 3}) {
    if (_allPastRides.isEmpty) return 1;
    return (_allPastRides.length / pageSize).ceil();
  }

  /// Refunds list matching Screenshot 2
  static List<ActivityRefundItem> getRefunds() {
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
