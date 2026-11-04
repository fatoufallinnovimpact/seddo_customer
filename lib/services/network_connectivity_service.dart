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
  static const Duration _gracePeriod = Duration(seconds: 12);

  /// Marque manuellement la connexion comme active (ex: suite à un appel API réussi)
  static void markOnline() {
    _lastSuccessfulCheck = DateTime.now();
  }

  /// Vérifie si l'appareil dispose actuellement d'un accès internet réel.
  static Future<bool> get isConnected async {
    if (mockIsConnected != null) return mockIsConnected!;

    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest) {
      return mockIsConnected ?? true;
    }

    // 1. Période de grâce : si une connexion a été confirmée il y a moins de 12 secondes,
    // on ne signale pas de déconnexion brutale pendant les micro-latences Wi-Fi ou réveils d'écran
    if (_lastSuccessfulCheck != null &&
        DateTime.now().difference(_lastSuccessfulCheck!) < _gracePeriod) {
      return true;
    }

    // 2. Sondes parallèles ultra-rapides :
    // On sonde simultanément sur les ports web 80 (HTTP) et 443 (HTTPS)
    // qui ne sont JAMAIS bloqués par les box Wi-Fi (contrairement au port 53 TCP).
    // Dès que LA PREMIÈRE sonde répond (20-40ms), on valide la connexion immédiatement !
    final completer = Completer<bool>();
    int pending = 0;

    void recordSuccess() {
      _lastSuccessfulCheck = DateTime.now();
      if (!completer.isCompleted) {
        completer.complete(true);
      }
    }

    void recordFailure() {
      pending--;
      if (pending <= 0 && !completer.isCompleted) {
        if (_lastSuccessfulCheck != null &&
            DateTime.now().difference(_lastSuccessfulCheck!) < _gracePeriod) {
          completer.complete(true);
        } else {
          completer.complete(false);
        }
      }
    }

    Future<void> probeSocket(String host, int port) async {
      try {
        final socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(milliseconds: 2000),
        );
        socket.destroy();
        recordSuccess();
      } catch (_) {
        recordFailure();
      }
    }

    Future<void> probeDns(String host) async {
      try {
        final res = await InternetAddress.lookup(host)
            .timeout(const Duration(milliseconds: 2000));
        if (res.isNotEmpty && res[0].rawAddress.isNotEmpty) {
          recordSuccess();
        } else {
          recordFailure();
        }
      } catch (_) {
        recordFailure();
      }
    }

    final probes = [
      () => probeSocket('1.1.1.1', 80),
      () => probeSocket('1.0.0.1', 80),
      () => probeSocket('seddo-api.innov.sn', 443),
      () => probeDns('google.com'),
      () => probeDns('cloudflare.com'),
    ];

    pending = probes.length;
    for (final probe in probes) {
      probe();
    }

    return completer.future.timeout(
      const Duration(milliseconds: 2500),
      onTimeout: () {
        if (_lastSuccessfulCheck != null &&
            DateTime.now().difference(_lastSuccessfulCheck!) < _gracePeriod) {
          return true;
        }
        return false;
      },
    );
  }
}
