import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/booking_api_service.dart';

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
  final double totalExtraFees;
  final double initialPaymentAmount;
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
    this.totalExtraFees = 0,
    this.initialPaymentAmount = 0,
    this.expiresAt,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with TickerProviderStateMixin {
  final BookingApiService _bookingService = BookingApiService();

  // Screen state
  bool _isSuccess = false;
  bool _isConfirming = false;
  bool _isCancelling = false;

  bool _isInitiating = true;
  String? _initError;
  Map<String, dynamic>? _payment;

  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  bool _isExpired = false;

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

    _startCountdown();
    _initiatePayment();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _successCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    if (widget.expiresAt == null) return;
    _remaining = widget.expiresAt!.difference(DateTime.now());
    if (_remaining.isNegative) {
      _isExpired = true;
      return;
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final newRemaining = widget.expiresAt!.difference(DateTime.now());
      setState(() {
        if (newRemaining.isNegative) {
          _remaining = Duration.zero;
          _isExpired = true;
          _countdownTimer?.cancel();
        } else {
          _remaining = newRemaining;
        }
      });
    });
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

  String _formatCountdown(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

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
      _countdownTimer?.cancel();
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

  Future<void> _cancelBooking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hủy đặt chỗ?'),
        content: const Text(
            'Kho đang giữ cho bạn sẽ được giải phóng và bạn phải đặt lại từ đầu. '
            'Bạn có chắc muốn hủy không?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Tiếp tục thanh toán')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy đặt chỗ'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isCancelling = true);
    try {
      await _bookingService.cancelBooking(bookingId: widget.bookingId);
      if (!mounted) return;
      _countdownTimer?.cancel();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đặt chỗ đã được hủy. Kho đã được giải phóng.'),
          backgroundColor: AppColors.success,
        ),
      );
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isSuccess ? 'Booking Confirmed' : 'Deposit Payment'),
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

  Widget _buildCountdownBanner() {
    if (widget.expiresAt == null) return const SizedBox.shrink();

    final color = _isExpired
        ? AppColors.error
        : _remaining.inMinutes < 5
            ? Colors.orange
            : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(
            _isExpired ? Icons.timer_off : Icons.timer_outlined,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _isExpired
                ? Text(
                    'Booking expired. Please go back and create a new booking.',
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  )
                : RichText(
                    text: TextSpan(
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      children: [
                        const TextSpan(text: 'Unit held for '),
                        TextSpan(
                          text: _formatCountdown(_remaining),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' — pay before time runs out!'),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBody() {
    return FadeTransition(
      opacity: _successFade,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 20),
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.mark_email_read_outlined,
                    color: Colors.green, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Booking confirmation email has been sent to your email address.',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
                        Text('Copy code',
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
          _buildSuccessBreakdown(),
          const SizedBox(height: 20),
          _summaryCard(),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
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

  Widget _buildSuccessBreakdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long, color: AppColors.primary, size: 18),
              SizedBox(width: 6),
              Text('Payment Breakdown',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.primary)),
            ],
          ),
          const Divider(height: 16),
          _breakdownRow('Rental fee (${widget.rentalMonths} mo)',
              _formatPrice(widget.totalRentalFee)),
          _breakdownRow('Deposit (refundable)',
              _formatPrice(widget.depositAmount)),
          _breakdownRow('Management fee',
              _formatPrice(widget.totalExtraFees)),
          const Divider(height: 16, thickness: 1.5),
          _breakdownRow(
            '💳 Total Paid',
            _formatPrice(widget.initialPaymentAmount > 0
                ? widget.initialPaymentAmount
                : widget.totalRentalFee + widget.depositAmount + widget.totalExtraFees),
            isHighlight: true,
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, String value,
      {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: isHighlight ? 14 : 13,
                  fontWeight:
                      isHighlight ? FontWeight.bold : FontWeight.normal,
                  color: isHighlight
                      ? AppColors.textPrimary
                      : AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: isHighlight ? 16 : 13,
                  fontWeight: FontWeight.bold,
                  color: isHighlight ? AppColors.primary : AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildPaymentBody() {
    final payment = _payment!;
    final amount =
        (payment['amount'] as num?)?.toDouble() ?? widget.depositAmount;
    final transactionId = payment['transactionId']?.toString() ?? '';
    final qrCodeUrl = payment['qrCodeUrl']?.toString() ?? '';

    return Column(
      children: [
        _buildCountdownBanner(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_isExpired)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.timer_off, color: AppColors.error, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your booking has expired. The unit has been released. '
                          'Please go back and create a new booking.',
                          style: TextStyle(
                              color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              const Text('📋 Booking Summary',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _summaryCard(),
              const SizedBox(height: 20),

              const Text('📱 Scan QR to Pay',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF003087),
                                  Color(0xFF0057B7)
                                ]),
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
                    qrCodeUrl.isEmpty
                        ? Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text('No QR code available',
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
                                child: Center(
                                    child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
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
                                    "Couldn't load the QR image.\nUse the transaction code below to transfer manually.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          const Text('Amount to transfer',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
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
                              const Text('Transaction code: ',
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
                                          content: Text(
                                              'Transaction code copied'),
                                          backgroundColor:
                                              AppColors.success));
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
                        Text('Payment Instructions',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange)),
                      ],
                    ),
                    SizedBox(height: 8),
                    _Step(
                        step: '1',
                        text: 'Open your banking app → Transfer → Scan QR'),
                    _Step(step: '2', text: 'Scan the QR code above'),
                    _Step(
                        step: '3',
                        text:
                            'Enter the exact amount & note the transaction code'),
                    _Step(step: '4', text: 'Tap "Confirm Payment" below'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      (_isConfirming || _isExpired) ? null : _confirmPayment,
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
                            Text('Confirm Payment',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: _isCancelling ? null : _cancelBooking,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.6)),
                  ),
                  child: _isCancelling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.error))
                      : const Text('Hủy đặt chỗ',
                          style: TextStyle(
                              color: AppColors.error, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
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
              value:
                  '${widget.unitTypeName} (${widget.unitTypeDimensions})'),
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
          const Divider(height: 16, thickness: 1.5),
          _summaryRow(
              icon: Icons.shield_outlined,
              label: '💳 Deposit',
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
                color: isHighlight ? AppColors.primary : AppColors.textPrimary)),
      ],
    );
  }
}

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
