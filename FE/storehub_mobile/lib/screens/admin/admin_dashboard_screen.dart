import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_api_service.dart';
import '../auth/login_screen.dart';
import 'user_management_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  final String userRole;
  const AdminDashboardScreen({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    final isAdmin = userRole.contains('ADMIN');

    return Scaffold(
      appBar: AppBar(
        title:
            Text(isAdmin ? 'System Administration' : 'Operations Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthApiService().logout();
              if (context.mounted) {
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard('Total Revenue (MTD)', '184,500,000 ₫', Icons.trending_up,
              Colors.green),
          const SizedBox(height: 12),
          _buildCard(
              'System Occupancy Rate', '86.4%', Icons.pie_chart, Colors.teal),
          const SizedBox(height: 12),
          _buildCard('Active Storage Facilities', '8 Locations', Icons.business,
              Colors.blue),
          const SizedBox(height: 24),
          const Text('System Management',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.manage_accounts,
                      color: AppColors.primary),
                  title: const Text('User Account & Role Controls'),
                  subtitle: const Text('Assign roles and branch permissions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const UserManagementScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.policy, color: AppColors.accent),
                  title: const Text('General Rental Policies'),
                  subtitle: const Text(
                      'Deposit rates, overdue fees, cancellation rules'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Standard facility policies loaded.')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, String val, IconData icon, Color col) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: col.withValues(alpha: 0.15),
          child: Icon(icon, color: col),
        ),
        title: Text(title,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        trailing: Text(val,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: col)),
      ),
    );
  }
}
