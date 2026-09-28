import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/ticket_model.dart';
import '../../services/staff_ticket_api_service.dart';
import '../../widgets/state_views.dart';

/// Nhân viên cơ sở xử lý ticket hỗ trợ của khách (StaffTicketController).
/// Vòng đời: OPEN -> (nhận xử lý) IN_PROGRESS -> RESOLVED -> CLOSED.
class StaffTicketsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const StaffTicketsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<StaffTicketsScreen> createState() => _StaffTicketsScreenState();
}

class _StaffTicketsScreenState extends State<StaffTicketsScreen> {
  final StaffTicketApiService _service = StaffTicketApiService();
  final _dateFmt = DateFormat('MMM d, h:mm a');

  static const _filters = ['ALL', 'OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'];

  late Future<List<TicketModel>> _future;
  String _filter = 'ALL';
  String? _busyTicketId;

  @override
  void initState() {
    super.initState();
    _future = _service.getFacilityTickets(widget.facilityId);
  }

  void _reload() {
    setState(() => _future = _service.getFacilityTickets(widget.facilityId));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return AppColors.warning;
      case 'IN_PROGRESS':
        return AppColors.secondary;
      case 'RESOLVED':
        return AppColors.success;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ),
    );
  }

  Future<void> _assignToMe(TicketModel ticket) async {
    setState(() => _busyTicketId = ticket.id);
    try {
      await _service.assignToMe(widget.facilityId, ticket.id);
      _snack('Ticket ${ticket.ticketCode} assigned to you');
      _reload();
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busyTicketId = null);
    }
  }

  Future<void> _changeStatus(TicketModel ticket, String nextStatus) async {
    String? note;
    if (nextStatus == 'RESOLVED' || nextStatus == 'CLOSED') {
      note = await _askResolutionNote(ticket, nextStatus);
      if (note == null) return;
    }

    setState(() => _busyTicketId = ticket.id);
    try {
      await _service.updateStatus(
        widget.facilityId,
        ticket.id,
        nextStatus,
        resolutionNote: note,
      );
      _snack('Ticket ${ticket.ticketCode} marked ${nextStatus.replaceAll('_', ' ')}');
      _reload();
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busyTicketId = null);
    }
  }

  // BE bắt buộc resolutionNote khi RESOLVED/CLOSED nên hỏi trước khi gửi.
  Future<String?> _askResolutionNote(TicketModel ticket, String nextStatus) {
    final controller = TextEditingController(text: ticket.resolutionNote ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(nextStatus == 'RESOLVED' ? 'Resolve ticket' : 'Close ticket'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: 'Resolution note',
                    hintText: 'What was done to solve this issue?',
                    errorText: error,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isEmpty) {
                    setLocal(() => error = 'A resolution note is required');
                    return;
                  }
                  Navigator.pop(ctx, text);
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actions(TicketModel t) {
    if (_busyTicketId == t.id) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    switch (t.status) {
      case 'OPEN':
        return ElevatedButton.icon(
          onPressed: () => _assignToMe(t),
          icon: const Icon(Icons.assignment_ind_outlined, size: 16),
          label: const Text('Take ticket'),
        );
      case 'IN_PROGRESS':
        return ElevatedButton.icon(
          onPressed: () => _changeStatus(t, 'RESOLVED'),
          icon: const Icon(Icons.check_circle_outline, size: 16),
          label: const Text('Mark resolved'),
        );
      case 'RESOLVED':
        return OutlinedButton.icon(
          onPressed: () => _changeStatus(t, 'CLOSED'),
          icon: const Icon(Icons.lock_outline, size: 16),
          label: const Text('Close ticket'),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _card(TicketModel t) {
    final created = DateTime.tryParse(t.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.ticketCode,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(t.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  t.status.replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _statusColor(t.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            t.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _meta(Icons.category_outlined, t.category.replaceAll('_', ' ')),
              if (t.bookingCode != null) _meta(Icons.inventory_2_outlined, t.bookingCode!),
              if (created != null) _meta(Icons.schedule, _dateFmt.format(created.toLocal())),
              if (t.assignedStaffName != null)
                _meta(Icons.person_outline, t.assignedStaffName!),
            ],
          ),
          if (t.resolutionNote != null && t.resolutionNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Resolution: ${t.resolutionNote}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: _actions(t)),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(text, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Support Tickets'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: _filters.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f == 'ALL' ? 'All' : f.replaceAll('_', ' ')),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<TicketModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoadingState(message: 'Loading tickets...');
                }
                if (snapshot.hasError) {
                  return AppErrorState(
                    message: snapshot.error.toString().replaceAll('Exception: ', ''),
                    onRetry: _reload,
                  );
                }
                final all = snapshot.data ?? [];
                final tickets =
                    _filter == 'ALL' ? all : all.where((t) => t.status == _filter).toList();
                if (tickets.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.support_agent_outlined,
                    title: 'No tickets',
                    message: _filter == 'ALL'
                        ? 'No customer has sent a support request to ${widget.facilityName} yet.'
                        : 'No ${_filter.replaceAll('_', ' ').toLowerCase()} tickets.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: tickets.length,
                    itemBuilder: (_, i) => _card(tickets[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
