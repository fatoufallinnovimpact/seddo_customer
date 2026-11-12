import 'package:equatable/equatable.dart';


class SafetyContactModel extends Equatable {
  final String id;
  final String name;
  final String relationship;
  final String phone;
  final int avatarThemeIndex;

  const SafetyContactModel({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    this.avatarThemeIndex = 0,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final first = parts[0].isNotEmpty ? parts[0][0] : '';
      final second = parts[1].isNotEmpty ? parts[1][0] : '';
      return '$first$second'.toUpperCase();
    }
    return name.isNotEmpty
        ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase()
        : '';
  }

  factory SafetyContactModel.fromJson(Map<String, dynamic> json, {int index = 0}) {
    final rawPhone = (json['phone'] ?? '').toString();
    final rawId = (json['id'] ?? '').toString();
    return SafetyContactModel(
      id: rawId.isNotEmpty
          ? rawId
          : (rawPhone.isNotEmpty ? rawPhone : 'contact_$index'),
      name: (json['name'] ?? '').toString(),
      relationship: (json['relationship'] ?? '').toString(),
      phone: rawPhone,
      avatarThemeIndex: json['avatar_theme_index'] as int? ?? (index % 3),
    );
  }

  /// Full representation for local cache (SharedPreferences).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
      'phone': phone,
      'avatar_theme_index': avatarThemeIndex,
    };
  }

  /// API DTO representation conforming to ContactDto: { name, phone }.
  Map<String, dynamic> toApiJson() {
    return {
      'name': name.trim(),
      'phone': phone.trim(),
    };
  }

  SafetyContactModel copyWith({
    String? id,
    String? name,
    String? relationship,
    String? phone,
    int? avatarThemeIndex,
  }) {
    return SafetyContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      avatarThemeIndex: avatarThemeIndex ?? this.avatarThemeIndex,
    );
  }

  @override
  List<Object?> get props => [id, name, relationship, phone, avatarThemeIndex];
}
