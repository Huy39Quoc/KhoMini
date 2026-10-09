import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/booking_api_service.dart';
import '../../../services/auth_api_service.dart';
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
  final BookingApiService _bookingService = BookingApiService();
  late Future<List<MyUnitModel>> _unitsFuture;
  final _currency = NumberFormat.currency(
      locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
  final _dateFmt = DateFormat('MMM d, yyyy');
  final _dateTimeFmt = DateFormat('MMM d, yyyy • h:mm a');

  // Chỉ gia hạn khi đã nhận kho; nếu đang treo yêu cầu gia hạn thì vẫn cho mở lại
  // để thanh toán/hủy; nợ phí trễ hạn thì phải trả trước.
  bool _canExtend(MyUnitModel unit) =>
      unit.isActive && (unit.hasPendingExtension || !unit.hasLateFeeDue);

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
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
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
                  child:
                      const Icon(Icons.key, color: AppColors.primaryContainer),
                ),
                title: const Text('Smart Access (PIN)'),
                enabled: unit.hasActiveAccess,
                subtitle: unit.hasActiveAccess
                    ? null
                    : Text(unit.accessDisabled
                        ? 'Access disabled - rental is overdue'
                        : 'Available after check-in at the facility'),
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
              if (unit.hasLateFeeDue)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.payments_outlined,
                        color: AppColors.error),
                  ),
                  title: const Text('Pay Late Fee'),
                  subtitle: Text(
                      '${_currency.format(unit.overdueFeeOutstanding)} outstanding'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openContractOperation(unit,
                        isExtension: false, payOverdue: true);
                  },
                ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.update,
                      color: AppColors.primaryContainer),
                ),
                title: const Text('Extend Rental'),
                enabled: _canExtend(unit),
                subtitle: !unit.isActive
                    ? const Text('Available after check-in at the facility')
                    : unit.hasPendingExtension
                        ? const Text('Resume or cancel your pending extension')
                        : unit.hasLateFeeDue
                            ? const Text('Pay the outstanding late fee first')
                            : null,
                onTap: _canExtend(unit)
                    ? () {
                        Navigator.pop(ctx);
                        _openContractOperation(
                          unit,
                          isExtension: true,
                          resumePending: unit.hasPendingExtension,
                        );
                      }
                    : null,
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
                title: Text(unit.scheduledReturnTime != null
                    ? 'Reschedule Checkout'
                    : 'Request Checkout'),
                enabled: unit.isActive,
                subtitle: unit.isActive
                    ? (unit.scheduledReturnTime != null
                        ? Text(
                            'Currently ${_dateTimeFmt.format(unit.scheduledReturnTime!)}')
                        : null)
                    : const Text('Available after check-in at the facility'),
                onTap: unit.isActive
                    ? () {
                        Navigator.pop(ctx);
                        _openContractOperation(unit, isExtension: false);
                      }
                    : null,
              ),
              if (unit.status == 'CONFIRMED')
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cancel_outlined,
                        color: AppColors.error),
                  ),
                  title: const Text('Cancel Booking'),
                  subtitle: const Text(
                      'Deposit is refunded per the facility cancellation policy'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmCancelBooking(unit);
                  },
                ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.report_problem_outlined,
                      color: AppColors.secondary),
                ),
                title: const Text('Report an Issue'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateTicketScreen(
                        preselectedBookingId: unit.bookingId,
                        preselectedUnitLabel:
                            '${unit.unitCode} • ${unit.facilityName}',
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

  Future<void> _confirmCancelBooking(MyUnitModel unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: Text(
          'Booking ${unit.bookingCode} (unit ${unit.unitCode}) will be '
          'cancelled and the unit released. Your deposit is refunded '
          'according to the facility cancellation policy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep booking'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _bookingService.cancelBooking(unit.bookingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking cancelled'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadUnits();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openContractOperation(
    MyUnitModel unit, {
    required bool isExtension,
    bool resumePending = false,
    bool payOverdue = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ContractOperationDialog(
        unit: unit,
        isExtension: isExtension,
        resumePending: resumePending,
        payOverdue: payOverdue,
      ),
    );
    if (result == true) {
      _loadUnits();
    }
  }

  void _logout(BuildContext context) async {
    await AuthApiService().logout();

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  Color _statusColor(String status) {
    if (status == 'OVERDUE') return AppColors.error;
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
                    message:
                        snapshot.error.toString().replaceAll('Exception: ', ''),
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
                        child: const Icon(Icons.inventory_2,
                            color: AppColors.secondaryContainer, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$activeCount active of ${units.length} unit${units.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                            const Text(
                              'Tap a unit to access its smart key, extend, or report an issue',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11),
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
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          unit.dimensions.isNotEmpty
                              ? '${unit.typeName} • ${unit.dimensions}'
                              : unit.typeName,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          _statusColor(unit.overdue ? 'OVERDUE' : unit.status)
                              .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      unit.overdue
                          ? 'OVERDUE'
                          : unit.status.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _statusColor(
                            unit.overdue ? 'OVERDUE' : unit.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      unit.facilityName.isNotEmpty
                          ? '${unit.facilityName}${unit.facilityAddress.isNotEmpty ? ', ${unit.facilityAddress}' : ''}'
                          : 'Facility not specified',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (unit.overdue || unit.accessDisabled) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: AppColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [
                            'Rental overdue${unit.overdueDays > 0 ? ' by ${unit.overdueDays} day(s)' : ''}.',
                            if (unit.hasLateFeeDue)
                              'Late fee due: ${_currency.format(unit.overdueFeeOutstanding)}.',
                            if (unit.accessDisabled)
                              'Smart access has been disabled.',
                            'Pay the fee, then extend or return the unit.',
                          ].join(' '),
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (unit.isActive && unit.scheduledReturnTime != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available,
                          size: 16, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Checkout scheduled for ${_dateTimeFmt.format(unit.scheduledReturnTime!)}',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (unit.hasPendingExtension) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_top,
                          size: 16, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          unit.pendingExtensionFee != null
                              ? 'Extension of ${unit.pendingExtraMonths ?? '?'} month(s) awaiting payment '
                                  '(${_currency.format(unit.pendingExtensionFee)}). Tap "Extend Rental" to pay or cancel it.'
                              : 'You have an extension request awaiting payment.',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.onSurfaceVariant)),
                            Text(_currency.format(monthlyRate),
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ends on',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.onSurfaceVariant)),
                          Text(
                            unit.endDate != null
                                ? _dateFmt.format(unit.endDate!)
                                : '-',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
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
                      label: const Text('Smart Key',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showUnitActions(unit),
                      icon: const Icon(Icons.more_horiz, size: 16),
                      label:
                          const Text('Manage', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40)),
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
