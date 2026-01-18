import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pillgrimage/dashboard_view.dart';

class CreateAccountView extends StatefulWidget {
  const CreateAccountView({super.key});

  @override
  State<CreateAccountView> createState() => _CreateAccountState();
}

class _CreateAccountState extends State<CreateAccountView> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  InputDecoration _inputStyle(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.blue),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  Future<void> _handleRegister() async {
    final email = _email.text.trim();
    final password = _password.text;
    final confirm = _confirmPassword.text;

    if (password != confirm) {
      _showSnackBar("Passwords do not match!", Colors.redAccent);
      return;
    }
    if (password.length < 6) {
      _showSnackBar("Password must be at least 6 characters", Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String uid = userCredential.user!.uid;
      final String defaultName = email.split('@').first;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'user_id': uid,
        'name': defaultName,
        'email': email,
        '__created': FieldValue.serverTimestamp(),
        '__updated': FieldValue.serverTimestamp()
      });

      if (mounted) {
        _showSnackBar("Account created successfully!", Colors.green);
        // Navigate to dashboard and remove everything from stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardView()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Auth Error', Colors.redAccent);
    } catch (e) {
      _showSnackBar("An unexpected error occurred", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Sign Up"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Get Started", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Create your pillgrimage account below", style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 32),

            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputStyle("Email Address", Icons.email_outlined),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _password,
              obscureText: _obscurePassword,
              decoration: _inputStyle(
                "Password",
                Icons.lock_outline,
                suffix: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _confirmPassword,
              obscureText: _obscurePassword,
              decoration: _inputStyle("Confirm Password", Icons.lock_reset_outlined),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SIGN UP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
