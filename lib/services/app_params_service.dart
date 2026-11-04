import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:seddo/core/utils/api_endpoints.dart';
import 'package:seddo/core/utils/map_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service pour récupérer et mettre en cache les paramètres applicatifs (clés Google Maps)
/// depuis l'endpoint GET /v1/app/params.
/// Durée de cache: 5 minutes (max-age=300).
class AppParamsService {
  static final AppParamsService _instance = AppParamsService._internal();
  factory AppParamsService({Dio? dio}) {
    if (dio != null) _instance._dio = dio;
    return _instance;
  }
  AppParamsService._internal();

  Dio _dio = Dio();

  static const String _prefKeyAndroid = 'seddo_maps_key_android';
  static const String _prefKeyIos = 'seddo_maps_key_ios';
  static const String _prefKeyWeb = 'seddo_maps_key_web';
  static const String _prefKeyTimestamp = 'seddo_maps_keys_cached_at';

  /// Cache TTL: 5 minutes en millisecondes
  static const int _cacheTtlMs = 5 * 60 * 1000;

  /// Charge les clés depuis le cache local (immédiat) ou interroge l'API GET /v1/app/params
  Future<void> initParams({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Appliquer d'abord les clés du cache local pour une disponibilité instantanée
    final cachedAndroid = prefs.getString(_prefKeyAndroid);
    final cachedIos = prefs.getString(_prefKeyIos);
    final cachedWeb = prefs.getString(_prefKeyWeb);
    if (cachedAndroid != null || cachedIos != null || cachedWeb != null) {
      MapConfig.updateKeys(
        android: cachedAndroid,
        ios: cachedIos,
        web: cachedWeb,
      );
    }

    // 2. Vérifier si le cache est encore valide (moins de 5 min)
    final lastFetched = prefs.getInt(_prefKeyTimestamp) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final isCacheExpired = (now - lastFetched) > _cacheTtlMs;

    if (!isCacheExpired && !forceRefresh) {
      debugPrint('[AppParamsService] ⚡ Clés Google Maps chargées depuis le cache local (valide 5 min)');
      return;
    }

    // 3. Interroger l'endpoint GET /v1/app/params
    try {
      final url = ApiEndpoints.appParams;
      debugPrint('[AppParamsService] 🚀 GET $url');
      final response = await _dio.get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;

        final maps = data['maps'] as Map<String, dynamic>?;
        if (maps != null) {
          final androidKey = maps['android'] as String?;
          final iosKey = maps['ios'] as String?;
          final webKey = maps['web'] as String?;

          MapConfig.updateKeys(
            android: androidKey,
            ios: iosKey,
            web: webKey,
          );

          // Sauvegarde dans le cache local
          if (androidKey != null) await prefs.setString(_prefKeyAndroid, androidKey);
          if (iosKey != null) await prefs.setString(_prefKeyIos, iosKey);
          if (webKey != null) await prefs.setString(_prefKeyWeb, webKey);
          await prefs.setInt(_prefKeyTimestamp, now);

          debugPrint('[AppParamsService] ✅ Clés Maps synchronisées avec succès depuis le backoffice.');
        }
      }
    } catch (e) {
      debugPrint('[AppParamsService] ⚠️ Erreur récupération params (utilisation fallback/cache): $e');
    }
  }
}
