import 'package:flutter/material.dart';
import '../../../core/utils/vi_labels.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/ticket_api_service.dart';
import '../../../models/paged_result.dart';
import '../../../widgets/state_views.dart';
import 'create_ticket_screen.dart';
import 'ticket_detail_screen.dart';

class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  final TicketApiService _ticketApiService = TicketApiService();
  late Future<PagedResult<Map<String, dynamic>>> _ticketsFuture;
  final List<Map<String, dynamic>> _additional = [];
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
      _ticketsFuture = _ticketApiService.getMyTickets();
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _lastPage) return;
    final currentLoad = _ticketsFuture;
    setState(() => _loadingMore = true);
    try {
      final result = await _ticketApiService.getMyTickets(page: _nextPage);
      if (!mounted || !identical(currentLoad, _ticketsFuture)) return;
      setState(() {
        _additional.addAll(result.content);
        _nextPage++;
        _lastPage = result.last;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  static const Map<String, String> _categoryLabels = {
    'PIN_CODE': 'Sự cố mã PIN',
    'LOCK_ISSUE': 'Sự cố khóa / cửa',
    'FACILITY_DAMAGE': 'Hư hỏng cơ sở',
    'PAYMENT_ISSUE': 'Sự cố thanh toán',
    'OTHER': 'Khác',
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
        title: const Text('Yêu cầu hỗ trợ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTickets,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadTickets(),
        child: FutureBuilder<PagedResult<Map<String, dynamic>>>(
          future: _ticketsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingState(message: 'Đang tải yêu cầu của bạn...');
            } else if (snapshot.hasError) {
              return ListView(
                children: [
                  AppErrorState(
                    message:
                        snapshot.error.toString().replaceAll('Exception: ', ''),
                    onRetry: _loadTickets,
                  ),
                ],
              );
            } else if (!snapshot.hasData || snapshot.data!.content.isEmpty) {
              return ListView(
                children: const [
                  AppEmptyState(
                    icon: Icons.support_agent,
                    title: 'Chưa có yêu cầu hỗ trợ',
                    message:
                        'Nếu gặp sự cố với ngăn kho, mã PIN hoặc thanh toán, chạm + để báo cho chúng tôi.',
                  ),
                ],
              );
            }

            final tickets = [...snapshot.data!.content, ..._additional];
            final hasMore = !snapshot.data!.last && !_lastPage;
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: tickets.length + (hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == tickets.length) {
                  return Center(child: TextButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: Text(_loadingMore ? 'Đang tải...' : 'Xem thêm yêu cầu'),
                  ));
                }
                final ticket = tickets[index];
                final category = ticket['category']?.toString();
                final status = ticket['status']?.toString();
                final priority = ticket['priority']?.toString();
                final ticketCode = ticket['ticketCode']?.toString();
                final title = (ticket['title'] as String?)?.trim();
                final description = ticket['description']?.toString() ?? '';
                final resolutionNote = ticket['resolutionNote']?.toString();

                final ticketId = ticket['id']?.toString() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: ticketId.isEmpty
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TicketDetailScreen(ticketId: ticketId),
                                ),
                              );
                            },
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    ViLabels.ticketStatus(status ?? 'OPEN'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _statusColor(status),
                                    ),
                                  ),
                                ),
                                if (priority != null &&
                                    priority.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainer,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      priority,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title?.isNotEmpty == true
                                  ? title!
                                  : (_categoryLabels[category] ??
                                      category ??
                                      'Yêu cầu hỗ trợ'),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _categoryLabels[category] ?? category ?? '',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            if (resolutionNote != null &&
                                resolutionNote.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.success.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle_outline,
                                        size: 16, color: AppColors.success),
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
        label: const Text('Yêu cầu mới'),
      ),
    );
  }
}
