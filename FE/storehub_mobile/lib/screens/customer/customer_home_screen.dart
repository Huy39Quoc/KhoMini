import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/auth_api_service.dart';
import '../../core/navigation/customer_tab_request.dart';
import '../../widgets/logout_dialog.dart';
import 'reservation/my_waitlist_screen.dart';
import '../auth/login_screen.dart';
import '../common/profile_screen.dart';
import '../common/transaction_history_screen.dart';
import 'my_units/my_rented_units_screen.dart';
import 'reservation/explore_screen.dart';
import 'reservation/pending_bookings_section.dart';
import 'tickets/ticket_list_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  final UserModel user;

  const CustomerHomeScreen({super.key, required this.user});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;
  final _authApiService = AuthApiService();
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    customerTabRequest.addListener(_onTabRequest);
    _screens = [
      _buildHomeOverview(),
      const MyRentedUnitsScreen(),
      const ExploreScreen(),
      const TicketListScreen(),
    ];
  }

  void _onTabRequest() {
    final tab = customerTabRequest.value;
    if (tab == null) return;
    customerTabRequest.value = null;
    if (mounted) setState(() => _currentIndex = tab);
  }

  @override
  void dispose() {
    customerTabRequest.removeListener(_onTabRequest);
    super.dispose();
  }

  Future<void> _logout() async {
    final shouldLogout = await confirmLogout(context);

    if (shouldLogout) {
      await _authApiService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.secondaryContainer,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Trang chủ'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined), label: 'Kho của tôi'),
          BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined), label: 'Khám phá'),
          BottomNavigationBarItem(
              icon: Icon(Icons.support_agent_outlined), label: 'Hỗ trợ'),
        ],
      ),
    );
  }

  Widget _buildHomeOverview() {
    final displayName = widget.user.fullName.isNotEmpty
        ? widget.user.fullName
        : widget.user.username;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chào mừng trở lại,',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                  Text(displayName,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProfileScreen(user: widget.user)),
                      );
                    },
                    child: const CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Đăng xuất',
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    onPressed: _logout,
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ra vào kho tự phục vụ 24/7',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text(
                    'Mở ngăn kho và cổng cơ sở bằng mã PIN điện tử.',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () => setState(() => _currentIndex = 1),
                  child: const Text('Xem khóa thông minh'),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          const PendingBookingsSection(),
          const SizedBox(height: 16),
          const Text('Thao tác nhanh',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildActionCard(
                  'Kho của tôi',
                  Icons.vpn_key,
                  AppColors.primaryContainer,
                  () => setState(() => _currentIndex = 1)),
              const SizedBox(width: 12),
              _buildActionCard('Đặt giữ kho', Icons.add_circle_outline,
                  AppColors.secondary, () => setState(() => _currentIndex = 2)),
              const SizedBox(width: 12),
              _buildActionCard(
                  'Nhận hỗ trợ',
                  Icons.headset_mic_outlined,
                  AppColors.secondaryContainer,
                  () => setState(() => _currentIndex = 3)),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long_outlined,
                    color: AppColors.primaryContainer),
              ),
              title: const Text('Lịch sử giao dịch',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Xem biên lai và lịch sử giao dịch',
                  style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionHistoryScreen(
                      userRole: widget.user.roleName,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.notifications_active_outlined,
                    color: AppColors.primaryContainer),
              ),
              title: const Text('Danh sách chờ của tôi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Theo dõi các loại kho đang chờ có ngăn trống',
                  style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyWaitlistScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(title,
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
