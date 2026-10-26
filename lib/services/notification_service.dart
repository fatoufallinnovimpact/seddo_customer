import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service managing high-priority local and background push notifications.
/// Matches behavior of ride apps like Yango and Uber:
/// - Appears in status bar (heads-up banner).
/// - Displays on lockscreen when phone is locked (`NotificationVisibility.public`).
/// - Alerts the user in background when driver accepts, approaches, arrives, or finishes ride.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  bool get _isTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  /// High priority channel ID for ongoing active rides
  static const String rideChannelId = 'seddo_ride_status_channel';
  static const String rideChannelName = 'Suivi de course Seddo';
  static const String rideChannelDescription =
      'Notifications prioritaires pour les courses en cours (chauffeur en route, arrivée, etc.)';

  /// General notifications channel ID
  static const String generalChannelId = 'seddo_general_channel';
  static const String generalChannelName = 'Seddo Notifications';
  static const String generalChannelDescription =
      'Informations et alertes générales Seddo';

  /// Initialize local notification plugins and create Android notification channels
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_isTest) {
      _isInitialized = true;
      return;
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create high priority channel on Android with public lockscreen visibility
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidImpl != null) {
          await androidImpl.createNotificationChannel(
            const AndroidNotificationChannel(
              rideChannelId,
              rideChannelName,
              description: rideChannelDescription,
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
              showBadge: true,
            ),
          );

          // Request runtime notification permission on Android 13+ (API 33+)
          await androidImpl.requestNotificationsPermission();
        }
      }

      // Request permissions on iOS
      if (!kIsWeb && Platform.isIOS) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('[NotificationService] Initialization error: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[NotificationService] Tapped payload: ${response.payload}');
  }

  /// Base notification details for heads-up + lockscreen visibility
  NotificationDetails _buildRideNotificationDetails({
    bool isOngoing = false,
  }) {
    final androidDetails = AndroidNotificationDetails(
      rideChannelId,
      rideChannelName,
      channelDescription: rideChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public, // Visible when screen is locked
      playSound: true,
      enableVibration: true,
      ongoing: isOngoing,
      autoCancel: !isOngoing,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.status,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );
  }

  Future<void> _safeShow({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    if (_isTest) {
      debugPrint('[NotificationService][Test] $title: $body');
      return;
    }
    await initialize();
    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[NotificationService] show error: $e');
    }
  }

  /// Show notification when driver accepts ride and is en route (Yango-style)
  Future<void> showDriverAcceptedNotification({
    required String driverName,
    required String carModel,
    required String eta,
    String? departureCode,
  }) async {
    final codeText = departureCode != null ? ' • Code: $departureCode' : '';
    await _safeShow(
      id: 1001,
      title: '🚗 Chauffeur en route ($eta)',
      body: '$driverName arrive en $carModel.$codeText Rendez-vous au point de départ.',
      notificationDetails: _buildRideNotificationDetails(),
      payload: 'driver_approaching',
    );
  }

  /// Show notification when driver arrives at pickup point
  Future<void> showDriverArrivedNotification({
    required String driverName,
    required String departureCode,
  }) async {
    await _safeShow(
      id: 1002,
      title: '📍 Votre chauffeur est arrivé !',
      body: '$driverName vous attend au point de départ. Donnez le code $departureCode pour démarrer.',
      notificationDetails: _buildRideNotificationDetails(),
      payload: 'driver_arrived',
    );
  }

  /// Show notification when trip has started towards destination
  Future<void> showRideStartedNotification({
    required String destinationName,
    required String eta,
  }) async {
    await _safeShow(
      id: 1003,
      title: '🛣️ Course en cours vers $destinationName',
      body: 'Arrivée estimée dans $eta. Bon trajet avec Seddo !',
      notificationDetails: _buildRideNotificationDetails(isOngoing: true),
      payload: 'ride_active',
    );
  }

  /// Show notification when trip has arrived at destination
  Future<void> showRideCompletedNotification({
    required String destinationName,
    required int price,
  }) async {
    // Cancel any active ongoing ride notification first
    await cancelNotification(1003);

    await _safeShow(
      id: 1004,
      title: '✅ Vous êtes arrivé à destination !',
      body: 'Votre trajet vers $destinationName est terminé. Montant : $price F CFA.',
      notificationDetails: _buildRideNotificationDetails(isOngoing: false),
      payload: 'ride_completed',
    );
  }

  /// Cancel specific notification by id
  Future<void> cancelNotification(int id) async {
    if (_isTest) return;
    try {
      await _notificationsPlugin.cancel(id: id);
    } catch (_) {}
  }

  /// Cancel all active notifications
  Future<void> cancelAll() async {
    if (_isTest) return;
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }
}
