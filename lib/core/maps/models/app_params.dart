import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:seddo/core/maps/models/map_provider.dart';

/// Configuration des clés API par plateforme.
class MapsKeysConfig {
  final String? android;
  final String? ios;
  final String? web;

  const MapsKeysConfig({
    this.android,
    this.ios,
    this.web,
  });

  factory MapsKeysConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MapsKeysConfig();
    return MapsKeysConfig(
      android: json['android'] as String?,
      ios: json['ios'] as String?,
      web: json['web'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'android': android,
        'ios': ios,
        'web': web,
      };

  /// Récupère la clé selon la plateforme courante (Android / iOS / Web / Test).
  String? get currentPlatformKey {
    if (kIsWeb) return web;
    if (Platform.isAndroid) return android;
    if (Platform.isIOS) return ios;
    // Environnement de test unitaire ou bureau (macOS / Linux / Windows)
    return android ?? ios ?? web;
  }
}

/// Indicateur d'activation de Google Maps par plateforme.
class MapsEnabledConfig {
  final bool android;
  final bool ios;
  final bool web;

  const MapsEnabledConfig({
    this.android = false,
    this.ios = false,
    this.web = false,
  });

  factory MapsEnabledConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MapsEnabledConfig();
    return MapsEnabledConfig(
      android: json['android'] == true,
      ios: json['ios'] == true,
      web: json['web'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'android': android,
        'ios': ios,
        'web': web,
      };

  /// Vérifie si Maps est activé sur la plateforme active.
  bool get isCurrentPlatformEnabled {
    if (kIsWeb) return web;
    if (Platform.isAndroid) return android;
    if (Platform.isIOS) return ios;
    // Environnement de test unitaire ou bureau
    return android || ios || web;
  }
}

/// Paramètres distants retournés par l'endpoint GET /v1/app/params.
class AppParams {
  final MapsKeysConfig maps;
  final MapsEnabledConfig mapsEnabled;

  const AppParams({
    this.maps = const MapsKeysConfig(),
    this.mapsEnabled = const MapsEnabledConfig(),
  });

  /// Parser ultra-tolérant (les champs manquants ou nulls retournent des valeurs par défaut sécurisées).
  factory AppParams.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppParams();

    final mapsData = json['maps'];
    final mapsEnabledData = json['mapsEnabled'];

    return AppParams(
      maps: MapsKeysConfig.fromJson(
        mapsData is Map<String, dynamic> ? mapsData : null,
      ),
      mapsEnabled: MapsEnabledConfig.fromJson(
        mapsEnabledData is Map<String, dynamic> ? mapsEnabledData : null,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'maps': maps.toJson(),
        'mapsEnabled': mapsEnabled.toJson(),
      };

  /// Clé API active pour les requêtes HTTP de cartographie et de recherche.
  /// Note : Sur iOS, la clé iOS du backend possède une restriction bundle ID native
  /// utilisée par GMSServices SDK dans AppDelegate.swift. Pour les requêtes REST Dart
  /// (Places API, Geocoding, Routes), la clé REST (android) est utilisée afin d'éviter
  /// le rejet Google "API_KEY_IOS_APP_BLOCKED".
  String? get activeApiKey {
    if (kIsWeb) return maps.web;
    return maps.android ?? maps.ios ?? maps.web;
  }

  /// Indique si Google Maps est activé côté backend pour cette plateforme.
  bool get isMapsEnabledForPlatform => mapsEnabled.isCurrentPlatformEnabled;

  /// Règle métier stricte : Google est utilisable UNIQUEMENT si
  /// mapsEnabled[plateforme] == true ET que la clé est non-nulle et non-vide.
  bool get isGoogleUsable {
    final key = activeApiKey;
    return isMapsEnabledForPlatform && key != null && key.trim().isNotEmpty;
  }

  /// Fournisseur déduit par la configuration distante.
  MapProvider get targetProvider =>
      isGoogleUsable ? MapProvider.google : MapProvider.osm;
}
