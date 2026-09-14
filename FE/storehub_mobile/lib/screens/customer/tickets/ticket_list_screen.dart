import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/ticket_model.dart';
import '../../../services/ticket_api_service.dart';
import 'create_ticket_screen.dart';

class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  final TicketApiService _ticketService = TicketApiService();
  late Future<List<TicketModel>> _ticketsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _ticketsFuture = _ticketService.getMyTickets();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Requests'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<TicketModel>>(
        future: _ticketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const Center(
                child: Text('No support requests submitted yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final t = list[i];
              return Card(
                elevation: 2,
                child: ListTile(
                  title: Text(t.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle:
                      Text('${t.ticketCode} • ${t.category}\n${t.description}'),
                  trailing: Chip(
                    label: Text(t.status,
                        style:
                            const TextStyle(fontSize: 10, color: Colors.white)),
                    backgroundColor: t.status == 'RESOLVED'
                        ? AppColors.success
                        : AppColors.accent,
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateTicketScreen()),
        ).then((_) => _load()),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
