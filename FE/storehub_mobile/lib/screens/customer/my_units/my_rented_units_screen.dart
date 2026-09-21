import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/storage_api_service.dart';
import '../../../models/my_unit_model.dart';
import '../../../widgets/state_views.dart';
import '../tickets/create_ticket_screen.dart';
import 'contract_operation_dialog.dart';
import 'smart_key_screen.dart';

class MyRentedUnitsScreen extends StatefulWidget {
  const MyRentedUnitsScreen({super.key});

  @override
  State<MyRentedUnitsScreen> createState() => _MyRentedUnitsScreenState();
}

class _MyRentedUnitsScreenState extends State<MyRentedUnitsScreen> {
  final StorageApiService _storageService = StorageApiService();
  late Future<List<MyUnitModel>> _unitsFuture;
  final _currency = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final _dateFmt = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  void _loadUnits() {
    setState(() {
      _unitsFuture = _storageService.getMyRentedUnits().then((response) {
        return response.map((item) {
          if (item is MyUnitModel) return item;
          return MyUnitModel.fromJson(item as Map<String, dynamic>);
        }).toList();
      });
    });
  }

  void _showUnitActions(MyUnitModel unit) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Unit ${unit.unitCode}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.key, color: AppColors.primaryContainer),
                ),
                title: const Text('Smart Access (PIN / QR)'),
                enabled: unit.hasActiveAccess,
                subtitle: unit.hasActiveAccess ? null : const Text('Not available for this unit'),
                onTap: unit.hasActiveAccess
                    ? () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SmartKeyScreen(
                              bookingId: unit.bookingId,
                              unitNumber: unit.unitCode,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.update, color: AppColors.primaryContainer),
                ),
                title: const Text('Extend Rental'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openContractOperation(unit, isExtension: true);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout, color: AppColors.error),
                ),
                title: const Text('Request Checkout'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openContractOperation(unit, isExtension: false);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.report_problem_outlined, color: AppColors.secondary),
                ),
                title: const Text('Report an Issue'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateTicketScreen(
                        preselectedBookingId: unit.bookingId,
                        preselectedUnitLabel: '${unit.unitCode} • ${unit.facilityName}',
                      ),
                    ),
                  );
                  if (result == true) _loadUnits();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openContractOperation(
    MyUnitModel unit, {
    required bool isExtension,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ContractOperationDialog(
        unit: unit,
        isExtension: isExtension,
      ),
    );
    if (result == true) {
      _loadUnits();
    }
  }

  void _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return AppColors.success;
      case 'CONFIRMED':
        return AppColors.secondaryContainer;
      case 'PENDING_PAYMENT':
        return AppColors.warning;
      case 'COMPLETED':
        return AppColors.outline;
      case 'CANCELLED':
        return AppColors.error;
      default:
        return AppColors.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('My Storage Units'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUnits,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadUnits(),
        child: FutureBuilder<List<MyUnitModel>>(
          future: _unitsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingState(message: 'Loading your units...');
            } else if (snapshot.hasError) {
              return ListView(
                children: [
                  AppErrorState(
                    message: snapshot.error.toString().replaceAll('Exception: ', ''),
                    onRetry: _loadUnits,
                  ),
                ],
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return ListView(
                children: const [
                  AppEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No rented storage units yet',
                    message: 'Units you rent will show up here.',
                  ),
                ],
              );
            }

            final units = snapshot.data!;
            final activeCount = units.where((u) => u.status == 'ACTIVE').length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.inventory_2, color: AppColors.secondaryContainer, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$activeCount active of ${units.length} unit${units.length == 1 ? '' : 's'}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const Text(
                              'Tap a unit to access its smart key, extend, or report an issue',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                ...units.map((unit) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildUnitCard(unit),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildUnitCard(MyUnitModel unit) {
    final monthlyRate = unit.monthlyRate;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showUnitActions(unit),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Unit ${unit.unitCode}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          unit.dimensions.isNotEmpty
                              ? '${unit.typeName} • ${unit.dimensions}'
                              : unit.typeName,
                          style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(unit.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      unit.status.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _statusColor(unit.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      unit.facilityName.isNotEmpty
                          ? '${unit.facilityName}${unit.facilityAddress.isNotEmpty ? ', ${unit.facilityAddress}' : ''}'
                          : 'Facility not specified',
                      style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    if (monthlyRate != null) ...[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Monthly rate',
                                style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
                            Text(_currency.format(monthlyRate),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ends on',
                              style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
                          Text(
                            unit.endDate != null ? _dateFmt.format(unit.endDate!) : '-',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: unit.hasActiveAccess
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SmartKeyScreen(
                                    bookingId: unit.bookingId,
                                    unitNumber: unit.unitCode,
                                  ),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.key, size: 16),
                      label: const Text('Smart Key', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showUnitActions(unit),
                      icon: const Icon(Icons.more_horiz, size: 16),
                      label: const Text('Manage', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
