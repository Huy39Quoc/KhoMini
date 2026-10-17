import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/facility_admin_api_service.dart';
import '../common/profile_screen.dart';
import '../common/transaction_history_screen.dart';
import 'facility_management_screen.dart';
import 'reports_screen.dart';
import 'revenue_chart_card.dart';
import 'unit_price_screen.dart';

/// Màn hình chính của Business Operations Manager: giám sát doanh thu toàn hệ thống,
/// quản lý danh sách cơ sở, chính sách thuê và giá/phí. (Quản lý tài khoản và phân quyền
/// là việc của System Administrator.)
class OperationsDashboardScreen extends StatefulWidget {
  final UserModel user;
  const OperationsDashboardScreen({super.key, required this.user});

  @override
  State<OperationsDashboardScreen> createState() =>
      _OperationsDashboardScreenState();
}

class _OperationsDashboardScreenState extends State<OperationsDashboardScreen> {
  final _reportsApi = FacilityAdminApiService();
  late Future<Map<String, dynamic>> _revenueFuture;
  late DateTime _revenueFrom;
  late DateTime _revenueTo;

  @override
  void initState() {
    super.initState();
    _loadRevenue();
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
        onRefresh: () async => _loadRevenue(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Xin chào, $name',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            const Text('Doanh thu tháng này của toàn hệ thống.',
                style:
                    TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
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
