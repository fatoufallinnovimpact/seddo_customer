import 'package:seddo/features/saved_places/data/models/saved_place_model.dart';
import 'package:seddo/features/saved_places/data/services/saved_places_service.dart';

abstract class SavedPlacesRepository {
  Future<List<SavedPlaceModel>> getSavedPlaces();
  Future<List<SavedPlaceModel>> addSavedPlace(SavedPlaceModel place);
  Future<List<SavedPlaceModel>> updateSavedPlace(SavedPlaceModel updatedPlace);
  Future<List<SavedPlaceModel>> deleteSavedPlace(String id);
}

class SavedPlacesRepositoryImpl implements SavedPlacesRepository {
  final SavedPlacesService _service;

  SavedPlacesRepositoryImpl({
    SavedPlacesService? service,
  }) : _service = service ?? SavedPlacesService();

  @override
  Future<List<SavedPlaceModel>> getSavedPlaces() => _service.getSavedPlaces();

  @override
  Future<List<SavedPlaceModel>> addSavedPlace(SavedPlaceModel place) =>
      _service.addSavedPlace(place);

  @override
  Future<List<SavedPlaceModel>> updateSavedPlace(SavedPlaceModel updatedPlace) =>
      _service.updateSavedPlace(updatedPlace);

  @override
  Future<List<SavedPlaceModel>> deleteSavedPlace(String id) =>
      _service.deleteSavedPlace(id);
}
