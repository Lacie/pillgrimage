import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import "package:firebase_auth/firebase_auth.dart";
import 'firebase_options.dart';

class CreateAccountView extends StatefulWidget {
  const CreateAccountView({super.key});

  @override
  State<CreateAccountView> createState() => _CreateAccountState();
}

class _CreateAccountState extends State<CreateAccountView> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  // State variable to toggle password visibility
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: FutureBuilder(
          future: Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ),
          builder: (context, snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.done:
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _email,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: "Email",
                        ),
                      ),
                      TextField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: "Password",
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      TextField(
                        controller: _confirmPassword,
                        obscureText: _obscurePassword,
                        decoration: const InputDecoration(
                          hintText: "Confirm Password",
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () async {
                          final email = _email.text.trim();
                          final password = _password.text;
                          final confirmPassword = _confirmPassword.text;

                          // 1. Check if passwords match before calling Firebase
                          if (password != confirmPassword) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Passwords do not match!")),
                            );
                            return;
                          }

                          try {
                            await FirebaseAuth.instance.createUserWithEmailAndPassword(
                              email: email,
                              password: password,
                            );
                            // SUCCESS: Navigate away or show success message here
                          } on FirebaseAuthException catch (e) {
                            // 2. Handle specific Firebase Auth Errors
                            String errorMessage = 'An error occurred';

                            if (e.code == 'weak-password') {
                              errorMessage = 'The password is too weak.';
                            } else if (e.code == 'email-already-in-use') {
                              errorMessage = 'Account already exists for this email.';
                            } else if (e.code == 'invalid-email') {
                              errorMessage = 'The email address is invalid.';
                            } else {
                              errorMessage = e.message ?? 'Unknown error';
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errorMessage),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          } catch (e) {
                            // Catch any other non-Firebase errors
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                        child: const Text("Create Account"),
                      ),
                    ],
                  ),
                );
              default:
                return const Center(child: CircularProgressIndicator());
            }
          }),
    );
  }
}
