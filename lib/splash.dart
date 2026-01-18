import 'package:flutter/material.dart';
import 'create_account_view.dart';
import 'login_view.dart';


class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/pillgrimage_name_and_logo.png", height: 250),
            const SizedBox(height: 40),

            // Calling the helper functions
            _buildLoginButton(context),
            const SizedBox(height: 10),
            _buildSignUpButton(context),
          ],
        ),
      ),
    );
  }


  // helper function for login button ui
  Widget _buildLoginButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const LoginView(),
            ),
          );
        },
        child: const Text('LOG IN'),
      ),
    );
  }


  // helper function for sign up button ui
  Widget _buildSignUpButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.blue),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CreateAccountView(),
            ),
          );
        },
        child: const Text('SIGN UP'),
      ),
    );
  }
}