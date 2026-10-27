import 'package:equatable/equatable.dart';

/// User entity model returned by the Seddo authentication API.
/// Follows Innov & Impact Africa guidelines (data/models/).
class UserModel extends Equatable {
  final String id;
  final String phone;
  final String? firstName;
  final String? lastName;
  final String? lang;
  final bool omEligible;
  final bool isNew;
  final bool needsProfile;

  const UserModel({
    required this.id,
    required this.phone,
    this.firstName,
    this.lastName,
    this.lang,
    this.omEligible = false,
    this.isNew = false,
    this.needsProfile = false,
  });

  /// Full display name
  String get fullName {
    final first = (firstName ?? '').trim();
    final last = (lastName ?? '').trim();
    if (first.isEmpty && last.isEmpty) return 'Utilisateur Seddo';
    if (first.isEmpty) return last;
    if (last.isEmpty) return first;
    return '$first $last';
  }

  /// True user initials for avatar badge (e.g. "FF" for "Fife Fall", "AD" for "Awa Diop")
  String get initials {
    final first = (firstName ?? '').trim();
    final last = (lastName ?? '').trim();

    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    if (first.isNotEmpty) {
      return first.substring(0, first.length >= 2 ? 2 : 1).toUpperCase();
    }
    if (last.isNotEmpty) {
      return last.substring(0, last.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'SD';
  }

  /// Extracts national digits (e.g. "771004313" from "+221 77 100 43 13" or "771004313")
  String get nationalDigits {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 9) {
      return digits.substring(digits.length - 9);
    }
    return digits;
  }

  /// Senegal national phone formatted with spaces: e.g. "77 100 43 13"
  String get formattedNationalPhone {
    final nat = nationalDigits;
    if (nat.length == 9) {
      return '${nat.substring(0, 2)} ${nat.substring(2, 5)} ${nat.substring(5, 7)} ${nat.substring(7)}';
    }
    return phone;
  }

  /// Masked phone for Orange Money payment displays: e.g. "77 ••• 43 13"
  String get maskedPhone {
    final nat = nationalDigits;
    if (nat.length == 9) {
      return '${nat.substring(0, 2)} ••• ${nat.substring(5, 7)} ${nat.substring(7)}';
    }
    if (formattedDisplayPhone.isNotEmpty) {
      return formattedDisplayPhone;
    }
    return '77 ••• 45 12';
  }

  /// Format phone for display with international code (e.g. "+221 77 100 43 13")
  String get formattedDisplayPhone {
    final nat = nationalDigits;
    if (nat.length == 9) {
      return '+221 ${nat.substring(0, 2)} ${nat.substring(2, 5)} ${nat.substring(5, 7)} ${nat.substring(7)}';
    }
    String clean = phone.replaceAll(RegExp(r'\s+'), '');
    return clean.isNotEmpty ? clean : phone;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      lang: json['lang'] as String?,
      omEligible: json['omEligible'] as bool? ?? false,
      isNew: json['isNew'] as bool? ?? false,
      needsProfile: json['needsProfile'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'firstName': firstName,
      'lastName': lastName,
      'lang': lang,
      'omEligible': omEligible,
      'isNew': isNew,
      'needsProfile': needsProfile,
    };
  }

  UserModel copyWith({
    String? id,
    String? phone,
    String? firstName,
    String? lastName,
    String? lang,
    bool? omEligible,
    bool? isNew,
    bool? needsProfile,
  }) {
    return UserModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      lang: lang ?? this.lang,
      omEligible: omEligible ?? this.omEligible,
      isNew: isNew ?? this.isNew,
      needsProfile: needsProfile ?? this.needsProfile,
    );
  }

  @override
  List<Object?> get props => [
        id,
        phone,
        firstName,
        lastName,
        lang,
        omEligible,
        isNew,
        needsProfile,
      ];
}
