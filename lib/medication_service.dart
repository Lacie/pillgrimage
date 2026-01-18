import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pillgrimage/medication_model.dart';
import 'package:pillgrimage/notification_service.dart';

class MedicationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final NotificationService _notificationService = NotificationService();

  /// Deletes all medication logs for the current user and resets the
  /// last_taken_utc field and next_scheduled_utc field for all their medications.
  static Future<void> resetUserMedicationData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No user logged in");

    final userId = user.uid;
    final batch = _db.batch();

    // 1. Fetch and delete all medication logs
    final logsQuery = await _db
        .collection('users')
        .doc(userId)
        .collection('medication_logs')
        .get();

    for (var doc in logsQuery.docs) {
      batch.delete(doc.reference);
    }

    // 2. Fetch and reset all medications
    final medsQuery = await _db
        .collection('users')
        .doc(userId)
        .collection('medications')
        .get();

    final now = DateTime.now();

    for (var doc in medsQuery.docs) {
      final med = Medication.fromFirestore(doc);
      final Map<String, dynamic> updates = {
        'last_taken_utc': null,
        '__updated': FieldValue.serverTimestamp(),
      };

      // Recalculate next_scheduled_utc for regular medications
      if (med.regimenType == 'REG' && med.doseSchedule != null && med.doseSchedule!.isNotEmpty) {
        List<DateTime> sortedSchedule = List.from(med.doseSchedule!);
        sortedSchedule.sort((a, b) => a.hour.compareTo(b.hour));

        DateTime? nextCandidate;
        for (var scheduledTime in sortedSchedule) {
          DateTime candidate = DateTime(now.year, now.month, now.day, scheduledTime.hour, scheduledTime.minute);
          if (candidate.isAfter(now)) {
            nextCandidate = candidate;
            break;
          }
        }

        if (nextCandidate == null) {
          DateTime firstScheduled = sortedSchedule.first;
          DateTime tomorrow = now.add(const Duration(days: 1));
          nextCandidate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, firstScheduled.hour, firstScheduled.minute);
        }
        
        updates['next_scheduled_utc'] = Timestamp.fromDate(nextCandidate);
      } else {
        updates['next_scheduled_utc'] = null;
      }

      batch.update(doc.reference, updates);
    }

    // Commit the batch
    await batch.commit();
  }

  static Future<void> checkOverdueMedications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final twoHoursAgo = now.subtract(const Duration(hours: 2));

    final querySnapshot = await _db
        .collection('users')
        .doc(user.uid)
        .collection('medications')
        .where('notify_caretaker', isEqualTo: true)
        .where('next_scheduled_utc', isLessThanOrEqualTo: twoHoursAgo)
        .where('overdue_notification_sent', isEqualTo: false)
        .get();

    for (final doc in querySnapshot.docs) {
      final medication = Medication.fromFirestore(doc);
      if (medication.caretakerEmail != null) {
        await _notificationService.sendCaretakerNotification(
          medication.medName,
          user.displayName ?? 'the patient',
          medication.caretakerEmail!,
        );
        await doc.reference.update({'overdue_notification_sent': true});
      }
    }
  }
}
