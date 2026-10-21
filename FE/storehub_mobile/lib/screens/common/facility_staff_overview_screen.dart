import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/admin_api_service.dart';
import '../../services/facility_admin_api_service.dart';
import '../../widgets/state_views.dart';

class FacilityStaffOverviewScreen extends StatefulWidget {
  final int initialTabIndex;

  const FacilityStaffOverviewScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<FacilityStaffOverviewScreen> createState() =>
      _FacilityStaffOverviewScreenState();
}

class _FacilityStaffOverviewScreenState
    extends State<FacilityStaffOverviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FacilityAdminApiService _facilityService = FacilityAdminApiService();
  final AdminApiService _adminService = AdminApiService();

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _facilities = [];
  List<UserModel> _allStaff = [];

  // Filter & Search
  String _facilitySearchQuery = '';
  String _staffSearchQuery = '';
  String _staffFacilityFilter = 'ALL'; // 'ALL', 'UNASSIGNED', or facilityId

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _facilityService.getFacilities(),
        _adminService.getStaffList(),
      ]);

      final rawFacilities = results[0];
      final staffList = results[1] as List<UserModel>;

      if (!mounted) return;
      setState(() {
        _facilities = rawFacilities
            .map((f) => Map<String, dynamic>.from(f as Map))
            .toList();
        _allStaff = staffList;
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

  List<UserModel> _getStaffForFacility(String facilityId) {
    return _allStaff.where((s) => s.facilityId == facilityId).toList();
  }

  List<UserModel> get _unassignedStaff {
    return _allStaff.where((s) => s.facilityId == null || s.facilityId!.isEmpty).toList();
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

  String _statusLabel(String? status) {
    switch (status) {
      case 'ACTIVE':
        return 'Hoạt động';
      case 'INACTIVE':
        return 'Tạm đóng';
      case 'MAINTENANCE':
        return 'Bảo trì';
      default:
        return status ?? '—';
    }
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final assignedStaffCount = _allStaff.length - _unassignedStaff.length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Cơ sở & Nhân sự hệ thống'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: const Icon(Icons.warehouse_rounded, size: 20),
              text: 'Cơ sở kho (${_facilities.length})',
            ),
            Tab(
              icon: const Icon(Icons.badge_rounded, size: 20),
              text: 'Nhân viên (${_allStaff.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const AppLoadingState(message: 'Đang tải dữ liệu cơ sở và nhân sự...')
          : _errorMessage != null
              ? AppErrorState(
                  message: _errorMessage!,
                  onRetry: _loadData,
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFacilitiesTab(),
                    _buildStaffTab(assignedStaffCount),
                  ],
                ),
    );
  }

  // ==========================================
  // TAB 1: DANH SÁCH CƠ SỞ & NHÂN SỰ MỖI CƠ SỞ
  // ==========================================
  Widget _buildFacilitiesTab() {
    final filtered = _facilities.where((f) {
      if (_facilitySearchQuery.isEmpty) return true;
      final q = _facilitySearchQuery.toLowerCase();
      final name = (f['name'] ?? '').toString().toLowerCase();
      final code = (f['code'] ?? '').toString().toLowerCase();
      final address = (f['address'] ?? '').toString().toLowerCase();
      final city = (f['city'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          code.contains(q) ||
          address.contains(q) ||
          city.contains(q);
    }).toList();

    final activeCount =
        _facilities.where((f) => f['status'] == 'ACTIVE').length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // Banner Thống kê nhanh cơ sở
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryContainer,
                  AppColors.primaryContainer.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryContainer.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_facilities.length} Cơ sở lưu trữ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$activeCount đang hoạt động • ${_allStaff.length} nhân viên toàn hệ thống',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Thanh tìm kiếm cơ sở
          TextField(
            onChanged: (v) => setState(() => _facilitySearchQuery = v.trim()),
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, mã cơ sở, địa chỉ...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _facilitySearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () =>
                          setState(() => _facilitySearchQuery = ''),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            const AppEmptyState(
              icon: Icons.search_off_rounded,
              title: 'Không tìm thấy cơ sở nào',
              message: 'Hãy thử tìm với từ khóa hoặc mã cơ sở khác.',
            )
          else
            ...filtered.map((f) => _buildFacilityCard(f)),
        ],
      ),
    );
  }

  Widget _buildFacilityCard(Map<String, dynamic> f) {
    final facilityId = f['id']?.toString() ?? '';
    final code = f['code']?.toString() ?? '';
    final name = f['name']?.toString() ?? 'Cơ sở';
    final address = f['address']?.toString() ?? '';
    final city = f['city']?.toString() ?? '';
    final status = f['status']?.toString() ?? 'ACTIVE';
    final managerName = f['managerName']?.toString();
    final contactPhone = f['contactPhone']?.toString() ?? '';
    final staffInFacility = _getStaffForFacility(facilityId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.surfaceContainerHigh),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card: Code & Trạng thái
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _statusColor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _statusColor(status),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tên cơ sở
            Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),

            // Địa chỉ
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 15, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$address${city.isNotEmpty ? ', $city' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),

            if (contactPhone.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.phone_outlined,
                      size: 14, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    contactPhone,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],

            const Divider(height: 20),

            // Quản lý cơ sở & Nhân sự trực thuộc
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.manage_accounts_outlined,
                          size: 16, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          (managerName != null && managerName.isNotEmpty)
                              ? 'Quản lý: $managerName'
                              : 'Chưa có quản lý',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: (managerName != null && managerName.isNotEmpty)
                                ? AppColors.onSurface
                                : AppColors.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge số lượng nhân viên
                InkWell(
                  onTap: () {
                    // Chuyển sang Tab nhân viên và lọc theo cơ sở này
                    setState(() {
                      _staffFacilityFilter = facilityId;
                      _tabController.animateTo(1);
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: staffInFacility.isNotEmpty
                          ? AppColors.primaryContainer.withValues(alpha: 0.1)
                          : AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: staffInFacility.isNotEmpty
                            ? AppColors.primaryContainer.withValues(alpha: 0.4)
                            : AppColors.surfaceContainerHigh,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_alt_outlined,
                          size: 14,
                          color: staffInFacility.isNotEmpty
                              ? AppColors.primaryContainer
                              : AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${staffInFacility.length} nhân viên',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: staffInFacility.isNotEmpty
                                ? AppColors.primaryContainer
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right,
                            size: 14, color: AppColors.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Danh sách nhân viên tóm tắt trực thuộc cơ sở này
            if (staffInFacility.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nhân sự trực thuộc cơ sở này:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: staffInFacility.map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.surfaceContainerHigh),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 8,
                                backgroundColor: AppColors.primaryContainer,
                                child: Text(
                                  s.fullName.isNotEmpty
                                      ? s.fullName.substring(0, 1).toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      fontSize: 8, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                s.fullName.isNotEmpty ? s.fullName : s.username,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: DANH SÁCH NHÂN VIÊN & CƠ SỞ TRỰC THUỘC
  // ==========================================
  Widget _buildStaffTab(int assignedStaffCount) {
    // Lọc theo cơ sở
    var filtered = _allStaff.where((s) {
      if (_staffFacilityFilter == 'ALL') return true;
      if (_staffFacilityFilter == 'UNASSIGNED') {
        return s.facilityId == null || s.facilityId!.isEmpty;
      }
      return s.facilityId == _staffFacilityFilter;
    }).toList();

    // Lọc theo tìm kiếm
    if (_staffSearchQuery.isNotEmpty) {
      final q = _staffSearchQuery.toLowerCase();
      filtered = filtered.where((s) {
        final name = s.fullName.toLowerCase();
        final username = s.username.toLowerCase();
        final email = s.email.toLowerCase();
        final phone = s.phone.toLowerCase();
        final facName = (s.facilityName ?? '').toLowerCase();
        final facCode = (s.facilityCode ?? '').toLowerCase();
        return name.contains(q) ||
            username.contains(q) ||
            email.contains(q) ||
            phone.contains(q) ||
            facName.contains(q) ||
            facCode.contains(q);
      }).toList();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // Banner Thống kê nhân sự
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.secondaryContainer,
                  AppColors.secondaryContainer.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondaryContainer.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.badge_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_allStaff.length} Nhân viên (Staff)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$assignedStaffCount đã gán cơ sở • ${_unassignedStaff.length} chưa phân cơ sở',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Thanh tìm kiếm nhân sự
          TextField(
            onChanged: (v) => setState(() => _staffSearchQuery = v.trim()),
            decoration: InputDecoration(
              hintText: 'Tìm nhân viên theo tên, email, cơ sở...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _staffSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _staffSearchQuery = ''),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),

          // Filter chips theo cơ sở
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('Tất cả (${_allStaff.length})'),
                  selected: _staffFacilityFilter == 'ALL',
                  onSelected: (_) =>
                      setState(() => _staffFacilityFilter = 'ALL'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_unassignedStaff.isNotEmpty) ...[
                        const Icon(Icons.warning_amber_rounded,
                            size: 14, color: AppColors.warning),
                        const SizedBox(width: 4),
                      ],
                      Text('Chưa phân cơ sở (${_unassignedStaff.length})'),
                    ],
                  ),
                  selected: _staffFacilityFilter == 'UNASSIGNED',
                  selectedColor: AppColors.warningContainer,
                  onSelected: (_) =>
                      setState(() => _staffFacilityFilter = 'UNASSIGNED'),
                ),
                for (final fac in _facilities) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                        '${fac['code'] ?? ''} (${_getStaffForFacility(fac['id']?.toString() ?? '').length})'),
                    selected: _staffFacilityFilter == fac['id']?.toString(),
                    onSelected: (_) => setState(
                        () => _staffFacilityFilter = fac['id']?.toString() ?? 'ALL'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            const AppEmptyState(
              icon: Icons.person_off_outlined,
              title: 'Không tìm thấy nhân viên',
              message: 'Không có nhân viên nào phù hợp bộ lọc.',
            )
          else
            ...filtered.map((staff) => _buildStaffCard(staff)),
        ],
      ),
    );
  }

  Widget _buildStaffCard(UserModel staff) {
    final hasFacility = staff.hasFacility;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasFacility
              ? AppColors.surfaceContainerHigh
              : AppColors.warning.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: staff.isActive
                      ? AppColors.primaryContainer
                      : AppColors.outline,
                  child: Text(
                    _initials(
                        staff.fullName.isNotEmpty ? staff.fullName : staff.username),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              staff.fullName.isNotEmpty
                                  ? staff.fullName
                                  : staff.username,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: staff.isActive
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : AppColors.outline.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              staff.isActive ? 'Đang làm việc' : 'Đã nghỉ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: staff.isActive
                                    ? AppColors.success
                                    : AppColors.outline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${staff.username} • ${staff.email}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      if (staff.phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined,
                                size: 12, color: AppColors.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              staff.phone,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // KHỐI HIỂN THỊ CƠ SỞ TRỰC THUỘC (HIỆN LÊN CHO RÕ)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: hasFacility
                    ? AppColors.primaryContainer.withValues(alpha: 0.08)
                    : AppColors.warningContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasFacility
                      ? AppColors.primaryContainer.withValues(alpha: 0.25)
                      : AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasFacility
                        ? Icons.storefront_rounded
                        : Icons.warning_amber_rounded,
                    size: 18,
                    color: hasFacility
                        ? AppColors.primaryContainer
                        : AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasFacility ? 'Cơ sở trực thuộc:' : 'Tình trạng cơ sở:',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: hasFacility
                                ? AppColors.primaryContainer
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          staff.facilityDisplayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: hasFacility
                                ? AppColors.onSurface
                                : AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
