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

  // Trước đây danh sách role bị hard-code cứng bằng tên (không đảm bảo khớp
  // với dữ liệu role thật trong DB) và gọi một endpoint không tồn tại
  // (PUT /users/{id}/role). Giờ lấy danh sách role thật từ GET /roles, và
  // cập nhật qua đúng endpoint PUT /users/{id} với {roleId, phone}.
  void _showAssignRoleDialog(
    String userId,
    String currentPhone,
  ) async {
    List<dynamic> roles;
    try {
      roles = await _adminService.getRoles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to load roles: $e'),
            backgroundColor: Colors.red),
      );
      return;
    }

    if (roles.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No roles available.')),
      );
      return;
    }

    String? selectedRoleId = roles.first['id']?.toString();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Assign User Role'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedRoleId,
            items: roles.map((r) {
              final id = r['id']?.toString() ?? '';
              final name = r['name']?.toString() ?? id;
              return DropdownMenuItem(value: id, child: Text(name));
            }).toList(),
            onChanged: (val) => setDialogState(() => selectedRoleId = val),
            decoration: const InputDecoration(labelText: 'Select Role'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white),
              onPressed: selectedRoleId == null
                  ? null
                  : () async {
                      try {
                        await _adminService.updateUserRole(
                          userId,
                          selectedRoleId!,
                          currentPhone,
                        );

                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);

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
                              content: Text('Failed: $e'),
                              backgroundColor: Colors.red),
                        );
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
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
              final phone = user['phone']?.toString() ?? '';
              final isActive = user['isActive'] == true;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: CircleAvatar(
                      backgroundColor:
                          isActive ? Colors.indigo : Colors.grey,
                      child: const Icon(Icons.person, color: Colors.white)),
                  title: Text(username,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  // Lưu ý: API GET /users hiện chưa trả về tên role của user
                  // (đây là giới hạn ở BE, không thể tự hiển thị đúng role
                  // hiện tại từ phía FE), nên chỉ hiển thị các thông tin có sẵn.
                  subtitle: Text(
                      '$email${phone.isNotEmpty ? '\n$phone' : ''}\n${isActive ? 'Active' : 'Inactive'}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.indigo),
                    onPressed: () => _showAssignRoleDialog(userId, phone),
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
