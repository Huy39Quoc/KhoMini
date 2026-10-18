import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/facility_admin_api_service.dart';
import '../../widgets/state_views.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen>
    with SingleTickerProviderStateMixin {
  final FacilityAdminApiService _service = FacilityAdminApiService();
  late final TabController _tabController;
  final _dateFmt = DateFormat('dd/MM, HH:mm');

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
    setState(() {
      _allLogsFuture = _service.getActivityLogs();
    });
  }

  void _loadLoginHistory() {
    setState(() {
      _loginHistoryFuture = _service.getLoginHistory();
    });
  }

  Color _statusColor(String? status) =>
      status == 'FAILED' ? AppColors.error : AppColors.success;

  Future<void> _showLogDetail(Map log) async {
    final id = log['id']?.toString();
    if (id == null || id.isEmpty) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _LogDetailSheet(
        fallback: Map<String, dynamic>.from(log),
        load: () => _service.getActivityLogDetail(id),
      ),
    );
  }

  Widget _buildLogTile(Map log) {
    final action = log['action']?.toString() ?? '';
    final status = log['status']?.toString();
    final isCritical = log['critical'] == true;
    final createdAt = log['createdAt'] != null
        ? DateTime.tryParse(log['createdAt'].toString())
        : null;
    final userName = log['userName']?.toString();
    final description = log['description']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _showLogDetail(log),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: _statusColor(status).withValues(alpha: 0.15),
          child: Icon(
            status == 'FAILED'
                ? Icons.error_outline
                : Icons.check_circle_outline,
            color: _statusColor(status),
            size: 18,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(action.replaceAll('_', ' '),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            if (isCritical)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('CRITICAL',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error)),
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
        title: const Text('Nhật ký hoạt động'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.secondaryContainer,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          indicatorColor: AppColors.secondaryContainer,
          tabs: const [Tab(text: 'Mọi hoạt động'), Tab(text: 'Lịch sử đăng nhập')],
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
                  return const AppLoadingState(message: 'Đang tải nhật ký...');
                }
                if (snapshot.hasError) {
                  return AppErrorState(
                      message: snapshot.error
                          .toString()
                          .replaceAll('Exception: ', ''),
                      onRetry: _loadAll);
                }
                final logs = snapshot.data ?? [];
                if (logs.isEmpty) {
                  return const AppEmptyState(
                      icon: Icons.history,
                      title: 'Chưa có hoạt động',
                      message: 'Các thao tác trong hệ thống sẽ hiển thị tại đây.');
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) =>
                      _buildLogTile(logs[index] as Map),
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
                  return const AppLoadingState(
                      message: 'Đang tải lịch sử đăng nhập...');
                }
                if (snapshot.hasError) {
                  return AppErrorState(
                      message: snapshot.error
                          .toString()
                          .replaceAll('Exception: ', ''),
                      onRetry: _loadLoginHistory);
                }
                final logs = snapshot.data ?? [];
                if (logs.isEmpty) {
                  return const AppEmptyState(
                      icon: Icons.login,
                      title: 'Chưa có lịch sử đăng nhập',
                      message: 'Các lần đăng nhập sẽ hiển thị tại đây.');
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) =>
                      _buildLogTile(logs[index] as Map),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LogDetailSheet extends StatefulWidget {
  final Map<String, dynamic> fallback;
  final Future<Map<String, dynamic>> Function() load;
  const _LogDetailSheet({required this.fallback, required this.load});

  @override
  State<_LogDetailSheet> createState() => _LogDetailSheetState();
}

class _LogDetailSheetState extends State<_LogDetailSheet> {
  late final Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  Widget _row(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState == ConnectionState.waiting;
            final d = snapshot.data ?? widget.fallback;
            final created = d['createdAt'] != null
                ? DateTime.tryParse(d['createdAt'].toString())
                : null;
            final who = [
              d['userName']?.toString() ?? '',
              d['userEmail']?.toString() ?? '',
            ].where((e) => e.isNotEmpty).join(' - ');
            final resource = [
              d['resourceType']?.toString() ?? '',
              d['resourceId']?.toString() ?? '',
            ].where((e) => e.isNotEmpty).join(' / ');
            final oldV = d['oldValue']?.toString() ?? '';
            final newV = d['newValue']?.toString() ?? '';
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Chi tiết hoạt động',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    if (loading)
                      const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(height: 8),
                _row('Hành động',
                    (d['action']?.toString() ?? '').replaceAll('_', ' ')),
                _row('Trạng thái', d['status']?.toString()),
                _row('Người thực hiện', who),
                _row('Email đăng nhập', d['emailAttempted']?.toString()),
                _row('Đối tượng', resource),
                _row('Mô tả', d['description']?.toString()),
                if (oldV.isNotEmpty || newV.isNotEmpty)
                  _row('Thay đổi',
                      '${oldV.isEmpty ? '—' : oldV}  →  ${newV.isEmpty ? '—' : newV}'),
                _row('Địa chỉ IP', d['ipAddress']?.toString()),
                _row('Thiết bị', d['userAgent']?.toString()),
                _row('Thời gian',
                    created == null ? null : DateFormat('dd/MM/yyyy HH:mm:ss').format(created.toLocal())),
                if (snapshot.hasError)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                        'Không tải được bản mới nhất, đang hiển thị dữ liệu trong danh sách.',
                        style: TextStyle(fontSize: 11, color: AppColors.error)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
