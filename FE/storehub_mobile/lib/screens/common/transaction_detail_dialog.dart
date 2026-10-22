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
    final dateFormat = DateFormat('dd/MM/yyyy • HH:mm');
    final formattedDate = payment.paymentTime != null
        ? dateFormat.format(payment.paymentTime!)
        : 'N/A';

    return SafeArea(child: SingleChildScrollView(child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
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
                color: AppColors.outlineVariant,
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
                'Chi tiết giao dịch',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: payment.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: payment.statusColor.withValues(alpha: 0.25)),
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
          if (payment.status.toUpperCase() == 'PENDING') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Giao dịch này chưa hoàn tất: khách chưa thanh toán xong trên VNPay '
                'hoặc đã thoát giữa chừng. Hệ thống sẽ tự cập nhật khi VNPay xác nhận; '
                'nếu quá hạn giữ chỗ, giao dịch sẽ chuyển sang "Thất bại".',
                style: TextStyle(fontSize: 12, color: Color(0xFF78350F), height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Amount Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Số tiền giao dịch',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  currencyFormat.format(payment.amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    payment.paymentTypeLabel,
                    style: const TextStyle(
                      color: Color(0xFFF1F5F9),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Details List
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _detailRow(
                    context,
                    label: 'Mã giao dịch',
                    value: payment.transactionId,
                    isCopyable: true,
                  ),
                  const Divider(height: 1, indent: 12, endIndent: 12),
                  _detailRow(
                    context,
                    label: 'Thời gian',
                    value: formattedDate,
                  ),
                  if (payment.paymentMethod != null && payment.paymentMethod!.isNotEmpty) ...[
                    const Divider(height: 1, indent: 12, endIndent: 12),
                    _detailRow(
                      context,
                      label: 'Phương thức',
                      value: payment.paymentMethod! == 'BANK_TRANSFER'
                          ? (payment.transactionId.startsWith('RF-')
                              ? 'Chuyển khoản ngân hàng'
                              : 'VNPay')
                          : payment.paymentMethod!,
                    ),
                  ],
                  if (payment.bookingCode != null && payment.bookingCode!.isNotEmpty) ...[
                    const Divider(height: 1, indent: 12, endIndent: 12),
                    _detailRow(
                      context,
                      label: 'Mã booking',
                      value: payment.bookingCode!,
                    ),
                  ],
                  if (payment.customerName != null && payment.customerName!.isNotEmpty) ...[
                    const Divider(height: 1, indent: 12, endIndent: 12),
                    _detailRow(
                      context,
                      label: 'Khách hàng',
                      value: '${payment.customerName} (${payment.customerEmail ?? ''})',
                    ),
                  ],
                  if (payment.facilityName != null && payment.facilityName!.isNotEmpty) ...[
                    const Divider(height: 1, indent: 12, endIndent: 12),
                    _detailRow(
                      context,
                      label: 'Cơ sở',
                      value: payment.facilityName!,
                    ),
                  ],
                  if (payment.unitCode != null && payment.unitCode!.isNotEmpty) ...[
                    const Divider(height: 1, indent: 12, endIndent: 12),
                    _detailRow(
                      context,
                      label: 'Ngăn kho',
                      value: 'Ngăn ${payment.unitCode}',
                    ),
                  ],
                  if (payment.note != null && payment.note!.isNotEmpty) ...[
                    const Divider(height: 1, indent: 12, endIndent: 12),
                    _detailRow(
                      context,
                      label: 'Ghi chú',
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
            child: const Text('Đóng'),
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
                    content: Text('Đã sao chép mã giao dịch'),
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
