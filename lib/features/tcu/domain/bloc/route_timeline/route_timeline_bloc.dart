import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../../data/models/transit/ItineraireLegModel.dart';
import '../../../data/models/transit/PlaceModel.dart';
import '../../../data/models/transit/StopTimeResponse.dart';
import '../../../data/models/transit/TransitResponseModel.dart';

part 'route_timeline_event.dart';
part 'route_timeline_state.dart';

class RouteTimelineBloc extends Bloc<RouteTimelineEvent, RouteTimelineState> {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "https://transit.innov.sn/api/v2/",
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 40),
      headers: {"accept": "*/*", "Content-Type": "application/json"},
    ),
  );

  StreamSubscription<Position>? positionStreamSubscription;

  RouteTimelineBloc() : super(const RouteTimelineState()) {
    on<RouteTimelineInitialized>(_onInitialized);
    on<RouteTimelineDepartureDataRequested>(_onDepartureDataRequested);
    on<RouteTimelineCurrentPositionUpdated>(_onCurrentPositionUpdated);
    on<RouteTimelineDispose>(_onDispose);
    on<RouteTimelineTabChanged>((event, emit) {
      emit(state.copyWith(itineraireIndex: event.index));
    });
  }

  @override
  Future<void> close() async {
    await positionStreamSubscription?.cancel();
    return super.close();
  }

  Future<void> _onInitialized(
    RouteTimelineInitialized event,
    Emitter<RouteTimelineState> emit,
  ) async {
    emit(
      state.copyWith(
        status: RouteTimelineStatus.loading,
        itineraires: [],
        departureTransit: [],
        itineraireIndex: event.index,
      ),
    );

    try {
      Position? currentPosition;
      try {
        currentPosition = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.medium),
        );
      } catch (_) {}

      double startLat = event.fromPlaceDetails?.latitude ?? 0;
      double startLon = event.fromPlaceDetails?.longitude ?? 0;
      double endLat = event.toPlaceDetails?.latitude ?? 0;
      double endLon = event.toPlaceDetails?.longitude ?? 0;

      // Si le départ est "Ma position actuelle" sans coordonnées, utiliser la position GPS
      if (startLat == 0 && startLon == 0 && currentPosition != null) {
        startLat = currentPosition.latitude;
        startLon = currentPosition.longitude;
      }
      if (startLat == 0 && startLon == 0) {
        startLat = 14.6937949;
        startLon = -17.4914255;
      }

      // Si l'arrivée est vide ou à 0
      if (endLat == 0 && endLon == 0) {
        emit(
          state.copyWith(
            status: RouteTimelineStatus.success,
            itineraires: [],
            errorMessage: 'Veuillez sélectionner une destination.',
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          status: RouteTimelineStatus.loading,
          startLat: startLat,
          startLon: startLon,
          endLat: endLat,
          endLon: endLon,
          currentPosition: currentPosition,
          itineraireIndex: event.index,
          date: event.date,
          time: event.time,
        ),
      );

      positionStreamSubscription?.cancel();
      try {
        positionStreamSubscription = Geolocator.getPositionStream(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        ).listen((p) {
          add(RouteTimelineCurrentPositionUpdated(p));
        });
      } catch (_) {}

      final dist =
          Geolocator.distanceBetween(startLat, startLon, endLat, endLon);
      if (dist >= 100) {
        await _fetchItineraires(
          startLat: startLat,
          startLon: startLon,
          endLat: endLat,
          endLon: endLon,
          emit: emit,
        );
      } else {
        emit(
          state.copyWith(
            status: RouteTimelineStatus.success,
            itineraires: [],
            errorMessage: 'Le départ et la destination sont trop proches.',
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: RouteTimelineStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onDepartureDataRequested(
    RouteTimelineDepartureDataRequested event,
    Emitter<RouteTimelineState> emit,
  ) async {
    await _fetchItineraires(
      startLat: event.startLat,
      startLon: event.startLon,
      endLat: event.endLat,
      endLon: event.endLon,
      emit: emit,
    );
  }

  void _onCurrentPositionUpdated(
    RouteTimelineCurrentPositionUpdated event,
    Emitter<RouteTimelineState> emit,
  ) {
    emit(state.copyWith(currentPosition: event.position));
  }

  Future<void> _onDispose(
    RouteTimelineDispose event,
    Emitter<RouteTimelineState> emit,
  ) async {
    await positionStreamSubscription?.cancel();
  }

  /// Recherche d'itinéraires de bus via Transit v2 (POST /api/v2/transit/find-bus)
  Future<void> _fetchItineraires({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    required Emitter<RouteTimelineState> emit,
    int maxDistanceFrom = 2000,
    int maxDistanceTo = 2000,
  }) async {
    emit(state.copyWith(departureLoader: true));

    final now = DateTime.now();
    final String date = state.date.isNotEmpty
        ? state.date.replaceAll('-', '')
        : DateFormat('yyyyMMdd').format(now);
    final String time = state.time.isNotEmpty
        ? state.time
        : DateFormat('HH:mm:ss').format(now);

    List<ItineraireModel>? itineraires;
    int attempt = 0;
    const int maxAttempts = 3;

    // Retry avec rayon élargi si aucun itinéraire immédiat
    while ((itineraires == null || itineraires.isEmpty) &&
        attempt < maxAttempts) {
      itineraires = await _callFindBus(
        startLat: startLat,
        startLon: startLon,
        endLat: endLat,
        endLon: endLon,
        maxDistanceFrom: maxDistanceFrom,
        maxDistanceTo: maxDistanceTo,
        date: date,
        time: time,
      );

      if (itineraires == null || itineraires.isEmpty) {
        maxDistanceTo += 1000;
        maxDistanceFrom += 1000;
        attempt++;
      }
    }

    if (itineraires != null && itineraires.isNotEmpty) {
      emit(
        state.copyWith(
          itineraires: itineraires,
          itineraireSize: itineraires.length,
          status: RouteTimelineStatus.success,
          departureLoader: false,
          maxDistanceFrom: maxDistanceFrom,
          maxDistanceTo: maxDistanceTo,
        ),
      );
    } else {
      emit(
        state.copyWith(
          itineraires: [],
          status: RouteTimelineStatus.success,
          departureLoader: false,
          errorMessage: 'Aucun bus disponible pour cet itinéraire.',
        ),
      );
    }
  }

  Future<List<ItineraireModel>?> _callFindBus({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    required int maxDistanceFrom,
    required int maxDistanceTo,
    required String date,
    required String time,
  }) async {
    try {
      final body = {
        "date": date,
        "time": time,
        "departureLat": startLat,
        "departureLon": startLon,
        "destinationLat": endLat,
        "destinationLon": endLon,
        "maxDistanceFrom": maxDistanceFrom,
        "maxDistanceTo": maxDistanceTo,
        "orderByFrom": true,
      };

      debugPrint('[Transit API] POST transit/find-bus: $body');
      final response = await _dio.post("transit/find-bus", data: body);
      debugPrint(
        '[Transit API] Status: ${response.statusCode}, count: ${(response.data as List?)?.length}',
      );

      if (response.data != null && response.data is List) {
        return (response.data as List)
            .map((e) => ItineraireModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return null;
    } catch (e) {
      debugPrint('[Transit API] Exception find-bus: $e');
      return null;
    }
  }
}
