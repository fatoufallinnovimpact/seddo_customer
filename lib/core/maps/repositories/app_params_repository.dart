import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:seddo/core/maps/models/app_params.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class IAppParamsRepository {
  Future<AppParams> getParams({bool forceRefresh = false});
  Future<AppParams> getCachedParams();
}

/// Dépôt responsable de la récupération et de la persistance locale des paramètres d'application.
class AppParamsRepository implements IAppParamsRepository {
  static const String endpointUrl = 'https://seddo-api.innov.sn/v1/app/params';
  static const String _prefKeyParamsJson = 'seddo_cached_app_params_json';
  static const String _prefKeyCachedAt = 'seddo_cached_app_params_timestamp';

  /// Timeout strict de 4 secondes exigé par les spécifications
  static const Duration requestTimeout = Duration(seconds: 4);

  final Dio _dio;
  final SharedPreferences? prefs;

  AppParamsRepository({Dio? dio, this.prefs}) : _dio = dio ?? Dio();

  Future<SharedPreferences> _getPrefs() async {
    return prefs ?? await SharedPreferences.getInstance();
  }

  @override
  Future<AppParams> getCachedParams() async {
    try {
      final prefs = await _getPrefs();
      final cachedJson = prefs.getString(_prefKeyParamsJson);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(cachedJson);
        return AppParams.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('[AppParamsRepository] Erreur lecture cache local: $e');
    }
    return const AppParams();
  }

  @override
  Future<AppParams> getParams({bool forceRefresh = false}) async {
    // 1. Tenter l'appel réseau avec timeout de 4 secondes
    try {
      final response = await _dio.get(
        endpointUrl,
        options: Options(
          sendTimeout: requestTimeout,
          receiveTimeout: requestTimeout,
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);

        final params = AppParams.fromJson(data);

        // Mise en cache local silencieuse (sans logger les clés)
        try {
          final prefs = await _getPrefs();
          await prefs.setString(_prefKeyParamsJson, jsonEncode(data));
          await prefs.setInt(
            _prefKeyCachedAt,
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (e) {
          debugPrint('[AppParamsRepository] Erreur écriture cache local: $e');
        }

        return params;
      }
    } on DioException catch (dioErr) {
      debugPrint('[AppParamsRepository] DioException (type: ${dioErr.type}) -> Bascule sur le cache local');
    } catch (e) {
      debugPrint('[AppParamsRepository] Exception réseau -> Bascule sur le cache local');
    }

    // 2. Si le réseau échoue ou timeout, fallback immédiat sur le cache local
    return getCachedParams();
  }
}
