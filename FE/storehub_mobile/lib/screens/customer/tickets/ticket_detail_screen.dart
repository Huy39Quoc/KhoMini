import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/ticket_api_service.dart';
import '../../../widgets/state_views.dart';

const Map<String, String> _kCategoryLabels = {
  'PIN_CODE': 'Access PIN issue',
  'LOCK_ISSUE': 'Lock / door issue',
  'FACILITY_DAMAGE': 'Facility damage',
  'PAYMENT_ISSUE': 'Payment issue',
  'OTHER': 'Other',
};

/// GET /customer/tickets/{ticketId} already existed on the BE and in
/// ticket_api_service.dart, but no screen ever called it - tapping a ticket
/// in the list did nothing. This screen wires that up.
class TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final TicketApiService _ticketApiService = TicketApiService();
  late Future<Map<String, dynamic>> _ticketFuture;
  final _dateFmt = DateFormat('MMM d, yyyy • h:mm a');

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _ticketFuture = _ticketApiService.getTicketDetail(widget.ticketId);
    });
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'OPEN':
        return AppColors.warning;
      case 'IN_PROGRESS':
        return AppColors.secondaryContainer;
      case 'RESOLVED':
      case 'CLOSED':
        return AppColors.success;
      default:
        return AppColors.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Ticket Details'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _ticketFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(message: 'Loading ticket...');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: snapshot.error.toString().replaceAll('Exception: ', ''),
              onRetry: _load,
            );
          }

          final ticket = snapshot.data!;
          final status = ticket['status']?.toString();
          final category = ticket['category']?.toString();
          final ticketCode = ticket['ticketCode']?.toString() ?? '';
          final title = ticket['title']?.toString() ?? '';
          final description = ticket['description']?.toString() ?? '';
          final priority = ticket['priority']?.toString();
          final resolutionNote = ticket['resolutionNote']?.toString();
          final bookingCode = ticket['bookingCode']?.toString();
          final createdAt = ticket['createdAt'] != null
              ? DateTime.tryParse(ticket['createdAt'].toString())
              : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(ticketCode,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                            letterSpacing: 0.5)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (status ?? 'OPEN').replaceAll('_', ' '),
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold, color: _statusColor(status)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _tag(Icons.category_outlined, _kCategoryLabels[category] ?? category ?? ''),
                    if (priority != null && priority.isNotEmpty)
                      _tag(Icons.flag_outlined, priority),
                    if (bookingCode != null && bookingCode.isNotEmpty)
                      _tag(Icons.inventory_2_outlined, bookingCode),
                    if (createdAt != null)
                      _tag(Icons.schedule_outlined, _dateFmt.format(createdAt)),
                  ],
                ),
                const SizedBox(height: 20),

                const Text('Description',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(description, style: const TextStyle(fontSize: 14, height: 1.5)),
                  ),
                ),

                if (resolutionNote != null && resolutionNote.trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Resolution',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(resolutionNote, style: const TextStyle(fontSize: 13, height: 1.5)),
                        ),
                      ],
                    ),
                  ),
                ] else if (status == 'OPEN' || status == 'IN_PROGRESS') ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hourglass_empty, size: 18, color: AppColors.onSurfaceVariant),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Our team is still reviewing this request. You will see an update here once it is resolved.',
                            style: TextStyle(fontSize: 12.5, color: AppColors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
