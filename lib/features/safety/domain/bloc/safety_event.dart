import 'package:equatable/equatable.dart';
import 'package:seddo/features/safety/data/models/safety_contact_model.dart';

abstract class SafetyEvent extends Equatable {
  const SafetyEvent();

  @override
  List<Object?> get props => [];
}

/// Request to load safety data (contacts, settings)
class SafetyLoadRequested extends SafetyEvent {
  const SafetyLoadRequested();
}

/// User triggered the SOS button
class SafetySosTriggered extends SafetyEvent {
  const SafetySosTriggered();
}

/// User dismissed the active SOS alert banner
class SafetySosDismissed extends SafetyEvent {
  const SafetySosDismissed();
}

/// User added a new emergency contact
class SafetyContactAdded extends SafetyEvent {
  final SafetyContactModel contact;

  const SafetyContactAdded(this.contact);

  @override
  List<Object?> get props => [contact];
}

/// User removed an emergency contact
class SafetyContactRemoved extends SafetyEvent {
  final String contactId;

  const SafetyContactRemoved(this.contactId);

  @override
  List<Object?> get props => [contactId];
}

/// User toggled the auto-share setting
class SafetyAutoShareToggled extends SafetyEvent {
  final bool value;

  const SafetyAutoShareToggled(this.value);

  @override
  List<Object?> get props => [value];
}

/// User toggled the PIN code setting
class SafetyPinCodeToggled extends SafetyEvent {
  final bool value;

  const SafetyPinCodeToggled(this.value);

  @override
  List<Object?> get props => [value];
}

/// User toggled the detour alert setting
class SafetyDetourAlertToggled extends SafetyEvent {
  final bool value;

  const SafetyDetourAlertToggled(this.value);

  @override
  List<Object?> get props => [value];
}
