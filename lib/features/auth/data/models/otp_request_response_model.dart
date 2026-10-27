import 'package:equatable/equatable.dart';

/// Response model returned by POST /v1/auth/otp/request.
/// Follows Innov & Impact Africa guidelines (data/models/).
class OtpRequestResponseModel extends Equatable {
  final String? channel;
  final String? phone;
  final int? expiresIn;
  final String? debugCode;

  const OtpRequestResponseModel({
    this.channel,
    this.phone,
    this.expiresIn,
    this.debugCode,
  });

  factory OtpRequestResponseModel.fromJson(Map<String, dynamic> json) {
    return OtpRequestResponseModel(
      channel: json['channel'] as String?,
      phone: json['phone'] as String?,
      expiresIn: json['expiresIn'] as int?,
      debugCode: json['debugCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channel': channel,
      'phone': phone,
      'expiresIn': expiresIn,
      'debugCode': debugCode,
    };
  }

  @override
  List<Object?> get props => [channel, phone, expiresIn, debugCode];
}
