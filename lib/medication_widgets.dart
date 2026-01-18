import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pillgrimage/medication_model.dart';
import 'package:pillgrimage/notification_service.dart';

String formatDateTime(DateTime dt) {
  final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final amPm = dt.hour >= 12 ? 'PM' : 'AM';
  return "$hour:${dt.minute.toString().padLeft(2, '0')} $amPm";
}

String formatLastTaken(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final takenDate = DateTime(dt.year, dt.month, dt.day);

  String datePart = "";
  if (takenDate == today) {
    datePart = "Today";
  } else if (takenDate == yesterday) {
    datePart = "Yesterday";
  } else {
    datePart = "${dt.month}/${dt.day}";
  }
  
  return "$datePart at ${formatDateTime(dt)}";
}

Future<void> takeMedication(BuildContext context, Medication med) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // Check if the medication is scheduled early (more than 1 hour from now)
  bool isEarly = false;
  if (med.regimenType == 'REG' && med.nextScheduledUtc != null) {
    final now = DateTime.now();
    if (med.nextScheduledUtc!.isAfter(now.add(const Duration(hours: 1)))) {
      isEarly = true;
    }
  }

  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(isEarly ? "Take Early?" : "Take Medication"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Are you sure you want to take ${med.medName} (${med.dosage})?"),
          if (isEarly) ...[
            const SizedBox(height: 12),
            const Text(
              "This dose is scheduled for later. Are you sure you want to take it early?",
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: isEarly ? ElevatedButton.styleFrom(backgroundColor: Colors.orange) : null,
          child: const Text("Take"),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    // Clear the notification when medication is taken
    NotificationService().cancelNotification(1);

    final now = FieldValue.serverTimestamp();
    final logData = {
      'med_id': med.id,
      'user_id': user.uid,
      'med_name': med.medName,
      'med_type': med.medType,
      'regimen_type': med.regimenType,
      'taken_at_utc': now,
      '__created': now,
      '__updated': now,
    };

    try {
      // 1. Log the dose
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('medication_logs')
          .add(logData);

      // 2. Update the medication record
      final Map<String, dynamic> updates = {
        'last_taken_utc': now,
        '__updated': now,
      };

      if (med.regimenType == 'REG' && med.doseSchedule != null && med.doseSchedule!.isNotEmpty) {
        final baseTime = med.nextScheduledUtc ?? DateTime.now();
        
        List<DateTime> sortedSchedule = List.from(med.doseSchedule!);
        sortedSchedule.sort((a, b) => a.hour.compareTo(b.hour));

        DateTime? nextCandidate;
        for (var scheduledTime in sortedSchedule) {
          DateTime candidate = DateTime(baseTime.year, baseTime.month, baseTime.day, scheduledTime.hour, scheduledTime.minute);
          if (candidate.isAfter(baseTime)) {
            nextCandidate = candidate;
            break;
          }
        }

        if (nextCandidate == null) {
          DateTime firstScheduled = sortedSchedule.first;
          DateTime tomorrow = baseTime.add(const Duration(days: 1));
          nextCandidate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, firstScheduled.hour, firstScheduled.minute);
        }
        
        updates['next_scheduled_utc'] = Timestamp.fromDate(nextCandidate);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('medications')
          .doc(med.id)
          .update(updates);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Logged ${med.medName}")),
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

class MedicationCard extends StatelessWidget {
  final Medication med;
  final bool showLastTaken;

  const MedicationCard({
    super.key,
    required this.med,
    this.showLastTaken = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => takeMedication(context, med),
      child: Container(
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
                  if (showLastTaken && med.lastTakenUtc != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Last taken: ${formatLastTaken(med.lastTakenUtc!)}",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            if (med.regimenType == 'REG' && med.nextScheduledUtc != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatDateTime(med.nextScheduledUtc!),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  IconButton(
                    onPressed: () {
                      NotificationService().showTestNotification(
                        title: "Time for ${med.medName}!",
                        body: "Reminder: Take your ${med.dosage} dose of ${med.medName}.",
                        medicationId: med.id!,
                      );
                    },
                    icon: const Icon(Icons.bug_report, size: 18, color: Colors.orange),
                    tooltip: "Test Notification",
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
