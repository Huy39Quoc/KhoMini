import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import 'my_units/my_rented_units_screen.dart';
import 'reservation/facility_detail_screen.dart';
import 'tickets/ticket_list_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  final UserModel user;

  const CustomerHomeScreen({super.key, required this.user});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      _buildHomeOverview(),
      const MyRentedUnitsScreen(),
      const FacilityDetailScreen(
        facilityId: '1',
        facilityName: 'StoreHub Central',
      ),
      const TicketListScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined), label: 'My Units'),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_business_outlined), label: 'Reserve'),
          BottomNavigationBarItem(
              icon: Icon(Icons.support_agent_outlined), label: 'Support'),
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
                  const Text('Welcome back,',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                  Text(displayName,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, color: Colors.white),
              )
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('24/7 Self-Storage Access',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text(
                    'Access your storage unit and facility gates with digital PIN and QR Key.',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () => setState(() => _currentIndex = 1),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black),
                  child: const Text('View Smart Access Keys'),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Quick Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildActionCard('My Units', Icons.vpn_key, Colors.teal,
                  () => setState(() => _currentIndex = 1)),
              const SizedBox(width: 12),
              _buildActionCard('Reserve Unit', Icons.add_circle_outline,
                  Colors.indigo, () => setState(() => _currentIndex = 2)),
              const SizedBox(width: 12),
              _buildActionCard('Get Support', Icons.headset_mic_outlined,
                  Colors.deepOrange, () => setState(() => _currentIndex = 3)),
            ],
          )
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
