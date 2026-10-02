import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/facility_admin_api_service.dart';
import '../../widgets/state_views.dart';

/// Wires GET /reports/revenue and GET /reports/occupancy
/// (ReportController) - real system-wide + per-facility numbers, replacing
/// the "not available" placeholder that used to live on the Operations
/// dashboard.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  final FacilityAdminApiService _service = FacilityAdminApiService();
  late final TabController _tabController;
  final _currency = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final _dateFmt = DateFormat('MMM d, yyyy');

  // Mặc định xem 12 tháng gần nhất; luôn gửi khoảng ngày rõ ràng cho BE.
  DateTime? _fromDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime? _toDate = DateTime.now();
  Future<Map<String, dynamic>>? _revenueFuture;
  Future<Map<String, dynamic>>? _occupancyFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRevenue();
    _loadOccupancy();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadRevenue() {
    setState(() {
      _revenueFuture =
          _service.getRevenueReport(fromDate: _fromDate, toDate: _toDate);
    });
  }

  void _loadOccupancy() {
    setState(() {
      _occupancyFuture = _service.getOccupancyReport();
    });
  }

  /// Xuất báo cáo của tab đang xem (CSV) và chép vào clipboard.
  Future<void> _exportCurrent() async {
    final type = _tabController.index == 0 ? 'revenue' : 'occupancy';
    try {
      final csv = await _service.exportReport(
        type: type,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      final lines = csv.trim().isEmpty ? 0 : csv.trim().split('\n').length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$type report copied to clipboard as CSV ($lines lines)'),
          backgroundColor: AppColors.success,
        ),
      );
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

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _loadRevenue();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Export CSV (copy)',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportCurrent,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.secondaryContainer,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          indicatorColor: AppColors.secondaryContainer,
          tabs: const [Tab(text: 'Revenue'), Tab(text: 'Occupancy')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildRevenueTab(), _buildOccupancyTab()],
      ),
    );
  }

  Widget _buildRevenueTab() {
    return RefreshIndicator(
      onRefresh: () async => _loadRevenue(),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _revenueFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(message: 'Loading revenue report...');
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(
                    _fromDate != null && _toDate != null
                        ? '${_dateFmt.format(_fromDate!)} - ${_dateFmt.format(_toDate!)}'
                        : 'All time (pick a date range)',
                  ),
                ),
                SizedBox(
                  height: 360,
                  child: AppErrorState(
                    message:
                        snapshot.error.toString().replaceAll('Exception: ', ''),
                    onRetry: _loadRevenue,
                  ),
                ),
              ],
            );
          }
          final data = snapshot.data ?? {};
          final summary = (data['systemSummary'] as Map?) ?? {};
          final byFacility = (data['byFacility'] as List?) ?? [];
          final total = (summary['totalRevenue'] as num?)?.toDouble() ?? 0;
          final deposit = (summary['depositRevenue'] as num?)?.toDouble() ?? 0;
          final rental = (summary['rentalFeeRevenue'] as num?)?.toDouble() ?? 0;
          final extra =
              (summary['extraChargeRevenue'] as num?)?.toDouble() ?? 0;
          final count = summary['paymentCount'] ?? 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              OutlinedButton.icon(
                onPressed: _pickDateRange,
                icon: const Icon(Icons.date_range, size: 16),
                label: Text(
                  _fromDate != null && _toDate != null
                      ? '${_dateFmt.format(_fromDate!)} - ${_dateFmt.format(_toDate!)}'
                      : 'All time (pick a date range)',
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Revenue',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(_currency.format(total),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$count payment${count == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _revenueChip(
                          'Deposits', deposit, AppColors.secondary)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _revenueChip(
                          'Rental Fees', rental, AppColors.secondaryContainer)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _revenueChip(
                          'Extra Charges', extra, AppColors.warning)),
                ],
              ),
              const SizedBox(height: 20),
              const Text('By Facility',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              if (byFacility.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text('No facility revenue yet.',
                      style: TextStyle(color: AppColors.onSurfaceVariant)),
                )
              else
                ...byFacility.map((f) {
                  final m = f as Map;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(m['facilityName']?.toString() ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('${m['paymentCount'] ?? 0} payments',
                          style: const TextStyle(fontSize: 12)),
                      trailing: Text(
                        _currency.format(
                            (m['totalRevenue'] as num?)?.toDouble() ?? 0),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryContainer),
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

  Widget _revenueChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(_currency.format(value),
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildOccupancyTab() {
    return RefreshIndicator(
      onRefresh: () async => _loadOccupancy(),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _occupancyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(
                message: 'Loading occupancy report...');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: snapshot.error.toString().replaceAll('Exception: ', ''),
              onRetry: _loadOccupancy,
            );
          }
          final data = snapshot.data ?? {};
          final summary = (data['systemSummary'] as Map?) ?? {};
          final byFacility = (data['byFacility'] as List?) ?? [];
          final byUnitType = (data['byUnitType'] as List?) ?? [];
          final byStatus = (data['bookingsByStatus'] as Map?) ?? {};
          final rate = (summary['occupancyRate'] as num?)?.toDouble() ?? 0;

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
                    const Text('System-wide Occupancy',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text('${rate.toStringAsFixed(1)}%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (rate / 100).clamp(0, 1),
                        minHeight: 8,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(
                            AppColors.secondaryContainer),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _occupancyStat('Total', summary['totalUnits']),
                        _occupancyStat('Occupied', summary['occupiedUnits']),
                        _occupancyStat('Available', summary['availableUnits']),
                        _occupancyStat('Reserved', summary['reservedUnits']),
                        _occupancyStat(
                            'Overdue', summary['overdueBookings'] ?? 0),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('By Facility',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              if (byFacility.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text('No facilities yet.',
                      style: TextStyle(color: AppColors.onSurfaceVariant)),
                )
              else
                ...byFacility.map((f) {
                  final m = f as Map;
                  final r = (m['occupancyRate'] as num?)?.toDouble() ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(m['facilityName']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              Text('${r.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryContainer)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (r / 100).clamp(0, 1),
                              minHeight: 6,
                              backgroundColor: AppColors.surfaceContainerLow,
                              valueColor: const AlwaysStoppedAnimation(
                                  AppColors.secondaryContainer),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${m['occupiedUnits'] ?? 0} occupied • ${m['availableUnits'] ?? 0} available • ${m['totalUnits'] ?? 0} total • ${m['overdueBookings'] ?? 0} overdue',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 20),
              const Text('By Unit Type',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              if (byUnitType.isEmpty)
                const Text('No unit types yet.',
                    style: TextStyle(color: AppColors.onSurfaceVariant))
              else
                ...byUnitType.map((t) {
                  final m = t as Map;
                  final r = (m['occupancyRate'] as num?)?.toDouble() ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(m['typeName']?.toString() ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        '${m['occupiedUnits'] ?? 0} occupied • ${m['availableUnits'] ?? 0} available • ${m['totalUnits'] ?? 0} total',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Text('${r.toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryContainer)),
                    ),
                  );
                }),
              const SizedBox(height: 10),
              const Text('Rental Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: byStatus.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key.toString().replaceAll('_', ' '),
                                style: const TextStyle(fontSize: 12)),
                            Text('${e.value}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _occupancyStat(String label, dynamic value) {
    return Column(
      children: [
        Text('$value',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}
