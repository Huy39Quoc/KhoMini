import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/user_model.dart';
import '../screens/common/notification_screen.dart';
import '../services/notification_api_service.dart';

class NotificationBadgeButton extends StatefulWidget {
  final UserModel? user;
  final String? facilityId;
  final Color? iconColor;

  const NotificationBadgeButton({
    super.key,
    this.user,
    this.facilityId,
    this.iconColor,
  });

  @override
  State<NotificationBadgeButton> createState() => NotificationBadgeButtonState();
}

class NotificationBadgeButtonState extends State<NotificationBadgeButton> {
  final NotificationApiService _api = NotificationApiService();
  int _unreadCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    refreshUnreadCount();
  }

  Future<void> refreshUnreadCount() async {
    if (!mounted || _isLoading) return;
    _isLoading = true;
    try {
      final count = await _api.getUnreadCount();
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    } catch (_) {
      // Ignore background fetch error
    } finally {
      _isLoading = false;
    }
  }

  void _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationScreen(
          user: widget.user,
          facilityId: widget.facilityId,
        ),
      ),
    );
    refreshUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Thông báo',
      icon: Badge(
        isLabelVisible: _unreadCount > 0,
        label: Text(
          _unreadCount > 99 ? '99+' : '$_unreadCount',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.error,
        child: Icon(
          _unreadCount > 0
              ? Icons.notifications_active_rounded
              : Icons.notifications_outlined,
          color: widget.iconColor,
        ),
      ),
      onPressed: _openNotifications,
    );
  }
}
