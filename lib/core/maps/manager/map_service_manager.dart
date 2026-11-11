import 'dart:async';
import 'package:flutter/material.dart';
import 'package:seddo/core/maps/models/app_params.dart';
import 'package:seddo/core/maps/models/map_models.dart';
import 'package:seddo/core/maps/models/map_provider.dart';
import 'package:seddo/core/maps/repositories/app_params_repository.dart';
import 'package:seddo/core/maps/services/google_map_service.dart';
import 'package:seddo/core/maps/services/map_service.dart';
import 'package:seddo/core/maps/services/osm_map_service.dart';
import 'package:seddo/core/utils/map_config.dart';

/// Gestionnaire central de la cartographie (Singleton & ChangeNotifier).
/// Gère :
/// 1. La sélection dynamique du fournisseur (Google vs OSM).
/// 2. Le rafraîchissement périodique (toutes les 5 minutes) et au premier plan.
/// 3. Le Circuit Breaker : bascule instantanée sur OSM en cas d'erreur de clé/quota.
class MapServiceManager extends ChangeNotifier with WidgetsBindingObserver {
  static final MapServiceManager _instance = MapServiceManager._internal();
  static MapServiceManager get instance => _instance;

  final IAppParamsRepository _repository;

  AppParams _currentParams = const AppParams();
  MapProvider _activeProvider = MapProvider.osm;
  bool _isCircuitBreakerTripped = false;

  Timer? _refreshTimer;
  bool _isInitialized = false;

  late GoogleMapService _googleService;
  final OsmMapService _osmService = OsmMapService();

  MapServiceManager._internal({IAppParamsRepository? repository})
      : _repository = repository ?? AppParamsRepository() {
    _googleService = GoogleMapService(apiKey: '');
  }

  /// Fournisseur actuellement actif
  MapProvider get activeProvider => _activeProvider;

  /// Indique si l'app tourne actuellement en mode secours (OSM)
  bool get isFallbackMode => _activeProvider == MapProvider.osm;

  /// Indique si le circuit breaker a disjoncté suite à une erreur de clé/quota Google
  bool get isCircuitBreakerTripped => _isCircuitBreakerTripped;

  /// Paramètres distants courants
  AppParams get currentParams => _currentParams;

  /// Service de cartographie actif (Google ou OSM)
  MapService get activeService {
    if (_activeProvider == MapProvider.google && !_isCircuitBreakerTripped) {
      return _googleService;
    }
    return _osmService;
  }

  /// Initialisation au démarrage de l'application
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    WidgetsBinding.instance.addObserver(this);

    // 1. Charger immédiatement le cache local
    final cached = await _repository.getCachedParams();
    _applyParams(cached);

    // 2. Interroger le backend
    await refreshConfig();

    // 3. Programmer un rafraîchissement automatique toutes les 5 minutes (aligné sur max-age=300)
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      refreshConfig();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-vérifier la configuration dès le retour au premier plan
      refreshConfig();
    }
  }

  /// Rafraîchit les paramètres depuis l'endpoint distant
  Future<void> refreshConfig() async {
    try {
      final fresh = await _repository.getParams();
      _applyParams(fresh);
    } catch (_) {}
  }

  /// Applique les nouveaux paramètres et réévalue le fournisseur actif
  void _applyParams(AppParams params) {
    _currentParams = params;

    final key = params.activeApiKey;
    if (key != null && key.isNotEmpty) {
      _googleService = GoogleMapService(apiKey: key);
      MapConfig.updateKeys(
        android: params.maps.android,
        ios: params.maps.ios,
        web: params.maps.web,
      );
    }

    // Réinitialiser le disjoncteur lors d'un rafraîchissement officiel de configuration
    _isCircuitBreakerTripped = false;

    final newProvider = params.isGoogleUsable ? MapProvider.google : MapProvider.osm;

    if (_activeProvider != newProvider) {
      _activeProvider = newProvider;
      notifyListeners();
    }
  }

  /// Méthode visible pour les tests unitaires afin de tester les bascules d'états
  @visibleForTesting
  void applyParamsForTesting(AppParams params) => _applyParams(params);

  /// Mécanisme de Circuit Breaker :
  /// Exécute l'appel Google via [googleCall]. Si une erreur de clé ou de quota survient :
  /// 1. Bascule immédiatement sur OSM.
  /// 2. Exécute et retourne le résultat de [osmFallback].
  /// 3. Bloque Google jusqu'au prochain rafraîchissement de config.
  Future<T> safeCall<T>({
    required Future<T> Function(GoogleMapService google) googleCall,
    required Future<T> Function(OsmMapService osm) osmFallback,
  }) async {
    if (_activeProvider == MapProvider.google && !_isCircuitBreakerTripped) {
      try {
        return await googleCall(_googleService);
      } on GoogleMapApiKeyException catch (keyErr) {
        debugPrint('[CircuitBreaker] ⚠️ Défaillance clé/quota Google ($keyErr) -> Bascule immédiate sur OSM');
        _tripCircuitBreaker();
        return await osmFallback(_osmService);
      } catch (generalErr) {
        // Les erreurs réseau classiques (ex: timeout, coupure de connexion) ne disjonctent pas le breaker
        rethrow;
      }
    }

    return await osmFallback(_osmService);
  }

  /// Enclenche le disjoncteur et bascule sur OSM sans redémarrer l'application
  void _tripCircuitBreaker() {
    if (!_isCircuitBreakerTripped || _activeProvider != MapProvider.osm) {
      _isCircuitBreakerTripped = true;
      _activeProvider = MapProvider.osm;
      notifyListeners();
    }
  }

  /// Méthodes directes facilitatrices (passant par le Circuit Breaker)

  Future<List<MapPlaceSuggestion>> autocomplete(
    String query, {
    MapLatLng? location,
    String? sessionToken,
  }) {
    return safeCall<List<MapPlaceSuggestion>>(
      googleCall: (google) => google.autocomplete(
        query,
        location: location,
        sessionToken: sessionToken,
      ),
      osmFallback: (osm) => osm.autocomplete(
        query,
        location: location,
        sessionToken: sessionToken,
      ),
    );
  }

  Future<MapPlaceDetails?> geocode(String address) {
    return safeCall<MapPlaceDetails?>(
      googleCall: (google) => google.geocode(address),
      osmFallback: (osm) => osm.geocode(address),
    );
  }

  Future<MapPlaceDetails?> reverseGeocode(double lat, double lng) {
    return safeCall<MapPlaceDetails?>(
      googleCall: (google) => google.reverseGeocode(lat, lng),
      osmFallback: (osm) => osm.reverseGeocode(lat, lng),
    );
  }

  Future<MapRouteResult> getRoute(MapLatLng origin, MapLatLng destination) {
    return safeCall<MapRouteResult>(
      googleCall: (google) => google.getRoute(origin, destination),
      osmFallback: (osm) => osm.getRoute(origin, destination),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }
}
