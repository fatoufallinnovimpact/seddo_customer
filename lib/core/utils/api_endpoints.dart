import 'package:seddo/core/utils/base_url.dart';

/// Centralized API endpoints for the Seddo application.
/// Follows Innov & Impact Africa coding guidelines (core/utils/).
abstract class ApiEndpoints {
  static String get baseUrl => BaseUrl.current;

  // Authentication endpoints
  static String get otpRequest => '$baseUrl/v1/auth/otp/request';
  static String get otpVerify => '$baseUrl/v1/auth/otp/verify';
  static String get terms => '$baseUrl/v1/auth/terms';
  static String get register => '$baseUrl/v1/auth/register';
  static String get refresh => '$baseUrl/v1/auth/refresh';
  static String get logout => '$baseUrl/v1/auth/logout';

  // Device push tokens endpoints
  static String get devices => '$baseUrl/v1/users/me/devices';
  static String deviceToken(String token) => '$baseUrl/v1/users/me/devices/$token';

  // Transit v2 endpoints (bus itineraries)
  static String get transitBaseUrl => BaseUrl.transitApi;
  static String get transitFindBus => '$transitBaseUrl/api/v2/transit/find-bus';

  // Rides endpoints (POST /v1/rides/quote, /v1/rides, GET /v1/rides/current)
  static String get ridesQuote => '$baseUrl/v1/rides/quote';
  static String get rides => '$baseUrl/v1/rides';
  static String get ridesCurrent => '$baseUrl/v1/rides/current';
  static String rideDetails(String id) => '$baseUrl/v1/rides/$id';
  static String rideCancel(String id) => '$baseUrl/v1/rides/$id/cancel';
  static String rideMessages(String id) => '$baseUrl/v1/rides/$id/messages';
  static String rideRating(String id) => '$baseUrl/v1/rides/$id/rating';
  static String rideReceiptLink(String id) => '$baseUrl/v1/rides/$id/receipt';
  static String rideReceiptPdf(String id) => '$baseUrl/v1/rides/$id/receipt.pdf';
  static String receiptDownload(String token) => '$baseUrl/v1/receipts/$token';
  static String rideShare(String id) => '$baseUrl/v1/rides/$id/share';
  static String shareView(String token) => '$baseUrl/v1/share/$token';

  // Drivers nearby endpoint (GET /v1/drivers/nearby?lat={lat}&lng={lng})
  static String get driversNearby => '$baseUrl/v1/drivers/nearby';

  // User saved places endpoints (GET /v1/users/me/places, POST /v1/users/me/places, DELETE /v1/users/me/places/{id})
  static String get userPlaces => '$baseUrl/v1/users/me/places';
  static String userPlaceById(String id) => '$baseUrl/v1/users/me/places/$id';

  // User home suggestions endpoint (GET /v1/users/me/suggestions)
  static String get userSuggestions => '$baseUrl/v1/users/me/suggestions';
}
