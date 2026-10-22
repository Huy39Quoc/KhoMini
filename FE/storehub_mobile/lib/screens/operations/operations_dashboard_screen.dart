import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/admin_api_service.dart';
import '../../services/facility_admin_api_service.dart';
import '../common/facility_staff_overview_screen.dart';
import '../common/profile_screen.dart';
import '../common/transaction_history_screen.dart';
import 'facility_management_screen.dart';
import 'reports_screen.dart';
import 'revenue_chart_card.dart';
import 'unit_price_screen.dart';

/// Màn hình chính của Business Operations Manager: giám sát doanh thu toàn hệ thống,
/// xem và quản lý danh sách cơ sở, phân bổ nhân sự, chính sách thuê và giá/phí.
class OperationsDashboardScreen extends StatefulWidget {
  final UserModel user;
  const OperationsDashboardScreen({super.key, required this.user});

  @override
  State<OperationsDashboardScreen> createState() =>
      _OperationsDashboardScreenState();
}

class _OperationsDashboardScreenState extends State<OperationsDashboardScreen> {
  final _reportsApi = FacilityAdminApiService();
  final _adminApi = AdminApiService();

  late Future<Map<String, dynamic>> _revenueFuture;
  late DateTime _revenueFrom;
  late DateTime _revenueTo;

  int _facilityCount = 0;
  int _staffCount = 0;
  bool _isLoadingCounts = true;

  @override
  void initState() {
    super.initState();
    _loadRevenue();
    _loadCounts();
  }

  void _loadRevenue() {
    final now = DateTime.now();
    setState(() {
      _revenueFrom = DateTime(now.year, now.month);
      _revenueTo = now;
      _revenueFuture = _reportsApi.getRevenueReport(
          fromDate: _revenueFrom, toDate: _revenueTo);
    });
  }

  Future<void> _loadCounts() async {
    try {
      final results = await Future.wait([
        _reportsApi.getFacilitiesCount(),
        _adminApi.getStaffCount(),
      ]);
      if (!mounted) return;
      setState(() {
        _facilityCount = results[0];
        _staffCount = results[1];
        _isLoadingCounts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingCounts = false);
    }
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user.fullName.isNotEmpty
        ? widget.user.fullName
        : widget.user.username;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Quản lý kinh doanh'),
        actions: [
          IconButton(
            tooltip: 'Tài khoản',
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
                    fontWeight: FontWeight.bold),
              ),
            ),
            onPressed: () => _open(ProfileScreen(user: widget.user)),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadRevenue();
          await _loadCounts();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Xin chào, $name',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            const Text('Tổng quan vận hành và doanh thu toàn hệ thống.',
                style:
                    TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 14),

            // HÀNG THỐNG KÊ NHANH: CƠ SỞ & NHÂN SỰ
            Row(
              children: [
                _kpiCard(
                  label: 'Cơ sở lưu trữ',
                  value: _isLoadingCounts ? '...' : '$_facilityCount',
                  subtext: 'Toàn hệ thống',
                  icon: Icons.storefront_rounded,
                  color: AppColors.primaryContainer,
                  onTap: () => _open(const FacilityStaffOverviewScreen(initialTabIndex: 0)),
                ),
                const SizedBox(width: 12),
                _kpiCard(
                  label: 'Nhân viên (Staff)',
                  value: _isLoadingCounts ? '...' : '$_staffCount',
                  subtext: 'Thuộc các cơ sở',
                  icon: Icons.badge_rounded,
                  color: AppColors.secondary,
                  onTap: () => _open(const FacilityStaffOverviewScreen(initialTabIndex: 1)),
                ),
              ],
            ),
            const SizedBox(height: 14),

            FutureBuilder<Map<String, dynamic>>(
              future: _revenueFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return ListTile(
                    title: const Text('Không tải được biểu đồ doanh thu'),
                    trailing: TextButton(
                        onPressed: _loadRevenue, child: const Text('Thử lại')),
                  );
                }
                return RevenueChartCard(
                    report: snapshot.data ?? {},
                    fromDate: _revenueFrom,
                    toDate: _revenueTo);
              },
            ),
            const SizedBox(height: 20),
            const Text('Chức năng',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            _menuCard(
              icon: Icons.store_mall_directory_rounded,
              color: AppColors.primaryContainer,
              title: 'Cơ sở & Phân bổ nhân sự',
              subtitle:
                  'Xem chi tiết $_facilityCount cơ sở & danh sách nhân viên thuộc cơ sở nào.',
              onTap: () => _open(const FacilityStaffOverviewScreen()),
            ),
            _menuCard(
              icon: Icons.bar_chart_rounded,
              color: AppColors.primaryContainer,
              title: 'Báo cáo doanh thu & lấp đầy',
              subtitle:
                  'Theo cơ sở, loại kho và trạng thái thuê; xuất báo cáo.',
              onTap: () => _open(const ReportsScreen()),
            ),
            _menuCard(
              icon: Icons.apartment_rounded,
              color: AppColors.secondaryContainer,
              title: 'Cơ sở & chính sách thuê',
              subtitle:
                  'Thêm/sửa cơ sở; cọc, phí trễ hạn, hủy, gia hạn, trả kho.',
              onTap: () => _open(const FacilityManagementScreen()),
            ),
            _menuCard(
              icon: Icons.sell_outlined,
              color: AppColors.secondary,
              title: 'Giá thuê & tiền cọc',
              subtitle: 'Giá thuê tháng và tiền cọc của từng loại kho.',
              onTap: () => _open(const UnitPriceScreen()),
            ),
            _menuCard(
              icon: Icons.receipt_long_outlined,
              color: AppColors.success,
              title: 'Lịch sử giao dịch',
              subtitle: 'Mọi khoản thu và hoàn tiền trên toàn hệ thống.',
              onTap: () => _open(
                  TransactionHistoryScreen(userRole: widget.user.roleName)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard({
    required String label,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceContainerHigh),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios,
                      size: 11, color: AppColors.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtext,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
