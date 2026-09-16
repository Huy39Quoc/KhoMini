import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class OperationsDashboardScreen extends StatefulWidget {
  const OperationsDashboardScreen({super.key});

  @override
  State<OperationsDashboardScreen> createState() =>
      _OperationsDashboardScreenState();
}

class _OperationsDashboardScreenState extends State<OperationsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Global policy controls
  double _depositMonths = 1.0;
  double _overdueFeePercentPerDay = 2.5;
  int _cancelNoticeDays = 7;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operations Manager Console'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
                icon: Icon(Icons.analytics_outlined),
                text: 'Revenue & Occupancy'),
            Tab(icon: Icon(Icons.policy_outlined), text: 'Policy Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAnalyticsTab(),
          _buildPolicySettingsTab(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
                child: _buildMetricCard('Monthly Revenue', '\$19,420',
                    Icons.payments, Colors.green)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildMetricCard(
                    'Total Occupancy', '84.6%', Icons.pie_chart, Colors.blue)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildMetricCard('Rented Units', '342 / 404',
                    Icons.warehouse, Colors.orange)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildMetricCard('Active Facilities', '4 Locations',
                    Icons.location_city, Colors.purple)),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Performance by Facility',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildFacilityRow(
            'Downtown Central Hub', '92% Occupied', '\$7,800 / mo', 0.92),
        _buildFacilityRow(
            'Westside Storage Park', '85% Occupied', '\$6,400 / mo', 0.85),
        _buildFacilityRow(
            'North Industrial Facility', '78% Occupied', '\$3,400 / mo', 0.78),
        _buildFacilityRow(
            'Airport Logistics Depot', '68% Occupied', '\$1,820 / mo', 0.68),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 6),
            Text(value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilityRow(
      String name, String rateText, String revenue, double progress) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(revenue,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                color: AppColors.primary),
            const SizedBox(height: 6),
            Text(rateText,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicySettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Global Rental Policies & Pricing Rules',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Standard Deposit: ${_depositMonths.toStringAsFixed(1)} Month(s) Rental Fee'),
                Slider(
                  value: _depositMonths,
                  min: 1.0,
                  max: 3.0,
                  divisions: 4,
                  label: '${_depositMonths.toStringAsFixed(1)} mo',
                  onChanged: (val) => setState(() => _depositMonths = val),
                ),
                const Divider(),
                Text(
                    'Overdue Charge Penalty: ${_overdueFeePercentPerDay.toStringAsFixed(1)}% / day'),
                Slider(
                  value: _overdueFeePercentPerDay,
                  min: 0.5,
                  max: 5.0,
                  divisions: 9,
                  label: '${_overdueFeePercentPerDay.toStringAsFixed(1)}%',
                  onChanged: (val) =>
                      setState(() => _overdueFeePercentPerDay = val),
                ),
                const Divider(),
                Text(
                    'Return / Cancellation Notice Period: $_cancelNoticeDays days'),
                Slider(
                  value: _cancelNoticeDays.toDouble(),
                  min: 3,
                  max: 30,
                  divisions: 27,
                  label: '$_cancelNoticeDays days',
                  onChanged: (val) =>
                      setState(() => _cancelNoticeDays = val.toInt()),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('System-wide policies updated successfully!')),
            );
          },
          icon: const Icon(Icons.save),
          label: const Text('Save System Policies'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        )
      ],
    );
  }
}
