import 'package:flutter/material.dart';
import '../../core/utils/vi_labels.dart';
import 'package:intl/intl.dart';

import '../../core/utils/safe_dispose.dart';
import '../../services/facility_ops_api_service.dart';

class RefundReviewScreen extends StatefulWidget {
  final String facilityId;
  const RefundReviewScreen({super.key, required this.facilityId});

  @override
  State<RefundReviewScreen> createState() => _RefundReviewScreenState();
}

class _RefundReviewScreenState extends State<RefundReviewScreen> {
  final _api = FacilityOpsApiService();
  late Future<Map<String, dynamic>> _requests;
  int _page = 0;
  String _filter = 'ALL';
  final _money = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload({bool resetPage = false}) => setState(() {
        if (resetPage) {
          _page = 0;
        }
        _requests = _api.getFacilityRefunds(widget.facilityId, page: _page);
      });

  Future<void> _provideDetails(Map<String, dynamic> refund) async {
    final date = TextEditingController();
    final transactionNo = TextEditingController();
    final amount = TextEditingController();
    try {
      final submitted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Giao dịch VNPay gốc'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Sao chép các giá trị này từ giao dịch gốc trên VNPay. '
                  'Không nhập ngày yêu cầu hoàn tiền.'),
              TextField(controller: date,
                  decoration: const InputDecoration(labelText: 'Ngày tạo giao dịch (yyyyMMddHHmmss)')),
              TextField(controller: transactionNo,
                  decoration: const InputDecoration(labelText: 'Mã giao dịch VNPay (không bắt buộc)')),
              TextField(controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Số tiền giao dịch gốc (VND)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(context, true),
                child: const Text('Gửi')),
          ],
        ),
      );
      if (submitted != true) return;
      final value = num.tryParse(amount.text.trim());
      if (!RegExp(r'^\d{14}$').hasMatch(date.text.trim()) || value == null
          || value < (num.tryParse('${refund['amount']}') ?? 0)) {
        throw const FormatException('Kiểm tra lại ngày và số tiền của giao dịch gốc.');
      }
      await _api.provideRefundDetails(widget.facilityId, '${refund['id']}',
          date.text.trim(), transactionNo.text.trim(), value);
      if (mounted) _reload(resetPage: true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      disposeAfterRouteCloses([date, transactionNo, amount]);
    }
  }

  Future<void> _retry(Map<String, dynamic> refund) async {
    try {
      await _api.retryRejectedRefund(widget.facilityId, '${refund['id']}');
      if (mounted) _reload(resetPage: true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    }
  }

  String _formatDateTime(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString());
      return DateFormat('dd/MM/yyyy • HH:mm').format(dt);
    } catch (_) {
      return raw.toString().replaceFirst('T', ' ');
    }
  }

  String _vnpayCodeDescription(String? code) {
    if (code == null || code.isEmpty) return '';
    switch (code) {
      case '00':
        return '00 (Đã tiếp nhận yêu cầu hoàn tiền thành công)';
      case '02':
        return '02 (Số tiền hoàn vượt quá giao dịch gốc)';
      case '03':
        return '03 (Dữ liệu gửi sang không đúng định dạng)';
      case '04':
        return '04 (Giao dịch đang được xử lý)';
      case '91':
        return '91 (Không tìm thấy giao dịch yêu cầu hoàn)';
      case '94':
        return '94 (Yêu cầu đang được xử lý)';
      case '95':
        return '95 (Giao dịch hoàn bị ngân hàng từ chối)';
      case '97':
        return '97 (Chữ ký không hợp lệ)';
      default:
        return code;
    }
  }

  bool _isReconciling = false;

  Future<void> _reconcile(Map<String, dynamic> refund) async {
    if (_isReconciling) return;
    setState(() => _isReconciling = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Đang truy vấn đối soát với cổng VNPay...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
    try {
      await _api.reconcileRefund(widget.facilityId, '${refund['id']}');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đồng bộ trạng thái mới nhất từ cổng VNPay!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        _reload(resetPage: true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kiểm tra VNPay: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReconciling = false);
    }
  }

  String _generateRefCode() {
    final now = DateTime.now();
    final ymd = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final millis = now.millisecondsSinceEpoch.toString();
    final suffix = millis.substring(millis.length > 5 ? millis.length - 5 : 0);
    return 'REF-$ymd-$suffix';
  }

  Future<void> _confirmBankTransfer(Map<String, dynamic> refund) async {
    final refController = TextEditingController(text: _generateRefCode());
    final noteController = TextEditingController();
    try {
      final amount = num.tryParse('${refund['amount']}') ?? 0;
      final submitted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xác nhận chuyển khoản hoàn cọc'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Số tiền hoàn cọc: ${_money.format(amount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                ),
                const SizedBox(height: 12),
                if (refund['bankCode'] != null || refund['bankAccountNumber'] != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (refund['bankCode'] != null)
                          Text('Ngân hàng: ${refund['bankCode']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (refund['bankAccountNumber'] != null)
                          Text('Số tài khoản: ${refund['bankAccountNumber']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        if (refund['bankAccountName'] != null)
                          Text('Chủ tài khoản: ${refund['bankAccountName']}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('Mã giao dịch ngân hàng đã được hệ thống tự tạo sẵn (bạn có thể đổi nếu muốn):'),
                const SizedBox(height: 8),
                TextField(
                  controller: refController,
                  decoration: InputDecoration(
                    labelText: 'Mã tham chiếu / Mã GD chuyển khoản *',
                    hintText: 'VD: FT2601019827361 hoặc GD-12345',
                    helperText: 'Tự động tạo mã, bấm biểu tượng để tạo lại',
                    suffixIcon: IconButton(
                      tooltip: 'Tạo mã mới',
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        refController.text = _generateRefCode();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú thêm (tùy chọn)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (refController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập mã tham chiếu giao dịch')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Xác nhận hoàn tất'),
            ),
          ],
        ),
      );

      if (submitted != true) return;

      await _api.confirmBankTransfer(
        widget.facilityId,
        '${refund['id']}',
        transferReference: refController.text.trim(),
        notes: noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xác nhận hoàn tiền cọc thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        _reload(resetPage: true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      disposeAfterRouteCloses([refController, noteController]);
    }
  }

  Widget _buildFilterTab(String label, String value, int count, Color activeColor) {
    final isSelected = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isCompleted = status == 'COMPLETED';
    final isPendingBank = status == 'AWAITING_BANK_TRANSFER';
    final isAwaitingVnpay = status == 'AWAITING_CONFIRMATION' || status == 'SENDING';

    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final IconData icon;
    final String label;

    if (isCompleted) {
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade300;
      textColor = Colors.green.shade800;
      icon = Icons.check_circle_rounded;
      label = 'ĐÃ HOÀN TẤT';
    } else if (isPendingBank) {
      bgColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade300;
      textColor = Colors.orange.shade900;
      icon = Icons.schedule_rounded;
      label = 'CHỜ CHUYỂN KHOẢN';
    } else if (isAwaitingVnpay) {
      bgColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade300;
      textColor = Colors.blue.shade900;
      icon = Icons.hourglass_top_rounded;
      label = 'CHỜ VNPAY XÁC NHẬN';
    } else {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade300;
      textColor = Colors.red.shade900;
      icon = Icons.error_outline_rounded;
      label = ViLabels.refund(status).toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Yêu cầu hoàn tiền'),
          actions: [
            IconButton(
              onPressed: () => _reload(resetPage: true),
              icon: const Icon(Icons.refresh),
              tooltip: 'Tải lại',
            ),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final result = snapshot.data!;
            final allRequests = (result['content'] as List? ?? const [])
                .map((item) => Map<String, dynamic>.from(item as Map)).toList();
            final totalPages = (result['totalPages'] as num?)?.toInt() ?? 0;
            final total = (result['totalElements'] as num?)?.toInt() ?? 0;

            final pendingCount = allRequests.where((r) => r['status'] != 'COMPLETED').length;
            final completedCount = allRequests.where((r) => r['status'] == 'COMPLETED').length;

            final requests = _filter == 'ALL'
                ? allRequests
                : (_filter == 'COMPLETED'
                    ? allRequests.where((r) => r['status'] == 'COMPLETED').toList()
                    : allRequests.where((r) => r['status'] != 'COMPLETED').toList());

            if (allRequests.isEmpty && total == 0) {
              return const Center(child: Text('Chưa có yêu cầu hoàn tiền nào.'));
            }

            return Column(
              children: [
                // Filter Tabs Bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterTab('Tất cả', 'ALL', allRequests.length, Colors.blue.shade800),
                        const SizedBox(width: 8),
                        _buildFilterTab('Chờ hoàn tiền', 'PENDING', pendingCount, Colors.orange.shade800),
                        const SizedBox(width: 8),
                        _buildFilterTab('Đã hoàn tiền', 'COMPLETED', completedCount, Colors.green.shade800),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: requests.isEmpty
                      ? Center(
                          child: Text(
                            _filter == 'PENDING'
                                ? 'Không có yêu cầu chờ hoàn tiền nào.'
                                : (_filter == 'COMPLETED'
                                    ? 'Chưa có yêu cầu đã hoàn tất nào.'
                                    : 'Không có yêu cầu phù hợp.'),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: requests.length + 1,
                          itemBuilder: (context, index) {
                            if (index == requests.length) {
                              return Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(children: [
                                  IconButton(
                                    tooltip: 'Trang trước',
                                    onPressed: _page > 0
                                        ? () {
                                            setState(() {
                                              _page--;
                                              _requests = _api.getFacilityRefunds(widget.facilityId, page: _page);
                                            });
                                          }
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Trang ${_page + 1} / $totalPages • $total yêu cầu',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Trang sau',
                                    onPressed: _page + 1 < totalPages
                                        ? () {
                                            setState(() {
                                              _page++;
                                              _requests = _api.getFacilityRefunds(widget.facilityId, page: _page);
                                            });
                                          }
                                        : null,
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ]),
                              );
                            }

                            final refund = requests[index];
                            final status = '${refund['status']}';
                            final isCompleted = status == 'COMPLETED';
                            final isPendingBank = status == 'AWAITING_BANK_TRANSFER';
                            final damageDeduction = num.tryParse('${refund['damageDeduction']}') ?? 0;

                            return Card(
                              margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                              elevation: isCompleted ? 0.5 : 2,
                              color: isCompleted ? const Color(0xFFF9FDF9) : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isCompleted
                                      ? Colors.green.shade300
                                      : (isPendingBank ? Colors.orange.shade400 : Colors.blue.shade200),
                                  width: isCompleted ? 1.2 : 1.5,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header: Mã đơn + Số tiền bên trái, Badge trạng thái bên phải
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${refund['bookingCode']}',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _money.format(num.tryParse('${refund['amount']}') ?? 0),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: isCompleted
                                                      ? Colors.green.shade700
                                                      : Colors.blue.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _buildStatusBadge(status),
                                      ],
                                    ),
                                    const Divider(height: 14),

                                    if (refund['originalTransactionId'] != null)
                                      Text('Giao dịch gốc: ${refund['originalTransactionId']}',
                                          style: const TextStyle(fontSize: 12.5)),
                                    if (damageDeduction > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          'Khấu trừ hư hại: -${_money.format(damageDeduction)}',
                                          style: const TextStyle(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5),
                                        ),
                                      ),
                                    if (refund['bankAccountNumber'] != null &&
                                        '${refund['bankAccountNumber']}'.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.blue.shade100),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.account_balance,
                                                    size: 16, color: Colors.blue),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '${refund['bankCode'] ?? 'Ngân hàng'}: ${refund['bankAccountNumber']}',
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                              ],
                                            ),
                                            if (refund['bankAccountName'] != null)
                                              Text('Chủ TK: ${refund['bankAccountName']}',
                                                  style: const TextStyle(fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (refund['transferReference'] != null &&
                                        '${refund['transferReference']}'.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.check_circle, size: 15, color: Colors.teal),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Mã GD chuyển tiền: ${refund['transferReference']}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal,
                                                  fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (refund['dueAt'] != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Hạn hoàn tiền: ${_formatDateTime(refund['dueAt'])}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: refund['overdue'] == true
                                              ? Colors.red
                                              : Colors.grey.shade700,
                                          fontWeight: refund['overdue'] == true
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      if (refund['overdue'] == true)
                                        const Text(
                                          'Đã quá hạn cam kết: cần xử lý/đối soát ngay.',
                                          style: TextStyle(color: Colors.red, fontSize: 12),
                                        ),
                                    ],
                                    if (refund['gatewayResponseCode'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          'Phản hồi VNPay: ${_vnpayCodeDescription(refund['gatewayResponseCode']?.toString())}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: refund['gatewayResponseCode'] == '00'
                                                ? Colors.teal.shade800
                                                : Colors.orange.shade800,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    if (status == 'AWAITING_CONFIRMATION') ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.blue.shade200),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.info_outline,
                                                size: 16, color: Colors.blue.shade700),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Cổng VNPay đã tiếp nhận yêu cầu hoàn tiền. Trong môi trường thử nghiệm hoặc khi cần xử lý nhanh, bạn có thể bấm "Hoàn tất thủ công" để ghi nhận hoàn tiền cho khách ngay.',
                                                style: TextStyle(
                                                    fontSize: 12, color: Colors.blue.shade900),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (status == 'AWAITING_BANK_TRANSFER')
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.icon(
                                            onPressed: () => _confirmBankTransfer(refund),
                                            icon: const Icon(Icons.check_circle_outline, size: 18),
                                            label: const Text('Xác nhận đã chuyển khoản hoàn cọc'),
                                            style: FilledButton.styleFrom(
                                                backgroundColor: Colors.green.shade700),
                                          ),
                                        ),
                                      ),
                                    if (status == 'MISSING_METADATA' || status == 'REJECTED')
                                      TextButton(
                                          onPressed: () => _provideDetails(refund),
                                          child: const Text('Nhập/sửa thông tin giao dịch gốc')),
                                    if (status == 'REJECTED')
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: FilledButton.icon(
                                                onPressed: () => _confirmBankTransfer(refund),
                                                icon: const Icon(Icons.check_circle_outline, size: 16),
                                                label: const Text('Hoàn tất thủ công'),
                                                style: FilledButton.styleFrom(
                                                    backgroundColor: Colors.teal.shade700),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            OutlinedButton(
                                              onPressed: () => _retry(refund),
                                              child: const Text('Gửi lại VNPay'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (status == 'NEEDS_REVIEW' ||
                                        status == 'SENDING' ||
                                        status == 'AWAITING_CONFIRMATION')
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: FilledButton.icon(
                                                onPressed: () => _confirmBankTransfer(refund),
                                                icon: const Icon(Icons.check_circle_outline, size: 16),
                                                label: const Text('Hoàn tất thủ công'),
                                                style: FilledButton.styleFrom(
                                                    backgroundColor: Colors.teal.shade700),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            OutlinedButton.icon(
                                              onPressed:
                                                  _isReconciling ? null : () => _reconcile(refund),
                                              icon: _isReconciling
                                                  ? const SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child: CircularProgressIndicator(
                                                          strokeWidth: 2),
                                                    )
                                                  : const Icon(Icons.sync, size: 16),
                                              label: const Text('Đối soát VNPay'),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      );
}
