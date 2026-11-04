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

  /// Vérifie si l'appareil dispose actuellement d'un accès internet réel.
  static Future<bool> get isConnected async {
    if (mockIsConnected != null) return mockIsConnected!;

    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest) {
      return mockIsConnected ?? true;
    }

    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
    return false;
  }
}
