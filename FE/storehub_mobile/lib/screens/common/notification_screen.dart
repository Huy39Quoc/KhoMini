import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../services/notification_api_service.dart';
import '../../widgets/state_views.dart';
import '../manager/booking_assignment_screen.dart';
import '../manager/appointment_assignment_screen.dart';
import '../manager/refund_review_screen.dart';
import '../customer/my_units/my_rented_units_screen.dart';
import '../staff/staff_ticket_screen.dart';

class NotificationScreen extends StatefulWidget {
  final UserModel? user;
  final String? facilityId;

  const NotificationScreen({
    super.key,
    this.user,
    this.facilityId,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationApiService _api = NotificationApiService();
  final DateFormat _dateFormat = DateFormat('HH:mm dd/MM/yyyy');

  bool _unreadOnly = false;
  bool _isLoading = true;
  String? _error;
  List<NotificationModel> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _api.getNotifications(
        unreadOnly: _unreadOnly ? true : null,
        size: 50,
      );
      if (!mounted) return;
      setState(() {
        _notifications = result.content;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(NotificationModel notif) async {
    if (notif.isRead) return;
    try {
      await _api.markAsRead(notif.id);
      if (!mounted) return;
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == notif.id);
        if (idx != -1) {
          _notifications[idx] = NotificationModel(
            id: notif.id,
            title: notif.title,
            content: notif.content,
            type: notif.type,
            referenceId: notif.referenceId,
            referenceType: notif.referenceType,
            facilityId: notif.facilityId,
            facilityName: notif.facilityName,
            isRead: true,
            readAt: DateTime.now(),
            createdAt: notif.createdAt,
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    try {
      await _api.markAllAsRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications.map((n) {
          return NotificationModel(
            id: n.id,
            title: n.title,
            content: n.content,
            type: n.type,
            referenceId: n.referenceId,
            referenceType: n.referenceType,
            facilityId: n.facilityId,
            facilityName: n.facilityName,
            isRead: true,
            readAt: DateTime.now(),
            createdAt: n.createdAt,
          );
        }).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đánh dấu tất cả thông báo là đã đọc'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  void _showNotificationDetail(NotificationModel notif) {
    _markAsRead(notif);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final iconData = _getTypeIcon(notif.type);
        final color = _getTypeColor(notif.type);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(iconData, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTypeBadge(notif.type),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          if (notif.createdAt != null)
                            Text(
                              _dateFormat.format(notif.createdAt!),
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
                const SizedBox(height: 16),
                Text(
                  notif.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  notif.content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (notif.facilityName != null && notif.facilityName!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primaryContainer.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.primaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          notif.facilityName!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _buildActionButtons(sheetContext, notif),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext sheetContext, NotificationModel notif) {
    final role = widget.user?.role ?? '';
    final facilityId = notif.facilityId ?? widget.facilityId ?? '';
    final facilityName = notif.facilityName ?? 'Cơ sở';

    Widget? actionBtn;

    if (role == 'FACILITY_MANAGER' && facilityId.isNotEmpty) {
      if (notif.type == 'BOOKING_NEW') {
        actionBtn = ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.assignment_ind_outlined),
          label: const Text('Phân công đơn đặt chỗ'),
          onPressed: () {
            Navigator.pop(sheetContext);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookingAssignmentScreen(
                  facilityId: facilityId,
                  facilityName: facilityName,
                ),
              ),
            );
          },
        );
      } else if (notif.type == 'CHECKOUT_REQUEST') {
        actionBtn = ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondaryContainer,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.schedule_outlined),
          label: const Text('Xem lịch trả kho & Phân công'),
          onPressed: () {
            Navigator.pop(sheetContext);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AppointmentAssignmentScreen(
                  facilityId: facilityId,
                ),
              ),
            );
          },
        );
      } else if (notif.type == 'CHECKOUT_INSPECTED') {
        actionBtn = ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Duyệt hoàn tiền cọc'),
          onPressed: () {
            Navigator.pop(sheetContext);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RefundReviewScreen(
                  facilityId: facilityId,
                ),
              ),
            );
          },
        );
      } else if (notif.type == 'HANDOVER_DEFECT') {
        actionBtn = ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Đổi ngăn kho cho khách'),
          onPressed: () {
            Navigator.pop(sheetContext);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookingAssignmentScreen(
                  facilityId: facilityId,
                  facilityName: facilityName,
                ),
              ),
            );
          },
        );
      } else if (notif.type == 'TICKET_NEW' && widget.user != null) {
        actionBtn = ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.support_agent_rounded),
          label: const Text('Xem yêu cầu hỗ trợ cơ sở'),
          onPressed: () {
            Navigator.pop(sheetContext);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StaffTicketScreen(
                  facilityId: facilityId,
                  staffId: widget.user!.id,
                ),
              ),
            );
          },
        );
      }
    } else if (role == 'STAFF' && facilityId.isNotEmpty) {
      if (notif.type == 'TICKET_NEW' && widget.user != null) {
        actionBtn = ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.support_agent_rounded),
          label: const Text('Tiếp nhận xử lý ticket'),
          onPressed: () {
            Navigator.pop(sheetContext);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StaffTicketScreen(
                  facilityId: facilityId,
                  staffId: widget.user!.id,
                ),
              ),
            );
          },
        );
      }
    } else if (role == 'CUSTOMER') {
      if (notif.referenceType == 'BOOKING') {
        actionBtn = ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Xem kho của tôi'),
          onPressed: () {
            Navigator.pop(sheetContext);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MyRentedUnitsScreen(),
              ),
            );
          },
        );
      }
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('Đóng'),
          ),
        ),
        if (actionBtn != null) ...[
          const SizedBox(width: 12),
          Expanded(child: actionBtn),
        ],
      ],
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'BOOKING_NEW':
        return Icons.bookmark_added_rounded;
      case 'BOOKING_CONFIRMED':
        return Icons.verified_rounded;
      case 'UNIT_ASSIGNED':
        return Icons.meeting_room_rounded;
      case 'APPOINTMENT_SCHEDULED':
        return Icons.assignment_ind_rounded;
      case 'HANDOVER_DEFECT':
        return Icons.warning_amber_rounded;
      case 'CHECKIN_COMPLETED':
        return Icons.check_circle_rounded;
      case 'CHECKOUT_REQUEST':
        return Icons.event_busy_rounded;
      case 'CHECKOUT_INSPECTED':
        return Icons.fact_check_rounded;
      case 'REFUND_COMPLETED':
        return Icons.payments_rounded;
      case 'TICKET_NEW':
        return Icons.support_agent_rounded;
      case 'TICKET_REPLIED':
        return Icons.question_answer_rounded;
      case 'BOOKING_CANCELLED':
        return Icons.cancel_outlined;
      case 'RENTAL_EXTENDED':
        return Icons.more_time_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'BOOKING_NEW':
      case 'BOOKING_CONFIRMED':
      case 'CHECKIN_COMPLETED':
      case 'REFUND_COMPLETED':
        return const Color(0xFF2E7D32); // Green
      case 'UNIT_ASSIGNED':
      case 'TICKET_NEW':
        return const Color(0xFF1565C0); // Blue
      case 'APPOINTMENT_SCHEDULED':
        return const Color(0xFF3949AB); // Indigo
      case 'CHECKOUT_REQUEST':
        return const Color(0xFFE65100); // Orange
      case 'CHECKOUT_INSPECTED':
        return const Color(0xFF00897B); // Teal
      case 'HANDOVER_DEFECT':
      case 'BOOKING_CANCELLED':
        return const Color(0xFFC62828); // Red
      case 'TICKET_REPLIED':
        return const Color(0xFF0288D1); // Light blue
      case 'RENTAL_EXTENDED':
        return const Color(0xFF6A1B9A); // Purple
      default:
        return AppColors.primaryContainer;
    }
  }

  String _getTypeBadge(String type) {
    switch (type) {
      case 'BOOKING_NEW':
        return 'ĐƠN ĐẶT CHỖ MỚI';
      case 'BOOKING_CONFIRMED':
        return 'ĐẶT CỌC THÀNH CÔNG';
      case 'UNIT_ASSIGNED':
        return 'ĐÃ GÁN NGĂN KHO';
      case 'APPOINTMENT_SCHEDULED':
        return 'PHÂN CÔNG LỊCH HẸN';
      case 'HANDOVER_DEFECT':
        return 'KHO CHƯA HỢP LỆ / SỰ CỐ';
      case 'CHECKIN_COMPLETED':
        return 'BÀN GIAO THÀNH CÔNG';
      case 'CHECKOUT_REQUEST':
        return 'YÊU CẦU TRẢ KHO';
      case 'CHECKOUT_INSPECTED':
        return 'NGHIỆM THU TRẢ KHO';
      case 'REFUND_COMPLETED':
        return 'HOÀN CỌC THÀNH CÔNG';
      case 'TICKET_NEW':
        return 'HỖ TRỢ SỰ CỐ';
      case 'TICKET_REPLIED':
        return 'PHẢN HỒI HỖ TRỢ';
      case 'BOOKING_CANCELLED':
        return 'HỦY ĐƠN ĐẶT CHỖ';
      case 'RENTAL_EXTENDED':
        return 'GIA HẠN THUÊ KHO';
      default:
        return 'THÔNG BÁO HỆ THỐNG';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => !n.isRead);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          if (hasUnread)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Đọc tất cả'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondaryContainer,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tất cả'),
                  selected: !_unreadOnly,
                  onSelected: (val) {
                    if (_unreadOnly) {
                      setState(() => _unreadOnly = false);
                      _loadNotifications();
                    }
                  },
                  selectedColor: AppColors.secondaryContainer.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.secondaryContainer,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: !_unreadOnly ? FontWeight.bold : FontWeight.normal,
                    color: !_unreadOnly ? AppColors.secondaryContainer : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Chưa đọc'),
                  selected: _unreadOnly,
                  onSelected: (val) {
                    if (!_unreadOnly) {
                      setState(() => _unreadOnly = true);
                      _loadNotifications();
                    }
                  },
                  selectedColor: AppColors.secondaryContainer.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.secondaryContainer,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _unreadOnly ? FontWeight.bold : FontWeight.normal,
                    color: _unreadOnly ? AppColors.secondaryContainer : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingState(message: 'Đang tải thông báo...');
    }

    if (_error != null) {
      return AppErrorState(
        message: _error!,
        onRetry: _loadNotifications,
      );
    }

    if (_notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadNotifications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 60),
            AppEmptyState(
              icon: Icons.notifications_off_outlined,
              title: _unreadOnly ? 'Không có thông báo chưa đọc' : 'Chưa có thông báo',
              message: _unreadOnly
                  ? 'Bạn đã đọc tất cả thông báo!'
                  : 'Các thao tác liên quan từ khách hàng sẽ hiển thị tại đây.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
        itemBuilder: (context, index) {
          final notif = _notifications[index];
          final color = _getTypeColor(notif.type);
          final iconData = _getTypeIcon(notif.type);

          return Material(
            color: notif.isRead
                ? Colors.transparent
                : AppColors.primary.withValues(alpha: 0.04),
            child: InkWell(
              onTap: () => _showNotificationDetail(notif),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: color.withValues(alpha: 0.12),
                          child: Icon(iconData, color: color, size: 20),
                        ),
                        if (!notif.isRead)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _getTypeBadge(notif.type),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              const Spacer(),
                              if (notif.createdAt != null)
                                Text(
                                  _dateFormat.format(notif.createdAt!),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notif.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: notif.isRead
                                  ? FontWeight.w600
                                  : FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notif.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: notif.isRead
                                  ? AppColors.textSecondary
                                  : Colors.black87,
                            ),
                          ),
                          if (notif.facilityName != null &&
                              notif.facilityName!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              notif.facilityName!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
