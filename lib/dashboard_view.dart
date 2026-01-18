import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Add logic for navigation or actions here
    if (index == 0) {
      // View History logic
    } else if (index == 1) {
      // Add Medication logic
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (userSnapshot.hasError) {
            return const Center(child: Text("Something went wrong"));
          }

          final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
          final String userName = userData?['name'] ?? 'User';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeHeader(userName),
                const SizedBox(height: 25),
                _buildMedicationList(user?.uid),
                const SizedBox(height: 25),
                // Sign out button
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Add Medication',
          ),
        ],
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

  Widget _buildMedicationList(String? userId) {
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('medications')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Text("Error loading medications");
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text(
                "No medications found. Add a medication to get started.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final medData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return _buildMedicationCard(medData);
          },
        );
      },
    );
  }

  Widget _buildMedicationCard(Map<String, dynamic> data) {
    final String name = data['name'] ?? 'Unknown Medication';
    final String dosage = data['dosage'] ?? '';
    final String time = data['time'] ?? 'No time set';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueAccent.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(color: Colors.white, fontSize: 18)),
                if (dosage.isNotEmpty)
                  Text(dosage,
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                const SizedBox(height: 5),
                Text(time,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Icon(Icons.medication, color: Colors.white, size: 40),
        ],
      ),
    );
  }
}
