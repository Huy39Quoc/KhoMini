import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../services/facility_ops_api_service.dart';
import '../../widgets/state_views.dart';

/// Facility Manager: theo dõi khách đang thuê, hợp đồng, thời hạn thuê,
/// tình trạng thanh toán và các ca quá hạn của cơ sở.
class FacilityContractsTab extends StatefulWidget {
  final String facilityId;

  const FacilityContractsTab({
    super.key,
    required this.facilityId,
  });

  @override
  State<FacilityContractsTab> createState() => _FacilityContractsTabState();
}

class _FacilityContractsTabState extends State<FacilityContractsTab> {
  final FacilityOpsApiService _service = FacilityOpsApiService();
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  late Future<List<Map<String, dynamic>>> _future;
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _future = _service.getFacilityContracts(widget.facilityId);
  }

  void _reload() {
    setState(() {
      _future = _service.getFacilityContracts(widget.facilityId);
    });
  }

  Future<void> _refresh() async {
    _reload();
    try {
      await _future;
    } catch (_) {
      // FutureBuilder hiển thị lỗi.
    }
  }

  Future<void> _approveSealing(Map<String, dynamic> item) async {
    final code = _text(item['bookingCode']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve sealing?'),
        content: Text(
            'Approve sealing of unit ${_text(item['unitCode'])} for booking $code. '
            'The customer is overdue and access has been disabled.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Approve')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.approveSealing(widget.facilityId, _text(item['bookingId']));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sealing approved'),
            backgroundColor: AppColors.success),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error),
      );
    }
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _text(dynamic value) => value?.toString() ?? '';

  bool _matches(Map<String, dynamic> item) {
    switch (_filter) {
      case 'CONFIRMED':
        return _text(item['status']) == 'CONFIRMED';
      case 'ACTIVE':
        return _text(item['status']) == 'ACTIVE';
      case 'OVERDUE':
        return item['overdue'] == true;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(message: 'Loading contracts...');
        }

        if (snapshot.hasError) {
          return AppErrorState(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: _reload,
          );
        }

        final all = snapshot.data ?? <Map<String, dynamic>>[];
        final items = all.where(_matches).toList();

        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  for (final option in const [
                    ['ALL', 'All'],
                    ['CONFIRMED', 'Awaiting check-in'],
                    ['ACTIVE', 'Active'],
                    ['OVERDUE', 'Overdue'],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(option[1]),
                        selected: _filter == option[0],
                        onSelected: (_) {
                          setState(() => _filter = option[0]);
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          AppEmptyState(
                            icon: Icons.description_outlined,
                            title: 'No contracts',
                            message: 'No rental contracts match this filter.',
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: items.length,
                        itemBuilder: (context, index) =>
                            _buildCard(items[index]),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final status = _text(item['status']);
    final overdue = item['overdue'] == true;
    final accessDisabled = item['accessDisabled'] == true;
    final sealingPending = item['sealingPending'] == true;
    final sealingApproved = item['sealingApproved'] == true;
    final pendingExtension = item['pendingExtensionFee'];
    final months = _text(item['rentalMonths']);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _text(item['bookingCode']),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                _chip(
                  status == 'ACTIVE' ? 'ACTIVE' : 'AWAITING CHECK-IN',
                  status == 'ACTIVE' ? AppColors.success : AppColors.warning,
                ),
                if (overdue) ...[
                  const SizedBox(width: 6),
                  _chip('OVERDUE', AppColors.error),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_text(item['customerName'])} • ${_text(item['customerEmail'])}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Unit ${_text(item['unitCode'])} • ${_text(item['unitType'])}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_text(item['startDate'])} → ${_text(item['endDate'])}'
              '${months.isNotEmpty ? ' ($months months)' : ''}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Deposit paid ${_currency.format(_num(item['depositPaid']))}'
              ' • Rental total ${_currency.format(_num(item['totalRentalFee']))}',
              style: const TextStyle(fontSize: 12),
            ),
            if (pendingExtension != null) ...[
              const SizedBox(height: 4),
              Text(
                'Extension awaiting payment: '
                '${_currency.format(_num(pendingExtension))}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.warning,
                ),
              ),
            ],
            if (overdue) ...[
              const SizedBox(height: 8),
              Text(
                'Overdue ${_text(item['overdueDays'])} day(s) • '
                'late fee accrued ${_currency.format(_num(item['overdueFeeAccrued']))}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
              if (accessDisabled || sealingPending) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    if (accessDisabled)
                      _chip('ACCESS DISABLED', AppColors.error),
                    if (sealingPending && !sealingApproved)
                      _chip('SEALING PENDING', AppColors.error),
                    if (sealingApproved)
                      _chip('SEALING APPROVED', AppColors.success),
                  ],
                ),
              ],
              if (sealingPending && !sealingApproved) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _approveSealing(item),
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Approve sealing'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
