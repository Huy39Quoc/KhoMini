import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ManagerDashboardScreen extends StatelessWidget {
  const ManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final units = List.generate(12, (index) {
      final status = index % 3 == 0
          ? 'RENTED'
          : (index % 5 == 0 ? 'MAINTENANCE' : 'AVAILABLE');
      return {'unitCode': 'A-${101 + index}', 'status': status};
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facility Manager - Unit Layout'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Storage Units Status Board',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildLegend(Colors.green, 'Available'),
                const SizedBox(width: 12),
                _buildLegend(Colors.redAccent, 'Rented'),
                const SizedBox(width: 12),
                _buildLegend(Colors.amber, 'Maintenance'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.2,
                ),
                itemCount: units.length,
                itemBuilder: (context, index) {
                  final u = units[index];
                  Color color = Colors.green;
                  if (u['status'] == 'RENTED') color = Colors.redAccent;
                  if (u['status'] == 'MAINTENANCE') color = Colors.amber;

                  return Container(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color, width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(u['unitCode']!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(u['status']!,
                            style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
