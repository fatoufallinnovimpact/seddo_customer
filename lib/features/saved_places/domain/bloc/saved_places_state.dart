import 'package:equatable/equatable.dart';
import 'package:seddo/features/saved_places/data/models/saved_place_model.dart';

abstract class SavedPlacesState extends Equatable {
  const SavedPlacesState();

  @override
  List<Object?> get props => [];
}

class SavedPlacesInitialState extends SavedPlacesState {
  const SavedPlacesInitialState();
}

class SavedPlacesLoadingState extends SavedPlacesState {
  const SavedPlacesLoadingState();
}

class SavedPlacesLoadedState extends SavedPlacesState {
  final List<SavedPlaceModel> places;

  const SavedPlacesLoadedState(this.places);

  @override
  List<Object?> get props => [places];
}

class SavedPlacesErrorState extends SavedPlacesState {
  final String message;

  const SavedPlacesErrorState(this.message);

  @override
  List<Object?> get props => [message];
}
