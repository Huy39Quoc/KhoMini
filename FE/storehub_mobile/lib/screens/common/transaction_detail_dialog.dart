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

          // Invoice Breakdown Card
          if (_hasBreakdown) ...[
            _buildInvoiceBreakdown(context, currencyFormat),
            const SizedBox(height: 16),
          ],

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

  bool get _hasBreakdown {
    return payment.rentalFee != null ||
        payment.managementFee != null ||
        payment.depositAmount != null ||
        payment.damageDeduction != null ||
        payment.refundedAmount != null ||
        payment.transactionId.startsWith('RF-');
  }

  Widget _buildInvoiceBreakdown(BuildContext context, NumberFormat currencyFormat) {
    final isRefund = payment.transactionId.startsWith('RF-');
    final double damage = payment.damageDeduction ?? 0.0;
    final double initialDeposit = (payment.depositAmount != null &&
            payment.depositAmount! > payment.amount)
        ? payment.depositAmount!
        : (payment.amount + damage);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isRefund ? Icons.currency_exchange_outlined : Icons.receipt_long_outlined,
                size: 18,
                color: isRefund ? AppColors.secondary : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isRefund ? 'Bảng kê hoàn tiền cọc' : 'Bảng kê chi tiết đơn thuê',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 8),
          if (isRefund) ...[
            _breakdownRow(
              'Tiền cọc ban đầu',
              currencyFormat.format(initialDeposit),
            ),
            _breakdownRow(
              'Khấu trừ hư hại / vi phạm',
              damage > 0
                  ? '- ${currencyFormat.format(damage)}'
                  : '0 ₫',
              isDeduction: damage > 0,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1, color: Color(0xFFE2E8F0)),
            ),
            _breakdownRow(
              'Thực nhận hoàn trả',
              currencyFormat.format(payment.amount),
              isHighlight: true,
            ),
          ] else ...[
            if (payment.rentalFee != null)
              _breakdownRow(
                'Tiền thuê kho',
                currencyFormat.format(payment.rentalFee),
              ),
            if (payment.managementFee != null && payment.managementFee! > 0)
              _breakdownRow(
                'Phí dịch vụ / quản lý',
                currencyFormat.format(payment.managementFee),
              ),
            if (payment.depositAmount != null)
              _breakdownRow(
                'Tiền cọc kho (hoàn lại)',
                currencyFormat.format(payment.depositAmount),
                subtext: 'Hoàn lại sau khi trả kho và nghiệm thu đạt',
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1, color: Color(0xFFE2E8F0)),
            ),
            _breakdownRow(
              'Tổng đã thanh toán ban đầu',
              currencyFormat.format(payment.amount),
              isHighlight: true,
            ),
            if (payment.refundedAmount != null && payment.refundedAmount! > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.successContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Đã hoàn cọc ${currencyFormat.format(payment.refundedAmount)} khi trả kho thành công.',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF14532D),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _breakdownRow(
    String label,
    String value, {
    bool isHighlight = false,
    bool isDeduction = false,
    String? subtext,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isHighlight ? 13 : 12,
                  fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                  color: isHighlight ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: isHighlight ? 14 : 12.5,
                  fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                  color: isHighlight
                      ? AppColors.primary
                      : (isDeduction ? AppColors.error : AppColors.textPrimary),
                ),
              ),
            ],
          ),
          if (subtext != null) ...[
            const SizedBox(height: 2),
            Text(
              subtext,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
