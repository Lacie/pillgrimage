import 'dart:async';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pillgrimage/medication_service.dart';
import 'package:pillgrimage/notification_service.dart';
import 'package:pillgrimage/splash.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAuth.instance.setSettings(
    appVerificationDisabledForTesting: true,
  );

  // Initialize notifications
  await NotificationService().init();

  // Periodically check for overdue medications
  Timer.periodic(const Duration(hours: 1), (timer) {
    MedicationService.checkOverdueMedications();
  });

  runApp(
    MaterialApp(
      title: 'pillgrimage',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const SplashPage(),
    ),
  );
}
