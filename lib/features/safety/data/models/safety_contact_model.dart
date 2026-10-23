import 'package:equatable/equatable.dart';

/// Model representing an emergency contact.
/// Follows Innov & Impact Africa guidelines (data/models/).
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

  factory SafetyContactModel.fromJson(Map<String, dynamic> json) {
    return SafetyContactModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      relationship: json['relationship'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      avatarThemeIndex: json['avatar_theme_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
      'phone': phone,
      'avatar_theme_index': avatarThemeIndex,
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
