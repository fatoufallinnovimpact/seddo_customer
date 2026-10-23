import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/base_url.dart';
import 'package:seddo/features/tcu/data/models/tcu_route_model.dart';

/// Data service providing public transport (TCU) routes and stops for Dakar.
/// Designed for easy integration with future real backend API (REST / GTFS-RT).
class PublicTransportService {
  final String baseUrl;

  const PublicTransportService({
    String? baseUrl,
  }) : baseUrl = baseUrl ?? BaseUrl.current;

  /// Retrieve available TCU options matching the current origin, destination and filter
  Future<List<TcuRouteOption>> getRouteOptions({
    String origin = 'Fann Hock',
    String destination = 'Liberté 6',
    TcuTransportType filter = TcuTransportType.all,
  }) async {
    // Simulated network latency for realistic UX / ready for HTTP API call
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final allOptions = _buildOptionsForRoute(origin, destination);

    if (filter == TcuTransportType.all) {
      return allOptions;
    }

    return allOptions.where((opt) => opt.type == filter).toList();
  }

  /// Dynamically build options tailored to origin and destination
  static List<TcuRouteOption> _buildOptionsForRoute(
    String origin,
    String destination,
  ) {
    final cleanOrigin = origin.trim();
    final cleanDest = destination.trim();

    // Default reference dataset when matching standard initial values
    if ((cleanOrigin.isEmpty || cleanOrigin.toLowerCase().contains('fann')) &&
        (cleanDest.isEmpty || cleanDest.toLowerCase().contains('libert'))) {
      return _buildDefaultOptions();
    }

    final isPlateau = cleanOrigin.toLowerCase().contains('plateau') ||
        cleanDest.toLowerCase().contains('plateau');
    final isAlmadies = cleanOrigin.toLowerCase().contains('almadies') ||
        cleanDest.toLowerCase().contains('almadies');
    final isOuakam = cleanOrigin.toLowerCase().contains('ouakam') ||
        cleanDest.toLowerCase().contains('ouakam');

    final dddStopName = isPlateau
        ? 'Plateau, Place Kermel'
        : (isAlmadies
            ? 'Almadies, Route de Ngor'
            : (isOuakam
                ? 'Ouakam, Cité Comico'
                : 'Arrêt $cleanOrigin, Axe Principal'));

    final aftuStopName = isPlateau
        ? 'Avenue Lamine Guèye, Dakar-Plateau'
        : (isAlmadies
            ? 'Rond-point Almadies, en face Pharmacie'
            : 'Arrêt AFTU $cleanOrigin');

    return [
      // 1. Dakar Dem Dikk
      TcuRouteOption(
        id: 'tcu_ddd_${cleanOrigin.hashCode}',
        type: TcuTransportType.ddd,
        lineCode: isPlateau ? 'DDD 1' : 'DDD 10',
        linePrefix: 'Ligne de bus :',
        estimatedDurationMinutes: isAlmadies ? 28 : 22,
        estimatedDurationText: isAlmadies ? '28 min' : '22 min',
        departureStop: TcuStop(
          id: 'stop_ddd_dynamic',
          name: dddStopName,
          subtitle: 'Station Dem Dikk',
          walkingDistanceMeters: 310,
          walkingDurationMinutes: 4,
          nextArrivalMinutes: 4,
          latitude: 14.6950,
          longitude: -17.4600,
        ),
        arrivalStop: TcuStop(
          id: 'stop_ddd_dest',
          name: 'Terminus $cleanDest',
          subtitle: 'Dakar',
          walkingDistanceMeters: 190,
          walkingDurationMinutes: 2,
          nextArrivalMinutes: 25,
          latitude: 14.7200,
          longitude: -17.4700,
        ),
        stopsCount: 6,
        stopsList: [
          dddStopName,
          'Place de la Nation',
          'Rond-point Jet d\'Eau',
          'Castors',
          'Sacré-Cœur',
          'Terminus $cleanDest',
        ],
        imagePath: 'assets/images/tcu/ddd_bus.png',
        userOriginCoordinates: const LatLng(14.6930, -17.4620),
        walkingPathToStop: const [
          LatLng(14.6930, -17.4620),
          LatLng(14.6940, -17.4610),
          LatLng(14.6950, -17.4600),
        ],
      ),

      // 2. Sunu BRT
      TcuRouteOption(
        id: 'tcu_brt_${cleanOrigin.hashCode}',
        type: TcuTransportType.brt,
        lineCode: 'B1',
        linePrefix: 'Ligne de bus :',
        estimatedDurationMinutes: 14,
        estimatedDurationText: '14 min',
        departureStop: TcuStop(
          id: 'stop_brt_dynamic',
          name: 'Station Voie Réservée BRT',
          subtitle: 'Axe Voie Rapide',
          walkingDistanceMeters: 280,
          walkingDurationMinutes: 3,
          nextArrivalMinutes: 2,
          latitude: 14.7085,
          longitude: -17.4580,
        ),
        arrivalStop: TcuStop(
          id: 'stop_brt_dest',
          name: 'Station $cleanDest',
          subtitle: 'Terminus BRT',
          walkingDistanceMeters: 120,
          walkingDurationMinutes: 2,
          nextArrivalMinutes: 18,
          latitude: 14.7350,
          longitude: -17.4450,
        ),
        stopsCount: 5,
        stopsList: [
          'Station $cleanOrigin',
          'Station Grand Médine',
          'Station Échangeur Hann',
          'Station Patte d\'Oie',
          'Station $cleanDest',
        ],
        imagePath: 'assets/images/tcu/brt_bus.png',
        userOriginCoordinates: const LatLng(14.7065, -17.4595),
        walkingPathToStop: const [
          LatLng(14.7065, -17.4595),
          LatLng(14.7075, -17.4588),
          LatLng(14.7085, -17.4580),
        ],
      ),

      // 3. AFTU
      TcuRouteOption(
        id: 'tcu_aftu_${cleanOrigin.hashCode}',
        type: TcuTransportType.aftu,
        lineCode: isOuakam ? 'AFTU 44' : 'AFTU 24',
        linePrefix: 'Ligne de bus :',
        estimatedDurationMinutes: 18,
        estimatedDurationText: '18 min',
        departureStop: TcuStop(
          id: 'stop_aftu_dynamic',
          name: aftuStopName,
          subtitle: 'Ligne directe Tata',
          walkingDistanceMeters: 240,
          walkingDurationMinutes: 3,
          nextArrivalMinutes: 5,
          latitude: 14.7015,
          longitude: -17.4655,
        ),
        arrivalStop: TcuStop(
          id: 'stop_aftu_dest',
          name: 'Arrêt $cleanDest',
          subtitle: 'Dakar',
          walkingDistanceMeters: 160,
          walkingDurationMinutes: 2,
          nextArrivalMinutes: 21,
          latitude: 14.7150,
          longitude: -17.4550,
        ),
        stopsCount: 7,
        stopsList: [
          aftuStopName,
          'Boulevard du Centenaire',
          'Marché HLM',
          'Allées Seydou Nourou Tall',
          'Rond-point Liberté 5',
          'Arrêt $cleanDest',
        ],
        imagePath: 'assets/images/tcu/aftu_bus.png',
        userOriginCoordinates: const LatLng(14.7000, -17.4668),
        walkingPathToStop: const [
          LatLng(14.7000, -17.4668),
          LatLng(14.7008, -17.4660),
          LatLng(14.7015, -17.4655),
        ],
      ),

      // 4. TER
      TcuRouteOption(
        id: 'tcu_ter_${cleanOrigin.hashCode}',
        type: TcuTransportType.ter,
        lineCode: 'TER',
        linePrefix: 'Ligne :',
        estimatedDurationMinutes: 16,
        estimatedDurationText: '16 min',
        departureStop: const TcuStop(
          id: 'stop_ter_dynamic',
          name: 'Gare TER Colobane',
          subtitle: 'Passerelle Colobane',
          walkingDistanceMeters: 450,
          walkingDurationMinutes: 6,
          nextArrivalMinutes: 5,
          latitude: 14.6950,
          longitude: -17.4420,
        ),
        arrivalStop: TcuStop(
          id: 'stop_ter_dest',
          name: 'Gare TER $cleanDest',
          subtitle: 'Ligne Express',
          walkingDistanceMeters: 200,
          walkingDurationMinutes: 3,
          nextArrivalMinutes: 22,
          latitude: 14.7300,
          longitude: -17.1800,
        ),
        stopsCount: 4,
        stopsList: const [
          'Gare de Dakar (Plateau)',
          'Gare TER Colobane',
          'Gare TER Hann',
          'Gare TER Dalifort',
        ],
        imagePath: 'assets/images/tcu/ter_train.png',
        userOriginCoordinates: const LatLng(14.6920, -17.4450),
        walkingPathToStop: const [
          LatLng(14.6920, -17.4450),
          LatLng(14.6935, -17.4435),
          LatLng(14.6950, -17.4420),
        ],
      ),
    ];
  }

  /// Master list of Dakar TCU propositions matching reference designs
  static List<TcuRouteOption> _buildDefaultOptions() {
    return const [
      // 1. Dakar Dem Dikk - DDD 10
      TcuRouteOption(
        id: 'tcu_ddd_10',
        type: TcuTransportType.ddd,
        lineCode: 'DDD 10',
        linePrefix: 'Ligne de bus :',
        estimatedDurationMinutes: 19,
        estimatedDurationText: '19 min',
        departureStop: TcuStop(
          id: 'stop_claudel',
          name: 'Claudel Corniche, face Hôtel Terrou Bi',
          subtitle: 'Corniche Ouest, Fann',
          walkingDistanceMeters: 376,
          walkingDurationMinutes: 5,
          nextArrivalMinutes: 3,
          latitude: 14.6930,
          longitude: -17.4725,
        ),
        arrivalStop: TcuStop(
          id: 'stop_liberte_6',
          name: 'Terminus Liberté 6',
          subtitle: 'Rond-point Liberté 6',
          walkingDistanceMeters: 180,
          walkingDurationMinutes: 2,
          nextArrivalMinutes: 22,
          latitude: 14.7180,
          longitude: -17.4620,
        ),
        stopsCount: 5,
        stopsList: [
          'Claudel Corniche (Hôtel Terrou Bi)',
          'Fann Résidence',
          'Université Cheikh Anta Diop (UCAD)',
          'Point E - Boulevard du Sud',
          'Stade Marius Ndiaye',
        ],
        imagePath: 'assets/images/tcu/ddd_bus.png',
        userOriginCoordinates: LatLng(14.6890, -17.4710),
        walkingPathToStop: [
          LatLng(14.6890, -17.4710),
          LatLng(14.6905, -17.4715),
          LatLng(14.6918, -17.4720),
          LatLng(14.6930, -17.4725),
        ],
      ),

      // 2. Sunu BRT - Ligne B1
      TcuRouteOption(
        id: 'tcu_brt_b1',
        type: TcuTransportType.brt,
        lineCode: 'B1',
        linePrefix: 'Ligne de bus :',
        estimatedDurationMinutes: 4,
        estimatedDurationText: '4 min',
        departureStop: TcuStop(
          id: 'stop_brt_liberte_1',
          name: 'LIBERTE 1',
          subtitle: 'Station Voie Réservée BRT',
          walkingDistanceMeters: 326,
          walkingDurationMinutes: 4,
          nextArrivalMinutes: 2,
          latitude: 14.7085,
          longitude: -17.4580,
        ),
        arrivalStop: TcuStop(
          id: 'stop_brt_guediawaye',
          name: 'Station Préfecture Guédiawaye',
          subtitle: 'Terminus BRT',
          walkingDistanceMeters: 120,
          walkingDurationMinutes: 2,
          nextArrivalMinutes: 26,
          latitude: 14.7780,
          longitude: -17.3950,
        ),
        stopsCount: 4,
        stopsList: [
          'Station Stade Marius Ndiaye',
          'Station LIBERTE 1',
          'Station Rond-point Jet d\'Eau',
          'Station Grand Yoff',
        ],
        imagePath: 'assets/images/tcu/brt_bus.png',
        userOriginCoordinates: LatLng(14.7060, -17.4560),
        walkingPathToStop: [
          LatLng(14.7060, -17.4560),
          LatLng(14.7072, -17.4570),
          LatLng(14.7085, -17.4580),
        ],
      ),

      // 3. AFTU - Ligne 24
      TcuRouteOption(
        id: 'tcu_aftu_24',
        type: TcuTransportType.aftu,
        lineCode: 'AFTU 24',
        linePrefix: 'Ligne de bus :',
        estimatedDurationMinutes: 7,
        estimatedDurationText: '7 min',
        departureStop: TcuStop(
          id: 'stop_casino_free',
          name: 'Casino, à côté de l\'agence Free',
          subtitle: 'Avenue Cheikh Anta Diop',
          walkingDistanceMeters: 277,
          walkingDurationMinutes: 3,
          nextArrivalMinutes: 6,
          latitude: 14.7015,
          longitude: -17.4655,
        ),
        arrivalStop: TcuStop(
          id: 'stop_aftu_marche',
          name: 'Marché Castors',
          subtitle: 'Castors, Dakar',
          walkingDistanceMeters: 210,
          walkingDurationMinutes: 3,
          nextArrivalMinutes: 14,
          latitude: 14.7120,
          longitude: -17.4510,
        ),
        stopsCount: 6,
        stopsList: [
          'Stade Marius Ndiaye',
          'Marché Castors',
          'Boulevard Dial Diop',
          'Casino, à côté de l\'agence Free',
          'Sacré-Cœur 3 Pyrotechnie',
          'Liberté 6 Terminus',
        ],
        imagePath: 'assets/images/tcu/aftu_bus.png',
        userOriginCoordinates: LatLng(14.6995, -17.4670),
        walkingPathToStop: [
          LatLng(14.6995, -17.4670),
          LatLng(14.7002, -17.4665),
          LatLng(14.7008, -17.4660),
          LatLng(14.7015, -17.4655),
        ],
      ),

      // 4. TER Dakar - Diamniadio
      TcuRouteOption(
        id: 'tcu_ter_express',
        type: TcuTransportType.ter,
        lineCode: 'TER',
        linePrefix: 'Ligne :',
        estimatedDurationMinutes: 15,
        estimatedDurationText: '15 min',
        departureStop: TcuStop(
          id: 'stop_gare_colobane',
          name: 'Gare TER Colobane',
          subtitle: 'Passerelle Colobane',
          walkingDistanceMeters: 450,
          walkingDurationMinutes: 6,
          nextArrivalMinutes: 5,
          latitude: 14.6950,
          longitude: -17.4420,
        ),
        arrivalStop: TcuStop(
          id: 'stop_gare_diamniadio',
          name: 'Gare TER Diamniadio',
          subtitle: 'Pôle Urbain Diamniadio',
          walkingDistanceMeters: 150,
          walkingDurationMinutes: 2,
          nextArrivalMinutes: 35,
          latitude: 14.7300,
          longitude: -17.1800,
        ),
        stopsCount: 3,
        stopsList: [
          'Gare de Dakar (Plateau)',
          'Gare TER Colobane',
          'Gare TER Hann',
          'Gare TER Dalifort',
          'Gare TER Diamniadio',
        ],
        imagePath: 'assets/images/tcu/ter_train.png',
        userOriginCoordinates: LatLng(14.6920, -17.4450),
        walkingPathToStop: [
          LatLng(14.6920, -17.4450),
          LatLng(14.6935, -17.4435),
          LatLng(14.6950, -17.4420),
        ],
      ),
    ];
  }
}
