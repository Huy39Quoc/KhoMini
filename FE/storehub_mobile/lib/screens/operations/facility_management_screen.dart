import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/facility_admin_api_service.dart';
import '../../models/paged_result.dart';
import '../../widgets/state_views.dart';
import 'facility_edit_screen.dart';

class FacilityManagementScreen extends StatefulWidget {
  const FacilityManagementScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Facilities')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Search by name, code, or city',
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
                        message: 'Loading facilities...');
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
                      title: 'No facilities yet',
                      message: 'Tap + to create the first storage facility.',
                      action: ElevatedButton.icon(
                        onPressed: () async {
                          final created = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const FacilityEditScreen()),
                          );
                          if (created == true) _load();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('New Facility'),
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
                          child: Text(_loadingMore ? 'Loading...' : 'Load more facilities'),
                        ));
                      }
                      final f = facilities[index];
                      final status = f['status']?.toString();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primaryContainer,
                            child: Text(
                              (f['code']?.toString().isNotEmpty ?? false)
                                  ? f['code']
                                      .toString()
                                      .substring(0, 1)
                                      .toUpperCase()
                                  : 'F',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
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
                                          ? 'Manager: ${f['managerName']}'
                                          : 'No manager assigned',
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
                            child: Text(status ?? '',
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
                                      FacilityEditScreen(facility: f)),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const FacilityEditScreen()),
          );
          if (created == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Facility'),
      ),
    );
  }
}
