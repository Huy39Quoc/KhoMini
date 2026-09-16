import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class StaffDashboardScreen extends StatelessWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = [
      {
        'title': 'Check-in: John Smith (Unit A-102)',
        'time': '09:30 AM',
        'action': 'Handover PIN'
      },
      {
        'title': 'Unit Inspection: Sarah Connor (Unit B-204)',
        'time': '11:00 AM',
        'action': 'Return Record'
      },
      {
        'title': 'Lock Jam Issue: Unit C-105',
        'time': '02:15 PM',
        'action': 'Resolve Ticket'
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facility Staff - Daily Schedule'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final t = tasks[index];
          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.assignment_outlined, color: Colors.white),
              ),
              title: Text(t['title']!,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Appointment: ${t['time']}'),
              trailing: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
                child: Text(t['action']!),
              ),
            ),
          );
        },
      ),
    );
  }
}
