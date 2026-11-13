import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';
import 'package:seddo/features/ride/data/services/ride_live_update_service_impl.dart';
import 'package:seddo/features/ride/domain/models/ride_live_update_data.dart';

/// Service gérant les notifications push distantes Firebase Cloud Messaging (FCM).
/// Permet la réception des notifications push en premier plan (foreground),
/// en arrière-plan (background) et lorsque l'application est fermée (killed).
class FcmService {
  static final FcmService _instance = FcmService._();
  factory FcmService() => _instance;
  FcmService._();

  bool _initialized = false;

  /// Initialise FCM, demande les autorisations utilisateur et configure l'affichage foreground iOS
  Future<void> init() async {
    if (_initialized) return;

    final bool isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest) {
      _initialized = true;
      return;
    }

    try {
      final fcm = FirebaseMessaging.instance;

      // 1. Demande de permission à l'utilisateur (iOS / Android 13+)
      final settings = await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('[FCM] Statut permission : ${settings.authorizationStatus}');

      // 2. Options d'affichage foreground spécifiques à iOS
      await fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Récupération du token FCM
      // ignore: deprecated_member_use
      final token = await fcm.getToken();
      debugPrint('[FCM] Token FCM de cet appareil : $token');
      if (token != null && token.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final accessToken = prefs.getString('auth_access_token');
        if (accessToken != null && accessToken.isNotEmpty) {
          await prefs.setString('fcm_device_token', token);
          await AuthRepository().registerCurrentDevicePushToken();
        }
      }

      // 4. Écoute du renouvellement de token
      // ignore: deprecated_member_use
      fcm.onTokenRefresh.listen((newToken) async {
        debugPrint('[FCM] Token FCM renouvelé : $newToken');
        final prefs = await SharedPreferences.getInstance();
        final accessToken = prefs.getString('auth_access_token');
        if (accessToken != null && accessToken.isNotEmpty) {
          await prefs.setString('fcm_device_token', newToken);
          await AuthRepository().registerCurrentDevicePushToken();
        }
      });

      // 5. Configuration des messages entrants en premier plan pour les Live Updates
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleIncomingLiveUpdate(message);
      });

      // 6. Gestionnaire de réveil en arrière-plan (app en pause ou tuée)
      FirebaseMessaging.onBackgroundMessage(fcmBackgroundLiveUpdateHandler);

      _initialized = true;
    } catch (e) {
      debugPrint('[FCM] Note : Firebase non initialisé ou fichier plist/json manquant ($e)');
    }
  }

  static Future<void> _handleIncomingLiveUpdate(RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('auth_access_token');
    if (accessToken == null || accessToken.isEmpty) {
      debugPrint('[FCM] Message entrant ignoré : utilisateur non connecté');
      return;
    }

    final data = message.data;
    if (data['type'] == 'ride_live_update') {
      final action = data['action']?.toString().toUpperCase() ?? 'UPDATE';
      final liveService = RideLiveUpdateServiceImpl();
      final rideId = data['rideId']?.toString() ?? '';
      if (action == 'END' || data['status'] == 'COMPLETED' || data['status'] == 'CANCELLED') {
        liveService.endLiveUpdate(rideId: rideId);
      } else {
        final updateData = RideLiveUpdateData.fromMap(data);
        liveService.updateLiveUpdate(updateData);
      }
    }
  }
}

/// Global top-level background handler waking the app when FCM sends a data message
@pragma('vm:entry-point')
Future<void> fcmBackgroundLiveUpdateHandler(RemoteMessage message) async {
  final prefs = await SharedPreferences.getInstance();
  final accessToken = prefs.getString('auth_access_token');
  if (accessToken == null || accessToken.isEmpty) {
    debugPrint('[FCM Background] Message d\'arrière-plan ignoré : utilisateur non connecté');
    return;
  }

  final data = message.data;
  if (data['type'] == 'ride_live_update') {
    final action = data['action']?.toString().toUpperCase() ?? 'UPDATE';
    final liveService = RideLiveUpdateServiceImpl();
    final rideId = data['rideId']?.toString() ?? '';
    if (action == 'END' || data['status'] == 'COMPLETED' || data['status'] == 'CANCELLED') {
      await liveService.endLiveUpdate(rideId: rideId);
    } else {
      final updateData = RideLiveUpdateData.fromMap(data);
      await liveService.updateLiveUpdate(updateData);
    }
  }
}
