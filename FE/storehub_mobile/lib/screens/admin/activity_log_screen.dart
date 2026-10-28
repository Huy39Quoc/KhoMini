import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/paged_result.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          tabs: const [
            Tab(text: 'Mọi hoạt động'),
            Tab(text: 'Lịch sử đăng nhập')
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PaginatedLogTab(
            loadPage: (page) => _service.getActivityLogs(page: page),
            tileBuilder: _buildLogTile,
            loadingMessage: 'Đang tải nhật ký...',
            emptyIcon: Icons.history,
            emptyTitle: 'Chưa có hoạt động',
            emptyMessage: 'Các thao tác trong hệ thống sẽ hiển thị tại đây.',
          ),
          _PaginatedLogTab(
            loadPage: (page) => _service.getLoginHistory(page: page),
            tileBuilder: _buildLogTile,
            loadingMessage: 'Đang tải lịch sử đăng nhập...',
            emptyIcon: Icons.login,
            emptyTitle: 'Chưa có lịch sử đăng nhập',
            emptyMessage: 'Các lần đăng nhập sẽ hiển thị tại đây.',
          ),
        ],
      ),
    );
  }
}

class _PaginatedLogTab extends StatefulWidget {
  final Future<PagedResult<Map<String, dynamic>>> Function(int page) loadPage;
  final Widget Function(Map<String, dynamic> log) tileBuilder;
  final String loadingMessage;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;

  const _PaginatedLogTab({
    required this.loadPage,
    required this.tileBuilder,
    required this.loadingMessage,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  @override
  State<_PaginatedLogTab> createState() => _PaginatedLogTabState();
}

class _PaginatedLogTabState extends State<_PaginatedLogTab> {
  final List<Map<String, dynamic>> _logs = [];
  bool _initialLoading = true;
  bool _loading = false;
  bool _loadingMore = false;
  bool _lastPage = false;
  int _nextPage = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading || (!refresh && _lastPage)) return;
    final requestedPage = refresh ? 0 : _nextPage;
    setState(() {
      _loading = true;
      if (refresh) {
        _initialLoading = _logs.isEmpty;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final result = await widget.loadPage(requestedPage);
      if (!mounted) return;
      setState(() {
        if (refresh) _logs.clear();
        _logs.addAll(result.content);
        _nextPage = result.page + 1;
        _lastPage = result.last;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _initialLoading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return AppLoadingState(message: widget.loadingMessage);
    }
    if (_error != null && _logs.isEmpty) {
      return AppErrorState(
          message: _error!, onRetry: () => _load(refresh: true));
    }
    if (_logs.isEmpty) {
      return AppEmptyState(
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        message: widget.emptyMessage,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length + (_lastPage ? 0 : 1),
        itemBuilder: (context, index) {
          if (index < _logs.length) return widget.tileBuilder(_logs[index]);
          return Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            child: Center(
              child: _loadingMore
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_error != null) ...[
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        OutlinedButton.icon(
                          onPressed: _load,
                          icon: Icon(
                            _error == null ? Icons.expand_more : Icons.refresh,
                          ),
                          label: Text(_error == null ? 'Tải thêm' : 'Thử lại'),
                        ),
                      ],
                    ),
            ),
          );
        },
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
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                _row(
                    'Thời gian',
                    created == null
                        ? null
                        : DateFormat('dd/MM/yyyy HH:mm:ss')
                            .format(created.toLocal())),
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
