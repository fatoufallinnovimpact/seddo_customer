
/// Configuration constants for Google Maps & Places API.
abstract class MapConfig {
  /// Android Maps Platform API Key
  static const String googleMapsApiKeyAndroid =
      'AIzaSyDS18vmy1SR3ghE66qKaM1_aa6eFZQ3DmQ';

  /// iOS Maps Platform API Key
  static const String googleMapsApiKeyIos =
      'AIzaSyAy0NF-94Jy_2pDVX8_X5vtvs3_RPH40wk';

  /// Central Dakar GPS Coordinates
  static const double dakarCenterLat = 14.7167;
  static const double dakarCenterLng = -17.4677;

  /// Default search radius around Dakar in meters (35 km)
  static const int dakarSearchRadiusMeters = 35000;

  /// Active API key for Places & Geocoding HTTP requests from Dart.
  /// Uses googleMapsApiKeyAndroid which is authorized for HTTP requests,
  /// while googleMapsApiKeyIos is dedicated to native iOS GMSServices SDK.
  static String get apiKey => googleMapsApiKeyAndroid;
}
