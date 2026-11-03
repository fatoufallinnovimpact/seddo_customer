import 'dart:async';
import 'package:seddo/features/ride/domain/models/ride_live_update_data.dart';

/// Abstract service interface defining the contract for platform-native
/// live updates (iOS ActivityKit Live Activities and Android 16 ProgressStyle).
/// Follows Clean Architecture by isolating native implementation details
/// (MethodChannels, system APIs) from the domain & presentation layers.
abstract class RideLiveUpdateService {
  /// Checks whether the current operating system and hardware support live updates:
  /// - iOS: requires iOS 16.1+ and ActivityKit enabled
  /// - Android: returns true if notification support is active
  Future<bool> isSupported();

  /// Checks whether the user has granted permission and has not toggled off
  /// Live Activities / Promoted Notifications in system settings.
  Future<bool> areActivitiesEnabled();

  /// Starts a new live activity / live update for an active ride.
  /// Returns the unique native activity ID if created, or null.
  Future<String?> startLiveUpdate(RideLiveUpdateData data);

  /// Updates the dynamic content state of an ongoing activity (ETA, status, progress).
  Future<void> updateLiveUpdate(RideLiveUpdateData data);

  /// Ends and dismisses the live activity / notification from the lock screen.
  Future<void> endLiveUpdate({
    required String rideId,
    RideLiveUpdateData? finalData,
  });

  /// Stream emitting native APNs push tokens for ongoing activities (iOS).
  Stream<String> get activityPushTokenStream;

  /// Stream emitting push-to-start tokens (iOS 17.2+).
  Stream<String> get pushToStartTokenStream;

  /// Releases resources, timers or event listeners.
  void dispose();
}
