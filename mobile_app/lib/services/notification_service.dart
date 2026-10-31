import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/prediction_result.dart';
import '../core/utils/sound_haptic_helper.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

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
      macOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification click if needed
      },
    );

    // Request permissions for Android 13+
    _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _isInitialized = true;
  }

  Future<void> triggerSafetyAlert({
    required SafetyStatus status,
    required String title,
    required String message,
  }) async {
    // Safety haptics & sounds (always run regardless of notification permissions)
    if (status == SafetyStatus.emergency) {
      SoundHapticHelper.triggerEmergencyFeedback();
    } else if (status == SafetyStatus.danger) {
      SoundHapticHelper.triggerDangerFeedback();
    } else if (status == SafetyStatus.warning) {
      SoundHapticHelper.triggerWarningFeedback();
    }

    if (!_isInitialized) {
      await initialize();
    }

    int id = 100;
    Importance importance = Importance.defaultImportance;
    Priority priority = Priority.defaultPriority;
    String channelId = 'worker_safety_normal';
    String channelName = 'Normal Safety Updates';

    if (status == SafetyStatus.emergency) {
      id = 999;
      importance = Importance.max;
      priority = Priority.max;
      channelId = 'worker_safety_emergency';
      channelName = 'EMERGENCY CRITICAL ALERTS';
    } else if (status == SafetyStatus.danger) {
      id = 500;
      importance = Importance.high;
      priority = Priority.high;
      channelId = 'worker_safety_danger';
      channelName = 'Danger Safety Alerts';
    } else if (status == SafetyStatus.warning) {
      id = 200;
      importance = Importance.high;
      priority = Priority.high;
      channelId = 'worker_safety_warning';
      channelName = 'Warning Notifications';
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Occupational safety and hazard alerts',
          importance: importance,
          priority: priority,
          playSound: true,
          enableVibration: true,
          fullScreenIntent: status == SafetyStatus.emergency,
        );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: message,
      notificationDetails: notificationDetails,
    );
  }
}
