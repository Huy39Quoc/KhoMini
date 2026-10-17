import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/facility_admin_api_service.dart';
import '../../models/paged_result.dart';
import '../../widgets/state_views.dart';
import 'facility_edit_screen.dart';

class FacilityManagementScreen extends StatefulWidget {
  /// true khi mở từ màn hình Admin: Admin chỉ GÁN quản lý cho cơ sở (không tạo/sửa cơ sở,
  /// việc đó thuộc Business Manager).
  final bool canAssignManager;

  const FacilityManagementScreen({super.key, this.canAssignManager = false});

  @override
  State<FacilityManagementScreen> createState() =>
      _FacilityManagementScreenState();
}

class _FacilityManagementScreenState extends State<FacilityManagementScreen> {
  final FacilityAdminApiService _service = FacilityAdminApiService();
  late Future<PagedResult<Map<String, dynamic>>> _facilitiesFuture;
  final List<Map<String, dynamic>> _additional = [];
  int _nextPage = 1;
  bool _lastPage = false;
  bool _loadingMore = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _additional.clear();
      _nextPage = 1;
      _lastPage = false;
      _facilitiesFuture =
          _service.getFacilitiesPage(search: _searchController.text.trim());
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _lastPage) return;
    final currentLoad = _facilitiesFuture;
    setState(() => _loadingMore = true);
    try {
      final batch = await _service.getFacilitiesPage(
          search: _searchController.text.trim(), page: _nextPage);
      if (!mounted || !identical(currentLoad, _facilitiesFuture)) return;
      setState(() {
        _additional.addAll(batch.content);
        _nextPage++;
        _lastPage = batch.last;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'ACTIVE':
        return AppColors.success;
      case 'INACTIVE':
        return AppColors.outline;
      case 'MAINTENANCE':
        return AppColors.warning;
      default:
        return AppColors.outline;
    }
  }

  String? _getFacilityThumbnail(Map<String, dynamic> f) {
    final img = f['imageUrl']?.toString().trim();
    if (img != null && img.isNotEmpty) return img;
    final images = f['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first?.toString().trim();
      if (first != null && first.isNotEmpty) return first;
    } else if (images is String && images.trim().isNotEmpty) {
      final first = images.split(',').first.trim();
      if (first.isNotEmpty) return first;
    }
    return null;
  }

  Widget _buildFacilityAvatar(Map<String, dynamic> f) {
    final thumbUrl = _getFacilityThumbnail(f);
    final initial = (f['code']?.toString().isNotEmpty ?? false)
        ? f['code'].toString().substring(0, 1).toUpperCase()
        : (f['name']?.toString().isNotEmpty ?? false)
            ? f['name'].toString().substring(0, 1).toUpperCase()
            : 'F';

    Widget fallback() => Container(
          width: 46,
          height: 46,
          color: AppColors.primaryContainer,
          alignment: Alignment.center,
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 46,
        height: 46,
        child: (thumbUrl != null && thumbUrl.isNotEmpty)
            ? Image.network(
                thumbUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: 46,
                    height: 46,
                    color: AppColors.surfaceContainer,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              )
            : fallback(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
            widget.canAssignManager ? 'Gán quản lý cơ sở' : 'Cơ sở & chính sách'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, mã hoặc thành phố',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh), onPressed: _load),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _load(),
              child: FutureBuilder<PagedResult<Map<String, dynamic>>>(
                future: _facilitiesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const AppLoadingState(
                        message: 'Đang tải danh sách cơ sở...');
                  }
                  if (snapshot.hasError) {
                    return AppErrorState(
                      message: snapshot.error
                          .toString()
                          .replaceAll('Exception: ', ''),
                      onRetry: _load,
                    );
                  }
                  final facilities = [...?snapshot.data?.content, ..._additional];
                  final hasMore = snapshot.data != null && !snapshot.data!.last && !_lastPage;
                  if (facilities.isEmpty) {
                    return AppEmptyState(
                      icon: Icons.warehouse_outlined,
                      title: 'Chưa có cơ sở nào',
                      message: widget.canAssignManager
                          ? 'Business Manager cần tạo cơ sở trước khi bạn gán quản lý.'
                          : 'Bấm nút bên dưới để tạo cơ sở kho đầu tiên.',
                      action: widget.canAssignManager
                          ? null
                          : ElevatedButton.icon(
                        onPressed: () async {
                          final created = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => FacilityEditScreen(
                                    canAssignManager: widget.canAssignManager)),
                          );
                          if (created == true) _load();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm cơ sở'),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    itemCount: facilities.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == facilities.length) {
                        return Center(child: TextButton(
                          onPressed: _loadingMore ? null : _loadMore,
                          child: Text(_loadingMore ? 'Đang tải...' : 'Tải thêm cơ sở'),
                        ));
                      }
                      final f = facilities[index];
                      final status = f['status']?.toString();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          leading: _buildFacilityAvatar(f),
                          title: Text(f['name']?.toString() ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${f['code'] ?? ''} • ${f['address'] ?? ''}${f['city'] != null && f['city'].toString().isNotEmpty ? ', ${f['city']}' : ''}',
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.manage_accounts_outlined,
                                    size: 14,
                                    color: (f['managerName'] != null &&
                                            f['managerName']
                                                .toString()
                                                .isNotEmpty)
                                        ? AppColors.primaryContainer
                                        : AppColors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      (f['managerName'] != null &&
                                              f['managerName']
                                                  .toString()
                                                  .isNotEmpty)
                                          ? 'Quản lý: ${f['managerName']}'
                                          : 'Chưa gán quản lý',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: (f['managerName'] != null &&
                                                f['managerName']
                                                    .toString()
                                                    .isNotEmpty)
                                            ? AppColors.onSurface
                                            : AppColors.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  _statusColor(status).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(_statusLabel(status),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _statusColor(status))),
                          ),
                          onTap: () async {
                            await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      FacilityEditScreen(
                                      facility: f,
                                      canAssignManager: widget.canAssignManager,
                                      assignOnly: widget.canAssignManager)),
                            );
                            if (!mounted) return;
                            _load();
                          },
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
      floatingActionButton: widget.canAssignManager
          ? null
          : FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => FacilityEditScreen(
                                    canAssignManager: widget.canAssignManager)),
          );
          if (created == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm cơ sở'),
      ),
    );
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'ACTIVE':
        return 'Hoạt động';
      case 'INACTIVE':
        return 'Tạm ngưng';
      case 'MAINTENANCE':
        return 'Bảo trì';
      default:
        return status ?? '';
    }
  }
}
