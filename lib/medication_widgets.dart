import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

String formatOverdueDuration(DateTime scheduled) {
  final diff = DateTime.now().difference(scheduled);
  if (diff.inHours >= 1) {
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours >= 24) {
      final days = diff.inDays;
      return "$days day${days > 1 ? 's' : ''} overdue";
    }
    return "$hours hr ${minutes > 0 ? '$minutes min ' : ''}overdue";
  } else {
    final minutes = diff.inMinutes;
    return "$minutes min overdue";
  }
}

String formatFrequency(Medication med) {
  if (med.regimenType == 'PRN') {
    if (med.minGapHours != null) {
      return "As needed (min ${med.minGapHours}h gap)";
    }
    return "As needed";
  } else if (med.regimenType == 'REG' && med.doseSchedule != null && med.doseSchedule!.isNotEmpty) {
    List<DateTime> sorted = List.from(med.doseSchedule!);
    sorted.sort((a, b) => a.hour.compareTo(b.hour));
    String times = sorted.map((d) => formatDateTime(d)).join(", ");
    return "$times daily";
  }
  return "";
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
          const SizedBox(height: 12),
          const Text("You will need to take a photo of your medication.", style: TextStyle(fontSize: 13, color: Colors.grey)),
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
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.camera_alt, size: 18),
          label: const Text("Take Med"),
          style: isEarly ? ElevatedButton.styleFrom(backgroundColor: Colors.orange) : null,
        ),
      ],
    ),
  );

  if (confirmed == true) {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) {
      return; // User canceled the camera after confirming
    }

    // Clear the notification when medication is taken
    NotificationService().cancelNotification(1);

    final now = FieldValue.serverTimestamp();
    final logData = {
      'med_id': med.id,
      'user_id': user.uid,
      'med_name': med.medName,
      'dosage': med.dosage,
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

      if (med.overdueNotificationSent) {
        updates['overdue_notification_sent'] = false;
      }

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
  final bool isOverdue;
  final bool showFrequency;
  final bool showNextScheduled;
  final bool showDebugButton;
  final bool isClickable;
  final VoidCallback? onEdit;

  const MedicationCard({
    super.key,
    required this.med,
    this.showLastTaken = false,
    this.isOverdue = false,
    this.showFrequency = false,
    this.showNextScheduled = true,
    this.showDebugButton = true,
    this.isClickable = true,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = isOverdue ? Colors.red : Colors.blue;

    return GestureDetector(
      onTap: isClickable ? () => takeMedication(context, med) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isClickable ? Colors.white : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isClickable ? [
            BoxShadow(
              color: (isOverdue ? Colors.red : Colors.grey).withValues(alpha: 0.1),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ] : null,
          border: Border.all(color: isClickable ? themeColor.withValues(alpha: 0.2) : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isClickable ? themeColor.withValues(alpha: 0.05) : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                med.medType == 'SUPP' ? Icons.spa : Icons.medication,
                color: isClickable ? themeColor : Colors.grey.shade400,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(med.medName,
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                        color: isClickable ? Colors.black : Colors.grey.shade600,
                      )),
                  Text(med.dosage,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  if (showFrequency)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        formatFrequency(med),
                        style: TextStyle(
                          color: isClickable ? Colors.blue : Colors.grey.shade400, 
                          fontSize: 12, 
                          fontWeight: FontWeight.w500
                        ),
                      ),
                    ),
                  if (showLastTaken && med.lastTakenUtc != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Last taken: ${formatLastTaken(med.lastTakenUtc!)}",
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (med.regimenType == 'REG' && med.nextScheduledUtc != null) ...[
                  if (!isOverdue && showNextScheduled)
                    Text(
                      formatDateTime(med.nextScheduledUtc!),
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        color: isClickable ? themeColor : Colors.grey.shade400
                      ),
                    ),
                  if (isOverdue)
                    Text(
                      formatOverdueDuration(med.nextScheduledUtc!),
                      style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onEdit != null)
                      IconButton(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit, size: 18, color: Colors.blueGrey),
                        tooltip: "Edit Medication",
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.only(right: 8),
                      ),
                    if (showDebugButton && (med.regimenType == 'REG' || (med.notifyCaretaker && med.caretakerEmail != null)))
                      IconButton(
                        onPressed: () {
                          NotificationService().showTestNotification(
                            title: "Time for ${med.medName}!",
                            body: "Reminder: Take your ${med.dosage} dose of ${med.medName}.",
                            medicationId: med.id!,
                          );
                        },
                        icon: Icon(Icons.bug_report, size: 18, color: isClickable ? Colors.orange : Colors.grey.shade300),
                        tooltip: "Test Notification",
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
