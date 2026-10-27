import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:seddo/core/network/api_client.dart';
import 'package:seddo/core/utils/api_endpoints.dart';

/// Remote HTTP service managing push notification device registration on Seddo backend.
/// Follows Innov & Impact Africa guidelines (data/services/).
class DeviceApiService {
  final Dio _dio;

  DeviceApiService({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  /// POST /v1/users/me/devices
  /// Registers the device push token on backend.
  Future<void> registerDeviceToken({
    required String token,
    String? platform,
    String? accessToken,
  }) async {
    try {
      final detectedPlatform = platform ?? (Platform.isIOS ? 'ios' : 'android');
      final options = Options();
      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers = {'Authorization': 'Bearer $accessToken'};
      }

      await _dio.post(
        ApiEndpoints.devices,
        data: {
          'platform': detectedPlatform,
          'token': token,
        },
        options: options,
      );
    } catch (_) {
      // Background push registration failure should not block user workflow
    }
  }

  /// DELETE /v1/users/me/devices/{token}
  /// Unregisters device push token on logout.
  Future<void> deleteDeviceToken({
    required String token,
    String? accessToken,
  }) async {
    try {
      final options = Options();
      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers = {'Authorization': 'Bearer $accessToken'};
      }

      await _dio.delete(
        ApiEndpoints.deviceToken(token),
        options: options,
      );
    } catch (_) {}
  }
}
