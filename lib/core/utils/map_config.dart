import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Configuration constants for Google Maps & Places API.
abstract class MapConfig {
  static const String defaultAndroidKey =
      'AIzaSyDS18vmy1SR3ghE66qKaM1_aa6eFZQ3DmQ';
  static const String defaultIosKey =
      'AIzaSyAy0NF-94Jy_2pDVX8_X5vtvs3_RPH40wk';
  static const String defaultWebKey =
      'AIzaSyBAkYh81k0fW558_N3tb7K_ig2t7Jf7Wi0';

  static String _googleMapsApiKeyAndroid = defaultAndroidKey;
  static String _googleMapsApiKeyIos = defaultIosKey;
  static String _googleMapsApiKeyWeb = defaultWebKey;

  /// Android Maps Platform API Key
  static String get googleMapsApiKeyAndroid => _googleMapsApiKeyAndroid;

  /// iOS Maps Platform API Key
  static String get googleMapsApiKeyIos => _googleMapsApiKeyIos;

  /// Web Maps Platform API Key
  static String get googleMapsApiKeyWeb => _googleMapsApiKeyWeb;

  /// Central Dakar GPS Coordinates
  static const double dakarCenterLat = 14.7167;
  static const double dakarCenterLng = -17.4677;

  /// Default search radius around Dakar in meters (35 km)
  static const int dakarSearchRadiusMeters = 35000;

  /// Active API key for Places & Geocoding HTTP requests from Dart.
  /// On mobile (both Android and iOS), HTTP REST calls to Google Maps web services
  /// require an API key without iOS bundle restriction. The iOS-restricted key is used
  /// exclusively in native AppDelegate.swift for GMSServices SDK rendering.
  static String get apiKey {
    if (kIsWeb) return _googleMapsApiKeyWeb;
    return _googleMapsApiKeyAndroid;
  }

  /// Updates map keys dynamically from backend params
  static void updateKeys({String? android, String? ios, String? web}) {
    if (android != null && android.isNotEmpty) {
      _googleMapsApiKeyAndroid = android;
    }
    if (ios != null && ios.isNotEmpty) {
      _googleMapsApiKeyIos = ios;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          const MethodChannel('sn.innov.seddo/maps_config')
              .invokeMethod('setMapsApiKey', {'apiKey': ios});
        } catch (_) {}
      }
    }
    if (web != null && web.isNotEmpty) {
      _googleMapsApiKeyWeb = web;
    }
  }
}
