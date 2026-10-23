import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seddo/features/saved_places/data/repositories/saved_places_repository.dart';
import 'package:seddo/features/saved_places/domain/bloc/saved_places_event.dart';
import 'package:seddo/features/saved_places/domain/bloc/saved_places_state.dart';

class SavedPlacesBloc extends Bloc<SavedPlacesEvent, SavedPlacesState> {
  final SavedPlacesRepository _repository;

  SavedPlacesBloc({
    SavedPlacesRepository? repository,
  })  : _repository = repository ?? SavedPlacesRepositoryImpl(),
        super(const SavedPlacesInitialState()) {
    on<SavedPlacesLoadEvent>(_onLoad);
    on<SavedPlacesAddEvent>(_onAdd);
    on<SavedPlacesUpdateEvent>(_onUpdate);
    on<SavedPlacesDeleteEvent>(_onDelete);
  }

  Future<void> _onLoad(
    SavedPlacesLoadEvent event,
    Emitter<SavedPlacesState> emit,
  ) async {
    emit(const SavedPlacesLoadingState());
    try {
      final places = await _repository.getSavedPlaces();
      emit(SavedPlacesLoadedState(places));
    } catch (e) {
      emit(SavedPlacesErrorState(e.toString()));
    }
  }

  Future<void> _onAdd(
    SavedPlacesAddEvent event,
    Emitter<SavedPlacesState> emit,
  ) async {
    try {
      final updated = await _repository.addSavedPlace(event.place);
      emit(SavedPlacesLoadedState(updated));
    } catch (e) {
      emit(SavedPlacesErrorState(e.toString()));
    }
  }

  Future<void> _onUpdate(
    SavedPlacesUpdateEvent event,
    Emitter<SavedPlacesState> emit,
  ) async {
    try {
      final updated = await _repository.updateSavedPlace(event.place);
      emit(SavedPlacesLoadedState(updated));
    } catch (e) {
      emit(SavedPlacesErrorState(e.toString()));
    }
  }

  Future<void> _onDelete(
    SavedPlacesDeleteEvent event,
    Emitter<SavedPlacesState> emit,
  ) async {
    try {
      final updated = await _repository.deleteSavedPlace(event.id);
      emit(SavedPlacesLoadedState(updated));
    } catch (e) {
      emit(SavedPlacesErrorState(e.toString()));
    }
  }
}
