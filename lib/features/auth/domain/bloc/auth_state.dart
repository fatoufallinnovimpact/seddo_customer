import 'package:equatable/equatable.dart';

enum AuthStatus {
  initial,
  phoneSubmitting,
  phoneSubmitted,
  otpVerifying,
  otpSuccess,
  error,
}

class AuthState extends Equatable {
  final String rawPhoneNumber; // 9 digits, e.g. "771234512"
  final String formattedPhoneNumber; // e.g. "77 123 45 12"
  final bool isPhoneValid; // rawPhoneNumber.length == 9
  final String otpCode; // up to 6 digits, e.g. "390214"
  final bool isOtpValid; // otpCode.length == 6
  final int resendSeconds; // countdown (60s)
  final bool canResend; // resendSeconds == 0
  final AuthStatus status;
  final String? errorMessage;

  const AuthState({
    this.rawPhoneNumber = '',
    this.formattedPhoneNumber = '',
    this.isPhoneValid = false,
    this.otpCode = '',
    this.isOtpValid = false,
    this.resendSeconds = 60,
    this.canResend = false,
    this.status = AuthStatus.initial,
    this.errorMessage,
  });

  AuthState copyWith({
    String? rawPhoneNumber,
    String? formattedPhoneNumber,
    bool? isPhoneValid,
    String? otpCode,
    bool? isOtpValid,
    int? resendSeconds,
    bool? canResend,
    AuthStatus? status,
    String? errorMessage,
  }) {
    return AuthState(
      rawPhoneNumber: rawPhoneNumber ?? this.rawPhoneNumber,
      formattedPhoneNumber: formattedPhoneNumber ?? this.formattedPhoneNumber,
      isPhoneValid: isPhoneValid ?? this.isPhoneValid,
      otpCode: otpCode ?? this.otpCode,
      isOtpValid: isOtpValid ?? this.isOtpValid,
      resendSeconds: resendSeconds ?? this.resendSeconds,
      canResend: canResend ?? this.canResend,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        rawPhoneNumber,
        formattedPhoneNumber,
        isPhoneValid,
        otpCode,
        isOtpValid,
        resendSeconds,
        canResend,
        status,
        errorMessage,
      ];
}
