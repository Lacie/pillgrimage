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
        title: Text(_getAppBarTitle(), style: const TextStyle(fontWeight: FontWeight.bold)),
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
              _buildDailyTimeline(user?.uid),
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
            itemBuilder: (context, index) => MedicationCard(med: meds[index]),
          ),
      ],
    );
  }
}
