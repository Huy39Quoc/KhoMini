import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/safe_dispose.dart';
import '../../models/facility_management_models.dart';
import '../../models/unit_type_model.dart';
import '../../models/user_model.dart';
import '../../services/catalog_api_service.dart';
import '../../services/facility_ops_api_service.dart';
import '../../widgets/state_views.dart';
import '../common/profile_screen.dart';
import '../common/transaction_history_screen.dart';
import '../common/gate_pass_verify_screen.dart';
import 'booking_assignment_screen.dart';
import 'appointment_assignment_screen.dart';
import 'refund_review_screen.dart';
import 'facility_contracts_tab.dart';
import 'facility_tickets_tab.dart';

class ManagerDashboardScreen extends StatefulWidget {
  final UserModel user;

  const ManagerDashboardScreen({
    super.key,
    required this.user,
  });

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen>
    with SingleTickerProviderStateMixin {
  final FacilityOpsApiService _opsService = FacilityOpsApiService();

  final CatalogApiService _catalogService = CatalogApiService();

  late final TabController _tabController;

  bool _isLoadingFacility = true;

  String? _facilityId;
  String? _facilityName;
  String? _facilityError;

  Future<List<FacilityUnitModel>>? _unitsFuture;
  Future<List<FacilityStaffModel>>? _staffFuture;
  Future<FacilityReportModel>? _reportFuture;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 5,
      vsync: this,
    );

    _tabController.addListener(
      _handleTabChanged,
    );

    _loadFacility();
  }

  @override
  void dispose() {
    _tabController.removeListener(
      _handleTabChanged,
    );
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadFacility() async {
    setState(() {
      _isLoadingFacility = true;
      _facilityError = null;
    });

    try {
      final facility = await _opsService.getAssignedFacility();

      if (!mounted) {
        return;
      }

      setState(() {
        _facilityId = facility.id;
        _facilityName = facility.name;
        _isLoadingFacility = false;
      });

      if (facility.id.isNotEmpty) {
        _loadAll();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _facilityError = _errorMessage(error);
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
    final facilityId = _facilityId;

    if (facilityId == null || facilityId.isEmpty) {
      return;
    }

    setState(() {
      _unitsFuture = _opsService.getFacilityUnits(facilityId);
    });
  }

  void _loadStaff() {
    final facilityId = _facilityId;

    if (facilityId == null || facilityId.isEmpty) {
      return;
    }

    setState(() {
      _staffFuture = _opsService.getFacilityStaff(facilityId);
    });
  }

  void _loadReport() {
    final facilityId = _facilityId;

    if (facilityId == null || facilityId.isEmpty) {
      return;
    }

    setState(() {
      _reportFuture = _opsService.getFacilityManagerReport(facilityId);
    });
  }

  Future<void> _refreshUnits() async {
    _loadUnits();

    try {
      await _unitsFuture;
    } catch (_) {
    }
  }

  Future<void> _refreshStaff() async {
    _loadStaff();

    try {
      await _staffFuture;
    } catch (_) {
    }
  }

  Future<void> _refreshReport() async {
    _loadReport();

    try {
      await _reportFuture;
    } catch (_) {
    }
  }

  Future<void> _changeUnitStatus(FacilityUnitModel unit) async {
    final facilityId = _facilityId;

    if (facilityId == null || facilityId.isEmpty) {
      return;
    }

    final target =
        unit.status == 'AVAILABLE' ? 'UNDER_MAINTENANCE' : 'AVAILABLE';

    try {
      await _opsService.updateUnitStatus(
        unitId: unit.id,
        facilityId: facilityId,
        status: target,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            target == 'UNDER_MAINTENANCE'
                ? 'Đã đánh dấu ngăn ${unit.unitCode} cần kiểm tra'
                : 'Ngăn ${unit.unitCode} đã sẵn sàng cho thuê',
          ),
          backgroundColor: AppColors.success,
        ),
      );

      _loadUnits();
      _loadReport();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(_errorMessage(error));
    }
  }

  Future<List<UnitTypeModel>> _loadUnitTypes() async {
    final values = await _catalogService.getUnitTypes(
      facilityId: _facilityId,
    );

    return values.whereType<Map>().map((value) {
      return UnitTypeModel.fromJson(
        Map<String, dynamic>.from(value),
      );
    }).toList();
  }

  Future<void> _openUnitSheet({
    FacilityUnitModel? unit,
  }) async {
    List<UnitTypeModel> unitTypes;

    try {
      unitTypes = await _loadUnitTypes();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        'Không tải được loại kho: '
        '${_errorMessage(error)}',
      );
      return;
    }

    if (unitTypes.isEmpty) {
      if (!mounted) {
        return;
      }

      _showError(
        'Chưa có loại kho nào.',
      );
      return;
    }

    final unitCodeController = TextEditingController(
      text: unit?.unitCode ?? '',
    );

    final floorController = TextEditingController(
      text: unit?.floorLevel ?? '',
    );

    String? selectedTypeId = unit?.unitTypeId.isNotEmpty == true
        ? unit!.unitTypeId
        : unitTypes.first.id;

    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
            sheetContext,
            setSheetState,
          ) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(
                  sheetContext,
                ).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        unit == null
                            ? 'Ngăn kho mới'
                            : 'Sửa ngăn ${unit.unitCode}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: unitCodeController,
                        enabled: !submitting,
                        decoration: const InputDecoration(
                          labelText: 'Mã ngăn kho',
                          hintText: 'Ví dụ: A-101',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập mã ngăn kho';
                          }

                          if (value.trim().length > 30) {
                            return 'Tối đa 30 ký tự';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: floorController,
                        enabled: !submitting,
                        decoration: const InputDecoration(
                          labelText: 'Tầng / khu vực (không bắt buộc)',
                          hintText: 'Ví dụ: Tầng 2',
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedTypeId,
                        decoration: const InputDecoration(
                          labelText: 'Loại kho',
                        ),
                        items: unitTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type.id,
                            child: Text(type.name),
                          );
                        }).toList(),
                        onChanged: submitting
                            ? null
                            : (value) {
                                setSheetState(() {
                                  selectedTypeId = value;
                                });
                              },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng chọn loại kho';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) {
                                  return;
                                }

                                setSheetState(() {
                                  submitting = true;
                                });

                                try {
                                  if (unit == null) {
                                    await _opsService.createFacilityUnit(
                                      _facilityId!,
                                      unitCode: unitCodeController.text.trim(),
                                      floorLevel: floorController.text.trim(),
                                      unitTypeId: selectedTypeId!,
                                    );
                                  } else {
                                    await _opsService.updateFacilityUnit(
                                      _facilityId!,
                                      unit.id,
                                      unitCode: unitCodeController.text.trim(),
                                      floorLevel: floorController.text.trim(),
                                      unitTypeId: selectedTypeId!,
                                    );
                                  }

                                  if (!sheetContext.mounted) {
                                    return;
                                  }

                                  Navigator.pop(
                                    sheetContext,
                                  );

                                  if (!mounted) {
                                    return;
                                  }

                                  _showSuccess(
                                    unit == null
                                        ? 'Đã tạo ngăn kho'
                                        : 'Đã cập nhật ngăn kho',
                                  );

                                  _loadUnits();
                                  _loadReport();
                                } catch (error) {
                                  if (!sheetContext.mounted) {
                                    return;
                                  }

                                  setSheetState(() {
                                    submitting = false;
                                  });

                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _errorMessage(
                                          error,
                                        ),
                                      ),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              },
                        child: submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                unit == null ? 'Tạo ngăn kho' : 'Lưu thay đổi',
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openAssignStaffSheet() async {
    List<AssignableUserModel> users;
    List<FacilityStaffModel> currentStaff;

    try {
      users = await _opsService.getAssignableUsers(_facilityId!);

      currentStaff = await _opsService.getFacilityStaff(
        _facilityId!,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        'Không tải được người dùng: '
        '${_errorMessage(error)}',
      );
      return;
    }

    final assignedIds = currentStaff.map((staff) => staff.id).toSet();

    users = users
        .where(
          (user) => !assignedIds.contains(user.id),
        )
        .toList();

    final searchController = TextEditingController();

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
            sheetContext,
            setSheetState,
          ) {
            final query = searchController.text.trim().toLowerCase();

            final filteredUsers = users.where((user) {
              if (query.isEmpty) {
                return true;
              }

              final searchText = [
                user.fullName,
                user.username,
                user.email,
              ].join(' ').toLowerCase();

              return searchText.contains(query);
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(
                  sheetContext,
                ).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(
                      sheetContext,
                    ).size.height *
                    0.7,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thêm nhân viên',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Chỉ có thể thêm người dùng có vai trò Nhân viên.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: searchController,
                            onChanged: (_) {
                              setSheetState(() {});
                            },
                            decoration: const InputDecoration(
                              hintText: 'Tìm theo tên hoặc email',
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: filteredUsers.isEmpty
                          ? const AppEmptyState(
                              icon: Icons.person_search,
                              title: 'Không tìm thấy người dùng',
                              message: 'Không có người dùng nào phù hợp.',
                            )
                          : ListView.builder(
                              itemCount: filteredUsers.length,
                              itemBuilder: (
                                context,
                                index,
                              ) {
                                final user = filteredUsers[index];

                                return ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(
                                      Icons.person,
                                    ),
                                  ),
                                  title: Text(
                                    user.displayName,
                                  ),
                                  subtitle: Text(
                                    user.email,
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                  ),
                                  onTap: () async {
                                    try {
                                      await _opsService.assignStaffToFacility(
                                        _facilityId!,
                                        user.id,
                                      );

                                      if (!sheetContext.mounted) {
                                        return;
                                      }

                                      Navigator.pop(
                                        sheetContext,
                                      );

                                      if (!mounted) {
                                        return;
                                      }

                                      _showSuccess(
                                        'Đã gán vai trò cho ${user.displayName}',
                                      );

                                      _loadStaff();
                                    } catch (error) {
                                      if (!sheetContext.mounted) {
                                        return;
                                      }

                                      ScaffoldMessenger.of(
                                        sheetContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            _errorMessage(
                                              error,
                                            ),
                                          ),
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
        );
      },
    );

    disposeAfterRouteCloses([searchController]);
  }

  Future<void> _removeStaff(
    FacilityStaffModel staff,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Gỡ nhân viên này?',
          ),
          content: Text(
            '${staff.fullName} sẽ không còn được '
            'được gán cho cơ sở này.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Gỡ'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _opsService.unassignStaff(
        _facilityId!,
        staff.id,
      );

      if (!mounted) {
        return;
      }

      _showSuccess(
        'Đã gỡ ${staff.fullName}',
      );

      _loadStaff();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(_errorMessage(error));
    }
  }

  Color _unitStatusColor(String status) {
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

  String _errorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          (_facilityName == null || _facilityName!.isEmpty)
              ? 'Bảng điều khiển quản lý cơ sở'
              : _facilityName!,
        ),
        actions: [
          if (_facilityId != null && _facilityId!.isNotEmpty)
            IconButton(
              tooltip: 'Kiểm tra QR cổng',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) =>
                    GatePassVerifyScreen(facilityId: _facilityId!)),
              ),
            ),
          if (_facilityId != null && _facilityId!.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Quản lý lịch, đơn, hoàn tiền và giao dịch',
              icon: const Icon(Icons.more_vert),
              onSelected: (action) {
                final facilityId = _facilityId!;
                switch (action) {
                  case 'refunds':
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => RefundReviewScreen(facilityId: facilityId)));
                    return;
                  case 'appointments':
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => AppointmentAssignmentScreen(facilityId: facilityId)));
                    return;
                  case 'bookings':
                    final route = MaterialPageRoute(
                      builder: (_) => BookingAssignmentScreen(
                        facilityId: facilityId,
                        facilityName: _facilityName ?? '',
                      ),
                    );
                    Navigator.push(context, route).then((_) {
                      if (!mounted) return;
                      _loadUnits();
                      _loadReport();
                    });
                    return;
                  case 'transactions':
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => TransactionHistoryScreen(
                        userRole: widget.user.roleName, facilityId: facilityId)));
                    return;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'appointments', child: Text('Phân công nhân viên bàn giao')),
                PopupMenuItem(value: 'bookings', child: Text('Xác nhận ngăn kho cho đơn')),
                PopupMenuItem(value: 'refunds', child: Text('Hoàn cọc cho khách')),
                PopupMenuItem(value: 'transactions', child: Text('Lịch sử giao dịch')),
              ],
            ),
          IconButton(
            tooltip: 'Hồ sơ',
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                widget.user.fullName.isNotEmpty
                    ? widget.user.fullName.substring(0, 1).toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    user: widget.user,
                    facilityId: _facilityId,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
        bottom: _facilityId != null && _facilityId!.isNotEmpty
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.secondaryContainer,
                unselectedLabelColor: AppColors.onSurfaceVariant,
                indicatorColor: AppColors.secondaryContainer,
                tabs: const [
                  Tab(text: 'Ngăn kho'),
                  Tab(text: 'Nhân viên'),
                  Tab(text: 'Hợp đồng'),
                  Tab(text: 'Hỗ trợ'),
                  Tab(text: 'Báo cáo'),
                ],
              )
            : null,
      ),
      body: _buildBody(),
      floatingActionButton: _facilityId != null &&
              _facilityId!.isNotEmpty &&
              _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                _openUnitSheet();
              },
              icon: const Icon(Icons.add),
              label: const Text('Thêm ngăn kho'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoadingFacility) {
      return const AppLoadingState(
        message: 'Đang tải cơ sở của bạn...',
      );
    }

    if (_facilityError != null) {
      return AppErrorState(
        message: _facilityError!,
        onRetry: _loadFacility,
      );
    }

    if (_facilityId == null || _facilityId!.isEmpty) {
      return const AppEmptyState(
        icon: Icons.storefront_outlined,
        title: 'Chưa được gán cơ sở',
        message: 'Hãy nhờ quản trị viên gán bạn vào một cơ sở.',
      );
    }

    return Column(
      children: [
        _buildWorkflowBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUnitsTab(),
              _buildStaffTab(),
              FacilityContractsTab(facilityId: _facilityId!),
              FacilityTicketsTab(facilityId: _facilityId!),
              _buildReportTab(),
            ],
          ),
        ),
      ],
    );
  }

  void _openBookingAssignment() {
    final facilityId = _facilityId!;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingAssignmentScreen(
          facilityId: facilityId,
          facilityName: _facilityName ?? '',
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      _loadUnits();
      _loadReport();
    });
  }

  void _openAppointments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppointmentAssignmentScreen(facilityId: _facilityId!),
      ),
    );
  }

  void _openRefunds() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RefundReviewScreen(facilityId: _facilityId!),
      ),
    );
  }

  /// Các bước điều phối của quản lý cơ sở, theo đúng thứ tự nghiệp vụ:
  /// khách đặt cọc -> xác nhận ngăn kho -> phân công nhân viên bàn giao
  /// -> nhân viên bàn giao/nghiệm thu -> quản lý hoàn cọc.
  Widget _buildWorkflowBar() {
    Widget step(int no, IconData icon, String title, String hint,
        VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceContainerHigh),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: AppColors.primaryContainer,
                  child: Text('$no',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 6),
                Icon(icon, size: 18, color: AppColors.secondaryContainer),
                const SizedBox(height: 4),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(hint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quy trình bàn giao kho',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            children: [
              step(1, Icons.assignment_turned_in_outlined, 'Xác nhận\nngăn kho',
                  'Khách đã cọc', _openBookingAssignment),
              const SizedBox(width: 8),
              step(2, Icons.event_available_outlined, 'Phân công\nnhân viên',
                  'Lịch bàn giao', _openAppointments),
              const SizedBox(width: 8),
              step(3, Icons.payments_outlined, 'Hoàn cọc\nsau trả kho',
                  'Nhân viên đã nghiệm thu', _openRefunds),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnitsTab() {
    return FutureBuilder<List<FacilityUnitModel>>(
      future: _unitsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(
            message: 'Đang tải ngăn kho...',
          );
        }

        if (snapshot.hasError) {
          return AppErrorState(
            message: _errorMessage(
              snapshot.error!,
            ),
            onRetry: _loadUnits,
          );
        }

        final units = snapshot.data ?? <FacilityUnitModel>[];

        if (units.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refreshUnits,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Chưa có ngăn kho',
                  message: 'Chạm "Thêm ngăn kho" để thêm ngăn đầu tiên.',
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshUnits,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              90,
            ),
            itemCount: units.length,
            itemBuilder: (context, index) {
              final unit = units[index];
              final color = _unitStatusColor(unit.status);

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () {
                    _openUnitSheet(unit: unit);
                  },
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(
                      Icons.inventory_2,
                      color: color,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    'Ngăn ${unit.unitCode}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    [
                      unit.unitType,
                      if (unit.floorLevel.isNotEmpty) unit.floorLevel,
                    ].join(' • '),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          unit.statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      if (unit.status == 'AVAILABLE' ||
                          unit.status == 'UNDER_MAINTENANCE')
                        IconButton(
                          tooltip: unit.status == 'AVAILABLE'
                              ? 'Đánh dấu cần kiểm tra'
                              : 'Đánh dấu đã sẵn sàng',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            unit.status == 'AVAILABLE'
                                ? Icons.build_outlined
                                : Icons.check_circle_outline,
                            size: 18,
                          ),
                          onPressed: () => _changeUnitStatus(unit),
                        ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.edit_outlined,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStaffTab() {
    return FutureBuilder<List<FacilityStaffModel>>(
      future: _staffFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(
            message: 'Đang tải nhân viên...',
          );
        }

        if (snapshot.hasError) {
          return AppErrorState(
            message: _errorMessage(
              snapshot.error!,
            ),
            onRetry: _loadStaff,
          );
        }

        final staffList = snapshot.data ?? <FacilityStaffModel>[];

        return RefreshIndicator(
          onRefresh: _refreshStaff,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              24,
            ),
            children: [
              OutlinedButton.icon(
                onPressed: _openAssignStaffSheet,
                icon: const Icon(
                  Icons.person_add_alt,
                ),
                label: const Text('Thêm nhân viên'),
              ),
              const SizedBox(height: 12),
              if (staffList.isEmpty)
                const AppEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'Chưa có nhân viên',
                  message: 'Thêm nhân viên để họ phụ trách bàn giao kho.',
                )
              else
                ...staffList.map((staff) {
                  return Card(
                    margin: const EdgeInsets.only(
                      bottom: 10,
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(
                        staff.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        staff.email,
                        style: const TextStyle(
                          fontSize: 12,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            staff.role,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Gỡ khỏi cơ sở',
                            onPressed: () {
                              _removeStaff(staff);
                            },
                            icon: const Icon(
                              Icons.person_remove_outlined,
                              size: 18,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportTab() {
    return FutureBuilder<FacilityReportModel>(
      future: _reportFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(
            message: 'Đang tải báo cáo...',
          );
        }

        if (snapshot.hasError) {
          return AppErrorState(
            message: _errorMessage(
              snapshot.error!,
            ),
            onRetry: _loadReport,
          );
        }

        final report = snapshot.data;

        if (report == null) {
          return AppErrorState(
            message: 'Chưa có báo cáo của cơ sở.',
            onRetry: _loadReport,
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshReport,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                    const Text(
                      'Tỷ lệ lấp đầy',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${report.occupancyRate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (report.occupancyRate / 100).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.secondaryContainer,
                        ),
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
                  _statTile(
                    'Tổng số ngăn',
                    '${report.total}',
                    Icons.grid_view,
                    AppColors.primaryContainer,
                  ),
                  _statTile(
                    'Còn trống',
                    '${report.available}',
                    Icons.check_circle_outline,
                    AppColors.success,
                  ),
                  _statTile(
                    'Đang thuê',
                    '${report.occupied}',
                    Icons.lock_outline,
                    AppColors.error,
                  ),
                  _statTile(
                    'Đã giữ chỗ',
                    '${report.reserved}',
                    Icons.schedule,
                    AppColors.warning,
                  ),
                  _statTile(
                    'Bảo trì',
                    '${report.underMaintenance}',
                    Icons.build_outlined,
                    AppColors.secondary,
                  ),
                  _statTile(
                    'Quá hạn',
                    '${report.overdueBookings}',
                    Icons.warning_amber_rounded,
                    AppColors.error,
                  ),
                  _statTile(
                    'Doanh thu (đã thu)',
                    NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
                        .format(report.revenue),
                    Icons.attach_money,
                    AppColors.success,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.surfaceContainerHigh,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
