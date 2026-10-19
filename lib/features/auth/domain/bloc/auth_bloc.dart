import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  Timer? _timer;

  AuthBloc() : super(const AuthState()) {
    on<AuthPhoneNumberChangedEvent>(_onPhoneNumberChanged);
    on<AuthPhoneNumberSubmittedEvent>(_onPhoneNumberSubmitted);
    on<AuthOtpCodeChangedEvent>(_onOtpCodeChanged);
    on<AuthOtpSubmittedEvent>(_onOtpSubmitted);
    on<AuthResendOtpEvent>(_onResendOtp);
    on<AuthTimerTickedEvent>(_onTimerTicked);
  }

  void _onPhoneNumberChanged(
    AuthPhoneNumberChangedEvent event,
    Emitter<AuthState> emit,
  ) {
    final cleanDigits = event.rawPhoneNumber.replaceAll(RegExp(r'\D'), '');
    final cappedDigits =
        cleanDigits.length > 9 ? cleanDigits.substring(0, 9) : cleanDigits;

    // Senegal format: XX XXX XX XX (e.g. 77 123 45 12)
    final buffer = StringBuffer();
    for (int i = 0; i < cappedDigits.length; i++) {
      if (i == 2 || i == 5 || i == 7) {
        buffer.write(' ');
      }
      buffer.write(cappedDigits[i]);
    }

    emit(state.copyWith(
      rawPhoneNumber: cappedDigits,
      formattedPhoneNumber: buffer.toString(),
      isPhoneValid: cappedDigits.length == 9,
      status: AuthStatus.initial,
      errorMessage: null,
    ));
  }

  void _onPhoneNumberSubmitted(
    AuthPhoneNumberSubmittedEvent event,
    Emitter<AuthState> emit,
  ) {
    if (!state.isPhoneValid) return;

    emit(state.copyWith(
      status: AuthStatus.phoneSubmitted,
      resendSeconds: 60,
      canResend: false,
    ));
    _startTimer();
  }

  void _onOtpCodeChanged(
    AuthOtpCodeChangedEvent event,
    Emitter<AuthState> emit,
  ) {
    final cleanDigits = event.otpCode.replaceAll(RegExp(r'\D'), '');
    final capped =
        cleanDigits.length > 6 ? cleanDigits.substring(0, 6) : cleanDigits;

    emit(state.copyWith(
      otpCode: capped,
      isOtpValid: capped.length == 6,
      status: AuthStatus.initial,
      errorMessage: null,
    ));
  }

  void _onOtpSubmitted(
    AuthOtpSubmittedEvent event,
    Emitter<AuthState> emit,
  ) {
    if (!state.isOtpValid) return;

    emit(state.copyWith(status: AuthStatus.otpSuccess));
  }

  void _onResendOtp(
    AuthResendOtpEvent event,
    Emitter<AuthState> emit,
  ) {
    if (!state.canResend) return;

    emit(state.copyWith(
      resendSeconds: 60,
      canResend: false,
    ));
    _startTimer();
  }

  void _onTimerTicked(
    AuthTimerTickedEvent event,
    Emitter<AuthState> emit,
  ) {
    emit(state.copyWith(
      resendSeconds: event.secondsRemaining,
      canResend: event.secondsRemaining <= 0,
    ));
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = state.resendSeconds - 1;
      if (current <= 0) {
        timer.cancel();
        add(const AuthTimerTickedEvent(0));
      } else {
        add(AuthTimerTickedEvent(current));
      }
    });
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
