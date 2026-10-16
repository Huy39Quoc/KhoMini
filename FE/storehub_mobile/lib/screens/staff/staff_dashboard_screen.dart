import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'staff_ticket_screen.dart';
import 'staff_units_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/safe_dispose.dart';
import '../../models/facility_operations_models.dart';
import '../../models/user_model.dart';
import '../../services/facility_ops_api_service.dart';
import '../../widgets/state_views.dart';
import '../../widgets/photo_preview_dialog.dart';
import '../common/profile_screen.dart';
import '../common/transaction_history_screen.dart';
import '../common/gate_pass_verify_screen.dart';

class StaffDashboardScreen extends StatefulWidget {
  final UserModel user;

  const StaffDashboardScreen({
    super.key,
    required this.user,
  });

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  final FacilityOpsApiService _opsService = FacilityOpsApiService();

  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  final DateFormat _timeFormat = DateFormat('h:mm a');

  bool _isLoadingFacility = true;

  String? _facilityId;
  String? _facilityName;
  String? _facilityError;

  DateTime _selectedDate = DateTime.now();

  Future<List<DailyScheduleModel>>? _scheduleFuture;

  @override
  void initState() {
    super.initState();
    _loadFacility();
  }

  Future<void> _loadFacility() async {
    setState(() {
      _isLoadingFacility = true;
      _facilityError = null;
    });

    try {
      final facility = await _opsService.getAssignedFacility();

      if (!mounted) {
        return;
      }

      setState(() {
        _facilityId = facility.id;
        _facilityName = facility.name;
        _isLoadingFacility = false;
      });

      if (facility.id.isNotEmpty) {
        _loadSchedule();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _facilityError = _errorMessage(error);
        _isLoadingFacility = false;
      });
    }
  }

  void _loadSchedule() {
    final facilityId = _facilityId;

    if (facilityId == null || facilityId.isEmpty) {
      return;
    }

    setState(() {
      _scheduleFuture = _opsService.getDailySchedule(
        facilityId: facilityId,
        date: _selectedDate,
      );
    });
  }

  Future<void> _refreshSchedule() async {
    _loadSchedule();

    try {
      await _scheduleFuture;
    } catch (_) {
    }
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(
        const Duration(days: 90),
      ),
      lastDate: DateTime.now().add(
        const Duration(days: 90),
      ),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = pickedDate;
    });

    _loadSchedule();
  }

  Future<void> _openHandoverSheet(
    DailyScheduleModel item,
  ) async {
    final bool isCheckIn = item.isCheckIn;

    String unitCondition = 'Good / clean';
    String lockCondition = 'Locked & working';

    final notesController = TextEditingController();
    final damageFeeController = TextEditingController();
    final damageReasonController = TextEditingController();
    List<File> evidencePhotos = [];

    bool submitting = false;
    bool inspectionConfirmed = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(
                  sheetContext,
                ).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isCheckIn
                          ? 'Check-in • Unit ${item.unitCode}'
                          : 'Check-out • Unit ${item.unitCode}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.customerName.isEmpty
                          ? 'Customer'
                          : item.customerName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Tình trạng ngăn kho',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: unitCondition,
                      items: const [
                        DropdownMenuItem(
                          value: 'Good / clean',
                          child: Text('Tốt / sạch'),
                        ),
                        DropdownMenuItem(
                          value: 'Needs cleaning',
                          child: Text('Cần vệ sinh'),
                        ),
                        DropdownMenuItem(
                          value: 'Damaged',
                          child: Text('Hư hỏng'),
                        ),
                      ],
                      onChanged: submitting
                          ? null
                          : (value) {
                              if (value != null) {
                                setSheetState(() {
                                  unitCondition = value;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Tình trạng khóa',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: lockCondition,
                      items: const [
                        DropdownMenuItem(
                          value: 'Locked & working',
                          child: Text(
                            'Khóa hoạt động tốt',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Unlocked',
                          child: Text('Chưa khóa'),
                        ),
                        DropdownMenuItem(
                          value: 'Damaged / needs repair',
                          child: Text(
                            'Hỏng / cần sửa',
                          ),
                        ),
                      ],
                      onChanged: submitting
                          ? null
                          : (value) {
                              if (value != null) {
                                setSheetState(() {
                                  lockCondition = value;
                                });
                              }
                            },
                    ),
                    if (!isCheckIn &&
                        (unitCondition == 'Damaged' ||
                            unitCondition == 'Needs cleaning' ||
                            lockCondition == 'Damaged / needs repair')) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 18, color: Colors.orange.shade900),
                                const SizedBox(width: 8),
                                Text(
                                  'Trừ phí hư hại / vệ sinh',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Khoản này được trừ trực tiếp vào tiền cọc của khách và không được vượt quá tiền cọc đang giữ.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: damageFeeController,
                              keyboardType: TextInputType.number,
                              enabled: !submitting,
                              decoration: const InputDecoration(
                                labelText: 'Phí hư hại / vệ sinh (₫)',
                                prefixIcon: Icon(Icons.attach_money, size: 20),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: damageReasonController,
                              enabled: !submitting,
                              decoration: const InputDecoration(
                                labelText:
                                    'Deduction Reason (e.g. Scratched wall, broken lock)',
                                prefixIcon:
                                    Icon(Icons.description_outlined, size: 20),
                                isDense: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      enabled: !submitting,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú (không bắt buộc)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ảnh bằng chứng (nên có)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCheckIn
                          ? 'Capture photos of clean unit, working lock, and meter (if any) as check-in proof.'
                          : 'Capture photos of return condition, damages, or left-behind items to avoid disputes.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    EvidencePhotoPicker(
                      selectedFiles: evidencePhotos,
                      enabled: !submitting,
                      onFilesChanged: (files) {
                        setSheetState(() {
                          evidencePhotos = files;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: inspectionConfirmed,
                      onChanged: submitting
                          ? null
                          : (value) => setSheetState(() {
                                inspectionConfirmed = value ?? false;
                              }),
                      title: Text(isCheckIn
                          ? 'I verified the customer, unit and lock before handover'
                          : 'I inspected the returned unit and lock'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: submitting || !inspectionConfirmed
                          ? null
                          : () async {
                              setSheetState(() {
                                submitting = true;
                              });

                              try {
                                List<String> uploadedPhotos = [];
                                if (evidencePhotos.isNotEmpty) {
                                  uploadedPhotos = await _opsService.uploadHandoverPhotos(
                                    evidencePhotos.map((f) => f.path).toList(),
                                  );
                                }

                                final HandoverModel result;

                                if (isCheckIn) {
                                  result = await _opsService.checkIn(
                                    bookingId: item.bookingId,
                                    facilityId: _facilityId!,
                                    unitCondition: unitCondition,
                                    lockCondition: lockCondition,
                                    notes: notesController.text,
                                    photos: uploadedPhotos,
                                  );
                                } else {
                                  final num? damageFee = num.tryParse(
                                      damageFeeController.text.trim());
                                  final String? damageReason =
                                      damageReasonController.text
                                              .trim()
                                              .isNotEmpty
                                          ? damageReasonController.text.trim()
                                          : null;

                                  result = await _opsService.checkOut(
                                    bookingId: item.bookingId,
                                    facilityId: _facilityId!,
                                    unitCondition: unitCondition,
                                    lockCondition: lockCondition,
                                    notes: notesController.text,
                                    damageFee: damageFee,
                                    damageReason: damageReason,
                                    photos: uploadedPhotos,
                                  );
                                }

                                if (!sheetContext.mounted) {
                                  return;
                                }

                                Navigator.pop(
                                  sheetContext,
                                );

                                if (!mounted) {
                                  return;
                                }

                                _showSuccess(
                                  result.message.isNotEmpty
                                      ? result.message
                                      : isCheckIn
                                          ? 'Check-in completed successfully'
                                          : 'Check-out completed successfully',
                                );

                                _loadSchedule();
                              } catch (error) {
                                if (!sheetContext.mounted) {
                                  return;
                                }

                                setSheetState(() {
                                  submitting = false;
                                });

                                ScaffoldMessenger.of(
                                  sheetContext,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _errorMessage(error),
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            },
                      child: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isCheckIn
                                  ? 'Complete Check-in'
                                  : 'Complete Check-out',
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    disposeAfterRouteCloses(
        [notesController, damageFeeController, damageReasonController]);
  }

  Future<void> _openHandoverHistory(
    DailyScheduleModel item,
  ) async {
    final historyFuture = _opsService.getHandoverHistory(
      bookingId: item.bookingId,
      facilityId: _facilityId!,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.65,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  20,
                  12,
                  12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lịch sử bàn giao',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.bookingCode} • Unit ${item.unitCode}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.close),
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
                        message: 'Đang tải lịch sử bàn giao...',
                      );
                    }

                    if (snapshot.hasError) {
                      return AppErrorState(
                        message: _errorMessage(
                          snapshot.error!,
                        ),
                      );
                    }

                    final records = snapshot.data ?? <HandoverRecordModel>[];

                    if (records.isEmpty) {
                      return const AppEmptyState(
                        icon: Icons.history,
                        title: 'Chưa có biên bản bàn giao',
                        message: 'Booking này chưa được bàn giao.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: records.length,
                      separatorBuilder: (context, index) {
                        return const SizedBox(
                          height: 10,
                        );
                      },
                      itemBuilder: (
                        context,
                        index,
                      ) {
                        return _buildHistoryCard(
                          records[index],
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

  Widget _buildHistoryCard(
    HandoverRecordModel record,
  ) {
    final isCheckIn = record.recordType.toUpperCase() == 'CHECK_IN';

    final recordedTime = record.recordedAt == null
        ? ''
        : DateFormat(
            'MMM d, yyyy • h:mm a',
          ).format(record.recordedAt!);

    final details = <String>[
      if (record.unitCondition.isNotEmpty) 'Condition: ${record.unitCondition}',
      if (record.damageFee != null && record.damageFee! > 0)
        'Damage Fee: ${record.damageFee} ₫${record.damageReason != null ? " (${record.damageReason})" : ""}',
      if (record.notes.isNotEmpty) 'Notes: ${record.notes}',
      if (record.staffName.isNotEmpty) 'Staff: ${record.staffName}',
      if (recordedTime.isNotEmpty) recordedTime,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isCheckIn
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.secondaryContainer.withValues(alpha: 0.15),
                  child: Icon(
                    isCheckIn ? Icons.login : Icons.logout,
                    color: isCheckIn ? AppColors.success : AppColors.secondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _recordTypeLabel(record.recordType),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (recordedTime.isNotEmpty)
                        Text(
                          recordedTime,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...details
                  .where((d) => d != recordedTime)
                  .map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(d, style: const TextStyle(fontSize: 13)),
                      )),
            ],
            if (record.photos.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Ảnh bằng chứng:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              PhotoThumbnailGrid(photos: record.photos, size: 64),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(
    DailyScheduleModel item,
  ) {
    final isCheckIn = item.isCheckIn;

    final scheduledTime = item.scheduledTime == null
        ? ''
        : _timeFormat.format(
            item.scheduledTime!,
          );

    final customerName =
        item.customerName.isEmpty ? 'Customer' : item.customerName;

    final unitCode = item.unitCode.isEmpty ? '-' : item.unitCode;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isCheckIn
                  ? AppColors.success.withValues(
                      alpha: 0.15,
                    )
                  : AppColors.secondaryContainer.withValues(alpha: 0.15),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unit $unitCode • '
                    '${isCheckIn ? 'Check-in' : 'Check-out'}'
                    '${scheduledTime.isEmpty ? '' : ' • $scheduledTime'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (item.customerEmail.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.customerEmail,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (item.assignedStaffName?.isNotEmpty == true)
                    Text('Assigned: ${item.assignedStaffName}',
                        style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Lịch sử bàn giao',
              onPressed: () {
                _openHandoverHistory(item);
              },
              icon: const Icon(Icons.history),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
              ),
              onPressed: item.assignedStaffId != null &&
                      item.assignedStaffId != widget.user.id
                  ? null
                  : () {
                _openHandoverSheet(item);
              },
              child: Text(
                isCheckIn ? 'Check in' : 'Check out',
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _recordTypeLabel(String recordType) {
    switch (recordType.toUpperCase()) {
      case 'CHECK_IN':
        return 'Check-in';
      case 'CHECK_OUT':
      case 'RETURN':
        return 'Check-out';
      default:
        return recordType.replaceAll('_', ' ');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  String _errorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Nhân viên cơ sở'),
        actions: [
          if (_facilityId != null && _facilityId!.isNotEmpty)
            IconButton(
              tooltip: 'Quét QR cổng',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) =>
                    GatePassVerifyScreen(facilityId: _facilityId!)),
              ),
            ),
          if (_facilityId != null && _facilityId!.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Ngăn kho, hỗ trợ và giao dịch',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                final facilityId = _facilityId!;
                Widget page;
                switch (value) {
                  case 'units':
                    page = StaffUnitsScreen(
                      facilityId: facilityId,
                      facilityName: _facilityName ?? 'Facility',
                    );
                    break;
                  case 'tickets':
                    page = StaffTicketScreen(
                      facilityId: facilityId,
                      staffId: widget.user.id,
                    );
                    break;
                  default:
                    page = TransactionHistoryScreen(
                      userRole: widget.user.roleName,
                      facilityId: facilityId,
                    );
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => page),
                );
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'units', child: Text('Ngăn kho')),
                PopupMenuItem(value: 'tickets', child: Text('Yêu cầu hỗ trợ')),
                PopupMenuItem(
                    value: 'transactions', child: Text('Lịch sử giao dịch')),
              ],
            ),
          IconButton(
            tooltip: 'Profile',
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                widget.user.fullName.isNotEmpty
                    ? widget.user.fullName.substring(0, 1).toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    user: widget.user,
                    facilityId: _facilityId,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingFacility) {
      return const AppLoadingState(
        message: 'Đang tải cơ sở của bạn...',
      );
    }

    if (_facilityError != null) {
      return AppErrorState(
        message: _facilityError!,
        onRetry: _loadFacility,
      );
    }

    if (_facilityId == null || _facilityId!.isEmpty) {
      return const AppEmptyState(
        icon: Icons.storefront_outlined,
        title: 'Chưa được gán cơ sở',
        message: 'Hãy nhờ Facility Manager thêm bạn vào danh sách nhân viên của cơ sở.',
      );
    }

    return Column(
      children: [
        _buildFacilityHeader(),
        Expanded(
          child: FutureBuilder<List<DailyScheduleModel>>(
            future: _scheduleFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AppLoadingState(
                  message: 'Đang tải lịch...',
                );
              }

              if (snapshot.hasError) {
                return AppErrorState(
                  message: _errorMessage(snapshot.error!),
                  onRetry: _loadSchedule,
                );
              }

              final schedules = snapshot.data ?? <DailyScheduleModel>[];

              if (schedules.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refreshSchedule,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      AppEmptyState(
                        icon: Icons.event_available,
                        title: 'Chưa có lịch bàn giao',
                        message: 'Không có khách nhận hoặc trả kho trong ngày này. Khách chỉ hiện từ ngày bắt đầu thuê '
                            '(nhận kho) hoặc theo giờ hẹn/ngày hết hạn (trả kho). Chọn ngày khác để xem.',
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _refreshSchedule,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: schedules.length,
                  itemBuilder: (context, index) {
                    return _buildScheduleCard(
                      schedules[index],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFacilityHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: AppColors.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _facilityName ?? 'Your facility',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _dateFormat.format(
                      _selectedDate,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
