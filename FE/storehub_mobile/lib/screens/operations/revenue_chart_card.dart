import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';

/// Plots the system revenue by facility from /reports/revenue.
/// Deposits are shown separately because they are refundable, not revenue.
class RevenueChartCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final DateTime fromDate;
  final DateTime toDate;

  const RevenueChartCard({
    super.key,
    required this.report,
    required this.fromDate,
    required this.toDate,
  });

  @override
  Widget build(BuildContext context) {
    final summary = report['systemSummary'] is Map
        ? report['systemSummary'] as Map
        : <String, dynamic>{};
    final rows = report['byFacility'] is List
        ? (report['byFacility'] as List).whereType<Map>().toList()
        : <Map>[];
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final compact = NumberFormat.compact(locale: 'vi_VN');
    final total = (summary['totalRevenue'] as num?)?.toDouble() ?? 0;
    final deposit = (summary['depositRevenue'] as num?)?.toDouble() ?? 0;
    final maxRevenue = rows.fold<double>(0, (max, row) {
      final value = (row['totalRevenue'] as num?)?.toDouble() ?? 0;
      return value > max ? value : max;
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revenue by facility • ${DateFormat('MMM d').format(fromDate)}–${DateFormat('MMM d, yyyy').format(toDate)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(currency.format(total),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                    color: AppColors.primaryContainer)),
            Text('Refundable deposits held: ${currency.format(deposit)}',
                style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 16),
            if (rows.isEmpty || maxRevenue <= 0)
              const Text('No paid rental revenue in this period.',
                  style: TextStyle(color: AppColors.onSurfaceVariant))
            else
              for (final row in rows) ...[
                Row(
                  children: [
                    Expanded(child: Text(row['facilityName']?.toString() ?? 'Facility',
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('${compact.format((row['totalRevenue'] as num?) ?? 0)} ₫',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 5),
                SizedBox(
                  height: 12,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final amount = (row['totalRevenue'] as num?)?.toDouble() ?? 0;
                      final fraction = (amount / maxRevenue).clamp(0.0, 1.0);
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: constraints.maxWidth * fraction,
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}
