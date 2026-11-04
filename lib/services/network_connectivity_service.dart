import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';

/// Service centralisé de vérification de connectivité réseau.
/// Fonctionne sans dépendance tierce complexe et permet des mocks fiables en tests.
class NetworkConnectivityService {
  static final NetworkConnectivityService _instance =
      NetworkConnectivityService._internal();
  factory NetworkConnectivityService() => _instance;
  NetworkConnectivityService._internal();

  /// Override manuel pour les tests ou simulation hors-ligne
  static bool? mockIsConnected;

  /// Cache horodaté du dernier succès pour éviter les faux négatifs
  /// lors des réveils d'écran ou transitions d'application (veille réseau de l'OS)
  static DateTime? _lastSuccessfulCheck;
  static const Duration _gracePeriod = Duration(seconds: 6);

  /// Vérifie si l'appareil dispose actuellement d'un accès internet réel.
  static Future<bool> get isConnected async {
    if (mockIsConnected != null) return mockIsConnected!;

    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest) {
      return mockIsConnected ?? true;
    }

    // 1. Connexion directe par socket IP sur 1.1.1.1:53 et 8.8.8.8:53
    // C'est la méthode la plus rapide (20-50ms) et infaillible car elle ne dépend d'aucun
    // serveur DNS local (Private DNS, routeur ou FAI)
    try {
      final socket = await Socket.connect(
        '1.1.1.1',
        53,
        timeout: const Duration(milliseconds: 1500),
      );
      socket.destroy();
      _lastSuccessfulCheck = DateTime.now();
      return true;
    } catch (_) {}

    try {
      final socket = await Socket.connect(
        '8.8.8.8',
        53,
        timeout: const Duration(milliseconds: 1500),
      );
      socket.destroy();
      _lastSuccessfulCheck = DateTime.now();
      return true;
    } catch (_) {}

    // 2. Première tentative rapide sur google.com
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _lastSuccessfulCheck = DateTime.now();
        return true;
      }
    } catch (_) {}

    // 3. Tentative de secours sur cloudflare.com pour éliminer les latences DNS
    // temporaires lors du réveil du Wi-Fi ou des données mobiles
    try {
      final fallback = await InternetAddress.lookup('cloudflare.com')
          .timeout(const Duration(milliseconds: 1500));
      if (fallback.isNotEmpty && fallback[0].rawAddress.isNotEmpty) {
        _lastSuccessfulCheck = DateTime.now();
        return true;
      }
    } catch (_) {}

    // 4. Période de grâce : si une connexion a été confirmée il y a moins de 6 secondes,
    // on ne signale pas de déconnexion brutale pendant la réactivation des sockets par l'OS
    if (_lastSuccessfulCheck != null &&
        DateTime.now().difference(_lastSuccessfulCheck!) < _gracePeriod) {
      return true;
    }

    return false;
  }
}
