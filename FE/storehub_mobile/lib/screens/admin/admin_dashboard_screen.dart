import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/admin_api_service.dart';
import '../../services/facility_admin_api_service.dart';
import '../common/facility_staff_overview_screen.dart';
import '../common/profile_screen.dart';
import '../../widgets/notification_badge_button.dart';
import '../common/transaction_history_screen.dart';
import 'activity_log_screen.dart';
import '../operations/facility_management_screen.dart';
import 'role_permission_screen.dart';
import 'user_management_screen.dart';
import '../operations/reports_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final UserModel user;
  const AdminDashboardScreen({super.key, required this.user});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _adminApiService = AdminApiService();
  final _facilityAdminApiService = FacilityAdminApiService();
  bool _isLoading = true;
  int _totalUsers = 0;
  int _totalRoles = 0;
  int _totalPermissions = 0;
  int _activeUsers = 0;
  int _totalFacilities = 0;
  int _totalStaff = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _adminApiService.getUserSummary(),
        _adminApiService.getRoles(),
        _adminApiService.getPermissions(),
        _facilityAdminApiService.getFacilitiesCount(),
        _adminApiService.getStaffCount(),
      ]);
      final summary = results[0] as ({int total, int active});
      final roles = results[1] as List<dynamic>;
      final permissions = results[2] as List<dynamic>;
      final facilityCount = results[3] as int;
      final staffCount = results[4] as int;

      if (!mounted) return;
      setState(() {
        _totalUsers = summary.total;
        _activeUsers = summary.active;
        _totalRoles = roles.length;
        _totalPermissions = permissions.length;
        _totalFacilities = facilityCount;
        _totalStaff = staffCount;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Quản trị hệ thống'),
        actions: [
          NotificationBadgeButton(
            user: widget.user,
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
                    fontWeight: FontWeight.bold),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProfileScreen(user: widget.user)),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Text(
                      'Xin chào, ${widget.user.fullName.isNotEmpty ? widget.user.fullName : widget.user.username}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  const Text(
                      'Quản trị tài khoản, vai trò và quyền truy cập theo cơ sở.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 16),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_errorMessage!,
                          style: const TextStyle(color: AppColors.error)),
                    ),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _statCard(
                        'Cơ sở lưu trữ',
                        '$_totalFacilities',
                        Icons.storefront_rounded,
                        AppColors.primaryContainer,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const FacilityStaffOverviewScreen(
                                        initialTabIndex: 0)),
                          );
                        },
                      ),
                      _statCard(
                        'Nhân viên cơ sở',
                        '$_totalStaff',
                        Icons.badge_rounded,
                        AppColors.secondary,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const FacilityStaffOverviewScreen(
                                        initialTabIndex: 1)),
                          );
                        },
                      ),
                      _statCard('Tổng người dùng', '$_totalUsers', Icons.people,
                          AppColors.primaryContainer),
                      _statCard('Đang hoạt động', '$_activeUsers',
                          Icons.verified_user, AppColors.success),
                      _statCard('Vai trò', '$_totalRoles', Icons.badge,
                          AppColors.secondaryContainer),
                      _statCard('Quyền hạn', '$_totalPermissions',
                          Icons.lock_outline, AppColors.secondary),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text('Chức năng quản trị',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  _actionTile(
                    icon: Icons.store_mall_directory_rounded,
                    title: 'Tổng quan cơ sở & nhân sự',
                    subtitle:
                        'Xem chi tiết $_totalFacilities cơ sở & danh sách $_totalStaff nhân viên thuộc từng cơ sở',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const FacilityStaffOverviewScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _actionTile(
                    icon: Icons.manage_accounts,
                    title: 'Người dùng & vai trò',
                    subtitle: 'Xem tài khoản và gán vai trò cho từng người dùng',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const UserManagementScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _actionTile(
                    icon: Icons.security,
                    title: 'Vai trò & quyền hạn',
                    subtitle: 'Cấu hình quyền của từng vai trò',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RolePermissionScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _actionTile(
                    icon: Icons.store_outlined,
                    title: 'Gán quản lý cho cơ sở',
                    subtitle:
                        'Chọn Facility Manager phụ trách từng cơ sở (quyết định ai xem được dữ liệu cơ sở nào)',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FacilityManagementScreen(
                                canAssignManager: true)),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _actionTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'Lịch sử giao dịch',
                    subtitle: 'Xem toàn bộ giao dịch trên hệ thống (chỉ đọc)',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => TransactionHistoryScreen(
                                  userRole: widget.user.roleName,
                                )),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _actionTile(
                    icon: Icons.bar_chart_rounded,
                    title: 'Báo cáo doanh thu & Lấp đầy kho',
                    subtitle: 'Báo cáo doanh thu thuần, đối chiếu tiền cọc và tỷ lệ lấp đầy toàn hệ thống',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ReportsScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _actionTile(
                    icon: Icons.history,
                    title: 'Nhật ký hoạt động',
                    subtitle: 'Lịch sử đăng nhập và thao tác dữ liệu trong hệ thống',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ActivityLogScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceContainerHigh),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const Spacer(),
                if (onTap != null)
                  const Icon(Icons.arrow_forward_ios,
                      size: 11, color: AppColors.onSurfaceVariant),
              ],
            ),
            const Spacer(),
            Text(value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primaryContainer),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }
}
