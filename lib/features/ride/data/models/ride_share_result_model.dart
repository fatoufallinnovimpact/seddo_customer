/// Result returned by POST /v1/rides/{id}/share
/// Public tracking link and token accessible without authentication.
class RideShareResultModel {
  final String url;
  final String token;

  const RideShareResultModel({
    required this.url,
    required this.token,
  });

  factory RideShareResultModel.fromJson(Map<String, dynamic> json) {
    return RideShareResultModel(
      url: json['url'] as String? ?? '',
      token: json['token'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'token': token,
      };
}
