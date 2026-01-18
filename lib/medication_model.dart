import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  final String? id;
  final String medName;
  final String medType; // RX, OTC, SUPP, OTHER
  final String regimenType; // REG, PRN
  final String dosage;
  final bool isCurrent;
  final String userId;
  final DateTime? nextScheduledUtc;
  final DateTime? lastTakenUtc;
  final int? minGapHours;
  final int? frequencyHours;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Medication({
    this.id,
    required this.medName,
    required this.medType,
    required this.regimenType,
    required this.dosage,
    required this.isCurrent,
    required this.userId,
    this.nextScheduledUtc,
    this.lastTakenUtc,
    this.minGapHours,
    this.frequencyHours,
    this.createdAt,
    this.updatedAt,
  });

  factory Medication.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Medication(
      id: doc.id,
      medName: data['med_name'] ?? '',
      medType: data['med_type'] ?? 'OTHER',
      regimenType: data['regimen_type'] ?? 'PRN',
      dosage: data['dosage'] ?? '',
      isCurrent: data['is_current'] ?? true,
      userId: data['user_id'] ?? '',
      nextScheduledUtc: (data['next_scheduled_utc'] as Timestamp?)?.toDate(),
      lastTakenUtc: (data['last_taken_utc'] as Timestamp?)?.toDate(),
      minGapHours: data['min_gap_hours'] as int?,
      frequencyHours: data['frequency_hours'] as int?,
      createdAt: (data['__created'] as Timestamp?)?.toDate(),
      updatedAt: (data['__updated'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'med_name': medName,
      'med_type': medType,
      'regimen_type': regimenType,
      'dosage': dosage,
      'is_current': isCurrent,
      'user_id': userId,
      'next_scheduled_utc': nextScheduledUtc != null ? Timestamp.fromDate(nextScheduledUtc!) : null,
      'last_taken_utc': lastTakenUtc != null ? Timestamp.fromDate(lastTakenUtc!) : null,
      'min_gap_hours': minGapHours,
      'frequency_hours': frequencyHours,
      '__created': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      '__updated': FieldValue.serverTimestamp(),
    };
  }
}
