import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/base_url.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';
import 'package:seddo/features/ride/data/models/chat_message_model.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/nearby_drivers_response_model.dart';
import 'package:seddo/features/ride/data/models/ride_quote_model.dart';
import 'package:seddo/services/route_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// État de connexion du WebSocket temps réel
enum RealtimeConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Événement temps réel de statut de course (ride.status)
class RealtimeRideStatusEvent {
  final String rideId;
  final String status;
  final String? departureCode;
  final DriverModel? driver;
  final int version;
  final DateTime timestamp;
  final Map<String, dynamic> raw;

  const RealtimeRideStatusEvent({
    required this.rideId,
    required this.status,
    this.departureCode,
    this.driver,
    this.version = 0,
    required this.timestamp,
    this.raw = const {},
  });

  factory RealtimeRideStatusEvent.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return RealtimeRideStatusEvent(
        rideId: '',
        status: '',
        timestamp: DateTime.now(),
      );
    }

    final rideObj = json['ride'] is Map<String, dynamic>
        ? json['ride'] as Map<String, dynamic>
        : json;

    final rideId = (rideObj['rideId'] ??
            rideObj['id'] ??
            json['rideId'] ??
            json['id'] ??
            '')
        .toString();

    final status = (rideObj['status'] ??
            json['status'] ??
            rideObj['rideStatus'] ??
            '')
        .toString()
        .toUpperCase();

    final version = (json['version'] ?? rideObj['version'] as num?)?.toInt() ?? 0;

    final departureCode = DriverModel.extractDepartureCode(json);

    DriverModel? driver;
    if (json['driver'] != null || rideObj['driver'] != null || json['carModel'] != null) {
      try {
        driver = DriverModel.fromRideJson(json);
      } catch (e) {
        debugPrint('[RealtimeService] Note parsing driver: $e');
      }
    }

    DateTime time;
    try {
      final rawTime = json['timestamp'] ?? json['updatedAt'] ?? json['time'];
      if (rawTime is String) {
        time = DateTime.tryParse(rawTime) ?? DateTime.now();
      } else if (rawTime is int) {
        time = DateTime.fromMillisecondsSinceEpoch(rawTime);
      } else {
        time = DateTime.now();
      }
    } catch (_) {
      time = DateTime.now();
    }

    return RealtimeRideStatusEvent(
      rideId: rideId,
      status: status,
      departureCode: departureCode,
      driver: driver,
      version: version,
      timestamp: time,
      raw: json,
    );
  }
}

/// Événement temps réel de position GPS du chauffeur (driver.location)
class RealtimeDriverLocationEvent {
  final String? rideId;
  final String? driverId;
  final LatLng location;
  final double heading;
  final double? speed;
  final double? accuracy;
  final DateTime? timestamp;
  final int version;
  final Map<String, dynamic> raw;

  const RealtimeDriverLocationEvent({
    this.rideId,
    this.driverId,
    required this.location,
    this.heading = 0.0,
    this.speed,
    this.accuracy,
    this.timestamp,
    this.version = 0,
    this.raw = const {},
  });

  factory RealtimeDriverLocationEvent.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const RealtimeDriverLocationEvent(
        location: LatLng(0, 0),
      );
    }

    final posObj = json['position'] is Map<String, dynamic>
        ? json['position'] as Map<String, dynamic>
        : (json['location'] is Map<String, dynamic>
            ? json['location'] as Map<String, dynamic>
            : json);

    final lat = (posObj['lat'] ?? posObj['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (posObj['lng'] ?? posObj['longitude'] as num?)?.toDouble() ?? 0.0;
    final heading = (posObj['heading'] ??
            posObj['bearing'] ??
            posObj['direction'] ??
            json['heading'] ??
            0.0 as num)
        .toDouble();
    final speed = (posObj['speed'] ?? json['speed'] as num?)?.toDouble();
    final accuracy = (posObj['accuracy'] ?? json['accuracy'] as num?)?.toDouble();

    final rideId = (json['rideId'] ?? posObj['rideId'])?.toString();
    final driverId = (json['driverId'] ?? posObj['driverId'])?.toString();
    final version = (json['version'] ?? posObj['version'] as num?)?.toInt() ?? 0;

    DateTime? time;
    final rawTime = posObj['timestamp'] ?? json['timestamp'] ?? json['time'];
    if (rawTime is String) {
      time = DateTime.tryParse(rawTime);
    } else if (rawTime is int) {
      time = DateTime.fromMillisecondsSinceEpoch(rawTime);
    }

    return RealtimeDriverLocationEvent(
      rideId: rideId,
      driverId: driverId,
      location: LatLng(lat, lng),
      heading: heading,
      speed: speed,
      accuracy: accuracy,
      timestamp: time,
      version: version,
      raw: json,
    );
  }
}

/// Événement temps réel d'estimation du temps d'arrivée (ride.eta)
class RealtimeRideEtaEvent {
  final String? rideId;
  final int durationSeconds;
  final int etaMinutes;
  final int? distanceMeters;
  final int version;
  final Map<String, dynamic> raw;

  const RealtimeRideEtaEvent({
    this.rideId,
    required this.durationSeconds,
    required this.etaMinutes,
    this.distanceMeters,
    this.version = 0,
    this.raw = const {},
  });

  factory RealtimeRideEtaEvent.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const RealtimeRideEtaEvent(
        durationSeconds: 0,
        etaMinutes: 0,
      );
    }

    final durS = (json['durationS'] ??
            json['duration'] ??
            json['durationSeconds'] ??
            (json['etaMinutes'] != null ? (json['etaMinutes'] as num).toInt() * 60 : 0)
                as num?)
        ?.toInt() ??
        0;

    final distM = (json['distanceM'] ?? json['distanceMeters'] as num?)?.toInt();
    final etaM = durS > 0 ? (durS / 60.0).ceil() : ((json['etaMinutes'] as num?)?.toInt() ?? 0);
    final rideId = json['rideId']?.toString();
    final version = (json['version'] as num?)?.toInt() ?? 0;

    return RealtimeRideEtaEvent(
      rideId: rideId,
      durationSeconds: durS,
      etaMinutes: etaM,
      distanceMeters: distM,
      version: version,
      raw: json,
    );
  }
}

/// Événement temps réel d'itinéraire mis à jour (ride.route.updated)
class RealtimeRideRouteEvent {
  final String? rideId;
  final String polyline;
  final List<LatLng> points;
  final List<TrafficSegmentModel> traffic;
  final int? durationSeconds;
  final int? distanceMeters;
  final int version;
  final Map<String, dynamic> raw;

  const RealtimeRideRouteEvent({
    this.rideId,
    required this.polyline,
    required this.points,
    this.traffic = const [],
    this.durationSeconds,
    this.distanceMeters,
    this.version = 0,
    this.raw = const {},
  });

  factory RealtimeRideRouteEvent.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const RealtimeRideRouteEvent(
        polyline: '',
        points: [],
      );
    }

    final routeObj = json['route'] is Map<String, dynamic>
        ? json['route'] as Map<String, dynamic>
        : json;

    final poly = (routeObj['polyline'] ?? json['polyline'] ?? '').toString();
    List<LatLng> pts = [];
    if (poly.isNotEmpty) {
      try {
        pts = RouteService.decodePolyline(poly);
      } catch (_) {}
    }

    List<TrafficSegmentModel> traffic = [];
    final rawTraffic = (routeObj['traffic'] ?? json['traffic']) as List<dynamic>?;
    if (rawTraffic != null) {
      traffic = rawTraffic
          .whereType<Map<String, dynamic>>()
          .map((t) => TrafficSegmentModel.fromJson(t))
          .toList();
    }

    final durS = (routeObj['durationS'] ?? json['durationS'] as num?)?.toInt();
    final distM = (routeObj['distanceM'] ?? json['distanceM'] as num?)?.toInt();
    final rideId = (json['rideId'] ?? routeObj['rideId'])?.toString();
    final version = (json['version'] ?? routeObj['version'] as num?)?.toInt() ?? 0;

    return RealtimeRideRouteEvent(
      rideId: rideId,
      polyline: poly,
      points: pts,
      traffic: traffic,
      durationSeconds: durS,
      distanceMeters: distM,
      version: version,
      raw: json,
    );
  }
}

/// Événement temps réel de statut de paiement (payment.status)
class RealtimePaymentStatusEvent {
  final String? rideId;
  final String status;
  final num? amount;
  final String? paymentMethod;
  final int version;
  final Map<String, dynamic> raw;

  const RealtimePaymentStatusEvent({
    this.rideId,
    required this.status,
    this.amount,
    this.paymentMethod,
    this.version = 0,
    this.raw = const {},
  });

  factory RealtimePaymentStatusEvent.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const RealtimePaymentStatusEvent(status: '');
    }

    final rideId = json['rideId']?.toString();
    final status = (json['status'] ?? json['paymentStatus'] ?? '').toString();
    final amount = (json['amount'] as num?);
    final method = (json['paymentMethod'] ?? json['method'])?.toString();
    final version = (json['version'] as num?)?.toInt() ?? 0;

    return RealtimePaymentStatusEvent(
      rideId: rideId,
      status: status,
      amount: amount,
      paymentMethod: method,
      version: version,
      raw: json,
    );
  }
}

/// Service centralisé de gestion de la connexion temps réel Socket.IO Seddo.
/// Respecte scrupuleusement la spécification Seddo :
/// - Path : '/v1/realtime'
/// - Auth : { token: accessToken }
/// - Transports : ['websocket']
/// - Événements :
///   * ride.status
///   * driver.location
///   * ride.eta
///   * ride.route.updated
///   * payment.status
///   * nearby.drivers
///   * ride.message / chat.message
/// - Une seule connexion partagée dans toute l'application.
/// - Reconnexion exponentielle automatique & resynchronisation REST.
class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  io.Socket? _socket;
  RealtimeConnectionStatus _connectionStatus = RealtimeConnectionStatus.disconnected;
  String? _currentActiveRideId;

  // Filtres d'intégrité (PDF pages 3-4-5) :
  // - Ignorer événement si version antérieure
  // - Ignorer position si précision > 50 m
  // - Ignorer position si plus ancienne que la dernière reçue
  final Map<String, int> _lastKnownVersions = {};
  final Map<String, DateTime> _lastLocationTimestamps = {};

  // Broadcast stream controllers
  final _statusController = StreamController<RealtimeConnectionStatus>.broadcast();
  final _rideStatusController = StreamController<RealtimeRideStatusEvent>.broadcast();
  final _driverLocationController = StreamController<RealtimeDriverLocationEvent>.broadcast();
  final _rideEtaController = StreamController<RealtimeRideEtaEvent>.broadcast();
  final _rideRouteController = StreamController<RealtimeRideRouteEvent>.broadcast();
  final _paymentStatusController = StreamController<RealtimePaymentStatusEvent>.broadcast();
  final _nearbyDriversController = StreamController<List<NearbyCarModel>>.broadcast();
  final _chatMessageController = StreamController<ChatMessageModel>.broadcast();
  final _reconnectController = StreamController<void>.broadcast();

  // Getters des Streams
  Stream<RealtimeConnectionStatus> get statusStream => _statusController.stream;
  Stream<RealtimeRideStatusEvent> get rideStatusStream => _rideStatusController.stream;
  Stream<RealtimeDriverLocationEvent> get driverLocationStream => _driverLocationController.stream;
  Stream<RealtimeRideEtaEvent> get rideEtaStream => _rideEtaController.stream;
  Stream<RealtimeRideRouteEvent> get rideRouteStream => _rideRouteController.stream;
  Stream<RealtimePaymentStatusEvent> get paymentStatusStream => _paymentStatusController.stream;
  Stream<List<NearbyCarModel>> get nearbyDriversStream => _nearbyDriversController.stream;
  Stream<ChatMessageModel> get chatMessageStream => _chatMessageController.stream;
  Stream<void> get onReconnect => _reconnectController.stream;

  RealtimeConnectionStatus get connectionStatus => _connectionStatus;
  bool get isConnected => _connectionStatus == RealtimeConnectionStatus.connected;
  bool get isConnecting =>
      _connectionStatus == RealtimeConnectionStatus.connecting ||
      _connectionStatus == RealtimeConnectionStatus.reconnecting;

  /// Établit la connexion WebSocket unique avec le serveur Seddo.
  /// Récupère automatiquement le jeton d'authentification [auth_access_token].
  Future<void> connect({
    String? customToken,
    String? customUrl,
  }) async {
    final bool isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest && customUrl == null) {
      _setConnectionStatus(RealtimeConnectionStatus.connected);
      return;
    }

    final token = customToken ?? await AuthRepository().getAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint('[RealtimeService] ⚠️ Aucun token disponible pour connecter le WebSocket');
      _setConnectionStatus(RealtimeConnectionStatus.disconnected);
      return;
    }

    final baseUrl = customUrl ?? BaseUrl.current;
    _setConnectionStatus(RealtimeConnectionStatus.connecting);

    debugPrint('[RealtimeService] 🔌 Connexion Socket.IO à $baseUrl (path: /v1/realtime)');

    try {
      _socket?.dispose();

      // Configuration Socket.IO conforme aux spécifications Seddo
      _socket = io.io(
        baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setPath('/v1/realtime')
            .setAuth({'token': token})
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(999999)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .build(),
      );

      _setupListeners();
      _socket?.connect();
    } catch (e) {
      debugPrint('[RealtimeService] ⚠️ Erreur lors de l\'initialisation Socket.IO: $e');
      _setConnectionStatus(RealtimeConnectionStatus.error);
    }
  }

  /// Déconnecte le WebSocket et réinitialise les états internes
  void disconnect() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
    } catch (_) {}
    _setConnectionStatus(RealtimeConnectionStatus.disconnected);
  }

  /// Rejoint le canal d'une course spécifique (ride:{id})
  void joinRide(String rideId) {
    if (rideId.isEmpty) return;
    _currentActiveRideId = rideId;
    if (_socket != null && _socket!.connected) {
      debugPrint('[RealtimeService] 🚪 Rejoindre canal ride:$rideId');
      _socket?.emit('join_ride', {'rideId': rideId});
      _socket?.emit('join', 'ride:$rideId');
    }
  }

  /// Quitte le canal d'une course spécifique (ride:{id})
  void leaveRide(String rideId) {
    if (rideId.isEmpty) return;
    if (_currentActiveRideId == rideId) {
      _currentActiveRideId = null;
    }
    if (_socket != null && _socket!.connected) {
      debugPrint('[RealtimeService] 🚪 Quitter canal ride:$rideId');
      _socket?.emit('leave_ride', {'rideId': rideId});
      _socket?.emit('leave', 'ride:$rideId');
    }
  }

  /// Configuration des écouteurs Socket.IO
  void _setupListeners() {
    final s = _socket;
    if (s == null) return;

    // Statuts de connexion
    s.onConnect((_) {
      debugPrint('[RealtimeService] ✅ Connecté au WebSocket Seddo');
      _setConnectionStatus(RealtimeConnectionStatus.connected);

      // Re-rejoindre la course en cours si nécessaire
      if (_currentActiveRideId != null && _currentActiveRideId!.isNotEmpty) {
        joinRide(_currentActiveRideId!);
      }
    });

    s.onDisconnect((_) {
      debugPrint('[RealtimeService] 🔌 Déconnecté du WebSocket Seddo');
      _setConnectionStatus(RealtimeConnectionStatus.disconnected);
    });

    s.onConnectError((err) {
      debugPrint('[RealtimeService] ⚠️ Erreur connexion WebSocket: $err');
      _setConnectionStatus(RealtimeConnectionStatus.error);
    });

    s.onReconnect((_) {
      debugPrint('[RealtimeService] 🔄 Reconnexion au WebSocket réussie');
      _setConnectionStatus(RealtimeConnectionStatus.connected);

      if (_currentActiveRideId != null && _currentActiveRideId!.isNotEmpty) {
        joinRide(_currentActiveRideId!);
      }
      // Notifie les pages de resynchroniser l'état par REST
      _reconnectController.add(null);
    });

    s.onReconnectAttempt((_) {
      _setConnectionStatus(RealtimeConnectionStatus.reconnecting);
    });

    // 1. Statut de la course (ride.status / ride:status)
    s.on('ride.status', (data) => _handleRideStatus(data));
    s.on('ride:status', (data) => _handleRideStatus(data));

    // 2. Position en direct du chauffeur (driver.location / driver:location)
    s.on('driver.location', (data) => _handleDriverLocation(data));
    s.on('driver:location', (data) => _handleDriverLocation(data));

    // 3. Temps d'arrivée estimé (ride.eta / ride:eta)
    s.on('ride.eta', (data) => _handleRideEta(data));
    s.on('ride:eta', (data) => _handleRideEta(data));

    // 4. Nouvel itinéraire avec le trafic (ride.route.updated / ride:route:updated)
    s.on('ride.route.updated', (data) => _handleRideRoute(data));
    s.on('ride:route:updated', (data) => _handleRideRoute(data));

    // 5. Paiement (payment.status / payment:status)
    s.on('payment.status', (data) => _handlePaymentStatus(data));
    s.on('payment:status', (data) => _handlePaymentStatus(data));

    // 6. Chauffeurs proches sur l'accueil (nearby.drivers / nearby:drivers)
    s.on('nearby.drivers', (data) => _handleNearbyDrivers(data));
    s.on('nearby:drivers', (data) => _handleNearbyDrivers(data));

    // 7. Messages de chat (ride.message / chat.message / chat:message)
    s.on('ride.message', (data) => _handleChatMessage(data));
    s.on('chat.message', (data) => _handleChatMessage(data));
    s.on('chat:message', (data) => _handleChatMessage(data));
  }

  void _handleRideStatus(dynamic data) {
    try {
      final event = RealtimeRideStatusEvent.fromJson(data);
      if (event.rideId.isNotEmpty && event.version > 0) {
        final last = _lastKnownVersions[event.rideId] ?? 0;
        if (event.version < last) {
          debugPrint('[RealtimeService] Ignoré ride.status périmé (v${event.version} < v$last)');
          return;
        }
        _lastKnownVersions[event.rideId] = event.version;
      }
      debugPrint('[RealtimeService] 📥 Reçu ride.status: ${event.status} pour course ${event.rideId}');
      _rideStatusController.add(event);
    } catch (e) {
      debugPrint('[RealtimeService] ⚠️ Erreur parsing ride.status: $e');
    }
  }

  void _handleDriverLocation(dynamic data) {
    try {
      final event = RealtimeDriverLocationEvent.fromJson(data);

      // Filtre 1 : Précision GPS minimale 50m (PDF page 3 & 5)
      if (event.accuracy != null && event.accuracy! > 50.0) {
        debugPrint('[RealtimeService] Ignoré driver.location imprécis (${event.accuracy}m > 50m)');
        return;
      }

      // Filtre 2 : Horodatage plus récent (PDF page 4 & 5)
      final trackKey = event.rideId ?? event.driverId ?? 'current';
      if (event.timestamp != null) {
        final lastTime = _lastLocationTimestamps[trackKey];
        if (lastTime != null && event.timestamp!.isBefore(lastTime)) {
          debugPrint('[RealtimeService] Ignoré driver.location plus ancien que le dernier reçu');
          return;
        }
        _lastLocationTimestamps[trackKey] = event.timestamp!;
      }

      // Filtre 3 : Versionning
      if (event.version > 0 && event.rideId != null) {
        final lastV = _lastKnownVersions[event.rideId!] ?? 0;
        if (event.version < lastV) {
          return;
        }
        _lastKnownVersions[event.rideId!] = event.version;
      }

      _driverLocationController.add(event);
    } catch (e) {
      debugPrint('[RealtimeService] ⚠️ Erreur parsing driver.location: $e');
    }
  }

  void _handleRideEta(dynamic data) {
    try {
      final event = RealtimeRideEtaEvent.fromJson(data);
      if (event.rideId != null && event.version > 0) {
        final last = _lastKnownVersions[event.rideId!] ?? 0;
        if (event.version < last) return;
        _lastKnownVersions[event.rideId!] = event.version;
      }
      _rideEtaController.add(event);
    } catch (e) {
      debugPrint('[RealtimeService] ⚠️ Erreur parsing ride.eta: $e');
    }
  }

  void _handleRideRoute(dynamic data) {
    try {
      final event = RealtimeRideRouteEvent.fromJson(data);
      if (event.rideId != null && event.version > 0) {
        final last = _lastKnownVersions[event.rideId!] ?? 0;
        if (event.version < last) return;
        _lastKnownVersions[event.rideId!] = event.version;
      }
      _rideRouteController.add(event);
    } catch (e) {
      debugPrint('[RealtimeService] ⚠️ Erreur parsing ride.route.updated: $e');
    }
  }

  void _handlePaymentStatus(dynamic data) {
    try {
      final event = RealtimePaymentStatusEvent.fromJson(data);
      _paymentStatusController.add(event);
    } catch (e) {
      debugPrint('[RealtimeService] ⚠️ Erreur parsing payment.status: $e');
    }
  }

  void _handleNearbyDrivers(dynamic data) {
    try {
      final List<NearbyCarModel> cars = [];
      if (data is List) {
        for (final item in data) {
          cars.add(NearbyCarModel.fromJson(item));
        }
      } else if (data is Map<String, dynamic>) {
        if (data['cars'] is List) {
          for (final item in data['cars'] as List) {
            cars.add(NearbyCarModel.fromJson(item));
          }
        } else if (data['categories'] is List) {
          final res = NearbyDriversResponseModel.fromJson(data);
          cars.addAll(res.allCars);
        }
      }
      if (cars.isNotEmpty) {
        _nearbyDriversController.add(cars);
      }
    } catch (e) {
      debugPrint('[RealtimeService] ⚠️ Erreur parsing nearby.drivers: $e');
    }
  }

  void _handleChatMessage(dynamic data) {
    try {
      if (data is Map<String, dynamic>) {
        final msg = ChatMessageModel.fromJson(data);
        _chatMessageController.add(msg);
      }
    } catch (e) {
      debugPrint('[RealtimeService] ⚠️ Erreur parsing chat message: $e');
    }
  }

  void _setConnectionStatus(RealtimeConnectionStatus status) {
    _connectionStatus = status;
    _statusController.add(status);
  }

  // --- Méthodes de test et simulation ---

  @visibleForTesting
  void emitMockEvent(String eventName, dynamic data) {
    switch (eventName) {
      case 'ride.status':
      case 'ride:status':
        _handleRideStatus(data);
        break;
      case 'driver.location':
      case 'driver:location':
        _handleDriverLocation(data);
        break;
      case 'ride.eta':
      case 'ride:eta':
        _handleRideEta(data);
        break;
      case 'ride.route.updated':
      case 'ride:route:updated':
        _handleRideRoute(data);
        break;
      case 'payment.status':
      case 'payment:status':
        _handlePaymentStatus(data);
        break;
      case 'nearby.drivers':
      case 'nearby:drivers':
        _handleNearbyDrivers(data);
        break;
      case 'ride.message':
      case 'chat.message':
      case 'chat:message':
        _handleChatMessage(data);
        break;
    }
  }

  @visibleForTesting
  void setMockStatus(RealtimeConnectionStatus status) {
    _setConnectionStatus(status);
  }

  @visibleForTesting
  void resetForTesting() {
    _lastKnownVersions.clear();
    _lastLocationTimestamps.clear();
    _currentActiveRideId = null;
    _setConnectionStatus(RealtimeConnectionStatus.disconnected);
  }
}
