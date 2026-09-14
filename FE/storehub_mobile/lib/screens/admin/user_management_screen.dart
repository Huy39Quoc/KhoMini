import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/admin_api_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AdminApiService _adminService = AdminApiService();
  late Future<List<UserModel>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _usersFuture = _adminService.getUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Account Directory'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<UserModel>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final u = users[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(u.fullName.isNotEmpty
                      ? u.fullName[0].toUpperCase()
                      : 'U'),
                ),
                title: Text(u.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${u.email}\nRole: ${u.role}'),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.edit_note),
                  onPressed: () => _showRoleDialog(u),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showRoleDialog(UserModel u) {
    String current = u.role;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Assign Role: ${u.username}'),
        content: DropdownButtonFormField<String>(
          initialValue: [
            'STORAGE_CUSTOMER',
            'FACILITY_STAFF',
            'FACILITY_MANAGER',
            'BUSINESS_OPERATIONS_MANAGER',
            'SYSTEM_ADMINISTRATOR'
          ].contains(current)
              ? current
              : 'STORAGE_CUSTOMER',
          items: const [
            DropdownMenuItem(
                value: 'STORAGE_CUSTOMER', child: Text('Storage Customer')),
            DropdownMenuItem(
                value: 'FACILITY_STAFF', child: Text('Facility Staff')),
            DropdownMenuItem(
                value: 'FACILITY_MANAGER', child: Text('Facility Manager')),
            DropdownMenuItem(
                value: 'BUSINESS_OPERATIONS_MANAGER',
                child: Text('Business Operations Manager')),
            DropdownMenuItem(
                value: 'SYSTEM_ADMINISTRATOR',
                child: Text('System Administrator')),
          ],
          onChanged: (v) {
            if (v != null) {
              current = v;
            }
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await _adminService.assignRole(u.id, current);
                if (mounted) {
                  _load();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Failed: $e'),
                        backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
