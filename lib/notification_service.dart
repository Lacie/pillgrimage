import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pillgrimage/medication_model.dart';
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
      if (kDebugMode) {
        print("Notification initialization failed: $e");
      }
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
      if (kDebugMode) {
        print("Error showing notification: $e");
      }
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> sendCaretakerNotification({
    required String medicationName,
    required String patientName,
    required String caretakerEmail,
    required Medication medication,
  }) async {
    final String subject = 'Overdue Medication Alert for $patientName';

    try {
      String htmlContent = await rootBundle.loadString('assets/email_notif.html');
      htmlContent = htmlContent.replaceAll('[User]', patientName);
      htmlContent = htmlContent.replaceAll('[Medication Name]', medicationName);
      htmlContent = htmlContent.replaceAll('[Appointment Time]', medication.nextScheduledUtc.toString());

      await _sendGridService.sendEmail(
        toEmail: caretakerEmail,
        subject: subject,
        htmlContent: htmlContent,
      );
      if (kDebugMode) {
        print('Caretaker notification sent for $medicationName.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending caretaker notification: $e');
      }
    }
  }
}
