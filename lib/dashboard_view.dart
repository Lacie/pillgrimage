import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Something went wrong"));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("User data not found"));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final String userName = userData['name'] ?? 'User';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeHeader(userName),
                const SizedBox(height: 25),
                _buildUpcomingSchedule(),
                const SizedBox(height: 25),
                // Sign out button for testing
                Center(
                  child: TextButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacementNamed('/');
                      }
                    },
                    child: const Text("Sign Out", style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeHeader(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Hello, $name!",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const Text("Upcoming Medication:",
            style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildUpcomingSchedule() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        color: Colors.blueAccent.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Tylenol",
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                SizedBox(height: 5),
                Text("Jan 18, 2026 @ 5:00PM",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
