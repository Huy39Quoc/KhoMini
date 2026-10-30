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
          final retainedRevenue = (summary['depositRetentionRevenue'] as num?)?.toDouble() ??
              ((deposits['retained'] as num?)?.toDouble() ?? 0);
          final count = summary['paymentCount'] ?? 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // BỘ CHỌN KỲ BÁO CÁO
              InkWell(
                onTap: _pickDateRange,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primaryContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Kỳ báo cáo', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text(
                              _fromDate != null && _toDate != null
                                  ? '${_dateFmt.format(_fromDate!)} – ${_dateFmt.format(_toDate!)}'
                                  : 'Tất cả thời gian (Bấm để chọn ngày)',
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Số liệu doanh thu trong kỳ đã chọn. Tab Lấp đầy kho luôn thể hiện trạng thái hiện tại.',
                style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 14),

              // THẺ TỔNG QUAN DOANH THU THUẦN (HERO CARD)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'DOANH THU THUẦN TRONG KỲ',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$count giao dịch',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currency.format(total),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _heroMetricItem('Tiền thuê kho', _currency.format(rental), Colors.white),
                          ),
                          Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.1)),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: _heroMetricItem('Phí phát sinh', _currency.format(extra), Colors.white70),
                            ),
                          ),
                          Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.1)),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: _heroMetricItem('Cọc vi phạm', '+${_currency.format(retainedRevenue)}', const Color(0xFF4ADE80)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 13, color: AppColors.onSurfaceVariant),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Doanh thu thuần = Tiền thuê kho (+) Phí phát sinh (+) Cọc giữ lại vi phạm.',
                      style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // THẺ ĐỐI CHIẾU TIỀN CỌC KÝ QUỸ
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppColors.secondary),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Quỹ tiền cọc bảo lãnh (Ký quỹ)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Text(
                              'Chi tiết',
                              style: TextStyle(fontSize: 12, color: AppColors.primaryContainer, fontWeight: FontWeight.w600),
                            ),
                            const Icon(Icons.chevron_right, size: 16, color: AppColors.primaryContainer),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _currency.format(deposit),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'đang giữ cuối kỳ (không tính doanh thu)',
                                style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              _escrowPill('Nhận mới', '+${_currency.format(deposits['received'] ?? 0)}', const Color(0xFF15803D)),
                              Container(width: 1, height: 16, color: const Color(0xFFE2E8F0)),
                              _escrowPill('Đã hoàn', '−${_currency.format(deposits['refunded'] ?? 0)}', const Color(0xFFB45309)),
                              Container(width: 1, height: 16, color: const Color(0xFFE2E8F0)),
                              _escrowPill('Giữ vi phạm', '−${_currency.format(deposits['retained'] ?? 0)}', const Color(0xFFB91C1C)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // DANH SÁCH THEO CƠ SỞ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Theo cơ sở',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                  Text('${byFacility.length} cơ sở',
                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                ],
              ),
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
                  final facRental = (m['rentalFeeRevenue'] as num?)?.toDouble() ?? 0;
                  final facExtra = (m['extraChargeRevenue'] as num?)?.toDouble() ?? 0;
                  final facRetained = (m['depositRetentionRevenue'] as num?)?.toDouble() ??
                      ((facDeposits['retained'] as num?)?.toDouble() ?? 0);
                  final facClosing = (facDeposits['closingBalance'] as num?)?.toDouble() ?? 0;
                  final facCount = m['paymentCount'] ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _showReconciliationDetails(
                        context: context,
                        title: m['facilityName']?.toString() ?? 'Cơ sở',
                        deposits: facDeposits,
                        totalRevenue: facRev,
                        paymentCount: facCount,
                        rentalFee: facRental,
                        extraCharge: facExtra,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.storefront_outlined, size: 18, color: AppColors.primaryContainer),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m['facilityName']?.toString() ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 1),
                                      Text('$facCount giao dịch ghi nhận',
                                          style: const TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _currency.format(facRev),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15.5,
                                          color: AppColors.primaryContainer),
                                    ),
                                    const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Đối chiếu', style: TextStyle(fontSize: 11, color: AppColors.primaryContainer, fontWeight: FontWeight.w500)),
                                        Icon(Icons.chevron_right, size: 14, color: AppColors.primaryContainer),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Doanh thu thuần', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                        const SizedBox(height: 1),
                                        Text(
                                          'Thuê: ${_currency.format(facRental)}'
                                          '${facRetained > 0 ? ' • Vi phạm: +${_currency.format(facRetained)}' : ''}'
                                          '${facExtra > 0 ? ' • Phụ phí: ${_currency.format(facExtra)}' : ''}',
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Cọc đang giữ', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                      const SizedBox(height: 1),
                                      Text(
                                        _currency.format(facClosing),
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Báo cáo doanh thu & đối chiếu tiền cọc ($paymentCount giao dịch)',
                            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // PHẦN 1: CƠ CẤU DOANH THU THUẦN
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.trending_up, size: 16, color: AppColors.primaryContainer),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('1. Cơ cấu doanh thu thuần',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ),
                    Text(_currency.format(totalRevenue),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryContainer)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.calculate_outlined, size: 16, color: Color(0xFF334155)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Doanh thu = Tiền thuê kho (+) Phí phát sinh (+) Cọc giữ lại vi phạm',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _detailFlowItem('Tiền thuê kho', _currency.format(rentalFee),
                          'Doanh thu từ phí thuê kho của khách hàng', const Color(0xFF0F172A)),
                      const Divider(height: 18, color: Color(0xFFF1F5F9)),
                      _detailFlowItem('(+) Phí phát sinh', '+${_currency.format(extraCharge)}',
                          'Phí tiện ích, gia hạn hoặc phụ thu khác',
                          extraCharge > 0 ? const Color(0xFF15803D) : const Color(0xFF64748B)),
                      const Divider(height: 18, color: Color(0xFFF1F5F9)),
                      _detailFlowItem('(+) Cọc vi phạm giữ lại', '+${_currency.format(retained)}',
                          'Khấu trừ hư hại (${_currency.format(damage)}) và phạt hủy (${_currency.format(cancel)}) chuyển thành doanh thu',
                          retained > 0 ? const Color(0xFF15803D) : const Color(0xFF64748B)),
                      const Divider(height: 20, thickness: 1.5, color: Color(0xFFCBD5E1)),
                      _detailFlowItem('(=) Tổng doanh thu thuần', _currency.format(totalRevenue),
                          'Tổng doanh thu ghi nhận trong kỳ báo cáo', AppColors.primaryContainer,
                          isBold: true),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // PHẦN 2: ĐỐI CHIẾU TIỀN CỌC KÝ QUỸ
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppColors.secondary),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('2. Đối chiếu tiền cọc ký quỹ',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ),
                    Text('Còn giữ: ${_currency.format(closing)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.calculate_outlined, size: 16, color: Color(0xFF334155)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cuối kỳ = Đầu kỳ (+) Nhận mới (−) Đã hoàn (−) Giữ lại vi phạm',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _detailFlowItem('Cọc đầu kỳ', _currency.format(opening),
                          'Số dư tiền cọc ký quỹ từ kỳ trước chuyển sang', const Color(0xFF64748B)),
                      const Divider(height: 18, color: Color(0xFFF1F5F9)),
                      _detailFlowItem('(+) Cọc đã nhận', '+${_currency.format(received)}',
                          'Tiền cọc khách hàng đã thanh toán trong kỳ', const Color(0xFF15803D)),
                      const Divider(height: 18, color: Color(0xFFF1F5F9)),
                      _detailFlowItem('(−) Cọc đã hoàn', '−${_currency.format(refunded)}',
                          'Tiền cọc đã chuyển khoản hoàn lại sau nghiệm thu',
                          refunded > 0 ? const Color(0xFFB45309) : const Color(0xFF94A3B8)),
                      const Divider(height: 18, color: Color(0xFFF1F5F9)),
                      _detailFlowItem('(−) Cọc giữ lại vi phạm', '−${_currency.format(retained)}',
                          'Khấu trừ giảm quỹ cọc để chuyển sang Doanh thu ở Mục 1',
                          retained > 0 ? const Color(0xFFB91C1C) : const Color(0xFF94A3B8)),
                      const Divider(height: 20, thickness: 1.5, color: Color(0xFFCBD5E1)),
                      _detailFlowItem('(=) Cọc còn giữ cuối kỳ', _currency.format(closing),
                          'Tiền cọc bảo đảm hợp đồng (chưa hoàn trả, không tính vào doanh thu)', const Color(0xFF0F172A),
                          isBold: true),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lưu ý kế toán: Tiền cọc (${_currency.format(closing)}) là nghĩa vụ nợ ký quỹ của khách hàng, không phải doanh thu. Khi có vi phạm (${_currency.format(retained)}), tiền cọc bị trừ khỏi quỹ và kết chuyển thành Doanh thu thuần của cơ sở.',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.35),
                        ),
                      ),
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

  Widget _detailFlowItem(String label, String value, String note, Color valueColor, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                      fontSize: isBold ? 13.5 : 12.5,
                      color: isBold ? const Color(0xFF0F172A) : const Color(0xFF334155))),
            ),
            const SizedBox(width: 8),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isBold ? 14 : 13,
                    color: valueColor)),
          ],
        ),
        const SizedBox(height: 2),
        Text(note, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _heroMetricItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: Colors.white70),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor),
          ),
        ),
      ],
    );
  }

  Widget _escrowPill(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ),
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
