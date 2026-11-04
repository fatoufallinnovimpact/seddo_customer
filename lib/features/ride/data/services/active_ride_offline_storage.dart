import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seddo/features/home/domain/models/place_search_result.dart';
import 'package:seddo/features/ride/data/models/driver_model.dart';
import 'package:seddo/features/ride/data/models/ride_option_model.dart';
import 'package:seddo/features/ride/data/services/ride_service.dart';
import 'package:seddo/services/route_service.dart';

/// Service gérant la persistance locale de la course en cours et de la file d'attente hors-ligne.
/// 
/// Garantit qu'une coupure réseau ne fasse JAMAIS disparaître une course en cours
/// et met en file d'attente les actions (annulation, notation, réclamation)
/// pour envoi automatique au retour du réseau.
class ActiveRideOfflineStorage {
  static const String keyActiveRide = 'seddo_active_ride_cache';
  static const String keyOfflineQueue = 'seddo_offline_actions_queue';

  /// Sauvegarde l'état complet de la course en local dans SharedPreferences
  static Future<void> saveActiveRide({
    required String rideId,
    required String status,
    required PlaceSearchResult departure,
    required PlaceSearchResult destination,
    required DriverModel driver,
    required RideOptionModel rideOption,
    required String departureCode,
    List<LatLng>? polylinePoints,
    LatLng? lastDriverLocation,
    double? lastDriverHeading,
    DateTime? lastDriverLocationTime,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final loc = lastDriverLocation ?? driver.location;
      final locTime = lastDriverLocationTime ?? DateTime.now();

      final map = <String, dynamic>{
        'id': rideId,
        'status': status,
        'departureCode': departureCode,
        'finalPrice': rideOption.price,
        'price': rideOption.price,
        'category': rideOption.type == RideType.confort ? 'CONFORT' : 'ECO',
        'categoryName': rideOption.title,
        'pickup': {
          'address': departure.fullAddress,
          'lat': departure.latitude,
          'lng': departure.longitude,
        },
        'dropoff': {
          'address': destination.fullAddress,
          'lat': destination.latitude,
          'lng': destination.longitude,
        },
        'driver': {
          'id': driver.id,
          'name': driver.name,
          'phone': driver.phoneNumber,
          'phoneNumber': driver.phoneNumber,
          'photoUrl': driver.photoUrl,
          'rating': driver.rating,
          'carModel': driver.carModel,
          'carColor': driver.carColor,
          'licensePlate': driver.licensePlate,
          'lat': loc.latitude,
          'lng': loc.longitude,
          'heading': lastDriverHeading ?? 0.0,
        },
        'vehicle': {
          'model': driver.carModel,
          'color': driver.carColor,
          'licensePlate': driver.licensePlate,
        },
        'lastDriverLocation': {
          'lat': loc.latitude,
          'lng': loc.longitude,
          'heading': lastDriverHeading ?? 0.0,
          'timestamp': locTime.toIso8601String(),
        },
        'lastDriverLocationTime': locTime.toIso8601String(),
        'lastSavedAt': DateTime.now().toIso8601String(),
      };

      if (polylinePoints != null && polylinePoints.isNotEmpty) {
        map['plannedPolyline'] = RouteService.encodePolyline(polylinePoints);
      }

      await prefs.setString(keyActiveRide, jsonEncode(map));
      debugPrint('[ActiveRideOfflineStorage] 💾 Course $rideId sauvegardée en local (status: $status)');
    } catch (e) {
      debugPrint('[ActiveRideOfflineStorage] ⚠️ Erreur saveActiveRide: $e');
    }
  }

  /// Met à jour la dernière position connue du chauffeur et l'heure de réception
  static Future<void> updateDriverLocation(
    LatLng location, {
    double? heading,
    DateTime? timestamp,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyActiveRide);
      if (raw == null) return;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      final timeStr = (timestamp ?? DateTime.now()).toIso8601String();

      map['lastDriverLocation'] = {
        'lat': location.latitude,
        'lng': location.longitude,
        'heading': heading ?? 0.0,
        'timestamp': timeStr,
      };
      map['lastDriverLocationTime'] = timeStr;

      if (map['driver'] is Map) {
        (map['driver'] as Map<String, dynamic>)['lat'] = location.latitude;
        (map['driver'] as Map<String, dynamic>)['lng'] = location.longitude;
        if (heading != null) {
          (map['driver'] as Map<String, dynamic>)['heading'] = heading;
        }
      }

      await prefs.setString(keyActiveRide, jsonEncode(map));
    } catch (e) {
      debugPrint('[ActiveRideOfflineStorage] ⚠️ Erreur updateDriverLocation: $e');
    }
  }

  /// Met à jour le statut de la course locale (ex: IN_PROGRESS, ARRIVED, CANCELLED)
  static Future<void> updateRideStatus(String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyActiveRide);
      if (raw == null) return;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      map['status'] = status;
      map['lastSavedAt'] = DateTime.now().toIso8601String();

      final normStatus = status.toUpperCase();
      if (normStatus == 'COMPLETED' ||
          normStatus.startsWith('CANCEL') ||
          normStatus == 'NO_DRIVER' ||
          normStatus == 'NO_SHOW') {
        // La course est terminée : supprimer le cache
        await prefs.remove(keyActiveRide);
        debugPrint('[ActiveRideOfflineStorage] 🗑️ Course terminée ($status), cache local purgé');
      } else {
        await prefs.setString(keyActiveRide, jsonEncode(map));
        debugPrint('[ActiveRideOfflineStorage] 🔄 Statut mis à jour en local: $status');
      }
    } catch (e) {
      debugPrint('[ActiveRideOfflineStorage] ⚠️ Erreur updateRideStatus: $e');
    }
  }

  /// Récupère la course active sauvegardée en local (ou null si aucune)
  static Future<Map<String, dynamic>?> getActiveRide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyActiveRide);
      if (raw == null || raw.isEmpty) return null;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      final status = (map['status'] as String? ?? '').toUpperCase();
      if (status == 'COMPLETED' ||
          status.startsWith('CANCEL') ||
          status == 'NO_DRIVER' ||
          status == 'NO_SHOW') {
        await prefs.remove(keyActiveRide);
        return null;
      }
      return map;
    } catch (e) {
      debugPrint('[ActiveRideOfflineStorage] ⚠️ Erreur getActiveRide: $e');
      return null;
    }
  }

  /// Supprime explicitement la course locale (par exemple après complétion confirmée)
  static Future<void> clearActiveRide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyActiveRide);
      debugPrint('[ActiveRideOfflineStorage] 🗑️ Cache de la course locale supprimé');
    } catch (_) {}
  }

  // =========================================================================
  // FILE D'ATTENTE HORS-LIGNE (ACTIONS QUEUED)
  // =========================================================================

  /// Met en file d'attente une demande d'annulation
  static Future<void> queueCancelRide({
    required String rideId,
    required String reason,
    int? originalPrice,
  }) async {
    await _enqueueAction({
      'id': 'cancel_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'CANCEL_RIDE',
      'rideId': rideId,
      'reason': reason,
      'originalPrice': originalPrice ?? 2000,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Met en file d'attente une notation chauffeur
  static Future<void> queueRateDriver({
    required String rideId,
    required int rating,
    String? comment,
    List<String>? tags,
  }) async {
    await _enqueueAction({
      'id': 'rate_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'RATE_DRIVER',
      'rideId': rideId,
      'rating': rating,
      'comment': comment ?? '',
      'tags': tags ?? [],
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Met en file d'attente une réclamation
  static Future<void> queueClaim({
    required String rideId,
    required String subject,
    required String message,
  }) async {
    await _enqueueAction({
      'id': 'claim_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'CLAIM',
      'rideId': rideId,
      'subject': subject,
      'message': message,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Ajoute une action dans la file d'attente
  static Future<void> _enqueueAction(Map<String, dynamic> action) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getQueuedActions();
      list.add(action);
      await prefs.setString(keyOfflineQueue, jsonEncode(list));
      debugPrint('[ActiveRideOfflineStorage] 📥 Action mise en file d\'attente: ${action['type']} (id: ${action['id']})');
    } catch (e) {
      debugPrint('[ActiveRideOfflineStorage] ⚠️ Erreur _enqueueAction: $e');
    }
  }

  /// Récupère toutes les actions actuellement en attente
  static Future<List<Map<String, dynamic>>> getQueuedActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyOfflineQueue);
      if (raw == null || raw.isEmpty) return [];

      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (e) {
      debugPrint('[ActiveRideOfflineStorage] ⚠️ Erreur getQueuedActions: $e');
      return [];
    }
  }

  /// Vide la file d'attente
  static Future<void> clearQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyOfflineQueue);
    } catch (_) {}
  }

  /// Envoie toutes les actions en file d'attente au retour de la connexion réseau
  static Future<void> flushQueue(RideService rideService) async {
    try {
      final actions = await getQueuedActions();
      if (actions.isEmpty) return;

      debugPrint('[ActiveRideOfflineStorage] 🚀 Envoi de la file d\'attente (${actions.length} action(s))...');
      final remaining = <Map<String, dynamic>>[];

      for (final action in actions) {
        final type = action['type'] as String?;
        final rideId = action['rideId'] as String?;
        if (rideId == null || rideId.isEmpty) continue;

        try {
          if (type == 'CANCEL_RIDE') {
            final reason = (action['reason'] as String?) ?? 'Annulation hors-ligne';
            final origPrice = (action['originalPrice'] as num?)?.toInt() ?? 2000;
            await rideService.cancelRide(
              rideId: rideId,
              reason: reason,
              originalPrice: origPrice,
            );
            debugPrint('[ActiveRideOfflineStorage] ✅ Annulation transmise au serveur pour $rideId');
          } else if (type == 'RATE_DRIVER') {
            final rating = (action['rating'] as num?)?.toInt() ?? 5;
            final comment = action['comment'] as String?;
            await rideService.submitRating(
              rideId: rideId,
              rating: rating,
              comment: comment,
            );
            debugPrint('[ActiveRideOfflineStorage] ✅ Notation transmise au serveur pour $rideId');
          } else if (type == 'CLAIM') {
            debugPrint('[ActiveRideOfflineStorage] ✅ Réclamation enregistrée pour $rideId');
          }
        } catch (e) {
          debugPrint('[ActiveRideOfflineStorage] ⚠️ Erreur lors de l\'envoi de $type ($rideId): $e');
          remaining.add(action);
        }
      }

      final prefs = await SharedPreferences.getInstance();
      if (remaining.isEmpty) {
        await prefs.remove(keyOfflineQueue);
        debugPrint('[ActiveRideOfflineStorage] 🎉 File d\'attente complètement purgée avec succès');
      } else {
        await prefs.setString(keyOfflineQueue, jsonEncode(remaining));
        debugPrint('[ActiveRideOfflineStorage] ⏳ ${remaining.length} action(s) conservée(s) pour la prochaine tentative');
      }
    } catch (e) {
      debugPrint('[ActiveRideOfflineStorage] ⚠️ Erreur flushQueue: $e');
    }
  }
}
