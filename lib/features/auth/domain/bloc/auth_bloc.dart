import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seddo/features/auth/data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC managing Authentication states, OTP requests, and Profile registration.
/// Follows Innov & Impact Africa guidelines (domain/bloc/).
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  Timer? _timer;

  AuthBloc({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository(),
        super(const AuthState()) {
    on<AuthPhoneNumberChangedEvent>(_onPhoneNumberChanged);
    on<AuthPhoneNumberSubmittedEvent>(_onPhoneNumberSubmitted);
    on<AuthOtpCodeChangedEvent>(_onOtpCodeChanged);
    on<AuthOtpSubmittedEvent>(_onOtpSubmitted);
    on<AuthResendOtpEvent>(_onResendOtp);
    on<AuthTimerTickedEvent>(_onTimerTicked);
    on<AuthRegisterProfileEvent>(_onRegisterProfile);
    on<AuthLoadSessionEvent>(_onLoadSession);
    on<AuthLogoutEvent>(_onLogout);
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

  Future<void> _onPhoneNumberSubmitted(
    AuthPhoneNumberSubmittedEvent event,
    Emitter<AuthState> emit,
  ) async {
    if (!state.isPhoneValid) return;

    emit(state.copyWith(
      status: AuthStatus.phoneSubmitting,
      errorMessage: null,
    ));

    try {
      final response = await _authRepository.requestOtp(state.formattedPhoneNumber);
      final seconds = (response.expiresIn != null && response.expiresIn! > 0)
          ? (response.expiresIn! > 60 ? 60 : response.expiresIn!)
          : 60;

      emit(state.copyWith(
        status: AuthStatus.phoneSubmitted,
        resendSeconds: seconds,
        canResend: false,
        otpResponse: response,
      ));
      _startTimer();
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: message,
      ));
    }
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

  Future<void> _onOtpSubmitted(
    AuthOtpSubmittedEvent event,
    Emitter<AuthState> emit,
  ) async {
    if (!state.isOtpValid) return;

    emit(state.copyWith(
      status: AuthStatus.otpVerifying,
      errorMessage: null,
    ));

    try {
      final tokens = await _authRepository.verifyOtp(
        phone: state.formattedPhoneNumber,
        code: state.otpCode,
        app: 'client',
      );

      final needsProfile = tokens.user?.needsProfile ?? true;

      emit(state.copyWith(
        status: AuthStatus.otpSuccess,
        user: tokens.user,
        needsProfile: needsProfile,
      ));
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: message,
      ));
    }
  }

  Future<void> _onResendOtp(
    AuthResendOtpEvent event,
    Emitter<AuthState> emit,
  ) async {
    if (!state.canResend) return;

    try {
      final response = await _authRepository.requestOtp(state.formattedPhoneNumber);
      emit(state.copyWith(
        resendSeconds: 60,
        canResend: false,
        otpResponse: response,
      ));
      _startTimer();
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: message,
      ));
    }
  }

  void _onTimerTicked(
    AuthTimerTickedEvent event,
    Emitter<AuthState> emit,
  ) {
    emit(state.copyWith(
      resendSeconds: event.secondsRemaining,
      canResend: event.secondsRemaining <= 0,
      status: state.status == AuthStatus.phoneSubmitted
          ? AuthStatus.initial
          : state.status,
    ));
  }

  Future<void> _onRegisterProfile(
    AuthRegisterProfileEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      status: AuthStatus.registerSubmitting,
      errorMessage: null,
    ));

    try {
      final user = await _authRepository.registerProfile(
        firstName: event.firstName,
        lastName: event.lastName,
        lang: event.lang,
        acceptData: event.acceptData,
        acceptLocation: event.acceptLocation,
      );

      emit(state.copyWith(
        status: AuthStatus.registerSuccess,
        user: user,
        needsProfile: false,
      ));
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: message,
      ));
    }
  }

  Future<void> _onLoadSession(
    AuthLoadSessionEvent event,
    Emitter<AuthState> emit,
  ) async {
    final cached = await _authRepository.getCachedUser();
    if (cached != null) {
      emit(state.copyWith(
        user: cached,
        needsProfile: cached.needsProfile,
      ));
    }
  }

  Future<void> _onLogout(
    AuthLogoutEvent event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    emit(state.copyWith(
      status: AuthStatus.loggedOut,
      user: null,
      rawPhoneNumber: '',
      formattedPhoneNumber: '',
      otpCode: '',
      isPhoneValid: false,
      isOtpValid: false,
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
