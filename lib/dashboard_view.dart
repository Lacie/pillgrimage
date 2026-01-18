import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pillgrimage/medication_model.dart';

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
    final gapController = TextEditingController();
    
    String selectedType = 'RX';
    String selectedRegimen = 'REG';
    
    // For Regular regimen
    bool takeMorning = false;
    bool takeAfternoon = false;
    bool takeNight = false;

    final Map<String, String> typeOptions = {
      'RX': 'Prescription',
      'OTC': 'Over the counter',
      'SUPP': 'Supplement',
      'OTHER': 'Other',
    };

    final Map<String, String> regimenOptions = {
      'REG': 'Regularly',
      'PRN': 'As needed',
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
                    DropdownButtonFormField<String>(
                      value: selectedRegimen,
                      decoration: InputDecoration(
                        labelText: "Regimen",
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: regimenOptions.entries.map((entry) {
                        return DropdownMenuItem(value: entry.key, child: Text(entry.value));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedRegimen = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    if (selectedRegimen == 'REG') ...[
                      const Text("When do you take this?", style: TextStyle(fontWeight: FontWeight.bold)),
                      CheckboxListTile(
                        title: const Text("Morning (8:00 AM)"),
                        value: takeMorning,
                        onChanged: (val) => setDialogState(() => takeMorning = val!),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                      CheckboxListTile(
                        title: const Text("Afternoon (1:00 PM)"),
                        value: takeAfternoon,
                        onChanged: (val) => setDialogState(() => takeAfternoon = val!),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                      CheckboxListTile(
                        title: const Text("Night (9:00 PM)"),
                        value: takeNight,
                        onChanged: (val) => setDialogState(() => takeNight = val!),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                    ] else
                      TextField(
                        controller: gapController,
                        decoration: InputDecoration(
                          labelText: "Minimum Gap (hours)",
                          prefixIcon: const Icon(Icons.hourglass_empty),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.number,
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
                        return DropdownMenuItem(value: entry.key, child: Text(entry.value));
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

                    final String name = nameController.text.trim();
                    final String dose = doseController.text.trim();

                    if (selectedRegimen == 'REG') {
                      final List<int> scheduledHours = [];
                      if (takeMorning) scheduledHours.add(8);
                      if (takeAfternoon) scheduledHours.add(13);
                      if (takeNight) scheduledHours.add(21);

                      if (scheduledHours.isEmpty) return;

                      for (int hour in scheduledHours) {
                        DateTime nextTime = DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                          DateTime.now().day,
                          hour,
                        );
                        
                        if (nextTime.isBefore(DateTime.now())) {
                          nextTime = nextTime.add(const Duration(days: 1));
                        }

                        final newMed = Medication(
                          medName: name,
                          medType: selectedType,
                          regimenType: selectedRegimen,
                          dosage: dose,
                          isCurrent: true,
                          userId: user.uid,
                          frequencyHours: 24,
                          nextScheduledUtc: nextTime,
                        );

                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('medications')
                            .add(newMed.toFirestore());
                      }
                    } else {
                      final int? gap = int.tryParse(gapController.text);
                      final newMed = Medication(
                        medName: name,
                        medType: selectedType,
                        regimenType: selectedRegimen,
                        dosage: dose,
                        isCurrent: true,
                        userId: user.uid,
                        minGapHours: gap,
                      );
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('medications')
                          .add(newMed.toFirestore());
                    }

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
          if (_selectedIndex == 2) // Only show on Medications page
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
        return "Medication History";
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
              _buildDailyTimeline(user?.uid),
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
            const SizedBox(height: 20),
            _buildMedicationList(user?.uid),
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
        const Text("Ready for your next step?",
            style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildDailyTimeline(String? userId) {
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('medications')
          .where('is_current', isEqualTo: true)
          .where('regimen_type', isEqualTo: 'REG')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text("Error: ${snapshot.error}");
        }

        final List<Medication> allRegMeds = snapshot.data!.docs
            .map((doc) => Medication.fromFirestore(doc))
            .where((med) => med.nextScheduledUtc != null)
            .toList();

        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day);
        final endOfToday = startOfToday.add(const Duration(days: 1));
        final endOfTomorrow = endOfToday.add(const Duration(days: 1));

        final List<Medication> todayMeds = allRegMeds
            .where((med) => med.nextScheduledUtc!.isAfter(startOfToday) && med.nextScheduledUtc!.isBefore(endOfToday))
            .toList();
        
        final List<Medication> tomorrowMeds = allRegMeds
            .where((med) => med.nextScheduledUtc!.isAfter(endOfToday) && med.nextScheduledUtc!.isBefore(endOfTomorrow))
            .toList();

        todayMeds.sort((a, b) => a.nextScheduledUtc!.compareTo(b.nextScheduledUtc!));
        tomorrowMeds.sort((a, b) => a.nextScheduledUtc!.compareTo(b.nextScheduledUtc!));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimelineSection("Today", todayMeds),
            const SizedBox(height: 24),
            _buildTimelineSection("Tomorrow", tomorrowMeds),
          ],
        );
      },
    );
  }

  Widget _buildTimelineSection(String title, List<Medication> meds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
        const Divider(color: Colors.blue, thickness: 1),
        const SizedBox(height: 12),
        if (meds.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text("Nothing scheduled", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: meds.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildMedicationCard(meds[index]),
          ),
      ],
    );
  }

  Widget _buildMedicationList(String? userId, {int? limit}) {
    if (userId == null) return const SizedBox.shrink();

    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('medications')
        .where('is_current', isEqualTo: true);

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
          return Text("Error: ${snapshot.error}");
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
                "No medications found.",
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
            final med = Medication.fromFirestore(snapshot.data!.docs[index]);
            return _buildMedicationCard(med);
          },
        );
      },
    );
  }

  Widget _buildMedicationCard(Medication med) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              med.medType == 'SUPP' ? Icons.spa : Icons.medication,
              color: Colors.blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med.medName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(med.dosage,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
          if (med.regimenType == 'REG' && med.nextScheduledUtc != null)
            Text(
              _formatDateTime(med.nextScheduledUtc!),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return "$hour:${dt.minute.toString().padLeft(2, '0')} $amPm";
  }
}
