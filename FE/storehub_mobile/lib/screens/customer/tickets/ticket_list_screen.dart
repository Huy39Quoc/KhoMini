import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/ticket_api_service.dart';
import '../../../widgets/state_views.dart';
import 'create_ticket_screen.dart';

class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  final TicketApiService _ticketApiService = TicketApiService();
  late Future<List<dynamic>> _ticketsFuture;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  void _loadTickets() {
    setState(() {
      _ticketsFuture = _ticketApiService.getMyTickets();
    });
  }

  static const Map<String, String> _categoryLabels = {
    'PIN_CODE': 'Access PIN issue',
    'LOCK_ISSUE': 'Lock / door issue',
    'FACILITY_DAMAGE': 'Facility damage',
    'PAYMENT_ISSUE': 'Payment issue',
    'OTHER': 'Other',
  };

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
        title: const Text('Support Tickets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTickets,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadTickets(),
        child: FutureBuilder<List<dynamic>>(
          future: _ticketsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingState(message: 'Loading your tickets...');
            } else if (snapshot.hasError) {
              return ListView(
                children: [
                  AppErrorState(
                    message: snapshot.error.toString().replaceAll('Exception: ', ''),
                    onRetry: _loadTickets,
                  ),
                ],
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return ListView(
                children: const [
                  AppEmptyState(
                    icon: Icons.support_agent,
                    title: 'No support requests yet',
                    message:
                        'If you run into an issue with your unit, PIN, or payment, tap + to let us know.',
                  ),
                ],
              );
            }

            final tickets = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: tickets.length,
              itemBuilder: (context, index) {
                final ticket = tickets[index] as Map;
                final category = ticket['category']?.toString();
                final status = ticket['status']?.toString();
                final priority = ticket['priority']?.toString();
                final ticketCode = ticket['ticketCode']?.toString();
                final title = (ticket['title'] as String?)?.trim();
                final description = ticket['description']?.toString() ?? '';
                final resolutionNote = ticket['resolutionNote']?.toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (ticketCode != null && ticketCode.isNotEmpty)
                                Text(
                                  ticketCode,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  (status ?? 'OPEN').replaceAll('_', ' '),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _statusColor(status),
                                  ),
                                ),
                              ),
                              if (priority != null && priority.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    priority,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title?.isNotEmpty == true
                                ? title!
                                : (_categoryLabels[category] ?? category ?? 'Support request'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _categoryLabels[category] ?? category ?? '',
                            style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (resolutionNote != null && resolutionNote.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      resolutionNote,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateTicketScreen()),
          );
          if (result == true) {
            _loadTickets();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New request'),
      ),
    );
  }
}
