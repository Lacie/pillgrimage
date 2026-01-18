import 'package:flutter/material.dart';
import 'package:pillgrimage/userRegistration.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      title: 'pillgrimage',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const UserRegistrationView(), // i change here to register view
    ),
  );
}
