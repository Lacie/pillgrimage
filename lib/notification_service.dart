import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pillgrimage/send_grid_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final SendGridService _sendGridService = SendGridService();

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
      icon: 'launcher_icon',
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    try {
      await _notificationsPlugin.show(
        1,
        title,
        body,
        details,
        payload: medicationId,
      );
    } catch (e) {
      print("Error showing notification: $e");
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> sendCaretakerNotification(String medicationName, String patientName, String caretakerEmail) async {
    final String subject = 'Overdue Medication Alert for $patientName';
    final String textContent =
        'This is an automated message to inform you that $patientName has missed a scheduled dose of $medicationName and is now 2 hours overdue.';

    try {
      await _sendGridService.sendEmail(
        toEmail: caretakerEmail,
        subject: subject,
        textContent: textContent,
      );
      print('Caretaker notification sent for $medicationName.');
    } catch (e) {
      print('Error sending caretaker notification: $e');
    }
  }
}
