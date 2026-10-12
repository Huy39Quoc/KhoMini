import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/booking_api_service.dart';
import '../payment/vnpay_checkout_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String bookingId;
  final String bookingCode;
  final String facilityName;
  final String unitTypeName;
  final String unitTypeDimensions;
  final DateTime startDate;
  final int rentalMonths;
  final double totalRentalFee;
  final double depositAmount;
  final DateTime? expiresAt;

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
    this.expiresAt,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final BookingApiService _bookingService = BookingApiService();

  bool _isSuccess = false;
  bool _isCancelling = false;

  bool _isInitiating = true;
  String? _initError;
  Map<String, dynamic>? _payment;

  Timer? _expiryTimer;
  Duration? _remaining;

  // Animation cho success
  late final AnimationController _successCtrl;
  late final Animation<double> _successScale;
  late final Animation<double> _successFade;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale =
        CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);
    _successFade = CurvedAnimation(parent: _successCtrl, curve: Curves.easeIn);

    _initiatePayment();
    _startExpiryCountdown();
  }

  void _startExpiryCountdown() {
    final expiresAt = widget.expiresAt;
    if (expiresAt == null) return;
    void tick() {
      final diff = expiresAt.difference(DateTime.now());
      if (!mounted) return;
      setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
    }

    tick();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  String _formatCountdown(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _isExpired => _remaining != null && _remaining == Duration.zero;

  Future<void> _handleExpiredOrCancel({required bool wasExpired}) async {
    setState(() => _isCancelling = true);
    try {
      if (!wasExpired) {
        await _bookingService.cancelBooking(widget.bookingId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              wasExpired ? 'This booking has expired.' : 'Booking cancelled.'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _successCtrl.dispose();
    _expiryTimer?.cancel();
    super.dispose();
  }

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
        _isSuccess = payment['status'] == 'PAID';
      });
      if (_isSuccess) _successCtrl.forward();
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

  /// Mở trang VNPay Sandbox ngay trong app (kèm bảng thẻ test). Giao dịch chỉ thành PAID khi
  /// VNPay gọi về server; app chỉ đọc lại trạng thái, không tự xác nhận.
  Future<void> _payWithVnpay() async {
    if (_isExpired || _payment == null) return;
    // The booking may still be valid after the previous 15-minute VNPay URL expires.
    // Ask the server to reconcile and return the current attempt before opening it.
    await _initiatePayment();
    if (!mounted || _isSuccess || _initError != null || _isExpired) return;
    final transactionId = _payment!['transactionId']?.toString() ?? '';
    final paymentUrl =
        (_payment!['paymentUrl'] ?? _payment!['qrCodeUrl'])?.toString() ?? '';
    if (transactionId.isEmpty || paymentUrl.isEmpty) return;
    final amount =
        (_payment!['amount'] as num?)?.toDouble() ?? widget.depositAmount;

    final paid = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => VnpayCheckoutScreen(
          paymentUrl: paymentUrl,
          transactionId: transactionId,
          amount: amount,
          title: 'Deposit • VNPay Sandbox',
          fetchStatus: (id) => _bookingService.getPaymentStatus(transactionId: id),
        ),
      ),
    );
    if (!mounted) return;
    if (paid != null) {
      setState(() {
        _payment = paid;
        _isSuccess = true;
      });
      _successCtrl.forward();
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isSuccess ? 'Booking Confirmed' : 'Deposit Payment'),
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isSuccess && _remaining != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isExpired
                        ? AppColors.error.withValues(alpha: 0.25)
                        : Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        _isExpired ? 'Expired' : _formatCountdown(_remaining!),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!_isSuccess)
            IconButton(
              tooltip: 'Cancel booking',
              icon: _isCancelling
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.close),
              onPressed: _isCancelling
                  ? null
                  : () async {
                      if (_isExpired) {
                        await _handleExpiredOrCancel(wasExpired: true);
                        return;
                      }
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Cancel this booking?'),
                          content: const Text(
                              'The reserved unit will be released back to availability.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Keep booking')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Cancel booking'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _handleExpiredOrCancel(wasExpired: false);
                      }
                    },
            ),
        ],
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
                      Text('Setting up your payment...'),
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
                              label: const Text('Try again'),
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

  // ── Success screen ────────────────────────────────────────────────────────

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
          const Text('Booking Confirmed! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
              'Your storage unit has been confirmed and reserved.\nPlease visit the facility on your scheduled date to check in.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 28),
          // Real booking code
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
                const Text('Your booking code',
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
                        content: Text('Booking code copied'),
                        backgroundColor: AppColors.success));
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, color: Colors.white70, size: 14),
                        SizedBox(width: 4),
                        Text('Copy code',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Booking details
          _summaryCard(),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Back to the home screen
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
            child: const Text('Back to Home',
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
            child: const Text('View My Units',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  // ── Payment screen ────────────────────────────────────────────────────────

  Widget _buildPaymentBody() {
    final payment = _payment!;
    final amount =
        (payment['amount'] as num?)?.toDouble() ?? widget.depositAmount;
    final transactionId = payment['transactionId']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_isExpired)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.timer_off_outlined, color: AppColors.error),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This booking has expired and the unit has been released. Please start a new reservation.',
                    style: TextStyle(color: AppColors.error, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        // Order summary
        const Text('📋 Booking Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _summaryCard(),
        const SizedBox(height: 20),

        // VNPay Gateway
        const Text('💳 VNPay Gateway',
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF003087), Color(0xFF0057B7)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_balance_wallet,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('VNPAY SANDBOX',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.1)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Amount card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    const Text('Payable Amount',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(_formatPrice(amount),
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Txn Ref: ',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                        Text(transactionId,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: transactionId));
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Transaction code copied'),
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

        // Test card details box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.credit_card, color: Color(0xFF0057B7), size: 20),
                  SizedBox(width: 8),
                  Text('VNPay Sandbox Test Card',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF003087))),
                ],
              ),
              const SizedBox(height: 12),
              _buildTestCardRow('Bank (Ngân hàng):', 'NCB'),
              const Divider(height: 12),
              _buildTestCardRow('Card Number (Số thẻ):', '9704198526191432198'),
              const Divider(height: 12),
              _buildTestCardRow('Cardholder (Chủ thẻ):', 'NGUYEN VAN A'),
              const Divider(height: 12),
              _buildTestCardRow('Expiry (Ngày phát hành):', '07/15'),
              const Divider(height: 12),
              _buildTestCardRow('OTP Code:', '123456'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Instructions
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
                  Icon(Icons.info_outline, color: Colors.amber, size: 18),
                  SizedBox(width: 6),
                  Text('Payment Steps',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.orange)),
                ],
              ),
              SizedBox(height: 8),
              _Step(step: '1', text: 'Tap "Pay with VNPay Sandbox" below'),
              _Step(step: '2', text: 'Choose NCB bank on the VNPay page'),
              _Step(step: '3', text: 'Copy the test card info above into the form, OTP 123456'),
              _Step(step: '4', text: 'The app confirms automatically once VNPay reports success'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // CTA buttons
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isExpired ? null : _payWithVnpay,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 20),
                SizedBox(width: 8),
                Text('Pay with VNPay Sandbox',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Pay later',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTestCardRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.black87)),
        Row(
          children: [
            SelectableText(
              value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003087)),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label copied'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: const Icon(Icons.copy, size: 13, color: Color(0xFF0057B7)),
            ),
          ],
        ),
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
              label: 'Booking code',
              value: widget.bookingCode),
          const Divider(height: 16),
          _summaryRow(
              icon: Icons.warehouse_outlined,
              label: 'Facility',
              value: widget.facilityName),
          const Divider(height: 16),
          _summaryRow(
              icon: Icons.category_outlined,
              label: 'Unit type',
              value: '${widget.unitTypeName} (${widget.unitTypeDimensions})'),
          const Divider(height: 16),
          _summaryRow(
              icon: Icons.calendar_today_outlined,
              label: 'Start date',
              value: _formatDate(widget.startDate)),
          const Divider(height: 16),
          _summaryRow(
              icon: Icons.date_range_outlined,
              label: 'Rental period',
              value: '${widget.rentalMonths} months'),
          const Divider(height: 16),
          _summaryRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Rental fee',
              value: _formatPrice(widget.totalRentalFee)),
          const Divider(height: 16),
          _summaryRow(
              icon: Icons.shield_outlined,
              label: 'Deposit (refundable)',
              value: _formatPrice(widget.depositAmount)),
          if (_payment?['amount'] is num &&
              (_payment!['amount'] as num) -
                      widget.totalRentalFee -
                      widget.depositAmount >
                  0) ...[
            const Divider(height: 16),
            _summaryRow(
                icon: Icons.build_circle_outlined,
                label: 'Management fee',
                value: _formatPrice((_payment!['amount'] as num).toDouble() -
                    widget.totalRentalFee -
                    widget.depositAmount)),
          ],
          const Divider(height: 16, thickness: 1.5),
          _summaryRow(
              icon: Icons.payments_outlined,
              label: '💳 Total to pay',
              value: _formatPrice(
                  (_payment?['amount'] as num?)?.toDouble() ??
                      (widget.totalRentalFee + widget.depositAmount)),
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
                  fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
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
