import 'package:equatable/equatable.dart';

abstract class PrivacyEvent extends Equatable {
  const PrivacyEvent();

  @override
  List<Object?> get props => [];
}

class PrivacyLoadRequested extends PrivacyEvent {
  const PrivacyLoadRequested();
}

class PrivacyLocationPermissionChanged extends PrivacyEvent {
  final int index;

  const PrivacyLocationPermissionChanged(this.index);

  @override
  List<Object?> get props => [index];
}

class PrivacyPreciseLocationToggled extends PrivacyEvent {
  final bool value;

  const PrivacyPreciseLocationToggled(this.value);

  @override
  List<Object?> get props => [value];
}

class PrivacyPersonalizedSuggestionsToggled extends PrivacyEvent {
  final bool value;

  const PrivacyPersonalizedSuggestionsToggled(this.value);

  @override
  List<Object?> get props => [value];
}

class PrivacyOffersPromotionsToggled extends PrivacyEvent {
  final bool value;

  const PrivacyOffersPromotionsToggled(this.value);

  @override
  List<Object?> get props => [value];
}

class PrivacyUsageStatisticsToggled extends PrivacyEvent {
  final bool value;

  const PrivacyUsageStatisticsToggled(this.value);

  @override
  List<Object?> get props => [value];
}

class PrivacyDataDownloadRequested extends PrivacyEvent {
  const PrivacyDataDownloadRequested();
}

class PrivacyClearHistoryRequested extends PrivacyEvent {
  const PrivacyClearHistoryRequested();
}

class PrivacyDeleteAccountRequested extends PrivacyEvent {
  const PrivacyDeleteAccountRequested();
}
