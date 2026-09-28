import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/staff_ticket_model.dart';
import '../../services/staff_ticket_api_service.dart';
import '../../widgets/state_views.dart';

class StaffTicketScreen extends StatefulWidget {
  final String facilityId;

  const StaffTicketScreen({
    super.key,
    required this.facilityId,
  });

  @override
  State<StaffTicketScreen> createState() =>
      _StaffTicketScreenState();
}

class _StaffTicketScreenState extends State<StaffTicketScreen> {
  final StaffTicketApiService _ticketService =
  StaffTicketApiService();

  Future<List<StaffTicketModel>>? _ticketsFuture;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  void _loadTickets() {
    setState(() {
      _ticketsFuture = _ticketService.getFacilityTickets(
        widget.facilityId,
      );
    });
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

      _showSuccess('Ticket accepted successfully.');
      _loadTickets();
    } catch (error) {
      if (!mounted) return;
      _showError(_errorMessage(error));
    }
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
          title: const Text('Resolve ticket'),
          content: TextField(
            controller: noteController,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Resolution note',
              hintText: 'Describe how the issue was resolved',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = noteController.text.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.pop(dialogContext, value);
              },
              child: const Text('Resolve'),
            ),
          ],
        );
      },
    );

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

      _showSuccess('Ticket resolved successfully.');
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
          title: const Text('Close ticket'),
          content: const Text(
            'Confirm that this ticket is fully completed?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Close ticket'),
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

      _showSuccess('Ticket closed successfully.');
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

  Widget _buildAction(StaffTicketModel ticket) {
    if (ticket.isOpen) {
      return OutlinedButton.icon(
        onPressed: () {
          _acceptTicket(ticket);
        },
        icon: const Icon(Icons.assignment_turned_in_outlined),
        label: const Text('Accept'),
      );
    }

    if (ticket.isInProgress) {
      return ElevatedButton.icon(
        onPressed: () {
          _resolveTicket(ticket);
        },
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Resolve'),
      );
    }

    if (ticket.isResolved) {
      return ElevatedButton.icon(
        onPressed: () {
          _closeTicket(ticket);
        },
        icon: const Icon(Icons.lock_outline),
        label: const Text('Close'),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Support Tickets'),
      ),
      body: FutureBuilder<List<StaffTicketModel>>(
        future: _ticketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const AppLoadingState(
              message: 'Loading tickets...',
            );
          }

          if (snapshot.hasError) {
            return AppErrorState(
              message: _errorMessage(snapshot.error!),
              onRetry: _loadTickets,
            );
          }

          final tickets =
              snapshot.data ?? <StaffTicketModel>[];

          if (tickets.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshTickets,
              child: ListView(
                physics:
                const AlwaysScrollableScrollPhysics(),
                children: const [
                  AppEmptyState(
                    icon: Icons.support_agent_outlined,
                    title: 'No support tickets',
                    message:
                    'Tickets from customers at this facility will appear here.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshTickets,
            child: ListView.separated(
              physics:
              const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: tickets.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                final statusColor =
                _statusColor(ticket.status);

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
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
                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius:
                                BorderRadius.circular(10),
                              ),
                              child: Text(
                                ticket.status.replaceAll('_', ' '),
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
                          'Category: ${ticket.category} • Priority: ${ticket.priority}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        if (ticket.bookingCode.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Booking: ${ticket.bookingCode}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                        if (ticket.assignedStaffName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Assigned: ${ticket.assignedStaffName}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                        if (ticket.resolutionNote.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Resolution: ${ticket.resolutionNote}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
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