import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pillgrimage/medication_model.dart';
import 'package:pillgrimage/medication_widgets.dart';

class MedicationListView extends StatelessWidget {
  final ScrollController? scrollController;

  const MedicationListView({super.key, this.scrollController});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      thickness: 6,
      radius: const Radius.circular(10),
      child: SingleChildScrollView(
        controller: scrollController,
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
            return MedicationCard(
              med: med,
              showLastTaken: true,
              showFrequency: true,
              showNextScheduled: false,
            );
          },
        );
      },
    );
  }
}

Future<void> showAddMedicationDialog(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final nameController = TextEditingController();
  final doseController = TextEditingController();
  final gapController = TextEditingController();
  final caretakerEmailController = TextEditingController();

  String selectedType = 'RX';
  String selectedRegimen = 'REG';

  bool takeMorning = false;
  bool takeAfternoon = false;
  bool takeNight = false;
  bool notifyCaretaker = false;

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
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text("Notify Caretaker"),
                    value: notifyCaretaker,
                    onChanged: (val) => setDialogState(() => notifyCaretaker = val!),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                  if (notifyCaretaker)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: TextField(
                        controller: caretakerEmailController,
                        decoration: InputDecoration(
                          labelText: "Caretaker's Email",
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
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
                  final String? caretakerEmail =
                      notifyCaretaker ? caretakerEmailController.text.trim() : null;

                  if (selectedRegimen == 'REG') {
                    final List<DateTime> schedule = [];
                    if (takeMorning) schedule.add(DateTime(2026, 1, 1, 8, 0));
                    if (takeAfternoon) schedule.add(DateTime(2026, 1, 1, 13, 0));
                    if (takeNight) schedule.add(DateTime(2026, 1, 1, 21, 0));

                    if (schedule.isEmpty) return;

                    schedule.sort((a, b) => a.hour.compareTo(b.hour));
                    DateTime now = DateTime.now();
                    DateTime? nextScheduled;

                    for (var time in schedule) {
                      DateTime candidate = DateTime(now.year, now.month, now.day, time.hour, time.minute);
                      if (candidate.isAfter(now)) {
                        nextScheduled = candidate;
                        break;
                      }
                    }
                    if (nextScheduled == null) {
                      DateTime tomorrow = now.add(const Duration(days: 1));
                      nextScheduled = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, schedule.first.hour, schedule.first.minute);
                    }

                    final newMed = Medication(
                      medName: name,
                      medType: selectedType,
                      regimenType: selectedRegimen,
                      dosage: dose,
                      isCurrent: true,
                      userId: user.uid,
                      doseSchedule: schedule,
                      nextScheduledUtc: nextScheduled,
                      notifyCaretaker: notifyCaretaker,
                      caretakerEmail: caretakerEmail,
                    );

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('medications')
                        .add(newMed.toFirestore());
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
                      notifyCaretaker: notifyCaretaker,
                      caretakerEmail: caretakerEmail,
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
