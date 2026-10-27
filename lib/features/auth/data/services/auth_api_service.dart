import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:seddo/core/network/api_client.dart';
import 'package:seddo/core/utils/api_endpoints.dart';
import 'package:seddo/features/auth/data/models/auth_tokens_model.dart';
import 'package:seddo/features/auth/data/models/otp_request_response_model.dart';
import 'package:seddo/features/auth/data/models/user_model.dart';

/// Remote HTTP API service handling authentication operations with the Seddo backend.
/// Follows Innov & Impact Africa guidelines (data/services/).
class AuthApiService {
  final Dio _dio;

  AuthApiService({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  /// POST /v1/auth/otp/request
  /// Sends a 6-digit OTP code to the provided phone number.
  Future<OtpRequestResponseModel> requestOtp(String phone) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.otpRequest,
        data: {'phone': phone.trim()},
      );

      final data = _parseResponseData(response.data);
      return OtpRequestResponseModel.fromJson(data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// POST /v1/auth/otp/verify
  /// Verifies the OTP code; creates account on first login and opens session.
  Future<AuthTokensModel> verifyOtp({
    required String phone,
    required String code,
    String app = 'client',
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.otpVerify,
        data: {
          'phone': phone.trim(),
          'code': code.trim(),
          'app': app,
        },
      );

      final data = _parseResponseData(response.data);
      return AuthTokensModel.fromJson(data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// GET /v1/auth/terms
  /// Returns the current CGU terms version to display on signup.
  Future<String> getTermsVersion() async {
    try {
      final response = await _dio.get(ApiEndpoints.terms);
      final data = _parseResponseData(response.data);
      return (data['version'] as String?) ?? '2026-10';
    } catch (_) {
      return '2026-10';
    }
  }

  /// POST /v1/auth/register
  /// Completes profile registration with name, language, and consents.
  Future<UserModel> register({
    required String firstName,
    required String lastName,
    required String lang,
    required String termsVersion,
    bool acceptData = true,
    bool acceptLocation = true,
    String? accessToken,
  }) async {
    try {
      final options = Options();
      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers = {'Authorization': 'Bearer $accessToken'};
      }

      final response = await _dio.post(
        ApiEndpoints.register,
        data: {
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'lang': lang,
          'termsVersion': termsVersion,
          'acceptData': acceptData,
          'acceptLocation': acceptLocation,
        },
        options: options,
      );

      final data = _parseResponseData(response.data);
      return UserModel.fromJson(data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// POST /v1/auth/refresh
  /// Exchanges a refresh token for a new pair of tokens.
  Future<AuthTokensModel> refreshToken(String refreshToken) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken.trim()},
      );

      final data = _parseResponseData(response.data);
      return AuthTokensModel.fromJson(data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// POST /v1/auth/logout
  /// Closes the current active session.
  Future<void> logout({String? accessToken}) async {
    try {
      final options = Options();
      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers = {'Authorization': 'Bearer $accessToken'};
      }

      await _dio.post(
        ApiEndpoints.logout,
        options: options,
      );
    } on DioException catch (e) {
      // If 401 or network error on logout, treat as completed locally
      if (e.response?.statusCode != 401) {
        throw _handleDioError(e);
      }
    }
  }

  Map<String, dynamic> _parseResponseData(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    return <String, dynamic>{};
  }

  Exception _handleDioError(DioException e) {
    String message = 'Une erreur est survenue lors de la communication avec le serveur.';
    if (e.response?.data != null) {
      try {
        final data = _parseResponseData(e.response!.data);
        if (data.containsKey('message')) {
          final msg = data['message'];
          if (msg is String) message = msg;
          if (msg is List && msg.isNotEmpty) message = msg.first.toString();
        } else if (data.containsKey('error')) {
          message = data['error'].toString();
        }
      } catch (_) {}
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Délai d\'attente dépassé. Veuillez vérifier votre connexion internet.';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'Impossible de contacter le serveur. Veuillez vérifier votre connexion internet.';
    }
    return Exception(message);
  }
}
