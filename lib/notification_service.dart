import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Stream to broadcast notification taps with their payload (medication ID)
  final StreamController<String?> _onNotificationTap = StreamController<String?>.broadcast();
  Stream<String?> get onNotificationTap => _onNotificationTap.stream;

  Future<void> init() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('launcher_icon');
    const InitializationSettings settings = InitializationSettings(android: androidSettings);
    
    try {
      await _notificationsPlugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _onNotificationTap.add(response.payload);
        },
      );
    } catch (e) {
      print("Notification initialization failed: $e");
    }
  }

  Future<void> requestPermissions() async {
    await Permission.notification.request();
  }

  Future<void> showTestNotification({
    required String title, 
    required String body,
    required String medicationId,
  }) async {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await requestPermissions();
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'medication_alerts_persistent_v7', 
      'Persistent Medication Alerts',
      channelDescription: 'Alarms that stay until interacted with',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: true,
      autoCancel: false,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    try {
      await _notificationsPlugin.show(
        1, // Use a fixed ID so we can cancel it later if needed
        title,
        body,
        details,
        payload: medicationId, // Pass the medication ID as payload
      );
    } catch (e) {
      print("Error showing notification: $e");
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }
}
