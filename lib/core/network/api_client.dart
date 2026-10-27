import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/core/utils/api_endpoints.dart';
import 'package:seddo/core/utils/base_url.dart';

/// Centralized Dio API Client with automatic JWT authorization and token refresh.
/// Follows Innov & Impact Africa guidelines (core/network/).
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  bool _isRefreshing = false;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: BaseUrl.current,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
        headers: {
          'accept': '*/*',
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // If authorization header is not explicitly set, attach saved access token
          if (!options.headers.containsKey('Authorization')) {
            try {
              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString('auth_access_token');
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            } catch (_) {}
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // Automatic Token Refresh on 401 Unauthorized
          if (error.response?.statusCode == 401 && !_isRefreshing) {
            final requestPath = error.requestOptions.path;
            final isAuthEndpoint = requestPath.contains('/v1/auth/otp') ||
                requestPath.contains('/v1/auth/refresh') ||
                requestPath.contains('/v1/auth/logout');

            if (!isAuthEndpoint) {
              _isRefreshing = true;
              try {
                final prefs = await SharedPreferences.getInstance();
                final refreshToken = prefs.getString('auth_refresh_token');

                if (refreshToken != null && refreshToken.isNotEmpty) {
                  // Dedicated fresh Dio instance to avoid interceptor recursion
                  final refreshDio = Dio(
                    BaseOptions(
                      baseUrl: BaseUrl.current,
                      headers: {
                        'accept': '*/*',
                        'Content-Type': 'application/json',
                      },
                    ),
                  );

                  final response = await refreshDio.post(
                    ApiEndpoints.refresh,
                    data: {'refreshToken': refreshToken},
                  );

                  if (response.statusCode == 200 && response.data != null) {
                    final data = response.data is String
                        ? jsonDecode(response.data as String) as Map<String, dynamic>
                        : response.data as Map<String, dynamic>;

                    final newAccess = data['accessToken'] as String?;
                    final newRefresh = data['refreshToken'] as String?;

                    if (newAccess != null) {
                      await prefs.setString('auth_access_token', newAccess);
                    }
                    if (newRefresh != null) {
                      await prefs.setString('auth_refresh_token', newRefresh);
                    }

                    // Retry original request with new access token
                    final originalOptions = error.requestOptions;
                    if (newAccess != null) {
                      originalOptions.headers['Authorization'] = 'Bearer $newAccess';
                    }

                    final retryResponse = await dio.fetch(originalOptions);
                    _isRefreshing = false;
                    return handler.resolve(retryResponse);
                  }
                }
              } catch (_) {
                // Refresh failed; let the error propagate
              } finally {
                _isRefreshing = false;
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }
}
