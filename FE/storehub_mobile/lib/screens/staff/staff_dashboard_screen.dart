import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../common/profile_screen.dart';

/// Honest placeholder: the BE has no controller yet for Flow 2 (daily
/// check-in/check-out schedule, handover records, unit condition checks) -
/// only the database tables exist. See ManagerDashboardScreen for the same
/// approach on the Flow 5 side.
class StaffDashboardScreen extends StatelessWidget {
  final UserModel user;
  const StaffDashboardScreen({super.key, required this.user});

  static const _plannedFeatures = [
    ('Daily schedule', Icons.event_note_outlined,
        'Customers due to check in or check out today'),
    ('Check-in & handover', Icons.qr_code_scanner_outlined,
        'Verify a reservation and hand over the unit, lock, or access code'),
    ('Handover record', Icons.fact_check_outlined,
        'Confirm cleanliness and lock condition at handover and return'),
    ('On-site issue handling', Icons.report_problem_outlined,
        'Lost keys, access code issues, or damaged units'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Staff Operations'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                user.fullName.isNotEmpty ? user.fullName.substring(0, 1).toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen(user: user)),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Welcome, ${user.fullName.isNotEmpty ? user.fullName : user.username}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Your on-site check-in & handover hub.',
              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                  child: const Icon(Icons.construction_rounded, color: AppColors.secondaryContainer, size: 30),
                ),
                const SizedBox(height: 14),
                const Text('Check-in & handover is not connected yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'The backend for the daily schedule and handover records (Flow 2) hasn\'t been built yet - '
                  'only the database tables exist so far. Nothing is shown here rather than fake data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('Planned for this console', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          ..._plannedFeatures.map((f) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(f.$2, color: AppColors.primaryContainer),
                  ),
                  title: Text(f.$1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(f.$3, style: const TextStyle(fontSize: 12)),
                ),
              )),
        ],
      ),
    );
  }
}
