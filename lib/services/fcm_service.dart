import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';

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
        await prefs.setString('fcm_device_token', token);
        await AuthRepository().registerCurrentDevicePushToken();
      }

      // 4. Écoute du renouvellement de token
      // ignore: deprecated_member_use
      fcm.onTokenRefresh.listen((newToken) async {
        debugPrint('[FCM] Token FCM renouvelé : $newToken');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_device_token', newToken);
        await AuthRepository().registerCurrentDevicePushToken();
      });

      _initialized = true;
    } catch (e) {
      debugPrint('[FCM] Note : Firebase non initialisé ou fichier plist/json manquant ($e)');
    }
  }
}
