import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/payment_model.dart';

class TransactionDetailDialog extends StatelessWidget {
  final PaymentModel payment;

  const TransactionDetailDialog({
    super.key,
    required this.payment,
  });

  static void show(BuildContext context, PaymentModel payment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailDialog(payment: payment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final formattedDate = payment.paymentTime != null
        ? dateFormat.format(payment.paymentTime!)
        : 'N/A';

    return SafeArea(child: SingleChildScrollView(child: Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transaction Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: payment.statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: payment.statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  payment.statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: payment.statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Amount Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  currencyFormat.format(payment.amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  payment.paymentTypeLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Details List
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _detailRow(
                    context,
                    label: 'Transaction ID',
                    value: payment.transactionId,
                    isCopyable: true,
                  ),
                  const Divider(height: 1, indent: 12, endIndent: 12),
                  _detailRow(
                    context,
                    label: 'Date & Time',
                    value: formattedDate,
                  ),
                  if (payment.paymentMethod != null && payment.paymentMethod!.isNotEmpty) ...[
                    const Divider(height: 1, indent: 12, endIndent: 12),
                    _detailRow(
                      context,
                      label: 'Payment Method',
                      value: payment.paymentMethod!,
                    ),
                  ],
                  if (payment.bookingCode != null && payment.bookingCode!.isNotEmpty) ...[
                    const Divider(height: 1, indent: 12, endIndent: 12),
                    _detailRow(
                      context,
                      label: 'Booking Code',
                      value: payment.bookingCode!,
                    ),
                  ],
                  if (payment.customerName != null && payment.customerName!.isNotEmpty) ...[
                    const Divider(height: 1, indent: 12, endIndent: 12),
                    _detailRow(
                      context,
                      label: 'Customer',
                      value: '${payment.customerName} (${payment.customerEmail ?? ''})',
                    ),
                  ],
                  if (payment.facilityName != null && payment.facilityName!.isNotEmpty) ...[
                    const Divider(height: 1, indent: 12, endIndent: 12),
                    _detailRow(
                      context,
                      label: 'Facility',
                      value: payment.facilityName!,
                    ),
                  ],
                  if (payment.unitCode != null && payment.unitCode!.isNotEmpty) ...[
                    const Divider(height: 1, indent: 12, endIndent: 12),
                    _detailRow(
                      context,
                      label: 'Storage Unit',
                      value: 'Unit ${payment.unitCode}',
                    ),
                  ],
                  if (payment.note != null && payment.note!.isNotEmpty) ...[
                    const Divider(height: 1, indent: 12, endIndent: 12),
                    _detailRow(
                      context,
                      label: 'Note',
                      value: payment.note!,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    )));
  }

  Widget _detailRow(
    BuildContext context, {
    required String label,
    required String value,
    bool isCopyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
          if (isCopyable) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transaction ID copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Icon(Icons.copy, size: 16, color: AppColors.primaryContainer),
            ),
          ],
        ],
      ),
    );
  }
}
