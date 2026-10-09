import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/facility_ops_api_service.dart';

class RefundReviewScreen extends StatefulWidget {
  final String facilityId;
  const RefundReviewScreen({super.key, required this.facilityId});

  @override
  State<RefundReviewScreen> createState() => _RefundReviewScreenState();
}

class _RefundReviewScreenState extends State<RefundReviewScreen> {
  final _api = FacilityOpsApiService();
  late Future<List<Map<String, dynamic>>> _requests;
  final _money = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
        _requests = _api.getFacilityRefunds(widget.facilityId);
      });

  Future<void> _provideDetails(Map<String, dynamic> refund) async {
    final date = TextEditingController();
    final transactionNo = TextEditingController();
    final amount = TextEditingController();
    try {
      final submitted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Original VNPay payment'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Copy these values from the original payment in VNPay. '
                  'Do not enter the refund request date.'),
              TextField(controller: date,
                  decoration: const InputDecoration(labelText: 'Payment create date (yyyyMMddHHmmss)')),
              TextField(controller: transactionNo,
                  decoration: const InputDecoration(labelText: 'VNPay transaction number (optional)')),
              TextField(controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Original payment amount (VND)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true),
                child: const Text('Submit')),
          ],
        ),
      );
      if (submitted != true) return;
      final value = num.tryParse(amount.text.trim());
      if (!RegExp(r'^\d{14}$').hasMatch(date.text.trim()) || value == null
          || value < (num.tryParse('${refund['amount']}') ?? 0)) {
        throw const FormatException('Check original payment date and amount.');
      }
      await _api.provideRefundDetails(widget.facilityId, '${refund['id']}',
          date.text.trim(), transactionNo.text.trim(), value);
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      date.dispose();
      transactionNo.dispose();
      amount.dispose();
    }
  }

  Future<void> _retry(Map<String, dynamic> refund) async {
    try {
      await _api.retryRejectedRefund(widget.facilityId, '${refund['id']}');
      if (mounted) _reload();
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
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Refund requests'),
            actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))]),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final requests = snapshot.data!;
            if (requests.isEmpty) return const Center(child: Text('No refunds yet.'));
            return ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final refund = requests[index];
                final status = '${refund['status']}';
                return Card(
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${refund['bookingCode']} • '
                          '${_money.format(num.tryParse('${refund['amount']}') ?? 0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Original transaction: ${refund['originalTransactionId']}'),
                      Text('Status: ${status.replaceAll('_', ' ')}'),
                      if (refund['gatewayResponseCode'] != null)
                        Text('VNPay response: ${refund['gatewayResponseCode']}'),
                      if (status == 'MISSING_METADATA' || status == 'REJECTED')
                        TextButton(onPressed: () => _provideDetails(refund),
                            child: const Text('Enter/correct original payment details')),
                      if (status == 'REJECTED')
                        TextButton(onPressed: () => _retry(refund),
                            child: const Text('Retry rejected request')),
                      if (status == 'NEEDS_REVIEW')
                        const Text('Check this request in the VNPay merchant portal '
                            'before taking further action.'),
                      if (status == 'NEEDS_REVIEW' || status == 'SENDING'
                          || status == 'AWAITING_CONFIRMATION')
                        TextButton(onPressed: () => _reconcile(refund),
                            child: const Text('Check with VNPay')),
                    ]),
                  ),
                );
              },
            );
          },
        ),
      );
}
