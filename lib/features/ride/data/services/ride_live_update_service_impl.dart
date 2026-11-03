import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:seddo/features/auth/data/services/device_api_service.dart';
import 'package:seddo/features/ride/domain/models/ride_live_update_data.dart';
import 'package:seddo/features/ride/domain/services/ride_live_update_service.dart';

/// Concrete implementation of [RideLiveUpdateService] using Flutter MethodChannel
/// & EventChannel to control iOS Live Activities (ActivityKit) and Android 16
/// Live Updates (Notification.ProgressStyle).
class RideLiveUpdateServiceImpl implements RideLiveUpdateService {
  static const MethodChannel _methodChannel =
      MethodChannel('sn.innov.seddo/live_updates');
  static const EventChannel _tokenChannel =
      EventChannel('sn.innov.seddo/live_updates_tokens');
  static const EventChannel _pushToStartChannel =
      EventChannel('sn.innov.seddo/live_updates_push_to_start');

  final DeviceApiService _deviceApiService;
  final StreamController<String> _activityPushTokenController =
      StreamController<String>.broadcast();
  final StreamController<String> _pushToStartTokenController =
      StreamController<String>.broadcast();

  StreamSubscription? _tokenSub;
  StreamSubscription? _pushToStartSub;
  String? _currentRideId;

  RideLiveUpdateServiceImpl({DeviceApiService? deviceApiService})
      : _deviceApiService = deviceApiService ?? DeviceApiService() {
    _initChannels();
  }

  void _initChannels() {
    final bool isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest) return;

    try {
      _tokenSub = _tokenChannel.receiveBroadcastStream().listen(
        (dynamic token) {
          if (token is String && token.isNotEmpty) {
            debugPrint('[LiveUpdates] 🔑 Reçu live activity token: $token');
            _activityPushTokenController.add(token);
            if (_currentRideId != null && _currentRideId!.isNotEmpty) {
              _deviceApiService.registerRideLiveActivityToken(
                rideId: _currentRideId!,
                liveActivityToken: token,
              );
            }
          }
        },
        onError: (err) {
          debugPrint('[LiveUpdates] Erreur flux tokens: $err');
        },
      );
    } catch (_) {}

    try {
      _pushToStartSub = _pushToStartChannel.receiveBroadcastStream().listen(
        (dynamic token) {
          if (token is String && token.isNotEmpty) {
            debugPrint('[LiveUpdates] 🔑 Reçu push-to-start token: $token');
            _pushToStartTokenController.add(token);
            _deviceApiService.registerDeviceToken(
              token: '',
              pushToStartToken: token,
            );
          }
        },
        onError: (err) {
          debugPrint('[LiveUpdates] Erreur flux push-to-start: $err');
        },
      );
    } catch (_) {}
  }

  @override
  Future<bool> isSupported() async {
    try {
      final supported =
          await _methodChannel.invokeMethod<bool>('isSupported');
      return supported ?? false;
    } catch (e) {
      debugPrint('[LiveUpdates] Note isSupported: $e');
      return false;
    }
  }

  @override
  Future<bool> areActivitiesEnabled() async {
    try {
      final enabled =
          await _methodChannel.invokeMethod<bool>('areActivitiesEnabled');
      return enabled ?? false;
    } catch (e) {
      debugPrint('[LiveUpdates] Note areActivitiesEnabled: $e');
      return false;
    }
  }

  @override
  Future<String?> startLiveUpdate(RideLiveUpdateData data) async {
    _currentRideId = data.rideId;
    try {
      final activityId = await _methodChannel.invokeMethod<String>(
        'startLiveUpdate',
        data.toMap(),
      );
      debugPrint('[LiveUpdates] Démarré avec id: $activityId');
      return activityId;
    } catch (e) {
      debugPrint('[LiveUpdates] Erreur démarrage Live Update: $e');
      return null;
    }
  }

  @override
  Future<void> updateLiveUpdate(RideLiveUpdateData data) async {
    _currentRideId = data.rideId;
    try {
      await _methodChannel.invokeMethod<void>(
        'updateLiveUpdate',
        data.toMap(),
      );
    } catch (e) {
      debugPrint('[LiveUpdates] Erreur mise à jour Live Update: $e');
    }
  }

  @override
  Future<void> endLiveUpdate({
    required String rideId,
    RideLiveUpdateData? finalData,
  }) async {
    try {
      final params = <String, dynamic>{'rideId': rideId};
      if (finalData != null) {
        params.addAll(finalData.toMap());
      }
      await _methodChannel.invokeMethod<void>('endLiveUpdate', params);
      debugPrint('[LiveUpdates] Arrêt Live Update pour course: $rideId');
    } catch (e) {
      debugPrint('[LiveUpdates] Erreur fin Live Update: $e');
    } finally {
      if (_currentRideId == rideId) {
        _currentRideId = null;
      }
    }
  }

  @override
  Stream<String> get activityPushTokenStream =>
      _activityPushTokenController.stream;

  @override
  Stream<String> get pushToStartTokenStream =>
      _pushToStartTokenController.stream;

  @override
  void dispose() {
    _tokenSub?.cancel();
    _pushToStartSub?.cancel();
    _activityPushTokenController.close();
    _pushToStartTokenController.close();
  }
}
