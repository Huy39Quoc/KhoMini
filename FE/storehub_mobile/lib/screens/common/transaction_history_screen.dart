import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/payment_model.dart';
import '../../services/payment_api_service.dart';
import '../../widgets/state_views.dart';
import 'transaction_detail_dialog.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final String userRole;
  final String? facilityId;

  const TransactionHistoryScreen({
    super.key,
    required this.userRole,
    this.facilityId,
  });

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final PaymentApiService _paymentService = PaymentApiService();
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy • h:mm a');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  bool _isLoading = true;
  String? _errorMessage;
  List<PaymentModel> _allPayments = [];
  String _selectedStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final role = widget.userRole.toUpperCase().replaceAll('ROLE_', '');
      List<PaymentModel> payments = [];

      if (role == 'CUSTOMER') {
        payments = await _paymentService.getMyPayments();
      } else if (role == 'FACILITY_MANAGER' || role == 'STAFF' || role == 'FACILITY_STAFF') {
        if (widget.facilityId == null || widget.facilityId!.isEmpty) {
          throw StateError('Your account has no assigned facility.');
        }
        payments = await _paymentService.getFacilityPayments(widget.facilityId!);
      } else if (role == 'ADMIN' || role == 'BUSINESS_MANAGER') {
        payments = await _paymentService.getAllPayments();
      } else {
        throw StateError('This account cannot view payment history.');
      }

      if (!mounted) return;
      setState(() {
        _allPayments = payments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString()
            .replaceAll('Exception: ', '')
            .replaceAll('Bad state: ', '');
        _isLoading = false;
      });
    }
  }

  List<PaymentModel> get _filteredPayments {
    final query = _searchController.text.trim().toLowerCase();
    return _allPayments.where((payment) {
      // Status filter
      if (_selectedStatus != 'ALL' &&
          payment.status.toUpperCase() != _selectedStatus) {
        return false;
      }
      // Search query
      if (query.isNotEmpty) {
        final searchText = [
          payment.transactionId,
          payment.bookingCode ?? '',
          payment.customerName ?? '',
          payment.facilityName ?? '',
          payment.unitCode ?? '',
          payment.paymentTypeLabel,
        ].join(' ').toLowerCase();
        return searchText.contains(query);
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPayments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search transaction ID, booking, unit...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _statusFilterChip('ALL', 'All'),
                      const SizedBox(width: 8),
                      _statusFilterChip('PAID', 'Paid'),
                      const SizedBox(width: 8),
                      _statusFilterChip('PENDING', 'Pending'),
                      const SizedBox(width: 8),
                      _statusFilterChip('FAILED', 'Failed'),
                      const SizedBox(width: 8),
                      _statusFilterChip('REFUNDED', 'Refunded'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content List
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _statusFilterChip(String value, String label) {
    final isSelected = _selectedStatus == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: AppColors.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) {
        setState(() {
          _selectedStatus = value;
        });
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingState(message: 'Loading transaction history...');
    }

    if (_errorMessage != null) {
      return AppErrorState(
        message: _errorMessage!,
        onRetry: _loadPayments,
      );
    }

    final payments = _filteredPayments;

    if (payments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPayments,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 60),
            AppEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No Transactions Found',
              message: 'There are no payment transactions matching your filter.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPayments,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: payments.length,
        itemBuilder: (context, index) {
          final payment = payments[index];
          return _buildPaymentCard(payment);
        },
      ),
    );
  }

  Widget _buildPaymentCard(PaymentModel payment) {
    final dateStr = payment.paymentTime != null
        ? _dateFormat.format(payment.paymentTime!)
        : 'N/A';

    IconData iconData;
    Color iconBgColor;

    switch (payment.paymentType.toUpperCase()) {
      case 'DEPOSIT':
        iconData = Icons.account_balance_wallet_outlined;
        iconBgColor = AppColors.primaryContainer;
        break;
      case 'RENTAL_FEE':
        iconData = Icons.inventory_2_outlined;
        iconBgColor = AppColors.secondaryContainer;
        break;
      case 'EXTRA_CHARGE':
        iconData = Icons.more_time_outlined;
        iconBgColor = AppColors.warning;
        break;
      default:
        iconData = Icons.payment_outlined;
        iconBgColor = AppColors.primary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => TransactionDetailDialog.show(context, payment),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: iconBgColor.withValues(alpha: 0.15),
                child: Icon(iconData, color: iconBgColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            payment.paymentTypeLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(payment.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              if (payment.unitCode != null && payment.unitCode!.isNotEmpty)
                                'Unit ${payment.unitCode}',
                              if (payment.bookingCode != null && payment.bookingCode!.isNotEmpty)
                                payment.bookingCode,
                              if (payment.customerName != null && payment.customerName!.isNotEmpty)
                                payment.customerName,
                            ].join(' • '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: payment.statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            payment.statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: payment.statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
