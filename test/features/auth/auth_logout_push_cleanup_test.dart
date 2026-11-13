import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/features/auth/data/models/user_model.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';
import 'package:seddo/features/auth/domain/bloc/auth_bloc.dart';
import 'package:seddo/features/auth/domain/bloc/auth_event.dart';
import 'package:seddo/features/auth/domain/bloc/auth_state.dart';
import 'package:seddo/services/realtime_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('AuthRepository Logout & Push Cleanup Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'auth_access_token': 'fake_jwt_access_token',
        'auth_refresh_token': 'fake_jwt_refresh_token',
        'auth_user_json': '{"id":"usr_123","phone":"771234567","name":"Fatou Fall"}',
        'fcm_device_token': 'fake_fcm_token_xyz_123:APA91bTest',
        'user_first_name': 'Fatou',
        'user_last_name': 'Fall',
        'user_phone': '771234567',
        'onboarding_completed': true,
      });
    });

    test('AuthRepository.logout() clears fcm_device_token and all credentials', () async {
      final repo = AuthRepository();
      repo.setCurrentUser(const UserModel(
        id: 'usr_123',
        phone: '771234567',
        firstName: 'Fatou',
        lastName: 'Fall',
      ));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('fcm_device_token'), isNotNull);
      expect(prefs.getString('auth_access_token'), isNotNull);

      await repo.logout();

      expect(prefs.getString('fcm_device_token'), isNull,
          reason: 'FCM device token must be cleared from storage on logout');
      expect(prefs.getString('auth_access_token'), isNull);
      expect(prefs.getString('auth_refresh_token'), isNull);
      expect(prefs.getString('auth_user_json'), isNull);
      expect(repo.currentUser, isNull);
      expect(RealtimeService().connectionStatus, RealtimeConnectionStatus.disconnected);
    });

    test('AuthBloc logout event triggers repository logout and resets state', () async {
      final authBloc = AuthBloc();

      authBloc.add(const AuthLogoutEvent());

      await expectLater(
        authBloc.stream,
        emits(predicate<AuthState>((state) {
          return state.status == AuthStatus.loggedOut &&
              state.user == null &&
              state.rawPhoneNumber.isEmpty;
        })),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('fcm_device_token'), isNull);
      expect(prefs.getString('auth_access_token'), isNull);

      await authBloc.close();
    });
  });
}
