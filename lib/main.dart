import 'package:flutter/material.dart';
import 'package:pillgrimage/register_view.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      title: 'Pillgrimage',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const RegisterView(), // i change here to register view
    ),
  );
}


