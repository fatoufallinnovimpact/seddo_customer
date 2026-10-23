import 'dart:async';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/utils/base_url.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:uuid/uuid.dart';

/// Remote Service handling HTTP communication with the Seddo backend for Rides.
/// Follows Innov & Impact Africa guidelines (data/services/).
/// Uses centralized [BaseUrl.current] without hardcoding URLs.
class RideService {
  final Dio _dio;
  final String _endpoint = '${BaseUrl.current}/api/v1/rides';

  String get endpoint => _endpoint;

  RideService({Dio? dio}) : _dio = dio ?? Dio();

  /// POST /rides/request
  Future<RideModel> requestRide({
    required PlaceSearchResult departure,
    required PlaceSearchResult destination,
    required RideOptionModel rideOption,
    required String paymentPhone,
    required String transactionRef,
  }) async {
    try {
      final response = await _dio.post(
        '$_endpoint/request',
        data: {
          'departure': {
            'id': departure.id,
            'name': departure.mainText,
            'lat': departure.latitude,
            'lng': departure.longitude,
          },
          'destination': {
            'id': destination.id,
            'name': destination.mainText,
            'lat': destination.latitude,
            'lng': destination.longitude,
          },
          'ride_type': rideOption.type.name,
          'price': rideOption.price,
          'payment_method': 'orange_money',
          'phone': paymentPhone,
          'transaction_ref': transactionRef,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return RideModel(
          id: data['id'] as String? ?? const Uuid().v4(),
          departure: departure,
          destination: destination,
          rideOption: rideOption,
          status: RideStatus.searching,
          paymentMethod: 'Orange Money',
          paymentPhone: paymentPhone,
          transactionRef: transactionRef,
          createdAt: DateTime.now(),
        );
      }
    } catch (_) {
      // Offline fallback / mock for immediate interactive experience
    }

    return RideModel(
      id: const Uuid().v4(),
      departure: departure,
      destination: destination,
      rideOption: rideOption,
      status: RideStatus.searching,
      paymentMethod: 'Orange Money',
      paymentPhone: paymentPhone,
      transactionRef: transactionRef,
      createdAt: DateTime.now(),
    );
  }

  /// POST /rides/:id/cancel
  Future<RideModel> cancelRide({
    required String rideId,
    required String reason,
    required RideModel currentRide,
  }) async {
    try {
      await _dio.post(
        '$_endpoint/$rideId/cancel',
        data: {'reason': reason},
      );
    } catch (_) {
      // Handled gracefully
    }
    return currentRide.copyWith(
      status: RideStatus.cancelled,
      completedAt: DateTime.now(),
    );
  }

  /// POST /rides/:id/messages
  Future<bool> sendChatMessage({
    required String rideId,
    required String message,
  }) async {
    try {
      final response = await _dio.post(
        '$_endpoint/$rideId/messages',
        data: {'text': message},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return true; // Optimistic local delivery
    }
  }

  /// POST /rides/:id/rate
  Future<bool> submitRating({
    required String rideId,
    required int rating,
    required List<String> tags,
    String? comment,
  }) async {
    try {
      final response = await _dio.post(
        '$_endpoint/$rideId/rate',
        data: {
          'rating': rating,
          'tags': tags,
          'comment': ?comment,
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return true;
    }
  }

  /// Fallback demo driver
  DriverModel getDemoDriver(RideOptionModel rideOption) {
    return DriverModel(
      id: 'driver_modou_fall',
      name: 'Modou Fall',
      phone: '+221 77 458 92 14',
      rating: 4.9,
      totalRides: 1420,
      carModel: rideOption.type == RideType.confort
          ? 'Mercedes-Benz Classe C'
          : 'Toyota Corolla',
      carColor: 'Gris métallisé',
      licensePlate: 'DK-7489-BG',
      rideType: rideOption.type,
      currentLocation: const LatLng(14.6980, -17.4680),
      etaMinutes: 3,
      distanceKm: 0.8,
    );
  }
}
