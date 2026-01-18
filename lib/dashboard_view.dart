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
    if (index == 1) {
      _showAddMedicationDialog();
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<void> _showAddMedicationDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final nameController = TextEditingController();
    final doseController = TextEditingController();
    final frequencyController = TextEditingController();
    final emailController = TextEditingController();
    String selectedType = 'RX';

    final Map<String, String> typeOptions = {
      'RX': 'Prescription',
      'OTC': 'Over the counter',
    };

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Medication"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Name"),
                    ),
                    TextField(
                      controller: doseController,
                      decoration: const InputDecoration(labelText: "Dose"),
                    ),
                    TextField(
                      controller: frequencyController,
                      decoration: const InputDecoration(labelText: "Frequency (seconds)"),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: "Notification Email"),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: "Type"),
                      items: typeOptions.entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedType = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty) return;

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('medications')
                        .add({
                      '__created': FieldValue.serverTimestamp(),
                      '__updated': FieldValue.serverTimestamp(),
                      'name': nameController.text.trim(),
                      'dose': doseController.text.trim(),
                      'frequency_seconds': int.tryParse(frequencyController.text) ?? 0,
                      'notification_email': emailController.text.trim(),
                      'type': selectedType,
                    });

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
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
          .orderBy('__created', descending: true)
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
    final String dose = data['dose'] ?? '';
    final String type = data['type'] == 'RX' ? 'Prescription' : 'OTC';

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
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(type,
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                const SizedBox(height: 5),
                if (dose.isNotEmpty)
                  Text("Dose: $dose",
                      style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
          const Icon(Icons.medication, color: Colors.white, size: 40),
        ],
      ),
    );
  }
}
