import 'package:equatable/equatable.dart';

abstract class HelpEvent extends Equatable {
  const HelpEvent();

  @override
  List<Object?> get props => [];
}

class HelpLoadRequested extends HelpEvent {
  const HelpLoadRequested();
}

class HelpSearchQueryChanged extends HelpEvent {
  final String query;

  const HelpSearchQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class HelpFaqToggled extends HelpEvent {
  final String id;

  const HelpFaqToggled(this.id);

  @override
  List<Object?> get props => [id];
}
