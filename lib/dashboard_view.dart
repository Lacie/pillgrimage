import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pillgrimage/history_view.dart';
import 'package:pillgrimage/medication_list_view.dart';
import 'package:pillgrimage/medication_model.dart';
import 'package:pillgrimage/medication_widgets.dart';
import 'package:pillgrimage/notification_service.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _selectedIndex = 1; // Default to Dashboard
  final ScrollController _medListScrollController = ScrollController();
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _listenToNotifications();
  }

  void _listenToNotifications() {
    _notificationSubscription = NotificationService().onNotificationTap.listen((medicationId) {
      if (medicationId != null) {
        _handleNotificationAction(medicationId);
      }
    });
  }

  Future<void> _handleNotificationAction(String medicationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch the medication from Firestore
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('medications')
        .doc(medicationId)
        .get();

    if (doc.exists) {
      final med = Medication.fromFirestore(doc);
      if (mounted) {
        takeMedication(context, med);
      }
    }
  }

  @override
  void dispose() {
    _medListScrollController.dispose();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/title_bar_logo.png',
              height: 28,
              width: 28,
              fit: BoxFit.scaleDown,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.medication, size: 32, color: Colors.blue),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _getAppBarTitle(),
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (_selectedIndex == 2) // Only show on Medications page
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: FilledButton.icon(
                onPressed: () => showAddMedicationDialog(context),
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
        return "Medications";
      default:
        return "pillgrimage";
    }
  }

  Widget _buildSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return const HistoryView();
      case 1:
        return _buildDashboardContent();
      case 2:
        return MedicationListView(scrollController: _medListScrollController);
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
              _buildDailyTimeline(user?.uid, userName),
              const SizedBox(height: 25),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeHeader(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Hello, $name!",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const Text("Let's keep your health on track today!",
            style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  DateTime _getNextDoseTime(Medication med, DateTime baseTime) {
    if (med.doseSchedule == null || med.doseSchedule!.isEmpty) {
      return baseTime.add(const Duration(days: 1));
    }
    
    List<DateTime> sortedSchedule = List.from(med.doseSchedule!);
    sortedSchedule.sort((a, b) => a.hour.compareTo(b.hour));

    for (var scheduledTime in sortedSchedule) {
      DateTime candidate = DateTime(baseTime.year, baseTime.month, baseTime.day, scheduledTime.hour, scheduledTime.minute);
      if (candidate.isAfter(baseTime)) {
        return candidate;
      }
    }

    DateTime firstScheduled = sortedSchedule.first;
    DateTime tomorrow = baseTime.add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, firstScheduled.hour, firstScheduled.minute);
  }

  Widget _buildDailyTimeline(String? userId, String userName) {
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

        final List<Medication> overdueMeds = [];
        final List<Medication> todayMeds = [];
        final List<Medication> tomorrowMeds = [];

        for (var med in allRegMeds) {
          DateTime? currentDose = med.nextScheduledUtc;
          if (currentDose == null) continue;

          int safety = 0;
          // Project doses up to the end of tomorrow
          while (currentDose != null && currentDose.isBefore(endOfTomorrow) && safety < 10) {
            safety++;
            // Create a virtual medication object for this specific dose
            final doseView = Medication(
              id: med.id,
              medName: med.medName,
              medType: med.medType,
              regimenType: med.regimenType,
              dosage: med.dosage,
              isCurrent: med.isCurrent,
              userId: med.userId,
              nextScheduledUtc: currentDose,
              doseSchedule: med.doseSchedule,
              lastTakenUtc: med.lastTakenUtc,
              notifyCaretaker: med.notifyCaretaker,
              caretakerEmail: med.caretakerEmail,
              overdueNotificationSent: med.overdueNotificationSent,
            );

            if (currentDose.isBefore(now)) {
              overdueMeds.add(doseView);
            } else if (currentDose.isBefore(endOfToday)) {
              todayMeds.add(doseView);
            } else {
              tomorrowMeds.add(doseView);
            }

            // Calculate the next one in the sequence
            currentDose = _getNextDoseTime(med, currentDose);
          }
        }

        overdueMeds.sort((a, b) => a.nextScheduledUtc!.compareTo(b.nextScheduledUtc!));
        todayMeds.sort((a, b) => a.nextScheduledUtc!.compareTo(b.nextScheduledUtc!));
        tomorrowMeds.sort((a, b) => a.nextScheduledUtc!.compareTo(b.nextScheduledUtc!));

        if (overdueMeds.isNotEmpty) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final Set<String> notifiedMedIds = {};
            for (final med in overdueMeds) {
              if (med.id != null && !notifiedMedIds.contains(med.id!)) {
                if (med.notifyCaretaker &&
                    med.caretakerEmail != null &&
                    !med.overdueNotificationSent) {
                  NotificationService().sendCaretakerNotification(
                    medicationName: med.medName,
                    patientName: userName,
                    caretakerEmail: med.caretakerEmail!,
                    medication: med,
                  );
                  // Update the medication to prevent duplicate notifications
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('medications')
                      .doc(med.id)
                      .update({'overdue_notification_sent': true});
                  notifiedMedIds.add(med.id!);
                }
              }
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (overdueMeds.isNotEmpty) ...[
              _buildTimelineSection("Overdue", overdueMeds, isOverdue: true),
              const SizedBox(height: 24),
            ],
            _buildTimelineSection("Today", todayMeds),
            const SizedBox(height: 24),
            _buildTimelineSection("Tomorrow", tomorrowMeds),
          ],
        );
      },
    );
  }

  Widget _buildTimelineSection(String title, List<Medication> meds, {bool isOverdue = false}) {
    final Color sectionColor = isOverdue ? Colors.red : Colors.blue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: sectionColor)),
        Divider(color: sectionColor, thickness: 1),
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
            itemBuilder: (context, index) => MedicationCard(med: meds[index], isOverdue: isOverdue),
          ),
      ],
    );
  }
}
