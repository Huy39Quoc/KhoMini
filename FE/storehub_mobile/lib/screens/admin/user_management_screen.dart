import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/admin_api_service.dart';
import '../../widgets/state_views.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AdminApiService _adminService = AdminApiService();
  late Future<List<dynamic>> _usersFuture;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _statusFilter = 'ALL'; // ALL, ACTIVE, INACTIVE

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadUsers() {
    setState(() {
      _usersFuture = _adminService.getUsers();
    });
  }

  Future<void> _showAssignRoleSheet(String userId, String username, String currentPhone) async {
    List<dynamic> roles;
    try {
      roles = await _adminService.getRoles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load roles: ${e.toString().replaceAll('Exception: ', '')}')),
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

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Assign role to $username',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            ...roles.map((r) {
              final id = r['id']?.toString() ?? '';
              final name = r['name']?.toString() ?? id;
              final description = r['description']?.toString();
              return ListTile(
                leading: const Icon(Icons.badge_outlined, color: AppColors.primaryContainer),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: description != null && description.isNotEmpty ? Text(description) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await _adminService.updateUserRole(userId, id, currentPhone);
                    _loadUsers();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$username is now $name'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(Map user) async {
    final userId = user['id']?.toString() ?? '';
    final wasActive = user['isActive'] == true;
    try {
      await _adminService.toggleUserActive(userId);
      _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wasActive ? 'User deactivated' : 'User activated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search by name, username, or email',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _filterChip('All', 'ALL'),
                const SizedBox(width: 8),
                _filterChip('Active', 'ACTIVE'),
                const SizedBox(width: 8),
                _filterChip('Inactive', 'INACTIVE'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _loadUsers(),
              child: FutureBuilder<List<dynamic>>(
                future: _usersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const AppLoadingState(message: 'Loading users...');
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        AppErrorState(
                          message: snapshot.error.toString().replaceAll('Exception: ', ''),
                          onRetry: _loadUsers,
                        ),
                      ],
                    );
                  }

                  var users = (snapshot.data ?? []).whereType<Map>().toList();
                  if (_statusFilter == 'ACTIVE') {
                    users = users.where((u) => u['isActive'] == true).toList();
                  } else if (_statusFilter == 'INACTIVE') {
                    users = users.where((u) => u['isActive'] != true).toList();
                  }
                  if (_query.isNotEmpty) {
                    users = users.where((u) {
                      final haystack = [
                        u['username'],
                        u['email'],
                        u['fullName'],
                      ].whereType<String>().join(' ').toLowerCase();
                      return haystack.contains(_query);
                    }).toList();
                  }

                  if (users.isEmpty) {
                    return ListView(
                      children: const [
                        AppEmptyState(
                          icon: Icons.people_outline,
                          title: 'No users found',
                          message: 'No users match this filter.',
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final userId = user['id']?.toString() ?? '';
                      final username = user['username']?.toString() ?? 'Unknown';
                      final fullName = user['fullName']?.toString() ?? username;
                      final email = user['email']?.toString() ?? '';
                      final phone = user['phone']?.toString() ?? '';
                      final isActive = user['isActive'] == true;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor:
                                isActive ? AppColors.primaryContainer : AppColors.outline,
                            child: Text(
                              _initials(fullName),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '@$username • $email${phone.isNotEmpty ? '\n$phone' : ''}',
                              style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                            ),
                          ),
                          isThreeLine: phone.isNotEmpty,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: isActive,
                                onChanged: (_) => _toggleActive(user),
                                activeThumbColor: AppColors.success,
                              ),
                              IconButton(
                                icon: const Icon(Icons.badge_outlined, size: 20),
                                tooltip: 'Assign role',
                                onPressed: () => _showAssignRoleSheet(userId, fullName, phone),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = value),
    );
  }
}
