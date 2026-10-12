import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
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
                ? 'Unit ${unit.unitCode} marked for inspection'
                : 'Unit ${unit.unitCode} is available again',
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
        'Could not load unit types: '
        '${_errorMessage(error)}',
      );
      return;
    }

    if (unitTypes.isEmpty) {
      if (!mounted) {
        return;
      }

      _showError(
        'No unit types are defined yet.',
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
                            ? 'New Storage Unit'
                            : 'Edit Unit ${unit.unitCode}',
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
                          labelText: 'Unit code',
                          hintText: 'Example: A-101',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Unit code is required';
                          }

                          if (value.trim().length > 30) {
                            return 'Maximum 30 characters';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: floorController,
                        enabled: !submitting,
                        decoration: const InputDecoration(
                          labelText: 'Floor / level (optional)',
                          hintText: 'Example: Floor 2',
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedTypeId,
                        decoration: const InputDecoration(
                          labelText: 'Unit type',
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
                            return 'Unit type is required';
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
                                        ? 'Unit created successfully'
                                        : 'Unit updated successfully',
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
                                unit == null ? 'Create Unit' : 'Save Changes',
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
        'Could not load users: '
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
                            'Assign Staff',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Only users with the STAFF role can be assigned.',
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
                              hintText: 'Search name or email',
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
                              title: 'No users found',
                              message: 'No active users match your search.',
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
                                        '${user.displayName} assigned successfully',
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

    searchController.dispose();
  }

  Future<void> _removeStaff(
    FacilityStaffModel staff,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Remove staff member?',
          ),
          content: Text(
            '${staff.fullName} will no longer be '
            'assigned to this facility.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
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
              child: const Text('Remove'),
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
        '${staff.fullName} removed',
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
              ? 'Facility Manager Console'
              : _facilityName!,
        ),
        actions: [
          if (_facilityId != null && _facilityId!.isNotEmpty)
            IconButton(
              tooltip: 'Verify gate QR',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) =>
                    GatePassVerifyScreen(facilityId: _facilityId!)),
              ),
            ),
          if (_facilityId != null && _facilityId!.isNotEmpty)
            IconButton(
              tooltip: 'Refund requests',
              icon: const Icon(Icons.currency_exchange_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RefundReviewScreen(facilityId: _facilityId!),
                ),
              ),
            ),
          if (_facilityId != null && _facilityId!.isNotEmpty)
            IconButton(
              tooltip: 'Handover appointments',
              icon: const Icon(Icons.event_note_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppointmentAssignmentScreen(
                    facilityId: _facilityId!,
                  ),
                ),
              ),
            ),
          if (_facilityId != null && _facilityId!.isNotEmpty)
            IconButton(
              tooltip: 'Confirmed bookings',
              icon: const Icon(Icons.swap_horiz_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingAssignmentScreen(
                      facilityId: _facilityId!,
                      facilityName: _facilityName ?? '',
                    ),
                  ),
                ).then((_) {
                  if (!mounted) return;
                  _loadUnits();
                  _loadReport();
                });
              },
            ),
          if (_facilityId != null && _facilityId!.isNotEmpty)
            IconButton(
              tooltip: 'Facility Transactions',
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionHistoryScreen(
                      userRole: widget.user.roleName,
                      facilityId: _facilityId,
                    ),
                  ),
                );
              },
            ),
          IconButton(
            tooltip: 'Profile',
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
                  Tab(text: 'Units'),
                  Tab(text: 'Staff'),
                  Tab(text: 'Contracts'),
                  Tab(text: 'Tickets'),
                  Tab(text: 'Report'),
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
              label: const Text('New Unit'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoadingFacility) {
      return const AppLoadingState(
        message: 'Loading your facility...',
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
        title: 'No facility assigned',
        message: 'Ask an administrator to assign you to a facility.',
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildUnitsTab(),
        _buildStaffTab(),
        FacilityContractsTab(facilityId: _facilityId!),
        FacilityTicketsTab(facilityId: _facilityId!),
        _buildReportTab(),
      ],
    );
  }

  Widget _buildUnitsTab() {
    return FutureBuilder<List<FacilityUnitModel>>(
      future: _unitsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(
            message: 'Loading units...',
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
                  title: 'No storage units yet',
                  message: 'Tap "New Unit" to add the first unit.',
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
                    'Unit ${unit.unitCode}',
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
                              ? 'Mark for inspection'
                              : 'Mark available',
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
            message: 'Loading staff...',
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
                label: const Text('Assign Staff'),
              ),
              const SizedBox(height: 12),
              if (staffList.isEmpty)
                const AppEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No staff assigned',
                  message: 'Assign staff so they can handle check-ins.',
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
                            tooltip: 'Remove from facility',
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
            message: 'Loading report...',
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
            message: 'Facility report is unavailable.',
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
                      'Occupancy Rate',
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
                    'Total Units',
                    '${report.total}',
                    Icons.grid_view,
                    AppColors.primaryContainer,
                  ),
                  _statTile(
                    'Available',
                    '${report.available}',
                    Icons.check_circle_outline,
                    AppColors.success,
                  ),
                  _statTile(
                    'Occupied',
                    '${report.occupied}',
                    Icons.lock_outline,
                    AppColors.error,
                  ),
                  _statTile(
                    'Reserved',
                    '${report.reserved}',
                    Icons.schedule,
                    AppColors.warning,
                  ),
                  _statTile(
                    'Maintenance',
                    '${report.underMaintenance}',
                    Icons.build_outlined,
                    AppColors.secondary,
                  ),
                  _statTile(
                    'Overdue',
                    '${report.overdueBookings}',
                    Icons.warning_amber_rounded,
                    AppColors.error,
                  ),
                  _statTile(
                    'Revenue (paid)',
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
