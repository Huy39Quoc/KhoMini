import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/booking_api_service.dart';

class PaymentScreen extends StatefulWidget {
  // bookingId/bookingCode là thật, lấy từ BookingResponse sau khi
  // FacilityDetailScreen đã gọi POST /bookings thành công - trước đây màn
  // này không nhận bookingId nào cả và tự bịa mã đặt chỗ ngẫu nhiên.
  final String bookingId;
  final String bookingCode;
  final String facilityName;
  final String unitTypeName;
  final String unitTypeDimensions;
  final DateTime startDate;
  final int rentalMonths;
  final double totalRentalFee;
  final double depositAmount;

  const PaymentScreen({
    super.key,
    required this.bookingId,
    required this.bookingCode,
    required this.facilityName,
    required this.unitTypeName,
    required this.unitTypeDimensions,
    required this.startDate,
    required this.rentalMonths,
    required this.totalRentalFee,
    required this.depositAmount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with TickerProviderStateMixin {
  final BookingApiService _bookingService = BookingApiService();

  // Trạng thái màn hình
  bool _isSuccess = false;
  bool _isConfirming = false;

  // Trạng thái khởi tạo giao dịch thanh toán (POST /payments/initiate)
  bool _isInitiating = true;
  String? _initError;
  Map<String, dynamic>? _payment; // PaymentResponse thật: transactionId, amount, qrCodeUrl...

  // Animation cho success
  late final AnimationController _successCtrl;
  late final Animation<double> _successScale;
  late final Animation<double> _successFade;

  @override
  void initState() {
    super.initState();

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale =
        CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);
    _successFade = CurvedAnimation(parent: _successCtrl, curve: Curves.easeIn);

    _initiatePayment();
  }

  @override
  void dispose() {
    _successCtrl.dispose();
    super.dispose();
  }

  // Gọi POST /payments/initiate thật để lấy transactionId + QR VietQR thật
  // từ BE, thay vì tạo QR giả từ 1 chuỗi tự bịa như trước.
  Future<void> _initiatePayment() async {
    setState(() {
      _isInitiating = true;
      _initError = null;
    });
    try {
      final payment = await _bookingService.initiatePayment(
        bookingId: widget.bookingId,
        paymentType: 'DEPOSIT',
        paymentMethod: 'BANK_TRANSFER',
      );
      if (!mounted) return;
      setState(() {
        _payment = payment;
        _isInitiating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = e.toString().replaceAll('Exception: ', '');
        _isInitiating = false;
      });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatPrice(double v) {
    final s = v.toInt().toString();
    return '${s.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} ₫';
  }

  // Gọi POST /payments/confirm thật với transactionId thật nhận được từ
  // bước initiate. Trước đây bước này chỉ Future.delayed(1.5s) rồi coi như
  // thành công, không có payment/booking nào được ghi nhận trong DB cả.
  Future<void> _confirmPayment() async {
    final transactionId = _payment?['transactionId']?.toString();
    if (transactionId == null || transactionId.isEmpty) return;

    setState(() => _isConfirming = true);
    try {
      final confirmed =
          await _bookingService.confirmPayment(transactionId: transactionId);
      if (!mounted) return;
      setState(() {
        _payment = confirmed;
        _isConfirming = false;
        _isSuccess = true;
      });
      _successCtrl.forward();
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isSuccess ? 'Đặt chỗ thành công' : 'Thanh toán cọc'),
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isSuccess
          ? _buildSuccessBody()
          : _isInitiating
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 12),
                      Text('Đang khởi tạo giao dịch thanh toán...'),
                    ],
                  ),
                )
              : _initError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: AppColors.error),
                            const SizedBox(height: 12),
                            Text(_initError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _initiatePayment,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Thử lại'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _buildPaymentBody(),
    );
  }

  // ── Màn hình Thành công ────────────────────────────────────────────────────

  Widget _buildSuccessBody() {
    return FadeTransition(
      opacity: _successFade,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 20),
          // Check icon
          Center(
            child: ScaleTransition(
              scale: _successScale,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.green.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 60),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Đặt chỗ thành công! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
              'Kho của bạn đã được xác nhận và đặt trước.\nHãy đến chi nhánh đúng ngày hẹn để nhận kho.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 28),
          // Mã đặt chỗ thật
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('Mã đặt chỗ của bạn',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Text(widget.bookingCode,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.bookingCode));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Đã sao chép mã đặt chỗ'),
                        backgroundColor: AppColors.success));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, color: Colors.white70, size: 14),
                        SizedBox(width: 4),
                        Text('Sao chép mã',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Thông tin đặt chỗ
          _summaryCard(),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Quay về màn hình chính
              int count = 0;
              Navigator.popUntil(context, (_) => count++ >= 2);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Về trang chủ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              side: const BorderSide(color: AppColors.primary),
            ),
            child: const Text('Xem kho của tôi',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  // ── Màn hình Thanh toán ────────────────────────────────────────────────────

  Widget _buildPaymentBody() {
    final payment = _payment!;
    final amount = (payment['amount'] as num?)?.toDouble() ?? widget.depositAmount;
    final transactionId = payment['transactionId']?.toString() ?? '';
    final qrCodeUrl = payment['qrCodeUrl']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Tóm tắt đơn hàng
        const Text('📋 Tóm tắt đặt chỗ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _summaryCard(),
        const SizedBox(height: 20),

        // QR Payment
        const Text('📱 Quét QR để thanh toán',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4))
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Bank header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF003087), Color(0xFF0057B7)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner,
                            color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('VietQR',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // QR code thật do BE sinh ra (qrCodeUrl)
              qrCodeUrl.isEmpty
                  ? Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('Không có mã QR',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  : Image.network(
                      qrCodeUrl,
                      width: 200,
                      height: 200,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          width: 200,
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'Không tải được ảnh QR.\nDùng mã giao dịch bên dưới để chuyển khoản.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 14),
              // Số tiền cần chuyển - số thật từ BE (PaymentResponse.amount)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    const Text('Số tiền cần chuyển',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(_formatPrice(amount),
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Mã giao dịch: ',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        Text(transactionId,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: transactionId));
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                                    content: Text('Đã sao chép mã giao dịch'),
                                    backgroundColor: AppColors.success));
                          },
                          child: const Icon(Icons.copy,
                              size: 14, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Hướng dẫn
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.amber, size: 18),
                  SizedBox(width: 6),
                  Text('Hướng dẫn thanh toán',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange)),
                ],
              ),
              SizedBox(height: 8),
              _Step(step: '1', text: 'Mở app ngân hàng → Chuyển tiền → QR'),
              _Step(step: '2', text: 'Quét mã QR bên trên'),
              _Step(
                  step: '3',
                  text: 'Nhập đúng số tiền & ghi chú mã giao dịch'),
              _Step(step: '4', text: 'Nhấn "Xác nhận đã thanh toán" bên dưới'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // CTA buttons
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isConfirming ? null : _confirmPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: _isConfirming
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text('Xác nhận đã thanh toán',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Thanh toán sau',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _summaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _summaryRow(
              icon: Icons.confirmation_number_outlined,
              label: 'Mã đặt chỗ',
              value: widget.bookingCode),
          const Divider(height: 16),
          _summaryRow(
              icon: Icons.warehouse_outlined,
              label: 'Chi nhánh',
              value: widget.facilityName),
          const Divider(height: 16),
          _summaryRow(
              icon: Icons.category_outlined,
              label: 'Loại kho',
              value: '${widget.unitTypeName} (${widget.unitTypeDimensions})'),
          const Divider(height: 16),
          _summaryRow(
              icon: Icons.calendar_today_outlined,
              label: 'Ngày bắt đầu',
              value: _formatDate(widget.startDate)),
          const Divider(height: 16),
          _summaryRow(
              icon: Icons.date_range_outlined,
              label: 'Chu kỳ thuê',
              value: '${widget.rentalMonths} tháng'),
          const Divider(height: 16),
          _summaryRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Tiền thuê',
              value: _formatPrice(widget.totalRentalFee)),
          const Divider(height: 16, thickness: 1.5),
          _summaryRow(
              icon: Icons.shield_outlined,
              label: '💳 Tiền cọc',
              value: _formatPrice(widget.depositAmount),
              isHighlight: true),
        ],
      ),
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        Icon(icon,
            size: 18,
            color: isHighlight ? AppColors.primary : AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: isHighlight ? 14 : 13,
                  fontWeight:
                      isHighlight ? FontWeight.bold : FontWeight.normal,
                  color: isHighlight
                      ? AppColors.textPrimary
                      : AppColors.textSecondary)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: isHighlight ? 16 : 13,
                fontWeight: FontWeight.bold,
                color:
                    isHighlight ? AppColors.primary : AppColors.textPrimary)),
      ],
    );
  }
}

// ── Step widget ───────────────────────────────────────────────────────────────

class _Step extends StatelessWidget {
  final String step;
  final String text;

  const _Step({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
                color: Colors.orange, shape: BoxShape.circle),
            child: Center(
              child: Text(step,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}
