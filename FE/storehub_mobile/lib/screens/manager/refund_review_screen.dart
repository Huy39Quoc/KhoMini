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
  String _statusLabel(String status) => ViLabels.refund(status);

  final _api = FacilityOpsApiService();
  late Future<Map<String, dynamic>> _requests;
  int _page = 0;
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

  Future<void> _reconcile(Map<String, dynamic> refund) async {
    try {
      await _api.reconcileRefund(widget.facilityId, '${refund['id']}');
      if (mounted) _reload(resetPage: true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    }
  }

  Future<void> _confirmBankTransfer(Map<String, dynamic> refund) async {
    final refController = TextEditingController();
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
                const Text('Vui lòng nhập mã giao dịch ngân hàng sau khi bạn đã chuyển khoản thành công:'),
                const SizedBox(height: 8),
                TextField(
                  controller: refController,
                  decoration: const InputDecoration(
                    labelText: 'Mã tham chiếu / Mã GD chuyển khoản *',
                    hintText: 'VD: FT2601019827361 hoặc GD-12345',
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

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Yêu cầu hoàn tiền'),
            actions: [IconButton(onPressed: () => _reload(resetPage: true),
                icon: const Icon(Icons.refresh))]),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final result = snapshot.data!;
            final requests = (result['content'] as List? ?? const [])
                .map((item) => Map<String, dynamic>.from(item as Map)).toList();
            final totalPages = (result['totalPages'] as num?)?.toInt() ?? 0;
            final total = (result['totalElements'] as num?)?.toInt() ?? 0;
            if (requests.isEmpty && total == 0) {
              return const Center(child: Text('Chưa có yêu cầu hoàn tiền.'));
            }
            if (requests.isEmpty && _page > 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _reload(resetPage: true);
              });
              return const Center(child: CircularProgressIndicator());
            }
            return ListView.builder(
              itemCount: requests.length + 1,
              itemBuilder: (context, index) {
                if (index == requests.length) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      IconButton(
                        tooltip: 'Trang trước',
                        onPressed: _page > 0 ? () {
                          setState(() {
                            _page--;
                            _requests = _api.getFacilityRefunds(widget.facilityId, page: _page);
                          });
                        } : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(child: Text('Trang ${_page + 1} / $totalPages • $total yêu cầu',
                          textAlign: TextAlign.center)),
                      IconButton(
                        tooltip: 'Trang sau',
                        onPressed: _page + 1 < totalPages ? () {
                          setState(() {
                            _page++;
                            _requests = _api.getFacilityRefunds(widget.facilityId, page: _page);
                          });
                        } : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ]),
                  );
                }
                final refund = requests[index];
                final status = '${refund['status']}';
                final damageDeduction = num.tryParse('${refund['damageDeduction']}') ?? 0;
                return Card(
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${refund['bookingCode']} • '
                          '${_money.format(num.tryParse('${refund['amount']}') ?? 0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (refund['originalTransactionId'] != null)
                        Text('Giao dịch gốc: ${refund['originalTransactionId']}'),
                      Text('Trạng thái: ${_statusLabel(status)}'),
                      if (damageDeduction > 0)
                        Text(
                          'Khấu trừ hư hại: -${_money.format(damageDeduction)}',
                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
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
                                  const Icon(Icons.account_balance, size: 16, color: Colors.blue),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${refund['bankCode'] ?? 'Ngân hàng'}: ${refund['bankAccountNumber']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              if (refund['bankAccountName'] != null)
                                Text('Chủ TK: ${refund['bankAccountName']}', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                      if (refund['transferReference'] != null &&
                          '${refund['transferReference']}'.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Mã GD chuyển tiền: ${refund['transferReference']}',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.teal),
                          ),
                        ),
                      if (refund['dueAt'] != null) ...[
                        Text('Hạn hoàn tiền: ${refund['dueAt'].toString().replaceFirst('T', ' ')}',
                            style: TextStyle(
                              color: refund['overdue'] == true ? Colors.red : null,
                              fontWeight: refund['overdue'] == true
                                  ? FontWeight.bold : FontWeight.normal,
                            )),
                        if (refund['overdue'] == true)
                          const Text('Đã quá hạn cam kết: cần xử lý/đối soát ngay.',
                              style: TextStyle(color: Colors.red)),
                      ],
                      if (refund['gatewayResponseCode'] != null)
                        Text('Phản hồi VNPay: ${refund['gatewayResponseCode']}'),
                      if (status == 'AWAITING_BANK_TRANSFER')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: FilledButton.icon(
                            onPressed: () => _confirmBankTransfer(refund),
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('Xác nhận đã chuyển khoản hoàn cọc'),
                          ),
                        ),
                      if (status == 'MISSING_METADATA' || status == 'REJECTED')
                        TextButton(onPressed: () => _provideDetails(refund),
                            child: const Text('Nhập/sửa thông tin giao dịch gốc')),
                      if (status == 'REJECTED')
                        TextButton(onPressed: () => _retry(refund),
                            child: const Text('Gửi lại yêu cầu bị từ chối')),
                      if (status == 'NEEDS_REVIEW')
                        const Text('Kiểm tra yêu cầu này trên cổng merchant của VNPay '
                            'trước khi thực hiện bước tiếp theo.'),
                      if (status == 'NEEDS_REVIEW' || status == 'SENDING'
                          || status == 'AWAITING_CONFIRMATION')
                        TextButton(onPressed: () => _reconcile(refund),
                            child: const Text('Kiểm tra với VNPay')),
                    ]),
                  ),
                );
              },
            );
          },
        ),
      );
}
