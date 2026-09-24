import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/admin_api_service.dart';
import '../../services/catalog_api_service.dart';
import '../../services/facility_ops_api_service.dart';
import '../../widgets/state_views.dart';
import '../common/profile_screen.dart';

/// Flow 5 (Facility Storage and Staff Management). Wires
/// FacilityManagementController, merged onto the BE after this screen was
/// first built as an honest "not connected yet" placeholder.
class ManagerDashboardScreen extends StatefulWidget {
  final UserModel user;
  const ManagerDashboardScreen({super.key, required this.user});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen>
    with SingleTickerProviderStateMixin {
  final FacilityOpsApiService _opsService = FacilityOpsApiService();
  final CatalogApiService _catalogService = CatalogApiService();
  final AdminApiService _adminApiService = AdminApiService();
  late final TabController _tabController;

  bool _isLoadingFacility = true;
  String? _facilityId;
  String? _facilityName;
  String? _facilityError;

  Future<List<dynamic>>? _unitsFuture;
  Future<List<dynamic>>? _staffFuture;
  Future<Map<String, dynamic>>? _reportFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadFacility();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFacility() async {
    setState(() {
      _isLoadingFacility = true;
      _facilityError = null;
    });
    try {
      final facility = await _opsService.getMyFacility();
      if (!mounted) return;
      final id = facility['id']?.toString();
      setState(() {
        _facilityId = id;
        _facilityName = facility['name']?.toString();
        _isLoadingFacility = false;
      });
      if (id != null && id.isNotEmpty) _loadAll();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _facilityError = e.toString().replaceAll('Exception: ', '');
        _isLoadingFacility = false;
      });
    }
  }

  void _loadAll() {
    _loadUnits();
    _loadStaff();
    _loadReport();
  }

  void _loadUnits() {
    if (_facilityId == null) return;
    setState(() => _unitsFuture = _opsService.getFacilityUnits(_facilityId!));
  }

  void _loadStaff() {
    if (_facilityId == null) return;
    setState(() => _staffFuture = _opsService.getFacilityStaff(_facilityId!));
  }

  void _loadReport() {
    if (_facilityId == null) return;
    setState(() => _reportFuture = _opsService.getFacilityManagerReport(_facilityId!));
  }

  Future<void> _openCreateUnitSheet() async {
    List<dynamic> unitTypes;
    try {
      unitTypes = await _catalogService.getUnitTypes(facilityId: _facilityId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't load unit types: ${e.toString().replaceAll('Exception: ', '')}")),
      );
      return;
    }
    if (unitTypes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unit types are defined in the catalog yet.')),
      );
      return;
    }

    final unitCodeController = TextEditingController();
    final floorController = TextEditingController();
    String? selectedTypeId = unitTypes.first['id']?.toString();
    bool submitting = false;
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('New Storage Unit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: unitCodeController,
                    decoration: const InputDecoration(labelText: 'Unit code', hintText: 'e.g. A-101'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Unit code is required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: floorController,
                    decoration: const InputDecoration(labelText: 'Floor / level (optional)', hintText: 'e.g. Floor 2'),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTypeId,
                    decoration: const InputDecoration(labelText: 'Unit type'),
                    items: unitTypes
                        .map((t) => DropdownMenuItem<String>(
                              value: t['id']?.toString(),
                              child: Text(t['typeName']?.toString() ?? ''),
                            ))
                        .toList(),
                    onChanged: (v) => setSheet(() => selectedTypeId = v),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate() || selectedTypeId == null) return;
                            setSheet(() => submitting = true);
                            try {
                              await _opsService.createFacilityUnit(
                                _facilityId!,
                                unitCode: unitCodeController.text.trim(),
                                floorLevel: floorController.text.trim(),
                                unitTypeId: selectedTypeId!,
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              _loadUnits();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Unit created'), backgroundColor: AppColors.success),
                              );
                            } catch (e) {
                              setSheet(() => submitting = false);
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString().replaceAll('Exception: ', '')),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          },
                    child: submitting
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Create Unit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAssignStaffSheet() async {
    List<dynamic> users;
    try {
      users = await _adminApiService.getUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't load users: ${e.toString().replaceAll('Exception: ', '')}")),
      );
      return;
    }

    if (!mounted) return;
    final searchController = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final query = searchController.text.trim().toLowerCase();
          final filtered = users.whereType<Map>().where((u) {
            if (query.isEmpty) return true;
            final haystack = [u['fullName'], u['email'], u['username']]
                .whereType<String>()
                .join(' ')
                .toLowerCase();
            return haystack.contains(query);
          }).toList();

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.7,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Assign Staff to This Facility',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        TextField(
                          controller: searchController,
                          onChanged: (_) => setSheet(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Search by name or email',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final u = filtered[index];
                        final userId = u['id']?.toString() ?? '';
                        final name = u['fullName']?.toString() ?? u['username']?.toString() ?? '';
                        return ListTile(
                          title: Text(name),
                          subtitle: Text(u['email']?.toString() ?? ''),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            try {
                              await _opsService.assignStaffToFacility(_facilityId!, userId);
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              _loadStaff();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$name assigned to this facility'), backgroundColor: AppColors.success),
                              );
                            } catch (e) {
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString().replaceAll('Exception: ', '')),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _unitStatusColor(String? status) {
    switch (status) {
      case 'AVAILABLE':
        return AppColors.success;
      case 'OCCUPIED':
        return AppColors.error;
      case 'RESERVED':
        return AppColors.warning;
      case 'UNDER_MAINTENANCE':
        return AppColors.secondary;
      default:
        return AppColors.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(_facilityName ?? 'Facility Manager Console'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                widget.user.fullName.isNotEmpty ? widget.user.fullName.substring(0, 1).toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(user: widget.user)),
            ),
          ),
          const SizedBox(width: 6),
        ],
        bottom: (_facilityId != null)
            ? TabBar(
                controller: _tabController,
                labelColor: AppColors.secondaryContainer,
                unselectedLabelColor: AppColors.onSurfaceVariant,
                indicatorColor: AppColors.secondaryContainer,
                tabs: const [
                  Tab(text: 'Units'),
                  Tab(text: 'Staff'),
                  Tab(text: 'Report'),
                ],
              )
            : null,
      ),
      body: _isLoadingFacility
          ? const AppLoadingState(message: 'Loading your facility...')
          : _facilityError != null
              ? AppErrorState(message: _facilityError!, onRetry: _loadFacility)
              : (_facilityId == null || _facilityId!.isEmpty)
                  ? const AppEmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No facility assigned',
                      message: 'Ask an administrator to assign you to a facility to manage it here.',
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [_buildUnitsTab(), _buildStaffTab(), _buildReportTab()],
                    ),
      floatingActionButton: (_facilityId != null && _tabController.index == 0)
          ? FloatingActionButton.extended(
              onPressed: _openCreateUnitSheet,
              icon: const Icon(Icons.add),
              label: const Text('New Unit'),
            )
          : null,
    );
  }

  Widget _buildUnitsTab() {
    return RefreshIndicator(
      onRefresh: () async => _loadUnits(),
      child: FutureBuilder<List<dynamic>>(
        future: _unitsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(message: 'Loading units...');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: snapshot.error.toString().replaceAll('Exception: ', ''),
              onRetry: _loadUnits,
            );
          }
          final units = snapshot.data ?? [];
          if (units.isEmpty) {
            return const AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No storage units yet',
              message: 'Tap "New Unit" to add the first physical unit at this facility.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: units.length,
            itemBuilder: (context, index) {
              final u = units[index] as Map;
              final status = u['status']?.toString();
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _unitStatusColor(status).withValues(alpha: 0.15),
                    child: Icon(Icons.inventory_2, color: _unitStatusColor(status), size: 18),
                  ),
                  title: Text('Unit ${u['unitCode'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('${u['unitType'] ?? ''}${u['floorLevel'] != null ? ' • ${u['floorLevel']}' : ''}',
                      style: const TextStyle(fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _unitStatusColor(status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text((status ?? '').replaceAll('_', ' '),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _unitStatusColor(status))),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStaffTab() {
    return RefreshIndicator(
      onRefresh: () async => _loadStaff(),
      child: FutureBuilder<List<dynamic>>(
        future: _staffFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(message: 'Loading staff...');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: snapshot.error.toString().replaceAll('Exception: ', ''),
              onRetry: _loadStaff,
            );
          }
          final staff = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              OutlinedButton.icon(
                onPressed: _openAssignStaffSheet,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Assign Staff'),
              ),
              const SizedBox(height: 12),
              if (staff.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: AppEmptyState(
                    icon: Icons.groups_outlined,
                    title: 'No staff assigned',
                    message: 'Assign staff members to this facility so they can handle check-ins.',
                  ),
                )
              else
                ...staff.map((s) {
                  final m = s as Map;
                  final userId = m['id']?.toString() ?? m['userId']?.toString() ?? '';
                  final name = m['fullName']?.toString() ?? '';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(m['email']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(m['role']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                          IconButton(
                            tooltip: 'Remove from facility',
                            icon: const Icon(Icons.person_remove_outlined, size: 18, color: AppColors.error),
                            onPressed: userId.isEmpty
                                ? null
                                : () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Remove staff member?'),
                                        content: Text('$name will no longer be assigned to this facility.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('Remove'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm != true) return;
                                    try {
                                      await _opsService.unassignStaff(_facilityId!, userId);
                                      _loadStaff();
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('$name removed'), backgroundColor: AppColors.success),
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(e.toString().replaceAll('Exception: ', '')),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReportTab() {
    return RefreshIndicator(
      onRefresh: () async => _loadReport(),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(message: 'Loading report...');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: snapshot.error.toString().replaceAll('Exception: ', ''),
              onRetry: _loadReport,
            );
          }
          final r = snapshot.data ?? {};
          final total = r['total'] ?? 0;
          final available = r['available'] ?? 0;
          final reserved = r['reserved'] ?? 0;
          final occupied = r['occupied'] ?? 0;
          final maintenance = r['underMaintenance'] ?? 0;
          final rate = (r['occupancyRate'] as num?)?.toDouble() ?? 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text('Occupancy Rate', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text('${rate.toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (rate / 100).clamp(0, 1),
                        minHeight: 8,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(AppColors.secondaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _statTile('Total Units', '$total', Icons.grid_view, AppColors.primaryContainer),
                  _statTile('Available', '$available', Icons.check_circle_outline, AppColors.success),
                  _statTile('Occupied', '$occupied', Icons.lock_outline, AppColors.error),
                  _statTile('Reserved', '$reserved', Icons.schedule, AppColors.warning),
                  _statTile('Maintenance', '$maintenance', Icons.build_outlined, AppColors.secondary),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
