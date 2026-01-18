import 'package:flutter/material.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        // Padding
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(),
            const SizedBox(height: 25),
            _buildUpcomingSchedule(),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  // welcome section
  // TODO: Connect to show the user's name
  Widget _buildWelcomeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text("Hello, User!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text("Upcoming Medication:", style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  // Displays the upcoming medication in the schedule.
  // TODO: connect to show the user's up coming medication
  Widget _buildUpcomingSchedule() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        color: Colors.blueAccent.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Tylenol", style: TextStyle(color: Colors.white, fontSize: 18)),
                SizedBox(height: 5),
                Text("Jan 18, 2026 @ 5:00PM", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

}