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
}
