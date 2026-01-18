import 'package:flutter/material.dart';
import 'package:pillgrimage/create_account_view.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      title: 'pillgrimage',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const CreateAccountView(), // i change here to register view
    ),
  );
}
