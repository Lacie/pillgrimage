import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
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
