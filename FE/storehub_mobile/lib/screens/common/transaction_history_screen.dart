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
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final PaymentApiService _paymentService = PaymentApiService();
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy • HH:mm');
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _nextPage = 0;
  String? _loadMoreError;
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

  Future<void> _loadPayments({bool more = false}) async {
    if (more && (_isLoadingMore || !_hasMore)) return;
    setState(() {
      if (more) {
        _isLoadingMore = true;
        _loadMoreError = null;
      } else {
        _isLoading = true;
        _errorMessage = null;
        _nextPage = 0;
      }
    });

    try {
      final role = widget.userRole.toUpperCase().replaceAll('ROLE_', '');
      PaymentPage payments;

      if (role == 'CUSTOMER') {
        payments = await _paymentService.getMyPayments(page: _nextPage);
      } else if (role == 'FACILITY_MANAGER' ||
          role == 'STAFF' ||
          role == 'FACILITY_STAFF') {
        if (widget.facilityId == null || widget.facilityId!.isEmpty) {
          throw StateError('Tài khoản của bạn chưa được gán cơ sở.');
        }
        payments = await _paymentService.getFacilityPayments(widget.facilityId!,
            page: _nextPage);
      } else if (role == 'ADMIN' || role == 'BUSINESS_MANAGER') {
        payments = await _paymentService.getAllPayments(page: _nextPage);
      } else {
        throw StateError('Tài khoản này không có quyền xem lịch sử giao dịch.');
      }

      if (!mounted) return;
      setState(() {
        _allPayments =
            more ? [..._allPayments, ...payments.items] : payments.items;
        _hasMore = payments.hasMore;
        _nextPage++;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final message = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('Bad state: ', '');
        if (more) {
          _loadMoreError = message;
        } else {
          _errorMessage = message;
        }
        _isLoading = false;
        _isLoadingMore = false;
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
        title: const Text('Lịch sử giao dịch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPayments,
            tooltip: 'Làm mới',
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
                    hintText: 'Tìm trong các giao dịch đã tải...',
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
                      _statusFilterChip('ALL', 'Tất cả'),
                      const SizedBox(width: 8),
                      _statusFilterChip('PAID', 'Đã thanh toán'),
                      const SizedBox(width: 8),
                      _statusFilterChip('PENDING', 'Chờ thanh toán'),
                      const SizedBox(width: 8),
                      _statusFilterChip('REFUND_PENDING', 'Đang hoàn tiền'),
                      const SizedBox(width: 8),
                      _statusFilterChip('FAILED', 'Thất bại'),
                      const SizedBox(width: 8),
                      _statusFilterChip('REFUNDED', 'Đã hoàn tiền'),
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
      selectedColor: AppColors.secondaryFixed,
      checkmarkColor: AppColors.onSecondaryFixed,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.onSecondaryFixed : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.secondaryContainer : AppColors.outlineVariant,
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) {
        setState(() {
          _selectedStatus = value;
        });
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingState(message: 'Đang tải lịch sử giao dịch...');
    }

    if (_errorMessage != null) {
      return AppErrorState(
        message: _errorMessage!,
        onRetry: _loadPayments,
      );
    }

    final payments = _filteredPayments;

    if (payments.isEmpty && !_hasMore) {
      return RefreshIndicator(
        onRefresh: _loadPayments,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 60),
            AppEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Không có giao dịch',
              message:
                  'Không có giao dịch nào phù hợp bộ lọc.',
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
        itemCount:
            payments.length + (_hasMore || _loadMoreError != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == payments.length) {
            if (_isLoadingMore) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator()));
            }
            return Center(
                child: TextButton(
              onPressed: () => _loadPayments(more: true),
              child: Text(
                  _loadMoreError == null ? 'Tải thêm' : 'Thử tải lại'),
            ));
          }
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => TransactionDetailDialog.show(context, payment),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: iconBgColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            payment.paymentTypeLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(payment.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: AppColors.textPrimary,
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
                              if (payment.unitCode != null &&
                                  payment.unitCode!.isNotEmpty)
                                'Ngăn ${payment.unitCode}',
                              if (payment.bookingCode != null &&
                                  payment.bookingCode!.isNotEmpty)
                                payment.bookingCode,
                              if (payment.customerName != null &&
                                  payment.customerName!.isNotEmpty)
                                payment.customerName,
                            ].join(' • '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: payment.statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: payment.statusColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            payment.statusLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: payment.statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.outline,
                        fontWeight: FontWeight.w500,
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
