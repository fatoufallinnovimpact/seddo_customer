import 'package:flutter_test/flutter_test.dart';
import 'package:seddo/features/auth/domain/bloc/auth_bloc.dart';
import 'package:seddo/features/auth/domain/bloc/auth_event.dart';
import 'package:seddo/features/auth/domain/bloc/auth_state.dart';

void main() {
  group('AuthBloc', () {
    late AuthBloc authBloc;

    setUp(() {
      authBloc = AuthBloc();
    });

    tearDown(() {
      authBloc.close();
    });

    test('initial state has default values', () {
      expect(authBloc.state.rawPhoneNumber, '');
      expect(authBloc.state.isPhoneValid, isFalse);
      expect(authBloc.state.otpCode, '');
      expect(authBloc.state.isOtpValid, isFalse);
      expect(authBloc.state.resendSeconds, 60);
      expect(authBloc.state.canResend, isFalse);
      expect(authBloc.state.status, AuthStatus.initial);
    });

    test('formats 9-digit Senegalese phone number correctly and validates', () {
      authBloc.add(const AuthPhoneNumberChangedEvent('771234512'));

      expectLater(
        authBloc.stream,
        emits(predicate<AuthState>((state) {
          return state.rawPhoneNumber == '771234512' &&
              state.formattedPhoneNumber == '77 123 45 12' &&
              state.isPhoneValid == true;
        })),
      );
    });

    test('strictly caps phone number at 9 digits', () {
      authBloc.add(const AuthPhoneNumberChangedEvent('77123451299999'));

      expectLater(
        authBloc.stream,
        emits(predicate<AuthState>((state) {
          return state.rawPhoneNumber == '771234512' &&
              state.rawPhoneNumber.length == 9 &&
              state.isPhoneValid == true;
        })),
      );
    });

    test('validates OTP code at 6 digits', () {
      authBloc.add(const AuthOtpCodeChangedEvent('390214'));

      expectLater(
        authBloc.stream,
        emits(predicate<AuthState>((state) {
          return state.otpCode == '390214' &&
              state.isOtpValid == true &&
              state.otpCode.length == 6;
        })),
      );
    });

    test('submits OTP successfully when code is valid', () {
      authBloc.add(const AuthOtpCodeChangedEvent('390214'));
      authBloc.add(const AuthOtpSubmittedEvent());

      expectLater(
        authBloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.isOtpValid == true),
          predicate<AuthState>((s) => s.status == AuthStatus.otpSuccess),
        ]),
      );
    });
  });
}
