import 'package:equatable/equatable.dart';

/// Model representing privacy settings and consent preferences.
/// Follows Innov & Impact Africa guidelines (data/models/).
class PrivacySettingsModel extends Equatable {
  final int locationPermissionIndex; // 0: while using, 1: always
  final bool preciseLocation;
  final bool personalizedSuggestions;
  final bool offersPromotions;
  final bool usageStatistics;
  final bool contactsAccess;

  const PrivacySettingsModel({
    this.locationPermissionIndex = 0,
    this.preciseLocation = true,
    this.personalizedSuggestions = true,
    this.offersPromotions = false,
    this.usageStatistics = true,
    this.contactsAccess = false,
  });

  factory PrivacySettingsModel.fromJson(Map<String, dynamic> json) {
    return PrivacySettingsModel(
      locationPermissionIndex:
          json['location_permission_index'] as int? ?? 0,
      preciseLocation: json['precise_location'] as bool? ?? true,
      personalizedSuggestions:
          json['personalized_suggestions'] as bool? ?? true,
      offersPromotions: json['offers_promotions'] as bool? ?? false,
      usageStatistics: json['usage_statistics'] as bool? ?? true,
      contactsAccess: json['contacts_access'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location_permission_index': locationPermissionIndex,
      'precise_location': preciseLocation,
      'personalized_suggestions': personalizedSuggestions,
      'offers_promotions': offersPromotions,
      'usage_statistics': usageStatistics,
      'contacts_access': contactsAccess,
    };
  }

  PrivacySettingsModel copyWith({
    int? locationPermissionIndex,
    bool? preciseLocation,
    bool? personalizedSuggestions,
    bool? offersPromotions,
    bool? usageStatistics,
    bool? contactsAccess,
  }) {
    return PrivacySettingsModel(
      locationPermissionIndex:
          locationPermissionIndex ?? this.locationPermissionIndex,
      preciseLocation: preciseLocation ?? this.preciseLocation,
      personalizedSuggestions:
          personalizedSuggestions ?? this.personalizedSuggestions,
      offersPromotions: offersPromotions ?? this.offersPromotions,
      usageStatistics: usageStatistics ?? this.usageStatistics,
      contactsAccess: contactsAccess ?? this.contactsAccess,
    );
  }

  @override
  List<Object?> get props => [
        locationPermissionIndex,
        preciseLocation,
        personalizedSuggestions,
        offersPromotions,
        usageStatistics,
        contactsAccess,
      ];
}
