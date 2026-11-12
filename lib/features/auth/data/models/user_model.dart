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
  final double? rating;
  final int? ratingCount;
  final String? photoUrl;
  final bool notifyPush;
  final bool notifySms;

  const UserModel({
    required this.id,
    required this.phone,
    this.firstName,
    this.lastName,
    this.lang,
    this.omEligible = false,
    this.isNew = false,
    this.needsProfile = false,
    this.rating,
    this.ratingCount,
    this.photoUrl,
    this.notifyPush = true,
    this.notifySms = false,
  });

  /// Formatted rating string from GET /v1/users/me (e.g. "4,8" or "Nouveau")
  String get displayRating {
    if (rating != null && rating! > 0) {
      return rating!.toStringAsFixed(1).replaceAll('.', ',');
    }
    return 'Nouveau';
  }

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
    // Support nested responses (e.g. { "user": { ... } } or { "data": { ... } } or { "profile": { ... } })
    final map = (json['user'] is Map<String, dynamic>)
        ? json['user'] as Map<String, dynamic>
        : (json['data'] is Map<String, dynamic>)
            ? json['data'] as Map<String, dynamic>
            : (json['profile'] is Map<String, dynamic>)
                ? json['profile'] as Map<String, dynamic>
                : json;

    final rawRating = map['rating'] ??
        map['averageRating'] ??
        map['clientRating'] ??
        map['driverRating'] ??
        map['note'];
    final double? parsedRating = rawRating is num
        ? rawRating.toDouble()
        : (rawRating != null ? double.tryParse(rawRating.toString()) : null);

    final rawRatingCount = map['ratingCount'] ??
        map['rating_count'] ??
        map['ratingsCount'] ??
        map['totalRatings'] ??
        map['count'];
    final int? parsedRatingCount = rawRatingCount is num
        ? rawRatingCount.toInt()
        : (rawRatingCount != null ? int.tryParse(rawRatingCount.toString()) : null);

    // Support firstName, first_name, prenom
    String? first = (map['firstName'] ?? map['first_name'] ?? map['prenom']) as String?;
    // Support lastName, last_name, nom
    String? last = (map['lastName'] ?? map['last_name'] ?? map['nom']) as String?;

    // If separate names are not provided, check combined name (e.g. "Fatou Fall" or "Fatou")
    if ((first == null || first.trim().isEmpty) && (last == null || last.trim().isEmpty)) {
      final combined = (map['name'] ??
          map['fullName'] ??
          map['full_name'] ??
          map['displayName']) as String?;
      if (combined != null && combined.trim().isNotEmpty) {
        final parts = combined.trim().split(RegExp(r'\s+'));
        first = parts.first;
        if (parts.length > 1) {
          last = parts.sublist(1).join(' ');
        }
      }
    }

    final phone = (map['phone'] ??
        map['phone_number'] ??
        map['phoneNumber'] ??
        map['telephone'] ??
        '') as String? ?? '';

    final photoUrl = (map['photoUrl'] ??
        map['photo_url'] ??
        map['photo'] ??
        map['avatar'] ??
        map['avatarUrl']) as String?;

    final lang = (map['lang'] ?? map['language'] ?? map['langue']) as String?;

    final omEligible = (map['omEligible'] ??
        map['om_eligible'] ??
        map['isOmEligible'] ??
        false) as bool? ?? false;

    final isNew = (map['isNew'] ?? map['is_new'] ?? false) as bool? ?? false;

    final needsProfile = (map['needsProfile'] ??
        map['needs_profile'] ??
        false) as bool? ?? false;

    final notifyPush = (map['notifyPush'] ??
        map['notify_push'] ??
        true) as bool? ?? true;

    final notifySms = (map['notifySms'] ??
        map['notify_sms'] ??
        false) as bool? ?? false;

    return UserModel(
      id: (map['id'] ?? map['_id'] ?? '') as String? ?? '',
      phone: phone,
      firstName: first,
      lastName: last,
      lang: lang,
      omEligible: omEligible,
      isNew: isNew,
      needsProfile: needsProfile,
      rating: parsedRating,
      ratingCount: parsedRatingCount,
      photoUrl: photoUrl,
      notifyPush: notifyPush,
      notifySms: notifySms,
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
      'rating': rating,
      'ratingCount': ratingCount,
      'photoUrl': photoUrl,
      'notifyPush': notifyPush,
      'notifySms': notifySms,
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
    double? rating,
    int? ratingCount,
    String? photoUrl,
    bool? notifyPush,
    bool? notifySms,
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
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      photoUrl: photoUrl ?? this.photoUrl,
      notifyPush: notifyPush ?? this.notifyPush,
      notifySms: notifySms ?? this.notifySms,
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
        rating,
        ratingCount,
        photoUrl,
        notifyPush,
        notifySms,
      ];
}
