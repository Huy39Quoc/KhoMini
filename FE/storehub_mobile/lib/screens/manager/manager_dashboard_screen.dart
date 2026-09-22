import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../common/profile_screen.dart';

/// Honest placeholder: the BE has no controller yet for Flow 5 (facility
/// unit assignment, tenant/contract monitoring, handover/renewal/overdue
/// management, staff assignment, facility reports) - only the database
/// tables exist. This screen says so clearly instead of implying there is
/// simply "nothing today".
class ManagerDashboardScreen extends StatelessWidget {
  final UserModel user;
  const ManagerDashboardScreen({super.key, required this.user});

  static const _plannedFeatures = [
    ('Unit assignment', Icons.assignment_ind_outlined,
        'Allocate a specific physical unit (e.g. A-101, Floor 2) to a booking'),
    ('Tenant & contract monitoring', Icons.groups_outlined,
        'Track current tenants, rental periods, and payment status'),
    ('Handover & return workflow', Icons.swap_horiz_outlined,
        'Manage move-in, move-out, renewal, and overdue handling'),
    ('Staff assignment', Icons.badge_outlined,
        'Assign facility staff to handovers and inspections'),
    ('Facility reports', Icons.insert_chart_outlined_rounded,
        'Available/rented units, revenue, and usage rate for your facility'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Facility Manager Console'),
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
          const Text('Your facility operations hub.',
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
                const Text('Facility management is not connected yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'The backend for unit assignment, handovers, and facility reports (Flow 5) hasn\'t been built yet - '
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
