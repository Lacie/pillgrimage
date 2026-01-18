import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _selectedIndex = 1; // Default to Dashboard
  final ScrollController _medListScrollController = ScrollController();

  @override
  void dispose() {
    _medListScrollController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text("Add New Medication", style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: "Name",
                        prefixIcon: const Icon(Icons.medication),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: doseController,
                      decoration: InputDecoration(
                        labelText: "Dose (e.g. 500mg)",
                        prefixIcon: const Icon(Icons.scale),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: frequencyController,
                      decoration: InputDecoration(
                        labelText: "Frequency (seconds)",
                        prefixIcon: const Icon(Icons.timer),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: "Notification Email",
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: InputDecoration(
                        labelText: "Type",
                        prefixIcon: const Icon(Icons.category),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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
                  child: const Text("Save Medication"),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_selectedIndex != 0)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: FilledButton.icon(
                onPressed: _showAddMedicationDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add"),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
        ],
      ),
      body: _buildSelectedPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medication_liquid_sharp),
            label: 'Medications',
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return "History";
      case 1:
        return "Dashboard";
      case 2:
        return "Medication List";
      default:
        return "Pillgrimage";
    }
  }

  Widget _buildSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return const Center(child: Text("History Page Content"));
      case 1:
        return _buildDashboardContent();
      case 2:
        return _buildMedicationListPage();
      default:
        return const Center(child: Text("Page Not Found"));
    }
  }

  Widget _buildDashboardContent() {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<DocumentSnapshot>(
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeHeader(userName),
              const SizedBox(height: 25),
              _buildMedicationList(user?.uid, limit: 2),
              const SizedBox(height: 25),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMedicationListPage() {
    final user = FirebaseAuth.instance.currentUser;
    return Scrollbar(
      controller: _medListScrollController,
      thumbVisibility: true,
      thickness: 6,
      radius: const Radius.circular(10),
      child: SingleChildScrollView(
        controller: _medListScrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //const Text("All Medications",
              //  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildMedicationList(user?.uid),
            // Extra spacing at bottom to ensure scrollbar is useful
            const SizedBox(height: 40),
          ],
        ),
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

  Widget _buildMedicationList(String? userId, {int? limit}) {
    if (userId == null) return const SizedBox.shrink();

    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('medications')
        .orderBy('__created', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
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
    final String type = data['type'] == 'RX' ? 'RX' : 'OTC';
    final String notificationEmail = data['notification_email'] ?? '';

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
                if (notificationEmail.isNotEmpty)
                  Text("Caretaker: $notificationEmail",
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const Icon(Icons.medication, color: Colors.white, size: 40),
        ],
      ),
    );
  }
}
