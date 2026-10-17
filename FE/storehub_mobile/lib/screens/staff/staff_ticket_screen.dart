import 'package:flutter/material.dart';

import '../../core/utils/vi_labels.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/safe_dispose.dart';
import '../../models/staff_ticket_model.dart';
import '../../models/paged_result.dart';
import '../../services/facility_ops_api_service.dart';
import '../../services/staff_ticket_api_service.dart';
import '../../widgets/state_views.dart';
import '../../widgets/photo_preview_dialog.dart';

class StaffTicketScreen extends StatefulWidget {
  final String facilityId;
  final String staffId;

  const StaffTicketScreen({
    super.key,
    required this.facilityId,
    required this.staffId,
  });

  @override
  State<StaffTicketScreen> createState() => _StaffTicketScreenState();
}

class _StaffTicketScreenState extends State<StaffTicketScreen> {
  final StaffTicketApiService _ticketService = StaffTicketApiService();
  final FacilityOpsApiService _opsService = FacilityOpsApiService();

  Future<PagedResult<StaffTicketModel>>? _ticketsFuture;
  final List<StaffTicketModel> _additional = [];
  int _nextPage = 1;
  bool _lastPage = false;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  void _loadTickets() {
    setState(() {
      _additional.clear();
      _nextPage = 1;
      _lastPage = false;
      _ticketsFuture = _ticketService.getFacilityTickets(
        widget.facilityId,
      );
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _lastPage) return;
    final currentLoad = _ticketsFuture;
    setState(() => _loadingMore = true);
    try {
      final page = await _ticketService.getFacilityTickets(widget.facilityId,
          page: _nextPage);
      if (!mounted || !identical(currentLoad, _ticketsFuture)) return;
      setState(() {
        _additional.addAll(page.content);
        _nextPage++;
        _lastPage = page.last;
      });
    } catch (error) {
      if (mounted) _showError(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refreshTickets() async {
    _loadTickets();

    try {
      await _ticketsFuture;
    } catch (_) {
      // FutureBuilder hiển thị lỗi.
    }
  }

  Future<void> _acceptTicket(
    StaffTicketModel ticket,
  ) async {
    try {
      await _ticketService.assignToMe(
        facilityId: widget.facilityId,
        ticketId: ticket.id,
      );

      if (!mounted) return;

      _showSuccess('Đã tiếp nhận yêu cầu.');
      _loadTickets();
    } catch (error) {
      if (!mounted) return;
      _showError(_errorMessage(error));
    }
  }

  bool _isAssignedToCurrentStaff(StaffTicketModel ticket) {
    return ticket.assignedStaffId.isNotEmpty &&
        ticket.assignedStaffId == widget.staffId;
  }

  Future<void> _resolveTicket(
    StaffTicketModel ticket,
  ) async {
    final noteController = TextEditingController(
      text: ticket.resolutionNote,
    );

    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hoàn tất yêu cầu'),
          content: TextField(
            controller: noteController,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Ghi chú xử lý',
              hintText: 'Mô tả cách đã xử lý sự cố',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = noteController.text.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.pop(dialogContext, value);
              },
              child: const Text('Hoàn tất xử lý'),
            ),
          ],
        );
      },
    );
    disposeAfterRouteCloses([noteController]);

    if (note == null || note.trim().isEmpty) {
      return;
    }

    try {
      await _ticketService.updateStatus(
        facilityId: widget.facilityId,
        ticketId: ticket.id,
        status: 'RESOLVED',
        resolutionNote: note,
      );

      if (!mounted) return;

      _showSuccess('Đã hoàn tất xử lý yêu cầu.');
      _loadTickets();
    } catch (error) {
      if (!mounted) return;
      _showError(_errorMessage(error));
    }
  }

  Future<void> _closeTicket(
    StaffTicketModel ticket,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Đóng yêu cầu'),
          content: const Text(
            'Xác nhận yêu cầu này đã hoàn tất?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Đóng yêu cầu'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _ticketService.updateStatus(
        facilityId: widget.facilityId,
        ticketId: ticket.id,
        status: 'CLOSED',
      );

      if (!mounted) return;

      _showSuccess('Đã đóng yêu cầu.');
      _loadTickets();
    } catch (error) {
      if (!mounted) return;
      _showError(_errorMessage(error));
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return AppColors.warning;
      case 'IN_PROGRESS':
        return AppColors.primary;
      case 'RESOLVED':
        return AppColors.success;
      case 'CLOSED':
        return AppColors.onSurfaceVariant;
      default:
        return AppColors.outline;
    }
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

  /// Khách quên PIN và không tự đặt lại được: nhân viên xác minh khách tại quầy rồi cấp PIN mới.
  Future<void> _resetCustomerPin(StaffTicketModel ticket) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đặt lại PIN cho khách?'),
        content: const Text(
            'Chỉ tiếp tục sau khi bạn đã xác minh trực tiếp danh tính của khách. '
            'PIN cũ sẽ ngừng hoạt động và ngăn kho được khóa lại.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đặt lại PIN')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final pin = await _opsService.resetCustomerPin(
          ticket.bookingId, widget.facilityId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Mã PIN mới'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                pin,
                style: const TextStyle(
                    fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 8),
              ),
              const SizedBox(height: 10),
              const Text(
                'Hãy đọc mã PIN này cho khách. Mã chỉ hiển thị một lần và khách có thể đổi trong mục Khóa thông minh.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Xong')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Widget _buildAction(StaffTicketModel ticket) {
    if (ticket.isOpen) {
      return OutlinedButton.icon(
        onPressed: () {
          _acceptTicket(ticket);
        },
        icon: const Icon(Icons.assignment_turned_in_outlined),
        label: const Text('Tiếp nhận'),
      );
    }

    final isOwner = _isAssignedToCurrentStaff(ticket);

    if (ticket.isInProgress && isOwner) {
      final resolveButton = ElevatedButton.icon(
        onPressed: () {
          _resolveTicket(ticket);
        },
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Hoàn tất xử lý'),
      );
      if (ticket.category == 'PIN_CODE' && ticket.bookingId.isNotEmpty) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _resetCustomerPin(ticket),
              icon: const Icon(Icons.pin_outlined),
              label: const Text('Đặt lại PIN'),
            ),
            resolveButton,
          ],
        );
      }
      return resolveButton;
    }

    if (ticket.isResolved && isOwner) {
      return ElevatedButton.icon(
        onPressed: () {
          _closeTicket(ticket);
        },
        icon: const Icon(Icons.lock_outline),
        label: const Text('Đóng'),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Yêu cầu hỗ trợ'),
      ),
      body: FutureBuilder<PagedResult<StaffTicketModel>>(
        future: _ticketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(
              message: 'Đang tải yêu cầu hỗ trợ...',
            );
          }

          if (snapshot.hasError) {
            return AppErrorState(
              message: _errorMessage(snapshot.error!),
              onRetry: _loadTickets,
            );
          }

          final tickets = [...?snapshot.data?.content, ..._additional];
          final hasMore = snapshot.data != null && !snapshot.data!.last && !_lastPage;

          if (tickets.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshTickets,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  AppEmptyState(
                    icon: Icons.support_agent_outlined,
                    title: 'Chưa có yêu cầu hỗ trợ',
                    message:
                        'Yêu cầu hỗ trợ của khách tại cơ sở này sẽ hiển thị tại đây.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshTickets,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: tickets.length + (hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == tickets.length) {
                  return Center(child: TextButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: Text(_loadingMore ? 'Đang tải...' : 'Xem thêm yêu cầu'),
                  ));
                }
                final ticket = tickets[index];
                final statusColor = _statusColor(ticket.status);

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                ticket.ticketCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                ViLabels.ticketStatus(ticket.status),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ticket.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ticket.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Loại: ${ticket.category} • Ưu tiên: ${ticket.priority}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        if (ticket.bookingCode.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Đơn: ${ticket.bookingCode}'
                            '${ticket.unitCode.isNotEmpty ? ' • Unit ${ticket.unitCode}' : ''}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                        if (ticket.customerName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Khách: ${ticket.customerName}'
                            '${ticket.customerPhone.isNotEmpty ? ' • ${ticket.customerPhone}' : ''}'
                            '${ticket.customerEmail.isNotEmpty ? ' • ${ticket.customerEmail}' : ''}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                        if (ticket.assignedStaffName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Phụ trách: ${ticket.assignedStaffName}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                        if (ticket.resolutionNote.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Cách xử lý: ${ticket.resolutionNote}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        if (ticket.photos.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Ảnh bằng chứng:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          PhotoThumbnailGrid(
                            photos: ticket.photos,
                            size: 64,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _buildAction(ticket),
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
