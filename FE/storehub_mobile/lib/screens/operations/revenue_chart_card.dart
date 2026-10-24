import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';

/// Plots net revenue by facility from /reports/revenue.
/// Deposits are a separate cash flow for the selected period, not revenue.
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
    final deposits = (summary['depositReconciliation'] as Map?) ?? {};
    final deposit = (deposits['closingBalance'] as num?)?.toDouble() ?? 0;
    final maxMagnitude = rows.fold<double>(0, (max, row) {
      final value = ((row['totalRevenue'] as num?)?.toDouble() ?? 0).abs();
      return value > max ? value : max;
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Doanh thu ròng theo cơ sở • ${DateFormat('dd/MM').format(fromDate)}–${DateFormat('dd/MM/yyyy').format(toDate)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(currency.format(total),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                    color: AppColors.primaryContainer)),
            Text('Cọc còn giữ cuối kỳ: ${currency.format(deposit)}',
                style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 16),
            if (rows.isEmpty || maxMagnitude <= 0)
              const Text('Không có dòng tiền thuê trong kỳ này.',
                  style: TextStyle(color: AppColors.onSurfaceVariant))
            else
              for (final row in rows) ...[
                Row(
                  children: [
                    Expanded(child: Text(row['facilityName']?.toString() ?? 'Cơ sở',
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
                      final fraction = (amount.abs() / maxMagnitude).clamp(0.0, 1.0);
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: constraints.maxWidth * fraction,
                          decoration: BoxDecoration(
                            color: amount < 0 ? AppColors.error : AppColors.secondaryContainer,
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
