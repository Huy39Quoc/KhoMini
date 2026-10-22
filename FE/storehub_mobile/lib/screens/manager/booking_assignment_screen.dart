import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/facility_management_models.dart';
import '../../services/facility_ops_api_service.dart';
import '../../widgets/state_views.dart';

class BookingAssignmentScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const BookingAssignmentScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<BookingAssignmentScreen> createState() =>
      _BookingAssignmentScreenState();
}

class _BookingAssignmentScreenState extends State<BookingAssignmentScreen> {
  final FacilityOpsApiService _opsService = FacilityOpsApiService();

  Future<List<FacilityBookingModel>>? _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  void _loadBookings() {
    setState(() {
      _bookingsFuture = _opsService.getConfirmedBookings(
        widget.facilityId,
      );
    });
  }

  Future<void> _refreshBookings() async {
    _loadBookings();

    try {
      await _bookingsFuture;
    } catch (_) {
    }
  }

  /// Cho quản lý đọc lý do nhân viên từ chối bàn giao ngăn này.
  Future<void> _showRejectionReason(FacilityBookingModel booking) async {
    try {
      final records = await _opsService.getHandoverHistory(
        bookingId: booking.id,
        facilityId: widget.facilityId,
      );
      final rejected = records
          .where((r) => r.recordType.toUpperCase() == 'CHECK_IN_REJECTED')
          .toList()
        ..sort((a, b) => (b.recordedAt ?? DateTime(1970))
            .compareTo(a.recordedAt ?? DateTime(1970)));
      if (!mounted) return;
      final record = rejected.isEmpty ? null : rejected.first;
      String two(int v) => v.toString().padLeft(2, '0');
      final time = record?.recordedAt?.toLocal();
      final lines = <String>[
        if (record == null) 'Chưa có biên bản từ chối bàn giao cho đơn này.',
        if (record != null && record.unitCondition.isNotEmpty)
          'Tình trạng: ${record.unitCondition}',
        if (record != null && record.notes.isNotEmpty)
          'Mô tả: ${record.notes}',
        if (record != null && record.staffName.isNotEmpty)
          'Nhân viên: ${record.staffName}',
        if (time != null)
          'Lúc: ${two(time.hour)}:${two(time.minute)} ${two(time.day)}/${two(time.month)}/${time.year}',
      ];
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Ngăn ${booking.unitCode}: lý do không bàn giao'),
          content: Text(lines.join('\n')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(_errorMessage(error));
    }
  }

  Future<void> _openUnitSelector(
    FacilityBookingModel booking,
  ) async {
    List<FacilityUnitModel> units;

    try {
      units = await _opsService.getFacilityUnits(
        widget.facilityId,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(_errorMessage(error));
      return;
    }

    final availableUnits = units.where((unit) {
      return unit.unitTypeId == booking.unitTypeId &&
          (unit.isAvailable ||
              (!booking.unitAssignmentConfirmed &&
                  !booking.unitNeedsInspection &&
                  unit.id == booking.storageUnitId));
    }).toList();

    if (availableUnits.isEmpty) {
      if (!mounted) {
        return;
      }

      _showError(
        'Không còn ngăn ${booking.unitType} nào trống.',
      );
      return;
    }

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  booking.unitAssignmentConfirmed
                      ? 'Đổi ngăn kho đã chọn' : 'Chọn ngăn kho cụ thể',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${booking.bookingCode} • ${booking.unitType}',
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: availableUnits.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final unit = availableUnits[index];

                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.inventory_2_outlined),
                        ),
                        title: Text('Ngăn ${unit.unitCode}'),
                        subtitle: Text(
                          unit.floorLevel.isEmpty
                              ? unit.unitType
                              : '${unit.unitType} • ${unit.floorLevel}',
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                        ),
                        onTap: () async {
                          try {
                            await _opsService.assignUnitToBooking(
                              widget.facilityId,
                              booking.id,
                              unit.id,
                            );

                            if (!sheetContext.mounted) {
                              return;
                            }

                            Navigator.pop(sheetContext);

                            if (!mounted) {
                              return;
                            }

                            _showSuccess('Đã chọn ngăn ${unit.unitCode} cho đơn.');
                            _loadBookings();
                          } catch (error) {
                            if (!sheetContext.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _errorMessage(error),
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _errorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Xác nhận ngăn kho'),
      ),
      body: FutureBuilder<List<FacilityBookingModel>>(
        future: _bookingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(
              message: 'Đang tải danh sách booking...',
            );
          }

          if (snapshot.hasError) {
            return AppErrorState(
              message: _errorMessage(snapshot.error!),
              onRetry: _loadBookings,
            );
          }

          final bookings = snapshot.data ?? <FacilityBookingModel>[];

          if (bookings.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshBookings,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  AppEmptyState(
                    icon: Icons.assignment_turned_in_outlined,
                    title: 'Chưa có booking cần xác nhận',
                    message: 'Booking đã thanh toán sẽ hiện ở đây để bạn xác nhận ngăn kho.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshBookings,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final booking = bookings[index];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                booking.bookingCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Text(
                              'ĐÃ THANH TOÁN',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(booking.customerName),
                        Text(
                          booking.customerEmail,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (booking.unitNeedsInspection)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Text(
                              'Nhân viên không bàn giao được ngăn ${booking.unitCode} '
                              'vì ngăn/khóa chưa đạt, ngăn đã chuyển sang "Cần kiểm tra / bảo trì". '
                              'Hãy đổi sang ngăn ${booking.unitType} khác đang trống.',
                              style: const TextStyle(fontSize: 12),
                            ),
                          )
                        else
                          Text(
                            booking.unitAssignmentConfirmed
                                ? 'Đã xác nhận ngăn ${booking.unitCode} (${booking.unitType}). Chờ nhân viên bàn giao từ ngày bắt đầu thuê.'
                                : 'Đã giữ chỗ loại ${booking.unitType}. '
                                    'Ngăn đề xuất ${booking.unitCode}: hãy xác nhận hoặc đổi sang ngăn khác.',
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${booking.startDate} → ${booking.endDate}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          children: [
                            if (booking.unitNeedsInspection)
                              TextButton(
                                onPressed: () => _showRejectionReason(booking),
                                child: const Text('Xem lý do'),
                              ),
                            OutlinedButton.icon(
                            onPressed: () {
                              _openUnitSelector(booking);
                            },
                            icon:  Icon(
                              (booking.unitAssignmentConfirmed || booking.unitNeedsInspection)
                                  ? Icons.swap_horiz : Icons.assignment_turned_in_outlined,
                            ),
                            label: Text((booking.unitAssignmentConfirmed || booking.unitNeedsInspection)
                                ? 'Đổi ngăn' : 'Xác nhận ngăn'),
                          ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
