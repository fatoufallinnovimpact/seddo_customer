import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched when the user edits the phone number
class AuthPhoneNumberChangedEvent extends AuthEvent {
  final String rawPhoneNumber;

  const AuthPhoneNumberChangedEvent(this.rawPhoneNumber);

  @override
  List<Object?> get props => [rawPhoneNumber];
}

/// Dispatched when clicking "Continuer" on the phone input screen
class AuthPhoneNumberSubmittedEvent extends AuthEvent {
  const AuthPhoneNumberSubmittedEvent();
}

/// Dispatched when the user edits the 6-digit OTP code
class AuthOtpCodeChangedEvent extends AuthEvent {
  final String otpCode;

  const AuthOtpCodeChangedEvent(this.otpCode);

  @override
  List<Object?> get props => [otpCode];
}

/// Dispatched when clicking "Continuer" on the OTP verification screen
class AuthOtpSubmittedEvent extends AuthEvent {
  const AuthOtpSubmittedEvent();
}

/// Dispatched to resend the OTP SMS
class AuthResendOtpEvent extends AuthEvent {
  const AuthResendOtpEvent();
}

/// Internal timer tick event for OTP resend countdown
class AuthTimerTickedEvent extends AuthEvent {
  final int secondsRemaining;

  const AuthTimerTickedEvent(this.secondsRemaining);

  @override
  List<Object?> get props => [secondsRemaining];
}
