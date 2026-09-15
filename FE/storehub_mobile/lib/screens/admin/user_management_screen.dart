import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AdminApiService _adminService = AdminApiService();
  late Future<List<dynamic>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() {
    setState(() {
      _usersFuture = _adminService.getUsers();
    });
  }

  void _showAssignRoleDialog(String userId, String currentRole) {
    String selectedRole = currentRole;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Assign User Role'),
        content: DropdownButtonFormField<String>(
          initialValue:
              selectedRole.isNotEmpty ? selectedRole : 'STORAGE_CUSTOMER',
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
          onChanged: (val) => selectedRole = val ?? 'STORAGE_CUSTOMER',
          decoration: const InputDecoration(labelText: 'Select Role'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await _adminService.assignRole(userId, selectedRole);

                // Kiểm tra dialogContext.mounted trước khi thao tác với context của dialog
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext); // Đóng dialog an toàn

                _loadUsers();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Role assigned successfully!'),
                      backgroundColor: Colors.green),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Failed: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)));
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final userId = user['id']?.toString() ?? '';
              final username = user['username'] ?? 'Unknown';
              final email = user['email'] ?? 'No email';
              final role = user['role'] ?? user['roleName'] ?? 'CUSTOMER';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: const CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.person, color: Colors.white)),
                  title: Text(username,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$email\nRole: $role'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.indigo),
                    onPressed: () => _showAssignRoleDialog(userId, role),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
