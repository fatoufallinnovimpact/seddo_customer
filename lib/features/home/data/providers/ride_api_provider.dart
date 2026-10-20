import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/features/home/domain/models/driver_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/home/domain/models/ride_model.dart';
import 'package:seddo/features/home/domain/models/ride_option_model.dart';
import 'package:uuid/uuid.dart';

/// Provider handling HTTP and WebSocket communication with the Seddo backend
class RideApiProvider {
  final Dio _dio;
  final String baseUrl;

  RideApiProvider({
    Dio? dio,
    this.baseUrl = const String.fromEnvironment(
      'SEDDO_API_BASE_URL',
      defaultValue: 'https://api.seddo.sn/api/v1',
    ),
  }) : _dio = dio ?? Dio();

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
        '$baseUrl/rides/request',
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
        // Parse backend payload
        final data = response.data as Map<String, dynamic>;
        return RideModel(
          id: data['id']?.toString() ?? const Uuid().v4(),
          departure: departure,
          destination: destination,
          rideOption: rideOption,
          status: RideStatus.searching,
          paymentPhone: paymentPhone,
          transactionRef: transactionRef,
          createdAt: DateTime.now(),
        );
      }
    } catch (_) {
      // Backend fallback simulation
    }

    return RideModel(
      id: 'ride_${const Uuid().v4().substring(0, 8)}',
      departure: departure,
      destination: destination,
      rideOption: rideOption,
      status: RideStatus.searching,
      paymentPhone: paymentPhone,
      transactionRef: transactionRef,
      createdAt: DateTime.now(),
    );
  }

  /// POST /rides/{id}/cancel
  Future<RideModel> cancelRide({
    required String rideId,
    required String reason,
    required RideModel currentRide,
  }) async {
    try {
      await _dio.post(
        '$baseUrl/rides/$rideId/cancel',
        data: {'reason': reason},
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
    } catch (_) {}

    return currentRide.copyWith(
      status: RideStatus.cancelled,
      completedAt: DateTime.now(),
    );
  }

  /// POST /rides/{id}/messages
  Future<bool> sendChatMessage({
    required String rideId,
    required String message,
  }) async {
    try {
      final response = await _dio.post(
        '$baseUrl/rides/$rideId/messages',
        data: {'message': message},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return true;
    }
  }

  /// POST /rides/{id}/rating
  Future<bool> submitRating({
    required String rideId,
    required int rating,
    required List<String> tags,
    String? comment,
  }) async {
    try {
      final response = await _dio.post(
        '$baseUrl/rides/$rideId/rating',
        data: {
          'rating': rating,
          'tags': tags,
          'comment': comment,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return true;
    }
  }

  /// Driver mock generator for development & integration
  DriverModel getMockDriver(RideType rideType, LatLng origin) {
    return DriverModel.mockDakarDriver(
      rideType: rideType,
      location: LatLng(
        origin.latitude + 0.0035,
        origin.longitude + 0.0030,
      ),
    );
  }
}
