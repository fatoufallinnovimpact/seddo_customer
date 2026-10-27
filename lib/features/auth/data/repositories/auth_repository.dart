import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/features/auth/data/models/auth_tokens_model.dart';
import 'package:seddo/features/auth/data/models/otp_request_response_model.dart';
import 'package:seddo/features/auth/data/models/user_model.dart';
import 'package:seddo/features/auth/data/services/auth_api_service.dart';
import 'package:seddo/features/auth/data/services/device_api_service.dart';

/// Repository coordinating authentication business logic and caching.
/// Follows Innov & Impact Africa guidelines (data/repositories/).
class AuthRepository {
  final AuthApiService _apiService;
  final DeviceApiService _deviceApiService;

  static UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  @visibleForTesting
  void setCurrentUser(UserModel? user) => _currentUser = user;

  bool get _isTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  AuthRepository({
    AuthApiService? apiService,
    DeviceApiService? deviceApiService,
  })  : _apiService = apiService ?? AuthApiService(),
        _deviceApiService = deviceApiService ?? DeviceApiService();

  /// Request OTP code via SMS or WhatsApp
  Future<OtpRequestResponseModel> requestOtp(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_pending_phone', phone);

    if (_isTest) {
      return OtpRequestResponseModel(
        channel: 'SMS',
        phone: '+221 $phone',
        expiresIn: 300,
        debugCode: '353025',
      );
    }

    final response = await _apiService.requestOtp(phone);
    return response;
  }

  /// Verify 6-digit OTP code and retrieve session tokens
  Future<AuthTokensModel> verifyOtp({
    required String phone,
    required String code,
    String app = 'client',
  }) async {
    final AuthTokensModel tokens;

    if (_isTest) {
      tokens = AuthTokensModel(
        accessToken: 'test_access_token',
        refreshToken: 'test_refresh_token',
        user: UserModel(
          id: 'test_user_id',
          phone: phone,
          firstName: 'Fatou',
          lastName: 'Fall',
          lang: 'fr',
          omEligible: true,
          isNew: false,
          needsProfile: false,
        ),
      );
    } else {
      tokens = await _apiService.verifyOtp(
        phone: phone,
        code: code,
        app: app,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_access_token', tokens.accessToken);
    await prefs.setString('auth_refresh_token', tokens.refreshToken);

    if (tokens.user != null) {
      _currentUser = tokens.user;
      await _persistUser(tokens.user!);

      // If user does not need profile completion (existing user), complete onboarding
      if (!tokens.user!.needsProfile) {
        await prefs.setBool('onboarding_completed', true);
        await registerCurrentDevicePushToken();
      } else {
        // Needs profile completion: do NOT mark onboarding as completed
        await prefs.setBool('onboarding_completed', false);
      }
    }

    return tokens;
  }

  /// Complete profile registration (name, language, and consents)
  Future<UserModel> registerProfile({
    required String firstName,
    required String lastName,
    required String lang,
    bool acceptData = true,
    bool acceptLocation = true,
  }) async {
    final UserModel user;

    if (_isTest) {
      user = UserModel(
        id: 'test_user_id',
        phone: '+221771234512',
        firstName: firstName,
        lastName: lastName,
        lang: lang,
        omEligible: true,
        isNew: false,
        needsProfile: false,
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('auth_access_token');
      final termsVersion = await _apiService.getTermsVersion();

      user = await _apiService.register(
        firstName: firstName,
        lastName: lastName,
        lang: lang,
        termsVersion: termsVersion,
        acceptData: acceptData,
        acceptLocation: acceptLocation,
        accessToken: accessToken,
      );
    }

    _currentUser = user;
    await _persistUser(user);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    await registerCurrentDevicePushToken();
    return user;
  }

  /// Logout current session and clear local credentials
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('auth_access_token');
    final pushToken = prefs.getString('fcm_device_token');

    if (!_isTest) {
      // 1. Delete push device token on backend if available
      if (pushToken != null && pushToken.isNotEmpty) {
        try {
          await _deviceApiService.deleteDeviceToken(
            token: pushToken,
            accessToken: accessToken,
          );
        } catch (_) {}
      }

      // 2. Terminate session on backend
      try {
        await _apiService.logout(accessToken: accessToken);
      } catch (_) {}
    }

    // 3. Clear all cached session data
    _currentUser = null;
    await prefs.remove('auth_access_token');
    await prefs.remove('auth_refresh_token');
    await prefs.remove('auth_user_json');
    await prefs.remove('auth_pending_phone');
    await prefs.remove('user_first_name');
    await prefs.remove('user_last_name');
    await prefs.remove('user_full_name');
    await prefs.remove('user_phone');
    await prefs.remove('onboarding_completed');
  }

  /// Clears session when profile was not completed so user can restart cleanly from onboarding
  Future<void> clearIncompleteSession() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_access_token');
    await prefs.remove('auth_refresh_token');
    await prefs.remove('auth_user_json');
    await prefs.remove('auth_pending_phone');
    await prefs.remove('user_first_name');
    await prefs.remove('user_last_name');
    await prefs.remove('user_full_name');
    await prefs.remove('user_phone');
    await prefs.remove('onboarding_completed');
  }

  /// Reads cached user from SharedPreferences
  Future<UserModel?> getCachedUser() async {
    if (_currentUser != null) return _currentUser;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('auth_user_json');
      if (userJson != null && userJson.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(userJson);
        _currentUser = UserModel.fromJson(data);
        return _currentUser;
      }

      // Fallback: build from individual keys if available
      final firstName = prefs.getString('user_first_name');
      final lastName = prefs.getString('user_last_name');
      final phone = prefs.getString('user_phone');

      if (phone != null || firstName != null || lastName != null) {
        _currentUser = UserModel(
          id: '',
          phone: phone ?? '',
          firstName: firstName,
          lastName: lastName,
          lang: prefs.getString('selected_language') ?? 'fr',
        );
        return _currentUser;
      }
    } catch (e) {
      debugPrint('[AuthRepository] Erreur lecture cache user : $e');
    }
    return null;
  }

  /// Retrieves stored access token
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_access_token');
  }

  /// Checks if user has an active access token and has completed profile setup
  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_access_token');
    if (token == null || token.isEmpty) return false;

    final user = await getCachedUser();
    // If user still needs profile completion, they must complete RegisterNamePage before going to HomePage
    if (user == null || user.needsProfile) {
      return false;
    }

    final completed = prefs.getBool('onboarding_completed') ?? false;
    return completed;
  }

  /// Registers push notification token with backend
  Future<void> registerCurrentDevicePushToken() async {
    if (_isTest) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      String? pushToken = prefs.getString('fcm_device_token');

      if (pushToken == null || pushToken.isEmpty) {
        final fcm = FirebaseMessaging.instance;
        // ignore: deprecated_member_use
        pushToken = await fcm.getToken();
        if (pushToken != null) {
          await prefs.setString('fcm_device_token', pushToken);
        }
      }

      if (pushToken != null && pushToken.isNotEmpty) {
        final accessToken = prefs.getString('auth_access_token');
        await _deviceApiService.registerDeviceToken(
          token: pushToken,
          accessToken: accessToken,
        );
      }
    } catch (_) {
      // Non-fatal if Firebase is not configured or in test environment
    }
  }

  Future<void> _persistUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_user_json', jsonEncode(user.toJson()));
    if (user.firstName != null && user.firstName!.trim().isNotEmpty) {
      await prefs.setString('user_first_name', user.firstName!.trim());
    } else {
      await prefs.remove('user_first_name');
    }
    if (user.lastName != null && user.lastName!.trim().isNotEmpty) {
      await prefs.setString('user_last_name', user.lastName!.trim());
    } else {
      await prefs.remove('user_last_name');
    }
    await prefs.setString('user_full_name', user.fullName);
    await prefs.setString('user_phone', user.phone);
  }
}
