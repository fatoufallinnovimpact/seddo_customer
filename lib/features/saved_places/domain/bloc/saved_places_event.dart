import 'package:equatable/equatable.dart';
import 'package:seddo/features/saved_places/data/models/saved_place_model.dart';

abstract class SavedPlacesEvent extends Equatable {
  const SavedPlacesEvent();

  @override
  List<Object?> get props => [];
}

class SavedPlacesLoadEvent extends SavedPlacesEvent {
  const SavedPlacesLoadEvent();
}

class SavedPlacesAddEvent extends SavedPlacesEvent {
  final SavedPlaceModel place;

  const SavedPlacesAddEvent(this.place);

  @override
  List<Object?> get props => [place];
}

class SavedPlacesUpdateEvent extends SavedPlacesEvent {
  final SavedPlaceModel place;

  const SavedPlacesUpdateEvent(this.place);

  @override
  List<Object?> get props => [place];
}

class SavedPlacesDeleteEvent extends SavedPlacesEvent {
  final String id;

  const SavedPlacesDeleteEvent(this.id);

  @override
  List<Object?> get props => [id];
}
