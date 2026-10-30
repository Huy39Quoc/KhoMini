import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/facility_admin_api_service.dart';
import '../../widgets/state_views.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  final FacilityAdminApiService _service = FacilityAdminApiService();
  late final TabController _tabController;
  final _currency = NumberFormat.currency(
      locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
  final _dateFmt = DateFormat('dd/MM/yyyy');

  DateTime? _fromDate = DateTime(DateTime.now().year, DateTime.now().month);
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
          content: Text('Đã sao chép báo cáo $type (CSV, $lines dòng)'),
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
      helpText: 'Chọn kỳ báo cáo doanh thu',
      saveText: 'Áp dụng',
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
        title: const Text('Báo cáo'),
        actions: [
          IconButton(
            tooltip: 'Xuất báo cáo (CSV)',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportCurrent,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.secondaryContainer,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          indicatorColor: AppColors.secondaryContainer,
          tabs: const [Tab(text: 'Doanh thu'), Tab(text: 'Lấp đầy kho')],
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
            return const AppLoadingState(message: 'Đang tải báo cáo doanh thu...');
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
                        ? 'Kỳ báo cáo: ${_dateFmt.format(_fromDate!)} - ${_dateFmt.format(_toDate!)}'
                        : 'Kỳ báo cáo: tất cả (bấm để chọn ngày)',
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
          final deposits = (summary['depositReconciliation'] as Map?) ?? {};
          final deposit = (deposits['closingBalance'] as num?)?.toDouble() ?? 0;
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
                      ? 'Kỳ báo cáo: ${_dateFmt.format(_fromDate!)} - ${_dateFmt.format(_toDate!)}'
                      : 'Kỳ báo cáo: tất cả (bấm để chọn ngày)',
                ),
              ),
              const Text('Chọn khoảng ngày để xem doanh thu trong kỳ đó. '
                  'Tab Lấp đầy kho luôn hiển thị số liệu hiện tại.',
                  style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
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
                    const Text('Doanh thu thuần trong kỳ',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(_currency.format(total),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$count giao dịch đã ghi nhận',
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
                          'Cọc còn giữ cuối kỳ', deposit, AppColors.secondary)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _revenueChip(
                          'Tiền thuê', rental, AppColors.secondaryContainer)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _revenueChip(
                          'Phí phát sinh', extra, AppColors.warning)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Cọc chưa khấu trừ không phải doanh thu. Khấu trừ được ghi nhận khi chốt; khoản hoàn chỉ ghi nhận khi hoàn tất.',
                  style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _showReconciliationDetails(
                    context: context,
                    title: 'Toàn hệ thống',
                    deposits: deposits,
                    totalRevenue: total,
                    paymentCount: count,
                    rentalFee: rental,
                    extraCharge: extra,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Đối chiếu tiền cọc trong kỳ',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Row(
                              children: [
                                Icon(Icons.touch_app, size: 13, color: AppColors.primaryContainer),
                                SizedBox(width: 3),
                                Text('Xem chi tiết', style: TextStyle(fontSize: 11, color: AppColors.primaryContainer, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _depositReconciliation(deposits),
                        const SizedBox(height: 6),
                        const Text('Cuối kỳ = Đầu kỳ (+) Nhận mới (−) Đã hoàn (−) Giữ lại vi phạm.',
                            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Theo cơ sở',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              if (byFacility.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text('Chưa có doanh thu theo cơ sở.',
                      style: TextStyle(color: AppColors.onSurfaceVariant)),
                )
              else
                ...byFacility.map((f) {
                  final m = f as Map;
                  final facDeposits = (m['depositReconciliation'] as Map?) ?? {};
                  final facRev = (m['totalRevenue'] as num?)?.toDouble() ?? 0;
                  final facCount = m['paymentCount'] ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _showReconciliationDetails(
                        context: context,
                        title: m['facilityName']?.toString() ?? 'Cơ sở',
                        deposits: facDeposits,
                        totalRevenue: facRev,
                        paymentCount: facCount,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(m['facilityName']?.toString() ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                ),
                                Text(
                                  _currency.format(facRev),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.primaryContainer),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('$facCount giao dịch thu', style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                            const SizedBox(height: 6),
                            _depositReconciliation(facDeposits),
                            const SizedBox(height: 6),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(Icons.touch_app, size: 12, color: AppColors.primaryContainer),
                                SizedBox(width: 4),
                                Text('Chạm để xem chi tiết đối chiếu', style: TextStyle(fontSize: 11, color: AppColors.primaryContainer, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
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

  Widget _depositReconciliation(Map data) {
    final opening = (data['openingBalance'] as num?)?.toDouble() ?? 0;
    final received = (data['received'] as num?)?.toDouble() ?? 0;
    final refunded = (data['refunded'] as num?)?.toDouble() ?? 0;
    final retained = (data['retained'] as num?)?.toDouble() ?? 0;
    final damage = (data['damageRetained'] as num?)?.toDouble() ?? 0;
    final cancel = (data['cancellationRetained'] as num?)?.toDouble() ?? 0;
    final closing = (data['closingBalance'] as num?)?.toDouble() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Đầu kỳ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
            const SizedBox(width: 6),
            Text('Cọc đầu kỳ: ${_currency.format(opening)}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('(+) CỘNG', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
            ),
            const SizedBox(width: 6),
            Text('Đã nhận trong kỳ: +${_currency.format(received)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade800)),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('(-) TRỪ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
            ),
            const SizedBox(width: 6),
            Text('Đã hoàn trong kỳ: -${_currency.format(refunded)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade900)),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('(-) TRỪ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
            ),
            const SizedBox(width: 6),
            Text('Giữ lại vi phạm: -${_currency.format(retained)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade800)),
          ],
        ),
        if (damage > 0 || cancel > 0) ...[
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 2),
            child: Text(
              '• Khấu trừ hư hại: ${_currency.format(damage)} | Giữ lại hủy đơn: ${_currency.format(cancel)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('(=) CÒN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
            ),
            const SizedBox(width: 6),
            Text('Cọc còn giữ cuối kỳ: ${_currency.format(closing)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
          ],
        ),
      ],
    );
  }

  void _showReconciliationDetails({
    required BuildContext context,
    required String title,
    required Map deposits,
    required num totalRevenue,
    required num paymentCount,
    num rentalFee = 0,
    num extraCharge = 0,
  }) {
    final opening = (deposits['openingBalance'] as num?)?.toDouble() ?? 0;
    final received = (deposits['received'] as num?)?.toDouble() ?? 0;
    final refunded = (deposits['refunded'] as num?)?.toDouble() ?? 0;
    final retained = (deposits['retained'] as num?)?.toDouble() ?? 0;
    final damage = (deposits['damageRetained'] as num?)?.toDouble() ?? 0;
    final cancel = (deposits['cancellationRetained'] as num?)?.toDouble() ?? 0;
    final closing = (deposits['closingBalance'] as num?)?.toDouble() ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Chi tiết đối chiếu: $title',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '$paymentCount giao dịch đã phát sinh trong kỳ',
                  style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.functions, size: 16, color: Colors.blue.shade900),
                          const SizedBox(width: 6),
                          Text('Công thức hạch toán tiền cọc:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue.shade900)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Cuối kỳ = Đầu kỳ (+) Nhận mới (−) Đã hoàn (−) Giữ lại vi phạm',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade900)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _flowRow('Cọc đầu kỳ', _currency.format(opening), 'Số dư tiền cọc ký quỹ từ kỳ trước chuyển sang', Colors.grey.shade700, '[Đầu kỳ]'),
                const Divider(height: 16),
                _flowRow('(+) Cọc đã nhận', '+${_currency.format(received)}', 'Tiền cọc khách hàng đóng khi đặt kho trong kỳ', Colors.green.shade800, '(+) CỘNG'),
                const Divider(height: 16),
                _flowRow('(-) Cọc đã hoàn', '-${_currency.format(refunded)}', 'Tiền cọc đã chuyển khoản hoàn trả khách sau nghiệm thu', Colors.orange.shade900, '(-) TRỪ'),
                const Divider(height: 16),
                _flowRow('(-) Cọc giữ lại (doanh thu)', '-${_currency.format(retained)}',
                    'Cọc chuyển thành doanh thu do khấu trừ hư hại (${_currency.format(damage)}) hoặc phạt hủy đơn (${_currency.format(cancel)})',
                    Colors.red.shade800, '(-) TRỪ'),
                const Divider(height: 16),
                _flowRow('(=) Cọc còn giữ cuối kỳ', _currency.format(closing),
                    'Tiền cọc hệ thống đang nắm giữ để bảo đảm cho các hợp đồng đang hoạt động',
                    Colors.blue.shade900, '(=) KẾT QUẢ', isBold: true),

                const SizedBox(height: 20),
                const Text('Doanh thu ghi nhận trong kỳ:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tổng doanh thu thuần:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(_currency.format(totalRevenue),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryContainer)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Đóng'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _flowRow(String label, String value, String note, Color color, String badge, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                ),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w600, fontSize: 13)),
              ],
            ),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          ],
        ),
        const SizedBox(height: 3),
        Text(note, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
      ],
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
                message: 'Đang tải báo cáo lấp đầy...');
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
                    const Text('Tỷ lệ lấp đầy toàn hệ thống',
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
                        _occupancyStat('Tổng', summary['totalUnits']),
                        _occupancyStat('Đang thuê', summary['occupiedUnits']),
                        _occupancyStat('Trống', summary['availableUnits']),
                        _occupancyStat('Đã giữ', summary['reservedUnits']),
                        _occupancyStat(
                            'Quá hạn', summary['overdueBookings'] ?? 0),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Theo cơ sở',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              if (byFacility.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text('Chưa có cơ sở nào.',
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
                            '${m['occupiedUnits'] ?? 0} đang thuê • ${m['availableUnits'] ?? 0} trống • ${m['totalUnits'] ?? 0} tổng • ${m['overdueBookings'] ?? 0} quá hạn',
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
              const Text('Theo loại kho',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              if (byUnitType.isEmpty)
                const Text('Chưa có loại kho nào.',
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
                        '${m['occupiedUnits'] ?? 0} đang thuê • ${m['availableUnits'] ?? 0} trống • ${m['totalUnits'] ?? 0} tổng',
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
              const Text('Theo trạng thái thuê',
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
