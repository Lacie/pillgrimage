import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  final String? id;
  final String medName;
  final String medType; // RX, OTC, SUPP, OTHER
  final String regimenType; // REG, PRN
  final bool isCurrent;
  final String userId;
  final DateTime? nextScheduledUtc;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Medication({
    this.id,
    required this.medName,
    required this.medType,
    required this.regimenType,
    required this.isCurrent,
    required this.userId,
    this.nextScheduledUtc,
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
      isCurrent: data['is_current'] ?? true,
      userId: data['user_id'] ?? '',
      nextScheduledUtc: data['next_scheduled_utc'] != null
          ? DateTime.tryParse(data['next_scheduled_utc'])
          : null,
      createdAt: (data['__created'] as Timestamp?)?.toDate(),
      updatedAt: (data['__updated'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'med_name': medName,
      'med_type': medType,
      'regimen_type': regimenType,
      'is_current': isCurrent,
      'user_id': userId,
      'next_scheduled_utc': nextScheduledUtc?.toIso8601String(),
      '__created': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      '__updated': FieldValue.serverTimestamp(),
    };
  }
}
