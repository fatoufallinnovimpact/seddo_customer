import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/nearby_driver_model.dart';
import 'home_event.dart';
import 'home_state.dart';

typedef LocationFetcher = Future<LatLng?> Function();

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final LocationFetcher? locationFetcher;
  Timer? _driverMovementTimer;

  HomeBloc({this.locationFetcher}) : super(const HomeState()) {
    on<HomeInitEvent>(_onInit);
    on<HomeUserLocationUpdatedEvent>(_onUserLocationUpdated);
    on<HomeUpdateDriversEvent>(_onUpdateDrivers);
    on<HomeSelectCategoryEvent>(_onSelectCategory);
    on<HomeSelectDestinationEvent>(_onSelectDestination);
    on<HomeClearDestinationEvent>(_onClearDestination);

    add(const HomeInitEvent());
  }

  void _onInit(HomeInitEvent event, Emitter<HomeState> emit) {
    const center = LatLng(14.6937, -17.4440);

    // Initial driver positions around default or current location
    final initialDrivers = _generateDriversAround(center);

    emit(state.copyWith(
      userLocation: center,
      drivers: initialDrivers,
      isMapReady: true,
    ));

    _startDriverSimulation();
    _fetchRealLocation();
  }

  void _onUserLocationUpdated(
    HomeUserLocationUpdatedEvent event,
    Emitter<HomeState> emit,
  ) {
    final updatedDrivers = _generateDriversAround(event.location);
    emit(state.copyWith(
      userLocation: event.location,
      drivers: updatedDrivers,
    ));
  }

  void _onUpdateDrivers(HomeUpdateDriversEvent event, Emitter<HomeState> emit) {
    // Cars do NOT change position; they just pivot on themselves
    final updatedDrivers =
        state.drivers.map((driver) => driver.pivot()).toList();

    emit(state.copyWith(drivers: updatedDrivers));
  }

  void _onSelectCategory(
    HomeSelectCategoryEvent event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(selectedCategory: event.categoryId));
  }

  void _onSelectDestination(
    HomeSelectDestinationEvent event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(
      destinationLocation: event.destinationLocation,
      destinationAddress: event.destinationAddress,
    ));
  }

  void _onClearDestination(
    HomeClearDestinationEvent event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(clearDestination: true));
  }

  List<NearbyDriverModel> _generateDriversAround(LatLng center) {
    return [
      NearbyDriverModel(
        id: 'driver_1',
        latitude: center.latitude + 0.0018,
        longitude: center.longitude + 0.0006,
        heading: 25.0,
        pivotStep: 18.0,
      ),
      NearbyDriverModel(
        id: 'driver_2',
        latitude: center.latitude + 0.0011,
        longitude: center.longitude - 0.0020,
        heading: 105.0,
        pivotStep: -15.0,
      ),
      NearbyDriverModel(
        id: 'driver_3',
        latitude: center.latitude - 0.0017,
        longitude: center.longitude - 0.0012,
        heading: 200.0,
        pivotStep: 22.0,
      ),
      NearbyDriverModel(
        id: 'driver_4',
        latitude: center.latitude - 0.0022,
        longitude: center.longitude + 0.0015,
        heading: 340.0,
        pivotStep: -18.0,
      ),
      NearbyDriverModel(
        id: 'driver_5',
        latitude: center.latitude + 0.0003,
        longitude: center.longitude + 0.0019,
        heading: 180.0,
        pivotStep: 20.0,
      ),
      NearbyDriverModel(
        id: 'driver_6',
        latitude: center.latitude + 0.0023,
        longitude: center.longitude - 0.0010,
        heading: 135.0,
        pivotStep: -20.0,
      ),
    ];
  }

  Future<void> _fetchRealLocation() async {
    try {
      final fetcher = locationFetcher ?? _defaultLocationFetcher;
      final location = await fetcher();
      if (location != null && !isClosed) {
        add(HomeUserLocationUpdatedEvent(location));
      }
    } catch (_) {
      // Graceful fallback to default center
    }
  }

  Future<LatLng?> _defaultLocationFetcher() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return LatLng(lastKnown.latitude, lastKnown.longitude);
        }
      } catch (_) {}
      return null;
    }
  }

  void _startDriverSimulation() {
    _driverMovementTimer?.cancel();
    _driverMovementTimer =
        Timer.periodic(const Duration(milliseconds: 1200), (_) {
      add(const HomeUpdateDriversEvent());
    });
  }

  @override
  Future<void> close() {
    _driverMovementTimer?.cancel();
    return super.close();
  }
}
