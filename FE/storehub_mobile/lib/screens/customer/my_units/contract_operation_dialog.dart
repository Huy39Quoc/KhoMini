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
  /// (GET /payments/bookings/{id}/overdue) và cho thanh toán qua VNPay.
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
  String? _timeValidationError;
  String? _bankError;
  String? _accountNumberError;
  String? _accountNameError;
  bool _isLoading = false;
  bool _isResuming = false;
  bool _isCancellingExtension = false;
  String? _resumeError;
  Map<String, dynamic>? _result;
  Map<String, dynamic>? _paymentConfirmed;

  static const List<String> _popularBanks = [
    'MBBank',
    'Vietcombank',
    'Techcombank',
    'BIDV',
    'ACB',
    'VietinBank',
    'VPBank',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.payOverdue) {
      _loadOverduePayment();
    } else if (widget.resumePending) {
      _loadPendingExtensionPayment();
    } else if (!widget.isExtension) {
      final now = DateTime.now();
      final openH = widget.unit.openHour;
      final closeH = widget.unit.closeHour;
      if (now.hour < closeH) {
        int targetHour;
        if (now.hour < openH) {
          targetHour = (openH <= 9 && closeH >= 9) ? 9 : openH;
        } else {
          targetHour = now.minute >= 45 ? now.hour + 2 : now.hour + 1;
          if (targetHour >= closeH) {
            targetHour = closeH;
          }
        }
        _scheduledReturnTime = DateTime(
          now.year,
          now.month,
          now.day,
          targetHour,
          0,
        );
      } else {
        final tomorrow = now.add(const Duration(days: 1));
        final defaultHour = (openH <= 9 && closeH >= 9) ? 9 : openH;
        _scheduledReturnTime = DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          defaultHour,
          0,
        );
      }
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

  void _setScheduledTime(DateTime dt) {
    final minuteFraction = dt.minute / 60.0;
    final totalHours = dt.hour + minuteFraction;
    final openH = widget.unit.openHour.toDouble();
    final closeH = widget.unit.closeHour.toDouble();

    String? error;
    if (totalHours < openH || totalHours > closeH) {
      final hourStr =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      error =
          'Giờ hẹn ($hourStr) nằm ngoài khung giờ mở cửa (${widget.unit.operatingHours}). Vui lòng chọn giờ trong khung giờ này.';
    } else if (dt.isBefore(DateTime.now())) {
      error = 'Giờ hẹn trả kho phải ở thời điểm tương lai.';
    }

    setState(() {
      _scheduledReturnTime = dt;
      _timeValidationError = error;
    });
  }

  List<TimeOfDay> get _suggestedTimeSlots {
    final defaultSlots = <TimeOfDay>[
      const TimeOfDay(hour: 9, minute: 0),
      const TimeOfDay(hour: 11, minute: 0),
      const TimeOfDay(hour: 14, minute: 0),
      const TimeOfDay(hour: 16, minute: 0),
      const TimeOfDay(hour: 18, minute: 0),
    ];
    return defaultSlots.where((s) {
      final h = s.hour + s.minute / 60.0;
      return h >= widget.unit.openHour && h <= widget.unit.closeHour;
    }).toList();
  }

  Future<void> _pickScheduledReturnTime() async {
    final now = DateTime.now();
    final initialDate = _scheduledReturnTime ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(now) ? now : initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'CHỌN NGÀY HẸN TRẢ KHO',
    );
    if (date == null || !mounted) return;

    final initialHour = _scheduledReturnTime?.hour ??
        ((widget.unit.openHour <= 9 && widget.unit.closeHour >= 9)
            ? 9
            : widget.unit.openHour);
    final initialMinute = _scheduledReturnTime?.minute ?? 0;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      helpText: 'CHỌN GIỜ HẸN TRẢ KHO (${widget.unit.operatingHours})',
    );
    if (time == null) return;

    _setScheduledTime(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Future<void> _submitAction() async {
    if (!widget.isExtension) {
      if (_scheduledReturnTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn ngày giờ hẹn trả kho.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (_timeValidationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_timeValidationError!),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final bank = _bankCodeController.text.trim();
      final accountNum = _accountNumberController.text.trim();
      final accountName = _accountNameController.text.trim();

      String? bankErr;
      String? numErr;
      String? nameErr;

      if (bank.isEmpty) {
        bankErr = 'Vui lòng chọn hoặc nhập tên ngân hàng';
      }
      if (accountNum.isEmpty) {
        numErr = 'Vui lòng nhập số tài khoản';
      } else if (accountNum.length < 6) {
        numErr = 'Số tài khoản không hợp lệ (tối thiểu 6 ký tự)';
      }
      if (accountName.isEmpty) {
        nameErr = 'Vui lòng nhập tên chủ tài khoản';
      }

      if (bankErr != null || numErr != null || nameErr != null) {
        setState(() {
          _bankError = bankErr;
          _accountNumberError = numErr;
          _accountNameError = nameErr;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng nhập đầy đủ thông tin tài khoản nhận hoàn cọc.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
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
          notes: _notesController.text.trim(),
          bankCode: _bankCodeController.text.trim(),
          bankAccountNumber: _accountNumberController.text.trim(),
          bankAccountName: _accountNameController.text.trim(),
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

  /// Mở VNPay trong app. Giao dịch chỉ thành PAID khi VNPay gọi về server;
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
          title: widget.payOverdue ? 'Phí trễ hạn • VNPay' : 'Gia hạn • VNPay',
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

    final titleWidget = widget.isExtension
        ? const Text('Gia hạn thuê')
        : Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.assignment_return_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Yêu cầu trả kho',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          );

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: titleWidget,
      content: SingleChildScrollView(
        child: widget.isExtension ? _buildExtendForm() : _buildCheckoutForm(),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: (_isLoading ||
                  (!widget.isExtension && _timeValidationError != null))
              ? null
              : _submitAction,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.isExtension ? 'Gia hạn' : 'Xác nhận trả kho',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
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
    final unit = widget.unit;
    final currentDateStr = _scheduledReturnTime != null
        ? _dateTimeFmt.format(_scheduledReturnTime!)
        : 'Chưa chọn thời gian';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Thẻ thông tin ngăn kho & cơ sở
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.warehouse_outlined,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Ngăn ${unit.unitCode}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule,
                            size: 12, color: Colors.green.shade800),
                        const SizedBox(width: 4),
                        Text(
                          unit.operatingHours,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                unit.dimensions.isNotEmpty
                    ? '${unit.typeName} • ${unit.dimensions}'
                    : unit.typeName,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 13, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      unit.facilityName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Khối chọn ngày giờ hẹn trả kho
        const Row(
          children: [
            Icon(Icons.event_available_outlined,
                size: 17, color: AppColors.primary),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                '1. Chọn ngày & giờ hẹn trả kho',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Vui lòng chọn thời điểm trong khung giờ mở cửa (${unit.operatingHours}).',
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),

        // Nút chọn ngày giờ lớn
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isLoading ? null : _pickScheduledReturnTime,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _timeValidationError != null
                    ? AppColors.error
                    : AppColors.outline.withValues(alpha: 0.5),
                width: _timeValidationError != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: _timeValidationError != null
                      ? AppColors.error
                      : AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    currentDateStr,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: _timeValidationError != null
                          ? AppColors.error
                          : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Đổi ngày/giờ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Quick time slot pills
        if (_suggestedTimeSlots.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _suggestedTimeSlots.map((slot) {
                final isSelected = _scheduledReturnTime != null &&
                    _scheduledReturnTime!.hour == slot.hour &&
                    _scheduledReturnTime!.minute == slot.minute;
                final slotText =
                    '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}';
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(slotText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.black87,
                        )),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceContainerHigh,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                    onSelected: (selected) {
                      if (!selected) return;
                      final base = _scheduledReturnTime ?? DateTime.now();
                      _setScheduledTime(DateTime(
                          base.year, base.month, base.day, slot.hour, slot.minute));
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // Lỗi cảnh báo ngoài khung giờ
        if (_timeValidationError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _timeValidationError!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // 3. Khối thông tin ngân hàng hoàn cọc (Tùy chọn)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 17, color: Colors.blue.shade800),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '2. Tài khoản nhận hoàn cọc (Bắt buộc)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Khoản tiền cọc sẽ được chuyển về tài khoản này sau khi nghiệm thu trả kho thành công:',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),

              // Gợi ý ngân hàng nhanh
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _popularBanks.map((bank) {
                    final selected = _bankCodeController.text == bank;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _bankCodeController.text = bank;
                            _bankError = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.blue.shade800
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? Colors.blue.shade800
                                  : Colors.blue.shade200,
                            ),
                          ),
                          child: Text(
                            bank,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: selected
                                  ? Colors.white
                                  : Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _bankCodeController,
                decoration: InputDecoration(
                  labelText: 'Ngân hàng * (VD: MBBank, Vietcombank)',
                  prefixIcon:
                      const Icon(Icons.account_balance_outlined, size: 18),
                  isDense: true,
                  errorText: _bankError,
                ),
                onChanged: (_) {
                  if (_bankError != null) setState(() => _bankError = null);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _accountNumberController,
                decoration: InputDecoration(
                  labelText: 'Số tài khoản *',
                  prefixIcon: const Icon(Icons.numbers, size: 18),
                  isDense: true,
                  errorText: _accountNumberError,
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  if (_accountNumberError != null) {
                    setState(() => _accountNumberError = null);
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _accountNameController,
                decoration: InputDecoration(
                  labelText: 'Tên chủ tài khoản *',
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                  isDense: true,
                  errorText: _accountNameError,
                ),
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) {
                  if (_accountNameError != null) {
                    setState(() => _accountNameError = null);
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 4. Ghi chú
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Ghi chú cho nhân viên cơ sở (không bắt buộc)',
            prefixIcon: Icon(Icons.edit_note, size: 20),
            hintText: 'Ví dụ: Đã dọn dẹp xong, cần hỗ trợ mở cửa...',
            isDense: true,
          ),
          maxLines: 2,
        ),

        const SizedBox(height: 12),

        // 5. Quy trình tóm tắt 3 bước
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 15, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Quy trình: 1. Hẹn giờ -> 2. Nghiệm thu tại kho -> 3. Hoàn cọc trong 3-5 ngày',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
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

    if (!widget.isExtension && !widget.payOverdue) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
            SizedBox(width: 8),
            Text(
              'Đã hẹn trả kho thành công',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yêu cầu trả kho của bạn đã được ghi nhận. Vui lòng có mặt tại cơ sở theo lịch hẹn để cùng nhân viên nghiệm thu bàn giao và nhận hoàn cọc.',
              style: TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  _resultRow('Ngăn kho', 'Ngăn ${widget.unit.unitCode}'),
                  if (_scheduledReturnTime != null)
                    _resultRow('Thời gian hẹn',
                        _dateTimeFmt.format(_scheduledReturnTime!)),
                  _resultRow('Cơ sở', widget.unit.facilityName),
                  _resultRow(
                    'Tài khoản hoàn cọc',
                    '${_bankCodeController.text.trim()} • ${_accountNumberController.text.trim()}',
                  ),
                  if (_accountNameController.text.trim().isNotEmpty)
                    _resultRow(
                      'Chủ tài khoản',
                      _accountNameController.text.trim().toUpperCase(),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Đã hiểu & Về danh sách'),
          ),
        ],
      );
    }

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.onSurfaceVariant)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
