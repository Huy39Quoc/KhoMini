import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/facility_admin_api_service.dart';
import '../../widgets/state_views.dart';

/// Wires GET /activity-logs and GET /activity-logs/login-history
/// (ActivityLogController) - the login history / audit trail feature from
/// Member 1's original scope, previously entity-only with no API.
class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> with SingleTickerProviderStateMixin {
  final FacilityAdminApiService _service = FacilityAdminApiService();
  late final TabController _tabController;
  final _dateFmt = DateFormat('MMM d, h:mm a');

  Future<List<dynamic>>? _allLogsFuture;
  Future<List<dynamic>>? _loginHistoryFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
    _loadLoginHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadAll() {
    setState(() => _allLogsFuture = _service.getActivityLogs());
  }

  void _loadLoginHistory() {
    setState(() => _loginHistoryFuture = _service.getLoginHistory());
  }

  Color _statusColor(String? status) => status == 'FAILED' ? AppColors.error : AppColors.success;

  Widget _buildLogTile(Map log) {
    final action = log['action']?.toString() ?? '';
    final status = log['status']?.toString();
    final isCritical = log['critical'] == true;
    final createdAt = log['createdAt'] != null ? DateTime.tryParse(log['createdAt'].toString()) : null;
    final userName = log['userName']?.toString();
    final description = log['description']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: _statusColor(status).withValues(alpha: 0.15),
          child: Icon(
            status == 'FAILED' ? Icons.error_outline : Icons.check_circle_outline,
            color: _statusColor(status),
            size: 18,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(action.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            if (isCritical)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(8)),
                child: const Text('CRITICAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.error)),
              ),
          ],
        ),
        subtitle: Text(
          [
            if (userName != null && userName.isNotEmpty) userName,
            if (description != null && description.isNotEmpty) description,
            if (createdAt != null) _dateFmt.format(createdAt),
          ].join(' • '),
          style: const TextStyle(fontSize: 11.5),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Activity Log'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.secondaryContainer,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          indicatorColor: AppColors.secondaryContainer,
          tabs: const [Tab(text: 'All Activity'), Tab(text: 'Login History')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
            onRefresh: () async => _loadAll(),
            child: FutureBuilder<List<dynamic>>(
              future: _allLogsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoadingState(message: 'Loading activity...');
                }
                if (snapshot.hasError) {
                  return AppErrorState(message: snapshot.error.toString().replaceAll('Exception: ', ''), onRetry: _loadAll);
                }
                final logs = snapshot.data ?? [];
                if (logs.isEmpty) {
                  return const AppEmptyState(icon: Icons.history, title: 'No activity yet', message: 'Actions across the system will show up here.');
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) => _buildLogTile(logs[index] as Map),
                );
              },
            ),
          ),
          RefreshIndicator(
            onRefresh: () async => _loadLoginHistory(),
            child: FutureBuilder<List<dynamic>>(
              future: _loginHistoryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoadingState(message: 'Loading login history...');
                }
                if (snapshot.hasError) {
                  return AppErrorState(message: snapshot.error.toString().replaceAll('Exception: ', ''), onRetry: _loadLoginHistory);
                }
                final logs = snapshot.data ?? [];
                if (logs.isEmpty) {
                  return const AppEmptyState(icon: Icons.login, title: 'No login history yet', message: 'Sign-in attempts will show up here.');
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) => _buildLogTile(logs[index] as Map),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
