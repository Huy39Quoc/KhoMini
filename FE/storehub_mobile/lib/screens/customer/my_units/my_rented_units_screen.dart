import 'package:flutter/material.dart';
import '../../../core/utils/vi_labels.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/booking_api_service.dart';
import '../../../services/auth_api_service.dart';
import '../../../widgets/logout_dialog.dart';
import '../../../services/storage_api_service.dart';
import '../../../models/my_unit_model.dart';
import '../../../widgets/state_views.dart';
import '../tickets/create_ticket_screen.dart';
import 'contract_operation_dialog.dart';
import 'smart_key_screen.dart';
import '../../../models/facility_operations_models.dart';
import '../../../widgets/photo_preview_dialog.dart';

class MyRentedUnitsScreen extends StatefulWidget {
  const MyRentedUnitsScreen({super.key});

  @override
  State<MyRentedUnitsScreen> createState() => _MyRentedUnitsScreenState();
}

class _MyRentedUnitsScreenState extends State<MyRentedUnitsScreen> {
  final StorageApiService _storageService = StorageApiService();
  final BookingApiService _bookingService = BookingApiService();
  late Future<({List<MyUnitModel> active, List<MyUnitModel> awaiting})> _unitsFuture;
  bool _showAwaiting = false;
  final _currency = NumberFormat.currency(
      locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _dateTimeFmt = DateFormat('dd/MM/yyyy • HH:mm');

  // Chỉ gia hạn khi đã nhận kho; nếu đang treo yêu cầu gia hạn thì vẫn cho mở lại
  // để thanh toán/hủy; nợ phí trễ hạn thì phải trả trước.
  bool _canExtend(MyUnitModel unit) =>
      unit.isActive &&
      (unit.hasPendingExtension ||
          (!unit.hasLateFeeDue && !unit.renewalNotYetOpen));

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  void _loadUnits() {
    setState(() {
      _unitsFuture = _fetchUnits();
    });
  }

  Future<({List<MyUnitModel> active, List<MyUnitModel> awaiting})> _fetchUnits() async {
    final results = await Future.wait([
      _storageService.getMyRentedUnits(),
      _storageService.getAwaitingHandover(),
    ]);
    List<MyUnitModel> parse(List<dynamic> items) => items
        .map((item) => MyUnitModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return (active: parse(results[0]), awaiting: parse(results[1]));
  }

  void _showUnitActions(MyUnitModel unit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.inventory_2_outlined,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            unit.displayUnit,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (unit.facilityName.isNotEmpty)
                            Text(
                              unit.facilityName,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.key, color: AppColors.primary),
                ),
                title: const Text('Khóa thông minh ngăn kho',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                enabled: unit.hasActiveAccess,
                subtitle: Text(
                  !unit.hasActiveAccess
                      ? (unit.accessDisabled
                          ? 'Đã khóa truy cập vì quá hạn thuê'
                          : 'Dùng được sau khi nhân viên bàn giao tại cơ sở')
                      : 'Mở / đóng khóa ngăn kho bằng mã PIN 6 số',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: unit.hasActiveAccess
                    ? () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SmartKeyScreen(
                              bookingId: unit.bookingId,
                              unitNumber: unit.unitCode,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
              if (unit.hasLateFeeDue)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.payments_outlined,
                        color: AppColors.error),
                  ),
                  title: const Text('Thanh toán phí trễ hạn',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                      'còn nợ ${_currency.format(unit.overdueFeeOutstanding)}',
                      style: const TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openContractOperation(unit,
                        isExtension: false, payOverdue: true);
                  },
                ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.update,
                      color: AppColors.primary),
                ),
                title: const Text('Gia hạn thuê',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                enabled: _canExtend(unit),
                subtitle: !unit.isActive
                    ? const Text('Dùng được sau khi nhân viên bàn giao tại cơ sở',
                        style: TextStyle(fontSize: 12))
                    : unit.hasPendingExtension
                        ? const Text('Tiếp tục hoặc hủy yêu cầu gia hạn đang chờ',
                            style: TextStyle(fontSize: 12))
                        : unit.hasLateFeeDue
                            ? const Text('Vui lòng thanh toán phí trễ hạn trước',
                                style: TextStyle(fontSize: 12))
                            : unit.renewalNotYetOpen
                                ? Text(
                                    'Chưa đến thời điểm gia hạn. Gia hạn mở từ '
                                    '${_dateFmt.format(unit.renewalOpensDate!)} '
                                    '(trong ${unit.endDate!.difference(unit.renewalOpensDate!).inDays} '
                                    'ngày cuối trước ngày hết hạn ${_dateFmt.format(unit.endDate!)}).',
                                    style: const TextStyle(fontSize: 12))
                                : null,
                onTap: _canExtend(unit)
                    ? () {
                        Navigator.pop(ctx);
                        _openContractOperation(
                          unit,
                          isExtension: true,
                          resumePending: unit.hasPendingExtension,
                        );
                      }
                    : null,
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout, color: AppColors.error),
                ),
                title: Text(unit.scheduledReturnTime != null
                    ? 'Đổi lịch trả kho'
                    : 'Yêu cầu trả kho',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                enabled: unit.isActive,
                subtitle: unit.isActive
                    ? (unit.scheduledReturnTime != null
                        ? Text(
                            'Hiện tại: ${_dateTimeFmt.format(unit.scheduledReturnTime!)}',
                            style: const TextStyle(fontSize: 12))
                        : null)
                    : const Text('Dùng được sau khi nhân viên bàn giao tại cơ sở',
                        style: TextStyle(fontSize: 12)),
                onTap: unit.isActive
                    ? () {
                        Navigator.pop(ctx);
                        _openContractOperation(unit, isExtension: false);
                      }
                    : null,
              ),
              if (unit.status == 'CONFIRMED')
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cancel_outlined,
                        color: AppColors.error),
                  ),
                  title: const Text('Hủy đơn',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text(
                      'Tiền cọc được hoàn theo chính sách hủy của cơ sở',
                      style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmCancelBooking(unit);
                  },
                ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history_edu_outlined,
                      color: AppColors.primary),
                ),
                title: const Text('Biên bản bàn giao & ảnh',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Xem tình trạng & ảnh lúc bàn giao/trả kho',
                    style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openCustomerHandoverHistory(unit);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.report_problem_outlined,
                      color: AppColors.secondary),
                ),
                title: const Text('Báo sự cố',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateTicketScreen(
                        preselectedBookingId: unit.bookingId,
                        preselectedUnitLabel:
                            '${unit.displayUnit} • ${unit.facilityName}',
                      ),
                    ),
                  );
                  if (result == true) _loadUnits();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCustomerHandoverHistory(MyUnitModel unit) async {
    final historyFuture =
        _storageService.getCustomerHandoverRecords(unit.bookingId);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.history_edu,
                        color: AppColors.primaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Biên bản bàn giao • Ngăn ${unit.unitCode}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<List<HandoverRecordModel>>(
                  future: historyFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const AppLoadingState(
                        message: 'Đang tải biên bản bàn giao...',
                      );
                    }
                    if (snapshot.hasError) {
                      return AppErrorState(
                        message: snapshot.error
                            .toString()
                            .replaceAll('Exception: ', ''),
                      );
                    }

                    final records = snapshot.data ?? <HandoverRecordModel>[];
                    if (records.isEmpty) {
                      return const AppEmptyState(
                        icon: Icons.history,
                        title: 'Chưa có biên bản bàn giao',
                        message:
                            'Biên bản bàn giao kèm ảnh sẽ hiển thị tại đây sau khi nhân viên bàn giao kho.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final record = records[index];
                        final isCheckIn =
                            record.recordType.toUpperCase() == 'CHECK_IN';
                        final recordedTime = record.recordedAt == null
                            ? ''
                            : _dateTimeFmt.format(record.recordedAt!);

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: isCheckIn
                                          ? AppColors.success
                                              .withValues(alpha: 0.15)
                                          : AppColors.secondaryContainer
                                              .withValues(alpha: 0.15),
                                      child: Icon(
                                        isCheckIn ? Icons.login : Icons.logout,
                                        color: isCheckIn
                                            ? AppColors.success
                                            : AppColors.secondaryContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isCheckIn
                                                ? 'Biên bản bàn giao kho'
                                                : 'Biên bản nghiệm thu trả kho',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          if (recordedTime.isNotEmpty)
                                            Text(
                                              recordedTime,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors
                                                      .onSurfaceVariant),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (record.unitCondition.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      'Tình trạng: ${record.unitCondition}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                if (record.damageFee != null &&
                                    record.damageFee! > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      'Khấu trừ: ${_currency.format(record.damageFee)}${record.damageReason != null ? " (${record.damageReason})" : ""}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.error,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                if (record.notes.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      'Ghi chú: ${record.notes}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                if (record.staffName.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      'Người kiểm tra: ${record.staffName}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.onSurfaceVariant),
                                    ),
                                  ),
                                if (record.photos.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Ảnh bằng chứng:',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  PhotoThumbnailGrid(
                                      photos: record.photos, size: 70),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmCancelBooking(MyUnitModel unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hủy đơn đặt kho?'),
        content: Text(
          'Đơn ${unit.bookingCode} (${unit.displayUnit}) sẽ được '
          'bị hủy và ngăn kho được trả lại. Tiền cọc của bạn được hoàn '
          'theo chính sách hủy của cơ sở.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ đơn'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _bookingService.cancelBooking(unit.bookingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã hủy đơn'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadUnits();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openContractOperation(
    MyUnitModel unit, {
    required bool isExtension,
    bool resumePending = false,
    bool payOverdue = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ContractOperationDialog(
        unit: unit,
        isExtension: isExtension,
        resumePending: resumePending,
        payOverdue: payOverdue,
      ),
    );
    if (result == true) {
      _loadUnits();
    }
  }

  void _logout(BuildContext context) async {
    if (!await confirmLogout(context)) return;
    await AuthApiService().logout();

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  Color _statusColor(String status) {
    if (status == 'OVERDUE') return AppColors.error;
    switch (status) {
      case 'ACTIVE':
        return AppColors.success;
      case 'CONFIRMED':
        return AppColors.secondaryContainer;
      case 'PENDING_PAYMENT':
        return AppColors.warning;
      case 'COMPLETED':
        return AppColors.outline;
      case 'CANCELLED':
        return AppColors.error;
      default:
        return AppColors.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Kho của tôi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUnits,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadUnits(),
        child: FutureBuilder<({List<MyUnitModel> active, List<MyUnitModel> awaiting})>(
          future: _unitsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingState(message: 'Đang tải kho của bạn...');
            } else if (snapshot.hasError) {
              return ListView(
                children: [
                  AppErrorState(
                    message:
                        snapshot.error.toString().replaceAll('Exception: ', ''),
                    onRetry: _loadUnits,
                  ),
                ],
              );
            }

            final active = snapshot.data?.active ?? <MyUnitModel>[];
            final awaiting = snapshot.data?.awaiting ?? <MyUnitModel>[];
            final units = _showAwaiting ? awaiting : active;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.warehouse_outlined,
                            color: AppColors.secondary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${active.length} đang thuê',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                const Text(' • ',
                                    style: TextStyle(color: Colors.white38)),
                                Text(
                                  '${awaiting.length} chờ nhận kho',
                                  style: const TextStyle(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _showAwaiting
                                  ? 'Bạn đã thanh toán. Hãy đến đúng giờ hẹn để nhân viên bàn giao ngăn kho.'
                                  : 'Chạm vào ngăn kho để mở khóa thông minh, xem mã ra vào hoặc quản lý hợp đồng.',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11.5, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _showAwaiting = false),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: !_showAwaiting
                                  ? AppColors.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 15,
                                    color: !_showAwaiting
                                        ? Colors.white
                                        : AppColors.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Text(
                                  'Đang thuê (${active.length})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: !_showAwaiting
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: !_showAwaiting
                                        ? Colors.white
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _showAwaiting = true),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _showAwaiting
                                  ? AppColors.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.schedule,
                                    size: 15,
                                    color: _showAwaiting
                                        ? Colors.white
                                        : AppColors.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Text(
                                  'Chờ nhận (${awaiting.length})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _showAwaiting
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: _showAwaiting
                                        ? Colors.white
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (units.isEmpty)
                  AppEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: _showAwaiting ? 'Chưa có lịch nhận kho' : 'Chưa có kho đang thuê',
                    message: _showAwaiting
                        ? 'Booking đã thanh toán sẽ hiện ở đây cho đến khi nhân viên bàn giao.'
                        : 'Ngăn kho sẽ hiện ở đây sau khi nhân viên hoàn tất bàn giao.',
                  ),
                ...units.map((unit) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildUnitCard(unit),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildUnitCard(MyUnitModel unit) {
    final monthlyRate = unit.monthlyRate;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showUnitActions(unit),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(unit.displayUnit,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          unit.dimensions.isNotEmpty
                              ? '${unit.typeName} • ${unit.dimensions}'
                              : unit.typeName,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          _statusColor(unit.overdue ? 'OVERDUE' : unit.status)
                              .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      unit.overdue
                          ? 'Quá hạn'
                          : ViLabels.booking(unit.status),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _statusColor(
                            unit.overdue ? 'OVERDUE' : unit.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      unit.facilityName.isNotEmpty
                          ? '${unit.facilityName}${unit.facilityAddress.isNotEmpty ? ', ${unit.facilityAddress}' : ''}'
                          : 'Chưa xác định cơ sở',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (unit.overdue || unit.accessDisabled) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: AppColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [
                            'Hợp đồng đã quá hạn${unit.overdueDays > 0 ? ' ${unit.overdueDays} ngày' : ''}.',
                            if (unit.hasLateFeeDue)
                              'Phí trễ hạn cần thanh toán: ${_currency.format(unit.overdueFeeOutstanding)}.',
                            if (unit.accessDisabled)
                              'Khóa thông minh đã bị vô hiệu hóa.',
                            'Hãy thanh toán phí, sau đó gia hạn hoặc trả kho.',
                          ].join(' '),
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (unit.isActive && unit.scheduledReturnTime != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available,
                          size: 16, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Hẹn trả kho lúc ${_dateTimeFmt.format(unit.scheduledReturnTime!)}',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (unit.hasPendingExtension) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_top,
                          size: 16, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          unit.pendingExtensionFee != null
                              ? 'Yêu cầu gia hạn ${unit.pendingExtraMonths ?? '?'} tháng đang chờ thanh toán '
                                  '(${_currency.format(unit.pendingExtensionFee)}). Chạm "Gia hạn thuê" để thanh toán hoặc hủy yêu cầu.'
                              : 'Bạn có yêu cầu gia hạn đang chờ thanh toán.',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outline.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    if (monthlyRate != null) ...[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Giá thuê / tháng',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.onSurfaceVariant)),
                            const SizedBox(height: 2),
                            Text(_currency.format(monthlyRate),
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Container(
                        height: 28,
                        width: 1,
                        color: AppColors.outline.withValues(alpha: 0.2),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ngày hết hạn',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.onSurfaceVariant)),
                          const SizedBox(height: 2),
                          Text(
                            unit.endDate != null
                                ? _dateFmt.format(unit.endDate!)
                                : '-',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: unit.hasActiveAccess
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SmartKeyScreen(
                                    bookingId: unit.bookingId,
                                    unitNumber: unit.unitCode,
                                  ),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.key, size: 16),
                      label: const Text('Mở khóa',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: () => _showUnitActions(unit),
                      icon: const Icon(Icons.more_horiz, size: 16),
                      label:
                          const Text('Quản lý', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
