import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/facility_management_models.dart';
import '../../models/staff_ticket_model.dart';
import '../../services/facility_ops_api_service.dart';
import '../../services/staff_ticket_api_service.dart';
import '../../widgets/state_views.dart';

class FacilityTicketsTab extends StatefulWidget {
  final String facilityId;

  const FacilityTicketsTab({
    super.key,
    required this.facilityId,
  });

  @override
  State<FacilityTicketsTab> createState() => _FacilityTicketsTabState();
}

class _FacilityTicketsTabState extends State<FacilityTicketsTab> {
  final StaffTicketApiService _ticketService = StaffTicketApiService();
  final FacilityOpsApiService _opsService = FacilityOpsApiService();

  late Future<List<StaffTicketModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _ticketService.getFacilityTickets(widget.facilityId);
  }

  void _reload() {
    setState(() {
      _future = _ticketService.getFacilityTickets(widget.facilityId);
    });
  }

  Future<void> _refresh() async {
    _reload();
    try {
      await _future;
    } catch (_) {
    }
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ),
    );
  }

  Future<void> _assign(StaffTicketModel ticket) async {
    List<FacilityStaffModel> staff;
    try {
      staff = await _opsService.getFacilityStaff(widget.facilityId);
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''), error: true);
      return;
    }

    if (!mounted) return;

    if (staff.isEmpty) {
      _toast('No staff are assigned to this facility yet.', error: true);
      return;
    }

    final selected = await showModalBottomSheet<FacilityStaffModel>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Assign ${ticket.ticketCode} to',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: staff.map((member) {
                    return ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(member.fullName),
                      subtitle: Text(member.email),
                      onTap: () => Navigator.pop(sheetContext, member),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) return;

    try {
      await _ticketService.assignToStaff(
        facilityId: widget.facilityId,
        ticketId: ticket.id,
        staffId: selected.id,
      );
      _toast('Ticket assigned to ${selected.fullName}');
      _reload();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return AppColors.warning;
      case 'IN_PROGRESS':
        return AppColors.primaryContainer;
      case 'RESOLVED':
        return AppColors.success;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StaffTicketModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(message: 'Loading tickets...');
        }

        if (snapshot.hasError) {
          return AppErrorState(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: _reload,
          );
        }

        final tickets = snapshot.data ?? <StaffTicketModel>[];

        return RefreshIndicator(
          onRefresh: _refresh,
          child: tickets.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    AppEmptyState(
                      icon: Icons.support_agent_outlined,
                      title: 'No support tickets',
                      message: 'Customer tickets for this facility appear here.',
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    final color = _statusColor(ticket.status);
                    final closed = ticket.status == 'RESOLVED' ||
                        ticket.status == 'CLOSED';

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
                                    ticket.ticketCode,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    ticket.status.replaceAll('_', ' '),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ticket.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ticket.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            if (ticket.customerName.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Customer: ${ticket.customerName}'
                                '${ticket.unitCode.isNotEmpty ? ' • Unit ${ticket.unitCode}' : ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              ticket.assignedStaffName.isEmpty
                                  ? 'Unassigned'
                                  : 'Assigned to ${ticket.assignedStaffName}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (!closed) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: () => _assign(ticket),
                                  icon: const Icon(
                                    Icons.person_add_alt,
                                    size: 16,
                                  ),
                                  label: Text(
                                    ticket.assignedStaffName.isEmpty
                                        ? 'Assign staff'
                                        : 'Reassign',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
