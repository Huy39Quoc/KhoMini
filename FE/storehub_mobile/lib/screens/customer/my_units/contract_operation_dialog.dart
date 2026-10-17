import '../payment/vnpay_checkout_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/my_unit_model.dart';
import '../../../services/storage_api_service.dart';

class ContractOperationDialog extends StatefulWidget {
  final MyUnitModel unit;
  final bool isExtension;
  final bool resumePending;

  /// true = khách bấm "Pay late fee": dialog tải khoản phí trễ hạn đang chờ
  /// (GET /payments/bookings/{id}/overdue) và cho thanh toán qua VNPay Sandbox.
  final bool payOverdue;

  const ContractOperationDialog({
    super.key,
    required this.unit,
    required this.isExtension,
    this.resumePending = false,
    this.payOverdue = false,
  });

  @override
  State<ContractOperationDialog> createState() =>
      _ContractOperationDialogState();
}

class _ContractOperationDialogState extends State<ContractOperationDialog> {
  static const bool _sandboxMode = bool.fromEnvironment('VNPAY_SANDBOX') ||
      !bool.fromEnvironment('dart.vm.product');
  final StorageApiService _storageService = StorageApiService();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _bankCodeController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final _currency = NumberFormat.currency(
      locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _dateTimeFmt = DateFormat('dd/MM/yyyy • HH:mm');

  int _extraMonths = 3;
  DateTime? _scheduledReturnTime;
  bool _isLoading = false;
  bool _isResuming = false;
  bool _isCancellingExtension = false;
  String? _resumeError;
  Map<String, dynamic>? _result;
  Map<String, dynamic>? _paymentConfirmed;

  @override
  void initState() {
    super.initState();
    if (widget.payOverdue) {
      _loadOverduePayment();
    } else if (widget.resumePending) {
      _loadPendingExtensionPayment();
    }
  }

  Future<void> _loadOverduePayment() async {
    setState(() {
      _isResuming = true;
      _resumeError = null;
    });
    try {
      final payment =
          await _storageService.getPendingOverduePayment(widget.unit.bookingId);
      if (!mounted) return;
      if (payment == null) {
        setState(() {
          _isResuming = false;
          _resumeError = 'Ngăn kho này không còn phí trễ hạn.';
        });
        return;
      }
      if (payment['status'] == 'PAID') {
        setState(() {
          _isResuming = false;
          _paymentConfirmed = payment;
          _result = {'paymentRequired': false};
        });
        return;
      }
      setState(() {
        _isResuming = false;
        _result = {
          'paymentRequired': true,
          'transactionId': payment['transactionId'],
          'qrCodeUrl': payment['qrCodeUrl'],
          'additionalFee': payment['amount'],
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResuming = false;
        _resumeError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // Hủy yêu cầu gia hạn đang chờ thanh toán để khách không bị kẹt ở trạng thái "pending".
  Future<void> _cancelExtension() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy yêu cầu gia hạn?'),
        content: const Text(
          'Yêu cầu gia hạn sẽ bị hủy. Nếu VNPay vẫn thu tiền '
          'từ liên kết cũ, hệ thống sẽ yêu cầu hoàn tiền. '
          'Sau đó bạn có thể yêu cầu gia hạn mới.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ lại'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy yêu cầu'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isCancellingExtension = true);
    try {
      await _storageService.cancelPendingExtension(widget.unit.bookingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã hủy yêu cầu gia hạn'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancellingExtension = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _loadPendingExtensionPayment() async {
    setState(() {
      _isResuming = true;
      _resumeError = null;
    });
    try {
      final payment = await _storageService
          .getPendingExtensionPayment(widget.unit.bookingId);
      if (!mounted) return;
      if (payment == null) {
        setState(() {
          _isResuming = false;
          _resumeError =
              'Không còn khoản gia hạn nào đang chờ thanh toán cho ngăn kho này.';
        });
        return;
      }
      if (payment['status'] == 'PAID') {
        setState(() {
          _isResuming = false;
          _paymentConfirmed = payment;
          _result = {'paymentRequired': false};
        });
        return;
      }
      setState(() {
        _isResuming = false;
        _result = {
          'paymentRequired': true,
          'transactionId': payment['transactionId'],
          'qrCodeUrl': payment['qrCodeUrl'],
          'additionalFee': payment['amount'],
          'newEndDate': widget.unit.pendingNewEndDate
              ?.toIso8601String().substring(0, 10),
          'updatedTotalFee': widget.unit.totalRentalFee +
              (widget.unit.pendingExtensionFee ?? 0),
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResuming = false;
        _resumeError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _bankCodeController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _pickScheduledReturnTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _scheduledReturnTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submitAction() async {
    if (!widget.isExtension && _scheduledReturnTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ngày giờ hẹn trả kho.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> result;
      if (widget.isExtension) {
        result = await _storageService.extendRental(
            widget.unit.bookingId, _extraMonths);
      } else {
        result = await _storageService.checkoutRental(
          widget.unit.bookingId,
          _scheduledReturnTime!,
          notes: _notesController.text,
          bankCode: _bankCodeController.text,
          bankAccountNumber: _accountNumberController.text,
          bankAccountName: _accountNameController.text,
        );
      }

      if (!mounted) return;
      setState(() {
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _needsExtensionPayment =>
      (widget.isExtension || widget.payOverdue) &&
      _result != null &&
      _result!['paymentRequired'] == true &&
      _paymentConfirmed == null;

  /// Mở VNPay Sandbox trong app. Giao dịch chỉ thành PAID khi VNPay gọi về server;
  /// khách không thể tự bấm "đã trả".
  Future<void> _payWithVnpay() async {
    // Re-read the attempt: a previously displayed URL can have expired.
    try {
      if (widget.payOverdue) {
        await _loadOverduePayment();
      } else {
        await _loadPendingExtensionPayment();
      }
    } catch (_) {
      return;
    }
    if (!mounted || _paymentConfirmed != null || _resumeError != null) return;
    final result = _result;
    if (result == null) return;
    final transactionId = result['transactionId']?.toString() ?? '';
    final paymentUrl =
        (result['paymentUrl'] ?? result['qrCodeUrl'])?.toString() ?? '';
    if (transactionId.isEmpty || paymentUrl.isEmpty) return;
    final fee = num.tryParse(result['additionalFee']?.toString() ?? '') ?? 0;

    final paid = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => VnpayCheckoutScreen(
          paymentUrl: paymentUrl,
          transactionId: transactionId,
          amount: fee.toDouble(),
          title: widget.payOverdue ? 'Phí trễ hạn • VNPay Sandbox' : 'Gia hạn • VNPay Sandbox',
          fetchStatus: _storageService.getPaymentStatus,
        ),
      ),
    );
    if (!mounted) return;
    if (paid != null) {
      setState(() => _paymentConfirmed = paid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resuming = widget.resumePending || widget.payOverdue;
    if (resuming && _isResuming) {
      return const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (resuming && _resumeError != null) {
      return AlertDialog(
        title: Text(widget.payOverdue
            ? 'Không tải được phí trễ hạn'
            : 'Không thể tiếp tục thanh toán'),
        content: Text(_resumeError!, style: const TextStyle(fontSize: 13)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OK'),
          ),
        ],
      );
    }
    if (_needsExtensionPayment) {
      return _buildExtensionPaymentDialog();
    }
    if (_result != null) {
      return _buildResultDialog();
    }
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.isExtension ? 'Gia hạn thuê' : 'Yêu cầu trả kho'),
      content: SingleChildScrollView(
        child: widget.isExtension ? _buildExtendForm() : _buildCheckoutForm(),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitAction,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.isExtension ? 'Gia hạn' : 'Xác nhận trả kho'),
        ),
      ],
    );
  }

  Widget _buildExtendForm() {
    final unit = widget.unit;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ngăn ${unit.unitCode}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (unit.monthlyRate != null)
                Text(
                    'Giá hiện tại: ${_currency.format(unit.monthlyRate)} / tháng',
                    style: const TextStyle(fontSize: 12)),
              if (unit.endDate != null)
                Text('Ngày hết hạn hiện tại: ${_dateFmt.format(unit.endDate!)}',
                    style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Gia hạn thêm bao nhiêu tháng?',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [1, 3, 6, 12].map((m) {
            final selected = _extraMonths == m;
            return ChoiceChip(
              label: Text('+$m tháng'),
              selected: selected,
              onSelected: (_) => setState(() => _extraMonths = m),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Tùy chọn:', style: TextStyle(fontSize: 12)),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: _extraMonths > 1
                  ? () => setState(() => _extraMonths--)
                  : null,
            ),
            Text('$_extraMonths tháng',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _extraMonths < 36
                  ? () => setState(() => _extraMonths++)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Phí gia hạn chính xác do hệ thống tính và hiển thị sau khi bạn xác nhận.',
          style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildCheckoutForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ngăn ${widget.unit.unitCode}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text('Chọn ngày giờ để hẹn trả kho.',
            style: TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _pickScheduledReturnTime,
          icon: const Icon(Icons.event),
          label: Text(
            _scheduledReturnTime == null
                ? 'Chọn ngày giờ trả kho'
                : _dateTimeFmt.format(_scheduledReturnTime!),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance, size: 18, color: Colors.blue.shade800),
                  const SizedBox(width: 8),
                  Text(
                    'Thông tin ngân hàng nhận hoàn cọc',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Nhập tài khoản ngân hàng để quản lý cơ sở chuyển khoản hoàn cọc sau khi nghiệm thu.',
                style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bankCodeController,
                decoration: const InputDecoration(
                  labelText: 'Ngân hàng (VD: MBBank, VCB)',
                  prefixIcon: Icon(Icons.account_balance_outlined, size: 20),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _accountNumberController,
                decoration: const InputDecoration(
                  labelText: 'Số tài khoản',
                  prefixIcon: Icon(Icons.numbers, size: 20),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _accountNameController,
                decoration: const InputDecoration(
                  labelText: 'Tên chủ tài khoản',
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Ghi chú cho nhân viên cơ sở (không bắt buộc)',
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildExtensionPaymentDialog() {
    final result = _result!;
    final transactionId = result['transactionId']?.toString() ?? '';
    final fee = num.tryParse(result['additionalFee']?.toString() ?? '') ?? 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.payOverdue ? 'Thanh toán phí trễ hạn' : 'Thanh toán phí gia hạn'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.payOverdue
                  ? 'Phí trễ hạn: ${_currency.format(fee)}'
                  : 'Phí gia hạn: ${_currency.format(fee)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              widget.payOverdue
                  ? 'Thanh toán phí trễ hạn không làm gia hạn hợp đồng. Để khôi phục truy cập, hãy '
                      'gia hạn hoặc hẹn trả kho.'
                  : 'Hợp đồng chỉ được gia hạn sau khi thanh toán này được xác nhận.',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
            if (_sandboxMode) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Column(
                  children: [
                    Text('THẺ THỬ VNPAY SANDBOX',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF003087))),
                    SizedBox(height: 6),
                    Text('Bank: NCB | Card: 9704198526191432198',
                        style: TextStyle(fontSize: 11)),
                    Text('Name: NGUYEN VAN A | Date: 07/15 | OTP: 123456',
                        style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text('Mã giao dịch: $transactionId',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
      actions: [
        if (!widget.payOverdue)
          TextButton(
            onPressed: _isCancellingExtension ? null : _cancelExtension,
            child: _isCancellingExtension
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Hủy yêu cầu',
                    style: TextStyle(color: AppColors.error)),
          ),
        TextButton(
          // true: server có thể đã tạo yêu cầu gia hạn treo -> màn danh sách cần tải lại
          onPressed: _isCancellingExtension
              ? null
              : () => Navigator.pop(context, true),
          child: const Text('Đóng'),
        ),
        ElevatedButton(
          onPressed: _isCancellingExtension ? null : _payWithVnpay,
          child: const Text('Thanh toán qua VNPay'),
        ),
      ],
    );
  }

  Widget _buildResultDialog() {
    final result = _result!;
    final message = widget.payOverdue
        ? 'Đã thanh toán phí trễ hạn. Hãy gia hạn hoặc hẹn trả kho để khôi phục quyền truy cập.'
        : (widget.isExtension && _paymentConfirmed != null)
            ? 'Đã xác nhận thanh toán. Hợp đồng của bạn đã được gia hạn.'
            : result['message']?.toString();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success),
          SizedBox(width: 8),
          Text('Đã ghi nhận yêu cầu'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null && message.isNotEmpty) ...[
            Text(message, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
          ],
          if (widget.isExtension) ...[
            if (result['newEndDate'] != null)
              _resultRow('Ngày hết hạn mới', result['newEndDate'].toString()),
            if (result['additionalFee'] != null)
              _resultRow(
                'Phí phát sinh',
                _currency.format(
                    num.tryParse(result['additionalFee'].toString()) ?? 0),
              ),
            if (result['updatedTotalFee'] != null)
              _resultRow(
                'Tổng tiền thuê mới',
                _currency.format(
                    num.tryParse(result['updatedTotalFee'].toString()) ?? 0),
              ),
          ] else if (widget.payOverdue) ...[
            if (result['additionalFee'] != null)
              _resultRow(
                'Đã thanh toán phí trễ hạn',
                _currency.format(
                    num.tryParse(result['additionalFee'].toString()) ?? 0),
              ),
          ] else ...[
            if (result['scheduledReturnTime'] != null)
              _resultRow(
                  'Hẹn trả kho', result['scheduledReturnTime'].toString()),
            if (result['status'] != null)
              _resultRow('Trạng thái', result['status'].toString()),
          ],
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Xong'),
        ),
      ],
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.onSurfaceVariant)),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
