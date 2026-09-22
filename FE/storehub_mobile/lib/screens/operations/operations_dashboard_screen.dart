import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/admin_api_service.dart';
import '../admin/role_permission_screen.dart';
import '../common/profile_screen.dart';

class OperationsDashboardScreen extends StatefulWidget {
  final UserModel user;
  const OperationsDashboardScreen({super.key, required this.user});

  @override
  State<OperationsDashboardScreen> createState() => _OperationsDashboardScreenState();
}

class _OperationsDashboardScreenState extends State<OperationsDashboardScreen> {
  final _adminApiService = AdminApiService();
  bool _isLoading = true;
  int _userCount = 0;
  int _activeUsers = 0;
  int _totalRoles = 0;
  int _totalPermissions = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchLiveMetrics();
  }

  Future<void> _fetchLiveMetrics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _adminApiService.getTotalUsersCount(),
        _adminApiService.getUsers(),
        _adminApiService.getRoles(),
        _adminApiService.getPermissions(),
      ]);
      final total = results[0] as int;
      final users = results[1] as List<dynamic>;
      final roles = results[2] as List<dynamic>;
      final permissions = results[3] as List<dynamic>;
      final active = users.whereType<Map>().where((u) => u['isActive'] == true).length;

      if (!mounted) return;
      setState(() {
        _userCount = total;
        _activeUsers = active;
        _totalRoles = roles.length;
        _totalPermissions = permissions.length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Operations Console'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                widget.user.fullName.isNotEmpty
                    ? widget.user.fullName.substring(0, 1).toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen(user: widget.user)),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchLiveMetrics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Welcome back, ${widget.user.fullName.isNotEmpty ? widget.user.fullName : widget.user.username}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  const Text('System-wide metrics at a glance.',
                      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 16),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
                    ),

                  const Text('System Overview',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _statCard('Registered Users', '$_userCount', Icons.people, AppColors.primaryContainer),
                      _statCard('Active Users', '$_activeUsers', Icons.verified_user, AppColors.success),
                      _statCard('Roles Defined', '$_totalRoles', Icons.badge, AppColors.secondaryContainer),
                      _statCard('Permissions', '$_totalPermissions', Icons.lock_outline, AppColors.secondary),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Business Policies',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Facility rental policies, deposit rules, late-fee thresholds, and cancellation rules '
                            'are configured on the backend and are not yet exposed through a management API - '
                            'this app will not display placeholder numbers for them.',
                            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.security, color: AppColors.primaryContainer),
                      ),
                      title: const Text('Roles & Permissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('View what each role can access (read-only)', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RolePermissionScreen(readOnly: true)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
