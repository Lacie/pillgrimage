import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pillgrimage/login_view.dart';
import 'package:pillgrimage/medication_service.dart';
import 'package:pillgrimage/medication_widgets.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  Future<void> _handleReset(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset History?"),
        content: const Text(
            "This will delete all your medication logs and reset your last taken records. This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Reset Everything"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await MedicationService.resetUserMedicationData();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("History cleared successfully")),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginView()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Medication Log",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _handleLogout(context),
                    icon: const Icon(Icons.logout, color: Colors.grey, size: 20),
                    label: const Text("Logout", style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _handleReset(context),
                    icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 20),
                    label: const Text("Clear All", style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .collection('medication_logs')
                .orderBy('taken_at_utc', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }

              final logs = snapshot.data?.docs ?? [];

              if (logs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        "No History Yet",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Your logged doses will appear here.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: logs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final log = logs[index].data() as Map<String, dynamic>;
                  final takenAt = (log['taken_at_utc'] as Timestamp?)?.toDate();
                  final String medName = log['med_name'] ?? 'Unknown Med';
                  final String? dosage = log['dosage'];
                  
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                medName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (takenAt != null)
                                Text(
                                  formatLastTaken(takenAt),
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                        if (dosage != null)
                          Text(
                            dosage,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
