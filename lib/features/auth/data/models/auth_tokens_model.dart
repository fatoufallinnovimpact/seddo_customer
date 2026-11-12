import 'package:equatable/equatable.dart';
import 'package:seddo/features/auth/data/models/user_model.dart';

/// Authentication tokens & session model returned by the Seddo API.
/// Follows Innov & Impact Africa guidelines (data/models/).
class AuthTokensModel extends Equatable {
  final String accessToken;
  final String refreshToken;
  final int? expiresIn;
  final UserModel? user;

  const AuthTokensModel({
    required this.accessToken,
    required this.refreshToken,
    this.expiresIn,
    this.user,
  });

  factory AuthTokensModel.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'] ?? json['data']?['user'] ?? json['profile'];
    return AuthTokensModel(
      accessToken: (json['accessToken'] ?? json['access_token'] ?? '') as String? ?? '',
      refreshToken: (json['refreshToken'] ?? json['refresh_token'] ?? '') as String? ?? '',
      expiresIn: (json['expiresIn'] ?? json['expires_in']) as int?,
      user: rawUser is Map<String, dynamic>
          ? UserModel.fromJson(rawUser)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresIn': expiresIn,
      if (user != null) 'user': user!.toJson(),
    };
  }

  AuthTokensModel copyWith({
    String? accessToken,
    String? refreshToken,
    int? expiresIn,
    UserModel? user,
  }) {
    return AuthTokensModel(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresIn: expiresIn ?? this.expiresIn,
      user: user ?? this.user,
    );
  }

  @override
  List<Object?> get props => [accessToken, refreshToken, expiresIn, user];
}
