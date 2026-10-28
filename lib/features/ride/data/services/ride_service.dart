import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seddo/core/network/api_client.dart';
import 'package:seddo/core/utils/api_endpoints.dart';
import 'package:seddo/core/utils/base_url.dart';
import 'package:seddo/features/home/data/models/home_suggestions_model.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/chat_message_model.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/nearby_drivers_response_model.dart';
import 'package:seddo/features/ride/data/models/ride_cancel_result_model.dart';
import 'package:seddo/features/ride/data/models/ride_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/models/ride_quote_model.dart';
import 'package:uuid/uuid.dart';

/// Remote Service handling HTTP communication with the Seddo backend for Rides.
/// Follows Innov & Impact Africa guidelines (data/services/).
/// Uses centralized [BaseUrl.current] without hardcoding URLs.
class RideService {
  final Dio _dio;
  final String _endpoint = '${BaseUrl.current}/v1/rides';

  /// Identifiant de la dernière course créée ou restaurée
  static String? lastCreatedRideId;

  String get endpoint => _endpoint;

  RideService({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  /// POST /v1/rides/quote
  /// Request a quote for category pricing and real road polyline from the backend.
  Future<RideQuoteModel?> getQuote({
    required PlaceSearchResult departure,
    required PlaceSearchResult destination,
    String? pickupNote,
  }) async {
    try {
      final pickupAddress = departure.fullAddress.isNotEmpty
          ? departure.fullAddress
          : (departure.mainText.isNotEmpty ? departure.mainText : 'Départ');
      final dropoffAddress = destination.fullAddress.isNotEmpty
          ? destination.fullAddress
          : (destination.mainText.isNotEmpty ? destination.mainText : 'Arrivée');

      final body = {
        'pickup': {
          'lat': departure.latitude,
          'lng': departure.longitude,
          'address': pickupAddress,
        },
        'dropoff': {
          'lat': destination.latitude,
          'lng': destination.longitude,
          'address': dropoffAddress,
        },
        if (pickupNote != null && pickupNote.trim().isNotEmpty)
          'pickupNote': pickupNote.trim(),
      };

      debugPrint('[RideQuote] 🚀 POST ${ApiEndpoints.ridesQuote}');

      final response = await _dio.post(
        ApiEndpoints.ridesQuote,
        data: body,
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;
        final model = RideQuoteModel.fromJson(data);
        debugPrint(
            '[RideQuote] ✅ 200 OK de l\'API : Prix Eco = ${model.ecoOption?.price} FCFA, quoteId = ${model.ecoOption?.quoteId}, distance = ${model.distanceKm} km');
        return model;
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint(
            '[RideQuote] ⚠️ Erreur API quote [${e.response?.statusCode}]: ${e.response?.data}');
      } else {
        debugPrint('[RideQuote] ⚠️ Erreur inattendue: $e');
      }
    }
    return null;
  }

  /// POST /v1/rides
  /// Commander : crée la course depuis un devis et lance le paiement Orange Money.
  /// Renvoie la course (PAYMENT_PENDING) avec payment.paymentUrl (app) et payment.payToken (Max it).
  Future<Map<String, dynamic>?> createRide({
    required String quoteId,
  }) async {
    try {
      debugPrint('[RideService] 🚀 POST ${ApiEndpoints.rides} avec quoteId: $quoteId');
      final response = await _dio.post(
        ApiEndpoints.rides,
        data: {'quoteId': quoteId},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      debugPrint(
          '[RideService] ✅ POST /v1/rides code ${response.statusCode}: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;
        final rideId = data['id']?.toString();
        if (rideId != null && rideId.isNotEmpty) {
          lastCreatedRideId = rideId;
        }
        return data;
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint(
            '[RideService] ⚠️ Erreur POST /v1/rides [${e.response?.statusCode}]: ${e.response?.data}');
      } else {
        debugPrint('[RideService] ⚠️ Erreur inattendue POST /v1/rides: $e');
      }
    }
    return null;
  }

  /// POST /v1/dev/orange-money/{orderId}/pay
  /// Simule le paiement dans Max it (outcome: SUCCESS, INSUFFICIENT_FUNDS, WRONG_PIN, CANCELLED)
  Future<bool> simulateDevPayment({
    required String orderId,
    String outcome = 'SUCCESS',
    bool notify = true,
  }) async {
    try {
      final url = '${BaseUrl.current}/v1/dev/orange-money/$orderId/pay';
      debugPrint('[RideService] 🚀 Simulation paiement OM: POST $url ($outcome)');
      final response = await _dio.post(
        url,
        data: {
          'outcome': outcome,
          'notify': notify,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      debugPrint('[RideService] ✅ Résultat simulation OM: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[RideService] ⚠️ Échec simulation OM: $e');
      return false;
    }
  }

  /// POST /rides/request
  Future<RideModel> requestRide({
    required PlaceSearchResult departure,
    required PlaceSearchResult destination,
    required RideOptionModel rideOption,
    required String paymentPhone,
    required String transactionRef,
  }) async {
    try {
      final targetUrl = (rideOption.quoteId != null && rideOption.quoteId!.isNotEmpty)
          ? _endpoint
          : '$_endpoint/request';
      final payload = (rideOption.quoteId != null && rideOption.quoteId!.isNotEmpty)
          ? {'quoteId': rideOption.quoteId}
          : {
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
            };

      final response = await _dio.post(
        targetUrl,
        data: payload,
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
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

  /// POST /v1/rides/{id}/cancel
  /// Annulation. Client : gratuite avant acceptation et 2 min après, frais ensuite ;
  /// renvoie les frais et le montant remboursé.
  Future<RideCancelResultModel> cancelRide({
    required String rideId,
    String reason = 'Le chauffeur est trop loin',
    num? originalPrice,
    RideModel? currentRide,
  }) async {
    final cleanReason = reason.trim().isNotEmpty
        ? reason.trim()
        : 'Le chauffeur est trop loin';
    final url = ApiEndpoints.rideCancel(rideId);
    debugPrint('[RideService] 🚀 POST $url avec reason: "$cleanReason"');

    try {
      final response = await _dio.post(
        url,
        data: {'reason': cleanReason},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      debugPrint(
          '[RideService] ✅ POST $url code ${response.statusCode}: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : (response.data is Map<String, dynamic>
                ? response.data as Map<String, dynamic>
                : <String, dynamic>{});

        final result =
            RideCancelResultModel.fromJson(data, defaultReason: cleanReason);

        // Si le montant remboursé n'est pas spécifié dans la réponse mais qu'on a le prix initial
        final effectiveOriginalPrice =
            originalPrice ?? currentRide?.rideOption.price;
        if (result.refundAmount == 0 &&
            effectiveOriginalPrice != null &&
            effectiveOriginalPrice > 0) {
          final computedRefund =
              (effectiveOriginalPrice - result.fee).clamp(0, effectiveOriginalPrice);
          return RideCancelResultModel(
            isSuccess: true,
            fee: result.fee,
            refundAmount: computedRefund,
            reason: result.reason,
            status: result.status,
            message: result.message,
            raw: data,
          );
        }
        return result;
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint(
            '[RideService] ⚠️ Erreur POST $url [${e.response?.statusCode}]: ${e.response?.data}');
      } else {
        debugPrint('[RideService] ⚠️ Erreur inattendue POST $url: $e');
      }
    }

    // Fallback gracieux en cas de mode hors-ligne ou simulation locale
    return RideCancelResultModel.fallback(
      originalPrice:
          originalPrice ?? currentRide?.rideOption.price ?? 0,
      reason: cleanReason,
    );
  }

  /// GET /v1/rides/{id}/messages
  /// Messages du chat de la course (Client ↔ chauffeur).
  Future<List<ChatMessageModel>> getChatMessages({
    required String rideId,
  }) async {
    try {
      final url = ApiEndpoints.rideMessages(rideId);
      debugPrint('[RideService] 🚀 GET $url');
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data != null) {
        final dynamic raw = response.data is String
            ? jsonDecode(response.data as String)
            : response.data;
        final List rawList = raw is List
            ? raw
            : (raw is Map && (raw['messages'] is List || raw['data'] is List))
                ? (raw['messages'] ?? raw['data']) as List
                : [];

        final list = rawList
            .whereType<Map<String, dynamic>>()
            .map((item) => ChatMessageModel.fromJson(item))
            .toList();

        debugPrint('[RideService] ✅ GET $url : ${list.length} message(s)');
        return list;
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint(
            '[RideService] ⚠️ Erreur GET messages [${e.response?.statusCode}]: ${e.response?.data}');
      } else {
        debugPrint('[RideService] ⚠️ Erreur inattendue GET messages: $e');
      }
    }
    return [];
  }

  /// POST /v1/rides/{id}/messages
  /// Chat client ↔ chauffeur (événement temps réel chat.message pour l'autre partie).
  /// Request body: { "body": "Je suis devant la pharmacie" } -> Status 201
  Future<bool> sendChatMessage({
    required String rideId,
    required String message,
  }) async {
    try {
      final clean = message.trim();
      if (clean.isEmpty) return false;

      final url = ApiEndpoints.rideMessages(rideId);
      debugPrint('[RideService] 🚀 POST $url avec body: "$clean"');

      final response = await _dio.post(
        url,
        data: {'body': clean},
      );

      final success = response.statusCode == 200 || response.statusCode == 201;
      debugPrint(
          '[RideService] ${success ? "✅" : "⚠️"} POST $url : code ${response.statusCode}');
      return success;
    } catch (e) {
      if (e is DioException) {
        debugPrint(
            '[RideService] ⚠️ Erreur POST messages [${e.response?.statusCode}]: ${e.response?.data}');
      } else {
        debugPrint('[RideService] ⚠️ Erreur inattendue POST messages: $e');
      }
      return false;
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

  /// GET /v1/drivers/nearby?lat={lat}&lng={lng}
  /// Accueil client & recherche : voitures disponibles autour (positions arrondies, anonymes) et temps d'approche.
  Future<NearbyDriversResponseModel?> getNearbyDrivers({
    required double lat,
    required double lng,
  }) async {
    try {
      debugPrint(
          '[RideService] 🚀 GET ${ApiEndpoints.driversNearby}?lat=$lat&lng=$lng');
      final response = await _dio.get(
        ApiEndpoints.driversNearby,
        queryParameters: {
          'lat': lat,
          'lng': lng,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;
        final model = NearbyDriversResponseModel.fromJson(data);
        debugPrint(
            '[RideService] ✅ Nearby drivers reçus: Eco=${model.ecoCount}, Confort=${model.confortCount}, Total voitures=${model.allCars.length}');
        return model;
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint(
            '[RideService] ⚠️ Erreur GET /v1/drivers/nearby [${e.response?.statusCode}]: ${e.response?.data}');
      } else {
        debugPrint('[RideService] ⚠️ Erreur inattendue GET nearby: $e');
      }
    }
    return null;
  }

  /// GET /v1/users/me/suggestions
  /// Suggestions de l'accueil : lieux enregistrés et destinations récentes.
  Future<HomeSuggestionsModel?> getSuggestions() async {
    try {
      debugPrint('[RideService] 🚀 GET ${ApiEndpoints.userSuggestions}');
      final response = await _dio.get(
        ApiEndpoints.userSuggestions,
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;
        final model = HomeSuggestionsModel.fromJson(data);
        debugPrint(
            '[RideService] ✅ Suggestions reçues: ${model.places.length} lieux enregistrés, ${model.recent.length} récents');
        return model;
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint(
            '[RideService] ⚠️ Erreur GET /v1/users/me/suggestions [${e.response?.statusCode}]: ${e.response?.data}');
      } else {
        debugPrint('[RideService] ⚠️ Erreur inattendue GET suggestions: $e');
      }
    }
    return null;
  }

  /// GET /v1/rides/current
  /// Course en cours de l’appelant (client ou chauffeur), ou ride: null : à appeler au démarrage de l’app.
  Future<Map<String, dynamic>?> getCurrentRide() async {
    try {
      debugPrint('[RideService] 🚀 GET ${ApiEndpoints.ridesCurrent}');
      final response = await _dio.get(
        ApiEndpoints.ridesCurrent,
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;
        debugPrint('[RideService] ✅ Current ride reçu: ${data['ride'] != null ? 'Course active ID ${data['ride']['id']}' : 'Aucune course en cours (ride: null)'}');
        return data;
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint(
            '[RideService] ⚠️ Erreur GET /v1/rides/current [${e.response?.statusCode}]: ${e.response?.data}');
      } else {
        debugPrint('[RideService] ⚠️ Erreur inattendue GET /v1/rides/current: $e');
      }
    }
    return null;
  }

  /// GET /v1/rides/{id}
  /// Détail d’une course : vue client (chauffeur, code de départ, paiement, remboursement) ou vue chauffeur (gain net).
  Future<Map<String, dynamic>?> getRideDetails(String id) async {
    try {
      final url = ApiEndpoints.rideDetails(id);
      debugPrint('[RideService] 🚀 GET $url');
      final response = await _dio.get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;
        debugPrint(
            '[RideService] ✅ Détail de la course reçu: id=$id, status=${data['status']}, code=${data['code'] ?? data['startCode'] ?? data['departureCode']}');
        return data;
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint(
            '[RideService] ⚠️ Erreur GET /v1/rides/$id [${e.response?.statusCode}]: ${e.response?.data}');
      } else {
        debugPrint('[RideService] ⚠️ Erreur inattendue GET /v1/rides/$id: $e');
      }
    }
    return null;
  }
}

